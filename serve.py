# Serves Ice Player locally, telling the browser never to use a stale cached copy.
import http.server, sys

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

    def log_message(self, *args):
        pass

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
http.server.ThreadingHTTPServer(('', port), NoCacheHandler).serve_forever()
