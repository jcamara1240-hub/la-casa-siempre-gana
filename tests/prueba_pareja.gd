extends SceneTree
## Cooperativo online de verdad: dos juegos (anfitrión e invitado) contra el relé.
## No se lanza suelto: lo lleva tests/prueba_pareja.sh, que arranca el relé y los dos juegos.
##   godot --headless --path . -s res://tests/prueba_pareja.gd -- anfitrion|invitado ws://... fichero_del_codigo

const TIPO := preload("res://scripts/generador_mazmorra.gd").Tipo

var Red: GDScript = load("res://scripts/red.gd")
var Mando: GDScript = load("res://scripts/mando.gd")
var _fallos := 0
var J: Node
var m
var red
var pareja
var _papel := ""
var _fichero := ""


func _initialize() -> void:
	_correr.call_deferred()


func _ok(condicion: bool, que: String) -> void:
	print("[%s] %s%s" % [_papel, "bien: " if condicion else "MAL:  ", que])
	if not condicion:
		_fallos += 1


func _esperar(fotogramas: int) -> void:
	for i in fotogramas:
		await process_frame


func _segundos(s: float) -> void:
	var fin := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fin:
		await process_frame


## Espera a que pase algo (como mucho unos segundos de reloj) y dice si ha pasado.
func _hasta(condicion: Callable, segundos := 12.0) -> bool:
	var fin := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fin:
		if condicion.call():
			return true
		await process_frame
	return condicion.call()


func _correr() -> void:
	var args := OS.get_cmdline_user_args()
	_papel = args[0]
	_fichero = args[2]
	J = root.get_node("Juego")
	DirAccess.remove_absolute("user://partida.sav")
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	red = m._red
	pareja = m._pareja
	red.servidor = args[1]
	m._menu.cerrar()
	if _papel == "anfitrion":
		await _anfitrion()
	else:
		await _invitado()
	print("[%s] FALLOS: %d" % [_papel, _fallos])
	quit(1 if _fallos > 0 else 0)


func _sala_de_pelea() -> Vector2i:
	for c in m.salas:
		if m.salas[c].tipo == TIPO.NORMAL and not m.salas[c].get("limpia", false):
			return c
	return Vector2i(-99, -99)


# ------------------------------------------------ anfitrión
func _anfitrion() -> void:
	_ok(Red.empaquetar([1, "hola", Vector2(1, 2)]).size() > 0, "un mensaje se empaqueta")
	var grande: Array = [4, []]
	for i in 400:
		grande[1].append([i, Vector2(i, i), "enemigo"])
	var ida = Red.desempaquetar(Red.empaquetar(grande))
	_ok(ida is Array and ida[1].size() == 400 and ida[1][7][1] == Vector2(7, 7), "y uno grande va comprimido y vuelve igual")
	_lo_raro_no_rompe()
	m._sala_online.abrir()
	m._sala_online._activar("crear")
	_ok(await _hasta(func(): return red.en_sala() and red.codigo.length() == 4), "el anfitrión crea la sala y recibe un código")
	var f := FileAccess.open(_fichero, FileAccess.WRITE)
	f.store_string(red.codigo)
	f.close()
	_ok(await _hasta(func(): return red.hay_companero, 40.0), "el invitado entra en la sala")
	_ok(red.companero == "INVI", "y se ve su nombre")
	_ok(await _hasta(func(): return PersonajesDB_tiene(pareja.personaje_invitado)), "llega el personaje que ha elegido")
	var personaje2: String = pareja.personaje_invitado
	# Elegir y empezar.
	m._sala_online._activar("empezar")
	_ok(m._seleccion.visible and m._seleccion.es_online(), "«empezar» abre la selección con el invitado de J2")
	m._seleccion.visible = false
	m._al_elegir_personaje("tahur", 0, false, false)
	await _esperar(5)
	_ok(J.coop and m.jugador2 != null and m.jugador2.remoto and m.jugador2.remoto_manda, "la partida es cooperativa y el J2 es el del otro ordenador")
	_ok(J.personaje2 == personaje2, "con su personaje")
	_ok(pareja.jugando_anfitrion() and Red.reenviando, "el anfitrión cuenta la partida")
	# El invitado se mueve: su muñeco le sigue aquí.
	var j2 = m.jugador2
	var p0: Vector2 = j2.position
	_ok(await _hasta(func(): return j2.position.distance_to(p0) > 20.0), "el muñeco del J2 va adonde dice el invitado")
	_ok(await _hasta(func(): return j2.rodando()), "y rueda cuando él rueda")
	# Una carta a elegir que le toca al invitado: la elige él desde su ordenador.
	var cartas_db: GDScript = load("res://scripts/cartas_db.gd")
	var ids: Array = cartas_db.CARTAS.keys().filter(func(id): return not J.cartas.has(id)).slice(0, 2)
	m._tomar_panel(j2)
	m.abrir_selector(ids, "ELIGE UNA CARTA")
	_ok(m._selector.visible and paused and m._dueno_panel == j2, "el J2 coge una carta: se abre el selector a su nombre")
	_ok(await _hasta(func(): return not m._selector.visible, 20.0), "el invitado elige desde su ordenador")
	_ok(J.cartas.has(ids[0]) and not paused, "y la carta entra en la fila")
	# Un evento que abre el J2: el panel es del anfitrión y lo maneja el invitado.
	await _segundos(1.0)
	m._tomar_panel(j2)
	paused = true
	m._panel.abrir("mendigo", RandomNumberGenerator.new())
	_ok(m._panel.visible, "el J2 abre un evento")
	_ok(await _hasta(func(): return not m._panel.visible, 25.0), "el invitado lo cierra con sus teclas")
	_ok(not paused and m.actual.get("evento_hecho", false), "y la partida sigue")
	await _segundos(1.0)
	# Un evento del J1 (mío): con la partida parada por mí, el invitado abre su menú igual.
	m._tomar_panel(m.jugador)
	paused = true
	m._panel.abrir("mendigo", RandomNumberGenerator.new())
	_ok(await _hasta(func(): return pareja.pausa_remota, 20.0), "con un evento mío abierto, el invitado abre su menú")
	_ok(await _hasta(func(): return not pareja.pausa_remota, 20.0), "y lo vuelve a cerrar")
	m._panel._cerrar()
	_ok(not m._panel.visible and not paused, "cierro mi evento y la partida sigue")
	await _segundos(1.0)
	# Reanimación: el J2 cae, el J1 se queda a su lado y lo levanta.
	m.jugador.invulnerable = true
	J.vida2 = 1
	j2._invulnerable_t = 0.0
	j2.recibir_golpe(1)
	await _segundos(1.0)
	_ok(j2.caido and J.vida2 <= 0, "el J2 cae fuera de juego")
	m.jugador.position = j2.position + Vector2(8, 0)
	_ok(await _hasta(func(): return not j2.caido, 10.0), "el J1, a su lado, lo reanima")
	_ok(J.vida2 == m.REANIMAR_VIDA, "y se levanta con %d de vida (%d)" % [m.REANIMAR_VIDA, J.vida2])
	m.jugador.invulnerable = false
	await _segundos(1.0)
	# Una sala con pelea: los enemigos viajan.
	var c := _sala_de_pelea()
	_ok(c.x > -99, "hay una sala con pelea")
	m.entrar_sala(c, Vector2i.RIGHT)
	_ok(await _hasta(func(): return m.en_combate and m._horda.get_child_count() > 0), "empieza la pelea en el anfitrión")
	J.oro = 77
	J.estado_cambiado.emit()
	await _segundos(1.5)
	_ok(pareja.tics_enviados > 20, "manda tics (%d)" % pareja.tics_enviados)
	# El invitado pausa.
	_ok(await _hasta(func(): return pareja.pausa_remota and paused), "si el invitado pausa, aquí también se para")
	_ok(m._letrero_coop.visible, "y se avisa de quién ha pausado")
	_ok(await _hasta(func(): return not pareja.pausa_remota and not paused), "al reanudar él, sigue")
	# El invitado pierde la conexión y vuelve.
	_ok(await _hasta(func(): return red.esperando, 20.0), "si al invitado se le corta, el anfitrión espera")
	_ok(await _hasta(func(): return paused), "con la partida parada")
	_ok(await _hasta(func(): return not red.esperando and red.hay_companero, 25.0), "el invitado vuelve")
	_ok(await _hasta(func(): return not paused), "y la partida sigue")
	_ok(pareja.jugando_anfitrion(), "sin dejar de ser online")
	await _segundos(4.0)
	# Final de partida y vuelta al vestíbulo.
	m._acabar(false)
	await _segundos(3.0)
	m._ir_al_menu()
	_ok(m._sala_online.visible and red.en_sala() and not pareja.en_partida, "tras la partida el anfitrión vuelve al vestíbulo con la sala abierta")
	_ok(not Red.reenviando, "y deja de contar")
	# Segunda partida (sin cerrar el vestíbulo a mano: lo cierra el arranque), que acaba enseguida.
	await _segundos(4.0)
	m._al_elegir_personaje("tahur", 0, false, false)
	await _esperar(5)
	_ok(pareja.jugando_anfitrion() and m.jugador2 != null, "se puede empezar otra partida sin salir de la sala")
	_ok(not m._sala_online.visible, "y el vestíbulo no se queda encima de la partida")
	await _segundos(3.0)
	m._acabar(false)
	await _segundos(2.0)
	# OTRA MANO pasa por el vestíbulo (la sala sigue abierta): tampoco se queda encima.
	m._otra_mano()
	await _esperar(5)
	_ok(pareja.jugando_anfitrion() and J.coop and m.jugador2 != null and m.jugador2.remoto, "OTRA MANO sigue siendo online")
	_ok(not m._sala_online.visible and not m._menu.visible and not paused, "y la juego sin el vestíbulo por medio")
	# El invitado se va a mitad.
	_ok(await _hasta(func(): return not J.coop and m.jugador2 == null, 30.0), "si el invitado se va, se sigue en solitario")
	_ok(not red.en_sala() and not pareja.en_partida and not paused, "sin sala y sin parar la partida")
	_ok(m.jugador.entrada == Mando.TODO or not m.jugador.remoto, "el J1 sigue manejándose")
	print("[anfitrion] bytes enviados: %d" % red.bytes_enviados)


## Lo que mandaría un ordenador con el juego tocado: se acota o se ignora, sin romper nada.
func _lo_raro_no_rompe() -> void:
	var enorme: Array = [30, []]
	for i in 3000:
		enorme[1].append([3, i, i + 1])
	_ok(Red.desempaquetar(Red.empaquetar(enorme), Red.TOPE_DEL_INVITADO) == null
			and Red.desempaquetar(Red.empaquetar([20, 1, Vector2.ONE, Vector2.ZERO, null]), Red.TOPE_DEL_INVITADO) != null,
			"lo grande del invitado no se abre; lo suyo de siempre, sí")
	var pareja_gd: GDScript = load("res://scripts/pareja.gd")
	_ok((load("res://scripts/jugo.gd") as GDScript).REENVIABLES.all(func(f): return pareja_gd.ARGS_FX.has(f)),
			"cada efecto que se reenvía sabe qué argumentos admite")
	_ok(pareja_gd._args_fx(&"camara_lenta", [1.0e9, 0.0]) == [1.5, 0.1] and pareja_gd._args_fx(&"cine", ["x", Vector2.ZERO, 0.1]) == null
			and pareja_gd._args_fx(&"trozos", [Vector2.ZERO, 100000, 1.0])[1] == 24 and pareja_gd._args_fx(&"golpe_jugador", []) == [],
			"los efectos que llegan se acotan (ni cámara lenta eterna ni un millón de trozos)")
	var e = (load("res://scripts/espejo.gd") as GDScript).new()
	var raices: Array = []
	for i in 4:
		raices.append(Node2D.new())
		root.add_child(raices[-1])
	var vacio := [PackedByteArray(), PackedInt32Array()]
	# Una cadena de grupos: el cuarto nivel ya no se crea (lo más hondo que copia el anfitrión es el tercero).
	e.aplicar([[], [[1, -3, 0, 0, 0, 0, -1, []], [2, 1, 0, 0, 0, 0, -1, []], [3, 2, 0, 0, 0, 0, -1, []],
			[4, 3, 0, 0, 0, 0, -1, []]]] + vacio, raices)
	_ok(e._nodos.has(3) and not e._nodos.has(4), "el espejo no crea nada más hondo de lo que se copia")
	# Raíz o tipo inventados; y un sprite con casillas de otro tipo, una z enorme y un material que no existe.
	e.aplicar([[], [[5, -9, 0, 0, 0, 0, -1, []], [6, -1, 7, 0, 0, 0, -1, []],
			[7, -1, 1, 0, 0, -3, -1, ["no", "es", Vector2.INF, 0, 0, 99999, 77]]]] + vacio, raices)
	var n7 = e._nodos.get(7)
	_ok(not e._nodos.has(5) and not e._nodos.has(6), "ni con una raíz o un tipo inventados")
	_ok(n7 != null and n7.visible and n7.scale == Vector2.ONE and n7.material == null and n7.frame == 0
			and n7.z_index == RenderingServer.CANVAS_ITEM_Z_MAX, "lo que no es de su tipo se ignora y lo enorme se acota")
	e.aplicar([[], [[7, -1, 2, 0, 0, 0, 1, [false]]]] + vacio, raices)
	_ok(n7.visible, "el mismo número con otro tipo de nodo no toca nada")
	# Texturas: un número fuera de tope, una ruta que sale de assets y un PNG que dice ser enorme.
	var png := Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png_to_buffer()
	var gigante := png.duplicate()
	gigante.encode_u32(16, 0x00100000)  # el ancho del IHDR, que el PNG lee al revés: 4096 píxeles
	e.aplicar([[[1, "", png], [2, "", gigante], [3, "res://assets/../project.godot", PackedByteArray()], [9999, "", png]], []] + vacio, raices)
	_ok(e._tex_por_numero.has(1) and not e._tex_por_numero.has(2) and not e._tex_por_numero.has(3) and not e._tex_por_numero.has(9999),
			"solo entran texturas pequeñas, del juego y con número")
	# Y un tope de nodos.
	var muchos: Array = []
	for i in 3100:
		muchos.append([100 + i, -2, 0, 0, 0, 0, -1, []])
	e.aplicar([[], muchos] + vacio, raices)
	_ok(e._nodos.size() == e.TOPE_NODOS, "como mucho %d nodos de pega" % e.TOPE_NODOS)
	e.vaciar()
	_ok(e._nodos.is_empty() and e._tex_por_numero.is_empty(), "y al vaciar no queda nada (las texturas vuelven con la sala)")
	for r in raices:
		r.queue_free()


# ------------------------------------------------ invitado
func _invitado() -> void:
	_ok(await _hasta(func(): return FileAccess.file_exists(_fichero), 40.0), "el anfitrión ha dicho su código")
	await _esperar(5)
	var codigo := FileAccess.get_file_as_string(_fichero).strip_edges()
	# Un código que no existe: error, y se puede volver a intentar.
	m._sala_online.abrir()
	m._sala_online._activar("unirse")
	m._sala_online._campo.text = "2222" if codigo != "2222" else "3333"
	m._sala_online._entrar()
	_ok(await _hasta(func(): return m._sala_online._mensaje != ""), "un código que no existe da un aviso")
	_ok(not red.en_sala(), "y no entra en ninguna sala")
	m._sala_online._activar("unirse")
	m._sala_online._campo.text = codigo.to_lower()
	m._sala_online._al_escribir(m._sala_online._campo.text)
	m._online.nombre = "INVI"
	m._sala_online._entrar()
	_ok(await _hasta(func(): return red.en_pareja() and not red.anfitrion), "el invitado entra con el código")
	_ok(m._sala_online._vista == m._sala_online.Vista.SALA, "y ve el vestíbulo")
	var mio: String = pareja.personaje_invitado
	_ok(PersonajesDB_tiene(mio), "tiene un personaje elegido (%s)" % mio)
	# Empieza la partida.
	_ok(await _hasta(func(): return pareja.jugando_invitado() and m.jugador2 != null, 30.0), "el anfitrión empieza y aquí empieza también")
	_ok(Red.espejo and J.coop and J.personaje == "tahur" and J.personaje2 == mio, "con los personajes de los dos")
	_ok(m.jugador.remoto and not m.jugador.remoto_manda and not m.jugador2.remoto, "aquí el muñeco es el J1, y el J2 se maneja")
	_ok(m.mio() == m.jugador2, "mi jugador es el J2")
	_ok(not m._sala_online.visible and not m._menu.visible and not paused, "sin menús por medio")
	_ok(await _hasta(func(): return pareja.tics_recibidos > 3), "llegan tics")
	# Me muevo y ruedo.
	var yo = m.jugador2
	yo.position += Vector2(40, 0)
	await _segundos(1.0)
	yo.pedir_voltereta()
	_ok(await _hasta(func(): return yo.rodando()), "ruedo aquí al instante")
	# Me toca elegir carta.
	_ok(await _hasta(func(): return m._selector.visible and m._dueno_panel == m.jugador2, 20.0), "me sale el selector de cartas, a mi nombre")
	_ok(paused and m._selector._ids.size() == 2, "con la partida parada y las dos cartas del anfitrión")
	var elegida: String = m._selector._ids[0]
	m._selector.elegida.emit(elegida)
	_ok(await _hasta(func(): return not m._selector.visible and J.cartas.has(elegida)), "la elijo y aparece en la fila")
	# El evento: lo veo y lo manejo.
	_ok(await _hasta(func(): return m._panel.visible and m._panel._botones.size() > 0, 20.0), "veo el evento del anfitrión, con sus botones")
	_ok(m._panel._tipo == "mendigo" and not m._panel.is_processing(), "es un dibujo: aquí no decide nada")
	await _segundos(1.5)
	pareja.pedir([pareja.I_TECLA, KEY_ESCAPE])  # B: al último botón, el de marcharse
	await _segundos(0.4)
	pareja.pedir([pareja.I_TECLA, KEY_ENTER])
	_ok(await _hasta(func(): return not m._panel.visible and not paused, 10.0), "me marcho del evento y se cierra en los dos")
	# Un evento que maneja el anfitrión: la partida está parada por él, pero mi menú se abre.
	_ok(await _hasta(func(): return m._panel.visible and m._dueno_panel == m.jugador, 20.0), "veo el evento que abre el anfitrión")
	_ok(paused and pareja.pausa_prestada(), "con la partida parada por él")
	root.push_input(_tecla(KEY_ESCAPE))
	_ok(m._menu.visible and paused, "Esc me abre el menú igual")
	_ok(not m._panel.visible, "y su panel no lo tapa")
	await _segundos(1.5)
	root.push_input(_tecla(KEY_ESCAPE))
	_ok(not m._menu.visible and m._panel.visible, "al cerrar el menú vuelvo a ver su evento")
	_ok(await _hasta(func(): return not m._panel.visible and not paused, 20.0), "y cuando lo cierra él, sigo")
	# Reanimación vista desde el invitado: caigo, me reanima el anfitrión y me levanto.
	_ok(await _hasta(func(): return m.jugador2.caido, 20.0), "me quedo fuera de juego")
	_ok(await _hasta(func(): return m.jugador2.reanimar > 0.3, 20.0), "el anfitrión me reanima: se llena la barra")
	_ok(await _hasta(func(): return not m.jugador2.caido and J.vida2 == 2, 20.0), "y me levanto con 2 de vida (%d)" % J.vida2)
	# La sala de pelea del anfitrión.
	_ok(await _hasta(func(): return m.actual.get("tipo") == TIPO.NORMAL and pareja.n_sala >= 2, 20.0), "cuando el anfitrión cambia de sala, aquí también")
	_ok(await _hasta(func(): return m._horda.get_child_count() > 0, 20.0), "y se ven sus enemigos (%d)" % m._horda.get_child_count())
	_ok(await _hasta(func(): return J.oro == 77), "el oro es el del anfitrión")
	_ok(await _hasta(func(): return m._barra.en_combate and J.en_combate), "la fila de cartas está en combate")
	_ok(not m._sala._puertas_abiertas, "y las puertas, cerradas como en el anfitrión")
	_ok(m._salas_limpiadas == 0 and not m.en_combate, "pero aquí no se simula ninguna pelea")
	# Pauso y reanudo.
	m.quizas_pausar()
	_ok(m._menu.visible and paused, "puedo pausar")
	await _segundos(2.5)
	m._menu.cerrar()
	m._reanudar()
	await _segundos(2.5)
	_ok(not paused, "y reanudar")
	# Se me corta la conexión (sin despedirme): vuelvo solo.
	var tics: int = pareja.tics_recibidos
	red._ws.close(4000, "prueba")
	_ok(await _hasta(func(): return red.estado == red.Estado.VOLVIENDO, 10.0), "si se corta, intento volver")
	_ok(await _hasta(func(): return red.estado == red.Estado.EN_SALA and red.hay_companero, 25.0), "y vuelvo a la sala")
	_ok(await _hasta(func(): return pareja.tics_recibidos > tics + 5 and not paused, 15.0), "la partida sigue llegando")
	_ok(pareja.jugando_invitado() and m._horda.get_child_count() > 0, "con sus enemigos otra vez")
	# El final.
	_ok(await _hasta(func(): return m._pantalla.visible, 30.0), "cuando acaba la partida, sale la pantalla final")
	_ok(await _hasta(func(): return m._sala_online.visible and not pareja.en_partida, 30.0), "y al volver el anfitrión al vestíbulo, yo también")
	_ok(red.en_pareja(), "seguimos en la sala")
	_ok(_paneles_de_siempre(), "y los paneles vuelven a ser los de siempre (procesan, cogen el ratón y no se ven)")
	# Segunda partida: la acaba el anfitrión y pide OTRA MANO.
	_ok(await _hasta(func(): return pareja.jugando_invitado(), 30.0), "empieza otra partida")
	_ok(await _hasta(func(): return m._pantalla.visible, 30.0), "se acaba")
	_ok(await _hasta(func(): return pareja.jugando_invitado() and not m._pantalla.visible, 30.0), "y con OTRA MANO empieza la tercera")
	_ok(not m._sala_online.visible and not m._menu.visible, "sin el vestíbulo por medio")
	# Me voy yo.
	await _segundos(2.0)
	m.quizas_pausar()
	m._ir_al_menu()
	_ok(not red.en_sala() and not pareja.en_partida and not Red.espejo, "al irme al menú dejo la sala")
	_ok(m._menu.visible, "y estoy en el menú principal")
	_ok(_paneles_de_siempre(), "con los paneles listos para una partida en local")
	await _esperar(30)


## Los paneles de evento y de apuestas, como en una partida local: ni dibujo ni a la vista.
func _paneles_de_siempre() -> bool:
	for panel in [m._panel, m._panel_apuestas]:
		if panel.visible or not panel.is_processing() or not panel.is_processing_unhandled_input() \
				or panel.mouse_filter != Control.MOUSE_FILTER_STOP:
			return false
	return true


func _tecla(codigo: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = codigo
	ev.physical_keycode = codigo
	return ev


func PersonajesDB_tiene(id: String) -> bool:
	return (load("res://scripts/personajes_db.gd") as GDScript).PERSONAJES.has(id)
