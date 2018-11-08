import asyncio
import asyncpg
import json

from aiohttp import web, WSMsgType
from aiojobs.aiohttp import atomic, setup
from prometheus_client import Summary, Histogram, start_http_server
from prometheus_async.aio import time

DB_NAME = 'woodroof'
DB_USER = 'woodroof'
DB_PASSWORD = ''
DB_HOST = 'localhost'
DB_PORT = 5432

PORT = 8000
PROMETHEUS_CLIENT_PORT = 9001

OP_TIME_BUCKETS = (0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10)
LONG_TIME_BUCKETS = (0.001, 0.01, 0.1, 1, 10, 1*60, 2*60, 5*60, 10*60, 30*60, 1*60*60, 2*60*60, 5*60*60, 10*60*60, 24*60*60)

CONNECT_TIME = Histogram('connect_time_seconds', 'Time spent creating new connection in database', buckets=OP_TIME_BUCKETS)
RECONNECT_TIME = Histogram('reconnect_time_seconds', 'Time spent renewing connection in database', buckets=OP_TIME_BUCKETS)
DISCONNECT_TIME = Histogram('disconnect_time_seconds', 'Time spent deleting connection from database', buckets=OP_TIME_BUCKETS)

MESSAGE_PROCESSING_TIME = Histogram('message_processing_time_seconds', 'Time spent processing one message', buckets=OP_TIME_BUCKETS)
NOTIFICATION_PROCESSING_TIME = Histogram('notification_processing_time_seconds', 'Time spent processing one database notification', buckets=OP_TIME_BUCKETS)

CONNECTION_TIME = Histogram('connection_time_seconds', 'Connection lifetime', buckets=LONG_TIME_BUCKETS)

async def init_socket(socket, request):
    await socket.prepare(request)

@time(CONNECT_TIME)
async def connect(connection, client_id, connection_object, request):
    print('Connected: %s' % client_id)
    await connection.execute('select api.add_connection($1)', client_id)
    ws = web.WebSocketResponse()
    connection_object['ws'] = ws
    await init_socket(ws, request)
    return ws

@time(RECONNECT_TIME)
async def reconnect(connection, client_id, connection_object, request):
    print('Reconnected: %s' % client_id)
    await connection_object['ws'].close()
    await connection.execute('select api.recreate_connection($1)', client_id)
    ws = web.WebSocketResponse()
    connection_object['ws'] = ws
    await init_socket(ws, request)
    return ws

@time(DISCONNECT_TIME)
async def disconnect(connection, client_id):
    print('Disconnected: %s' % client_id)
    await connection.execute('select api.remove_connection($1)', client_id)

@time(MESSAGE_PROCESSING_TIME)
async def process_message(connection, client_id, data):
    await connection.execute('select api.api($1, $2)', client_id, data)

@time(NOTIFICATION_PROCESSING_TIME)
async def process_notification(connection, notification_id):
    return await connection.fetchval('select api.get_notification($1)', notification_id)

@atomic
@time(CONNECTION_TIME)
async def api(request):
    client_id = request.match_info.get('client_id')

    connections = request.app.connections
    pool = request.app.db_pool

    async with pool.acquire() as connection:
        if client_id in connections:
            connection_object = connections[client_id]
            async with connection_object['lock']:
                ws = await reconnect(connection, client_id, connection_object, request)
        else:
            connection_object = {}
            lock = asyncio.Lock()
            connection_object['lock'] = lock
            connections[client_id] = connection_object
            async with lock:
                ws = await connect(connection, client_id, connection_object, request)

    async for msg in ws:
        if msg.type == WSMsgType.TEXT:
            async with pool.acquire() as connection:
                await process_message(connection, client_id, msg.data)
        elif msg.type == WSMsgType.BINARY:
            print('Received binary message')
        elif msg.type == WSMsgType.ERROR:
            print('Connection closed: %s' % ws.exception())

    async with connection_object['lock']:
        if connection_object['ws'] is ws:
            del connections[client_id]

            async with pool.acquire() as connection:
                await disconnect(connection, client_id)

    return ws

async def post_image(request):
    # TODO
    web.Response(status=200, content_type='application/json', text='{"filename": "1.png"}')

async def get_image(request):
    file_name = request.match_info.get('file_name')
    # TODO
    web.Response(status=200, text=file_name)

async def async_listener(app, notification_id):
    connections = app.connections
    pool = app.db_pool

    async with pool.acquire() as connection:
        result = await process_notification(connection, notification_id)
        client_id = result['client_id']
        if client_id in connections:
            # TODO обработка исключения при закрытии подключения
            await connections[client_id].send_str(result['message'])

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
            web.get('/images/{file_name}', get_image),
            web.post('/images', post_image),
        ])
    app.connections = {}
    app.db_pool = await asyncpg.create_pool(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, database=DB_NAME, init=init_connection)
    async with app.db_pool.acquire() as connection:
        await connection.execute('select api.remove_all_connections()')
    app.listen_connection = await asyncpg.connect(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, database=DB_NAME)
    await app.listen_connection.add_listener('api_channel', listener_creator(app))
    return app

if __name__ == '__main__':
    start_http_server(PROMETHEUS_CLIENT_PORT)
    loop = asyncio.get_event_loop()
    app = loop.run_until_complete(init_app())
    web.run_app(app, port = PORT)