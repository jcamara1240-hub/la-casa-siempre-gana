extends SceneTree
## Monta las escenas del tráiler dentro del juego real.
##   godot --path . --fixed-fps 30 --write-movie carpeta/f.png -s res://tests/trailer.gd

var m
var J: Node
var _pie: Label
var _pie_fondo: ColorRect
var _negro: ColorRect
var _pulsadas := {}
var _mover := true
var _t := 0.0
var _frame := 0


func _initialize() -> void:
	_correr.call_deferred()


func _esperar(segundos: float) -> void:
	for _i in int(segundos * 30.0):
		await process_frame
		_frame += 1
		_t += 1.0 / 30.0
		if _mover and not paused:
			_andar()


func _andar() -> void:
	var yo: Vector2 = m.jugador.position
	var a := _t * 1.1
	var hacia := Sala.CENTRO + Vector2(cos(a) * 200.0, sin(a * 1.4) * 80.0) - yo
	_tecla(KEY_D, hacia.x > 8.0)
	_tecla(KEY_A, hacia.x < -8.0)
	_tecla(KEY_S, hacia.y > 8.0)
	_tecla(KEY_W, hacia.y < -8.0)


func _tecla(codigo: Key, si: bool) -> void:
	if _pulsadas.get(codigo, false) == si:
		return
	_pulsadas[codigo] = si
	var e := InputEventKey.new()
	e.physical_keycode = codigo
	e.pressed = si
	Input.parse_input_event(e)


func _soltar_teclas() -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_tecla(k, false)


func _marca(nombre: String) -> void:
	print("MARCA %s %.2f %d" % [nombre, _t, _frame])


func _crear_capas() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 100
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(capa)
	_pie_fondo = ColorRect.new()
	_pie_fondo.color = Color(0.08, 0.06, 0.12, 0.85)
	_pie_fondo.visible = false
	capa.add_child(_pie_fondo)
	_pie = Label.new()
	_pie.add_theme_font_override("font", J.fuente_grande)
	_pie.add_theme_font_size_override("font_size", 16)
	_pie.add_theme_color_override("font_color", Color8(247, 198, 74))
	_pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pie.position = Vector2(0, 54)
	_pie.size = Vector2(640, 20)
	capa.add_child(_pie)
	_negro = ColorRect.new()
	_negro.color = Color8(20, 16, 30)
	_negro.size = Vector2(640, 360)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_negro)


func _texto(t: String) -> void:
	if OS.get_cmdline_user_args().has("limpio"):
		return
	_pie.text = t
	_pie_fondo.visible = t != ""
	if t != "":
		var ancho: float = J.fuente_grande.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_pie_fondo.position = Vector2(320.0 - ancho * 0.5 - 10.0, 50)
		_pie_fondo.size = Vector2(ancho + 20.0, 24)


func _fundir(de: float, a: float, seg := 0.2) -> void:
	for i in int(seg * 30.0):
		_negro.modulate.a = lerpf(de, a, float(i + 1) / int(seg * 30.0))
		await _esperar(1.0 / 30.0 + 0.001)
	_negro.modulate.a = a


func _sala_de(tipo: int) -> Vector2i:
	for c in m.salas:
		if m.salas[c].tipo == tipo:
			return c
	return Vector2i.ZERO


func _limpiar_mesa() -> void:
	m.en_combate = false
	m._barra.en_combate = false
	m._motor.parar()
	m._barra.parar_animacion()
	m._oleadas = []
	m._horda.limpiar()
	m._ataques.limpiar()
	for r in m._recogibles.get_children():
		r.queue_free()
	m._cartel.text = ""
	m._cartel_sub.text = ""
	m._aviso.text = ""


func _fila(cartas: Array) -> void:
	J.cartas = cartas
	J.cartas_cambiadas.emit()


func _horda(tipos: Array, cuantos: int, vida := 1.0) -> void:
	for i in cuantos:
		var a := randf() * TAU
		var r := randf_range(130.0, 280.0)
		var p: Vector2 = Sala.CENTRO + Vector2(cos(a) * r, sin(a) * r * 0.42)
		m._horda.crear(tipos[i % tipos.size()], p, vida)


func _sala_combate(cartas: Array, tipos: Array, cuantos: int, vida := 1.0) -> void:
	_limpiar_mesa()
	var normal := Vector2i.ZERO
	for c in m.salas:
		if m.salas[c].tipo == GeneradorMazmorra.Tipo.NORMAL:
			normal = c
	m.salas[normal].limpia = false
	m.entrar_sala(normal, Vector2i.ZERO)
	m._cartel.text = ""
	m._cartel_sub.text = ""
	m._oleadas = []
	_fila(cartas)
	_horda(tipos, cuantos, vida)


func _jefe(id: String) -> void:
	_limpiar_mesa()
	J.orden_jefes[0] = id
	J.piso = 1
	var c := _sala_de(GeneradorMazmorra.Tipo.JEFE)
	m.salas[c].limpia = false
	m.entrar_sala(c, Vector2i.ZERO)
	m.jugador.position = Vector2(320, 240)
	var j = m._horda.jefe
	j.vida *= 40.0
	j.vida_max *= 40.0
	j._nacer = 0.05
	j._reloj = 0.15
	await _esperar(2.7)


func _arrastrar(desde: int, hasta: int, seg: float) -> void:
	var barra = m._barra
	var y := 25.0
	var origen := Vector2(6.0 + desde * 36.0 + 16.0, y)
	var fin := Vector2(6.0 + hasta * 36.0 + 16.0, y)
	var pulsar := InputEventMouseButton.new()
	pulsar.button_index = MOUSE_BUTTON_LEFT
	pulsar.pressed = true
	pulsar.position = origen
	barra._gui_input(pulsar)
	var pasos := int(seg * 30.0)
	for i in pasos:
		var mover := InputEventMouseMotion.new()
		mover.position = origen.lerp(fin, ease(float(i + 1) / pasos, -2.0))
		barra._gui_input(mover)
		await _esperar(1.0 / 30.0 + 0.001)
	var soltar := InputEventMouseButton.new()
	soltar.button_index = MOUSE_BUTTON_LEFT
	soltar.pressed = false
	soltar.position = fin
	barra._gui_input(soltar)


func _correr() -> void:
	J = root.get_node("Juego")
	Idioma.actual = "es"
	J.sacudida = true
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	# Solo efectos: la música se mezcla aparte, continua, al montar el vídeo.
	J.cambiar_volumenes(0.0, 0.8)
	Progreso.personajes = ["tahur", "borracho", "crupier", "heredera"]
	Progreso.mesa_max = 4
	_crear_capas()
	_mover = false

	_marca("titulo")
	await _fundir(1.0, 0.0, 0.5)
	await _esperar(2.6)
	await _fundir(0.0, 1.0)

	m._menu.cerrar()
	m.empezar_partida("tahur", 0)
	m.jugador.invulnerable = true
	for c in m.salas:
		m.salas[c].visitada = true
	_mover = true

	_marca("horda")
	_sala_combate(["bala", "abanico", "", "", ""], ["ficha", "dado", "ficha"], 16)
	_texto("MAZMORRAS DISTINTAS EN CADA PARTIDA")
	await _fundir(1.0, 0.0)
	await _esperar(3.2)
	await _fundir(0.0, 1.0)

	_marca("cartas")
	_sala_combate(["afilar", "bala", "doble", "abanico", "rayo", "", "", ""], ["ficha", "dado", "naipe", "sota", "ficha_grande"], 30, 2.0)
	_texto("TÚ NO ATACAS: ATACAN TUS CARTAS")
	await _fundir(1.0, 0.0)
	await _esperar(3.6)
	await _fundir(0.0, 1.0)

	_marca("arrastre")
	_limpiar_mesa()
	m.entrar_sala(GeneradorMazmorra.INICIO, Vector2i.ZERO)
	m._cartel.text = ""
	m._cartel_sub.text = ""
	_fila(["doble_nada", "propina", "afilar", "as_picas", "doble", "dados", "", ""])
	_mover = false
	_soltar_teclas()
	_texto("EL ORDEN LO ES TODO")
	await _fundir(1.0, 0.0)
	await _esperar(0.8)
	await _arrastrar(0, 5, 0.8)
	await _esperar(0.5)
	await _arrastrar(0, 5, 0.8)
	await _esperar(1.0)
	await _fundir(0.0, 1.0)
	_mover = true

	_marca("combo")
	J.piso = 4
	_sala_combate(["ciega_grande", "as_picas", "doble", "jackpot", "nova", "escalera", "doble_nada", "propina"],
			["ficha", "dado", "naipe", "ficha_grande", "joker", "portero", "cubilete", "sota"], 60, 3.0)
	_texto("MULTIPLICA HASTA REVENTAR LA BANCA")
	J.objetos = []
	await _fundir(1.0, 0.0)
	await _esperar(4.6)
	await _fundir(0.0, 1.0)

	_marca("tienda")
	J.piso = 1
	_limpiar_mesa()
	J.oro = 94
	J.estado_cambiado.emit()
	m.entrar_sala(_sala_de(GeneradorMazmorra.Tipo.TIENDA), Vector2i.ZERO)
	m._cartel.text = ""
	m._cartel_sub.text = ""
	_mover = false
	_soltar_teclas()
	m.jugador.position = Vector2(248, 170)
	_texto("45 CARTAS Y 16 OBJETOS")
	await _fundir(1.0, 0.0)
	await _esperar(1.5)
	_texto("")
	m.abrir_selector(["full", "comodin", "mano_muerta"], "¡TESORO!")
	await _esperar(1.7)
	m._cerrar_selector()

	for id in ["traje", "puro"]:
		J.dar_objeto(id)
	await _esperar(0.2)
	J.dar_objeto("whisky")
	await _esperar(1.8)
	await _fundir(0.0, 1.0)

	_marca("evento")
	var p = m._panel
	paused = true
	J.oro = 57
	p.abrir("trileros")
	_texto("")
	await _fundir(1.0, 0.0)
	await _esperar(0.6)
	p._apostar_trileros(20)
	await _esperar(3.2)
	await _fundir(0.0, 1.0)
	p.visible = false
	paused = false
	_mover = true

	_marca("jefes")
	for id in ["pez", "tragaperras", "ruleta", "baccarat", "blackjack"]:
		_texto("")
		_negro.modulate.a = 0.0
		await _jefe(id)
	await _fundir(0.0, 1.0)

	_marca("seleccion")
	_limpiar_mesa()
	paused = true
	_soltar_teclas()
	m._seleccion._indice = 1
	m._seleccion._mesa = 2
	m._seleccion.abrir()
	await _fundir(1.0, 0.0)
	await _esperar(2.3)
	await _fundir(0.0, 1.0)

	_marca("final")
	m._seleccion.visible = false
	m._menu.abrir_principal()
	m._menu._items = []
	m._menu.solo_titulo = true
	_texto("")
	var fin := Label.new()
	fin.text = "" if OS.get_cmdline_user_args().has("limpio") else "JUEGA GRATIS EN EL NAVEGADOR"
	fin.add_theme_font_override("font", J.fuente_grande)
	fin.add_theme_font_size_override("font_size", 16)
	fin.add_theme_color_override("font_color", Color8(247, 236, 210))
	fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fin.position = Vector2(0, 170)
	fin.size = Vector2(640, 20)
	_pie.get_parent().add_child(fin)
	_pie.get_parent().move_child(fin, _negro.get_index())
	await _fundir(1.0, 0.0, 0.4)
	await _esperar(3.0)
	await _fundir(0.0, 1.0, 0.7)
	_marca("fin")
	quit()
