class_name PantallaReto
extends Control
## El reto diario: la clasificación de hoy, tu nombre y el botón de jugar.

signal jugar_reto
signal atras

const LETRAS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
const LARGO_NOMBRE := 6
const CAJA_JUGAR := Rect2(240, 310, 160, 20)
const CAJA_VOLVER := Rect2(240, 334, 160, 18)
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)

var marcador: Marcador

var _filas: Array = []
var _estado := ""
var _nombre: Array = []
var _cursor := 0
var _pendiente_envio := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false


func conectar(m: Marcador) -> void:
	marcador = m
	m.top_recibido.connect(_al_recibir)
	m.puntuacion_enviada.connect(_al_enviar)


func abrir(puntos_a_enviar := -1) -> void:
	_pendiente_envio = puntos_a_enviar
	_filas = []
	_cursor = 0
	var guardado := Progreso.nombre.rpad(LARGO_NOMBRE)
	_nombre = []
	for i in LARGO_NOMBRE:
		_nombre.append(maxi(LETRAS.find(guardado[i].to_upper()), 0))
	visible = true
	_refrescar()


func _texto_nombre() -> String:
	var t := ""
	for i in _nombre:
		t += LETRAS[i]
	return t.strip_edges()


func _refrescar() -> void:
	if not marcador.configurado():
		_estado = "sin_config"
		return
	if _pendiente_envio >= 0 and _texto_nombre() != "":
		_enviar()
		return
	_estado = "cargando"
	marcador.pedir_top(Juego.fecha_hoy())


func _enviar() -> void:
	Progreso.nombre = _texto_nombre()
	Progreso.guardar()
	_estado = "enviando"
	marcador.enviar(Juego.fecha_hoy(), Progreso.nombre, _pendiente_envio)
	_pendiente_envio = -1


func _al_enviar(_correcto: bool) -> void:
	if visible:
		_estado = "cargando"
		marcador.pedir_top(Juego.fecha_hoy())


func _al_recibir(filas: Array, correcto: bool) -> void:
	if not visible:
		return
	_filas = filas
	_estado = "lista" if correcto else "error"
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _cambiar_letra(sentido: int) -> void:
	_nombre[_cursor] = wrapi(_nombre[_cursor] + sentido, 0, LETRAS.length())
	Sonido.tocar("mover")


func _caja_letra(i: int) -> Rect2:
	return Rect2(236.0 + i * 28.0, 262.0, 24.0, 30.0)


func _gui_input(evento: InputEvent) -> void:
	if not (evento is InputEventMouseButton) or not evento.pressed or evento.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = evento.position
	for i in LARGO_NOMBRE:
		var c := _caja_letra(i)
		if c.has_point(p):
			_cursor = i
			_cambiar_letra(1 if p.y >= c.get_center().y else -1)
			return
	if CAJA_JUGAR.has_point(p):
		_accion_principal()
	elif CAJA_VOLVER.has_point(p):
		_volver()


func _accion_principal() -> void:
	Sonido.tocar("clic")
	Progreso.nombre = _texto_nombre()
	Progreso.guardar()
	if _pendiente_envio >= 0 and marcador.configurado() and Progreso.nombre != "":
		_enviar()
		return
	visible = false
	jugar_reto.emit()


func _volver() -> void:
	Sonido.tocar("clic")
	visible = false
	atras.emit()


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match evento.keycode:
		KEY_UP, KEY_W: _cambiar_letra(-1)
		KEY_DOWN, KEY_S: _cambiar_letra(1)
		KEY_LEFT, KEY_A: _cursor = wrapi(_cursor - 1, 0, LARGO_NOMBRE)
		KEY_RIGHT, KEY_D: _cursor = wrapi(_cursor + 1, 0, LARGO_NOMBRE)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _accion_principal()
		KEY_ESCAPE: _volver()
		_: return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color8(20, 16, 30))
	draw_string(Juego.fuente_grande, Vector2(0, 28), Idioma.t("RETO DIARIO"), HORIZONTAL_ALIGNMENT_CENTER, 640, 16, COLOR_ORO)
	var info := Idioma.t("MISMA MAZMORRA PARA TODOS HOY (%s). JUEGAS CON EL TAHÚR.") % Juego.fecha_hoy()
	draw_string(Juego.fuente, Vector2(0, 44), info, HORIZONTAL_ALIGNMENT_CENTER, 640, 8, COLOR_GRIS)
	_dibujar_tabla()
	draw_string(Juego.fuente, Vector2(0, 256), Idioma.t("TU NOMBRE (TOCA ARRIBA O ABAJO DE CADA LETRA)"), HORIZONTAL_ALIGNMENT_CENTER, 640, 8, COLOR_GRIS)
	for i in LARGO_NOMBRE:
		var c := _caja_letra(i)
		draw_rect(c, Color8(42, 31, 61))
		draw_rect(c, COLOR_ORO if i == _cursor else Color8(74, 52, 102), false, 1.0)
		draw_string(Juego.fuente_grande, c.position + Vector2(0, 23), LETRAS[_nombre[i]], HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 16, COLOR_CREMA)
	var texto := "ENVIAR PUNTOS" if _pendiente_envio >= 0 and marcador.configurado() else "JUGAR RETO"
	draw_rect(CAJA_JUGAR, Color8(122, 90, 160))
	draw_string(Juego.fuente, Vector2(CAJA_JUGAR.position.x, 324), Idioma.t(texto), HORIZONTAL_ALIGNMENT_CENTER, CAJA_JUGAR.size.x, 8, COLOR_CREMA)
	draw_rect(CAJA_VOLVER, Color8(42, 31, 61))
	draw_string(Juego.fuente, Vector2(CAJA_VOLVER.position.x, 347), Idioma.t("VOLVER"), HORIZONTAL_ALIGNMENT_CENTER, CAJA_VOLVER.size.x, 8, COLOR_CREMA)


func _dibujar_tabla() -> void:
	var mi_marca := Idioma.t("TU MEJOR MARCA DE HOY: %d") % Progreso.reto_mejor_hoy(Juego.fecha_hoy())
	draw_string(Juego.fuente, Vector2(0, 62), mi_marca, HORIZONTAL_ALIGNMENT_CENTER, 640, 8, COLOR_ORO)
	var mensaje := ""
	match _estado:
		"sin_config": mensaje = "CLASIFICACIÓN MUNDIAL AÚN NO ACTIVADA"
		"cargando": mensaje = "CARGANDO..."
		"enviando": mensaje = "ENVIANDO..."
		"error": mensaje = "SIN CONEXIÓN CON LA CLASIFICACIÓN"
		"lista":
			if _filas.is_empty():
				mensaje = "NADIE HA JUGADO HOY. SÉ EL PRIMERO."
	if mensaje != "":
		draw_string(Juego.fuente, Vector2(0, 150), Idioma.t(mensaje), HORIZONTAL_ALIGNMENT_CENTER, 640, 8, COLOR_GRIS)
		return
	for i in _filas.size():
		var y := 80.0 + i * 16.0
		var fila: Dictionary = _filas[i]
		var color := COLOR_ORO if i == 0 else COLOR_CREMA
		draw_string(Juego.fuente, Vector2(200, y), "%d." % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS)
		draw_string(Juego.fuente, Vector2(224, y), String(fila.nombre), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
		draw_string(Juego.fuente, Vector2(320, y), str(fila.puntos), HORIZONTAL_ALIGNMENT_RIGHT, 120, 8, color)
