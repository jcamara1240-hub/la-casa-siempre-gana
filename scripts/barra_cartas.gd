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
var _mult_ahora: Array = []  # lo que multiplica ahora mismo cada carta ("x1.75"), o "" si no multiplica
var _mult_cambio: Array = []  # 1 justo cuando su multiplicador cambia; se apaga solo
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
var _refresco_t := 0.0
var _etiqueta_dur := 0.45
var _t := 0.0

const COLOR_FONDO := Color8(20, 16, 30)
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)
const COLOR_ROJO := Color8(214, 61, 79)
const COLOR_FIEBRE := Color8(240, 129, 60)
const COLOR_MARCO := Color8(74, 52, 102)


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
	_marcar_sin_efecto()
	queue_redraw()


## Qué cartas no hacen nada ahora mismo (y el total, si no se está animando un ciclo).
func _marcar_sin_efecto() -> void:
	var plan := Combo.resolver(_fila_visible(), Juego.contexto_combo())
	_sin_efecto.resize(Juego.RANURAS_MAX)
	_sin_efecto.fill(false)
	if _mult_ahora.size() != Juego.RANURAS_MAX:
		_mult_ahora.resize(Juego.RANURAS_MAX)
		_mult_ahora.fill("")
		_mult_cambio.resize(Juego.RANURAS_MAX)
		_mult_cambio.fill(0.0)
	var antes := _mult_ahora.duplicate()
	_mult_ahora.fill("")
	for paso in plan.pasos:
		_sin_efecto[paso.ranura] = paso.sin_efecto
		# Racha, Hucha, Fiebre, Mesa Llena...: su multiplicador sube y baja, y se enseña.
		if paso.tipo == CartasDB.Tipo.MULTIPLICADOR:
			_mult_ahora[paso.ranura] = String(paso.texto) if String(paso.texto) != "" else "x1"
	for i in _mult_ahora.size():
		if _mult_ahora[i] != antes[i] and _mult_ahora[i] != "" and antes[i] != "":
			_mult_cambio[i] = 1.0
	if not _anim_activa:
		_total_visible = plan.total


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
		_etiqueta_dur = _etiqueta_t
		_etiqueta_color = COLOR_ORO
	elif paso.ataque.get("premio", false):
		# La Ruleta Rusa ha salido: que se vea.
		_etiqueta = "x%d" % roundi(Combo.PREMIO_RULETA)
		_etiqueta_t = 0.7
		_etiqueta_dur = _etiqueta_t
		_etiqueta_color = COLOR_ROJO


func parar_animacion() -> void:
	_anim_activa = false
	_recalcular()


func _process(delta: float) -> void:
	_t += delta
	for i in _rebote.size():
		_rebote[i] = maxf(0.0, _rebote[i] - delta * 5.0)
	_total_pulso = maxf(0.0, _total_pulso - delta * 6.0)
	for i in _mult_cambio.size():
		_mult_cambio[i] = maxf(0.0, _mult_cambio[i] - delta * 1.6)
	_etiqueta_t = maxf(0.0, _etiqueta_t - delta)
	# La Fiebre, las volteretas y los órdagos cambian en plena sala: se mira a menudo
	# para que sus cartas se enciendan y se apaguen a tiempo.
	_refresco_t -= delta
	if en_combate and _refresco_t <= 0.0 and not get_tree().paused:
		_refresco_t = 0.25
		_marcar_sin_efecto()
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
			if modo_sustituir and Juego.tactil and evento.position.x >= 412.0:
				sustitucion_cancelada.emit()
				return
			_pulsar(_ranura_en(evento.position))
		else:
			_soltar()
	elif evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_RIGHT and evento.pressed:
		if modo_sustituir:
			sustitucion_cancelada.emit()


func _pulsar(r: int) -> void:
	_sobre = r  # con el dedo no hay "pasar por encima": tocar una carta la describe
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
	_dibujar_borde()
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
		var rebote: float = _rebote[i] if i < _rebote.size() else 0.0
		var salto := roundf(rebote * 5.0)
		var carta := Rect2(p + Vector2(0, -salto), Vector2(32, 44))
		if rebote > 0.0:
			# La carta que se dispara: un halo dorado detrás que se apaga enseguida.
			draw_rect(carta.grow(3.0), Color(COLOR_ORO, 0.18 * rebote))
			draw_rect(carta.grow(1.0), Color(COLOR_ORO, 0.55 * rebote))
		var tinte := Color(0.5, 0.5, 0.55) if _sin_efecto[i] else Color.WHITE
		draw_texture(_textura(id), carta.position, tinte)
		_dibujar_multiplicador(i, carta)
		if rebote > 0.0:
			_dibujar_disparo(carta, rebote)
	if _arrastrando != -1:
		draw_texture(_textura(Juego.cartas[_arrastrando]), _raton - Vector2(16, 22))
	_dibujar_combo()
	_dibujar_info()


## El multiplicador que da la carta ahora mismo, en una placa sobre su borde de abajo.
## En gris si ahora no multiplica nada; en oro si sí, y con un destello cuando cambia.
func _dibujar_multiplicador(ranura: int, carta: Rect2) -> void:
	if ranura >= _mult_ahora.size() or _mult_ahora[ranura] == "":
		return
	var texto: String = String(_mult_ahora[ranura]).to_upper()
	var cambio: float = _mult_cambio[ranura]
	var activo: bool = texto != "X1" and not _sin_efecto[ranura]
	var color := COLOR_ORO if activo else COLOR_GRIS
	if cambio > 0.0:
		color = color.lerp(COLOR_CREMA, cambio)
	var ancho: float = Juego.fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var placa := Rect2(carta.position.x + 16.0 - roundf(ancho * 0.5) - 2.0, carta.position.y + 34.0 - roundf(cambio * 2.0), ancho + 4.0, 10.0)
	draw_rect(placa.grow(1.0), color if cambio > 0.3 else COLOR_MARCO)
	draw_rect(placa, COLOR_FONDO)
	draw_string(Juego.fuente, placa.position + Vector2(2.0, 8.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)


## Un destello crema al principio, el borde blanco y unas chispas que suben de la carta;
## debajo, una muesca dorada marca cuál se acaba de disparar.
func _dibujar_disparo(carta: Rect2, rebote: float) -> void:
	if rebote > 0.6:
		draw_rect(carta, Color(1.0, 0.97, 0.88, (rebote - 0.6) * 1.1))
	if rebote > 0.4:
		draw_rect(carta, COLOR_CREMA, false, 1.0)
	var sube := roundf((1.0 - rebote) * 9.0)
	for k in 4:
		var x := carta.position.x + 5.0 + k * 7.0 + (1.0 if k % 2 == 0 else 0.0)
		var y := carta.position.y - 3.0 - sube - (2.0 if k % 2 == 0 else 0.0)
		draw_rect(Rect2(x, y, 1, 2), Color(COLOR_ORO if k % 2 == 0 else COLOR_CREMA, rebote))
	var c := Vector2(carta.get_center().x, ORIGEN.y + ALTO_CARTA + 3.0).round()
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2), c + Vector2(3, 1), c + Vector2(-3, 1)]), Color(COLOR_ORO, rebote))


## La raya de arriba de la fila se calienta con la Fiebre y arde desatada.
func _dibujar_borde() -> void:
	var borde := COLOR_MARCO
	var fiebre := clampf(Juego.fiebre / 3.0, 0.0, 1.0)
	var desatado: bool = Juego.get("desatado") == true
	if desatado:
		borde = COLOR_ORO.lerp(COLOR_ROJO, 0.5 + 0.5 * sin(_t * 20.0))
	elif fiebre > 0.0:
		borde = COLOR_MARCO.lerp(COLOR_FIEBRE, fiebre)
	draw_rect(Rect2(0, 0, 640, 1), borde)
	if desatado or fiebre >= 1.0:
		draw_rect(Rect2(0, 1, 640, 1), Color(borde, 0.3 + 0.15 * sin(_t * 9.0)))


func _dibujar_combo() -> void:
	var x := 300.0
	var fuente := Juego.fuente
	draw_string(fuente, Vector2(x, 15), Idioma.t("DAÑO POR CICLO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS)
	var numero := str(roundi(_total_visible))
	var color := COLOR_CREMA.lerp(COLOR_ORO, _total_pulso)
	var y := roundf(42.0 - _total_pulso * 3.0)
	draw_string(Juego.fuente_grande, Vector2(x, y), numero, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	if _etiqueta_t > 0.0:
		var ancho := Juego.fuente_grande.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		# El multiplicador entra de golpe al doble de tamaño (creciendo hacia la derecha,
		# sin pisar el número) y se asienta.
		var pasado := _etiqueta_dur - _etiqueta_t
		var escala := 2.0 if pasado < 0.06 else 1.0
		var color_etiqueta := _etiqueta_color
		color_etiqueta.a = clampf(_etiqueta_t / 0.12, 0.0, 1.0)
		draw_set_transform(Vector2(x + ancho + 10.0, 36.0), 0.0, Vector2(escala, escala))
		draw_string(Juego.fuente_grande, Vector2(0.0, 6.0), _etiqueta,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color_etiqueta)
		draw_set_transform(Vector2.ZERO)


func _dibujar_info() -> void:
	var fuente := Juego.fuente
	var x := 412.0
	var ancho := 222.0
	if modo_sustituir:
		var aviso_fila := "FILA LLENA. TOCA LA CARTA QUE QUIERAS CAMBIAR O TOCA AQUÍ PARA CANCELAR." if Juego.tactil else "FILA LLENA. HAZ CLIC EN LA CARTA QUE QUIERAS CAMBIAR. CLIC DERECHO: CANCELAR."
		_parrafo(Idioma.t(aviso_fila), x, ancho, COLOR_ORO)
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
