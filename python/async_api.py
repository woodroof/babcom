import asyncio
import asyncpg

from aiohttp import web

DB_NAME = 'babcom'
DB_USER = 'http'
DB_PASSWORD = 'http'
DB_HOST = 'localhost'
DB_PORT = 5433

PORT = 8000

async def process_post_request(request):
	if request.content_type != 'application/json':
		return web.Response(status=415)

	connection = await asyncpg.connect(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, database=DB_NAME)
	try:
		result = await connection.fetchrow('select * from api.api($1)', await request.text())
	except asyncpg.exceptions.InvalidTextRepresentationError:
		return web.Response(status=400)

	return web.Response(status=result[0], content_type='application/json', text=result[1])

app = web.Application()
app.router.add_post('/', process_post_request)
web.run_app(app, port = PORT)