"""Imita lo justo de la API REST de Firestore para probar la clasificación sin red."""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

dias = {}


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_POST(self):
        cuerpo = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        ruta = self.path.split("?")[0]
        fecha = ruta.split("/dias/")[1].split("/")[0].split(":")[0]
        if ruta.endswith(":runQuery"):
            filas = sorted(dias.get(fecha, []), key=lambda d: -int(d["puntos"]["integerValue"]))[:10]
            respuesta = [{"document": {"fields": f}} for f in filas] or [{"readTime": "x"}]
        else:
            dias.setdefault(fecha, []).append(cuerpo["fields"])
            respuesta = {"name": "x"}
        datos = json.dumps(respuesta).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(datos)))
        self.end_headers()
        self.wfile.write(datos)


HTTPServer(("127.0.0.1", 9811), H).serve_forever()
