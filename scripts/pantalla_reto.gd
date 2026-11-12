class_name PantallaReto
extends Control
## El reto diario: la misma mazmorra para todos cada día y tu mejor marca.

signal jugar_reto
signal atras

const CAJA_JUGAR := Rect2(240, 200, 160, 22)
const CAJA_VOLVER := Rect2(240, 230, 160, 18)
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false


func abrir() -> void:
	visible = true
	queue_redraw()


func _jugar() -> void:
	Sonido.tocar("clic")
	visible = false
	jugar_reto.emit()


func _volver() -> void:
	Sonido.tocar("clic")
	visible = false
	atras.emit()


func _gui_input(evento: InputEvent) -> void:
	if not (evento is InputEventMouseButton) or not evento.pressed or evento.button_index != MOUSE_BUTTON_LEFT:
		return
	if CAJA_JUGAR.has_point(evento.position):
		_jugar()
	elif CAJA_VOLVER.has_point(evento.position):
		_volver()


func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	match Mando.tecla(evento):
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _jugar()
		KEY_ESCAPE: _volver()
		_: return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color8(20, 16, 30))
	draw_string(Juego.fuente_grande, Vector2(0, 92), Idioma.t("RETO DIARIO"), HORIZONTAL_ALIGNMENT_CENTER, 640, 16, COLOR_ORO)
	var info := Idioma.t("MISMA MAZMORRA PARA TODOS HOY (%s). JUEGAS CON EL TAHÚR.") % Juego.fecha_hoy()
	draw_string(Juego.fuente, Vector2(0, 120), info, HORIZONTAL_ALIGNMENT_CENTER, 640, 8, COLOR_GRIS)
	var marca := Idioma.t("TU MEJOR MARCA DE HOY: %d") % Progreso.reto_mejor_hoy(Juego.fecha_hoy())
	draw_string(Juego.fuente_grande, Vector2(0, 165), marca, HORIZONTAL_ALIGNMENT_CENTER, 640, 16, COLOR_CREMA)
	draw_rect(CAJA_JUGAR, Color8(122, 90, 160))
	draw_string(Juego.fuente, Vector2(CAJA_JUGAR.position.x, 215), Idioma.t("JUGAR RETO"), HORIZONTAL_ALIGNMENT_CENTER, CAJA_JUGAR.size.x, 8, COLOR_CREMA)
	draw_rect(CAJA_VOLVER, Color8(42, 31, 61))
	draw_string(Juego.fuente, Vector2(CAJA_VOLVER.position.x, 243), Idioma.t("VOLVER"), HORIZONTAL_ALIGNMENT_CENTER, CAJA_VOLVER.size.x, 8, COLOR_CREMA)
