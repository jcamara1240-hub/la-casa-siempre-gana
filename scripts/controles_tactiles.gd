class_name ControlesTactiles
extends Control
## Joystick flotante y botones para jugar con el dedo. Solo se ven en pantallas táctiles.
## El resto de la interfaz ya funciona con toques: Godot los convierte en clics.

const RADIO_BASE := 34.0
const RADIO_MANDO := 13.0
const ZONA_MUERTA := 0.18
const CAJA_PAUSA := Rect2(440, 2, 30, 26)
const CAJA_COMPRAR := Rect2(520, 236, 100, 42)
# Botones redondos abajo a la derecha, para el pulgar derecho: rodar (grande) y órdago.
const BOTON_RODAR := Vector2(596, 250)
const RADIO_RODAR := 22.0
const BOTON_ORDAGO := Vector2(548, 272)
const RADIO_ORDAGO := 15.0
const CREMA := Color8(247, 236, 210)

var principal: Node

var _dedo := -1
var _centro := Vector2.ZERO
var _punta := Vector2.ZERO
var _ordago_tex: Texture2D = Jugo.textura("res://assets/objetos/ordago.png")
var _pulsado_t := {}  # botón -> tiempo que le queda al brillo de "pulsado"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 304)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _soltar() -> void:
	_dedo = -1
	Juego.direccion_tactil = Vector2.ZERO


func _process(delta: float) -> void:
	if get_tree().paused and _dedo != -1:
		_soltar()
	for boton in _pulsado_t:
		_pulsado_t[boton] = maxf(_pulsado_t[boton] - delta, 0.0)
	queue_redraw()


func _hay_compra() -> bool:
	return principal != null and not get_tree().paused and (principal.articulo_a_mano() != null or _maquina() != null)


## La tragaperras o la ruleta a mano: el mismo botón sirve para jugar.
func _maquina() -> Node:
	return principal.maquina_a_mano() if principal != null and principal.has_method("maquina_a_mano") else null


## Con el botón de comprar a la vista, los de rodar y órdago se apartan (están debajo).
func _hay_botones() -> bool:
	return principal != null and not get_tree().paused and not _hay_compra()


func _en_boton(p: Vector2, centro: Vector2, radio: float) -> bool:
	return p.distance_to(centro) <= radio + 6.0  # un poco de margen: el dedo es gordo


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
		if _maquina() != null:
			principal.jugar_maquina(_maquina())
		else:
			principal.comprar(principal.articulo_a_mano())
		get_viewport().set_input_as_handled()
	elif _hay_botones() and _en_boton(p, BOTON_RODAR, RADIO_RODAR):
		principal.jugador.pedir_voltereta()
		_pulsado_t["rodar"] = 0.15
		get_viewport().set_input_as_handled()
	elif _hay_botones() and _en_boton(p, BOTON_ORDAGO, RADIO_ORDAGO):
		principal.lanzar_ordago()
		_pulsado_t["ordago"] = 0.15
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
		var rotulo := Idioma.t("JUGAR") if _maquina() != null else Idioma.t("COMPRAR")
		draw_string(Juego.fuente_grande, CAJA_COMPRAR.position + Vector2(0, 27), rotulo,
				HORIZONTAL_ALIGNMENT_CENTER, CAJA_COMPRAR.size.x, 16, CREMA)
	elif _hay_botones():
		_dibujar_botones()


func _dibujar_botones() -> void:
	var lista: bool = principal.jugador.voltereta_lista()
	var brillo_rodar: float = _pulsado_t.get("rodar", 0.0) / 0.15
	draw_circle(BOTON_RODAR, RADIO_RODAR, Color(0.48, 0.35, 0.63, 0.55 + 0.3 * brillo_rodar))
	draw_arc(BOTON_RODAR, RADIO_RODAR, 0.0, TAU, 32, Color(CREMA, 0.8 if lista else 0.35), 1.5)
	draw_string(Juego.fuente, BOTON_RODAR + Vector2(-RADIO_RODAR, 3), Idioma.t("RODAR"),
			HORIZONTAL_ALIGNMENT_CENTER, RADIO_RODAR * 2.0, 8, Color(CREMA, 1.0 if lista else 0.5))
	var hay_ordagos := Juego.ordagos > 0
	var brillo_ordago: float = _pulsado_t.get("ordago", 0.0) / 0.15
	draw_circle(BOTON_ORDAGO, RADIO_ORDAGO, Color(0.84, 0.24, 0.31, (0.5 if hay_ordagos else 0.2) + 0.3 * brillo_ordago))
	draw_arc(BOTON_ORDAGO, RADIO_ORDAGO, 0.0, TAU, 28, Color(Color8(247, 198, 74), 0.8 if hay_ordagos else 0.3), 1.5)
	if _ordago_tex != null:
		draw_texture(_ordago_tex, BOTON_ORDAGO - _ordago_tex.get_size() * 0.5 + Vector2(0, -2), Color(1, 1, 1, 1.0 if hay_ordagos else 0.4))
	draw_string(Juego.fuente, BOTON_ORDAGO + Vector2(-RADIO_ORDAGO, RADIO_ORDAGO - 1), str(Juego.ordagos),
			HORIZONTAL_ALIGNMENT_CENTER, RADIO_ORDAGO * 2.0, 8, CREMA)
