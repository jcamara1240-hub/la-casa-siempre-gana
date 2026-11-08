extends SceneTree
## Joystick y botones con toques simulados.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_tactil.gd

var _fallos := 0


func _initialize() -> void:
	_correr.call_deferred()


func _ok(c: bool, que: String) -> void:
	print("ok  " if c else "MAL ", que)
	if not c:
		_fallos += 1


func _tocar(p: Vector2, si: bool, dedo := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = dedo
	e.position = p
	e.pressed = si
	root.push_input(e, true)


func _arrastrar(p: Vector2, dedo := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = dedo
	e.position = p
	root.push_input(e, true)


func _esperar(n: int) -> void:
	for _i in n:
		await physics_frame


func _correr() -> void:
	var J: Node = root.get_node("Juego")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._menu.cerrar()
	m.empezar_partida("tahur", 0)
	m.jugador.invulnerable = true
	await _esperar(3)

	var inicio: Vector2 = m.jugador.position
	_tocar(Vector2(200, 200), true)
	_arrastrar(Vector2(240, 200))
	await _esperar(30)
	_ok(J.tactil, "al tocar se activan los controles táctiles")
	_ok(m.jugador.position.x > inicio.x + 20.0, "el joystick mueve al personaje")
	_tocar(Vector2(240, 200), false)
	await _esperar(30)
	var quieto: Vector2 = m.jugador.position
	await _esperar(20)
	_ok(quieto.distance_to(m.jugador.position) < 1.0, "al soltar se para")

	_tocar(Vector2(455, 15), true)
	await process_frame
	_ok(paused and m._menu.visible, "el botón de pausa funciona")
	_tocar(Vector2(455, 15), false)
	m._menu.cerrar()
	m._reanudar()

	var tienda := Vector2i.ZERO
	for c in m.salas:
		if m.salas[c].tipo == GeneradorMazmorra.Tipo.TIENDA:
			tienda = c
	m.entrar_sala(tienda, Vector2i.ZERO)
	await _esperar(4)
	var r = m._recogibles.get_child(3)
	J.oro = 200
	m.jugador.position = r.position
	await _esperar(4)
	_ok(m.articulo_a_mano() != null, "cerca de un artículo aparece Comprar")
	var oro_antes: int = J.oro
	_tocar(Vector2(570, 256), true)
	_tocar(Vector2(570, 256), false)
	await _esperar(3)
	_ok(J.oro < oro_antes, "el botón Comprar compra")

	m._acabar(false)
	await process_frame
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	clic.position = Vector2(320, 200)
	m._pantalla._gui_input(clic)
	_ok(m._pantalla.animacion_terminada(), "tocar la pantalla final salta la animación")
	m._pantalla._gui_input(clic)
	await process_frame
	_ok(not m._pantalla.visible and m._menu.visible, "otro toque vuelve al menú")

	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)
