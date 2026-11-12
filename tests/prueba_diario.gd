extends SceneTree
## El reto diario es igual para todos: misma mazmorra, mismas oleadas, tiendas, tesoros,
## eventos y jefes, juegue como juegue cada uno. Y otro día, otra cosa.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_diario.gd

const INICIO := 0
const NORMAL := 1
const TESORO := 2
const TIENDA := 3
const JEFE := 4
const EVENTO := 5
const FECHA := "2026-03-14"  # una fecha fija que no es hoy: el reto no puede depender del reloj

var _fallos := 0
var J: Node
var _guardado := {}


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
	_guardar_progreso()

	comprobar_formula()
	await comprobar_determinismo(m)
	comprobar_presion_normal(m)
	await comprobar_intentos(m)
	await comprobar_reto_caducado(m)

	m._ir_al_menu()
	_restaurar_progreso()
	load("res://scripts/guardado.gd").borrar()
	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)


## Las pruebas no pueden gastarte el reto de hoy ni tocar tus desbloqueos.
func _guardar_progreso() -> void:
	_guardado = {"reto_fecha": Progreso.reto_fecha, "reto_mejor": Progreso.reto_mejor, "reto_empezado": Progreso.reto_empezado,
		"reto_detalle": Progreso.reto_detalle.duplicate(), "reto_practica_fecha": Progreso.reto_practica_fecha,
		"reto_practica": Progreso.reto_practica, "cartas_extra": Progreso.cartas_extra.duplicate(),
		"objetos_extra": Progreso.objetos_extra.duplicate()}


func _restaurar_progreso() -> void:
	Progreso.reto_fecha = _guardado.reto_fecha
	Progreso.reto_mejor = _guardado.reto_mejor
	Progreso.reto_empezado = _guardado.reto_empezado
	Progreso.reto_detalle = _guardado.reto_detalle
	Progreso.reto_practica_fecha = _guardado.reto_practica_fecha
	Progreso.reto_practica = _guardado.reto_practica
	Progreso.cartas_extra = _guardado.cartas_extra
	Progreso.objetos_extra = _guardado.objetos_extra
	Progreso.guardar()


func comprobar_formula() -> void:
	_ok(J.calcular_puntos(0, false, 50, 0, 0, 0) == 0, "sin hacer nada, 0 puntos")
	_ok(J.calcular_puntos(2, false, 600, 300, 120, 4) == 2000 + 600 + 120 - 400, "pisos, bajas, monedas y golpes")
	_ok(J.calcular_puntos(5, true, 1000, 500, 300, 0) == 5000 + 5000 + 1000 + 300 + 500 * 3, "al ganar, bono por rapidez")
	_ok(J.calcular_puntos(5, true, 4000, 0, 0, 0) == 10000, "sin bono pasados 25 minutos")
	_ok(J.calcular_puntos(0, false, 50, 0, 0, 10) == 0, "nunca negativo")


## Recorre la mazmorra entera de un reto y anota todo lo que debería ser igual para todos.
## `paliza`: recibe golpes, gasta azar de combate a lo loco y no tiene nada desbloqueado.
## Si no, juega limpio y rápido con todo desbloqueado.
func recorrer(m, paliza: bool) -> Array:
	var huella: Array = []
	if paliza:
		Progreso.cartas_extra = []
		Progreso.objetos_extra = []
	else:
		Progreso.cartas_extra = CartasDB.CARTAS.keys()
		Progreso.objetos_extra = ObjetosDB.OBJETOS.keys()
	J.nueva_partida_reto(FECHA, true)
	m._arrancar()
	huella.append("jefes %s" % [J.orden_jefes])
	var basura := RandomNumberGenerator.new()
	basura.seed = 99 if paliza else 7
	for piso in range(1, J.PISOS_TOTALES + 1):
		if piso > 1:
			J.piso = piso
			m._generar_piso()
		var claves: Array = m.salas.keys()
		claves.sort()
		var mapa := ""
		for c in claves:
			mapa += "%s:%d:%d:%s " % [c, m.salas[c].tipo, m.salas[c].semilla, m.salas[c].get("evento", "")]
		huella.append("piso %d mapa %s" % [piso, mapa])
		for c in claves:
			var tipo: int = m.salas[c].tipo
			if tipo == INICIO:
				continue
			m.entrar_sala(c, Vector2i.ZERO)
			var s: Dictionary = m.actual
			var semilla: int = s.semilla
			match tipo:
				NORMAL:
					huella.append("sala %s %s regla=%s presupuesto=%.4f vida=%.4f oleadas=%s elites=%s" % [c, m._plan.perfil,
							m._plan.regla, m._plan.presupuesto, m._plan.vida, m._oleadas, m._elites])
					_pelear(m, paliza, basura)
					huella.append("tras %s prob_carta=%.2f eleccion=%s" % [c, m._prob_carta,
							J.robar_cartas(2, 0.0, J.azar_para(semilla, "eleccion"))])
				TIENDA:
					var ids: Array = s.tienda.map(func(a): return "%s/%d" % [a.id, a.precio])
					huella.append("tienda %s %s rebarajar=%s" % [c, ids, J.robar_cartas(3, 0.0, J.azar_para(semilla, "rebarajar1"))])
				TESORO:
					huella.append("tesoro %s %s cofre=%s" % [c, s.get("premio", ""), J.robar_cartas(3, 1.5, J.azar_para(semilla, "cofre"))])
				EVENTO:
					huella.append("evento %s %s tirada=%d" % [c, s.evento, J.azar_para(semilla, "evento").randi()])
				JEFE:
					huella.append("jefe %s %s premio=%s" % [c, J.jefe_del_piso(), J.robar_objeto([], J.azar_para(semilla, "premio"))])
					m._horda.limpiar()
					m.en_combate = false
					m._motor.parar()
	return huella


## Lo que haría un combate: según la conducta, golpes, prisa y azar gastado sin control.
func _pelear(m, paliza: bool, basura: RandomNumberGenerator) -> void:
	if paliza:
		for _i in 3:
			J.golpes += 1
			m._golpes_sala += 1
			m._sin_golpes = false
		for _i in basura.randi_range(5, 200):
			J.azar_combate.randf()
			J.azar.randi()  # aunque algo gastara el azar de la partida, no debería notarse
		m._sala_t = 999.0
	else:
		m._sala_t = 0.1
	m._oleadas = []
	m._por_nacer.clear()
	m._horda.limpiar()
	m._terminar_combate()


func comprobar_determinismo(m) -> void:
	var a := recorrer(m, true)
	_ok(is_equal_approx(J.presion, 1.0), "en el reto la presión no se mueve aunque te den (%.2f)" % J.presion)
	var b := recorrer(m, false)
	_ok(is_equal_approx(J.presion, 1.0), "ni aunque lo bordes (%.2f)" % J.presion)
	var distinto := -1
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			distinto = i
			break
	_ok(a.size() == b.size() and distinto == -1, "dos jugadores distintos, mismo reto (%d cosas comparadas)" % a.size())
	if distinto >= 0:
		print("   A: ", a[distinto])
		print("   B: ", b[distinto])
	var cuenta := {"sala": 0, "tienda": 0, "tesoro": 0, "evento": 0, "jefe": 0}
	for linea in a:
		var tipo: String = linea.split(" ")[0]
		if cuenta.has(tipo):
			cuenta[tipo] += 1
	_ok(cuenta.sala >= 20 and cuenta.tienda == 5 and cuenta.tesoro == 5 and cuenta.evento == 10 and cuenta.jefe == 5,
			"se han comparado salas, tiendas, tesoros, eventos y jefes de los 5 pisos (%s)" % [cuenta])
	var hubo_elites := false
	for linea in a:
		if "true" in linea.get_slice("elites=", 1):
			hubo_elites = true
	_ok(hubo_elites, "los élites también están en el plan (y coinciden)")
	# Otro día, otra mazmorra.
	var guardada := FECHA
	J.nueva_partida_reto("2026-03-15", true)
	m._arrancar()
	var otro_mapa := ""
	var claves: Array = m.salas.keys()
	claves.sort()
	for c in claves:
		otro_mapa += "%s:%d:%d:%s " % [c, m.salas[c].tipo, m.salas[c].semilla, m.salas[c].get("evento", "")]
	_ok("piso 1 mapa " + otro_mapa != a[1], "otro día da otra mazmorra")
	_ok(J.semilla_de("reto:" + guardada) == J.semilla_de("reto:" + FECHA) and J.semilla_de("x") != 0, "la semilla es estable")
	# Con todo desbloqueado, en el reto solo sale la bolsa de partida.
	Progreso.cartas_extra = CartasDB.CARTAS.keys()
	_ok(not J.carta_en_bolsa("laser") and Progreso.carta_libre("laser"), "en el reto no salen tus desbloqueos")
	m._ir_al_menu()
	await physics_frame


func comprobar_presion_normal(m) -> void:
	# Fuera del reto la presión sí se adapta a cómo juegas.
	m.empezar_partida("tahur", 0)
	var c: Vector2i = m.salas.keys().filter(func(k): return m.salas[k].tipo == NORMAL)[0]
	m.entrar_sala(c, Vector2i.ZERO)
	m._sala_t = 0.1
	m._oleadas = []
	m._horda.limpiar()
	m._terminar_combate()
	_ok(J.presion > 1.0, "en partida normal la presión sube si limpias sin golpes")
	m._ir_al_menu()


func comprobar_intentos(m) -> void:
	var hoy: String = J.fecha_hoy()
	Progreso.reto_empezado = ""
	Progreso.reto_fecha = ""
	Progreso.reto_practica_fecha = ""
	_ok(Progreso.reto_puntuable(hoy), "el primer intento del día puntúa")
	m.empezar_reto()
	_ok(J.diario and J.reto_puntuable and J.fecha_reto == hoy and not Progreso.reto_puntuable(hoy), "empezar gasta el intento")
	J.enemigos_eliminados = 100
	J.oro_total = 50
	J.golpes = 2
	J.piso = 2
	J.tiempo_partida = 400.0
	var esperados: int = J.calcular_puntos(1, false, 400, 100, 50, 2)
	m._acabar(false)
	_ok(Progreso.reto_mejor_hoy(hoy) == esperados and int(Progreso.reto_detalle.get("piso", 0)) == 2, "la marca y el resumen se guardan (%d)" % esperados)
	m._pantalla.visible = false
	m.empezar_reto()
	_ok(J.diario and not J.reto_puntuable, "el segundo intento es de práctica")
	J.enemigos_eliminados = 900
	J.piso = 4
	J.tiempo_partida = 900.0
	m._acabar(false)
	_ok(Progreso.reto_mejor_hoy(hoy) == esperados, "la práctica no cambia la marca")
	_ok(Progreso.practica_hoy(hoy) > esperados, "pero se apunta como práctica")
	m._pantalla.visible = false
	m._ir_al_menu()
	# La pantalla del reto lo enseña y su botón pasa a "PRACTICAR".
	m._reto.abrir()
	await process_frame
	_ok(m._reto.visible and not m._reto.hay_mundial(), "sin online.cfg no hay pestaña mundial")
	m._reto.tecla(KEY_RIGHT)
	_ok(m._reto._pestana == 0, "y las flechas no llevan a ninguna parte")
	m._reto.tecla(KEY_ESCAPE)
	_ok(not m._reto.visible, "Esc vuelve")


func comprobar_reto_caducado(m) -> void:
	# Un reto guardado ayer se puede terminar, pero ya no puntúa.
	Progreso.reto_empezado = ""
	m.empezar_reto()
	J.fecha_reto = "2000-01-01"
	m._guardar_punto()
	m._ir_al_menu()
	m.continuar_partida()
	await physics_frame
	_ok(J.diario and J.fecha_reto == "2000-01-01" and not J.reto_puntuable, "un reto de otro día ya no puntúa al continuarlo")
	m._ir_al_menu()
