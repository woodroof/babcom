import asyncio
import asyncpg
import json

from aiohttp import web
from aiohttp import WSMsgType

DB_NAME = 'woodroof'
DB_USER = 'woodroof'
DB_PASSWORD = ''
DB_HOST = 'localhost'
DB_PORT = 5432

PORT = 8000

async def api(request):
    client_id = request.match_info.get('client_id')
    print('Connected: %s' % client_id)

    connections = request.app.connections
    pool = request.app.db_pool

    if client_id in connections:
        print('Attempt to connect twice with same client_id: %s' % client_id)
        return web.Response(status=500)

    ws = web.WebSocketResponse()
    connections[client_id] = ws
    await ws.prepare(request)

    async with pool.acquire() as connection:
        await connection.execute('select api.add_connection($1)', client_id)

    async for msg in ws:
        if msg.type == WSMsgType.TEXT:
            async with pool.acquire() as connection:
                await connection.execute('select api.api($1, $2)', client_id, msg.data)
        elif msg.type == WSMsgType.BINARY:
            print('Received binary message')
        elif msg.type == WSMsgType.ERROR:
            print('Connection closed: %s' % ws.exception())

    async with pool.acquire() as connection:
        await connection.execute('select api.remove_connection($1)', client_id)

    print ('Disconnected: %s' % client_id)
    del connections[client_id]

    return ws

async def post_image(request):
    # TODO
    web.Response(status=200, content_type='application/json', text='{"filename": "1.png"}')

async def get_image(request):
    file_name = request.match_info.get('file_name')
    # TODO
    web.Response(status=200, text=file_name)

async def async_listener(app, payload):
    connections = app.connections
    pool = app.db_pool

    async with pool.acquire() as connection:
        result = await connection.fetchval('select api.get_notification($1)', payload)
        client_id = result['client_id']
        if client_id in connections:
            # TODO обработка исключения при закрытии подключения
            await connections[client_id].send_str(result['message'])

def listener_creator(app):
    def listener(connection, pid, channel, payload):
        asyncio.get_event_loop().create_task(async_listener(app, payload))
    return listener

def jsonb_encoder(value):
    return b'\x01' + json.dumps(value).encode('utf-8')

def jsonb_decoder(value):
    return json.loads(value[1:].decode('utf-8'))

async def init_connection(conn):
    await conn.set_type_codec('jsonb', encoder=jsonb_encoder, decoder=jsonb_decoder, schema='pg_catalog', format='binary')

async def init_app():
    app = web.Application()
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

loop = asyncio.get_event_loop()
app = loop.run_until_complete(init_app())
web.run_app(app, port = PORT)