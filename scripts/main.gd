extends Node2D
## Une todas las piezas y lleva el hilo de la partida, sala a sala.

const TIPO := GeneradorMazmorra.Tipo
const ARTICULO_CORAZON := "_corazon"
const ARTICULO_RANURA := "_ranura"
const ARTICULO_REBARAJAR := "_rebarajar"
const PREFIJO_OBJETO := "obj:"
const PRECIO_REBARAJAR := 6
const VIDA_JEFE_EXTREMO := 3.0
const VIDA_JEFE_NORMAL := 1.4
const PROB_ELITE := 0.08
const PRESUPUESTO_MAX := 180
const TINTE_PISO := [Color.WHITE, Color(0.8, 0.9, 1.1), Color(0.8, 1.05, 0.85), Color(1.1, 0.9, 0.75), Color(1.15, 0.75, 0.8)]
# tipo, coste en el presupuesto, piso mínimo, salas limpiadas mínimas, peso
const CATALOGO := [
	["ficha", 1, 1, 0, 50.0],
	["dado", 1, 1, 0, 30.0],
	["naipe", 2, 1, 1, 22.0],
	["sota", 3, 1, 2, 16.0],
	["ficha_grande", 4, 1, 4, 12.0],
	["joker", 4, 2, 0, 12.0],
	["cubilete", 5, 2, 2, 10.0],
	["portero", 6, 3, 0, 10.0],
	["ficha_oro", 2, 1, 3, 3.0],
	["camara", 3, 1, 3, 9.0],
	["ratero", 2, 1, 2, 10.0],
	["dado_bomba", 3, 2, 0, 12.0],
	["reina", 5, 3, 0, 8.0],
]
const PRECIO_CORAZON := 10
const PRECIO_RANURA := 25
const MAX_ENEMIGOS := 70

var jugador: CharacterBody2D
var salas: Dictionary = {}
var actual: Dictionary = {}
var en_combate := false

var _oleadas: Array = []
var _oleada_t := 0.0
var _salas_limpiadas := 0  # en este piso
var _sin_golpes := true
var _cartel_tween: Tween
var _sonido: Sonido
var _seleccion: Seleccion
var _coleccion: Coleccion
var _panel: PanelEvento
var _tactiles: ControlesTactiles
var _logros: PantallaLogros
var _reto: PantallaReto
var _prob_carta := 0.55
var _cambiando_sala := false
var _carta_pendiente := ""
var _hint_tienda := ""
var _articulo_mostrado := ""
var _sacudida := 0.0

@onready var _mundo: Node2D = $Mundo
@onready var _sala: Sala = $Mundo/Sala
@onready var _recogibles: Node2D = $Mundo/Recogibles
@onready var _horda: Horda = $Mundo/Horda
@onready var _ataques: Ataques = $Mundo/Ataques
@onready var _efectos: Node2D = $Mundo/Efectos
@onready var _motor: MotorCartas = $Motor
@onready var _barra: BarraCartas = $UI/Barra
@onready var _hud: Hud = $UI/Hud
@onready var _selector: Selector = $UI/Selector
@onready var _pantalla: Pantalla = $UI/Pantalla
@onready var _fundido: ColorRect = $UI/Fundido
@onready var _aviso: Label = $UI/Aviso
@onready var _menu: Menu = $UI/Menu
@onready var _cartel: Label = $UI/Cartel
@onready var _cartel_sub: Label = $UI/CartelSub


func _ready() -> void:
	jugador = $Mundo/Player
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Mundo.process_mode = Node.PROCESS_MODE_PAUSABLE
	_motor.process_mode = Node.PROCESS_MODE_PAUSABLE
	_horda.jugador = jugador
	_horda.ataques = _ataques
	_horda.sala = _sala
	_ataques.horda = _horda
	_ataques.jugador = jugador
	_motor.ataques = _ataques
	_hud.horda = _horda
	_hud.barra = _barra
	_cartel.add_theme_font_override("font", Juego.fuente_grande)
	_cartel.add_theme_font_size_override("font_size", 16)
	_barra.conectar_motor(_motor)
	_horda.enemigo_muerto.connect(_al_morir_enemigo)
	_horda.danio_hecho.connect(_texto_danio)
	_ataques.explosion_hecha.connect(sacudir.bind(2.0))
	jugador.golpeado.connect(_al_golpear_jugador)
	_selector.elegida.connect(_al_elegir_carta)
	_selector.saltada.connect(_cerrar_selector)
	_barra.sustitucion_elegida.connect(_al_sustituir)
	_barra.sustitucion_cancelada.connect(_cerrar_selector)
	_pantalla.aceptada.connect(_al_cerrar_final)
	_pantalla.seguir_infinito.connect(_seguir_infinito)
	_menu.jugar.connect(empezar_partida)
	_menu.continuar.connect(_reanudar)
	_menu.ir_a_portada.connect(_ir_al_menu)
	_crear_pantallas_extra()
	get_tree().paused = true
	_menu.abrir_principal()
	Sonido.musica("menu")


func _crear_pantallas_extra() -> void:
	_sonido = Sonido.new()
	add_child(_sonido)
	_seleccion = Seleccion.new()
	_coleccion = Coleccion.new()
	_panel = PanelEvento.new()
	_tactiles = ControlesTactiles.new()
	_tactiles.principal = self
	get_tree().quit_on_go_back = false
	_logros = PantallaLogros.new()
	_reto = PantallaReto.new()
	for pantalla in [_tactiles, _panel, _seleccion, _coleccion, _logros, _reto]:
		$UI.add_child(pantalla)
	$UI.move_child(_tactiles, _menu.get_index())
	_menu.jugar.connect(_seleccion.abrir)
	_menu.ver_coleccion.connect(_coleccion.abrir)
	_seleccion.elegido.connect(empezar_partida)
	_seleccion.atras.connect(_menu.abrir_principal)
	_coleccion.atras.connect(_menu.abrir_principal)
	_panel.cerrado.connect(_al_cerrar_evento)
	_menu.ver_logros.connect(_logros.abrir)
	_menu.ver_reto.connect(_reto.abrir)
	_menu.reanudar.connect(continuar_partida)
	_logros.atras.connect(_menu.abrir_principal)
	_reto.atras.connect(_menu.abrir_principal)
	_reto.jugar_reto.connect(empezar_reto)
	Juego.logro_obtenido.connect(_hud.avisar_logro)
	Juego.transformacion_obtenida.connect(_al_transformarse)


func _ir_al_menu() -> void:
	_pantalla.visible = false
	en_combate = false
	_barra.en_combate = false
	_motor.parar()
	_barra.parar_animacion()
	_horda.limpiar()
	_ataques.limpiar()
	_cerrar_selector()
	get_tree().paused = true
	_menu.abrir_principal()
	Sonido.musica("menu")


func _al_cerrar_final() -> void:
	var era_reto: bool = Juego.diario
	_ir_al_menu()
	if era_reto:
		_menu.cerrar()
		_reto.abrir()


## Tras ganar se sigue bajando con todo lo que llevabas.
func _seguir_infinito() -> void:
	Juego.empezar_infinito()
	get_tree().paused = false
	Sonido.musica("piso")
	_bajar_piso()
	_aviso.text = Idioma.t("MODO INFINITO: CADA PISO ES PEOR QUE EL ANTERIOR.")


func _reanudar() -> void:
	get_tree().paused = false


## El botón "atrás" de Android hace de Esc.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		quizas_pausar()


func empezar_reto() -> void:
	# La semilla sale de la fecha: todo el mundo juega la misma mazmorra ese día.
	Juego.nueva_partida(hash(Juego.fecha_hoy()), "tahur", 1, false, true)
	Juego.revisar_logros()
	_arrancar()


func empezar_partida(personaje := "", mesa := -1, extremo := false, imposible := false) -> void:
	Juego.nueva_partida(0, personaje, mesa, extremo, false, imposible)
	_arrancar()


func continuar_partida() -> void:
	var datos := Guardado.cargar()
	if datos.is_empty():
		_ir_al_menu()
		return
	Juego.restaurar(datos.juego)
	salas = datos.salas
	_salas_limpiadas = datos.salas_limpiadas
	_prob_carta = datos.prob_carta
	_hud.salas = salas
	_pintar_piso()
	jugador.aplicar_personaje()
	if not Juego.transformaciones.is_empty():
		_al_tenir(Juego.transformaciones[-1])
	Sonido.musica("piso")
	get_tree().paused = false
	entrar_sala(datos.pos, Vector2i.ZERO)


func _guardar_punto() -> void:
	Guardado.guardar({"juego": Juego.volcar(), "salas": salas, "salas_limpiadas": _salas_limpiadas,
		"prob_carta": _prob_carta, "pos": actual.pos})


func _pintar_piso() -> void:
	_sala.modulate = TINTE_PISO[clampi(Juego.piso - 1, 0, TINTE_PISO.size() - 1)]


func _al_tenir(id: String) -> void:
	jugador.teñir(Color.html(ObjetosDB.TRANSFORMACIONES[id].color).lerp(Color.WHITE, 0.45))


func _arrancar() -> void:
	jugador.aplicar_personaje()
	Sonido.musica("piso")
	_prob_carta = 0.55
	_generar_piso()
	get_tree().paused = false


func _generar_piso() -> void:
	_salas_limpiadas = 0
	if Juego.diario:
		Juego.azar.seed = hash("%s-%d" % [Juego.fecha_hoy(), Juego.piso])
	salas = GeneradorMazmorra.generar(Juego.azar, mini(12 + Juego.piso, 15))
	_quitar_tienda_si_extremo()
	_repartir_eventos()
	_hud.salas = salas
	_pintar_piso()
	entrar_sala(GeneradorMazmorra.INICIO, Vector2i.ZERO)
	mostrar_cartel(Idioma.t("PISO %d") % Juego.piso, Idioma.t("AL FONDO TE ESPERA %s") % Idioma.t(Jefe.NOMBRES[Juego.jefe_del_piso()]))


## En modo extremo la tienda se convierte en una sala de combate más.
## En el imposible, también el tesoro.
func _quitar_tienda_si_extremo() -> void:
	if not Juego.extremo:
		return
	for c in salas:
		if salas[c].tipo == TIPO.TIENDA or (Juego.imposible and salas[c].tipo == TIPO.TESORO):
			salas[c].tipo = TIPO.NORMAL
			salas[c].limpia = false


func _repartir_eventos() -> void:
	# Con un solo corazón no tienen sentido ni la barra ni vender vida.
	var tipos: Array = ["trileros", "doble_nada", "mendigo", "caja_fuerte"] if Juego.extremo else PanelEvento.TIPOS.duplicate()
	for c in salas:
		if salas[c].tipo == TIPO.EVENTO:
			salas[c]["evento"] = tipos.pop_at(Juego.azar.randi() % tipos.size())


func mostrar_cartel(titulo: String, subtitulo: String) -> void:
	_cartel.text = titulo
	_cartel_sub.text = subtitulo
	if _cartel_tween != null:
		_cartel_tween.kill()
	_cartel.modulate.a = 1.0
	_cartel_sub.modulate.a = 1.0
	_cartel_tween = create_tween()
	_cartel_tween.tween_interval(1.8)
	_cartel_tween.tween_property(_cartel, "modulate:a", 0.0, 0.4)
	_cartel_tween.parallel().tween_property(_cartel_sub, "modulate:a", 0.0, 0.4)


func entrar_sala(c: Vector2i, venimos: Vector2i) -> void:
	actual = salas[c]
	actual.visitada = true
	_hud.posicion_actual = c
	_horda.limpiar()
	_ataques.limpiar()
	for r in _recogibles.get_children():
		r.queue_free()
	for f in _efectos.get_children():
		f.queue_free()
	_sala.construir(actual, salas)
	_colocar_jugador(venimos)
	_hint_tienda = ""
	_aviso.text = ""
	_barra.info_externa = {}
	jugador.seguro_listo = Juego.stat("seguro") > 0.0
	_sin_golpes = true
	match actual.tipo:
		TIPO.NORMAL:
			if not actual.limpia:
				_empezar_combate()
		TIPO.JEFE:
			if not actual.limpia:
				_empezar_jefe()
			else:
				_crear_salida_jefe()
		TIPO.TESORO:
			_crear_cofre()
			_crear_premio_tesoro()
		TIPO.TIENDA:
			_crear_tienda()
		TIPO.EVENTO:
			_crear_evento()
	_guardar_punto()


func _colocar_jugador(venimos: Vector2i) -> void:
	jugador.velocity = Vector2.ZERO
	match venimos:
		Vector2i.UP: jugador.position = Vector2(320, 272)
		Vector2i.DOWN: jugador.position = Vector2(320, 50)
		Vector2i.LEFT: jugador.position = Vector2(606, 160)
		Vector2i.RIGHT: jugador.position = Vector2(34, 160)
		_: jugador.position = Sala.CENTRO


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	Juego.tiempo_partida += delta
	_aplicar_sacudida(delta)
	if en_combate:
		_actualizar_combate(delta)
	else:
		_mirar_puertas()
	_actualizar_hint_tienda()


# ------------------------------------------------------------ combate
func _empezar_combate() -> void:
	en_combate = true
	_barra.en_combate = true
	_sala.poner_puertas(false)
	Sonido.tocar("puerta_cierra")
	_oleadas = _planificar_oleadas()
	_oleada_t = 0.3
	_motor.activo = true


func _planificar_oleadas() -> Array:
	var presupuesto := mini(11 + _salas_limpiadas * 3 + (Juego.piso - 1) * 10 + Juego.pisos_extra() * 6, PRESUPUESTO_MAX)
	if Juego.mesa >= 2:
		presupuesto = int(presupuesto * 1.3)
	var numero_oleadas := 2 + mini(_salas_limpiadas / 3, 2)
	var oleadas: Array = []
	for i in numero_oleadas:
		var parte := presupuesto / numero_oleadas + i * 2
		var grupo: Array = []
		while parte > 0:
			var elegido: Array = _elegir_enemigo(parte)
			grupo.append(elegido[0])
			parte -= int(elegido[1])
		oleadas.append(grupo)
	return oleadas


func _elegir_enemigo(presupuesto: int) -> Array:
	var validos: Array = []
	var suma := 0.0
	for fila in CATALOGO:
		if int(fila[1]) <= presupuesto and Juego.piso >= fila[2] and (Juego.piso > 1 or _salas_limpiadas >= fila[3]):
			validos.append(fila)
			suma += fila[4]
	var tirada := Juego.azar.randf() * suma
	for fila in validos:
		tirada -= fila[4]
		if tirada <= 0.0:
			return fila
	return CATALOGO[0]


func _actualizar_combate(delta: float) -> void:
	_oleada_t -= delta
	var vivos := _horda.enemigos.size()
	if not _oleadas.is_empty() and (_oleada_t <= 0.0 or vivos <= 2):
		_soltar_oleada(_oleadas.pop_front())
		_oleada_t = 6.0
		return
	if _oleadas.is_empty() and vivos == 0:
		_terminar_combate()


func _soltar_oleada(grupo: Array) -> void:
	var azar := Juego.azar
	var mult := 1.3 + (Juego.piso - 1) * 0.8 + _salas_limpiadas * 0.08
	if Juego.mesa >= 1:
		mult *= 1.25
	mult *= pow(1.22, Juego.pisos_extra())
	var prob_elite := minf(PROB_ELITE + Juego.pisos_extra() * 0.03, 0.4)
	for tipo in grupo:
		if _horda.enemigos.size() >= MAX_ENEMIGOS:
			break
		var p := _punto_lejos_del_jugador(azar)
		var e := _horda.crear(tipo, p, mult)
		if Juego.piso >= 2 and azar.randf() < prob_elite:
			e.hacer_elite()


func _punto_lejos_del_jugador(azar: RandomNumberGenerator) -> Vector2:
	var zona := Sala.INTERIOR.grow(-14.0)
	var p := Vector2.ZERO
	for _i in 30:
		p = Vector2(azar.randf_range(zona.position.x, zona.end.x), azar.randf_range(zona.position.y, zona.end.y))
		if p.distance_to(jugador.position) > 110.0:
			break
	return p


func _empezar_jefe() -> void:
	en_combate = true
	_barra.en_combate = true
	_sala.poner_puertas(false)
	_oleadas = []
	var jefe := Jefe.crear(Juego.jefe_del_piso())
	jefe.position = Vector2(320, 110)
	var vida_jefe := (1.0 + (Juego.piso - 1) * 0.9) * (1.4 if Juego.mesa >= 4 else 1.0)
	vida_jefe *= VIDA_JEFE_EXTREMO if Juego.extremo else VIDA_JEFE_NORMAL
	vida_jefe *= Juego.refuerzo_jefe()
	jefe.preparar(vida_jefe)
	mostrar_cartel(Idioma.t(jefe.nombre), "")
	Sonido.tocar("jefe_aparece")
	Sonido.musica("jefe")
	_horda.anadir_jefe(jefe)
	_motor.activo = true


func _terminar_combate() -> void:
	en_combate = false
	_barra.en_combate = false
	_motor.parar()
	_barra.parar_animacion()
	actual.limpia = true
	_sala.poner_puertas(true)
	Sonido.tocar("puerta_abre")
	for r in _recogibles.get_children():
		if r.clase == Recogible.Clase.MONEDA:
			r.iman = true
	if _sin_golpes:
		Juego.racha += 1
		Juego.estado_cambiado.emit()
	Juego.revisar_logros()
	Progreso.guardar()
	if Juego.stat("monedas_sala") > 0.0:
		Juego.ganar_oro(int(Juego.stat("monedas_sala")))
	if actual.tipo == TIPO.JEFE:
		_crear_salida_jefe(true)
		Sonido.musica("piso")
		return
	_salas_limpiadas += 1
	if Juego.azar.randf() < _prob_carta:
		_prob_carta = 0.4
		_crear_recogible(Recogible.Clase.CARTA, "res://assets/objetos/carta_suelo.png", Sala.CENTRO)
	else:
		_prob_carta += 0.25


func _al_morir_enemigo(posicion: Vector2, oro_prob: float, tipo: String, monedas: int) -> void:
	Progreso.sumar("enemigos", 1)
	for _i in monedas:
		_soltar_moneda(posicion)
	if Juego.azar.randf() < oro_prob:
		_soltar_moneda(posicion)
	if tipo == "jefe":
		sacudir(8.0)
		Juego.curar(2)
		Sonido.tocar("jefe_muere")
		Juego.novedades += Progreso.al_vencer_jefe(Juego.jefe_del_piso(), Juego.azar)
		if _sin_golpes:
			Juego.marcar_logro("sin_tocar")
		for i in 16:
			_soltar_moneda(posicion)
	_efecto_muerte(posicion, tipo == "jefe")


func _soltar_moneda(posicion: Vector2) -> void:
	var m := _crear_recogible(Recogible.Clase.MONEDA, "res://assets/objetos/moneda.png", posicion)
	m.hframes = 4


func _efecto_muerte(posicion: Vector2, grande: bool) -> void:
	var fx := Sprite2D.new()
	fx.texture = load("res://assets/efectos/explosion.png")
	fx.hframes = 6
	fx.position = posicion
	fx.scale = Vector2.ONE * (2.0 if grande else 0.35)
	_efectos.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "frame", 5, 0.5 if grande else 0.2)
	tw.tween_callback(fx.queue_free)


func _texto_danio(posicion: Vector2, cantidad: float, color: Color) -> void:
	if not Juego.numeros_dano or _efectos.get_child_count() > 60:
		return
	var l := Label.new()
	l.text = str(maxi(1, roundi(cantidad)))
	l.add_theme_color_override("font_color", color)
	l.position = posicion + Vector2(randf_range(-5, 3), -6)
	l.z_index = 5
	_efectos.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 12.0, 0.4)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.15)
	tw.tween_callback(l.queue_free)


func _al_golpear_jugador() -> void:
	_sin_golpes = false
	sacudir(5.0)
	if Juego.vida <= 0:
		_perder()


func sacudir(fuerza: float) -> void:
	if not Juego.sacudida:
		return
	_sacudida = maxf(_sacudida, fuerza)


func _aplicar_sacudida(delta: float) -> void:
	_sacudida = maxf(0.0, _sacudida - delta * 30.0)
	_mundo.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * ceilf(_sacudida * 0.4)
	if _sacudida <= 0.0:
		_mundo.position = Vector2.ZERO


# ------------------------------------------------------------ puertas
func _mirar_puertas() -> void:
	if _cambiando_sala:
		return
	var p := jugador.position
	var d := Vector2i.ZERO
	if p.y < 18.0:
		d = Vector2i.UP
	elif p.y > 298.0:
		d = Vector2i.DOWN
	elif p.x < 8.0:
		d = Vector2i.LEFT
	elif p.x > 632.0:
		d = Vector2i.RIGHT
	if d != Vector2i.ZERO and _sala.puerta_abierta(d):
		_cruzar_puerta(d)


func _cruzar_puerta(d: Vector2i) -> void:
	_cambiando_sala = true
	var destino: Vector2i = actual.pos + d
	var ida := create_tween()
	ida.tween_property(_fundido, "color:a", 1.0, 0.09)
	await ida.finished
	entrar_sala(destino, d)
	var vuelta := create_tween()
	vuelta.tween_property(_fundido, "color:a", 0.0, 0.12)
	_cambiando_sala = false


# ------------------------------------------------------------ objetos y salas especiales
func _crear_recogible(clase: int, ruta: String, posicion: Vector2) -> Recogible:
	var r := Recogible.new()
	r.texture = load(ruta)
	r.position = posicion
	r.iniciar(clase, self)
	_recogibles.call_deferred("add_child", r)
	return r


func _crear_salida_jefe(recien_ganado := false) -> void:
	_crear_recogible(Recogible.Clase.TRAMPILLA, "res://assets/objetos/trampilla.png", Sala.CENTRO)
	if recien_ganado or not actual.get("premio_cogido", true):
		var id: String = actual.get("premio", "")
		if id == "":
			id = Juego.robar_objeto()
			actual["premio"] = id
			actual["premio_cogido"] = false
		if id != "":
			_crear_objeto_suelo(id, Sala.CENTRO + Vector2(-80, 0))


func _crear_evento() -> void:
	var r := _crear_recogible(Recogible.Clase.EVENTO, "res://assets/personajes/npc.png", Sala.CENTRO)
	r.hframes = 6
	r.frame = PanelEvento.TIPOS.find(actual.evento)
	r.scale = Vector2(2, 2)


func _al_cerrar_evento(carta: String) -> void:
	actual["evento_hecho"] = true
	get_tree().paused = false
	if carta != "":
		_dar_carta(carta)


func _crear_cofre() -> void:
	var c := _crear_recogible(Recogible.Clase.COFRE, "res://assets/objetos/cofre.png", Sala.CENTRO + Vector2(-46, 0))
	c.hframes = 2
	c.frame = 1 if actual.cofre_abierto else 0


func _crear_premio_tesoro() -> void:
	if actual.get("premio_cogido", false):
		return
	var id: String = actual.get("premio", "")
	if id == "":
		id = Juego.robar_objeto()
		actual["premio"] = id
	if id != "":
		_crear_objeto_suelo(id, Sala.CENTRO + Vector2(46, 0))


func _crear_objeto_suelo(id: String, posicion: Vector2) -> void:
	var r := _crear_recogible(Recogible.Clase.OBJETO, "res://assets/objetos/pedestal.png", posicion)
	r.datos = {"id": id}
	r.offset = Vector2(0, 8)
	var icono := Sprite2D.new()
	icono.texture = ObjetosDB.textura(id)
	icono.scale = Vector2(2, 2)
	icono.position = Vector2(0, -12)
	r.add_child(icono)


func _crear_tienda() -> void:
	if actual.tienda.is_empty():
		_llenar_tienda()
	_pintar_tienda()


func _llenar_tienda() -> void:
	for id in Juego.robar_cartas(3):
		actual.tienda.append({"id": id, "precio": Juego.precio_final(CartasDB.PRECIO_RAREZA[CartasDB.CARTAS[id].rareza])})
	var objeto := Juego.robar_objeto()
	if objeto != "":
		actual.tienda.append({"id": PREFIJO_OBJETO + objeto, "precio": Juego.precio_final(ObjetosDB.PRECIO)})
	actual.tienda.append({"id": ARTICULO_CORAZON, "precio": Juego.precio_final(PRECIO_CORAZON)})
	actual.tienda.append({"id": ARTICULO_RANURA, "precio": Juego.precio_final(PRECIO_RANURA)})
	actual.tienda.append({"id": ARTICULO_REBARAJAR, "precio": PRECIO_REBARAJAR})


func _pintar_tienda() -> void:
	var total: int = actual.tienda.size()
	for i in total:
		var articulo: Dictionary = actual.tienda[i]
		if articulo.get("vendido", false):
			continue
		var p := Vector2(320 + (i - (total - 1) * 0.5) * 72.0, 136)
		var r := _crear_recogible(Recogible.Clase.ARTICULO, "res://assets/objetos/pedestal.png", p)
		r.datos = articulo
		r.offset = Vector2(0, 8)
		r.add_child(_icono_articulo(String(articulo.id)))
		r.add_child(_etiqueta_precio(int(articulo.precio)))


func _icono_articulo(id: String) -> Sprite2D:
	var icono := Sprite2D.new()
	icono.position = Vector2(0, -22)
	if id.begins_with(PREFIJO_OBJETO):
		icono.texture = ObjetosDB.textura(id.trim_prefix(PREFIJO_OBJETO))
		icono.scale = Vector2(2, 2)
		icono.position = Vector2(0, -12)
		return icono
	match id:
		ARTICULO_CORAZON:
			icono.texture = load("res://assets/objetos/corazon.png")
			icono.hframes = 3
			icono.scale = Vector2(2, 2)
			icono.position = Vector2(0, -12)
		ARTICULO_RANURA:
			icono.texture = load("res://assets/cartas/_cerrada.png")
		ARTICULO_REBARAJAR:
			icono.texture = load("res://assets/objetos/rebarajar.png")
			icono.position = Vector2(0, -12)
		_:
			icono.texture = CartasDB.textura(id)
	return icono


## El precio: el número y al lado la moneda.
func _etiqueta_precio(cantidad: int) -> Node2D:
	var grupo := Node2D.new()
	grupo.position = Vector2(0, 19)
	var numero := Label.new()
	numero.text = str(cantidad)
	numero.add_theme_color_override("font_color", Color8(247, 198, 74))
	var ancho: float = Juego.fuente.get_string_size(numero.text).x
	var total := ancho + 2.0 + 8.0
	numero.position = Vector2(-total * 0.5, 0)
	grupo.add_child(numero)
	var moneda := Sprite2D.new()
	moneda.texture = load("res://assets/objetos/moneda.png")
	moneda.hframes = 4
	moneda.centered = false
	moneda.position = Vector2(-total * 0.5 + ancho + 2.0, 1)
	grupo.add_child(moneda)
	return grupo


func _actualizar_hint_tienda() -> void:
	if actual.get("tipo") != TIPO.TIENDA:
		return
	var articulo := _articulo_cerca()
	if articulo == null:
		if _articulo_mostrado != "":
			_articulo_mostrado = ""
			_aviso.text = ""
			_barra.info_externa = {}
		return
	var id: String = articulo.datos.id
	if id != _articulo_mostrado:
		_articulo_mostrado = id
		_aviso.text = "" if Juego.tactil else Idioma.t("E: COMPRAR")
		_barra.info_externa = _info_articulo(id)


func _articulo_cerca() -> Recogible:
	for r in _recogibles.get_children():
		if r.is_queued_for_deletion():
			continue
		if r.clase == Recogible.Clase.ARTICULO and r.tocando():
			return r
	return null


func _info_articulo(id: String) -> Dictionary:
	var info := {"origen": "tienda"}
	if id.begins_with(PREFIJO_OBJETO):
		var objeto := id.trim_prefix(PREFIJO_OBJETO)
		info["nombre"] = ObjetosDB.nombre(objeto)
		info["desc"] = ObjetosDB.descripcion(objeto)
		return info
	match id:
		ARTICULO_CORAZON:
			info["nombre"] = Idioma.t("Corazón")
			info["desc"] = Idioma.t("Recuperas un corazón.")
		ARTICULO_RANURA:
			info["nombre"] = Idioma.t("Ranura Extra")
			info["desc"] = Idioma.t("Una ranura más en la fila de cartas.")
		ARTICULO_REBARAJAR:
			info["nombre"] = Idioma.t("Volver a Barajar")
			info["desc"] = Idioma.t("Cambia las cartas de la tienda. Cada vez cuesta más.")
		_:
			info["nombre"] = CartasDB.nombre(id)
			info["desc"] = CartasDB.descripcion(id)
	return info


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_ESCAPE:
		quizas_pausar()
		return
	if get_tree().paused:
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_E:
		var articulo := _articulo_cerca()
		if articulo != null:
			comprar(articulo)


func articulo_a_mano() -> Recogible:
	if actual.get("tipo") != TIPO.TIENDA:
		return null
	return _articulo_cerca()


## Esc no hace nada mientras eliges carta o estás en una pantalla de fin de partida.
func quizas_pausar() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	_menu.abrir_pausa()


func comprar(r: Recogible) -> void:
	var id: String = r.datos.id
	if int(r.datos.precio) <= Juego.oro:
		Sonido.tocar("comprar")
	if id == ARTICULO_CORAZON and Juego.vida >= Juego.vida_max:
		_aviso.text = Idioma.t("YA TIENES LA VIDA LLENA")
		return
	if id == ARTICULO_RANURA and Juego.cartas.size() >= Juego.RANURAS_MAX:
		_aviso.text = Idioma.t("NO CABEN MÁS RANURAS")
		return
	if not Juego.gastar_oro(int(r.datos.precio)):
		_aviso.text = Idioma.t("NO TE LLEGA")
		return
	if id == ARTICULO_REBARAJAR:
		_rebarajar(r)
		return
	r.datos["vendido"] = true
	r.queue_free()
	_articulo_mostrado = ""
	_aviso.text = ""
	_barra.info_externa = {}
	if id.begins_with(PREFIJO_OBJETO):
		_recoger_objeto(id.trim_prefix(PREFIJO_OBJETO))
		return
	match id:
		ARTICULO_CORAZON: Juego.curar(2)
		ARTICULO_RANURA: Juego.anadir_ranura()
		_: _dar_carta(id)


func _rebarajar(r: Recogible) -> void:
	r.datos["precio"] = int(r.datos.precio) + 3
	var nuevas := Juego.robar_cartas(3)
	var i := 0
	for articulo in actual.tienda:
		if CartasDB.CARTAS.has(articulo.id) and not articulo.get("vendido", false):
			articulo["id"] = nuevas[i]
			articulo["precio"] = Juego.precio_final(CartasDB.PRECIO_RAREZA[CartasDB.CARTAS[nuevas[i]].rareza])
			i += 1
	for hijo in _recogibles.get_children():
		if hijo.clase == Recogible.Clase.ARTICULO:
			hijo.queue_free()
	_articulo_mostrado = ""
	_pintar_tienda()


func _recoger_objeto(id: String) -> void:
	# Primero el cartel del objeto: si completa un conjunto, el de la transformación lo pisa.
	mostrar_cartel(ObjetosDB.nombre(id), ObjetosDB.descripcion(id))
	Sonido.tocar("objeto")
	Juego.dar_objeto(id)


func _al_transformarse(id: String) -> void:
	var datos: Dictionary = ObjetosDB.TRANSFORMACIONES[id]
	mostrar_cartel(Idioma.t(datos.nombre).to_upper(), Idioma.t(datos.desc))
	Sonido.tocar("transformacion")
	_al_tenir(id)


func recogido(r: Recogible) -> void:
	match r.clase:
		Recogible.Clase.MONEDA:
			Juego.ganar_oro(1 + int(Juego.stat("moneda_extra")))
			Progreso.sumar("monedas", 1 + int(Juego.stat("moneda_extra")))
			Sonido.tocar("moneda", randf_range(0.95, 1.2), -6.0)
			r.queue_free()
		Recogible.Clase.CARTA:
			r.queue_free()
			Sonido.tocar("carta_coger")
			abrir_selector(Juego.robar_cartas(2), Idioma.t("ELIGE UNA CARTA"))
		Recogible.Clase.EVENTO:
			if actual.get("evento_hecho", false) or _panel.visible:
				return
			get_tree().paused = true
			_panel.abrir(actual.evento)
		Recogible.Clase.COFRE:
			if actual.cofre_abierto:
				return
			actual.cofre_abierto = true
			r.frame = 1
			Sonido.tocar("carta_coger")
			abrir_selector(Juego.robar_cartas(3, 1.5), Idioma.t("¡TESORO!"))
		Recogible.Clase.OBJETO:
			actual["premio_cogido"] = true
			r.queue_free()
			_recoger_objeto(String(r.datos.id))
		Recogible.Clase.TRAMPILLA:
			r.queue_free()
			_bajar_piso()


func _bajar_piso() -> void:
	if Juego.piso >= Juego.PISOS_TOTALES and not Juego.infinito:
		_ganar()
		return
	Juego.piso += 1
	Juego.ganar_oro(int(Juego.oro * Juego.stat("intereses")))
	Sonido.tocar("bajar")
	var aviso_deuda := Juego.cobrar_deuda()
	_generar_piso()
	if aviso_deuda != "":
		_aviso.text = aviso_deuda


func abrir_selector(ids: Array, titulo: String) -> void:
	get_tree().paused = true
	_selector.abrir(ids, titulo)


func _al_elegir_carta(id: String) -> void:
	Sonido.tocar("carta_coger")
	_selector.cerrar()
	_dar_carta(id)
	if not _barra.modo_sustituir:
		get_tree().paused = false


func _dar_carta(id: String) -> void:
	if Juego.anadir_carta(id):
		return
	get_tree().paused = true
	_carta_pendiente = id
	_barra.modo_sustituir = true


func _al_sustituir(ranura: int) -> void:
	if Juego.dejaria_sin_ataques(ranura, _carta_pendiente):
		_aviso.text = Idioma.t("NECESITAS AL MENOS UNA CARTA DE ATAQUE")
		return
	_aviso.text = ""
	Juego.sustituir_carta(ranura, _carta_pendiente)
	_cerrar_selector()


func _cerrar_selector() -> void:
	_selector.cerrar()
	_barra.modo_sustituir = false
	_carta_pendiente = ""
	get_tree().paused = false


func _perder() -> void:
	Sonido.tocar("derrota")
	_acabar(false)


func _ganar() -> void:
	Juego.novedades += Progreso.al_ganar(Juego.mesa, Juego.extremo, Juego.personaje)
	_acabar(true)


func _acabar(gano: bool) -> void:
	en_combate = false
	_barra.en_combate = false
	_motor.parar()
	_barra.parar_animacion()
	_horda.limpiar()
	_ataques.limpiar()
	get_tree().paused = true
	Sonido.musica("")
	Guardado.borrar()
	if Juego.infinito:
		Progreso.registrar_infinito(Juego.piso)
	else:
		Juego.novedades += Progreso.al_terminar_partida()
	Juego.revisar_logros(gano)
	if Juego.diario:
		Progreso.registrar_reto(Juego.fecha_hoy(), Juego.puntos_reto(gano))
	_pantalla.mostrar_final(gano)
