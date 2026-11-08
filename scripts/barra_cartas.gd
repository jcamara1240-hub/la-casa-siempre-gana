class_name BarraCartas
extends Control
## La fila de cartas de abajo: arrastrar, ver el combo y leer cada carta.

signal sustitucion_elegida(ranura: int)
signal sustitucion_cancelada

const ALTO_CARTA := 44
const ANCHO_RANURA := 36
const ORIGEN := Vector2(6, 6)

var en_combate := false
var modo_sustituir := false
var info_externa: Dictionary = {}  # lo que señalas fuera de la fila: objetos, artículos

var _cartas_tex := {}
var _hueco_tex: Texture2D = load("res://assets/cartas/_hueco.png")
var _cerrada_tex: Texture2D = load("res://assets/cartas/_cerrada.png")
var _rebote: Array = []
var _sin_efecto: Array = []
var _arrastrando := -1
var _destino := -1
var _raton := Vector2.ZERO
var _sobre := -1
var _total_visible := 0.0
var _total_pulso := 0.0
var _etiqueta := ""
var _etiqueta_t := 0.0
var _etiqueta_color := Color.WHITE
var _anim_activa := false
var _paso_n := 0

const COLOR_FONDO := Color8(20, 16, 30)
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)
const COLOR_ROJO := Color8(214, 61, 79)


func _ready() -> void:
	for id in CartasDB.CARTAS:
		_cartas_tex[id] = CartasDB.textura(id)
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2(0, 304)
	size = Vector2(640, 56)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Juego.cartas_cambiadas.connect(_recalcular)
	Juego.estado_cambiado.connect(_al_cambiar_estado)
	_recalcular()


func conectar_motor(motor: MotorCartas) -> void:
	motor.ciclo_empezado.connect(_al_empezar_ciclo)
	motor.paso_ejecutado.connect(_al_ejecutar_paso)
	motor.ciclo_terminado.connect(_recalcular)


func _recalcular() -> void:
	_rebote.resize(Juego.cartas.size())
	_rebote.fill(0.0)
	var plan := Combo.resolver(_fila_visible(), Juego.contexto_combo())
	_sin_efecto.resize(Juego.RANURAS_MAX)
	_sin_efecto.fill(false)
	for paso in plan.pasos:
		_sin_efecto[paso.ranura] = paso.sin_efecto
	if not _anim_activa:
		_total_visible = plan.total
	queue_redraw()


## Las monedas y la vida también cuentan en algunos combos.
func _al_cambiar_estado() -> void:
	if not _anim_activa:
		_recalcular()


func _fila_visible() -> Array:
	if _arrastrando != -1 and _destino != -1:
		return Juego.fila_con_movimiento(_arrastrando, _destino)
	return Juego.cartas


func _al_empezar_ciclo(_plan: Dictionary) -> void:
	_anim_activa = true
	_total_visible = 0.0
	_paso_n = 0


func _al_ejecutar_paso(paso: Dictionary) -> void:
	var r: int = paso.ranura
	if r < _rebote.size():
		_rebote[r] = 1.0
	_total_visible = paso.total
	_total_pulso = 1.0
	# Como en Balatro: cada carta de la fila suena un poco más aguda que la anterior.
	var tono := 1.0 + _paso_n * 0.12
	_paso_n += 1
	if paso.tipo == CartasDB.Tipo.MULTIPLICADOR and not paso.sin_efecto:
		Sonido.tocar("mult", tono, -6.0)
	elif not paso.sin_efecto:
		Sonido.tocar("tick", tono, -8.0)
	if paso.tipo == CartasDB.Tipo.MULTIPLICADOR and not paso.sin_efecto:
		_etiqueta = paso.texto
		_etiqueta_t = 0.45
		_etiqueta_color = COLOR_ORO


func parar_animacion() -> void:
	_anim_activa = false
	_recalcular()


func _process(delta: float) -> void:
	for i in _rebote.size():
		_rebote[i] = maxf(0.0, _rebote[i] - delta * 5.0)
	_total_pulso = maxf(0.0, _total_pulso - delta * 6.0)
	_etiqueta_t = maxf(0.0, _etiqueta_t - delta)
	queue_redraw()


func _ranura_en(p: Vector2) -> int:
	if p.y < ORIGEN.y - 4 or p.y > ORIGEN.y + ALTO_CARTA + 4:
		return -1
	var i := floori((p.x - ORIGEN.x + 2) / ANCHO_RANURA)
	return i if i >= 0 and i < Juego.cartas.size() else -1


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		_raton = evento.position
		_sobre = _ranura_en(_raton)
		if _arrastrando != -1:
			var nuevo := _ranura_en(_raton)
			if nuevo != -1 and nuevo != _destino:
				_destino = nuevo
				_recalcular()
		queue_redraw()
	elif evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			_pulsar(_ranura_en(evento.position))
		else:
			_soltar()
	elif evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_RIGHT and evento.pressed:
		if modo_sustituir:
			sustitucion_cancelada.emit()


func _pulsar(r: int) -> void:
	if r == -1:
		return
	if modo_sustituir:
		if Juego.cartas[r] != "":
			sustitucion_elegida.emit(r)
		return
	if en_combate or get_tree().paused or Juego.cartas[r] == "":
		return
	_arrastrando = r
	_destino = r
	_recalcular()


func _soltar() -> void:
	if _arrastrando == -1:
		return
	var origen := _arrastrando
	var destino := _destino
	_arrastrando = -1
	_destino = -1
	if destino != -1 and destino != origen:
		Juego.mover_carta(origen, destino)
	else:
		_recalcular()


func _textura(id: String) -> Texture2D:
	if not _cartas_tex.has(id):
		_cartas_tex[id] = CartasDB.textura(id)
	return _cartas_tex[id]


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 56), COLOR_FONDO)
	draw_rect(Rect2(0, 0, 640, 1), Color8(74, 52, 102))
	var fila := _fila_visible()
	for i in Juego.RANURAS_MAX:
		var p := ORIGEN + Vector2(i * ANCHO_RANURA, 0)
		if i >= fila.size():
			draw_texture(_cerrada_tex, p)
			continue
		draw_texture(_hueco_tex, p)
		var id: String = fila[i]
		if id == "" or (_arrastrando != -1 and i == _destino):
			continue
		var salto: float = _rebote[i] * 5.0 if i < _rebote.size() else 0.0
		var tinte := Color(0.5, 0.5, 0.55) if _sin_efecto[i] else Color.WHITE
		draw_texture(_textura(id), p + Vector2(0, -salto), tinte)
		if i < _rebote.size() and _rebote[i] > 0.5:
			draw_rect(Rect2(p + Vector2(0, -salto), Vector2(32, 44)), COLOR_CREMA, false, 1.0)
	if _arrastrando != -1:
		draw_texture(_textura(Juego.cartas[_arrastrando]), _raton - Vector2(16, 22))
	_dibujar_combo()
	_dibujar_info()


func _dibujar_combo() -> void:
	var x := 300.0
	var fuente := Juego.fuente
	draw_string(fuente, Vector2(x, 15), Idioma.t("DAÑO POR CICLO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS)
	var numero := str(roundi(_total_visible))
	var color := COLOR_CREMA.lerp(COLOR_ORO, _total_pulso)
	var y := 42.0 - _total_pulso * 3.0
	draw_string(Juego.fuente_grande, Vector2(x, y), numero, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	if _etiqueta_t > 0.0:
		var ancho := Juego.fuente_grande.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(Juego.fuente_grande, Vector2(x + ancho + 10, 42), _etiqueta,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, _etiqueta_color)


func _dibujar_info() -> void:
	var fuente := Juego.fuente
	var x := 412.0
	var ancho := 222.0
	if modo_sustituir:
		_parrafo(Idioma.t("FILA LLENA. HAZ CLIC EN LA CARTA QUE QUIERAS CAMBIAR. CLIC DERECHO: CANCELAR."), x, ancho, COLOR_ORO)
		return
	if not info_externa.is_empty():
		draw_string(fuente, Vector2(x, 15), info_externa.nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO)
		_parrafo(info_externa.desc, x, ancho, COLOR_CREMA, 27)
		return
	var id := ""
	var fila := _fila_visible()
	if _sobre >= 0 and _sobre < fila.size():
		id = fila[_sobre]
	if id != "":
		var nombre_carta := CartasDB.nombre(id)
		draw_string(fuente, Vector2(x, 15), nombre_carta, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO)
		var aviso: String = Idioma.t("   SIN EFECTO AQUÍ") if _sin_efecto[_sobre] else ""
		draw_string(fuente, Vector2(x + fuente.get_string_size(nombre_carta).x, 15), aviso,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ROJO)
		_parrafo(CartasDB.descripcion(id), x, ancho, COLOR_CREMA, 27)
	elif en_combate:
		_parrafo(Idioma.t("LAS CARTAS SE COLOCAN CUANDO LA SALA ESTÉ LIMPIA."), x, ancho, COLOR_GRIS)
	else:
		_parrafo(Idioma.t("ARRASTRA LAS CARTAS PARA CAMBIAR EL ORDEN. SE EJECUTAN DE IZQUIERDA A DERECHA."), x, ancho, COLOR_GRIS)


func _parrafo(texto: String, x: float, ancho: float, color: Color, y := 15) -> void:
	draw_multiline_string(Juego.fuente, Vector2(x, y), texto, HORIZONTAL_ALIGNMENT_LEFT, ancho, 8, 4, color)
