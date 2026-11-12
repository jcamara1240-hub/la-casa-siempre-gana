#!/usr/bin/env python3
"""Servidor falso de la tabla mundial, para pruebas sin Supabase.

Imita las rutas que usa scripts/online.gd (POST /rest/v1/rpc/<función>) con la misma
lógica que servidor/esquema.sql, pero en memoria. Solo biblioteca estándar.

    python3 tests/servidor_falso.py --puerto 8765 --clave clave-falsa --secreto secreto-falso

Escribe "LISTO <puerto>" cuando ya escucha. Rutas extra para las pruebas:
    GET /__estado  -> {"jugadores": n, "puntuaciones": n, "peticiones": n}
"""

import argparse
import datetime
import hashlib
import hmac
import json
import re
import secrets
import sys
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# La misma lista que scripts/online.gd y servidor/esquema.sql.
PALABRAS_FEAS = ["puta", "puto", "mierda", "cabron", "gilipollas", "maricon", "marica", "polla",
                 "zorra", "joder", "follar", "subnormal", "retrasado", "pendejo", "culero", "verga", "chinga", "nazi",
                 "hitler", "fuck", "shit", "bitch", "cunt", "nigger", "nigga", "faggot", "whore", "slut", "asshole",
                 "retard", "rape", "penis", "admin"]


def huella(texto):
    return hashlib.sha256(texto.encode()).hexdigest()


def calcular_puntos(pisos, gano, tiempo, bajas, monedas, golpes):
    """Igual que Juego.calcular_puntos y privado.calcular_puntos."""
    total = pisos * 1000 + bajas * 2 + monedas * 1 - golpes * 100
    if gano:
        total += 5000 + max(1500 - tiempo, 0) * 3
    return max(total, 0)


def nombre_feo(nombre):
    plano = nombre.lower()
    for a, b in [("ñ", "n"), ("0", "o"), ("1", "i"), ("3", "e"), ("4", "a"), ("5", "s"), ("7", "t"), ("8", "b"), ("-", "")]:
        plano = plano.replace(a, b)
    return any(p in plano for p in PALABRAS_FEAS)


def texto_firma(token, fecha, modo, puntos, piso, pisos, gano, tiempo, bajas, monedas, golpes, version):
    """Igual que Online.texto_firma y el concat_ws de enviar_puntuacion."""
    return "|".join(str(x) for x in [token, fecha, modo, puntos, piso, pisos, 1 if gano else 0, tiempo, bajas,
                                      monedas, golpes, version])


def firmar(secreto, texto):
    return hmac.new(secreto.encode(), texto.encode(), hashlib.sha256).hexdigest()


class Estado:
    def __init__(self, clave, secreto, versiones):
        self.clave = clave
        self.secreto = secreto
        self.versiones = set(versiones)
        self.jugadores = {}  # id -> dict
        self.puntuaciones = []  # dicts
        self.peticiones = 0
        self.cerrojo = threading.Lock()

    def jugador_de(self, token):
        if not token:
            return None
        h = huella(token)
        for j in self.jugadores.values():
            if j["token_hash"] == h:
                return j
        return None

    # ---------------------------------------------------------------- RPC
    def registrar(self, a):
        disp = a.get("p_dispositivo") or ""
        if not (16 <= len(disp) <= 128):
            return {"ok": False, "error": "invalido"}
        token = secrets.token_hex(32)
        h = huella(disp)
        for j in self.jugadores.values():
            if j["dispositivo_hash"] == h:
                j["token_hash"] = huella(token)
                return {"ok": True, "jugador": j["id"], "token": token, "nombre": j["nombre"]}
        j = {"id": str(uuid.uuid4()), "dispositivo_hash": h, "token_hash": huella(token), "nombre": None}
        self.jugadores[j["id"]] = j
        return {"ok": True, "jugador": j["id"], "token": token, "nombre": None}

    def poner_nombre(self, a):
        j = self.jugador_de(a.get("p_token"))
        if j is None:
            return {"ok": False, "error": "token"}
        n = (a.get("p_nombre") or "").strip().upper()
        if len(n) < 3:
            return {"ok": False, "error": "nombre_corto"}
        if len(n) > 16:
            return {"ok": False, "error": "nombre_largo"}
        if not re.fullmatch(r"[A-Z0-9Ñ-]+", n):
            return {"ok": False, "error": "nombre_invalido"}
        if nombre_feo(n):
            return {"ok": False, "error": "nombre_feo"}
        if any(o["nombre"] == n and o is not j for o in self.jugadores.values()):
            return {"ok": False, "error": "nombre_ocupado"}
        j["nombre"] = n
        return {"ok": True, "nombre": n}

    def enviar_puntuacion(self, a):
        j = self.jugador_de(a.get("p_token"))
        if j is None:
            return {"ok": False, "error": "token"}
        if a.get("p_version") not in self.versiones:
            return {"ok": False, "error": "version"}
        if a.get("p_modo") != "diario" or not a.get("p_fecha"):
            return {"ok": False, "error": "invalido"}
        ahora = datetime.datetime.now(datetime.timezone.utc)
        hoy = ahora.date()
        try:
            fecha = datetime.date.fromisoformat(a["p_fecha"])
        except ValueError:
            return {"ok": False, "error": "invalido"}
        if not (fecha == hoy or (fecha == hoy - datetime.timedelta(days=1) and ahora.hour < 3)):
            return {"ok": False, "error": "fuera_de_plazo"}
        try:
            piso, pisos, gano = int(a["p_piso"]), int(a["p_pisos"]), bool(a["p_gano"])
            tiempo, bajas, monedas, golpes = int(a["p_tiempo"]), int(a["p_bajas"]), int(a["p_monedas"]), int(a["p_golpes"])
            puntos = int(a["p_puntos"])
        except (KeyError, TypeError, ValueError):
            return {"ok": False, "error": "implausible"}
        if (not 1 <= piso <= 5 or pisos != (5 if gano else piso - 1) or (gano and piso != 5)
                or not 30 * pisos <= tiempo <= 21600 or not 0 <= bajas <= 1500 * (pisos + 1)
                or not 0 <= monedas <= 2000 * (pisos + 1) or not 0 <= golpes <= 200):
            return {"ok": False, "error": "implausible"}
        if puntos != calcular_puntos(pisos, gano, tiempo, bajas, monedas, golpes):
            return {"ok": False, "error": "puntos"}
        if self.secreto:
            texto = texto_firma(a["p_token"], a["p_fecha"], a["p_modo"], puntos, piso, pisos, gano, tiempo, bajas,
                                monedas, golpes, a["p_version"])
            if not hmac.compare_digest(a.get("p_firma") or "", firmar(self.secreto, texto)):
                return {"ok": False, "error": "firma"}
        for p in self.puntuaciones:
            if p["jugador"] == j["id"] and p["fecha"] == a["p_fecha"] and p["modo"] == "diario":
                return {"ok": True, "repetido": True}
        self.puntuaciones.append({"jugador": j["id"], "fecha": a["p_fecha"], "modo": "diario", "puntos": puntos,
                                  "piso": piso, "tiempo": tiempo, "orden": len(self.puntuaciones)})
        return {"ok": True}

    def _tabla(self, filas, yo_id, limite, con_fecha=False):
        filas = [f for f in filas if self.jugadores.get(f["jugador"], {}).get("nombre")]
        filas.sort(key=lambda f: (-f["puntos"], f["tiempo"], f["orden"]))
        salida = []
        pos = 0
        anterior = None
        for i, f in enumerate(filas):
            clave = (f["puntos"], f["tiempo"])
            if clave != anterior:
                pos = i + 1
                anterior = clave
            fila = {"pos": pos, "nombre": self.jugadores[f["jugador"]]["nombre"], "puntos": f["puntos"],
                    "piso": f["piso"], "tiempo": f["tiempo"], "yo": f["jugador"] == yo_id}
            if con_fecha:
                fila["fecha"] = f["fecha"]
            salida.append(fila)
        limite = max(1, min(int(limite or 50), 100))
        yo = next((dict(f, yo=True) for f in salida if f["yo"]), None)
        return {"ok": True, "total": len(salida), "top": salida[:limite], "yo": yo}

    def tabla_diaria(self, a):
        j = self.jugador_de(a.get("p_token"))
        filas = [p for p in self.puntuaciones if p["fecha"] == a.get("p_fecha") and p["modo"] == a.get("p_modo", "diario")]
        datos = self._tabla(filas, j["id"] if j else None, a.get("p_limite", 50))
        datos["fecha"] = a.get("p_fecha")
        return datos

    def tabla_historica(self, a):
        j = self.jugador_de(a.get("p_token"))
        mejores = {}
        for p in self.puntuaciones:
            m = mejores.get(p["jugador"])
            if m is None or (-p["puntos"], p["tiempo"], p["orden"]) < (-m["puntos"], m["tiempo"], m["orden"]):
                mejores[p["jugador"]] = p
        return self._tabla(list(mejores.values()), j["id"] if j else None, a.get("p_limite", 50), True)

    def borrar_cuenta(self, a):
        j = self.jugador_de(a.get("p_token"))
        if j is not None:
            del self.jugadores[j["id"]]
            self.puntuaciones = [p for p in self.puntuaciones if p["jugador"] != j["id"]]
        return {"ok": True}


FUNCIONES = ["registrar", "poner_nombre", "enviar_puntuacion", "tabla_diaria", "tabla_historica", "borrar_cuenta"]


def hacer_manejador(estado):
    class Manejador(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def _responder(self, codigo, datos):
            cuerpo = json.dumps(datos).encode()
            self.send_response(codigo)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(cuerpo)))
            # Como Supabase: CORS abierto, para que funcione desde la versión web.
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(cuerpo)

        def do_OPTIONS(self):
            self.send_response(204)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "apikey, authorization, content-type")
            self.end_headers()

        def do_GET(self):
            if self.path == "/__estado":
                with estado.cerrojo:
                    self._responder(200, {"jugadores": len(estado.jugadores), "puntuaciones": len(estado.puntuaciones),
                                          "peticiones": estado.peticiones})
                return
            self._responder(404, {"message": "no existe"})

        def do_POST(self):
            with estado.cerrojo:
                estado.peticiones += 1
            prefijo = "/rest/v1/rpc/"
            if not self.path.startswith(prefijo) or self.path[len(prefijo):] not in FUNCIONES:
                self._responder(404, {"code": "PGRST202", "message": "Could not find the function"})
                return
            autorizacion = self.headers.get("Authorization")
            if self.headers.get("apikey") != estado.clave or (autorizacion and autorizacion != "Bearer " + estado.clave):
                self._responder(401, {"message": "Invalid API key"})
                return
            largo = int(self.headers.get("Content-Length") or 0)
            try:
                args = json.loads(self.rfile.read(largo) or b"{}")
            except json.JSONDecodeError:
                self._responder(400, {"message": "JSON roto"})
                return
            with estado.cerrojo:
                datos = getattr(estado, self.path[len(prefijo):])(args)
            self._responder(200, datos)

    return Manejador


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--puerto", type=int, default=8765)
    p.add_argument("--clave", default="clave-falsa")
    p.add_argument("--secreto", default="secreto-falso")
    p.add_argument("--versiones", default="1.7", help="separadas por comas")
    a = p.parse_args()
    estado = Estado(a.clave, a.secreto, a.versiones.split(","))
    servidor = ThreadingHTTPServer(("127.0.0.1", a.puerto), hacer_manejador(estado))
    print("LISTO", servidor.server_address[1], flush=True)
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    sys.exit(main())
