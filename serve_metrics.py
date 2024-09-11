import http.server
import socketserver

PORT = 8000
DIRECTORY = "C:/Scripts/ac/metrics"  # Ensure this is the path to the directory containing the metrics file

class MyHttpRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

handler_object = MyHttpRequestHandler

with socketserver.TCPServer(("", PORT), handler_object) as httpd:
    print(f"Serving HTTP on 0.0.0.0 port {PORT} (http://0.0.0.0:{PORT}/)")
    httpd.serve_forever()