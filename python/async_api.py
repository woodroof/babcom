import asyncio
import asyncpg
import collections

from aiohttp import web

DB_NAME = 'test'
DB_USER = 'woodroof'
DB_PASSWORD = ''
DB_HOST = 'localhost'
DB_PORT = 5432

PORT = 8000

async def process_post_request(request):
	if request.content_type != 'application/json':
		return web.Response(status=415)

	pool = request.app['pool']

	async with pool.acquire() as connection:
		try:
			result = await connection.fetchrow('select * from api.api($1)', await request.text())
		except asyncpg.exceptions.InvalidTextRepresentationError:
			return web.Response(status=400)

		return web.Response(status=result[0], content_type='application/json', text=result[1], headers={'Access-Control-Allow-Origin': '*'})

async def process_options_request(request):
	return web.Response(status=200, headers={'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*'})

async def init_app():
	app = web.Application()
	app['pool'] = await asyncpg.create_pool(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, database=DB_NAME)
	app.router.add_post('/', process_post_request)
	app.router.add_options('/', process_options_request)
	return app

loop = asyncio.get_event_loop()
app = loop.run_until_complete(init_app())
web.run_app(app, port = PORT)
