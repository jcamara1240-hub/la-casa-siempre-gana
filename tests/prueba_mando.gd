extends SceneTree
## El mando, con eventos inventados (en headless no hay mando de verdad): se meten con
## Input.parse_input_event como los mandaría el sistema y se mira lo que pasa.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_mando.gd

var _fallos := 0
var Mando: GDScript = load("res://scripts/mando.gd")


func _initialize() -> void:
	_correr.call_deferred()


func _ok(condicion: bool, que: String) -> void:
	print("bien: " if condicion else "MAL:  ", que)
	if not condicion:
		_fallos += 1


func _boton(boton: int, pulsado: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = boton
	e.pressed = pulsado
	e.pressure = 1.0 if pulsado else 0.0
	Input.parse_input_event(e)
	await process_frame


func _pulsar(boton: int) -> void:
	await _boton(boton, true)
	await _boton(boton, false)


func _eje(eje: int, valor: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = eje
	e.axis_value = valor
	Input.parse_input_event(e)
	await process_frame


func _tecla(codigo: Key) -> void:
	for pulsada in [true, false]:
		var e := InputEventKey.new()
		e.keycode = codigo
		e.physical_keycode = codigo
		e.pressed = pulsada
		Input.parse_input_event(e)
		await process_frame


func _esperar(fotogramas: int) -> void:
	for i in fotogramas:
		await physics_frame


## Baja (o sube) con la cruceta hasta que el menú señale ese botón.
func _ir_a_boton(menu, id: String) -> void:
	for i in 12:
		if menu._items[menu._indice] == id:
			return
		await _pulsar(JOY_BUTTON_DPAD_DOWN)


func _correr() -> void:
	var juego: Node = root.get_node("Juego")
	DirAccess.remove_absolute("user://partida.sav")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	var menu = m._menu
	_ok(menu.visible and paused, "arranca en el menú")

	# ------------------------------------------------ detección y ayudas
	_ok(not Mando.activo, "sin tocar el mando, las ayudas son de teclado")
	await _pulsar(JOY_BUTTON_DPAD_DOWN)
	_ok(Mando.activo and menu._indice == 1, "la cruceta baja en el menú y activa el mando")
	_ok("STICK" in menu.instrucciones()[0] and "A:" in menu.instrucciones()[3], "las instrucciones enseñan los botones del mando")
	await _tecla(KEY_UP)
	_ok(not Mando.activo and menu._indice == 0, "una tecla vuelve a las ayudas de teclado")
	_ok("WASD" in menu.instrucciones()[0], "las instrucciones vuelven a las teclas")

	# El stick hace de cruceta: un paso por inclinación, sin repetir mientras sigue inclinado.
	await _eje(JOY_AXIS_LEFT_Y, 0.9)
	await _eje(JOY_AXIS_LEFT_Y, 0.95)
	_ok(menu._indice == 1, "el stick baja una sola vez aunque siga inclinado")
	await _eje(JOY_AXIS_LEFT_Y, 0.0)
	await _eje(JOY_AXIS_LEFT_Y, -0.9)
	await _eje(JOY_AXIS_LEFT_Y, 0.0)
	_ok(menu._indice == 0, "el stick sube")
	await _eje(JOY_AXIS_LEFT_Y, 0.1)
	_ok(menu._indice == 0, "dentro de la zona muerta no pasa nada")

	# ------------------------------------------------ opciones y vibración
	await _ir_a_boton(menu, "opciones")
	await _pulsar(JOY_BUTTON_A)
	_ok(menu._items[0] == "idioma" and "vibracion" in menu._items, "A abre las opciones, con la vibración")
	await _ir_a_boton(menu, "vibracion")
	await _pulsar(JOY_BUTTON_A)
	var cfg := ConfigFile.new()
	_ok(not Mando.vibracion and cfg.load("user://ajustes.cfg") == OK and cfg.get_value("ajustes", "vibracion") == false,
			"A quita la vibración y se guarda en ajustes.cfg")
	await _pulsar(JOY_BUTTON_A)
	_ok(Mando.vibracion, "y la vuelve a poner")
	await _pulsar(JOY_BUTTON_B)
	_ok("jugar" in menu._items and menu.visible, "B vuelve al menú principal")

	# ------------------------------------------------ colección, logros y reto
	await _ir_a_boton(menu, "coleccion")
	await _pulsar(JOY_BUTTON_A)
	var col = m._coleccion
	_ok(col.visible, "A abre la colección")
	await _pulsar(JOY_BUTTON_RIGHT_SHOULDER)
	_ok(col._pagina == 1 and col._cursor == 0, "RB cambia de pestaña")
	await _pulsar(JOY_BUTTON_DPAD_RIGHT)
	_ok(col._cursor == 1 and col._titulo_info != "", "la cruceta recorre las casillas y enseña qué son")
	await _pulsar(JOY_BUTTON_DPAD_DOWN)
	_ok(col._cursor > 1, "abajo baja de fila")
	await _pulsar(JOY_BUTTON_LEFT_SHOULDER)
	_ok(col._pagina == 0, "LB vuelve a la otra pestaña")
	await _pulsar(JOY_BUTTON_B)
	_ok(not col.visible and menu.visible, "B sale de la colección")

	await _ir_a_boton(menu, "logros")
	await _pulsar(JOY_BUTTON_A)
	_ok(m._logros.visible, "A abre los logros")
	if m._logros._paginas > 1:
		await _pulsar(JOY_BUTTON_RIGHT_SHOULDER)
		_ok(m._logros._pagina == 1, "RB pasa a la siguiente página de logros")
		await _pulsar(JOY_BUTTON_DPAD_LEFT)
		_ok(m._logros._pagina == 0, "la cruceta vuelve a la primera")
	await _pulsar(JOY_BUTTON_B)
	_ok(not m._logros.visible and menu.visible, "B sale de los logros")

	await _ir_a_boton(menu, "reto")
	await _pulsar(JOY_BUTTON_A)
	_ok(m._reto.visible, "A abre el reto diario")
	await _pulsar(JOY_BUTTON_B)
	_ok(not m._reto.visible and menu.visible, "B sale del reto")

	# ------------------------------------------------ elegir personaje y empezar
	await _ir_a_boton(menu, "jugar")
	await _pulsar(JOY_BUTTON_A)
	var sel = m._seleccion
	_ok(sel.visible, "A en Jugar lleva a elegir personaje")
	await _pulsar(JOY_BUTTON_DPAD_RIGHT)
	_ok(sel._indice == 1, "la cruceta cambia de personaje")
	await _pulsar(JOY_BUTTON_DPAD_LEFT)
	await _pulsar(JOY_BUTTON_X)
	_ok(sel._modo == 1, "X cambia el modo")
	await _pulsar(JOY_BUTTON_X)
	await _pulsar(JOY_BUTTON_X)
	_ok(sel._modo == 0, "y da la vuelta")
	await _pulsar(JOY_BUTTON_B)
	_ok(not sel.visible and menu.visible, "B vuelve al menú")
	await _ir_a_boton(menu, "jugar")  # ahora arriba está "Continuar partida"
	await _pulsar(JOY_BUTTON_A)
	_ok(sel.visible, "otra vez a elegir personaje")
	await _pulsar(JOY_BUTTON_A)
	await physics_frame
	_ok(not paused and not menu.visible and not sel.visible and not m.salas.is_empty() and not m.en_combate, "A empieza la partida")
	await _esperar(30)  # que se calme todo antes de medir

	# ------------------------------------------------ moverse
	var jugador = m.jugador
	await _eje(JOY_AXIS_LEFT_X, 1.0)
	await _esperar(12)
	var lleno: float = jugador.velocity.x
	_ok(lleno > 150.0, "el stick a tope mueve a la derecha a toda velocidad (%d)" % lleno)
	await _eje(JOY_AXIS_LEFT_X, 0.15)
	await _esperar(12)
	_ok(jugador.velocity.length() < 1.0, "en la zona muerta se para")
	await _eje(JOY_AXIS_LEFT_X, 0.5)
	await _esperar(12)
	var medio: float = jugador.velocity.x
	_ok(medio > lleno * 0.25 and medio < lleno * 0.5, "a medias va más despacio: es analógico (%d de %d)" % [medio, lleno])
	await _eje(JOY_AXIS_LEFT_X, 0.0)
	await _boton(JOY_BUTTON_DPAD_UP, true)
	await _esperar(12)
	_ok(jugador.velocity.y < -150.0 and absf(jugador.velocity.x) < 1.0, "la cruceta mueve hacia arriba")
	await _boton(JOY_BUTTON_DPAD_UP, false)
	await _esperar(12)
	_ok(jugador.velocity.length() < 1.0, "al soltar la cruceta se para")

	# ------------------------------------------------ voltereta
	juego.ultima_voltereta = -100.0
	await _pulsar(JOY_BUTTON_A)
	await _esperar(3)
	_ok(juego.ultima_voltereta > -100.0, "A rueda")
	await _esperar(40)
	juego.ultima_voltereta = -100.0
	await _eje(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _esperar(3)
	_ok(juego.ultima_voltereta > -100.0, "el gatillo derecho también rueda")
	await _eje(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _esperar(40)
	juego.ultima_voltereta = -100.0
	await _pulsar(JOY_BUTTON_RIGHT_SHOULDER)
	await _esperar(3)
	_ok(juego.ultima_voltereta > -100.0, "RB también rueda")
	await _esperar(40)

	# ------------------------------------------------ órdago (con una oleada pendiente para que haya pelea)
	m.en_combate = true
	m._oleadas = [["ficha"]]
	m._oleada_t = 999.0
	juego.ordagos = 2
	var vibraciones: int = Mando.vibraciones
	await _pulsar(JOY_BUTTON_X)
	_ok(juego.ordagos == 1, "X lanza el órdago")
	_ok(Mando.vibraciones == vibraciones + 1, "el órdago vibra")
	await _pulsar(JOY_BUTTON_LEFT_SHOULDER)
	_ok(juego.ordagos == 0, "LB también lanza el órdago")
	Mando.vibracion = false
	vibraciones = Mando.vibraciones
	jugador.recibir_golpe(1)
	_ok(Mando.vibraciones == vibraciones, "con la vibración quitada no vibra")
	Mando.vibracion = true
	await _esperar(50)  # que pase el respiro tras el golpe
	vibraciones = Mando.vibraciones
	juego.vida = juego.vida_max
	jugador.recibir_golpe(1)
	_ok(Mando.vibraciones == vibraciones + 1, "un golpe vibra")
	juego.vida = juego.vida_max
	m._oleadas = []
	m.en_combate = false
	await _esperar(2)

	# ------------------------------------------------ pausa
	await _pulsar(JOY_BUTTON_START)
	_ok(paused and menu.visible and menu._items[0] == "continuar", "Start pausa")
	await _pulsar(JOY_BUTTON_START)
	_ok(not paused and not menu.visible, "Start reanuda")
	await _pulsar(JOY_BUTTON_START)
	await _pulsar(JOY_BUTTON_B)
	_ok(not paused and not menu.visible, "B también sale de la pausa")

	# ------------------------------------------------ interactuar
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_Y
	e.pressed = true
	_ok(Mando.accion(e) == "interactuar", "Y es interactuar (la E)")

	# ------------------------------------------------ reordenar la fila de cartas
	var barra = m._barra
	var o := -1
	for i in juego.cartas.size() - 1:
		if juego.cartas[i] != "":
			o = i
			break
	_ok(o != -1, "hay una carta que mover")
	var esperado: Array = juego.fila_con_movimiento(o, o + 1)
	barra.en_combate = true
	await _pulsar(JOY_BUTTON_BACK)
	_ok(not barra.modo_cartas, "en plena pelea no se entra a ordenar")
	barra.en_combate = false
	await _pulsar(JOY_BUTTON_BACK)
	_ok(barra.modo_cartas and Mando.bloqueado, "Select entra en el modo cartas")
	await _eje(JOY_AXIS_LEFT_X, 1.0)
	await _esperar(10)
	_ok(jugador.velocity.length() < 1.0, "ordenando, el stick no mueve al jugador")
	await _eje(JOY_AXIS_LEFT_X, 0.0)
	for i in 10:
		if barra._cursor == o:
			break
		await _pulsar(JOY_BUTTON_DPAD_RIGHT if barra._cursor < o else JOY_BUTTON_DPAD_LEFT)
	_ok(barra._cursor == o and barra._sobre == o, "la cruceta señala la carta")
	juego.ultima_voltereta = -100.0
	await _pulsar(JOY_BUTTON_A)
	await _esperar(3)
	_ok(barra._arrastrando == o, "A coge la carta")
	_ok(juego.ultima_voltereta == -100.0, "y no rueda")
	await _pulsar(JOY_BUTTON_DPAD_RIGHT)
	_ok(barra._destino == o + 1 and barra._fila_visible() == esperado, "se ve dónde caería")
	await _pulsar(JOY_BUTTON_A)
	_ok(juego.cartas == esperado and barra._arrastrando == -1, "A la suelta: la fila cambia de orden")
	var tras_mover: Array = juego.cartas.duplicate()
	await _pulsar(JOY_BUTTON_A)
	await _pulsar(JOY_BUTTON_DPAD_LEFT)
	await _pulsar(JOY_BUTTON_B)
	_ok(barra.modo_cartas and juego.cartas == tras_mover and barra._arrastrando == -1, "B con una carta cogida la devuelve")
	await _pulsar(JOY_BUTTON_B)
	_ok(not barra.modo_cartas and not Mando.bloqueado, "B otra vez sale del modo cartas")
	await _pulsar(JOY_BUTTON_BACK)
	await _pulsar(JOY_BUTTON_START)
	_ok(not barra.modo_cartas and paused, "Start sale del modo cartas y pausa")
	await _pulsar(JOY_BUTTON_START)

	# ------------------------------------------------ elegir carta (tesoro, carta del suelo)
	m.abrir_selector(["bala", "rayo"], "X")
	var selector = m._selector
	_ok(selector._sobre == 0, "con el mando, el selector empieza señalando la primera")
	await _pulsar(JOY_BUTTON_A)
	_ok(selector.visible, "nada más abrirse, A no elige (por si venías rodando)")
	await _esperar(20)
	await _pulsar(JOY_BUTTON_DPAD_RIGHT)
	_ok(selector._sobre == 1, "la cruceta cambia de carta")
	await _pulsar(JOY_BUTTON_B)
	_ok(selector._sobre == selector.SALTAR and selector.visible, "B señala Saltar sin saltar")
	await _pulsar(JOY_BUTTON_DPAD_RIGHT)
	var antes_cartas: Array = juego.cartas.duplicate()
	await _pulsar(JOY_BUTTON_A)
	_ok(not selector.visible and (juego.cartas != antes_cartas or barra.modo_sustituir), "A elige la carta")
	if barra.modo_sustituir:
		await _pulsar(JOY_BUTTON_B)

	# La fila llena: se elige con la cruceta cuál se cambia, o se cancela.
	for i in 10:
		m._dar_carta("bala")
		if barra.modo_sustituir:
			break
	_ok(barra.modo_sustituir and paused, "con la fila llena hay que elegir cuál cambiar")
	await _pulsar(JOY_BUTTON_DPAD_RIGHT)
	_ok(barra._cursor_visible(), "se ve el cursor en la fila")
	await _pulsar(JOY_BUTTON_B)
	_ok(not barra.modo_sustituir and not paused, "B cancela")
	m._dar_carta("rayo")
	var cursor_cambio: int = barra._cursor
	await _pulsar(JOY_BUTTON_A)
	_ok(not barra.modo_sustituir and juego.cartas[cursor_cambio] == "rayo", "A cambia la carta señalada")

	# ------------------------------------------------ eventos
	var panel = m._panel
	juego.oro = 0
	paused = true
	panel.abrir("mendigo")
	_ok(panel._sobre == 1, "el cursor salta el botón que no se puede pulsar")
	await _esperar(20)
	await _pulsar(JOY_BUTTON_A)
	_ok(not panel.visible and not paused, "A se marcha del mendigo")

	juego.oro = 50
	paused = true
	panel.abrir("trileros")
	_ok(panel._sobre == 0, "trileros: el cursor en la primera apuesta")
	await _esperar(20)
	await _pulsar(JOY_BUTTON_DPAD_DOWN)
	_ok(panel._sobre == 1, "abajo pasa a la siguiente apuesta")
	await _pulsar(JOY_BUTTON_DPAD_UP)
	await _pulsar(JOY_BUTTON_A)
	_ok(juego.oro == 45, "A apuesta")
	for i in 600:
		if panel._fase == panel.Fase.ELEGIR:
			break
		await process_frame
	_ok(panel._fase == panel.Fase.ELEGIR and panel._copa_mando == 1, "tras mezclar, se señala la copa del centro")
	await _pulsar(JOY_BUTTON_DPAD_RIGHT)
	_ok(panel._copa_mando == 2, "la cruceta cambia de copa")
	var copa: int = panel._copas.find(2.0)
	await _pulsar(JOY_BUTTON_A)
	_ok(panel._fase == panel.Fase.RESULTADO and panel._revelar == copa, "A levanta la copa señalada")
	await _pulsar(JOY_BUTTON_B)
	_ok(panel._botones[panel._sobre].texto == Idioma.t("MARCHARSE"), "B lleva el cursor a Marcharse")
	await _pulsar(JOY_BUTTON_A)
	_ok(not panel.visible and not paused, "y A se marcha")

	# ------------------------------------------------ pantalla final, con la oferta del modo infinito
	juego.diario = false
	paused = true
	m._pantalla.mostrar_final(true)
	await _pulsar(JOY_BUTTON_A)
	_ok(not m._pantalla.animacion_terminada(), "nada más salir, A no la salta (por si venías rodando)")
	await _esperar(40)
	await _pulsar(JOY_BUTTON_A)
	_ok(m._pantalla.animacion_terminada() and m._pantalla._hay_oferta(), "A salta la animación y sale la oferta")
	await _pulsar(JOY_BUTTON_DPAD_RIGHT)
	_ok(m._pantalla._opcion == 1, "la cruceta elige Salir al menú")
	await _pulsar(JOY_BUTTON_A)
	_ok(menu.visible and menu._items.has("jugar") and not m._pantalla.visible, "A vuelve al menú")

	await _tecla(KEY_DOWN)
	_ok(not Mando.activo, "al final, el teclado manda otra vez")
	Mando.vibracion = true
	juego.guardar_ajustes()
	DirAccess.remove_absolute("user://partida.sav")
	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)
