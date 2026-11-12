extends Node2D
## Une todas las piezas y lleva el hilo de la partida, sala a sala.

const TIPO := GeneradorMazmorra.Tipo
const ARTICULO_CORAZON := "_corazon"
const ARTICULO_RANURA := "_ranura"
const ARTICULO_REBARAJAR := "_rebarajar"
const ARTICULO_ORDAGO := "_ordago"
const PREFIJO_OBJETO := "obj:"
const PRECIO_REBARAJAR := 6
const PRECIO_ORDAGO := 20
# El órdago: empuja a todos desde ti, los aturde y te deja un respiro.
const ORDAGO_EMPUJE := 520.0
const ORDAGO_ATURDIR := 1.3
const ORDAGO_RESPIRO := 0.6
# Ritmo de las oleadas: se solapan sin esperar a que la sala se vacíe
# (ronda 1: 0,2 s la primera, 4,5 s entre ellas y con 3 vivos).
const PRIMERA_OLEADA := 0.05
# Las oleadas entran por porcentaje: cuando has matado la parte que pide el perfil de la
# sala (Director). ENTRE_OLEADAS es solo el tope: si tardas más que eso, entra igual.
const ENTRE_OLEADAS := 4.5
const CAMPANA_SEG := 1.0  # la Campana: lo que tardan en reaccionar los que nacen
const ULTIMOS := 4  # cuando quedan estos y no viene nadie más, se desesperan
const OLEADA_MINIMO := 0.9  # aunque queden pocos, una oleada no pisa a la anterior antes de esto
# Nacen cerca de ti, pero antes se marca el sitio en el suelo.
const AVISO_NACER := 0.4
const AVISO_PRIMERA := 0.3  # la primera oleada avisa más: acabas de cruzar la puerta
const AVISO_EXTREMO := 0.15  # donde un golpe mata, un pelín más de margen
const ESCALONADO_NACER := 0.035  # cada uno de la oleada sale un pelín después del anterior
const NACER_CERCA := 60.0
const NACER_CERCA_EXTREMO := 95.0
const NACER_LEJOS := 175.0
# Más enemigos y menos duros que en la ronda 1 (x1,0 de presupuesto y de vida): mueren antes, vienen más.
const VIDA_ENEMIGOS := 0.85  # hardcore: antes 0,66
const PRESUPUESTO_EXTRA := 1.8  # hardcore: antes 1,35
# Propina por rapidez: limpiar la sala antes de este tiempo da monedas (hay que ir a por ellos).
const PROPINA_BASE := 2.5
const PROPINA_POR_OLEADA := 1.4
const PROPINA_DOBLE := 0.7  # por debajo de esta parte del tiempo, el doble
# Bajas encadenadas: tantas en tan poco tiempo cuentan como remate.
const CADENA_VENTANA := 0.6
const CADENA_REMATE := 5
# Los que al morir paran el tiempo un instante: se nota que eran duros.
const ENEMIGOS_GORDOS := ["ficha_grande", "portero", "maton", "cubilete", "reina", "joker"]
const COLOR_CRITICO := Color8(247, 198, 74)
const COLOR_FIEBRE := Color8(240, 129, 60)
const COLOR_LIMITE := Color8(214, 61, 79)
const VIDA_JEFE_EXTREMO := 3.0
const VIDA_JEFE_NORMAL := 2.0  # hardcore: antes 1,4
# Los rangos (raro y élite) y su probabilidad viven en Enemigo (prob_rangos, tirar_rango).
# El botín garantizado de un élite: una tirada, carta o corazón (si no, solo sus monedas).
const BOTIN_ELITE_CARTA := 0.2
const BOTIN_ELITE_CORAZON := 0.3
const PRESUPUESTO_MAX := 320
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
	["crupier", 3, 1, 3, 12.0],
	["maton", 5, 2, 0, 10.0],
	["botones", 4, 2, 0, 10.0],
]
const PRECIO_CORAZON := 18
const PRECIO_RANURA := 25
const MAX_ENEMIGOS := 105  # antes 90; los que esperan a nacer también cuentan

var jugador: CharacterBody2D
var salas: Dictionary = {}
var actual: Dictionary = {}
## Se copia en Juego.en_combate para que la música y los efectos lo sepan.
var en_combate := false:
	set(valor):
		en_combate = valor
		Juego.en_combate = valor

var _oleadas: Array = []
var _oleada_t := 0.0
var _oleadas_total := 0
var _plan: Dictionary = {}  # el plan procedural de la sala (Director.plan_sala)
var _elites: Array = []  # por oleada, el rango de cada enemigo: [rango, modificadores] (se decide al planear la sala)
var _oleada_base := 0  # los que había vivos justo al soltar la última oleada
var _sala_previstos := 0  # enemigos que trae la sala entre todas las oleadas
var _sala_bajas := 0
var _golpes_sala := 0
var _por_nacer: Array = []  # [tiempo, tipo, posición, vida, rango, modificadores] de los que aún se están avisando
var _sala_t := 0.0  # cronómetro de la propina
var _propina_t := 0.0  # lo que hay para cobrarla; 0 = ya no hay propina
var _cadena := 0
var _cadena_t := 0.0
var _limite_avisado := false
var _crono: Label
var _salas_limpiadas := 0  # en este piso
var _sin_golpes := true
var _favorito := ""
var _ordago_en_sala := false  # para el logro de vencer a un jefe sin gastar ninguno
var _cartel_tween: Tween
var _sonido: Sonido
var _seleccion: Seleccion
var _coleccion: Coleccion
var _panel: PanelEvento
var _tactiles: ControlesTactiles
var _logros: PantallaLogros
var _reto: PantallaReto
var _online: Online  # la tabla mundial; sin online.cfg no hace nada ni se ve
var _prob_carta := 0.55
var _cambiando_sala := false
var _carta_pendiente := ""
var _hint_tienda := ""
var _articulo_mostrado := ""
var _jugo: Jugo
var _lenta_hecha := false  # la cámara lenta de la última baja, una vez por sala
var _hint_mesa := ""
var _panel_apuestas: PanelApuestas
var _hint_maquina := ""

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
	jugador.sala = _sala
	jugador.horda = _horda
	jugador.ataques = _ataques
	_motor.ataques = _ataques
	_hud.horda = _horda
	_hud.barra = _barra
	_cartel.add_theme_font_override("font", Juego.fuente_grande)
	_cartel.add_theme_font_size_override("font_size", 16)
	_barra.conectar_motor(_motor)
	_crear_jugo()
	_horda.enemigo_muerto.connect(_al_morir_enemigo)
	_horda.rango_muerto.connect(_al_morir_rango)
	_horda.danio_hecho.connect(_texto_danio)
	_ataques.explosion_hecha.connect(sacudir.bind(2.0))
	jugador.golpeado.connect(_al_golpear_jugador)
	_selector.elegida.connect(_al_elegir_carta)
	_selector.saltada.connect(_cerrar_selector)
	_barra.sustitucion_elegida.connect(_al_sustituir)
	_barra.sustitucion_cancelada.connect(_cerrar_selector)
	_pantalla.aceptada.connect(_al_cerrar_final)
	_pantalla.seguir_infinito.connect(_seguir_infinito)
	_menu.continuar.connect(_reanudar)
	_menu.ir_a_portada.connect(_ir_al_menu)
	_crear_pantallas_extra()
	Input.joy_connection_changed.connect(_al_cambiar_mando)
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
	_online = Online.new()
	add_child(_online)
	_reto.online = _online
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
	# La sala de apuestas: su panel va encima de todo, como el de los eventos.
	_panel_apuestas = PanelApuestas.new()
	$UI.add_child(_panel_apuestas)
	_panel_apuestas.cerrado.connect(_al_cerrar_apuestas)
	_panel_apuestas.jugada.connect(_guardar_punto)


## La sensación de cada golpe y las mecánicas nuevas (voltereta, órdago, mesas, fiebre).
func _crear_jugo() -> void:
	_jugo = Jugo.new()
	_mundo.add_child(_jugo)
	_jugo.preparar(_mundo, $UI, jugador)
	_ataques.disparo.connect(_jugo.al_disparar)
	_ataques.impacto.connect(_jugo.al_impactar)
	_ataques.explosion_en.connect(_jugo.al_explotar)
	jugador.voltereta.connect(_jugo.al_rodar)
	jugador.por_los_pelos.connect(_al_rozar_bala)
	jugador.roce.connect(_al_rozar_sin_rodar)
	_sala.mesa_volcada.connect(_al_volcar_mesa)
	_sala.mesa_rota.connect(_al_romper_mesa)
	_sala.mesa_golpeada.connect(_al_golpear_mesa)
	Juego.fiebre_cambiada.connect(_al_cambiar_fiebre)
	Juego.desatado_cambiado.connect(_al_desatar)
	_crear_crono()


## El cronómetro de la propina: pequeño, abajo a la derecha, solo mientras se puede cobrar.
func _crear_crono() -> void:
	_crono = Label.new()
	_crono.position = Vector2(536, 289)
	_crono.size = Vector2(100, 10)
	_crono.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_crono.add_theme_color_override("font_color", COLOR_CRITICO)
	_crono.add_theme_color_override("font_outline_color", Color8(20, 16, 30))
	_crono.add_theme_constant_override("outline_size", 2)
	_crono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crono.visible = false
	$UI.add_child(_crono)
	$UI.move_child(_crono, _cartel.get_index())


func _ir_al_menu() -> void:
	_jugo.limpiar()
	_pantalla.visible = false
	en_combate = false
	_por_nacer.clear()
	_crono.visible = false
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


## Cada evento pasa por el mando: así se sabe si lo último que se ha tocado es el mando
## (las ayudas enseñan sus botones) o el teclado y el ratón.
func _input(evento: InputEvent) -> void:
	Mando.observar(evento)
	if Juego.tactil and Mando.activo and Mando.es_mando(evento):
		Juego.tactil = false  # un mando conectado al móvil: fuera los botones de la pantalla


func _al_cambiar_mando(dispositivo: int, conectado: bool) -> void:
	if not conectado:
		Mando.olvidar(dispositivo)


## El botón "atrás" de Android hace de Esc.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		quizas_pausar()


func empezar_reto() -> void:
	# La semilla sale de la fecha (UTC): todo el mundo juega la misma mazmorra ese día.
	# El primer intento del día puntúa; los demás son de práctica.
	var fecha := Juego.fecha_hoy()
	var puntuable := Progreso.reto_puntuable(fecha)
	if puntuable:
		Progreso.empezar_reto_puntuable(fecha)
	Juego.nueva_partida_reto(fecha, puntuable)
	Juego.revisar_logros()
	_arrancar()
	if not puntuable:
		_aviso.text = Idioma.t("PRÁCTICA: ESTE INTENTO NO PUNTÚA")


func empezar_partida(personaje := "", mesa := -1, extremo := false, imposible := false) -> void:
	Juego.nueva_partida(0, personaje, mesa, extremo, false, imposible)
	_arrancar()


func continuar_partida() -> void:
	var datos := Guardado.cargar()
	if datos.is_empty():
		_ir_al_menu()
		return
	Juego.restaurar(datos.juego)
	# Un reto guardado de otro día se puede acabar, pero ya no puntúa.
	var reto_caducado: bool = Juego.diario and Juego.fecha_reto != Juego.fecha_hoy()
	if reto_caducado:
		Juego.reto_puntuable = false
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
	if reto_caducado:
		_aviso.text = Idioma.t("RETO DE OTRO DÍA: YA NO PUNTÚA")


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
		# La fecha del reto, no la de ahora: si pasas la medianoche jugando, sigue siendo tu reto.
		Juego.azar.seed = Juego.semilla_de("reto:%s:%d" % [Juego.fecha_reto, Juego.piso])
	salas = GeneradorMazmorra.generar(Juego.azar, mini(12 + Juego.piso, 15))
	_quitar_tienda_si_extremo()
	_quitar_apuestas_si_extremo()
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


## En extremo e imposible no hay sala de apuestas: ahí no hay tienda (ni tesoro) a propósito,
## y una máquina que reparte corazones, objetos y montones de monedas rompería esa escasez.
## Vuelve a ser la sala de combate que era.
func _quitar_apuestas_si_extremo() -> void:
	if not Juego.extremo:
		return
	for c in salas:
		if salas[c].tipo == TIPO.APUESTAS:
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
	_cartel_tween.tween_interval(1.3)  # antes 1,8 s: que no tape la pelea
	_cartel_tween.tween_property(_cartel, "modulate:a", 0.0, 0.3)
	_cartel_tween.parallel().tween_property(_cartel_sub, "modulate:a", 0.0, 0.3)


func entrar_sala(c: Vector2i, venimos: Vector2i) -> void:
	actual = salas[c]
	actual.visitada = true
	_hud.posicion_actual = c
	_horda.limpiar()
	_ataques.limpiar()
	_jugo.limpiar()
	_por_nacer.clear()
	_propina_t = 0.0
	_crono.visible = false
	_cadena = 0
	_lenta_hecha = false
	_hint_mesa = ""
	for r in _recogibles.get_children():
		r.queue_free()
	for f in _efectos.get_children():
		f.queue_free()
	_ajustar_mesas()
	_sala.construir(actual, salas)
	_colocar_jugador(venimos)
	_hint_tienda = ""
	_hint_maquina = ""
	_aviso.text = ""
	_barra.info_externa = {}
	jugador.seguro_listo = Juego.stat("seguro") > 0.0
	_sin_golpes = true
	_ordago_en_sala = false
	if _jugo.has_method("al_entrar_sala"):
		_jugo.al_entrar_sala(actual.tipo, Juego.piso)
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
		TIPO.APUESTAS:
			_crear_apuestas()
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
	Juego.enfriar_fiebre(delta)
	if en_combate:
		_actualizar_combate(delta)
	else:
		_mirar_puertas()
	_cadena_t -= delta
	if _limite_avisado and not Juego.al_limite():
		_limite_avisado = false
	_actualizar_hint_tienda()
	_actualizar_hint_mesa()
	_actualizar_hint_maquina()


# ------------------------------------------------------------ combate
func _empezar_combate() -> void:
	en_combate = true
	_barra.en_combate = true
	_sala.poner_puertas(false)
	Sonido.tocar("puerta_cierra")
	# Todo el plan sale de la semilla de la sala: la misma sala trae lo mismo, pase lo que pase antes.
	var rng := Juego.azar_para(int(actual.semilla), "oleadas")
	_plan = Director.plan_sala(rng, _salas_limpiadas, Juego.piso, Juego.presion_sala())
	_oleadas = _planificar_oleadas(rng)
	_oleadas_total = _oleadas.size()
	_oleada_base = 0
	_sala_bajas = 0
	_golpes_sala = 0
	_sala_previstos = 0
	for grupo in _oleadas:
		_sala_previstos += grupo.size()
	Juego.progreso_sala = 0.0
	Juego.balas_sala = float(_plan.balas)
	if _plan.regla != "":
		var regla: Dictionary = Director.REGLAS[_plan.regla]
		mostrar_cartel(Idioma.t(regla.nombre), Idioma.t(regla.desc))
	_oleada_t = PRIMERA_OLEADA
	_sala_t = 0.0
	_propina_t = PROPINA_BASE + PROPINA_POR_OLEADA * _oleadas_total
	_motor.activo = true


func _planificar_oleadas(rng: RandomNumberGenerator) -> Array:
	var bruto := (11 + _salas_limpiadas * 3 + (Juego.piso - 1) * 10 + Juego.pisos_extra() * 6) * PRESUPUESTO_EXTRA
	var presupuesto := mini(roundi(bruto * float(_plan.get("presupuesto", 1.0))), PRESUPUESTO_MAX)
	if Juego.mesa >= 2:
		presupuesto = int(presupuesto * 1.3)
	# Cada sala tiene un enemigo de la casa, que sale el triple: así no se parecen entre sí.
	_favorito = ""
	_favorito = String(_elegir_enemigo(presupuesto, rng)[0])
	var oleadas: Array = []
	_elites = []
	# El rango de cada enemigo (normal, raro o élite) se decide aquí, con el azar de la sala.
	var prob := Enemigo.prob_rangos(Juego.piso, Juego.mesa, Juego.pisos_extra(), float(_plan.get("elites", 1.0)))
	var puede_raro: bool = Juego.piso >= 2 or _salas_limpiadas >= 1
	var puede_elite: bool = Juego.piso >= 2 or _salas_limpiadas >= 3
	for parte_oleada in Director.repartir(presupuesto, _plan.get("reparto", [0.3, 0.3, 0.4])):
		var parte: int = parte_oleada
		var grupo: Array = []
		var elites: Array = []
		while parte > 0:
			var elegido: Array = _elegir_enemigo(parte, rng)
			grupo.append(elegido[0])
			elites.append(Enemigo.tirar_rango(rng, elegido[0], prob, puede_raro, puede_elite))
			parte -= int(elegido[1])
		oleadas.append(grupo)
		_elites.append(elites)
	return oleadas


func _elegir_enemigo(presupuesto: int, rng: RandomNumberGenerator) -> Array:
	var validos: Array = []
	var suma := 0.0
	for fila in CATALOGO:
		if int(fila[1]) <= presupuesto and Juego.piso >= fila[2] and (Juego.piso > 1 or _salas_limpiadas >= fila[3]):
			validos.append(fila)
			suma += _peso(fila)
	var tirada := rng.randf() * suma
	for fila in validos:
		tirada -= _peso(fila)
		if tirada <= 0.0:
			return fila
	return CATALOGO[0]


func _peso(fila: Array) -> float:
	return float(fila[4]) * (3.0 if fila[0] == _favorito else 1.0)


func _actualizar_combate(delta: float) -> void:
	_oleada_t -= delta
	_nacer_pendientes(delta)
	_contar_propina(delta)
	var vivos := _horda.enemigos.size() + _por_nacer.size()
	if _sala_previstos > 0:
		Juego.progreso_sala = clampf(float(_sala_bajas) / _sala_previstos, 0.0, 1.0)
	# La siguiente entra cuando has matado el porcentaje que pide el perfil de la sala.
	var matado := 1.0 - float(vivos) / maxf(_oleada_base, 1.0)
	var toca: bool = matado >= float(_plan.get("umbral", 0.6)) and _oleada_t <= ENTRE_OLEADAS - OLEADA_MINIMO
	if not _oleadas.is_empty() and (_oleada_t <= 0.0 or toca):
		_soltar_oleada(_oleadas.pop_front(), _elites.pop_front() if not _elites.is_empty() else [])
		_oleada_t = ENTRE_OLEADAS
		_oleada_base = _horda.enemigos.size() + _por_nacer.size()
		return
	if _oleadas.is_empty() and vivos == 0:
		_terminar_combate()
	elif _oleadas.is_empty() and _por_nacer.is_empty() and vivos <= ULTIMOS and _horda.jefe == null:
		for e in _horda.enemigos:
			e.desesperar()


## La oleada no sale de golpe: primero se marca en el suelo dónde va a nacer cada uno.
func _soltar_oleada(grupo: Array, elites: Array = []) -> void:
	var azar := Juego.azar_combate  # dónde nacen depende de dónde estés: azar de la pelea
	var mult := (1.3 + (Juego.piso - 1) * 1.1 + _salas_limpiadas * 0.08) * VIDA_ENEMIGOS  # hardcore: por piso, antes 0,8
	if Juego.mesa >= 1:
		mult *= 1.25
	mult *= pow(1.22, Juego.pisos_extra()) * float(_plan.get("vida", 1.0))
	var numero := _oleadas_total - _oleadas.size()
	if _jugo.has_method("oleada"):
		_jugo.oleada(numero, _oleadas_total)
	if numero > 1:
		Sonido.tocar("oleada")
	Sonido.tocar("aviso", randf_range(0.95, 1.1), -4.0)
	var hueco := MAX_ENEMIGOS - _horda.enemigos.size() - _por_nacer.size()
	var aviso := AVISO_NACER + (AVISO_PRIMERA if numero == 1 else 0.0) + (AVISO_EXTREMO if Juego.extremo else 0.0)
	for i in mini(grupo.size(), maxi(hueco, 0)):
		var p := _punto_de_nacimiento(azar)
		var espera := aviso + i * ESCALONADO_NACER
		var rango: Array = elites[i] if i < elites.size() else [0, []]
		if _jugo.has_method("aviso_nacimiento"):
			_jugo.aviso_nacimiento(p, espera)
		_por_nacer.append([espera, grupo[i], p, mult, rango[0], rango[1]])


func _nacer_pendientes(delta: float) -> void:
	var i := _por_nacer.size() - 1
	while i >= 0:
		var pendiente: Array = _por_nacer[i]
		pendiente[0] -= delta
		if pendiente[0] <= 0.0:
			_por_nacer.remove_at(i)
			var e := _horda.crear(pendiente[1], pendiente[2], pendiente[3])
			e.vel *= float(_plan.get("vel", 1.0))
			if Juego.stat("campana") > 0.0:
				e.aturdir(CAMPANA_SEG)
			if int(pendiente[4]) > 0:
				e.hacer_rango(int(pendiente[4]), pendiente[5])
				e.golpes_al_nacer = _golpes_sala
		i -= 1


## Cerca del jugador (entre 70 y 175 píxeles; 95 en extremo), pero nunca encima: así no hay paseos vacíos.
func _punto_de_nacimiento(azar: RandomNumberGenerator) -> Vector2:
	var zona := Sala.INTERIOR.grow(-14.0)
	var centro: Vector2 = jugador.position
	var cerca := NACER_CERCA_EXTREMO if Juego.extremo else NACER_CERCA
	var p := Vector2.ZERO
	for _i in 30:
		p = centro + Vector2.RIGHT.rotated(azar.randf() * TAU) * azar.randf_range(cerca, NACER_LEJOS)
		if zona.has_point(p):
			return p
	# Arrinconado: cualquier sitio de la sala que no esté encima.
	for _i in 30:
		p = Vector2(azar.randf_range(zona.position.x, zona.end.x), azar.randf_range(zona.position.y, zona.end.y))
		if p.distance_to(centro) > cerca:
			break
	return p


## La propina por rapidez: el reloj corre mientras dura la pelea de una sala normal.
func _contar_propina(delta: float) -> void:
	_sala_t += delta
	if _propina_t <= 0.0 or actual.get("tipo") != TIPO.NORMAL:
		_crono.visible = false
		return
	var queda := _propina_t - _sala_t
	_crono.visible = queda > 0.0
	if queda > 0.0:
		_crono.text = Idioma.t("PROPINA %d") % ceili(queda)
		_crono.modulate.a = 0.55 if queda > 3.0 else 0.9


func _cobrar_propina() -> void:
	_crono.visible = false
	if _propina_t <= 0.0 or _sala_t > _propina_t or actual.get("tipo") != TIPO.NORMAL:
		return
	# Más rápido aún, el doble.
	var monedas := (1 + Juego.piso) * (2 if _sala_t <= _propina_t * PROPINA_DOBLE else 1)
	monedas = roundi(monedas * (1.0 + Juego.stat("propina_extra")))
	_propina_t = 0.0
	Juego.ganar_oro(monedas)
	Progreso.sumar("monedas", monedas)
	Progreso.sumar("propinas", 1)
	Sonido.tocar("moneda", 1.3)
	_jugo.texto(jugador.position + Vector2(0, -26), Idioma.t("¡PROPINA! +%d") % monedas, COLOR_CRITICO, true)


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
	# La entrada del jefe, de cine: franjas, la cámara se le acerca y el tiempo se frena.
	_jugo.cine(1.7, jefe.position, 0.09)
	_jugo.camara_lenta(0.7, 0.4)
	_jugo.destello(Color(1, 0.9, 0.8, 0.25), 0.35)
	sacudir(5.0)
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
	Juego.progreso_sala = -1.0
	Juego.balas_sala = 1.0
	if actual.get("tipo") == TIPO.NORMAL and not Juego.diario:
		Juego.presion = Director.ajustar(Juego.presion, _golpes_sala, _propina_t > 0.0 and _sala_t <= _propina_t)
	_cobrar_propina()
	if Juego.nivel_fiebre() >= 3:
		Juego.marcar_logro("rojo_vivo")
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
	if actual.tipo == TIPO.APUESTAS:
		actual["emboscada"] = false
		return  # la emboscada era un castigo: ni cuenta como sala ni deja carta
	_salas_limpiadas += 1
	if Juego.azar_para(int(actual.semilla), "carta").randf() < _prob_carta:
		_prob_carta = 0.4
		_crear_recogible(Recogible.Clase.CARTA, "res://assets/objetos/carta_suelo.png", Sala.CENTRO)
	else:
		_prob_carta += 0.25


func _al_morir_enemigo(posicion: Vector2, oro_prob: float, tipo: String, monedas: int, elite := false) -> void:
	Progreso.sumar("enemigos", 1)
	if tipo != "jefe":
		_sala_bajas += 1
	if elite and Juego.stat("elite_cura") > 0.0:
		Juego.curar(1)
	for _i in monedas:
		_soltar_moneda(posicion)
	if Juego.azar_combate.randf() < oro_prob:
		_soltar_moneda(posicion)
	if tipo == "jefe":
		sacudir(8.0)
		Juego.curar(1)  # hardcore: un jefe ya solo devuelve medio corazón
		Sonido.tocar("jefe_muere")
		Juego.novedades += Progreso.al_vencer_jefe(Juego.jefe_del_piso(), Juego.azar_combate)
		if _sin_golpes:
			Juego.marcar_logro("sin_tocar")
		if not _ordago_en_sala:
			Juego.marcar_logro("sin_despeinarse")
		for i in 16:
			_soltar_moneda(posicion)
		# El golpe final al jefe, a cámara lenta: lo único que de verdad para el juego.
		_jugo.camara_lenta(1.1, 0.22)
		_jugo.destello(Color(1, 1, 1, 0.4), 0.3)
		_jugo.cine(1.8, posicion, 0.1)
	Juego.subir_fiebre(Juego.FIEBRE_POR_JEFE if tipo == "jefe" else Juego.FIEBRE_POR_BAJA)
	Juego.alargar_desatado()
	jugador.remate()
	_efecto_muerte(posicion, tipo == "jefe")
	_jugo.trozos(posicion, 20 if tipo == "jefe" else (9 if ENEMIGOS_GORDOS.has(tipo) else 5), 1.6 if tipo == "jefe" else 1.0)
	# Las bajas normales no paran nada; los gordos, un pelín; los élite, un remate.
	if elite:
		_jugo.parar(0.035)
		sacudir(3.0)
	elif ENEMIGOS_GORDOS.has(tipo):
		_jugo.parar(0.02)
		sacudir(2.0)
	# Remate (uno por baja, aunque coincidan): jefe, élite, cadena o la última de la sala.
	var cadena := _mirar_cadena()
	var ultima := _mirar_ultima_baja(tipo)
	if tipo == "jefe" or elite or cadena or ultima:
		_remate(posicion)


## Un raro o un élite que cae: cuenta para los logros y el élite suelta su botín.
func _al_morir_rango(e: Enemigo) -> void:
	if e.rango == Enemigo.Rango.RARO:
		Progreso.sumar("raros", 1)
		return
	Progreso.sumar("elites", 1)
	if e.golpes_al_nacer >= 0 and e.golpes_al_nacer == _golpes_sala:
		Juego.marcar_logro("elite_limpio")
	var tirada := Juego.azar.randf()
	if tirada < BOTIN_ELITE_CARTA:
		_crear_recogible(Recogible.Clase.CARTA, "res://assets/objetos/carta_suelo.png", e.position)
	elif tirada < BOTIN_ELITE_CARTA + BOTIN_ELITE_CORAZON:
		var corazon := _crear_recogible(Recogible.Clase.CORAZON, "res://assets/objetos/corazon.png", e.position)
		corazon.hframes = 3


## Muchas bajas casi a la vez: remate. Vuelve a contar desde cero tras cada uno.
func _mirar_cadena() -> bool:
	if _cadena_t <= 0.0:
		_cadena = 0
	_cadena += 1
	_cadena_t = CADENA_VENTANA
	if _cadena >= CADENA_REMATE:
		_cadena = 0
		return true
	return false


## Una baja especial (la última de la sala, un élite, una cadena): efecto gordo y sonido.
func _remate(posicion: Vector2) -> void:
	if _jugo.has_method("remate"):
		_jugo.remate(posicion)
	Sonido.tocar("remate", randf_range(0.95, 1.08))


## La última baja de la sala va a cámara lenta: el remate se saborea (breve, que hay prisa).
func _mirar_ultima_baja(tipo: String) -> bool:
	if _lenta_hecha or not en_combate or not _oleadas.is_empty() or not _por_nacer.is_empty() or tipo == "jefe" or tipo == "ficha_grande":
		return false
	if actual.get("tipo") == TIPO.JEFE:
		return false
	for e in _horda.enemigos:
		if not e.muerto:
			return false
	_lenta_hecha = true
	_jugo.camara_lenta(0.4, 0.35)
	sacudir(4.0)
	return true


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


## Los números los pinta el jugo, sin crear nodos. Los golpes dobles salen más grandes.
func _texto_danio(posicion: Vector2, cantidad: float, color: Color) -> void:
	var critico := color.is_equal_approx(COLOR_CRITICO) or _jugo.fue_critico(posicion)
	_jugo.numero_dano(posicion, cantidad, color, critico)


func _al_golpear_jugador() -> void:
	_sin_golpes = false
	_golpes_sala += 1
	Juego.golpes += 1
	_jugo.golpe_jugador()
	if Juego.vida <= 0:
		_jugo.cine(2.5, jugador.position, 0.1)
	sacudir(6.0)
	_jugo.destello(Color(0.84, 0.24, 0.31, 0.45), 0.2)
	_jugo.parar(0.08, true)  # antes 0,1: se nota, pero no corta el ritmo
	Mando.vibrar(Mando.VIBRAR_GOLPE)
	if Juego.vida <= 0:
		_perder()
		return
	# Al límite: corres más y la fiebre sube antes. Se avisa una vez cada vez que entras.
	if Juego.al_limite() and not _limite_avisado:
		_limite_avisado = true
		_jugo.texto(jugador.position + Vector2(0, -24), Idioma.t("¡AL LÍMITE!"), COLOR_LIMITE, true)


## La sacudida la lleva el jugo; aquí se queda el nombre de siempre.
func sacudir(fuerza: float, direccion := Vector2.ZERO) -> void:
	_jugo.sacudir(fuerza, direccion)


# ------------------------------------------------------------ voltereta, órdago, mesas y fiebre
## Q o F (o el botón táctil): borra las balas enemigas y aparta a todos. Solo en combate.
func lanzar_ordago() -> void:
	if get_tree().paused or not en_combate:
		return
	if not Juego.gastar_ordago():
		_jugo.texto(jugador.position + Vector2(0, -18), Idioma.t("SIN ÓRDAGOS"), Color8(168, 154, 142))
		return
	_ordago_en_sala = true
	var centro: Vector2 = jugador.position
	_ataques.borrar_balas_enemigas()
	_horda.empujar_todos(centro, ORDAGO_EMPUJE, ORDAGO_ATURDIR)
	# Pitillera de Plata: además hace daño a todos.
	if Juego.stat("ordago_dano") > 0.0:
		var dano := (10.0 + (Juego.piso - 1) * 8.0) * Juego.stat("ordago_dano")
		for e in _horda.enemigos.duplicate():
			if e.activo():
				_horda.danar(e, dano, Vector2.ZERO, COLOR_FIEBRE)
	jugador.proteger(ORDAGO_RESPIRO)
	Sonido.tocar("ordago")
	_jugo.onda(centro)
	_jugo.destello(Color(1, 1, 1, 0.35), 0.25)
	_jugo.parar(0.05, true)
	sacudir(8.0)
	Mando.vibrar(Mando.VIBRAR_ORDAGO)


func _al_rozar_bala() -> void:
	Progreso.sumar("por_los_pelos", 1)
	_jugo.texto(jugador.position + Vector2(0, -16), Idioma.t("¡POR LOS PELOS!"))


## Una bala te ha pasado rozando sin rodar: la fiebre ya la ha subido el jugador.
func _al_rozar_sin_rodar(posicion: Vector2) -> void:
	Progreso.sumar("roces", 1)
	if _jugo.has_method("roce"):
		_jugo.roce(posicion)


func _al_cambiar_fiebre(nivel: int) -> void:
	if nivel <= 0 or not en_combate or Juego.desatado:
		return
	Sonido.tocar("fiebre", 1.0 + 0.12 * nivel)
	_jugo.texto(jugador.position + Vector2(0, -22), Idioma.t("FIEBRE %d") % nivel, COLOR_FIEBRE, true)


## Desatado: un golpe de efecto al empezar (sin parar casi nada: es para correr).
func _al_desatar(activo: bool) -> void:
	if not activo:
		return
	Progreso.sumar("desatados", 1)
	Sonido.tocar("desatado")
	_jugo.texto(jugador.position + Vector2(0, -26), Idioma.t("¡DESATADO!"), COLOR_FIEBRE, true)
	_jugo.destello(Color(0.94, 0.5, 0.24, 0.3), 0.25)
	_jugo.parar(0.04, true)
	sacudir(5.0)


func _al_volcar_mesa(posicion: Vector2, direccion: Vector2) -> void:
	Progreso.sumar("mesas", 1)
	Sonido.tocar("mesa", randf_range(0.9, 1.1))
	_jugo.polvo(posicion + direccion * 8.0, 6, -direccion)
	sacudir(3.0, direccion)


func _al_romper_mesa(posicion: Vector2) -> void:
	Sonido.tocar("mesa_rota")
	_jugo.polvo(posicion, 8)
	sacudir(2.0)


func _al_golpear_mesa(posicion: Vector2) -> void:
	_jugo.chispas(posicion, Vector2.ZERO, false)


## Lo que depende de la partida y la mesa necesita para hacer daño y aguantar.
func _ajustar_mesas() -> void:
	_sala.refuerzo_mesas = Juego.stat("mesas")
	_sala.dano_mesas = 6.0 + (Juego.piso - 1) * 5.0


## "E: VOLCAR" cuando tienes una mesa de pie al lado (con teclado; en el móvil, rodando).
func _actualizar_hint_mesa() -> void:
	if Juego.tactil or _sala.mesas.is_empty():
		return
	var cerca := _sala.mesa_cerca(jugador.position, 12.0) != null
	if cerca and _hint_mesa == "" and _aviso.text == "":
		_hint_mesa = (Idioma.t("%s: VOLCAR LA MESA") % Mando.nombre("interactuar")) if Mando.activo else Idioma.t("E: VOLCAR LA MESA")
		_aviso.text = _hint_mesa
	elif not cerca and _hint_mesa != "":
		if _aviso.text == _hint_mesa:
			_aviso.text = ""
		_hint_mesa = ""


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
	# Fundido casi instantáneo (antes 0,09 + 0,12 s): de una pelea a la siguiente.
	var ida := create_tween()
	ida.tween_property(_fundido, "color:a", 1.0, 0.05)
	await ida.finished
	entrar_sala(destino, d)
	var vuelta := create_tween()
	vuelta.tween_property(_fundido, "color:a", 0.0, 0.07)
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
			id = Juego.robar_objeto([], Juego.azar_para(int(actual.semilla), "premio"))
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


# ------------------------------------------------------------ sala de apuestas
## La tragaperras y la ruleta. Si una tirada trajo una emboscada y se cerró el juego en
## mitad de la pelea, al volver a entrar empieza otra vez: recargar no la evita.
func _crear_apuestas() -> void:
	for maquina in Sala.MAQUINAS:
		var ruta := "res://assets/objetos/tragaperras.png" if maquina == "tragaperras" else "res://assets/objetos/mesa_ruleta.png"
		var r := _crear_recogible(Recogible.Clase.MAQUINA, ruta, Sala.MAQUINAS[maquina])
		r.datos = {"maquina": maquina}
	_entregar_carta_apuestas.call_deferred()
	if not actual.limpia:
		_empezar_emboscada()


## La máquina que tienes al lado (para E y el botón táctil), o null.
func maquina_a_mano() -> Recogible:
	if actual.get("tipo") != TIPO.APUESTAS or en_combate or get_tree().paused:
		return null
	for r in _recogibles.get_children():
		if not r.is_queued_for_deletion() and r.clase == Recogible.Clase.MAQUINA and r.tocando():
			return r
	return null


func jugar_maquina(r: Recogible) -> void:
	if r == null or _panel_apuestas.visible or en_combate:
		return
	_hint_maquina = ""
	_aviso.text = ""
	get_tree().paused = true
	Sonido.tocar("clic")
	_panel_apuestas.abrir(String(r.datos.maquina), actual)


func _al_cerrar_apuestas() -> void:
	get_tree().paused = false
	_entregar_carta_apuestas()
	if actual.get("emboscada", false) and not actual.limpia:
		_empezar_emboscada()
	_guardar_punto()


## La carta que ganaste con la fila llena: ahora eliges qué cambiar.
func _entregar_carta_apuestas() -> void:
	var carta := String(actual.get("carta_pendiente", ""))
	if carta == "" or _panel_apuestas.visible:
		return
	actual["carta_pendiente"] = ""
	_dar_carta(carta)


## Tres pistolas en la tragaperras: los matones de la casa. Una pelea corta (dos oleadas
## como mucho) y sin propina; mientras dura, las máquinas no se pueden usar.
func _empezar_emboscada() -> void:
	_empezar_combate()
	_oleadas = _oleadas.slice(0, 2)
	_oleadas_total = _oleadas.size()
	_sala_previstos = 0
	for grupo in _oleadas:
		_sala_previstos += grupo.size()
	_propina_t = 0.0
	mostrar_cartel(Idioma.t("¡EMBOSCADA!"), Idioma.t("LOS MATONES DE LA CASA VIENEN A COBRAR"))


func _actualizar_hint_maquina() -> void:
	if actual.get("tipo") != TIPO.APUESTAS:
		return
	var r := maquina_a_mano()
	var texto := ""
	if r != null and not Juego.tactil:
		texto = Idioma.t("E: JUGAR A LA TRAGAPERRAS") if r.datos.maquina == "tragaperras" else Idioma.t("E: JUGAR A LA RULETA")
	if texto == _hint_maquina:
		return
	if _aviso.text == _hint_maquina:
		_aviso.text = texto
	_hint_maquina = texto


func _crear_cofre() -> void:
	var c := _crear_recogible(Recogible.Clase.COFRE, "res://assets/objetos/cofre.png", Sala.CENTRO + Vector2(-46, 0))
	c.hframes = 2
	c.frame = 1 if actual.cofre_abierto else 0


func _crear_premio_tesoro() -> void:
	if actual.get("premio_cogido", false):
		return
	var id: String = actual.get("premio", "")
	if id == "":
		id = Juego.robar_objeto([], Juego.azar_para(int(actual.semilla), "premio"))
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
	var rng := Juego.azar_para(int(actual.semilla), "tienda")
	for id in Juego.robar_cartas(3, 0.0, rng):
		actual.tienda.append({"id": id, "precio": Juego.precio_final(CartasDB.PRECIO_RAREZA[CartasDB.CARTAS[id].rareza])})
	var objeto := Juego.robar_objeto([], rng)
	if objeto != "":
		actual.tienda.append({"id": PREFIJO_OBJETO + objeto, "precio": Juego.precio_final(ObjetosDB.PRECIO)})
	actual.tienda.append({"id": ARTICULO_CORAZON, "precio": Juego.precio_final(PRECIO_CORAZON)})
	actual.tienda.append({"id": ARTICULO_RANURA, "precio": Juego.precio_final(PRECIO_RANURA)})
	actual.tienda.append({"id": ARTICULO_ORDAGO, "precio": Juego.precio_final(PRECIO_ORDAGO)})
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
		ARTICULO_ORDAGO:
			icono.texture = Jugo.textura("res://assets/objetos/ordago.png")
			icono.scale = Vector2(2, 2)
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
		_aviso.text = "" if Juego.tactil else (Idioma.t("%s: COMPRAR") % Mando.nombre("interactuar")) if Mando.activo else Idioma.t("E: COMPRAR")
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
		ARTICULO_ORDAGO:
			info["nombre"] = Idioma.t("Órdago")
			info["desc"] = Idioma.t("Uno más para la reserva: borra todas las balas enemigas y aparta a todos.")
		_:
			info["nombre"] = CartasDB.nombre(id)
			info["desc"] = CartasDB.descripcion(id)
	return info


func _unhandled_input(evento: InputEvent) -> void:
	var del_mando: String = Mando.accion(evento)  # Start pausa, Y interactúa, X o LB órdago
	if (evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_ESCAPE) or del_mando == "pausa":
		quizas_pausar()
		return
	if get_tree().paused:
		return
	match del_mando:
		"interactuar":
			_interactuar()
			return
		"ordago":
			lanzar_ordago()
			return
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match evento.physical_keycode:
		KEY_E:
			_interactuar()
		KEY_Q, KEY_F:
			lanzar_ordago()


## La E (o el botón de interactuar del mando): comprar lo que tienes delante o volcar una mesa.
func _interactuar() -> void:
	var articulo := _articulo_cerca()
	if maquina_a_mano() != null:
		jugar_maquina(maquina_a_mano())
	elif articulo != null:
		comprar(articulo)
	else:
		_sala.volcar_cerca(jugador.position, 12.0, _horda)


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
		ARTICULO_ORDAGO: Juego.ganar_ordagos(1)
		_: _dar_carta(id)


func _rebarajar(r: Recogible) -> void:
	r.datos["precio"] = int(r.datos.precio) + 3
	# Cada vez que rebarajas sale la siguiente tanda de esa tienda: la misma para todos.
	var veces := int(actual.get("rebarajadas", 0)) + 1
	actual["rebarajadas"] = veces
	var nuevas := Juego.robar_cartas(3, 0.0, Juego.azar_para(int(actual.semilla), "rebarajar%d" % veces))
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
	_ajustar_mesas()


func _al_transformarse(id: String) -> void:
	var datos: Dictionary = ObjetosDB.TRANSFORMACIONES[id]
	mostrar_cartel(Idioma.t(datos.nombre).to_upper(), Idioma.t(datos.desc))
	Sonido.tocar("transformacion")
	_al_tenir(id)


func recogido(r: Recogible) -> void:
	# Lo de la sala que acabas de dejar se borra al final del fotograma: ya no se coge.
	if r.is_queued_for_deletion():
		return
	match r.clase:
		Recogible.Clase.MONEDA:
			Juego.ganar_oro(1 + int(Juego.stat("moneda_extra")))
			Progreso.sumar("monedas", 1 + int(Juego.stat("moneda_extra")))
			Sonido.tocar("moneda", randf_range(0.95, 1.2), -6.0)
			r.queue_free()
		Recogible.Clase.CORAZON:
			# El medio corazón que suelta un élite: si vas lleno, se queda en el suelo.
			if Juego.vida >= Juego.vida_max:
				return
			r.queue_free()
			Juego.curar(1)
			Sonido.tocar("objeto", 1.2)
		Recogible.Clase.CARTA:
			r.queue_free()
			Sonido.tocar("carta_coger")
			abrir_selector(Juego.robar_cartas(2, 0.0, Juego.azar_para(int(actual.semilla), "eleccion")), Idioma.t("ELIGE UNA CARTA"))
		Recogible.Clase.EVENTO:
			if actual.get("evento_hecho", false) or _panel.visible:
				return
			get_tree().paused = true
			_panel.abrir(actual.evento, Juego.azar_para(int(actual.semilla), "evento"))
		Recogible.Clase.COFRE:
			if actual.cofre_abierto:
				return
			actual.cofre_abierto = true
			r.frame = 1
			Sonido.tocar("carta_coger")
			abrir_selector(Juego.robar_cartas(3, 1.5, Juego.azar_para(int(actual.semilla), "cofre")), Idioma.t("¡TESORO!"))
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
	Juego.rellenar_ordagos()
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
	_por_nacer.clear()
	_crono.visible = false
	_motor.parar()
	_barra.parar_animacion()
	_horda.limpiar()
	_ataques.limpiar()
	_jugo.limpiar()
	get_tree().paused = true
	Sonido.musica("")
	Guardado.borrar()
	if Juego.infinito:
		Progreso.registrar_infinito(Juego.piso)
	else:
		Juego.novedades += Progreso.al_terminar_partida()
	Juego.revisar_logros(gano)
	if Juego.diario:
		var resumen := Juego.resumen_reto(gano)
		if Juego.reto_puntuable:
			Progreso.registrar_reto_puntuable(resumen)
			_online.enviar_reto(resumen)
		else:
			Progreso.registrar_practica(Juego.fecha_reto, int(resumen.puntos))
	_pantalla.mostrar_final(gano)
