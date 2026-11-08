class_name Seleccion
extends Control
## Elegir personaje y mesa antes de empezar.

signal elegido(personaje: String, mesa: int, extremo: bool, imposible: bool)
signal atras

const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)
const COLOR_FONDO := Color8(20, 16, 30)
const COLOR_ROJO_CLARO := Color8(214, 61, 79)
const ANCHO := 100.0
const CAJA_EXTREMO := Rect2(220, 282, 200, 16)
const CAJA_EMPEZAR := Rect2(240, 302, 160, 20)
const CAJA_VOLVER := Rect2(240, 327, 160, 18)
const FLECHA_IZQ := Rect2(190, 240, 24, 18)
const FLECHA_DER := Rect2(426, 240, 24, 18)

var _ids: Array = []
var _texturas := {}
var _indice := 0
var _mesa := 0
var _modo := 0  # 0: normal, 1: extremo, 2: imposible
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false
	_ids = PersonajesDB.PERSONAJES.keys()
	for id in _ids:
		_texturas[id] = PersonajesDB.textura(id)


func abrir() -> void:
	_mesa = mini(_mesa, Progreso.mesa_max)
	visible = true


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _caja(i: int) -> Rect2:
	return Rect2(7.0 + i * (ANCHO + 5.0), 40.0, ANCHO, 186.0)


func _empezar() -> void:
	var id: String = _ids[_indice]
	if not Progreso.personaje_libre(id):
		Sonido.tocar("perder")
		return
	Sonido.tocar("clic")
	visible = false
	elegido.emit(id, _mesa, _modo == 1, _modo == 2)


func _volver() -> void:
	Sonido.tocar("clic")
	visible = false
	atras.emit()


func _cambiar_extremo() -> void:
	_modo = (_modo + 1) % 3
	Sonido.tocar("mult" if _modo > 0 else "clic")


func _cambiar_mesa(sentido: int) -> void:
	_mesa = wrapi(_mesa + sentido, 0, Progreso.mesa_max + 1)
	Sonido.tocar("mover")


func _gui_input(evento: InputEvent) -> void:
	if not (evento is InputEventMouseButton) or not evento.pressed or evento.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = evento.position
	for i in _ids.size():
		if _caja(i).has_point(p):
			_indice = i
			Sonido.tocar("mover")
	if FLECHA_IZQ.has_point(p):
		_cambiar_mesa(-1)
	elif FLECHA_DER.has_point(p):
		_cambiar_mesa(1)
	elif CAJA_EXTREMO.has_point(p):
		_cambiar_extremo()
	elif CAJA_EMPEZAR.has_point(p):
		_empezar()
	elif CAJA_VOLVER.has_point(p):
		_volver()


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match evento.keycode:
		KEY_LEFT, KEY_A:
			_indice = wrapi(_indice - 1, 0, _ids.size())
			Sonido.tocar("mover")
		KEY_RIGHT, KEY_D:
			_indice = wrapi(_indice + 1, 0, _ids.size())
			Sonido.tocar("mover")
		KEY_UP, KEY_W:
			_cambiar_mesa(1)
		KEY_DOWN, KEY_S:
			_cambiar_mesa(-1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_empezar()
		KEY_ESCAPE:
			_volver()
		KEY_X:
			_cambiar_extremo()
		_:
			return
	get_viewport().set_input_as_handled()


func _centrado(fuente: Font, tam: int, texto: String, x: float, ancho: float, y: float, color: Color) -> void:
	draw_string(fuente, Vector2(x, y), texto, HORIZONTAL_ALIGNMENT_CENTER, ancho, tam, color)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), COLOR_FONDO)
	_centrado(Juego.fuente_grande, 16, Idioma.t("ELIGE A TU JUGADOR"), 0, 640, 30, COLOR_ORO)
	for i in _ids.size():
		_dibujar_personaje(i)
	var mesa: Dictionary = PersonajesDB.MESAS[_mesa]
	_centrado(Juego.fuente_grande, 16, Idioma.t(mesa.nombre).to_upper(), 214, 212, 254, COLOR_ORO)
	_centrado(Juego.fuente_grande, 16, "<", FLECHA_IZQ.position.x, FLECHA_IZQ.size.x, 254, COLOR_CREMA)
	_centrado(Juego.fuente_grande, 16, ">", FLECHA_DER.position.x, FLECHA_DER.size.x, 254, COLOR_CREMA)
	var explicacion: String = Idioma.t("COMO EL EXTREMO, PERO CON DOS RANURAS Y SIN SALAS DE TESORO.") if _modo == 2 else Idioma.t("UN GOLPE Y A CASA. SIN TIENDA. JEFES CON EL TRIPLE DE VIDA.") if _modo == 1 else Idioma.t(mesa.desc)
	_centrado(Juego.fuente, 8, explicacion, 0, 640, 275, COLOR_ROJO_CLARO if _modo > 0 else COLOR_GRIS)
	draw_rect(CAJA_EXTREMO, Color8(143, 35, 64) if _modo > 0 else Color8(42, 31, 61))
	draw_rect(CAJA_EXTREMO, COLOR_ROJO_CLARO, false, 1.0)
	var estado := Idioma.t(["NORMAL", "EXTREMO", "IMPOSIBLE"][_modo])
	_centrado(Juego.fuente, 8, Idioma.t("MODO: %s") % estado, CAJA_EXTREMO.position.x, CAJA_EXTREMO.size.x, 293, COLOR_CREMA)
	var libre := Progreso.personaje_libre(_ids[_indice])
	draw_rect(CAJA_EMPEZAR, Color8(122, 90, 160) if libre else Color8(42, 31, 61))
	_centrado(Juego.fuente, 8, Idioma.t("EMPEZAR"), CAJA_EMPEZAR.position.x, CAJA_EMPEZAR.size.x, 315, COLOR_CREMA if libre else COLOR_GRIS)
	draw_rect(CAJA_VOLVER, Color8(42, 31, 61))
	_centrado(Juego.fuente, 8, Idioma.t("VOLVER"), CAJA_VOLVER.position.x, CAJA_VOLVER.size.x, 339, COLOR_CREMA)


func _dibujar_personaje(i: int) -> void:
	var caja := _caja(i)
	var id: String = _ids[i]
	var datos: Dictionary = PersonajesDB.PERSONAJES[id]
	var libre := Progreso.personaje_libre(id)
	draw_rect(caja, Color8(42, 31, 61))
	draw_rect(caja, COLOR_ORO if i == _indice else Color8(74, 52, 102), false, 1.0)
	var columna := int(_t * 2.5) % 2 if i != _indice else 2 + int(_t * 8.0) % 4
	var tinte := Color.WHITE if libre else Color(0.08, 0.06, 0.12)
	draw_texture_rect_region(_texturas[id], Rect2(caja.position.x + 26, caja.position.y + 10, 48, 48),
			Rect2(columna * 16, 0, 16, 16), tinte)
	var x := caja.position.x + 4
	var ancho := caja.size.x - 8
	if libre:
		_centrado(Juego.fuente, 8, PersonajesDB.nombre(id).to_upper(), x, ancho, caja.position.y + 72, COLOR_ORO)
		draw_multiline_string(Juego.fuente, Vector2(x, caja.position.y + 86), PersonajesDB.descripcion(id),
				HORIZONTAL_ALIGNMENT_CENTER, ancho, 8, 5, COLOR_CREMA)
		_centrado(Juego.fuente, 8, Idioma.t("VIDA %d  ORO %d") % [int(datos.vida), int(datos.oro)], x, ancho, caja.position.y + 144, COLOR_GRIS)
		var nombres: Array = datos.cartas.map(func(c): return CartasDB.nombre(c))
		draw_multiline_string(Juego.fuente, Vector2(x, caja.position.y + 158), ", ".join(nombres),
				HORIZONTAL_ALIGNMENT_CENTER, ancho, 8, 3, COLOR_GRIS)
	else:
		_centrado(Juego.fuente, 8, Idioma.t("BLOQUEADO"), x, ancho, caja.position.y + 72, COLOR_GRIS)
		draw_multiline_string(Juego.fuente, Vector2(x, caja.position.y + 88), Idioma.t(datos.requisito),
				HORIZONTAL_ALIGNMENT_CENTER, ancho, 8, 5, COLOR_CREMA)
