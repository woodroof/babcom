import asyncio

from aiohttp import web
from aiohttp import WSMsgType

PORT = 8000

async def api(request):
    client_id = request.match_info.get('client_id')
    print('Connected: %s' % client_id)

    connections = request.app.connections
    if client_id in connections:
        print('Attempt to connect twice with same client_id: %s' % client_id)
        return web.Response(status=500)

    ws = web.WebSocketResponse()
    connections[client_id] = ws
    await ws.prepare(request)

    async for msg in ws:
        if msg.type == WSMsgType.TEXT:
            # TODO Честно обращаться к базе
            # TODO обработка исключения при закрытии подключения
            await ws.send_str('{"type": "actors", "data": {"actors": []}}')
        elif msg.type == WSMsgType.BINARY:
            print('Received binary message')
        elif msg.type == WSMsgType.ERROR:
            print('Connection closed: %s' % ws.exception())

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

async def init_app():
    app = web.Application()
    app.add_routes(
        [
            web.get('/api/{client_id}', api),
            web.get('/images/{file_name}', get_image),
            web.post('/images', post_image),
        ])
    app.connections = {}
    return app

loop = asyncio.get_event_loop()
app = loop.run_until_complete(init_app())
web.run_app(app, port = PORT)