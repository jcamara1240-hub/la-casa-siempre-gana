#!/usr/bin/env python3
"""Prueba servidor/esquema.sql contra un PostgreSQL de verdad (local y temporal).

Necesita los binarios de PostgreSQL (initdb, pg_ctl, psql). Imita lo mínimo de Supabase:
los roles anon y authenticated. No es Supabase (no hay PostgREST ni su configuración),
pero sí el mismo motor: valida la sintaxis, los permisos y la lógica de las funciones.

    python3 tests/prueba_sql.py

Imprime "ok/MAL" y "FALLOS: N". Si no hay PostgreSQL, lo dice y sale con 0 fallos comprobados.
"""

import datetime
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import servidor_falso as falso  # noqa: E402  (la fórmula y la firma de referencia)

ESQUEMA = os.path.join(AQUI, "..", "servidor", "esquema.sql")
fallos = 0


def ok(c, que):
    global fallos
    print("ok  " if c else "MAL ", que)
    if not c:
        fallos += 1


def binario(nombre):
    ruta = shutil.which(nombre)
    if ruta:
        return ruta
    candidatos = sorted(glob.glob("/usr/lib/postgresql/*/bin/" + nombre))
    return candidatos[-1] if candidatos else None


def main():
    initdb, pg_ctl, psql = binario("initdb"), binario("pg_ctl"), binario("psql")
    if not (initdb and pg_ctl and psql):
        print("No hay PostgreSQL instalado: no se ha podido validar el SQL.")
        print("FALLOS: 0")
        return 0
    carpeta = tempfile.mkdtemp(prefix="prueba_sql_")
    os.chmod(carpeta, 0o777)
    datos = os.path.join(carpeta, "datos")
    # initdb no se deja ejecutar como root: se usa "nobody".
    como = ["runuser", "-u", "nobody", "--"] if os.geteuid() == 0 else []
    puerto = "54329"
    try:
        subprocess.run(como + [initdb, "-D", datos, "-U", "postgres", "-E", "UTF8", "--locale=C.UTF-8", "-A", "trust"],
                       check=True, capture_output=True)
        subprocess.run(como + [pg_ctl, "-D", datos, "-l", os.path.join(carpeta, "log"), "-w", "-o",
                               "-p %s -k %s -c listen_addresses=''" % (puerto, carpeta), "start"],
                       check=True, capture_output=True)

        def sql(orden, rol=None, fallar=True):
            if rol:
                orden = "set role %s;\n%s" % (rol, orden)
            r = subprocess.run([psql, "-h", carpeta, "-p", puerto, "-U", "postgres", "-d", "postgres", "-X", "-q",
                                "-t", "-A", "-v", "ON_ERROR_STOP=1", "-c", orden], capture_output=True, text=True)
            if fallar and r.returncode != 0:
                raise RuntimeError(r.stderr)
            return r

        def rpc(funcion, **args):
            # Como lo llama PostgREST: con el rol anon y argumentos por nombre.
            lista = ", ".join("%s => %s" % (k, literal(v)) for k, v in args.items())
            r = sql("select public.%s(%s);" % (funcion, lista), rol="anon")
            return json.loads(r.stdout.strip().splitlines()[-1])

        # Lo que Supabase ya trae: los roles de la API.
        sql("create role anon nologin; create role authenticated nologin; grant usage on schema public to anon, authenticated;")
        r = subprocess.run([psql, "-h", carpeta, "-p", puerto, "-U", "postgres", "-d", "postgres", "-X", "-q",
                            "-v", "ON_ERROR_STOP=1", "-f", ESQUEMA], capture_output=True, text=True)
        ok(r.returncode == 0, "el esquema se carga en PostgreSQL sin errores " + ("" if r.returncode == 0 else r.stderr.strip()[:300]))
        r = subprocess.run([psql, "-h", carpeta, "-p", puerto, "-U", "postgres", "-d", "postgres", "-X", "-q",
                            "-v", "ON_ERROR_STOP=1", "-f", ESQUEMA], capture_output=True, text=True)
        ok(r.returncode == 0, "y se puede volver a ejecutar encima " + ("" if r.returncode == 0 else r.stderr.strip()[:300]))

        # Nadie lee ni escribe las tablas a pelo con la clave anónima.
        for tabla in ["public.jugadores", "public.puntuaciones", "public.versiones", "privado.ajustes"]:
            r = sql("select * from %s;" % tabla, rol="anon", fallar=False)
            ok(r.returncode != 0 and "permission denied" in r.stderr, "anon no puede leer " + tabla)
        r = sql("insert into public.puntuaciones (jugador_id, fecha, modo, puntos, piso, pisos, gano, tiempo_seg, bajas, "
                "monedas, golpes, version) values (gen_random_uuid(), current_date, 'diario', 1, 1, 0, false, 1, 0, 0, 0, '1.7');",
                rol="anon", fallar=False)
        ok(r.returncode != 0, "anon no puede insertar puntuaciones directamente")
        r = sql("select privado.calcular_puntos(1, false, 1, 1, 1, 1);", rol="anon", fallar=False)
        ok(r.returncode != 0, "anon no puede llamar a las funciones privadas")

        # La fórmula del servidor es la del juego (la del servidor falso es copia de Juego.calcular_puntos).
        casos = [(0, False, 40, 0, 0, 0), (2, False, 300, 140, 90, 3), (5, True, 900, 600, 400, 2),
                 (5, True, 2000, 50, 10, 1), (0, False, 10, 0, 0, 40)]
        iguales = all(int(sql("select privado.calcular_puntos(%d, %s, %d, %d, %d, %d);" % c).stdout.strip())
                      == falso.calcular_puntos(*c) for c in casos)
        ok(iguales, "la fórmula de puntos del SQL coincide con la del juego")

        # Cuentas y nombres.
        a = rpc("registrar", p_dispositivo="a" * 32)
        b = rpc("registrar", p_dispositivo="b" * 32)
        ok(a["ok"] and len(a["token"]) == 64 and a["nombre"] is None, "registrar da token")
        ok(not rpc("registrar", p_dispositivo="corto")["ok"], "un dispositivo raro no se registra")
        a2 = rpc("registrar", p_dispositivo="a" * 32)
        ok(a2["jugador"] == a["jugador"] and a2["token"] != a["token"], "registrar otra vez da token nuevo a la misma cuenta")
        ok(rpc("poner_nombre", p_token=a["token"], p_nombre="x")["error"] == "token", "el token viejo deja de valer")
        a = a2
        ok(rpc("poner_nombre", p_token=a["token"], p_nombre="tahur-1") == {"ok": True, "nombre": "TAHUR-1"}, "pone nombre (en mayúsculas)")
        ok(rpc("poner_nombre", p_token=b["token"], p_nombre="TAHUR-1")["error"] == "nombre_ocupado", "nombre único")
        ok(rpc("poner_nombre", p_token=b["token"], p_nombre="P4T0-PUT4")["error"] == "nombre_feo", "filtro de insultos con leet")
        ok(rpc("poner_nombre", p_token=b["token"], p_nombre="HOLA_MUNDO")["error"] == "nombre_invalido", "caracteres raros fuera")
        ok(rpc("poner_nombre", p_token=b["token"], p_nombre="AB")["error"] == "nombre_corto", "mínimo 3")
        ok(rpc("poner_nombre", p_token=b["token"], p_nombre="A" * 17)["error"] == "nombre_largo", "máximo 16")
        ok(rpc("poner_nombre", p_token=b["token"], p_nombre="CRUPIER")["ok"], "otro nombre libre")

        # Puntuaciones, con secreto.
        secreto = "secreto-de-prueba"
        sql("insert into privado.ajustes values ('secreto_hmac', '%s') on conflict (clave) do update set valor = excluded.valor;" % secreto)
        hoy = datetime.datetime.now(datetime.timezone.utc).date().isoformat()

        def envio(token, puntos=None, firma=None, **cambios):
            e = dict(fecha=hoy, modo="diario", piso=3, pisos=2, gano=False, tiempo=600, bajas=300, monedas=120, golpes=4,
                     version="1.7")
            e.update(cambios)
            if puntos is None:
                puntos = falso.calcular_puntos(e["pisos"], e["gano"], e["tiempo"], e["bajas"], e["monedas"], e["golpes"])
            if firma is None:
                firma = falso.firmar(secreto, falso.texto_firma(token, e["fecha"], e["modo"], puntos, e["piso"], e["pisos"],
                                                                 e["gano"], e["tiempo"], e["bajas"], e["monedas"],
                                                                 e["golpes"], e["version"]))
            return rpc("enviar_puntuacion", p_token=token, p_fecha=e["fecha"], p_modo=e["modo"], p_puntos=puntos,
                       p_piso=e["piso"], p_pisos=e["pisos"], p_gano=e["gano"], p_tiempo=e["tiempo"], p_bajas=e["bajas"],
                       p_monedas=e["monedas"], p_golpes=e["golpes"], p_version=e["version"], p_firma=firma)

        ok(envio(a["token"], firma="00" * 32)["error"] == "firma", "firma mala: fuera")
        ok(envio(a["token"], puntos=99999)["error"] in ("puntos", "firma"), "puntos que no salen de la fórmula: fuera")
        ok(envio(a["token"], version="0.1")["error"] == "version", "versión no activa: fuera")
        ayer = (datetime.date.fromisoformat(hoy) - datetime.timedelta(days=2)).isoformat()
        ok(envio(a["token"], fecha=ayer)["error"] == "fuera_de_plazo", "fecha vieja: fuera")
        ok(envio(a["token"], tiempo=5)["error"] == "implausible", "tiempo imposible: fuera")
        ok(envio(a["token"], gano=True, piso=3, pisos=5)["error"] == "implausible", "ganar sin llegar al piso 5: fuera")
        ok(envio("nada")["error"] == "token", "sin cuenta: fuera")
        ok(envio(a["token"]) == {"ok": True}, "envío bueno aceptado")
        ok(envio(a["token"], bajas=900).get("repetido"), "solo una por jugador y día")
        ok(envio(b["token"], piso=5, pisos=5, gano=True, tiempo=1200, golpes=0) == {"ok": True}, "otro jugador gana")
        c = rpc("registrar", p_dispositivo="c" * 32)
        ok(envio(c["token"], piso=1, pisos=0, tiempo=60, bajas=20, monedas=5, golpes=1) == {"ok": True}, "sin nombre también se guarda")

        t = rpc("tabla_diaria", p_fecha=hoy, p_token=a["token"])
        ok(t["ok"] and t["total"] == 2 and [f["nombre"] for f in t["top"]] == ["CRUPIER", "TAHUR-1"], "la tabla ordena y oculta a quien no tiene nombre")
        ok(t["yo"] and t["yo"]["pos"] == 2 and t["top"][1]["yo"] and not t["top"][0]["yo"], "tu fila viene marcada")
        t = rpc("tabla_diaria", p_fecha=hoy)
        ok(t["yo"] is None and t["top"][0]["yo"] is False, "sin token no hay fila tuya")
        t = rpc("tabla_diaria", p_fecha=ayer, p_token=a["token"])
        ok(t["total"] == 0 and t["top"] == [] and t["yo"] is None, "un día sin puntuaciones da tabla vacía")
        h = rpc("tabla_historica", p_token=b["token"])
        ok(h["ok"] and h["top"][0]["nombre"] == "CRUPIER" and h["top"][0]["fecha"] == hoy and h["yo"]["pos"] == 1, "histórico")
        ok(rpc("borrar_cuenta", p_token=a["token"])["ok"] and rpc("tabla_diaria", p_fecha=hoy)["total"] == 1, "borrar cuenta borra sus puntuaciones")

        # Sin secreto configurado no se mira la firma.
        sql("delete from privado.ajustes where clave = 'secreto_hmac';")
        d = rpc("registrar", p_dispositivo="d" * 32)
        ok(envio(d["token"], firma="") == {"ok": True}, "sin secreto en el servidor, la firma no se exige")
    finally:
        subprocess.run(como + [pg_ctl, "-D", datos, "-m", "immediate", "stop"], capture_output=True)
        shutil.rmtree(carpeta, ignore_errors=True)
    print("FALLOS:", fallos)
    return 1 if fallos else 0


def literal(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    return "'" + str(v).replace("'", "''") + "'"


if __name__ == "__main__":
    sys.exit(main())
