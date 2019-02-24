#!/usr/bin/env python3
import asyncio
import asyncpg
import time
import os
import json
import uuid

from aiohttp import web, WSMsgType
from aiojobs.aiohttp import atomic, setup
from collections import deque
from pathlib import Path
from prometheus_client import Counter, Gauge, Histogram, start_http_server
from prometheus_async import aio

from db_settings import DB_HOST, DB_PORT, DB_NAME

DB_USER = 'http'
DB_PASSWORD = 'http'

PORT = 8000
PROMETHEUS_CLIENT_PORT = 9001

TMP_DIR_PATH = Path(os.path.dirname(os.path.abspath(__file__))) / 'tmp'
IMAGES_DIR_PATH = TMP_DIR_PATH / '..' / 'images'

OP_TIME_BUCKETS = (0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10)
LONG_TIME_BUCKETS = (0.001, 0.01, 0.1, 1, 10, 1*60, 2*60, 5*60, 10*60, 30*60, 1*60*60, 2*60*60, 5*60*60, 10*60*60, 24*60*60)

SQL_TIME = Histogram('sql_time_seconds', 'Time spent executing sql query', buckets=OP_TIME_BUCKETS)

CONNECTION_TIME = Histogram('connection_time_seconds', 'Connection lifetime', buckets=LONG_TIME_BUCKETS)

SQL_EXCEPTION_COUNT = Counter('sql_exception_count', 'Total number of sql errors')

CONNECTION_COUNT = Gauge('connection_count', 'Current number of active connections')
PROCESSING_MESSAGE_COUNT = Gauge('processing_message_count', 'Current number of processing messages')

DB_DEADLOCK_COUNT = Gauge('db_deadlock_count', 'Total number of deadlocks')
DB_ERROR_COUNT = Gauge('db_error_count', 'Total number of errors')
DB_MAX_API_TIME = Gauge('db_max_api_time_ms', 'Max time of api request')
DB_MAX_JOB_TIME = Gauge('db_max_job_time_ms', 'Max time of single job processing')

@aio.time(SQL_TIME)
async def execute_sql(connection, query, *args):
    try:
        await connection.execute(query, *args)
    except:
        SQL_EXCEPTION_COUNT.inc()
        raise

@aio.time(SQL_TIME)
async def fetchval_sql(connection, query, *args):
    try:
        return await connection.fetchval(query, *args)
    except:
        SQL_EXCEPTION_COUNT.inc()
        raise

class Worker:
    def __init__(self, pool):
        self._pool = pool
        self._job_active = False
        self._time = None
        self._task = None

    def set_timeout(self, timeout):
        new_time = time.monotonic() + timeout
        if self._time is None or self._time > new_time:
            self._time = new_time
            if self._task is None or not self._job_active:
                if self._task is not None and not self._task.done():
                    self._task.cancel()
                self._task = asyncio.ensure_future(self._job())

    async def _job(self):
        await asyncio.sleep(max(self._time - time.monotonic(), 0))
        self._time = None
        self._job_active = True
        await self._run_db_job()
        self._job_active = False
        if self._time is not None:
            self._task = asyncio.ensure_future(self._job())

    async def _run_db_job(self):
        async with self._pool.acquire() as connection:
            await execute_sql(connection, 'select api.run_jobs()')

async def init_socket(socket, request):
    await socket.prepare(request)

async def connect(connection, client_code, connection_object, request):
    CONNECTION_COUNT.inc()
    await execute_sql(connection, 'select api.connect_client($1)', client_code)
    ws = web.WebSocketResponse()
    connection_object['ws'] = ws
    await init_socket(ws, request)
    return ws

async def reconnect(connection, client_code, connection_object, request):
    #TODO отправлять сообщение определённого формата
    await connection_object['ws'].close()
    #TODO чтобы не отправлять новому клиенту старые сообщения, нужно из БД получать какой-то id активного подключения, но пока забиваем
    await execute_sql(connection, 'select api.disconnect_client($1)', client_code)
    await execute_sql(connection, 'select api.connect_client($1)', client_code)
    ws = web.WebSocketResponse()
    connection_object['ws'] = ws
    connection_object['queue'].clear()
    await init_socket(ws, request)
    return ws

async def disconnect(connection, client_code):
    CONNECTION_COUNT.dec()
    await execute_sql(connection, 'select api.disconnect_client($1)', client_code)

async def process_message(connection, client_code, data):
    await execute_sql(connection, 'select api.api($1, $2)', client_code, data)

async def process_notification(connection, notification_id):
    return await fetchval_sql(connection, 'select api.get_notification($1)', notification_id)

@atomic
@aio.time(CONNECTION_TIME)
async def api(request):
    client_code = request.match_info.get('client_id')

    connections = request.app.connections
    pool = request.app.db_pool

    async with pool.acquire() as connection:
        if client_code in connections:
            connection_object = connections[client_code]
            async with connection_object['lock']:
                ws = await reconnect(connection, client_code, connection_object, request)
        else:
            connection_object = {}
            lock = asyncio.Lock()
            connection_object['lock'] = lock
            connection_object['processing'] = False
            connection_object['queue'] = deque()
            connections[client_code] = connection_object
            async with lock:
                ws = await connect(connection, client_code, connection_object, request)

    async for msg in ws:
        if msg.type == WSMsgType.TEXT:
            PROCESSING_MESSAGE_COUNT.inc()
            async with pool.acquire() as connection:
                await process_message(connection, client_code, msg.data)
            PROCESSING_MESSAGE_COUNT.dec()
        elif msg.type == WSMsgType.BINARY:
            print('Received binary message')
        elif msg.type == WSMsgType.ERROR:
            print('Connection closed: %s' % ws.exception())

    async with connection_object['lock']:
        if connection_object['ws'] is ws:
            del connections[client_code]

            async with pool.acquire() as connection:
                await disconnect(connection, client_code)

    return ws

async def post_image(request):
    reader = await request.multipart()

    field = await reader.next()
    if field.name != 'image':
        return web.Response(status=400, text='Form field "image" not found')

    extension = os.path.splitext(field.filename)[1]
    file_name = str(uuid.uuid4())
    tmp_path = TMP_DIR_PATH / file_name
    dest_path = IMAGES_DIR_PATH / (file_name + extension)
    size = 0
    with open(tmp_path, 'wb') as file:
        while True:
            chunk = await field.read_chunk()
            if not chunk:
                break
            size += len(chunk)
            file.write(chunk)
    # TODO обработать прерывание загрузки
    # TODO check size
    os.rename(tmp_path, dest_path)
    response_text = '{{"filename": "{}{}"}}'.format(file_name, extension)
    additional_headers = {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*'}
    return web.Response(status=200, content_type='application/json', text=response_text, headers=additional_headers)

async def process_client_notifications(app, client_code):
    connections = app.connections
    pool = app.db_pool

    if not client_code in connections:
        return

    connection_object = connections[client_code]

    async with pool.acquire() as connection:
        while True:
            tasks = list(connection_object['queue'])

            if len(tasks) == 0:
                connection_object['processing'] = False
                return

            connection_object['queue'].clear()
            ws = connection_object['ws']
            lock = connection_object['lock']

            for task in tasks:
                result = await process_notification(connection, task)
                if result is not None:
                    notification_type = result['type']
                    message = result['message']

                    if notification_type == 'client_message':
                        async with lock:
                            if not client_code in connections or not connections[client_code]['ws'] is ws:
                                return

                            try:
                                await ws.send_str(json.dumps(message, ensure_ascii=False))
                            except RuntimeError:
                                return
                    else:
                        print('Unsupported client notification type ' + notification_type)

async def process_app_notifications(app):
    pool = app.db_pool
    queue = app.listener['queue']

    async with pool.acquire() as connection:
        while True:
            tasks = list(queue)

            if len(tasks) == 0:
                app.listener['processing'] = False
                return

            queue.clear()

            for task in tasks:
                result = await process_notification(connection, task)
                if result is not None:
                    notification_type = result['type']
                    message = result['message']

                    if notification_type == 'metric':
                        metric_type = message['type']
                        value = message['value']

                        if metric_type == 'max_api_time_ms':
                            DB_MAX_API_TIME.set(value)
                        elif metric_type == 'max_job_time_ms':
                            DB_MAX_JOB_TIME.set(value)
                        elif metric_type == 'error_count':
                            DB_ERROR_COUNT.set(value)
                        elif metric_type == 'deadlock_count':
                            DB_DEADLOCK_COUNT.set(value)
                        else:
                            print('Unsupported metric type ' + metric_type)
                    elif notification_type == 'job':
                        app.worker.set_timeout(message)
                    else:
                        print('Unsupported non-client notification type ' + notification_type)

def listener_creator(app):
    def listener(connection, pid, channel, payload):
        connections = app.connections
        notification = json.loads(payload)
        notification_code = notification['notification_code']
        if 'client_code' in notification:
            client_code = notification['client_code']
            if client_code in connections:
                connection_object = connections[client_code]
                connection_object['queue'].append(notification_code)
                if not connection_object['processing']:
                    connection_object['processing'] = True
                    asyncio.get_event_loop().create_task(process_client_notifications(app, client_code))
        else:
            app.listener['queue'].append(notification_code)
            if not app.listener['processing']:
                app.listener['processing'] = True
                asyncio.get_event_loop().create_task(process_app_notifications(app))
    return listener

def jsonb_encoder(value):
    return b'\x01' + json.dumps(json.loads(value)).encode('utf-8')

def jsonb_decoder(value):
    return json.loads(value[1:].decode('utf-8'))

async def init_connection(conn):
    await conn.set_type_codec('jsonb', encoder=jsonb_encoder, decoder=jsonb_decoder, schema='pg_catalog', format='binary')

async def init_app():
    app = web.Application()
    setup(app)
    app.add_routes(
        [
            web.get('/api/{client_id}', api),
            web.post('/images', post_image),
        ])
    app.router.add_static('/images/', IMAGES_DIR_PATH)
    app.connections = {}

    app.listener = {}
    app.listener['queue'] = deque()
    app.listener['processing'] = False

    app.db_pool = await asyncpg.create_pool(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, database=DB_NAME, init=init_connection)
    async with app.db_pool.acquire() as connection:
        await connection.execute('select api.disconnect_all_clients()')
    app.listen_connection = await asyncpg.connect(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, database=DB_NAME)
    await app.listen_connection.add_listener('api_channel', listener_creator(app))
    app.worker = Worker(app.db_pool)
    app.worker.set_timeout(0)
    return app

if __name__ == '__main__':
    if not os.path.exists(IMAGES_DIR_PATH):
        os.makedirs(IMAGES_DIR_PATH)
    if not os.path.exists(TMP_DIR_PATH):
        os.makedirs(TMP_DIR_PATH)

    start_http_server(PROMETHEUS_CLIENT_PORT)
    loop = asyncio.get_event_loop()
    app = loop.run_until_complete(init_app())
    web.run_app(app, port = PORT)