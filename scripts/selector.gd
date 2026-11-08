class_name Selector
extends Control
## "Elige una carta": cofres, cartas del suelo. Pausa el juego mientras está abierto.

signal elegida(id: String)
signal saltada

const ESCALA := 2
const ANCHO := 64
const ALTO := 88
const SEPARACION := 44

var _ids: Array = []
var _texturas: Array = []
var _titulo := ""
var _sobre := -2

const SALTAR := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2.ZERO
	size = Vector2(640, 304)
	visible = false


func abrir(ids: Array, titulo: String) -> void:
	_ids = ids
	_titulo = titulo
	# Se cargan aquí y no al pintar: una textura cargada durante _draw sale en blanco.
	_texturas = ids.map(func(id): return CartasDB.textura(id))
	_sobre = -2
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func cerrar() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _caja(i: int) -> Rect2:
	var total: int = _ids.size() * ANCHO + (_ids.size() - 1) * SEPARACION
	return Rect2(320 - total * 0.5 + i * (ANCHO + SEPARACION), 44, ANCHO, ALTO)


func _caja_saltar() -> Rect2:
	return Rect2(280, 262, 80, 18)


func _elemento_en(p: Vector2) -> int:
	if _caja_saltar().has_point(p):
		return SALTAR
	for i in _ids.size():
		if _caja(i).has_point(p):
			return i
	return -2


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		_sobre = _elemento_en(evento.position)
		queue_redraw()
	elif evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var e := _elemento_en(evento.position)
		if e == SALTAR:
			saltada.emit()
		elif e >= 0:
			elegida.emit(_ids[e])


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 304), Color(0.06, 0.05, 0.1, 0.86))
	var ancho_t := Juego.fuente_grande.get_string_size(_titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(Juego.fuente_grande, Vector2(320 - ancho_t * 0.5, 30), _titulo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(247, 198, 74))
	for i in _ids.size():
		var caja := _caja(i)
		if i == _sobre:
			caja.position.y -= 4
		var id: String = _ids[i]
		var carta: Dictionary = CartasDB.CARTAS[id]
		draw_texture_rect(_texturas[i], caja, false)
		var y := 44 + ALTO + 14.0
		var cx := caja.position.x - 20
		var cw := caja.size.x + 40
		draw_string(Juego.fuente, Vector2(cx, y), CartasDB.nombre(id), HORIZONTAL_ALIGNMENT_CENTER, cw, 8, Color8(247, 236, 210))
		draw_string(Juego.fuente, Vector2(cx, y + 9), Idioma.t(CartasDB.NOMBRE_RAREZA[carta.rareza]),
				HORIZONTAL_ALIGNMENT_CENTER, cw, 8, Color8(168, 154, 142))
		draw_multiline_string(Juego.fuente, Vector2(cx, y + 22), CartasDB.descripcion(id), HORIZONTAL_ALIGNMENT_CENTER, cw, 8, 5,
				Color8(247, 236, 210))
	var saltar := _caja_saltar()
	draw_rect(saltar, Color8(122, 90, 160) if _sobre == SALTAR else Color8(74, 52, 102))
	draw_string(Juego.fuente, Vector2(saltar.position.x, saltar.position.y + 12), Idioma.t("SALTAR"),
			HORIZONTAL_ALIGNMENT_CENTER, saltar.size.x, 8, Color8(247, 236, 210))
