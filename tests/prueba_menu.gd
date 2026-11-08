extends SceneTree
## Recorre el menú con ratón y teclado.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_menu.gd

var _fallos := 0


func _initialize() -> void:
	_correr.call_deferred()


func _ok(condicion: bool, que: String) -> void:
	print("ok  " if condicion else "MAL ", que)
	if not condicion:
		_fallos += 1


func _tecla(codigo: Key) -> void:
	for pulsada in [true, false]:
		var e := InputEventKey.new()
		e.keycode = codigo
		e.physical_keycode = codigo
		e.pressed = pulsada
		root.push_input(e)
	await process_frame


func _clic(menu, i: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = menu._caja(i).get_center()
	menu._gui_input(e)
	await process_frame


func _correr() -> void:
	var juego: Node = root.get_node("Juego")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	_ok(not m._pantalla.visible, "la pantalla final empieza oculta")
	var menu = m._menu
	_ok(menu.visible and paused, "el juego arranca en el menú y en pausa")
	_ok(menu._items == ["jugar", "coleccion", "opciones", "salir"], "Jugar, Colección, Opciones y Salir")

	await _clic(menu, 1)
	_ok(m._coleccion.visible and not menu.visible, "se abre la colección")
	await _tecla(KEY_ESCAPE)
	_ok(menu.visible and not m._coleccion.visible, "Esc sale de la colección")

	await _clic(menu, 2)
	_ok(menu._items[0] == "idioma", "clic en Opciones")
	var antes: String = Idioma.actual
	await _tecla(KEY_ENTER)
	_ok(Idioma.actual != antes, "Enter cambia el idioma")
	await _tecla(KEY_LEFT)
	_ok(Idioma.actual == antes, "la flecha lo devuelve")
	var cfg := ConfigFile.new()
	_ok(cfg.load("user://ajustes.cfg") == OK and cfg.get_value("ajustes", "idioma") == antes, "el idioma queda guardado")
	await _tecla(KEY_ESCAPE)
	_ok(menu._items[0] == "jugar", "Esc vuelve al menú principal")

	await _tecla(KEY_ENTER)
	_ok(m._seleccion.visible, "Jugar lleva a elegir personaje")
	await _tecla(KEY_ESCAPE)
	_ok(menu.visible and not m._seleccion.visible, "Esc vuelve desde la selección")
	await _tecla(KEY_ENTER)
	await _tecla(KEY_ENTER)
	await physics_frame
	_ok(not menu.visible and not paused and not m.salas.is_empty(), "Enter empieza la partida")
	_ok(not m._pantalla.visible and not m._selector.visible and not m._panel.visible
			and not m._seleccion.visible and not m._coleccion.visible, "ninguna pantalla tapa la partida")

	await _tecla(KEY_ESCAPE)
	_ok(menu.visible and paused and menu._items[0] == "continuar", "Esc pausa")
	await _tecla(KEY_ESCAPE)
	_ok(not menu.visible and not paused, "Esc reanuda")

	m.abrir_selector(["bala", "rayo"], "X")
	await _tecla(KEY_ESCAPE)
	_ok(not menu.visible and m._selector.visible, "Esc no interrumpe la elección de carta")
	m._cerrar_selector()

	await _tecla(KEY_ESCAPE)
	await _clic(menu, 2)
	_ok(menu.visible and menu._items[0] == "jugar" and paused, "desde la pausa al menú principal")
	await _tecla(KEY_ENTER)
	await _tecla(KEY_ENTER)
	await physics_frame
	_ok(juego.vida == juego.vida_max and not paused, "se puede empezar otra partida")

	juego.vida = 1
	m.jugador.recibir_golpe(1)
	await process_frame
	_ok(m._pantalla.visible, "al morir sale la pantalla final")
	await _tecla(KEY_ENTER)
	_ok(menu.visible and menu._items[0] == "jugar" and not m._pantalla.visible, "Enter vuelve al menú")

	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)
