class_name ControlesTactiles
extends Control
## Joystick flotante y botones para jugar con el dedo. Solo se ven en pantallas táctiles.
## El resto de la interfaz ya funciona con toques: Godot los convierte en clics.

const RADIO_BASE := 34.0
const RADIO_MANDO := 13.0
const ZONA_MUERTA := 0.18
const CAJA_PAUSA := Rect2(440, 2, 30, 26)
const CAJA_COMPRAR := Rect2(520, 236, 100, 42)
const CREMA := Color8(247, 236, 210)

var principal: Node

var _dedo := -1
var _centro := Vector2.ZERO
var _punta := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 304)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _soltar() -> void:
	_dedo = -1
	Juego.direccion_tactil = Vector2.ZERO


func _process(_delta: float) -> void:
	if get_tree().paused and _dedo != -1:
		_soltar()
	queue_redraw()


func _hay_compra() -> bool:
	return principal != null and not get_tree().paused and principal.articulo_a_mano() != null


func _input(evento: InputEvent) -> void:
	if evento is InputEventScreenTouch:
		Juego.tactil = true
		if evento.pressed:
			_toque(evento)
		elif evento.index == _dedo:
			_soltar()
	elif evento is InputEventScreenDrag and evento.index == _dedo:
		_punta = evento.position
		_actualizar_direccion()


func _toque(evento: InputEventScreenTouch) -> void:
	if get_tree().paused:
		return
	var p: Vector2 = evento.position
	if CAJA_PAUSA.has_point(p):
		principal.quizas_pausar()
		get_viewport().set_input_as_handled()
	elif _hay_compra() and CAJA_COMPRAR.has_point(p):
		principal.comprar(principal.articulo_a_mano())
		get_viewport().set_input_as_handled()
	elif _dedo == -1 and p.y < 304.0:
		_dedo = evento.index
		_centro = p
		_punta = p


func _actualizar_direccion() -> void:
	var v := (_punta - _centro) / RADIO_BASE
	var largo := v.length()
	if largo < ZONA_MUERTA:
		Juego.direccion_tactil = Vector2.ZERO
		return
	# Basta con inclinarlo un poco para ir a toda velocidad: en un móvil se agradece.
	Juego.direccion_tactil = v / largo * minf(1.0, largo * 1.5)
	if largo > 1.0:
		_centro = _punta - v / largo * RADIO_BASE  # la base sigue al dedo


func _draw() -> void:
	if not Juego.tactil or get_tree().paused:
		return
	draw_rect(CAJA_PAUSA, Color(0.08, 0.06, 0.12, 0.8))
	draw_rect(Rect2(CAJA_PAUSA.position + Vector2(10, 7), Vector2(3, 12)), CREMA)
	draw_rect(Rect2(CAJA_PAUSA.position + Vector2(17, 7), Vector2(3, 12)), CREMA)
	if _dedo != -1:
		draw_arc(_centro, RADIO_BASE, 0.0, TAU, 32, Color(CREMA, 0.45), 2.0)
		var mando := _centro + (_punta - _centro).limit_length(RADIO_BASE)
		draw_circle(mando, RADIO_MANDO, Color(CREMA, 0.5))
	if _hay_compra():
		draw_rect(CAJA_COMPRAR, Color8(122, 90, 160))
		draw_rect(CAJA_COMPRAR, Color8(247, 198, 74), false, 1.0)
		draw_string(Juego.fuente_grande, CAJA_COMPRAR.position + Vector2(0, 27), Idioma.t("COMPRAR"),
				HORIZONTAL_ALIGNMENT_CENTER, CAJA_COMPRAR.size.x, 16, CREMA)
