extends SceneTree
## Monta situaciones concretas y guarda una imagen de cada una.
##   godot --path . -s res://tests/capturas.gd -- DIRECTORIO

var m
var J: Node
var dir_salida := ""


func _initialize() -> void:
	dir_salida = OS.get_cmdline_user_args()[0]
	_correr.call_deferred()


func _salva(nombre: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [dir_salida, nombre])


func _espera(n: int) -> void:
	for _i in n:
		await physics_frame


func _sala_de(tipo: int) -> Vector2i:
	for c in m.salas:
		if m.salas[c].tipo == tipo:
			return c
	return Vector2i.ZERO


func _correr() -> void:
	J = root.get_node("Juego")
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	Idioma.actual = "es"
	await _espera(40)
	await _salva("menu_es")
	m._menu._ir_a(1)
	Idioma.actual = "en"
	await _salva("opciones_en")
	m._menu._ir_a(0)
	await _salva("menu_en")
	Idioma.actual = "es"
	m._menu.cerrar()
	Progreso.personajes = ["tahur", "borracho", "crupier"]
	Progreso.mesa_max = 2
	m._seleccion.abrir()
	await _espera(10)
	await _salva("seleccion")
	m._seleccion.visible = false
	m._coleccion.abrir()
	await _espera(4)
	await _salva("coleccion")
	m._coleccion.visible = false
	m.empezar_partida("borracho", 1)
	await _espera(4)
	J.oro = 57
	J.dar_objeto("traje")
	J.dar_objeto("puro")
	J.dar_objeto("whisky")
	J.pedir_prestamo()
	await _espera(10)
	await _salva("transformacion")
	var p = m._panel
	p.abrir("trileros")
	p._apostar_trileros(10)
	await _espera(70)
	await _salva("evento_trileros")
	p._cerrar()
	p.abrir("prestamista")
	await _espera(3)
	await _salva("evento_prestamista")
	p._cerrar()
	m._pantalla.visible = false
	m._menu.cerrar()
	m.empezar_partida()
	m.jugador.invulnerable = true
	J.oro = 57
	J.estado_cambiado.emit()
	J.cartas = ["ciega_grande", "as_picas", "doble", "dados", "bala", "pareja", "", ""]
	J.cartas_cambiadas.emit()
	for id in ["trebol", "puro", "gafas", "whisky", "herradura", "iman"]:
		J.dar_objeto(id)
	for c in m.salas:
		m.salas[c].visitada = true
	m.entrar_sala(_sala_de(GeneradorMazmorra.Tipo.TIENDA), Vector2i.ZERO)
	m.jugador.position = Vector2(176, 150)
	await _espera(10)
	m.abrir_selector(["full", "comodin", "mano_muerta"], Idioma.t("¡TESORO!"))
	await _salva("selector_en")
	m._cerrar_selector()
	m._quizas_pausar()
	await _salva("pausa_en")
	m._menu.cerrar()
	paused = false
	await _salva("tienda")

	m.entrar_sala(_sala_de(GeneradorMazmorra.Tipo.TESORO), Vector2i.ZERO)
	await _espera(10)
	await _salva("tesoro")

	J.piso = 3
	m._salas_limpiadas = 6
	var normal := Vector2i.ZERO
	for c in m.salas:
		if m.salas[c].tipo == GeneradorMazmorra.Tipo.NORMAL:
			normal = c
	m.entrar_sala(normal, Vector2i.ZERO)
	m._oleadas = []
	for t in ["ficha", "dado", "sota", "naipe", "ficha_grande", "joker", "cubilete", "portero", "ficha_grande", "naipe"]:
		m._horda.crear(t, Vector2(randf_range(100, 540), randf_range(60, 270)), 60.0)
	await _espera(100)
	await _salva("enemigos")
	m._horda.limpiar()

	var i := 0
	for id in ["pez", "tragaperras", "ruleta", "baccarat", "blackjack"]:
		m.en_combate = false
		J.orden_jefes[0] = id
		J.piso = 1
		var jefe_c := _sala_de(GeneradorMazmorra.Tipo.JEFE)
		m.salas[jefe_c].limpia = false
		m.entrar_sala(jefe_c, Vector2i.ZERO)
		m.jugador.position = Vector2(320, 250)
		if m._horda.jefe != null:
			m._horda.jefe.vida *= 20.0
			m._horda.jefe.vida_max *= 20.0
		await _espera(280)
		await _salva("jefe_%d" % i)
		m._horda.limpiar()
		m._ataques.limpiar()
		i += 1
	quit()
