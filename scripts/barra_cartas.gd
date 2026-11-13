class_name BarraCartas
extends Control
## La fila de cartas de abajo: arrastrar, ver el combo y leer cada carta.
## Con el mando hay un "modo cartas" (botón Select/View/Share/-, con la sala limpia): la cruceta
## elige carta, A la coge y la suelta en otro sitio, B o Select salen.

signal sustitucion_elegida(ranura: int)
signal sustitucion_cancelada

const ALTO_CARTA := 44
const ANCHO_RANURA := 36
const ORIGEN := Vector2(6, 6)

var en_combate := false
var modo_sustituir := false
var info_externa: Dictionary = {}  # lo que señalas fuera de la fila: objetos, artículos
var modo_cartas := false  # ordenando la fila con el mando

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
var _cursor := 0  # la ranura señalada con el mando (modo cartas y fila llena)
## Cooperativo: ¿es este evento del que tiene el panel abierto? (lo pone main; sin él, de todos).
## La fila lee el mando antes que main, así que mira ella misma de quién es lo que llega.
var es_del_dueno: Callable
var _disp_cartas := -1  # en cooperativo, el mando que está ordenando (-1: cualquiera)
var _con_teclas := false  # qué carta cambiar se está eligiendo con el teclado (cooperativo)

const COLOR_FONDO := Color8(20, 16, 30)
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)
const COLOR_ROJO := Color8(214, 61, 79)
const COLOR_FIEBRE := Color8(240, 129, 60)
const COLOR_MARCO := Color8(74, 52, 102)
const COLOR_SUMA := Color8(46, 111, 176)

# Desglose del ciclo, como en Balatro: encima de cada carta, lo que suma o multiplica
# ("+5", "x2") en el orden en que se ejecuta, y al final el total da un salto (en oro y con
# sonido si bate tu mejor combo). Los ciclos pueden ir muy deprisa (Fiebre, desatado), así que:
#   - cada etiqueta vive APORTE_VIDA aunque el ciclo sea más corto: se lee entera;
#   - mientras el total no cambie, se desglosa como mucho un ciclo cada DESGLOSE_PAUSA; los
#     ciclos de en medio solo mueven el número, sin etiquetas ni salto (si no, sería un parpadeo);
#   - si el total cambia (carta nueva, fiebre...) se vuelve a desglosar antes (DESGLOSE_MIN),
#     y un récord se desglosa siempre; su sonido, como mucho uno cada RECORD_SONIDO.
# Con varios ciclos dobles (objeto "doble_ciclo") solo se desglosa el primer pase.
const APORTE_VIDA := 0.55
const DESGLOSE_PAUSA := 1.6
const DESGLOSE_MIN := 0.6
const RECORD_SONIDO := 2.0
const POP_SEG := 0.35

var desgloses := 0  # cuántos ciclos se han desglosado (lo miran las pruebas)
var _aporte_texto: Array = []
var _aporte_t: Array = []
var _aporte_mult: Array = []
var _desglose := false  # el ciclo en marcha se está desglosando
var _desglose_pasos := 0  # los pasos que quedan de su primer pase
var _desde_desglose := 99.0
var _total_desglose := -1
var _record := false
var _pop_t := 0.0
var _pop_record := false
var _record_espera := 0.0


func _ready() -> void:
	for id in CartasDB.CARTAS:
		_cartas_tex[id] = CartasDB.textura(id)
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2(0, 304)
	size = Vector2(640, 56)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_aporte_texto.resize(Juego.RANURAS_MAX)
	_aporte_texto.fill("")
	_aporte_t.resize(Juego.RANURAS_MAX)
	_aporte_t.fill(0.0)
	_aporte_mult.resize(Juego.RANURAS_MAX)
	_aporte_mult.fill(false)
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


func _al_empezar_ciclo(plan: Dictionary) -> void:
	_anim_activa = true
	_total_visible = 0.0
	_paso_n = 0
	_empezar_desglose(plan)


## ¿Se desglosa este ciclo? Ver la cadencia arriba, junto a APORTE_VIDA.
func _empezar_desglose(plan: Dictionary) -> void:
	_desglose = false
	if not Juego.desglose_ciclo or plan.pasos.is_empty():
		return
	var total := roundi(plan.total)
	var record: bool = plan.get("record", false)
	var espera := DESGLOSE_MIN if total != _total_desglose else DESGLOSE_PAUSA
	if not record and _desde_desglose < espera:
		return
	_desglose = true
	_desglose_pasos = plan.pasos.size()
	_record = record
	_total_desglose = total
	_desde_desglose = 0.0
	_aporte_t.fill(0.0)
	desgloses += 1


func _apuntar_aporte(paso: Dictionary) -> void:
	if not _desglose or _desglose_pasos <= 0:
		return
	_desglose_pasos -= 1
	var r: int = paso.ranura
	var aporte := String(paso.get("aporte", ""))
	if aporte != "" and r < _aporte_t.size():
		var valor := float(paso.valor)
		_aporte_mult[r] = aporte == "mult"
		_aporte_texto[r] = ("X" + Combo._numero(valor)) if aporte == "mult" else ("+" + _cifra(valor))
		_aporte_t[r] = APORTE_VIDA
	if _desglose_pasos == 0:
		# La última carta: el total salta.
		_pop_t = 1.0
		_pop_record = _record
		if _record and _record_espera <= 0.0:
			Sonido.tocar("remate", 1.2, -5.0)
			_record_espera = RECORD_SONIDO


static func _cifra(v: float) -> String:
	return str(roundi(v)) if v >= 10.0 or is_equal_approx(v, roundf(v)) else "%.1f" % v


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
	_apuntar_aporte(paso)


func parar_animacion() -> void:
	_anim_activa = false
	_desglose = false
	_recalcular()


func _process(delta: float) -> void:
	_t += delta
	for i in _rebote.size():
		_rebote[i] = maxf(0.0, _rebote[i] - delta * 5.0)
	_total_pulso = maxf(0.0, _total_pulso - delta * 6.0)
	for i in _mult_cambio.size():
		_mult_cambio[i] = maxf(0.0, _mult_cambio[i] - delta * 1.6)
	_etiqueta_t = maxf(0.0, _etiqueta_t - delta)
	for i in _aporte_t.size():
		_aporte_t[i] = maxf(0.0, _aporte_t[i] - delta)
	_pop_t = maxf(0.0, _pop_t - delta / POP_SEG)
	_desde_desglose += delta
	_record_espera -= delta
	# La Fiebre, las volteretas y los órdagos cambian en plena sala: se mira a menudo
	# para que sus cartas se enciendan y se apaguen a tiempo.
	_refresco_t -= delta
	if en_combate and _refresco_t <= 0.0 and not get_tree().paused:
		_refresco_t = 0.25
		_marcar_sin_efecto()
	# Si empieza una pelea o se abre algo encima, el modo cartas se cierra solo.
	if modo_cartas and (en_combate or get_tree().paused or modo_sustituir):
		salir_modo_cartas()
	queue_redraw()


# ------------------------------------------------------------ mando
## Con el mando, la fila se maneja aquí antes que nadie: así A no rueda mientras ordenas.
## En cooperativo, qué carta cambiar lo elige solo quien tiene el panel (también con el
## teclado: el J2 del teclado repartido no tiene ratón), y ordenar es del mando que ha entrado:
## lo del otro le llega a su jugador, que sigue a lo suyo.
func _input(evento: InputEvent) -> void:
	if modo_sustituir:
		if not es_del_dueno.is_valid() or es_del_dueno.call(evento):
			_mando_sustituir(evento)
		return
	if not Mando.es_mando(evento):
		return
	if modo_cartas:
		if _disp_cartas < 0 or evento.device == _disp_cartas:
			_mando_cartas(evento)
	elif Mando.accion(evento) == "cartas" and not get_tree().paused:  # en los menús, Select es "volver"
		if puede_ordenar():
			entrar_modo_cartas(evento.device if Juego.coop else -1)
		else:
			Sonido.tocar("perder")
		get_viewport().set_input_as_handled()


## Ni en plena pelea ni con una carta cogida con el ratón (en cooperativo, la del otro).
func puede_ordenar() -> bool:
	return not en_combate and not modo_sustituir and not get_tree().paused and not Juego.cartas.is_empty() and _arrastrando == -1


## "disp": en cooperativo, el mando que ordena (los demás no tocan la fila ni se quedan quietos).
func entrar_modo_cartas(disp := -1) -> void:
	modo_cartas = true
	Mando.bloqueado = true
	_disp_cartas = disp
	Mando.bloqueado_disp = disp
	_cursor = clampi(_cursor, 0, Juego.cartas.size() - 1)
	_sobre = _cursor
	Sonido.tocar("clic")
	queue_redraw()


## Sale del modo cartas; si llevabas una carta cogida, vuelve a su sitio.
func salir_modo_cartas() -> void:
	modo_cartas = false
	Mando.bloqueado = false
	_disp_cartas = -1
	Mando.bloqueado_disp = -1
	_sobre = -1
	if _arrastrando != -1:
		_arrastrando = -1
		_destino = -1
		_recalcular()
	queue_redraw()


func _mando_cartas(evento: InputEvent) -> void:
	# Start sale del modo y sigue su camino: pausa.
	if Mando.accion(evento) == "pausa":
		salir_modo_cartas()
		return
	var tecla := Mando.tecla_mando(evento)
	get_viewport().set_input_as_handled()  # el stick tampoco mueve al jugador
	match tecla:
		KEY_LEFT, KEY_RIGHT:
			_mover_cursor(-1 if tecla == KEY_LEFT else 1)
			if _arrastrando != -1:
				_destino = _cursor
				_recalcular()
		KEY_ENTER:
			if _arrastrando == -1:
				if Juego.cartas[_cursor] != "":
					_arrastrando = _cursor
					_destino = _cursor
					Sonido.tocar("carta_coger")
					_recalcular()
			else:
				Sonido.tocar("clic")
				_soltar()
		KEY_ESCAPE:
			# B con una carta cogida la devuelve; sin carta (o con Select), se sale.
			if _arrastrando != -1 and Mando.accion(evento) != "cartas":
				_arrastrando = -1
				_destino = -1
				_recalcular()
			else:
				salir_modo_cartas()
			Sonido.tocar("clic")


## La fila está llena y llega una carta: la cruceta elige cuál se cambia, A la cambia, B cancela.
## En cooperativo, también las flechas, Intro y Retroceso (o WASD, E y Esc).
func _mando_sustituir(evento: InputEvent) -> void:
	var tecla := Mando.tecla_panel(evento, Juego.coop)
	if tecla == KEY_NONE:
		return
	get_viewport().set_input_as_handled()
	_con_teclas = evento is InputEventKey
	match tecla:
		KEY_LEFT, KEY_RIGHT:
			_mover_cursor(-1 if tecla == KEY_LEFT else 1)
		KEY_ENTER:
			if _cursor < Juego.cartas.size() and Juego.cartas[_cursor] != "":
				sustitucion_elegida.emit(_cursor)
		KEY_ESCAPE:
			sustitucion_cancelada.emit()


func _mover_cursor(paso: int) -> void:
	_cursor = wrapi(_cursor + paso, 0, maxi(Juego.cartas.size(), 1))
	_sobre = _cursor
	Sonido.tocar("mover")


## Se ve el cursor del mando: en el modo cartas y cuando hay que elegir cuál cambiar.
func _cursor_visible() -> bool:
	return modo_cartas or (modo_sustituir and (Mando.activo or _con_teclas))


func _ranura_en(p: Vector2) -> int:
	if p.y < ORIGEN.y - 4 or p.y > ORIGEN.y + ALTO_CARTA + 4:
		return -1
	var i := floori((p.x - ORIGEN.x + 2) / ANCHO_RANURA)
	return i if i >= 0 and i < Juego.cartas.size() else -1


func _gui_input(evento: InputEvent) -> void:
	if modo_cartas and _disp_cartas >= 0:
		return  # cooperativo: la fila la está ordenando un mando; el ratón del otro no la toca
	if evento is InputEventMouseMotion:
		_con_teclas = false
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
	for i in mini(fila.size(), _aporte_t.size()):
		_dibujar_aporte(i)
	if _cursor_visible():
		_dibujar_cursor()
	elif _arrastrando != -1:
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


## Lo que ha sumado o multiplicado la carta en el desglose: una placa azul (suma) o roja
## (multiplica) sobre su borde de arriba, que entra grande y se apaga sola.
func _dibujar_aporte(ranura: int) -> void:
	var queda: float = _aporte_t[ranura]
	if queda <= 0.0:
		return
	var texto: String = _aporte_texto[ranura]
	var pasado := APORTE_VIDA - queda
	var escala := 1.5 if pasado < 0.05 else 1.0
	var alfa := clampf(queda / 0.15, 0.0, 1.0)
	var ancho := roundf(Juego.fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var centro := ORIGEN + Vector2(ranura * ANCHO_RANURA + 16.0, 1.0)
	var placa := Rect2(-roundf(ancho * 0.5) - 2.0, -5.0, ancho + 4.0, 10.0)
	draw_set_transform(centro, 0.0, Vector2(escala, escala))
	draw_rect(placa.grow(1.0), Color(COLOR_FONDO, alfa))
	draw_rect(placa, Color(COLOR_ROJO if _aporte_mult[ranura] else COLOR_SUMA, alfa))
	draw_string(Juego.fuente, Vector2(placa.position.x + 2.0, 3.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(COLOR_CREMA, alfa))
	draw_set_transform(Vector2.ZERO)


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
## El cursor del mando: marco dorado y una flecha encima. La carta cogida va levantada
## sobre la ranura donde caería, y arriba se recuerda qué hace cada botón.
func _dibujar_cursor() -> void:
	_cursor = clampi(_cursor, 0, maxi(Juego.cartas.size() - 1, 0))
	var p := ORIGEN + Vector2(_cursor * ANCHO_RANURA, 0)
	var cogida := _arrastrando != -1 and modo_cartas
	var subir := 5.0 if cogida else 0.0
	var carta := Rect2(p + Vector2(0, -subir), Vector2(32, 44))
	if cogida:
		draw_texture(_textura(Juego.cartas[_arrastrando]), carta.position)
	var brillo := 0.75 + 0.25 * sin(_t * 8.0)
	draw_rect(carta.grow(2.0), Color(COLOR_ORO, brillo), false, 1.0)
	var c := Vector2(carta.get_center().x, carta.position.y - 4.0).round()
	draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -3), c + Vector2(3, -3), c + Vector2(0, 0)]), COLOR_ORO)
	if not modo_cartas:
		return
	var ayuda := Idioma.t("CRUCETA: ELEGIR   %s: COGER Y SOLTAR   %s: SALIR") % [Mando.nombre("aceptar"), Mando.nombre("volver")]
	var ancho: float = Juego.fuente.get_string_size(ayuda, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_rect(Rect2(2, -15, ancho + 8, 11), Color(COLOR_FONDO, 0.85))
	draw_string(Juego.fuente, Vector2(6, -7), ayuda, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO)


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
	if _pop_t > 0.0:
		# El total del desglose: un salto de escala; en oro si es récord.
		var escala := 1.0 + 0.5 * _pop_t * _pop_t
		if _pop_record:
			color = COLOR_ORO
			draw_string(fuente, Vector2(x + 76.0, 15), Idioma.t("¡RÉCORD!"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO)
		draw_set_transform(Vector2(x, 42.0), 0.0, Vector2(escala, escala))
		draw_string(Juego.fuente_grande, Vector2(0.0, y - 42.0), numero, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		draw_set_transform(Vector2.ZERO)
	else:
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
		if Mando.activo:
			_parrafo(Idioma.t("FILA LLENA. ELIGE CON LA CRUCETA LA CARTA QUE QUIERAS CAMBIAR. %s: CAMBIAR. %s: CANCELAR.") % [
					Mando.nombre("aceptar"), Mando.nombre("volver")], x, ancho, COLOR_ORO)
			return
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
	elif Mando.activo:
		_parrafo(Idioma.t("%s: ORDENAR LAS CARTAS. SE EJECUTAN DE IZQUIERDA A DERECHA.") % Mando.nombre("cartas"), x, ancho, COLOR_GRIS)
	else:
		_parrafo(Idioma.t("ARRASTRA LAS CARTAS PARA CAMBIAR EL ORDEN. SE EJECUTAN DE IZQUIERDA A DERECHA."), x, ancho, COLOR_GRIS)


func _parrafo(texto: String, x: float, ancho: float, color: Color, y := 15) -> void:
	draw_multiline_string(Juego.fuente, Vector2(x, y), texto, HORIZONTAL_ALIGNMENT_LEFT, ancho, 8, 4, color)
