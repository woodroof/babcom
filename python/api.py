import http.server
import socketserver
import json
import psycopg2
import psycopg2.extras

DB_NAME = 'babcom'
DB_USER = 'http'
DB_PASSWORD = 'http'
DB_HOST = 'localhost'
DB_PORT = 5433

PORT = 8000

class HttpRequestHandler(http.server.BaseHTTPRequestHandler):
	def error(self):
		self.send_response(400)
		self.send_header('Content-Length', 0)
		self.end_headers()

	def do_HEAD(self):
		self.error()

	def do_GET(self):
		self.error()

	def do_POST(self):
		content_length = int(self.headers.get('Content-Length'))
		request_data = self.rfile.read(content_length)
		try:
			request = json.loads(request_data.decode())
		except json.JSONDecodeError:
			self.error()
			return

		cursor = connection.cursor()
		cursor.execute("select api.api(%s);", (psycopg2.extras.Json(request),))
		result = cursor.fetchone()

		data = json.dumps(result[0]).encode()

		self.send_response(200)
		self.send_header('Content-Type', 'application/json')
		self.send_header('Content-Length', len(data))
		self.end_headers()
		self.wfile.write(data)

if __name__ == "__main__":
	connection = psycopg2.connect(database=DB_NAME, user=DB_USER, password=DB_PASSWORD, host=DB_HOST, port=DB_PORT)
	connection.autocommit = True

	handler = HttpRequestHandler
	handler.protocol_version='HTTP/1.1'
	httpd = socketserver.TCPServer(("", PORT), handler)
	httpd.serve_forever()
