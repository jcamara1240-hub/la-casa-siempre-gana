class_name PantallaLogros
extends Control
## Logros conseguidos y estadísticas de todas tus partidas.

signal atras

const CAJA_VOLVER := Rect2(240, 336, 160, 18)
const ALTO_MAX := 20.0
const ZONA := 296.0  # alto libre entre el título y el botón de volver
# Con más logros de los que caben a dos columnas de filas enteras, se pasa de página.
const CAJA_ANTERIOR := Rect2(196, 336, 40, 18)
const CAJA_SIGUIENTE := Rect2(404, 336, 40, 18)
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)

var _ids: Array = []
var _trofeo: Texture2D
var _por_columna := 14
var _alto_fila := ALTO_MAX
var _pagina := 0
var _paginas := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false
	_ids = LogrosDB.LOGROS.keys()
	# Dos columnas de filas enteras (nombre y descripción se leen sin pisarse); lo que no
	# cabe va a la página siguiente.
	_por_columna = maxi(1, floori(ZONA / ALTO_MAX))
	_alto_fila = ALTO_MAX
	_paginas = maxi(1, ceili(_ids.size() / float(_por_columna * 2)))
	_trofeo = load("res://assets/objetos/trofeo.png")


func abrir() -> void:
	_pagina = 0
	visible = true
	queue_redraw()


func _volver() -> void:
	Sonido.tocar("clic")
	visible = false
	atras.emit()


func _pasar_pagina(paso: int) -> void:
	var nueva := clampi(_pagina + paso, 0, _paginas - 1)
	if nueva == _pagina:
		return
	_pagina = nueva
	Sonido.tocar("mover")
	queue_redraw()


func _gui_input(evento: InputEvent) -> void:
	if not (evento is InputEventMouseButton) or not evento.pressed:
		return
	match evento.button_index:
		MOUSE_BUTTON_LEFT:
			if CAJA_VOLVER.has_point(evento.position):
				_volver()
			elif _paginas > 1 and CAJA_ANTERIOR.grow(4.0).has_point(evento.position):
				_pasar_pagina(-1)
			elif _paginas > 1 and CAJA_SIGUIENTE.grow(4.0).has_point(evento.position):
				_pasar_pagina(1)
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
			_pasar_pagina(-1)
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
			_pasar_pagina(1)


## Teclado y mando (Mando.tecla traduce los botones): flechas, A/D, Re Pág y Av Pág, o la
## cruceta, el stick, LB y RB pasan de página; Esc, Intro, A o B vuelven.
func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	var tecla := Mando.tecla(evento)
	if tecla in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		_volver()
	elif tecla in [KEY_LEFT, KEY_UP, KEY_A, KEY_W, KEY_PAGEUP]:
		_pasar_pagina(-1)
	elif tecla in [KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S, KEY_PAGEDOWN]:
		_pasar_pagina(1)
	else:
		return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color8(20, 16, 30))
	draw_string(Juego.fuente_grande, Vector2(16, 22), Idioma.t("LOGROS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_ORO)
	var c: Dictionary = Progreso.contadores
	var resumen := Idioma.t("%d/%d   PARTIDAS %d   ENEMIGOS %d   MONEDAS %d   MEJOR COMBO %d") % [
		Progreso.logros.size(), _ids.size(), Progreso.partidas, int(c.get("enemigos", 0)), int(c.get("monedas", 0)), int(c.get("combo", 0))]
	draw_string(Juego.fuente, Vector2(0, 21), resumen, HORIZONTAL_ALIGNMENT_RIGHT, 624, 8, COLOR_GRIS)
	var por_pagina := _por_columna * 2
	for i in range(_pagina * por_pagina, mini(_ids.size(), (_pagina + 1) * por_pagina)):
		var id: String = _ids[i]
		var k := i - _pagina * por_pagina
		var columna := k / _por_columna
		var p := Vector2(16.0 + columna * 308.0, 34.0 + (k % _por_columna) * _alto_fila)
		var ok: bool = Progreso.logros.has(id)
		draw_rect(Rect2(p, Vector2(300, minf(18.0, _alto_fila - 1.0))), Color8(42, 31, 61))
		draw_texture(_trofeo, p + Vector2(3, 3), Color.WHITE if ok else Color(0.2, 0.17, 0.26))
		draw_string(Juego.fuente, p + Vector2(20, 8), LogrosDB.nombre(id).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO if ok else COLOR_GRIS)
		draw_string(Juego.fuente, p + Vector2(20, 16), LogrosDB.descripcion(id), HORIZONTAL_ALIGNMENT_LEFT, 276, 8, COLOR_CREMA if ok else COLOR_GRIS)
	draw_rect(CAJA_VOLVER, Color8(42, 31, 61))
	draw_string(Juego.fuente, Vector2(CAJA_VOLVER.position.x, 350), Idioma.t("VOLVER"), HORIZONTAL_ALIGNMENT_CENTER, CAJA_VOLVER.size.x, 8, COLOR_CREMA)
	if _paginas > 1:
		# Con el mando, las flechas enseñan sus botones (LB y RB).
		var flechas := [Mando.nombre("pestana_izq"), Mando.nombre("pestana_der")] if Mando.activo else ["<", ">"]
		var cajas := [CAJA_ANTERIOR, CAJA_SIGUIENTE]
		for j in 2:
			var se_puede := _pagina > 0 if j == 0 else _pagina < _paginas - 1
			draw_rect(cajas[j], Color8(42, 31, 61))
			draw_string(Juego.fuente, cajas[j].position + Vector2(0, 14), flechas[j], HORIZONTAL_ALIGNMENT_CENTER, cajas[j].size.x, 8,
					COLOR_CREMA if se_puede else Color8(74, 52, 102))
		draw_string(Juego.fuente, Vector2(CAJA_SIGUIENTE.end.x + 8, 350), "%d/%d" % [_pagina + 1, _paginas], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS)
