class_name Coleccion
extends Control
## Todo lo que existe en el juego y lo que llevas desbloqueado.

signal atras

const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)
const CAJA_VOLVER := Rect2(240, 336, 160, 18)
const POR_FILA := 15
const INICIO := Vector2(44, 36)

var _cartas: Array = []
var _objetos: Array = []
var _tex_cartas := {}
var _tex_objetos := {}
var _cerrada: Texture2D
var _titulo_info := ""
var _texto_info := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false
	_cartas = CartasDB.CARTAS.keys()
	_objetos = ObjetosDB.OBJETOS.keys()
	_cerrada = load("res://assets/cartas/_cerrada.png")
	for id in _cartas:
		_tex_cartas[id] = CartasDB.textura(id)
	for id in _objetos:
		_tex_objetos[id] = ObjetosDB.textura(id)


func abrir() -> void:
	_titulo_info = ""
	_texto_info = ""
	visible = true
	queue_redraw()


func _caja_carta(i: int) -> Rect2:
	return Rect2(INICIO + Vector2((i % POR_FILA) * 37.0, (i / POR_FILA) * 47.0), Vector2(32, 44))


func _caja_objeto(i: int) -> Rect2:
	return Rect2(Vector2(44.0 + i * 35.0, 182.0), Vector2(24, 24))


func _caja_transformacion(i: int) -> Rect2:
	return Rect2(Vector2(44.0 + i * 112.0, 216.0), Vector2(106, 18))


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		_mirar(evento.position)
		queue_redraw()
	elif evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		if CAJA_VOLVER.has_point(evento.position):
			_volver()


func _unhandled_input(evento: InputEvent) -> void:
	if visible and evento is InputEventKey and evento.pressed and not evento.echo \
			and evento.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		_volver()
		get_viewport().set_input_as_handled()


func _volver() -> void:
	Sonido.tocar("clic")
	visible = false
	atras.emit()


func _mirar(p: Vector2) -> void:
	_titulo_info = ""
	_texto_info = ""
	for i in _cartas.size():
		if _caja_carta(i).has_point(p):
			_info(Progreso.carta_libre(_cartas[i]), CartasDB.nombre(_cartas[i]), CartasDB.descripcion(_cartas[i]))
	for i in _objetos.size():
		if _caja_objeto(i).has_point(p):
			_info(Progreso.objeto_libre(_objetos[i]), ObjetosDB.nombre(_objetos[i]), ObjetosDB.descripcion(_objetos[i]))
	var ids: Array = ObjetosDB.TRANSFORMACIONES.keys()
	for i in ids.size():
		if _caja_transformacion(i).has_point(p):
			var datos: Dictionary = ObjetosDB.TRANSFORMACIONES[ids[i]]
			_info(Progreso.transformaciones.has(ids[i]), Idioma.t(datos.nombre), ObjetosDB.descripcion_transformacion(ids[i]))


func _info(libre: bool, titulo: String, texto: String) -> void:
	_titulo_info = titulo if libre else Idioma.t("BLOQUEADO")
	_texto_info = texto if libre else Idioma.t("VENCE A LOS JEFES PARA DESCUBRIRLO.")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color8(20, 16, 30))
	draw_string(Juego.fuente_grande, Vector2(44, 28), Idioma.t("COLECCIÓN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_ORO)
	var resumen := Idioma.t("CARTAS %d/%d   OBJETOS %d/%d   JEFES %d/%d   VICTORIAS %d") % [
		Progreso.cartas_libres(), _cartas.size(), Progreso.objetos_libres(), _objetos.size(),
		Progreso.jefes_vencidos.size(), Jefe.NOMBRES.size(), Progreso.victorias]
	draw_string(Juego.fuente, Vector2(0, 28), resumen, HORIZONTAL_ALIGNMENT_RIGHT, 596, 8, COLOR_GRIS)
	for i in _cartas.size():
		draw_texture(_tex_cartas[_cartas[i]] if Progreso.carta_libre(_cartas[i]) else _cerrada, _caja_carta(i).position)
	for i in _objetos.size():
		var caja := _caja_objeto(i)
		draw_rect(caja, Color8(42, 31, 61))
		var tinte := Color.WHITE if Progreso.objeto_libre(_objetos[i]) else Color(0.08, 0.06, 0.12)
		draw_texture(_tex_objetos[_objetos[i]], caja.position + Vector2(6, 6), tinte)
	var ids: Array = ObjetosDB.TRANSFORMACIONES.keys()
	for i in ids.size():
		var caja := _caja_transformacion(i)
		var conocida: bool = Progreso.transformaciones.has(ids[i])
		draw_rect(caja, Color8(42, 31, 61))
		var nombre: String = Idioma.t(ObjetosDB.TRANSFORMACIONES[ids[i]].nombre) if conocida else "???"
		draw_string(Juego.fuente, caja.position + Vector2(0, 12), nombre, HORIZONTAL_ALIGNMENT_CENTER, caja.size.x, 8,
				COLOR_ORO if conocida else COLOR_GRIS)
	draw_string(Juego.fuente, Vector2(44, 256), _titulo_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO)
	draw_multiline_string(Juego.fuente, Vector2(44, 270), _texto_info, HORIZONTAL_ALIGNMENT_LEFT, 552, 8, 3, COLOR_CREMA)
	draw_rect(CAJA_VOLVER, Color8(42, 31, 61))
	draw_string(Juego.fuente, Vector2(CAJA_VOLVER.position.x, 350), Idioma.t("VOLVER"), HORIZONTAL_ALIGNMENT_CENTER,
			CAJA_VOLVER.size.x, 8, COLOR_CREMA)
