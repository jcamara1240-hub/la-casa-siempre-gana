extends SceneTree
## Personajes, desbloqueos, transformaciones, deudas y eventos.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_progreso.gd

var _fallos := 0
var J: Node


func _initialize() -> void:
	_correr.call_deferred()


func _ok(c: bool, que: String) -> void:
	print("ok  " if c else "MAL ", que)
	if not c:
		_fallos += 1


func _correr() -> void:
	J = root.get_node("Juego")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._menu.cerrar()

	Progreso.personajes = ["tahur"]
	Progreso.cartas_extra = []
	Progreso.objetos_extra = []
	Progreso.jefes_vencidos = []
	Progreso.mesa_max = 0
	var azar := RandomNumberGenerator.new()
	var libres_antes := Progreso.cartas_libres()
	_ok(libres_antes < CartasDB.CARTAS.size(), "hay cartas por desbloquear (%d de %d)" % [libres_antes, CartasDB.CARTAS.size()])
	var nuevo := Progreso.al_vencer_jefe("pez", azar)
	_ok(Progreso.personaje_libre("borracho") and nuevo.size() == 6, "el pez abre 3 cartas, 2 objetos y el Borracho")
	_ok(Progreso.cartas_libres() == libres_antes + 3, "las cartas quedan libres")
	Progreso.al_vencer_jefe("ruleta", azar)
	_ok(not Progreso.personaje_libre("crupier"), "con 2 jefes aún no sale la Crupier")
	Progreso.al_vencer_jefe("baccarat", azar)
	_ok(Progreso.personaje_libre("crupier"), "con 3 jefes sale la Crupier")
	Progreso.al_ganar(0)
	_ok(Progreso.personaje_libre("heredera") and Progreso.mesa_max == 1, "ganar abre la Heredera y la Mesa Roja")

	Progreso.cartas_extra = []
	for _i in 300:
		for id in J.robar_cartas(3):
			if not Progreso.carta_libre(id):
				_ok(false, "salió una carta bloqueada: " + id)
	_ok(true, "no salen cartas bloqueadas")

	m.empezar_partida("heredera", 0)
	_ok(J.vida_max == 4 and J.oro == 40 and J.cartas[1] == "hucha", "la Heredera empieza con su mazo")
	m.jugador.recibir_golpe(1)
	_ok(J.vida == 4 and J.oro == 32, "la Heredera paga con monedas")

	m.empezar_partida("crupier", 3)
	_ok(J.precio_final(100) == 98, "descuento de la Crupier y recargo de la Mesa Negra")
	m.empezar_partida("tahur", 4)
	_ok(J.vida_max == 6, "la Mesa de Oro quita un corazón")

	m.empezar_partida("tahur", 0)
	J.dar_objeto("traje")
	J.dar_objeto("puro")
	_ok(J.transformaciones.is_empty(), "dos piezas no transforman")
	J.dar_objeto("whisky")
	_ok(J.transformaciones == ["mafioso"], "tres piezas forman al Mafioso")
	_ok(is_equal_approx(Combo.resolver(["bala"], J.contexto_combo()).total, 7.0), "el Mafioso da +2 de daño")
	J.dar_objeto("gafas")
	_ok(J.transformaciones.size() == 1, "no se transforma dos veces")

	J.oro = 10
	J.pedir_prestamo()
	_ok(J.oro == 50 and J.deuda == 60, "préstamo")
	var antes: int = J.vida_max
	J.cobrar_deuda()
	_ok(J.vida_max == antes - 2 and J.deuda == 0, "sin dinero te cobra un corazón")
	J.oro = 80
	J.pedir_prestamo()
	J.cobrar_deuda()
	_ok(J.oro == 60, "con dinero pagas la deuda")

	# Trileros de verdad: la moneda tiene que seguir bajo su copa tras mezclar.
	J.oro = 100
	var p = m._panel
	p.abrir("trileros")
	p._apostar_trileros(10)
	_ok(J.oro == 90, "apostar cobra")
	var bola_en: int = p._bola
	var hueco_antes: float = p._copas[bola_en]
	while p._fase != 3:  # ELEGIR
		await process_frame
	_ok(p._bola == bola_en and p._copas.duplicate().size() == 3, "la bola no cambia de copa")
	var huecos: Array = p._copas.duplicate()
	huecos.sort()
	_ok(huecos == [0.0, 1.0, 2.0], "las copas acaban en huecos distintos (empezó en %s)" % hueco_antes)
	p._elegir(bola_en)
	_ok(J.oro == 115, "acertar paga 2.5 veces")
	p._cerrar()

	for tipo in ["trileros", "doble_nada", "prestamista", "barra"]:
		for _r in 15:
			J.oro = 60
			J.vida = J.vida_max
			p.abrir(tipo)
			var pasos := 0
			while p.visible and pasos < 3000:
				p.actuar_al_azar()
				await process_frame
				pasos += 1
			if p.visible:
				_ok(false, "el evento %s no termina" % tipo)
			if J.oro < 0 or J.vida < 1:
				_ok(false, "%s dejó un estado imposible: oro %d vida %d" % [tipo, J.oro, J.vida])
			if m._barra.modo_sustituir:
				m._cerrar_selector()
	_ok(true, "los cuatro eventos terminan siempre")

	comprobar_extremo(m)
	await comprobar_guardado(m)
	comprobar_logros(m)
	await process_frame
	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)


func comprobar_extremo(m) -> void:
	m.empezar_partida("heredera", 0, true)
	_ok(J.extremo and J.vida == 2 and J.vida_max == 2, "extremo: un solo corazón, también con la Heredera")
	var tiendas := 0
	var tipos_evento := {}
	for c in m.salas:
		if m.salas[c].tipo == GeneradorMazmorra.Tipo.TIENDA:
			tiendas += 1
		if m.salas[c].tipo == GeneradorMazmorra.Tipo.EVENTO:
			tipos_evento[m.salas[c].evento] = true
	_ok(tiendas == 0, "extremo: no hay tienda")
	_ok(not tipos_evento.has("barra") and not tipos_evento.has("prestamista"), "extremo: sin barra ni prestamista")
	for _i in 200:
		var o: String = J.robar_objeto()
		if o == "herradura" or o == "seguro":
			_ok(false, "extremo: salió un objeto prohibido")
			break
	var c_jefe := Vector2i.ZERO
	for c in m.salas:
		if m.salas[c].tipo == GeneradorMazmorra.Tipo.JEFE:
			c_jefe = c
	m.entrar_sala(c_jefe, Vector2i.ZERO)
	_ok(is_equal_approx(m._horda.jefe.vida, 600.0), "extremo: el Pez Rojo tiene el triple de vida (%s)" % m._horda.jefe.vida)
	J.oro = 50
	m.jugador.recibir_golpe(1)
	_ok(J.vida == 0 and m._pantalla.visible and J.oro == 50, "extremo: un golpe y se acaba, sin pagar con monedas")
	m._ir_al_menu()
	m.empezar_partida("heredera", 0, false)
	_ok(not J.extremo and J.vida_max == 4, "fuera del extremo todo sigue igual")


func comprobar_guardado(m) -> void:
	m.empezar_partida("crupier", 2, false)
	await process_frame
	J.oro = 77
	J.dar_objeto("gafas")
	var c: Vector2i = m.salas.keys().filter(func(k): return m.salas[k].tipo == 3)[0]
	m.entrar_sala(c, Vector2i.ZERO)  # guarda al entrar
	var pos_salas: int = m.salas.size()
	var azar_antes: int = J.azar.state
	var cartas_antes: Array = J.cartas.duplicate()
	_ok(load("res://scripts/guardado.gd").hay_partida(), "se guarda al entrar en una sala")
	J.oro = 1
	J.objetos = []
	m._ir_al_menu()
	_ok("reanudar" in m._menu._items, "el menú ofrece continuar")
	m.continuar_partida()
	await process_frame
	_ok(J.oro == 77 and J.objetos == ["gafas"] and J.personaje == "crupier" and J.mesa == 2, "se recupera la partida")
	_ok(m.salas.size() == pos_salas and m.actual.pos == c and J.cartas == cartas_antes and J.azar.state == azar_antes, "se recupera la mazmorra y la sala")
	m._acabar(false)
	_ok(not load("res://scripts/guardado.gd").hay_partida(), "al terminar se borra el guardado")
	m._ir_al_menu()


func comprobar_logros(m) -> void:
	Progreso.logros = []
	Progreso.contadores = {"enemigos": 150}
	m.empezar_partida("tahur", 0)
	J.novedades = []
	J.revisar_logros()
	_ok(Progreso.logros.has("cien") and not Progreso.logros.has("mil"), "los logros miran los contadores")
	_ok(J.novedades.size() >= 2 and J.novedades[0].tipo == "logro", "los logros salen en la pantalla final")
	var a := Progreso.logros.size()
	J.revisar_logros()
	_ok(Progreso.logros.size() == a, "un logro no se consigue dos veces")
	_ok(J.orden_jefes.size() == 5 and J.orden_jefes[0] == "pez", "cinco jefes por partida y el pez primero")
	var hoy: String = J.fecha_hoy()
	Progreso.reto_fecha = ""
	Progreso.registrar_reto(hoy, 100)
	Progreso.registrar_reto(hoy, 300)
	Progreso.registrar_reto(hoy, 200)
	_ok(Progreso.reto_mejor_hoy(hoy) == 300, "el reto guarda la mejor marca del día")
	m.empezar_reto()
	var a1: Dictionary = {}
	for k in m.salas:
		a1[k] = m.salas[k].tipo
	m.empezar_reto()
	var igual: bool = a1.size() == m.salas.size()
	for k in a1:
		igual = igual and m.salas.has(k) and m.salas[k].tipo == a1[k]
	_ok(igual and J.diario and J.personaje == "tahur", "el reto diario da la misma mazmorra")
	m._ir_al_menu()

