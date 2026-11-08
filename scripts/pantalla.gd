class_name Pantalla
extends Control
## Portada, derrota y victoria: un título, unas líneas y "pulsa Enter".

signal aceptada

var _titulo := ""
var _lineas: Array = []
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func mostrar(titulo: String, lineas: Array) -> void:
	_titulo = titulo
	_lineas = lineas
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _unhandled_input(evento: InputEvent) -> void:
	if visible and evento is InputEventKey and evento.pressed and not evento.echo \
			and evento.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		visible = false
		aceptada.emit()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color8(20, 16, 30))
	var ancho := Juego.fuente_grande.get_string_size(_titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(Juego.fuente_grande, Vector2(320 - ancho * 0.5, 110), _titulo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color8(247, 198, 74))
	for i in _lineas.size():
		draw_string(Juego.fuente, Vector2(0, 140 + i * 12), _lineas[i], HORIZONTAL_ALIGNMENT_CENTER, 640, 8,
				Color8(247, 236, 210))
	if fmod(_t, 1.0) < 0.65:
		draw_string(Juego.fuente, Vector2(0, 300), Idioma.t("PULSA ENTER"), HORIZONTAL_ALIGNMENT_CENTER, 640, 8, Color8(108, 207, 148))
