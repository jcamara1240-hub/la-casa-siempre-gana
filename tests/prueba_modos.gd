extends SceneTree
## Modo imposible, modo infinito y refuerzo de vida de los jefes.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_modos.gd

var _fallos := 0


func _ok(cond: bool, texto: String) -> void:
	print(("bien: " if cond else "MAL: ") + texto)
	if not cond:
		_fallos += 1


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	var J: Node = root.get_node("Juego")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m._menu.cerrar()

	# ---- imposible
	for personaje in ["tahur", "borracho", "crupier", "heredera", "guarda", "tiburon"]:
		if not J.get_script() or not load("res://scripts/personajes_db.gd").PERSONAJES.has(personaje):
			continue
		m.empezar_partida(personaje, 0, false, true)
		_ok(J.imposible and J.extremo and J.cartas.size() == 2, "imposible con %s: dos ranuras y es extremo" % personaje)
	m.empezar_partida("tahur", 0, false, true)
	J.anadir_ranura()
	_ok(J.cartas.size() == 2, "imposible: no se pueden ganar ranuras")
	for piso in 5:
		J.piso = piso + 1
		m._generar_piso()
		var tipos: Array = m.salas.values().map(func(s): return s.tipo)
		_ok(not tipos.has(2) and not tipos.has(3), "imposible piso %d: sin tesoro ni tienda" % J.piso)
	var robos: Array = []
	for _i in 60:
		robos.append(J.robar_objeto())
	_ok(not robos.has("ficha_vip"), "imposible: no sale la Ficha VIP")
	J.piso = 5
	_ok(is_equal_approx(J.refuerzo_jefe(), 1.0), "imposible: sin refuerzo extra de vida")

	# ---- refuerzo
	m.empezar_partida("tahur", 0)
	_ok(not J.imposible and J.cartas.size() == 5, "partida normal: cinco ranuras")
	J.piso = 1
	_ok(is_equal_approx(J.refuerzo_jefe(), 1.0), "piso 1: los jefes no cambian")
	var anterior := 1.0
	for piso in [2, 3, 4, 5]:
		J.piso = piso
		_ok(J.refuerzo_jefe() > anterior, "piso %d: más vida que el anterior" % piso)
		anterior = J.refuerzo_jefe()

	# ---- tope de daño por segundo
	J.piso = 3
	var jefe = load("res://scripts/jefe.gd").crear("pez")
	root.add_child(jefe)
	jefe.preparar(10.0)
	var llena: float = jefe.vida
	for _i in 8:
		jefe.aplicar_golpe(99999999.0, Vector2.ZERO)
	_ok(is_equal_approx(llena - jefe.vida, llena * 0.1), "piso 3: un combo enorme no quita más del 10 % por segundo")
	J.piso = 1
	jefe.vida = llena
	jefe._dano_segundo = 0.0
	jefe.aplicar_golpe(llena * 0.5, Vector2.ZERO)
	_ok(is_equal_approx(jefe.vida, llena * 0.5), "piso 1: sin tope")
	jefe.queue_free()

	# ---- infinito: ganar, seguir y conservar todo
	J.piso = 5
	J.oro = 77
	J.cartas = ["as_picas", "bala", "doble", "", ""]
	J.objetos = ["puro"]
	J.vida = 3
	m._ganar()
	await process_frame
	_ok(m._pantalla.visible and paused, "al ganar sale la pantalla final")
	m._pantalla._t = m._pantalla._fin + 1.0
	_ok(m._pantalla._hay_oferta(), "al ganar se ofrece seguir")
	var partidas: int = load("res://scripts/progreso.gd").partidas
	m._pantalla._elegir(0)
	await process_frame
	_ok(J.infinito and J.piso == 6 and not paused, "seguir: piso 6 en modo infinito y sin pausa")
	_ok(not m._pantalla.visible and not m._menu.visible, "seguir: no vuelve al menú")
	_ok(J.cartas[0] == "as_picas" and J.objetos.has("puro") and J.vida == 3 and J.oro >= 77, "seguir: conservas cartas, objetos, vida y oro")
	_ok(J.jefe_del_piso() != "" and J.orden_jefes.size() == 6, "seguir: hay jefe para el piso 6")
	for piso in range(7, 31):
		J.piso = piso
		_ok(J.jefe_del_piso() != "", "infinito: jefe en el piso %d" % piso) if piso % 10 == 0 else J.jefe_del_piso()
	_ok(J.orden_jefes[9] == "dueno" and J.orden_jefes[14] == "dueno", "infinito: el Dueño vuelve cada cinco pisos")
	J.piso = 6
	var r6: float = J.refuerzo_jefe()
	J.piso = 7
	_ok(J.refuerzo_jefe() > r6 and J.pisos_extra() == 2, "infinito: cada piso sube la vida del jefe")
	var datos: Dictionary = J.volcar()
	_ok(datos.infinito == true and datos.has("imposible"), "el modo se guarda en la partida")
	for piso in [6, 12, 30]:
		J.piso = piso
		m._generar_piso()
		await process_frame
		var c := Vector2i.ZERO
		for k in m.salas:
			if m.salas[k].tipo == 4:
				c = k
		m.salas[c].limpia = false
		m.entrar_sala(c, Vector2i.ZERO)
		await process_frame
		_ok(m._horda.jefe != null and m._horda.jefe.vida > 0.0, "infinito: el jefe del piso %d aparece" % piso)
		m._horda.limpiar()
		m.en_combate = false
	# Morir en el infinito no cuenta como otra partida y guarda el récord.
	J.piso = 9
	m._acabar(false)
	var P = load("res://scripts/progreso.gd")
	_ok(P.partidas == partidas and P.mejor_infinito >= 9, "morir en infinito: guarda el récord y no suma otra partida")
	_ok(not m._pantalla._hay_oferta(), "morir en infinito: no se ofrece seguir")
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
