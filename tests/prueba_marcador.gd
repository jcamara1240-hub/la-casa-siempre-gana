extends SceneTree
## Habla con un servidor falso que imita a Firestore (tests/firestore_falso.py).

var _fallos := 0


func _initialize() -> void:
	_correr.call_deferred()


func _ok(c: bool, que: String) -> void:
	print("ok  " if c else "MAL ", que)
	if not c:
		_fallos += 1


func _correr() -> void:
	var J: Node = root.get_node("Juego")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	var marcador = m._marcador
	marcador.base = "http://127.0.0.1:9811/v1"
	marcador.proyecto = "prueba"
	marcador.clave = "k"
	marcador.enviar("2026-11-08", "JAIME", 1200)
	await marcador.puntuacion_enviada
	marcador.enviar("2026-11-08", "ANA", 3400)
	var envio = await marcador.puntuacion_enviada
	_ok(envio, "las puntuaciones se envían")
	marcador.pedir_top("2026-11-08")
	var r: Array = await marcador.top_recibido
	_ok(r[1] and r[0].size() == 2 and r[0][0].nombre == "ANA" and r[0][0].puntos == 3400, "la clasificación llega ordenada: %s" % [r[0]])
	marcador.pedir_top("2000-01-01")
	r = await marcador.top_recibido
	_ok(r[1] and r[0].is_empty(), "un día sin partidas da lista vacía")
	marcador.base = "http://127.0.0.1:9/v1"
	marcador.pedir_top("2026-11-08")
	r = await marcador.top_recibido
	_ok(not r[1], "sin conexión avisa del error en vez de colgarse")
	marcador.base = "http://127.0.0.1:9811/v1"

	m._menu.cerrar()
	var reto = m._reto
	reto.abrir(5000)
	reto._nombre = [9, 0, 8, 12, 4, 36]  # "JAIME "
	reto._pendiente_envio = 5000
	reto._accion_principal()
	await marcador.puntuacion_enviada
	await marcador.top_recibido
	await process_frame
	_ok(reto._estado == "lista" and reto._filas[0].puntos == 5000 and reto._filas[0].nombre == "JAIME", "la pantalla envía y muestra la tabla")
	print("FALLOS: ", _fallos, " ", J.fecha_hoy())
	quit(1 if _fallos > 0 else 0)
