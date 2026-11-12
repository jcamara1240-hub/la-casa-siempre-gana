class_name PantallaLogros
extends Control
## Logros conseguidos y estadísticas de todas tus partidas.

signal atras

const CAJA_VOLVER := Rect2(240, 336, 160, 18)
const ALTO_MAX := 20.0
const ZONA := 296.0  # alto libre entre el título y el botón de volver
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)

var _ids: Array = []
var _trofeo: Texture2D
var _por_columna := 14
var _alto_fila := ALTO_MAX


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false
	_ids = LogrosDB.LOGROS.keys()
	# Dos columnas; si hay más logros, las filas se aprietan para que todo quepa sobre el botón.
	_por_columna = maxi(1, ceili(_ids.size() / 2.0))
	_alto_fila = minf(ALTO_MAX, ZONA / _por_columna)
	_trofeo = load("res://assets/objetos/trofeo.png")


func abrir() -> void:
	visible = true
	queue_redraw()


func _volver() -> void:
	Sonido.tocar("clic")
	visible = false
	atras.emit()


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT \
			and CAJA_VOLVER.has_point(evento.position):
		_volver()


func _unhandled_input(evento: InputEvent) -> void:
	if visible and Mando.tecla(evento) in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		_volver()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color8(20, 16, 30))
	draw_string(Juego.fuente_grande, Vector2(16, 22), Idioma.t("LOGROS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_ORO)
	var c: Dictionary = Progreso.contadores
	var resumen := Idioma.t("%d/%d   PARTIDAS %d   ENEMIGOS %d   MONEDAS %d   MEJOR COMBO %d") % [
		Progreso.logros.size(), _ids.size(), Progreso.partidas, int(c.get("enemigos", 0)), int(c.get("monedas", 0)), int(c.get("combo", 0))]
	draw_string(Juego.fuente, Vector2(0, 21), resumen, HORIZONTAL_ALIGNMENT_RIGHT, 624, 8, COLOR_GRIS)
	for i in _ids.size():
		var id: String = _ids[i]
		var columna := i / _por_columna
		var p := Vector2(16.0 + columna * 308.0, 34.0 + (i % _por_columna) * _alto_fila)
		var ok: bool = Progreso.logros.has(id)
		draw_rect(Rect2(p, Vector2(300, minf(18.0, _alto_fila - 1.0))), Color8(42, 31, 61))
		draw_texture(_trofeo, p + Vector2(3, 3), Color.WHITE if ok else Color(0.2, 0.17, 0.26))
		draw_string(Juego.fuente, p + Vector2(20, 8), LogrosDB.nombre(id).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO if ok else COLOR_GRIS)
		draw_string(Juego.fuente, p + Vector2(20, 16), LogrosDB.descripcion(id), HORIZONTAL_ALIGNMENT_LEFT, 276, 8, COLOR_CREMA if ok else COLOR_GRIS)
	draw_rect(CAJA_VOLVER, Color8(42, 31, 61))
	draw_string(Juego.fuente, Vector2(CAJA_VOLVER.position.x, 350), Idioma.t("VOLVER"), HORIZONTAL_ALIGNMENT_CENTER, CAJA_VOLVER.size.x, 8, COLOR_CREMA)
