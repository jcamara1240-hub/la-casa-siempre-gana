extends SceneTree
## Arrastra una carta con eventos de ratón y cruza una puerta andando.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_interfaz.gd

const TECLAS := {Vector2i.UP: KEY_W, Vector2i.DOWN: KEY_S, Vector2i.LEFT: KEY_A, Vector2i.RIGHT: KEY_D}


func _initialize() -> void:
	_correr.call_deferred()


func _boton(barra, p: Vector2, pulsado: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pulsado
	e.position = p
	barra._gui_input(e)


func _mover(barra, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	barra._gui_input(e)


func _correr() -> void:
	var juego: Node = root.get_node("Juego")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._pantalla.visible = false
	m._menu.cerrar()
	m.empezar_partida()
	await physics_frame

	juego.cartas = ["bala", "afilar", "", "", ""]
	var barra = m._barra
	_boton(barra, Vector2(20, 25), true)
	_mover(barra, Vector2(60, 25))
	print("mientras arrastra, combo=", Combo.resolver(barra._fila_visible()).total)
	_boton(barra, Vector2(60, 25), false)
	print("tras soltar: ", juego.cartas)
	var ok_drag: bool = juego.cartas[0] == "afilar" and juego.cartas[1] == "bala"

	barra.en_combate = true
	_boton(barra, Vector2(20, 25), true)
	var ok_bloqueo: bool = barra._arrastrando == -1
	barra.en_combate = false
	print("en combate no se arrastra: ", ok_bloqueo)

	var ok_puertas := true
	for d in TECLAS:
		var origen: Vector2i = m.actual.pos
		if not m.salas.has(origen + d):
			continue
		m.jugador.position = Sala.CENTRO + Vector2(d) * 60.0
		var e := InputEventKey.new()
		e.physical_keycode = TECLAS[d]
		e.pressed = true
		Input.parse_input_event(e)
		var cruzo := false
		for _i in 240:
			await physics_frame
			if m.actual.pos != origen:
				cruzo = true
				break
		e = InputEventKey.new()
		e.physical_keycode = TECLAS[d]
		e.pressed = false
		Input.parse_input_event(e)
		print("puerta ", d, " cruzada andando: ", cruzo)
		ok_puertas = ok_puertas and cruzo
		break
	print("RESULTADO ", ok_drag and ok_bloqueo and ok_puertas)
	quit()
