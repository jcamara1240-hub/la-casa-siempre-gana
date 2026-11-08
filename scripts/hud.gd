class_name Hud
extends Control
## Vidas, oro, mapa y barra del jefe, pintados sobre el muro de arriba.

var salas: Dictionary = {}
var posicion_actual := Vector2i.ZERO
var horda: Horda
var barra: BarraCartas

var _texturas_objetos := {}
var _cola_logros: Array = []
var _logro_t := 0.0
@onready var _trofeo: Texture2D = load("res://assets/objetos/trofeo.png")

var _corazon: Texture2D = load("res://assets/objetos/corazon.png")
var _moneda: Texture2D = load("res://assets/objetos/moneda.png")

const COLOR_MAPA := {
	GeneradorMazmorra.Tipo.INICIO: Color8(168, 154, 142),
	GeneradorMazmorra.Tipo.NORMAL: Color8(122, 90, 160),
	GeneradorMazmorra.Tipo.TESORO: Color8(247, 198, 74),
	GeneradorMazmorra.Tipo.TIENDA: Color8(108, 207, 148),
	GeneradorMazmorra.Tipo.JEFE: Color8(214, 61, 79),
	GeneradorMazmorra.Tipo.EVENTO: Color8(111, 195, 232),
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 304)
	Juego.estado_cambiado.connect(queue_redraw)


func avisar_logro(id: String) -> void:
	_cola_logros.append(id)
	if _cola_logros.size() == 1:
		_logro_t = 2.6


func _process(delta: float) -> void:
	queue_redraw()
	_mirar_raton()
	if not _cola_logros.is_empty():
		_logro_t -= delta
		if _logro_t <= 0.0:
			_cola_logros.pop_front()
			_logro_t = 2.6


func _dibujar_logro() -> void:
	if _cola_logros.is_empty():
		return
	var caja := Rect2(404, 36, 232, 22)
	draw_rect(caja, Color8(20, 16, 30))
	draw_rect(caja, Color8(247, 198, 74), false, 1.0)
	draw_texture(_trofeo, caja.position + Vector2(5, 5))
	draw_string(Juego.fuente, caja.position + Vector2(22, 9), Idioma.t("LOGRO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(168, 154, 142))
	draw_string(Juego.fuente, caja.position + Vector2(22, 18), LogrosDB.nombre(_cola_logros[0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(247, 198, 74))


func _caja_transformacion(i: int) -> Rect2:
	return Rect2(566.0 - i * 13.0, 4.0, 11.0, 11.0)


func _caja_objeto(i: int) -> Rect2:
	return Rect2(98 + (i % 10) * 13, 3 + (i / 10) * 13, 12, 12)


## El ratón sobre un objeto de arriba: su descripción sale en la barra de cartas.
func _mirar_raton() -> void:
	if barra == null or barra.info_externa.get("origen") == "tienda":
		return
	var raton := get_local_mouse_position()
	for i in Juego.transformaciones.size():
		if _caja_transformacion(i).has_point(raton):
			var t: String = Juego.transformaciones[i]
			barra.info_externa = {"nombre": Idioma.t(ObjetosDB.TRANSFORMACIONES[t].nombre), "desc": Idioma.t(ObjetosDB.TRANSFORMACIONES[t].desc), "origen": "hud"}
			return
	for i in Juego.objetos.size():
		if _caja_objeto(i).has_point(raton):
			var id: String = Juego.objetos[i]
			barra.info_externa = {"nombre": ObjetosDB.nombre(id), "desc": ObjetosDB.descripcion(id), "origen": "hud"}
			return
	if barra.info_externa.get("origen") == "hud":
		barra.info_externa = {}


func _draw() -> void:
	var placa := Color(0.08, 0.06, 0.12, 0.8)
	draw_rect(Rect2(2, 2, 92, 25), placa)
	draw_rect(Rect2(640 - 58, 1, 56, 28), placa)
	# Cada corazón son dos puntos de vida.
	for i in Juego.vida_max / 2:
		var puntos := Juego.vida - i * 2
		var columna := 0 if puntos >= 2 else (1 if puntos == 1 else 2)
		draw_texture_rect_region(_corazon, Rect2(6 + i * 11, 4, 9, 7), Rect2(columna * 9, 0, 9, 7))
	draw_texture_rect_region(_moneda, Rect2(6, 15, 8, 8), Rect2(0, 0, 8, 8))
	draw_string(Juego.fuente, Vector2(17, 23), str(Juego.oro), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(247, 236, 210))
	draw_string(Juego.fuente, Vector2(50, 23), Idioma.t("PISO %d/%d") % [Juego.piso, Juego.PISOS_TOTALES], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(168, 154, 142))
	_dibujar_objetos()
	_dibujar_logro()
	_dibujar_transformaciones()
	if Juego.diario:
		draw_rect(Rect2(2, 28, 76, 11), Color(0.08, 0.06, 0.12, 0.8))
		draw_string(Juego.fuente, Vector2(6, 37), Idioma.t("RETO DIARIO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(108, 207, 148))
	if Juego.extremo:
		draw_rect(Rect2(2, 28, 58, 11), Color(0.08, 0.06, 0.12, 0.8))
		draw_string(Juego.fuente, Vector2(6, 37), Idioma.t("EXTREMO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(214, 61, 79))
	if Juego.deuda > 0:
		draw_rect(Rect2(2, 28, 70, 11), Color(0.08, 0.06, 0.12, 0.8))
		draw_string(Juego.fuente, Vector2(6, 37), Idioma.t("DEUDA %d") % Juego.deuda, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(214, 61, 79))
	_dibujar_mapa()
	if horda != null and is_instance_valid(horda.jefe):
		_dibujar_jefe()


func _dibujar_objetos() -> void:
	for i in Juego.objetos.size():
		var id: String = Juego.objetos[i]
		if not _texturas_objetos.has(id):
			_texturas_objetos[id] = ObjetosDB.textura(id)
		draw_texture(_texturas_objetos[id], _caja_objeto(i).position)


func _dibujar_transformaciones() -> void:
	for i in Juego.transformaciones.size():
		var datos: Dictionary = ObjetosDB.TRANSFORMACIONES[Juego.transformaciones[i]]
		var caja := _caja_transformacion(i)
		draw_rect(caja, Color8(20, 16, 30))
		draw_rect(caja.grow(-1.0), Color.html(datos.color))


func _dibujar_mapa() -> void:
	var origen := Vector2(640 - 6 - 49, 3)
	for c in salas:
		var s: Dictionary = salas[c]
		var visible_sala: bool = s.visitada
		if not visible_sala:
			for d in GeneradorMazmorra.DIRECCIONES:
				if salas.has(c + d) and salas[c + d].visitada:
					visible_sala = true
		if not visible_sala:
			continue
		var caja := Rect2(origen + Vector2(c.x * 7, c.y * 5), Vector2(6, 4))
		var color: Color = COLOR_MAPA[s.tipo]
		if not s.visitada:
			color = color.darkened(0.55)
		draw_rect(caja, color)
		if c == posicion_actual:
			draw_rect(caja.grow(1.0), Color8(247, 236, 210), false, 1.0)


func _dibujar_jefe() -> void:
	var j := horda.jefe
	var ancho := 180.0
	var x := 320.0 - ancho * 0.5
	draw_string(Juego.fuente, Vector2(x, 9), Idioma.t(j.nombre), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(247, 198, 74))
	draw_rect(Rect2(x, 12, ancho, 6), Color8(20, 16, 30))
	draw_rect(Rect2(x + 1, 13, (ancho - 2) * clampf(j.vida / j.vida_max, 0.0, 1.0), 4), Color8(214, 61, 79))
