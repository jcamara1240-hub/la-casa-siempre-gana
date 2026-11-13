extends SceneTree
## Cooperativo local: dos jugadores en la misma sala, con eventos inventados de dos
## dispositivos (en headless no hay mandos de verdad).
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_coop.gd

const CARTA := 2  # Recogible.Clase
const CORAZON := 1
const EVENTO := 7

var _fallos := 0
var Mando: GDScript = load("res://scripts/mando.gd")
var Combo: GDScript = load("res://scripts/combo.gd")
var Guardado: GDScript = load("res://scripts/guardado.gd")
var Progreso: GDScript = load("res://scripts/progreso.gd")
var J: Node
var m


func _initialize() -> void:
	_correr.call_deferred()


func _ok(condicion: bool, que: String) -> void:
	print("bien: " if condicion else "MAL:  ", que)
	if not condicion:
		_fallos += 1


func _esperar(fotogramas: int) -> void:
	for i in fotogramas:
		await physics_frame


func _boton(disp: int, boton: int, pulsado: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = disp
	e.button_index = boton
	e.pressed = pulsado
	e.pressure = 1.0 if pulsado else 0.0
	Input.parse_input_event(e)
	await process_frame


func _pulsar(disp: int, boton: int) -> void:
	await _boton(disp, boton, true)
	await _boton(disp, boton, false)


func _eje(disp: int, eje: int, valor: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = disp
	e.axis = eje
	e.axis_value = valor
	Input.parse_input_event(e)
	await process_frame


func _evento_tecla(codigo: Key, pulsada: bool, derecha := false) -> void:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.physical_keycode = codigo
	e.pressed = pulsada
	if derecha:
		e.location = KEY_LOCATION_RIGHT
	Input.parse_input_event(e)
	await process_frame


func _tecla(codigo: Key, derecha := false) -> void:
	await _evento_tecla(codigo, true, derecha)
	await _evento_tecla(codigo, false, derecha)


func _balas_propias() -> Array:
	return m._ataques.get_children().filter(func(h): return h.get("_ataque") != null and not h._enemigo and not h.is_queued_for_deletion())


func _limpiar_suelo() -> void:
	for r in m._recogibles.get_children():
		r.queue_free()
	await process_frame


func _correr() -> void:
	J = root.get_node("Juego")
	DirAccess.remove_absolute("user://partida.sav")
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	Mando.vibracion = true
	await _seleccion()
	await _en_sala()
	await _persecucion()
	await _danos_y_caidas()
	await _cartas()
	await _ordagos()
	await _equilibrio()
	await _guardado()
	await _desconexion_y_paneles()
	await _fin_de_partida()
	await _paneles_con_teclado()
	await _fila_con_dos_mandos()
	await _solitario()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ------------------------------------------------ selección de personaje
func _seleccion() -> void:
	m._menu.cerrar()
	var sel = m._seleccion
	Mando.activo = false
	sel._indice = 0
	sel.abrir()
	_ok(sel.visible and not sel.j2_unido() and sel.entrada_j1 == Mando.TECLADO, "se abre la selección con el J1 en el teclado y sin J2")
	_ok(sel.hay_coop(), "con teclado el cooperativo se ofrece")
	await _pulsar(1, JOY_BUTTON_A)
	_ok(not sel.j2_unido() and sel.entrada_j1 == 1, "A en un mando no une a nadie: es el J1 que coge el mando")
	await _tecla(KEY_ESCAPE)  # (el teclado vuelve a ser del J1; Esc saldría: se vuelve a abrir)
	if not sel.visible:
		m._menu.cerrar()
		sel.abrir()
	_ok(sel.entrada_j1 == Mando.TECLADO, "al tocar el teclado el J1 vuelve a él")
	await _pulsar(1, JOY_BUTTON_START)
	_ok(sel.j2_unido() and int(sel._j2.entrada) == 1, "START en otro mando une al J2")
	var i1: int = sel._indice
	var i2: int = sel._j2.indice
	var libres: int = PersonajesDB_libres()
	await _pulsar(1, JOY_BUTTON_DPAD_RIGHT)
	_ok(sel._indice == i1, "la cruceta del J2 no mueve el cursor del J1")
	_ok((sel._j2.indice != i2) == (libres > 1), "el J2 elige su personaje (solo entre los libres)")
	var i2b: int = sel._j2.indice
	await _tecla(KEY_RIGHT)
	_ok(sel._indice != i1 and sel._j2.indice == i2b, "el teclado sigue siendo del J1")
	sel._indice = i1
	await _pulsar(1, JOY_BUTTON_B)
	_ok(not sel.j2_unido(), "B en su mando saca al J2")
	await _tecla(KEY_CTRL, true)
	_ok(sel.j2_unido() and int(sel._j2.entrada) == Mando.TECLADO_DER and sel.entrada_j1 == Mando.TECLADO_IZQ, "Ctrl derecho reparte el teclado: J1 WASD y J2 flechas")
	await _tecla(KEY_LEFT)
	_ok(sel._indice == i1, "con el teclado repartido las flechas son del J2")
	await _tecla(KEY_BACKSPACE)
	_ok(not sel.j2_unido() and sel.entrada_j1 == Mando.TECLADO, "Retroceso saca al J2 y el teclado vuelve entero al J1")
	await _pulsar(1, JOY_BUTTON_START)
	sel._indice = 0
	sel._j2.indice = 0
	sel._modo = 0
	var cfg: Dictionary = sel.config_coop()
	_ok(cfg.get("entrada1") == Mando.TECLADO and cfg.get("entrada2") == 1 and cfg.get("personaje2") == sel._ids[0], "la selección da a main el personaje y los dispositivos de cada uno")
	sel._empezar()
	await _esperar(3)
	_ok(J.coop and m.jugadores.size() == 2 and m.jugador2 != null and not sel.visible, "empieza una partida cooperativa con dos jugadores")
	_ok(m.jugador.entrada == Mando.TECLADO and m.jugador2.entrada == 1, "cada jugador tiene su dispositivo")
	_ok(J.vida2 == J.vida_max2 and J.vida_max2 > 0 and J.personaje2 == J.personaje, "el J2 tiene sus corazones")
	_ok(m.jugador2.get_node("Sprite").modulate != Color.WHITE, "con el mismo personaje, el J2 va teñido")
	_ok(m._horda.jugadores.size() == 2 and m._ataques.jugadores.size() == 2, "la horda y los ataques ven a los dos")


func PersonajesDB_libres() -> int:
	var n := 0
	for id in m._seleccion._ids:
		if Progreso.personaje_libre(id):
			n += 1
	return n


# ------------------------------------------------ cada dispositivo mueve a su jugador
func _en_sala() -> void:
	var j1 = m.jugador
	var j2 = m.jugador2
	j1.invulnerable = true
	j2.invulnerable = true
	j1.position = Vector2(220, 160)
	j2.position = Vector2(400, 160)
	await _esperar(2)
	var p1: Vector2 = j1.position
	var p2: Vector2 = j2.position
	await _eje(1, JOY_AXIS_LEFT_X, 1.0)
	await _esperar(12)
	await _eje(1, JOY_AXIS_LEFT_X, 0.0)
	await _esperar(6)
	_ok(j2.position.x > p2.x + 15.0, "el stick del mando 1 mueve al J2")
	_ok(j1.position.distance_to(p1) < 1.0, "y no al J1")
	p1 = j1.position
	p2 = j2.position
	await _evento_tecla(KEY_D, true)
	await _esperar(12)
	await _evento_tecla(KEY_D, false)
	await _esperar(6)
	_ok(j1.position.x > p1.x + 15.0, "la D mueve al J1")
	_ok(j2.position.distance_to(p2) < 1.0, "y no al J2")
	# La voltereta de cada uno.
	await _pulsar(1, JOY_BUTTON_A)
	await _esperar(1)
	_ok(j2.rodando() and not j1.rodando(), "A en el mando 1 hace rodar al J2")
	await _esperar(30)
	await _tecla(KEY_SPACE)
	await _esperar(1)
	_ok(j1.rodando() and not j2.rodando(), "Espacio hace rodar al J1")
	await _esperar(30)


# ------------------------------------------------ los enemigos van a por el más cercano
func _persecucion() -> void:
	var j1 = m.jugador
	var j2 = m.jugador2
	j1.position = Vector2(100, 160)
	j2.position = Vector2(420, 160)
	var e = m._horda.crear("dado", Vector2(500, 160))
	e.nacer_ya()
	await _esperar(15)
	_ok(m._horda.objetivo_para(e.position) == j2, "el más cercano al enemigo es el J2")
	_ok(e._blanco(m._horda) == j2, "y el enemigo va a por él")
	var antes: float = e.position.distance_to(j2.position)
	await _esperar(20)
	_ok(e.position.distance_to(j2.position) < antes, "se le acerca")
	m._caer(j2)
	_ok(m._horda.objetivo_para(e.position) == j1, "con el J2 fuera de juego va a por el J1")
	m._levantar(j2, J.vida_max2)
	_ok(not j2.caido, "se levanta")
	m._horda.limpiar()
	await _esperar(1)


# ------------------------------------------------ daño por separado, caída y reanimación
func _danos_y_caidas() -> void:
	var j1 = m.jugador
	var j2 = m.jugador2
	m._jugo.limpiar()
	for j in [j1, j2]:
		j.invulnerable = false
		j._invulnerable_t = 0.0
	var v1: int = J.vida
	var v2: int = J.vida2
	j2.recibir_golpe(1)
	_ok(J.vida == v1 and J.vida2 < v2, "un golpe al J2 solo le quita corazones a él")
	_ok(Mando.ultimo_vibrado == 1, "y vibra su mando")
	v2 = J.vida2
	j1.recibir_golpe(1)
	_ok(J.vida < v1 and J.vida2 == v2, "un golpe al J1 solo le quita a él")
	m._jugo.limpiar()
	# Una bala enemiga encima del J2: le da a él.
	j2._invulnerable_t = 0.0
	j1._invulnerable_t = 0.0
	j1.position = Vector2(100, 200)
	j2.position = Vector2(400, 200)
	v1 = J.vida
	v2 = J.vida2
	m._ataques.bala_enemiga(j2.position + Vector2(-20, 0), Vector2(200, 0))
	await _esperar(12)
	_ok(J.vida2 < v2 and J.vida == v1, "la bala enemiga golpea al jugador que toca")
	m._jugo.limpiar()

	# Cae el J2: la partida sigue.
	J.vida2 = 1
	j2._invulnerable_t = 0.0
	j2.recibir_golpe(1)
	await _esperar(2)
	_ok(j2.caido and not m._pantalla.visible and not paused, "el J2 queda fuera de juego y la partida sigue")
	j2.recibir_golpe(1)
	_ok(J.vida2 == 0, "en el suelo no le pegan")
	j1.invulnerable = true
	j1.position = j2.position + Vector2(10, 0)
	await _esperar(90)
	_ok(j2.caido and j2.reanimar > 0.4, "al lado, la barra de reanimación se llena")
	j1.invulnerable = false
	j1._invulnerable_t = 0.0
	j1.recibir_golpe(1)
	_ok(j2.reanimar == 0.0, "un golpe al que reanima la corta")
	j1.invulnerable = true
	await _esperar(230)
	_ok(not j2.caido and J.vida2 == m.REANIMAR_VIDA, "a los 3 segundos al lado se levanta con un corazón")
	m._jugo.limpiar()

	# Vuelve a caer, nadie lo levanta: al limpiar la sala vuelve con medio corazón.
	J.vida2 = 1
	j2._invulnerable_t = 0.0
	j2.recibir_golpe(1)
	j1.position = j2.position + Vector2(200, 0)
	await _esperar(30)
	_ok(j2.caido and j2.reanimar == 0.0, "lejos no se reanima")
	m._empezar_combate()
	m._oleadas.clear()
	m._elites.clear()
	m._por_nacer.clear()
	m._sala_previstos = 0
	m._horda.limpiar()
	await _esperar(3)
	_ok(not m.en_combate, "la sala se limpia")
	_ok(not j2.caido and J.vida2 == m.VIDA_AL_LIMPIAR, "y el caído vuelve con medio corazón")
	await _limpiar_suelo()
	m._jugo.limpiar()


# ------------------------------------------------ cartas: salen de los dos al 60 %
func _cartas() -> void:
	var j1 = m.jugador
	var j2 = m.jugador2
	j1.position = Vector2(200, 200)
	j2.position = Vector2(440, 200)
	var e = m._horda.crear("dado", Vector2(320, 90))
	e.nacer_ya()
	e.vida = 99999.0
	e.vida_max = 99999.0
	await _esperar(15)
	m._ataques.limpiar()
	await process_frame
	var a: Dictionary = Combo.ataque_suelto("bala", 10.0, 1)
	m._ataques.lanzar(a)
	var balas := _balas_propias()
	_ok(balas.size() == 2, "una carta de ataque sale de los dos jugadores")
	_ok(balas.all(func(b): return is_equal_approx(float(b._ataque.dano), 6.0)), "cada una al 60 % del daño")
	_ok(balas.any(func(b): return b.position.distance_to(j1.position) < 2.0) and balas.any(func(b): return b.position.distance_to(j2.position) < 2.0), "cada una desde su jugador")
	_ok(is_equal_approx(float(a.dano), 10.0), "la carta original no se toca")
	m._ataques.limpiar()
	await process_frame
	m._caer(j2)
	m._ataques.lanzar(a)
	balas = _balas_propias()
	_ok(balas.size() == 1 and balas[0].position.distance_to(j1.position) < 2.0, "con uno fuera de juego, solo sale del otro")
	m._levantar(j2, J.vida_max2)
	m._ataques.limpiar()
	# La navaja gira alrededor de quien la lanza.
	var navaja: Dictionary = Combo.ataque_suelto("cuchilla", 5.0, 1)
	if navaja.id == "cuchilla":
		m._ataques.lanzar(navaja)
		var cuchillas: Array = m._ataques.get_children().filter(func(h): return h.get("_eje") != null)
		_ok(cuchillas.size() == 2 and cuchillas.any(func(c): return c._eje == j2), "la navaja gira alrededor de cada jugador")
	m._ataques.limpiar()
	m._horda.limpiar()
	await _esperar(1)


# ------------------------------------------------ órdagos: reserva común
func _ordagos() -> void:
	# Un enemigo duro y lejos, para que la pelea no se dé por acabada.
	var e = m._horda.crear("dado", Vector2(600, 60))
	e.nacer_ya()
	e.vida = 99999.0
	e.vida_max = 99999.0
	await _esperar(15)
	m.en_combate = true
	J.ordagos = 2
	await _pulsar(1, JOY_BUTTON_X)
	_ok(J.ordagos == 1, "el J2 lanza un órdago de la reserva común")
	await _tecla(KEY_Q)
	_ok(J.ordagos == 0, "y el J1 el siguiente")
	await _pulsar(1, JOY_BUTTON_X)
	_ok(J.ordagos == 0, "sin órdagos no sale ninguno")
	m.en_combate = false
	m._horda.limpiar()
	m._jugo.limpiar()
	_ok(Mando.entrada_de(_tecla_ev(KEY_SHIFT, true)) == Mando.TECLADO_DER and Mando.entrada_de(_tecla_ev(KEY_SHIFT, false)) == Mando.TECLADO_IZQ, "Mayús derecha es del J2 y la izquierda del J1")
	_ok(Mando.entrada_de(_tecla_ev(KEY_END, false)) == Mando.TECLADO_DER and Mando.entrada_de(_tecla_ev(KEY_E, false)) == Mando.TECLADO_IZQ, "Fin es del J2 y la E del J1")


## Un evento de ratón sobre una ranura de la fila (en sus coordenadas): movimiento si
## "pulsado" es null; si no, el botón izquierdo pulsado o soltado.
func _raton_en_ranura(barra, ranura: int, pulsado) -> InputEvent:
	var p: Vector2 = barra.ORIGEN + Vector2(ranura * barra.ANCHO_RANURA + 16, 20)
	if pulsado == null:
		var mov := InputEventMouseMotion.new()
		mov.position = p
		return mov
	var clic := InputEventMouseButton.new()
	clic.position = p
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = pulsado
	return clic


func _tecla_ev(codigo: Key, derecha: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.physical_keycode = codigo
	e.pressed = true
	if derecha:
		e.location = KEY_LOCATION_RIGHT
	return e


# ------------------------------------------------ equilibrio
func _coste(oleadas: Array) -> int:
	var costes := {}
	for fila in m.CATALOGO:
		costes[fila[0]] = int(fila[1])
	var total := 0
	for grupo in oleadas:
		for tipo in grupo:
			total += int(costes[tipo])
	return total


func _equilibrio() -> void:
	m._plan = {"presupuesto": 1.0, "reparto": [0.3, 0.3, 0.4], "elites": 1.0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var coop := _coste(m._planificar_oleadas(rng))
	J.coop = false
	rng.seed = 1234
	var solo := _coste(m._planificar_oleadas(rng))
	J.coop = true
	_ok(coop >= solo * 1.4 and coop <= solo * 1.6 + 6, "en cooperativo la sala trae x1,5 de enemigos (%d frente a %d)" % [coop, solo])
	J.coop = false
	m._empezar_jefe()
	var vida_solo: float = m._horda.jefe.vida_max
	m._horda.limpiar()
	m._motor.parar()
	J.coop = true
	m._empezar_jefe()
	var vida_coop: float = m._horda.jefe.vida_max
	m._horda.limpiar()
	m._motor.parar()
	m.en_combate = false
	m._barra.en_combate = false
	m._jugo.limpiar()
	_ok(absf(vida_coop / vida_solo - m.COOP_VIDA_JEFE) < 0.01, "y los jefes x1,6 de vida")
	await _esperar(2)


# ------------------------------------------------ guardado y continuar
func _guardado() -> void:
	J.vida2 = J.vida_max2 - 1
	m._guardar_punto()
	var datos: Dictionary = Guardado.cargar()
	_ok(datos.juego.get("coop") == true and datos.juego.get("personaje2") == J.personaje2 and int(datos.juego.get("vida2")) == J.vida2, "la partida guardada recuerda que era cooperativa (personaje y vida del J2)")
	var v2: int = J.vida2
	m._ir_al_menu()
	m._menu.cerrar()
	Mando.activo = false
	m.continuar_partida()
	_ok(m._letrero_coop.visible and paused and not m._espera_j2.is_empty(), "al continuar, se espera a que el J2 vuelva a unirse")
	await _pulsar(1, JOY_BUTTON_DPAD_DOWN)
	_ok(not m._espera_j2.is_empty() and m._espera_j2.entrada1 == 1, "un botón cualquiera de otro mando no lo une (es el J1, que coge el mando)")
	await _tecla(KEY_D)
	await _pulsar(1, JOY_BUTTON_START)
	await _esperar(2)
	_ok(m._espera_j2.is_empty() and J.coop and m.jugador2 != null and J.vida2 == v2 and m.jugador2.entrada == 1 and not paused, "con START en su mando vuelve con su vida")
	m._guardar_punto()
	m._ir_al_menu()
	m._menu.cerrar()
	m.continuar_partida()
	await _tecla(KEY_ENTER)
	await _esperar(2)
	_ok(not J.coop and m.jugador2 == null and m.jugadores.size() == 1 and m.jugador.entrada == Mando.TODO, "si el J1 acepta sin él, se sigue en solitario")
	_ok(m._aviso.text != "", "con aviso")


# ------------------------------------------------ mando desconectado y paneles de uno
func _desconexion_y_paneles() -> void:
	m._ir_al_menu()
	m._menu.cerrar()
	m._coop_cfg = {"personaje2": "tahur", "entrada1": 0, "entrada2": 1}
	m.empezar_partida("tahur", 0)
	await _esperar(3)
	var j1 = m.jugador
	var j2 = m.jugador2
	_ok(J.coop and j1.entrada == 0 and j2.entrada == 1 and j1.tambien_teclado, "dos mandos (y el teclado, del J1)")
	m._al_cambiar_mando(1, false)
	_ok(paused and m._menu.visible and m._letrero_coop.visible, "si se desconecta el mando del J2, pausa con aviso")
	m._menu.cerrar()
	m._reanudar()
	_ok(not paused and not m._letrero_coop.visible, "al reanudar se quita el aviso")
	# El J2 coge una carta del suelo: el selector es suyo.
	j1.invulnerable = true
	j2.invulnerable = true
	j1.position = Vector2(120, 200)
	j2.position = Vector2(480, 200)
	m._crear_recogible(CARTA, Progreso.ruta_dorso(), j2.position)
	await _esperar(3)
	_ok(m._selector.visible and m._dueno_panel == j2 and J.titular == 1, "el J2 coge una carta: el selector lo maneja él")
	await _esperar(30)  # el selector tiene un momento de seguro
	var antes: int = m._selector._sobre
	await _pulsar(0, JOY_BUTTON_DPAD_RIGHT)
	_ok(m._selector._sobre == antes, "el mando del J1 no lo toca")
	await _pulsar(1, JOY_BUTTON_DPAD_RIGHT)
	_ok(m._selector._sobre != antes, "el del J2 sí")
	m._cerrar_selector()
	await _pulsar(0, JOY_BUTTON_DPAD_LEFT)
	_ok(m._dueno_panel == null and J.titular == 0, "al cerrarse, el panel no es de nadie")
	await _limpiar_suelo()
	# Los corazones del suelo son de quien los coge.
	J.vida = J.vida_max - 1
	J.vida2 = J.vida_max2 - 1
	var c = m._crear_recogible(CORAZON, "res://assets/objetos/corazon.png", j2.position)
	c.hframes = 3
	await _esperar(3)
	_ok(J.vida2 == J.vida_max2 and J.vida == J.vida_max - 1, "el corazón cura a quien lo coge")
	await _limpiar_suelo()


# ------------------------------------------------ fin de partida solo si caen los dos
func _fin_de_partida() -> void:
	var j1 = m.jugador
	var j2 = m.jugador2
	m._jugo.limpiar()
	j1.invulnerable = false
	j2.invulnerable = false
	j1._invulnerable_t = 0.0
	J.vida = 1
	j1.recibir_golpe(1)
	await _esperar(2)
	_ok(j1.caido and not m._pantalla.visible and not paused, "si cae el J1, el J2 sigue jugando")
	_ok(m._horda.objetivo_para(Vector2(100, 100)) == j2, "y los enemigos van a por el J2")
	m._jugo.limpiar()
	J.vida2 = 1
	j2._invulnerable_t = 0.0
	j2.recibir_golpe(1)
	await _esperar(2)
	_ok(m._pantalla.visible and paused, "si caen los dos, fin de partida")
	m._ir_al_menu()


# ------------------------------------------------ teclado repartido: el J2 maneja lo suyo con sus teclas
## Con el teclado repartido el ratón es del J1: lo que abre el J2 (la caja fuerte y los demás
## eventos, la carta del suelo, qué carta cambiar) solo lo puede manejar él, con flechas e Intro.
func _paneles_con_teclado() -> void:
	m._menu.cerrar()
	m._coop_cfg = {"personaje2": "tahur", "entrada1": Mando.TECLADO_IZQ, "entrada2": Mando.TECLADO_DER}
	m.empezar_partida("tahur", 0)
	await _esperar(3)
	# Al continuar, el letrero dice que el J2 vuelve con el 5.
	m._guardar_punto()
	m._ir_al_menu()
	m._menu.cerrar()
	Mando.activo = false
	m.continuar_partida()
	await _tecla(KEY_5)
	await _esperar(2)
	_ok(m._espera_j2.is_empty() and J.coop and m.jugador2 != null and m.jugador.entrada == Mando.TECLADO_IZQ and m.jugador2.entrada == Mando.TECLADO_DER,
			"al continuar, el 5 une al J2 con el teclado repartido")
	if not m._espera_j2.is_empty():
		await _tecla(KEY_CTRL, true)
		await _esperar(2)
	var j1 = m.jugador
	var j2 = m.jugador2
	j1.invulnerable = true
	j2.invulnerable = true
	j1.position = Vector2(120, 200)
	j2.position = Vector2(480, 200)
	await _limpiar_suelo()
	J.cartas = ["bala", "dados", "", "", ""]
	J.cartas_cambiadas.emit()

	# La caja fuerte, abierta por el J2.
	var panel = m._panel
	m.actual["evento"] = "caja_fuerte"
	m.actual["evento_hecho"] = false
	J.oro = 40
	var npc = m._crear_recogible(EVENTO, "res://assets/personajes/npc.png", j2.position)
	npc.hframes = 6
	await _esperar(3)
	_ok(panel.visible and m._dueno_panel == j2 and J.titular == 1, "el J2 llega a la caja fuerte: el panel es suyo")
	await _esperar(30)  # el panel tiene un momento de seguro
	await _tecla(KEY_S)
	await _tecla(KEY_E)
	_ok(panel.visible and panel._fase == panel.Fase.MENU and panel._sobre == -1, "las teclas del J1 no tocan el panel del J2")
	await _tecla(KEY_DOWN)
	_ok(panel._sobre == 0, "la flecha del J2 señala la primera caja")
	await _tecla(KEY_ENTER)
	_ok(panel._fase == panel.Fase.FIN, "e Intro la abre")
	await _tecla(KEY_DOWN)
	await _tecla(KEY_ENTER)
	_ok(not panel.visible and m.actual.get("evento_hecho", false) and not paused, "y con Intro en Marcharse se va")
	if panel.visible:
		panel._cerrar()
	if m._barra.modo_sustituir:
		m._cerrar_selector()
	await _limpiar_suelo()

	# El prestamista va igual (todos los eventos usan el mismo panel).
	m.actual["evento"] = "prestamista"
	m.actual["evento_hecho"] = false
	J.deuda = 0
	J.oro = 0
	npc = m._crear_recogible(EVENTO, "res://assets/personajes/npc.png", j2.position)
	npc.hframes = 6
	await _esperar(3)
	await _esperar(30)
	await _tecla(KEY_DOWN)
	await _tecla(KEY_DOWN)
	await _tecla(KEY_END)
	_ok(J.deuda == 60 and J.oro == 40, "el J2 pide el préstamo con sus teclas (Fin también acepta)")
	if panel.visible:
		panel._cerrar()
	await _limpiar_suelo()

	# Y si lo abre el J1, va con las suyas (WASD y E) y las del J2 no cuentan.
	m.actual["evento"] = "mendigo"
	m.actual["evento_hecho"] = false
	J.oro = 10
	npc = m._crear_recogible(EVENTO, "res://assets/personajes/npc.png", j1.position)
	npc.hframes = 6
	await _esperar(3)
	_ok(panel.visible and m._dueno_panel == j1 and J.titular == 0, "el J1 llega al mendigo: el panel es suyo")
	await _esperar(30)
	await _tecla(KEY_DOWN)
	await _tecla(KEY_ENTER)
	_ok(panel._fase == panel.Fase.MENU and J.oro == 10, "las teclas del J2 no tocan el panel del J1")
	await _tecla(KEY_S)
	await _tecla(KEY_E)
	_ok(panel._fase == panel.Fase.FIN, "con S y E el J1 le da las monedas")
	if panel.visible:
		panel._cerrar()
	await _limpiar_suelo()

	# La carta del suelo: el selector del J2 va con sus flechas e Intro.
	J.cartas = ["bala", "dados", "bala", "dados", "bala"]
	J.cartas_cambiadas.emit()
	m._crear_recogible(CARTA, Progreso.ruta_dorso(), j2.position)
	await _esperar(3)
	var selector = m._selector
	_ok(selector.visible and m._dueno_panel == j2, "el J2 coge una carta del suelo: el selector es suyo")
	await _esperar(30)
	await _tecla(KEY_D)
	await _tecla(KEY_E)
	_ok(selector.visible and selector._sobre < 0, "las teclas del J1 no lo tocan")
	await _tecla(KEY_RIGHT)
	await _tecla(KEY_RIGHT)
	var elegida: String = selector._ids[1] if selector._ids.size() > 1 else ""
	_ok(selector._sobre == 1, "las flechas del J2 cambian de carta")
	await _tecla(KEY_ENTER)
	var barra = m._barra
	_ok(not selector.visible and barra.modo_sustituir and paused, "Intro la elige y, con la fila llena, toca decir cuál cambiar")
	# Qué carta cambiar: también con sus teclas.
	var antes: Array = J.cartas.duplicate()
	await _tecla(KEY_D)
	await _tecla(KEY_E)
	_ok(barra.modo_sustituir and J.cartas == antes, "las del J1 no cambian ninguna")
	await _tecla(KEY_RIGHT)
	var hueco: int = barra._cursor
	_ok(barra._cursor_visible(), "se ve el cursor en la fila")
	await _tecla(KEY_ENTER)
	_ok(not barra.modo_sustituir and not paused and J.cartas[hueco] == elegida, "Intro cambia la señalada")
	if selector.visible or barra.modo_sustituir:
		m._cerrar_selector()
	await _limpiar_suelo()
	m._ir_al_menu()


# ------------------------------------------------ dos mandos: la fila la maneja quien la coge
func _fila_con_dos_mandos() -> void:
	m._menu.cerrar()
	m._coop_cfg = {"personaje2": "tahur", "entrada1": 0, "entrada2": 1}
	m.empezar_partida("tahur", 0)
	await _esperar(3)
	var j1 = m.jugador
	var j2 = m.jugador2
	var barra = m._barra
	j1.invulnerable = true
	j2.invulnerable = true
	j1.position = Vector2(120, 200)
	j2.position = Vector2(480, 200)
	await _limpiar_suelo()
	J.cartas = ["bala", "dados", "bala", "", ""]
	J.cartas_cambiadas.emit()
	await _esperar(2)
	# El J1 ordena la fila con su mando; el J2 sigue a lo suyo.
	await _pulsar(0, JOY_BUTTON_BACK)
	_ok(barra.modo_cartas, "Select en el mando del J1 entra a ordenar")
	var cursor: int = barra._cursor
	await _pulsar(1, JOY_BUTTON_DPAD_RIGHT)
	_ok(barra._cursor == cursor, "la cruceta del J2 no mueve el cursor del J1")
	await _pulsar(1, JOY_BUTTON_A)
	_ok(barra._arrastrando == -1, "ni su A le coge una carta")
	await _esperar(30)
	var p2: Vector2 = j2.position
	await _eje(1, JOY_AXIS_LEFT_X, 1.0)
	await _esperar(12)
	await _eje(1, JOY_AXIS_LEFT_X, 0.0)
	await _esperar(6)
	_ok(j2.position.x > p2.x + 15.0 and barra._cursor == cursor, "el J2 sigue andando mientras el J1 ordena")
	var p1: Vector2 = j1.position
	await _pulsar(0, JOY_BUTTON_DPAD_RIGHT)
	_ok(barra._cursor != cursor, "la cruceta del J1 sí mueve su cursor")
	await _eje(0, JOY_AXIS_LEFT_X, -1.0)
	await _esperar(12)
	await _eje(0, JOY_AXIS_LEFT_X, 0.0)
	_ok(j1.position.distance_to(p1) < 1.0, "y el J1, que ordena, no anda")
	for i in J.cartas.size():
		if barra._cursor == 0:
			break
		await _pulsar(0, JOY_BUTTON_DPAD_LEFT)
	await _pulsar(0, JOY_BUTTON_A)
	var destino: int = barra._destino
	barra._gui_input(_raton_en_ranura(barra, (destino + 1) % J.cartas.size(), null))
	_ok(barra._arrastrando != -1 and barra._destino == destino, "mientras un mando ordena, el ratón no le mueve la carta")
	await _pulsar(0, JOY_BUTTON_B)
	await _pulsar(0, JOY_BUTTON_B)
	_ok(not barra.modo_cartas and not Mando.bloqueado, "B en su mando sale de ordenar")
	# Con una carta cogida con el ratón, Select no entra (si no, A soltaría la carta del otro).
	barra._gui_input(_raton_en_ranura(barra, 0, true))
	await _pulsar(0, JOY_BUTTON_BACK)
	_ok(not barra.modo_cartas, "con una carta cogida con el ratón no se entra a ordenar")
	barra._gui_input(_raton_en_ranura(barra, 0, false))

	# El J2 coge una carta con la fila llena: qué carta cambiar lo decide él.
	J.cartas = ["bala", "dados", "bala", "dados", "bala"]
	J.cartas_cambiadas.emit()
	m._crear_recogible(CARTA, Progreso.ruta_dorso(), j2.position)
	await _esperar(3)
	await _esperar(30)
	await _pulsar(1, JOY_BUTTON_DPAD_RIGHT)
	await _pulsar(1, JOY_BUTTON_A)
	_ok(not m._selector.visible and barra.modo_sustituir and m._dueno_panel == j2, "el J2 elige una carta del suelo con la fila llena")
	var antes: Array = J.cartas.duplicate()
	await _pulsar(0, JOY_BUTTON_A)
	await _pulsar(0, JOY_BUTTON_B)
	_ok(barra.modo_sustituir and J.cartas == antes, "el mando del J1 ni cambia ni cancela la carta del J2")
	await _pulsar(1, JOY_BUTTON_DPAD_RIGHT)
	var hueco: int = barra._cursor
	var nueva: String = m._carta_pendiente
	await _pulsar(1, JOY_BUTTON_A)
	_ok(not barra.modo_sustituir and nueva != "" and J.cartas[hueco] == nueva, "el del J2 sí")
	if m._selector.visible or barra.modo_sustituir:
		m._cerrar_selector()
	await _limpiar_suelo()
	m._ir_al_menu()


# ------------------------------------------------ un jugador: como siempre
func _solitario() -> void:
	m._menu.cerrar()
	m._coop_cfg = {}
	m.empezar_partida("tahur", 0)
	await _esperar(3)
	var j1 = m.jugador
	_ok(not J.coop and m.jugadores.size() == 1 and m.jugador2 == null, "sin J2, la partida es de uno")
	_ok(j1.entrada == Mando.TODO and j1.collision_layer == 1 and not j1.en_coop, "el jugador lo maneja todo, como siempre")
	_ok(m._horda.objetivo_para(Vector2(9, 9)) == j1 and m._horda.vivos() == [j1], "todo va a por él")
	var e = m._horda.crear("dado", Vector2(320, 90))
	e.nacer_ya()
	e.vida = 99999.0
	await _esperar(15)
	m._ataques.limpiar()
	await process_frame
	m._ataques.lanzar(Combo.ataque_suelto("bala", 10.0, 1))
	var balas := _balas_propias()
	_ok(balas.size() == 1 and is_equal_approx(float(balas[0]._ataque.dano), 10.0), "las cartas, al 100 % y desde él")
	m._horda.limpiar()
	m._ataques.limpiar()
	j1.invulnerable = true
	j1.position = Vector2(300, 200)
	await _esperar(2)
	var p: Vector2 = j1.position
	await _eje(1, JOY_AXIS_LEFT_X, 1.0)
	await _esperar(10)
	await _eje(1, JOY_AXIS_LEFT_X, 0.0)
	_ok(j1.position.x > p.x + 10.0, "cualquier mando lo mueve")
	await _esperar(6)
	p = j1.position
	await _evento_tecla(KEY_LEFT, true)
	await _esperar(10)
	await _evento_tecla(KEY_LEFT, false)
	_ok(j1.position.x < p.x - 10.0, "y las flechas también")
	_ok(J.vida_de(1) == J.vida and J.al_limite() == (J.vida > 0 and J.vida <= 2), "las vidas son las de siempre")
	m._ir_al_menu()
