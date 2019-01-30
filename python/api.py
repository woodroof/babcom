#!/usr/bin/env python3
import asyncio
import asyncpg
import os
import json
import uuid

from aiohttp import web, WSMsgType
from aiojobs.aiohttp import atomic, setup
from pathlib import Path
from prometheus_client import Counter, Gauge, Summary, Histogram, start_http_server
from prometheus_async.aio import time

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

async def init_socket(socket, request):
    await socket.prepare(request)

@time(SQL_TIME)
async def execute_sql(connection, query, *args):
    try:
        await connection.execute(query, *args)
    except:
        SQL_EXCEPTION_COUNT.inc()
        raise

@time(SQL_TIME)
async def fetchval_sql(connection, query, *args):
    try:
        return await connection.fetchval(query, *args)
    except:
        SQL_EXCEPTION_COUNT.inc()
        raise

async def connect(connection, client_code, connection_object, request):
    CONNECTION_COUNT.inc()
    print('Connected: %s' % client_code)
    await execute_sql(connection, 'select api.connect_client($1)', client_code)
    ws = web.WebSocketResponse()
    connection_object['ws'] = ws
    await init_socket(ws, request)
    return ws

async def reconnect(connection, client_code, connection_object, request):
    print('Reconnected: %s' % client_code)
    await connection_object['ws'].close()
    await execute_sql(connection, 'select api.disconnect_client($1)', client_code)
    await execute_sql(connection, 'select api.connect_client($1)', client_code)
    ws = web.WebSocketResponse()
    connection_object['ws'] = ws
    await init_socket(ws, request)
    return ws

async def disconnect(connection, client_code):
    CONNECTION_COUNT.dec()
    print('Disconnected: %s' % client_code)
    await execute_sql(connection, 'select api.disconnect_client($1)', client_code)

async def process_message(connection, client_code, data):
    await execute_sql(connection, 'select api.api($1, $2)', client_code, data)

async def process_notification(connection, notification_id):
    return await fetchval_sql(connection, 'select api.get_notification($1)', notification_id)

@atomic
@time(CONNECTION_TIME)
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
    return web.Response(status=200, content_type='application/json', text=response_text)

async def async_listener(app, notification_id):
    connections = app.connections
    pool = app.db_pool

    async with pool.acquire() as connection:
        result = await process_notification(connection, notification_id)
        client_code = result['client_code']
        if client_code in connections:
            connection_object = connections[client_code]
            ws = connection_object['ws']
            async with connection_object['lock']:
                if connection_object['ws'] is ws:
                    # TODO обработка исключения при закрытии подключения
                    await ws.send_str(result['message'])

def listener_creator(app):
    def listener(connection, pid, channel, payload):
        asyncio.get_event_loop().create_task(async_listener(app, payload))
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
    app.db_pool = await asyncpg.create_pool(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, database=DB_NAME, init=init_connection)
    async with app.db_pool.acquire() as connection:
        await connection.execute('select api.disconnect_all_clients()')
    app.listen_connection = await asyncpg.connect(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, database=DB_NAME)
    await app.listen_connection.add_listener('api_channel', listener_creator(app))
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