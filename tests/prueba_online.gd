extends SceneTree
## La tabla mundial contra tests/servidor_falso.py en localhost (no hay Supabase en las pruebas),
## y el modo "sin configurar": nada visible y ni una petición.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_online.gd

const CUENTA_PRUEBA := "user://cuenta_prueba.cfg"
const CLAVE := "clave-falsa"
const SECRETO := "secreto-falso"

var _fallos := 0
var J: Node
var _pid := -1
var _puerto := 0
var _avisos: Array = []  # lo que van emitiendo las señales del Online


func _initialize() -> void:
	_correr.call_deferred()


func _ok(c: bool, que: String) -> void:
	print("ok  " if c else "MAL ", que)
	if not c:
		_fallos += 1


func _correr() -> void:
	J = root.get_node("Juego")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CUENTA_PRUEBA))
	await comprobar_sin_configurar()
	if await _arrancar_servidor():
		await comprobar_cuenta_y_envio()
		await comprobar_pantalla()
	else:
		_ok(false, "arranca el servidor falso (¿hay python3?)")
	if _pid > 0:
		OS.kill(_pid)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CUENTA_PRUEBA))
	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)


func _nuevo_online(url := "", clave := "", secreto := ""):
	var o = load("res://scripts/online.gd").new()
	o.rutas_config = ["user://no_existe_online.cfg"]
	o.ruta_cuenta = CUENTA_PRUEBA
	root.add_child(o)
	if url != "":
		o.configurar(url, clave, secreto)
	o.tabla_lista.connect(func(d): _avisos.append(["tabla", d]))
	o.tabla_fallida.connect(func(t, m): _avisos.append(["fallo", t, m]))
	o.nombre_resultado.connect(func(ok, e): _avisos.append(["nombre", ok, e]))
	o.envio_terminado.connect(func(ok, e): _avisos.append(["envio", ok, e]))
	return o


## Espera (como mucho 5 s de reloj) a que llegue un aviso de ese tipo y lo devuelve.
func _esperar(tipo: String) -> Array:
	var limite := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < limite:
		for i in _avisos.size():
			if _avisos[i][0] == tipo:
				return _avisos.pop_at(i)
		await _fotograma()
	return []


## Un fotograma y un respiro de reloj: con --fixed-fps los fotogramas pasan sin esperar a la red.
func _fotograma() -> void:
	OS.delay_msec(5)
	await process_frame


## Espera hasta que se cumpla la condición (como mucho 5 s de reloj).
func _hasta(condicion: Callable) -> void:
	var limite := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < limite and not condicion.call():
		await _fotograma()


func comprobar_sin_configurar() -> void:
	var o = _nuevo_online()
	await process_frame
	_ok(not o.activo, "sin online.cfg queda apagado")
	o.elegir_nombre("ALGUIEN")
	o.enviar_reto({"fecha": "2026-01-01", "modo": "diario", "puntos": 1, "piso": 1, "pisos": 0, "gano": false,
			"tiempo": 60, "bajas": 0, "monedas": 1, "golpes": 0})
	o.pedir_tabla("2026-01-01")
	o.pedir_historico()
	await process_frame
	_ok(o.peticiones_hechas == 0 and o.pendientes() == 0, "apagado no hace ninguna petición ni guarda cola")
	_ok(not FileAccess.file_exists(CUENTA_PRUEBA), "ni crea cuenta")
	o.configurar("", CLAVE)
	_ok(not o.activo, "sin URL sigue apagado")
	o.configurar("http://127.0.0.1:1", "")
	_ok(not o.activo, "sin clave sigue apagado")
	_ok(_avisos.size() == 1 and _avisos[0] == ["nombre", false, "apagado"], "apagado, elegir nombre contesta sin red")
	_avisos.clear()
	o.queue_free()

	# El juego entero, tal cual, sin online.cfg: ni pestaña ni peticiones aunque juegues el reto.
	var hay_cfg := FileAccess.file_exists("user://online.cfg") or FileAccess.file_exists("res://online.cfg")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._menu.cerrar()
	if hay_cfg:
		print("aviso: hay un online.cfg de verdad; se salta la parte del juego sin configurar")
	else:
		var empezado: String = Progreso.reto_empezado
		m._reto.abrir()
		await process_frame
		_ok(not m._reto.hay_mundial(), "el juego sin configurar no enseña la pestaña MUNDIAL")
		m._reto.tocar(PantallaRetoCajas.MUNDIAL)
		_ok(m._reto._pestana == 0, "tocar donde iría la pestaña no hace nada")
		m._reto.visible = false
		m.empezar_reto()
		m._acabar(false)
		m._pantalla.visible = false
		_ok(m._online.peticiones_hechas == 0 and m._online.pendientes() == 0, "terminar un reto sin configurar no envía nada")
		Progreso.reto_empezado = empezado
		Progreso.guardar()
		load("res://scripts/guardado.gd").borrar()
	m._ir_al_menu()
	m.queue_free()
	await process_frame


func _arrancar_servidor() -> bool:
	var python := "python3"
	var ruta := ProjectSettings.globalize_path("res://tests/servidor_falso.py")
	for intento in 3:
		_puerto = 20000 + randi() % 20000
		_pid = OS.create_process(python, [ruta, "--puerto", str(_puerto), "--clave", CLAVE, "--secreto", SECRETO])
		if _pid <= 0:
			return false
		for _i in 50:
			var http := HTTPRequest.new()
			http.process_mode = Node.PROCESS_MODE_ALWAYS  # el menú deja el árbol en pausa
			root.add_child(http)
			http.request("http://127.0.0.1:%d/__estado" % _puerto)
			var r: Array = await http.request_completed
			http.queue_free()
			if r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200:
				return true
			OS.delay_msec(100)  # con --fixed-fps los fotogramas no esperan: se espera de verdad
		OS.kill(_pid)
	return false


func _url() -> String:
	return "http://127.0.0.1:%d" % _puerto


func _resumen(puntos_extra := 0) -> Dictionary:
	J.fecha_reto = J.fecha_hoy()
	J.piso = 3
	J.tiempo_partida = 500.0
	J.enemigos_eliminados = 200 + puntos_extra
	J.oro_total = 80
	J.golpes = 3
	return J.resumen_reto(false)


func comprobar_cuenta_y_envio() -> void:
	# Sin red (puerto cerrado): la tabla falla con aviso y el envío se queda en cola.
	var o = _nuevo_online("http://127.0.0.1:1", CLAVE, SECRETO)
	await process_frame
	_ok(o.activo and o.dispositivo.length() == 32, "configurado: activo y con id de dispositivo al azar")
	o.pedir_tabla(J.fecha_hoy())
	var f := await _esperar("fallo")
	_ok(f.size() == 3 and f[2] == "sin_conexion", "sin conexión, la tabla avisa y no se cuelga")
	o.enviar_reto(_resumen())
	await _hasta(func(): return not o._enviando)
	_ok(o.pendientes() == 1, "sin conexión, la puntuación queda pendiente")
	o.queue_free()

	# Vuelve la red: al arrancar se recupera la cuenta y la cola, pero sin nombre no sale en la tabla.
	var a = _nuevo_online(_url(), CLAVE, SECRETO)
	_ok(a.pendientes() == 1, "la cola sobrevive a cerrar el juego")
	a._procesar_cola()
	var e := await _esperar("envio")
	_ok(e.size() == 3 and e[1] and a.pendientes() == 0 and a.token != "", "con red, se registra y envía lo pendiente")
	_ok(Online.revisar_nombre("ab") == "nombre_corto" and Online.revisar_nombre("hola_mundo") == "nombre_invalido"
			and Online.revisar_nombre("pUt4-m4dre") == "nombre_feo" and Online.revisar_nombre("tahúr uno") == "",
			"el filtro de nombres del cliente")
	a.elegir_nombre("p0llas")
	var n := await _esperar("nombre")
	_ok(n.size() == 3 and not n[1] and n[2] == "nombre_feo", "un insulto se rechaza sin ir al servidor")
	a.elegir_nombre("tahúr uno")
	n = await _esperar("nombre")
	_ok(n.size() == 3 and n[1] and a.nombre == "TAHUR-UNO", "pone nombre (limpio: mayúsculas, sin tildes)")
	a.enviar_reto(_resumen(50))
	e = await _esperar("envio")
	_ok(e.size() == 3 and e[1] and a.pendientes() == 0, "un segundo envío del mismo día se acepta como repetido y sale de la cola")

	# Otro jugador, mismo nombre: ocupado. Otro nombre y más puntos.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CUENTA_PRUEBA))
	var b = _nuevo_online(_url(), CLAVE, SECRETO)
	_ok(b.dispositivo != a.dispositivo and b.token == "", "otro dispositivo, otra cuenta")
	b.elegir_nombre("TAHUR-UNO")
	n = await _esperar("nombre")
	_ok(n.size() == 3 and not n[1] and n[2] == "nombre_ocupado", "nombre único")
	b.elegir_nombre("CRUPIER")
	n = await _esperar("nombre")
	_ok(n.size() == 3 and n[1], "otro nombre libre")
	b.enviar_reto(_resumen(500))
	e = await _esperar("envio")
	_ok(e.size() == 3 and e[1], "envío del segundo jugador")

	# La tabla: orden, posición y tu fila.
	a.pedir_tabla(J.fecha_hoy())
	var t := await _esperar("tabla")
	var d: Dictionary = t[1] if t.size() == 2 else {}
	var nombres: Array = d.get("top", []).map(func(x): return x.nombre)
	_ok(nombres == ["CRUPIER", "TAHUR-UNO"], "top del día ordenado por puntos (%s)" % [nombres])
	_ok(d.get("yo") is Dictionary and int(d.yo.pos) == 2 and d.top[1].yo and not d.top[0].yo, "tu posición y tu fila marcada")
	_ok(int(d.top[0].piso) == 3 and int(d.top[0].tiempo) == 500, "con piso y tiempo")
	a.pedir_historico()
	t = await _esperar("tabla")
	_ok(t.size() == 2 and t[1].tipo == "historico" and t[1].top.size() == 2, "histórico")

	# Firma: con otro secreto el servidor lo rechaza (y no se queda atascado en la cola).
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CUENTA_PRUEBA))
	var c = _nuevo_online(_url(), CLAVE, "otro-secreto")
	c.enviar_reto(_resumen())
	e = await _esperar("envio")
	_ok(e.size() == 3 and not e[1] and e[2] == "firma" and c.pendientes() == 0, "firma mala: rechazada y fuera de la cola")
	# Puntos trucados: el servidor recalcula la fórmula.
	var trampa := _resumen()
	trampa.puntos = 99999
	c.configurar(_url(), CLAVE, SECRETO)
	c.enviar_reto(trampa)
	e = await _esperar("envio")
	_ok(e.size() == 3 and not e[1] and e[2] == "puntos", "puntos que no cuadran: rechazados")
	# Clave anónima mala: el servidor da 401 y se trata como fallo, sin colgarse.
	var mala = _nuevo_online(_url(), "clave-mala", SECRETO)
	mala.pedir_tabla(J.fecha_hoy())
	f = await _esperar("fallo")
	_ok(f.size() == 3 and f[2] == "servidor", "clave mala: error de servidor, no cuelga")
	for o2 in [a, b, c, mala]:
		o2.queue_free()
	await process_frame


func comprobar_pantalla() -> void:
	# La pantalla del reto con el online del juego apuntando al servidor falso.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CUENTA_PRUEBA))
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._menu.cerrar()
	var o = m._online
	o.ruta_cuenta = CUENTA_PRUEBA
	o.nombre = ""
	o.token = ""
	o.configurar(_url(), CLAVE, SECRETO)
	var r = m._reto
	r._nombre_preguntado = false
	r.abrir()
	await process_frame
	_ok(r.hay_mundial() and r._eligiendo_nombre and r._campo.visible, "la primera vez pide nombre")
	r._campo.text = "ab"
	r.tocar(r.CAJA_ACEPTAR.get_center())
	_ok(r._eligiendo_nombre and r._error_nombre == "nombre_corto", "avisa si el nombre no vale")
	r._campo.text = "jugadora-3"
	r.tocar(r.CAJA_ACEPTAR.get_center())
	await _hasta(func(): return not r._eligiendo_nombre)
	_ok(not r._eligiendo_nombre and o.nombre == "JUGADORA-3", "con un nombre bueno se cierra")
	o.enviar_reto(_resumen(1000))
	await _hasta(func(): return o.pendientes() == 0)
	r.tecla(KEY_RIGHT)
	_ok(r._pestana == 1, "flecha: pestaña MUNDIAL")
	await _hasta(func(): return r._estado == "" and r._filas.size() == 3)
	_ok(r._filas.size() == 3 and r._filas[0].nombre == "JUGADORA-3" and r.fila_propia_visible(), "la tabla sale con tu fila resaltada")
	r.tocar(r.CAJA_MODO.get_center())
	_ok(r._historico, "tocar: cambia a histórico")
	r.tecla(KEY_H)
	_ok(not r._historico, "H: vuelve a hoy")
	r.tocar(r.CAJA_PESTANA_HOY.get_center())
	_ok(r._pestana == 0, "tocar: pestaña HOY")
	r.tecla(KEY_ESCAPE)
	_ok(not r.visible, "Esc vuelve al menú")
	m.queue_free()
	await process_frame


## Puntos de la pantalla del reto, para tocar sin nombrar la clase (que usa Juego).
class PantallaRetoCajas:
	const MUNDIAL := Vector2(369, 52)
