class_name Coleccion
extends Control
## Todo lo que existe en el juego y lo que llevas desbloqueado.

signal atras

const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)
const CAJA_VOLVER := Rect2(240, 336, 160, 18)
const POR_FILA := 15
const FILAS_CARTAS := 5  # cinco filas de naipes caben entre las pestañas y la ficha de abajo
const INICIO := Vector2(44, 36)
const PESTANAS := [Rect2(150, 16, 74, 16), Rect2(228, 16, 74, 16)]
const Y_INFO := 284.0  # la ficha de lo que señalas, debajo de la rejilla

var _pagina := 0  # 0: cartas, 1: objetos y transformaciones

var _cartas: Array = []
var _objetos: Array = []
var _tex_cartas := {}
var _tex_objetos := {}
var _cerrada: Texture2D
var _titulo_info := ""
var _texto_info := ""
var _cartas_por_fila := POR_FILA
var _paso_cartas := 37.0
var _y_transformaciones := 132.0
var _cursor := -1  # con el mando: la casilla que miras (-1: ninguna)


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
	# Si hay más naipes de los que caben en cinco filas de 15, se ensanchan las filas y se juntan.
	_cartas_por_fila = maxi(POR_FILA, ceili(_cartas.size() / float(FILAS_CARTAS)))
	_paso_cartas = minf(37.0, 524.0 / (_cartas_por_fila - 1))
	# Las transformaciones van justo debajo de la última fila de objetos.
	_y_transformaciones = 44.0 + ceili(_objetos.size() / float(POR_FILA)) * 36.0 + 8.0


func abrir() -> void:
	_titulo_info = ""
	_texto_info = ""
	_cursor = -1
	visible = true
	queue_redraw()


func _caja_carta(i: int) -> Rect2:
	return Rect2(INICIO + Vector2((i % _cartas_por_fila) * _paso_cartas, (i / _cartas_por_fila) * 47.0), Vector2(32, 44))


func _caja_objeto(i: int) -> Rect2:
	return Rect2(Vector2(44.0 + (i % POR_FILA) * 37.0, 44.0 + (i / POR_FILA) * 36.0), Vector2(24, 24))


func _caja_transformacion(i: int) -> Rect2:
	return Rect2(Vector2(44.0 + (i % 5) * 112.0, _y_transformaciones + (i / 5) * 38.0), Vector2(106, 34))


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		_mirar(evento.position)
		queue_redraw()
	elif evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		_mirar(evento.position)  # con el dedo no hay "pasar por encima"
		for i in PESTANAS.size():
			if PESTANAS[i].has_point(evento.position):
				_cambiar_pagina(i)
		queue_redraw()
		if CAJA_VOLVER.has_point(evento.position):
			_volver()


func _cambiar_pagina(pagina: int) -> void:
	if pagina == _pagina:
		return
	_pagina = pagina
	_titulo_info = ""
	_texto_info = ""
	_cursor = -1
	Sonido.tocar("clic")
	queue_redraw()


func _unhandled_input(evento: InputEvent) -> void:
	if visible and Mando.es_mando(evento):
		_entrada_mando(Mando.tecla_mando(evento))
		get_viewport().set_input_as_handled()
		return
	if visible and evento is InputEventKey and evento.pressed and evento.keycode in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
		_cambiar_pagina(1 - _pagina)
		get_viewport().set_input_as_handled()
		return
	if visible and evento is InputEventKey and evento.pressed and not evento.echo \
			and evento.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		_volver()
		get_viewport().set_input_as_handled()


## Con el mando: LB y RB cambian de pestaña, la cruceta o el stick recorren las casillas
## (y se lee lo que es cada una) y B vuelve.
func _entrada_mando(tecla: Key) -> void:
	match tecla:
		KEY_PAGEUP, KEY_PAGEDOWN:
			_cambiar_pagina(1 - _pagina)
			_mover_cursor(Vector2.ZERO)
		KEY_LEFT: _mover_cursor(Vector2.LEFT)
		KEY_RIGHT: _mover_cursor(Vector2.RIGHT)
		KEY_UP: _mover_cursor(Vector2.UP)
		KEY_DOWN: _mover_cursor(Vector2.DOWN)
		KEY_ESCAPE: _volver()


## Las casillas de la pestaña abierta, en orden: naipes, o bien objetos y transformaciones.
func _casillas() -> Array:
	var cajas: Array = []
	if _pagina == 0:
		for i in _cartas.size():
			cajas.append(_caja_carta(i))
		return cajas
	for i in _objetos.size():
		cajas.append(_caja_objeto(i))
	for i in ObjetosDB.TRANSFORMACIONES.size():
		cajas.append(_caja_transformacion(i))
	return cajas


## A izquierda y derecha va de una en una; arriba y abajo, a la más cercana en esa dirección.
func _mover_cursor(hacia: Vector2) -> void:
	var cajas := _casillas()
	if cajas.is_empty():
		return
	if _cursor < 0 or _cursor >= cajas.size() or hacia == Vector2.ZERO:
		_cursor = 0
	elif hacia.x != 0.0:
		_cursor = wrapi(_cursor + int(hacia.x), 0, cajas.size())
	else:
		var desde: Vector2 = cajas[_cursor].get_center()
		var mejor := -1
		var mejor_d := INF
		for i in cajas.size():
			var d: Vector2 = cajas[i].get_center() - desde
			if d.y * hacia.y <= 2.0:
				continue
			var coste := absf(d.y) + absf(d.x) * 2.0
			if coste < mejor_d:
				mejor_d = coste
				mejor = i
		if mejor == -1:
			return
		_cursor = mejor
	Sonido.tocar("mover")
	_mirar(cajas[_cursor].get_center())
	queue_redraw()


func _volver() -> void:
	Sonido.tocar("clic")
	visible = false
	atras.emit()


func _mirar(p: Vector2) -> void:
	_titulo_info = ""
	_texto_info = ""
	for i in (_cartas.size() if _pagina == 0 else 0):
		if _caja_carta(i).has_point(p):
			_info(Progreso.carta_libre(_cartas[i]), CartasDB.nombre(_cartas[i]), CartasDB.descripcion(_cartas[i]))
			if not Progreso.carta_libre(_cartas[i]):
				_info_cerrada_carta(_cartas[i])
	for i in (_objetos.size() if _pagina == 1 else 0):
		if _caja_objeto(i).has_point(p):
			_info(Progreso.objeto_libre(_objetos[i]), ObjetosDB.nombre(_objetos[i]), ObjetosDB.descripcion(_objetos[i]))
			if not Progreso.objeto_libre(_objetos[i]):
				_texto_info = Idioma.t("LO ABRE UN JEFE: CADA JEFE QUE VENCES ABRE 2 OBJETOS AL AZAR.") + "\n" + _recuento()
	var ids: Array = ObjetosDB.TRANSFORMACIONES.keys() if _pagina == 1 else []
	for i in ids.size():
		if _caja_transformacion(i).has_point(p):
			var datos: Dictionary = ObjetosDB.TRANSFORMACIONES[ids[i]]
			_info(Progreso.transformaciones.has(ids[i]), Idioma.t(datos.nombre), ObjetosDB.descripcion_transformacion(ids[i]))
			if not Progreso.transformaciones.has(ids[i]):
				_info_transformacion_oculta(ids[i])


## Una carta cerrada: de qué rareza es, cómo se abre y cuánto llevas.
func _info_cerrada_carta(id: String) -> void:
	_titulo_info = "%s (%s)" % [Idioma.t("BLOQUEADO"), Idioma.t(CartasDB.NOMBRE_RAREZA[CartasDB.CARTAS[id].rareza])]
	_texto_info = Idioma.t("LA ABRE UN JEFE: CADA JEFE QUE VENCES ABRE 3 CARTAS AL AZAR.") + "\n" + _recuento()


func _recuento() -> String:
	return Idioma.t("CARTAS: %d/%d   OBJETOS: %d/%d   JEFES VENCIDOS: %d/%d") % [Progreso.cartas_libres(), _cartas.size(),
		Progreso.objetos_libres(), _objetos.size(), Progreso.jefes_vencidos.size(), Jefe.NOMBRES.size()]


## Una transformación sin descubrir: solo se nombran las piezas que ya has visto.
func _info_transformacion_oculta(id: String) -> void:
	var datos: Dictionary = ObjetosDB.TRANSFORMACIONES[id]
	var vistas: Array = (datos.piezas as Array).filter(func(p): return Progreso.visto("objetos", p))
	_titulo_info = "???"
	_texto_info = Idioma.t("TRANSFORMACIÓN SIN DESCUBRIR. REÚNE %d PIEZAS.") % int(datos.necesarias) + " " \
		+ Idioma.t("PIEZAS VISTAS: %d/%d") % [vistas.size(), datos.piezas.size()]
	if not vistas.is_empty():
		_texto_info += ": " + ", ".join(vistas.map(func(p): return ObjetosDB.nombre(p).to_upper()))


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
	for i in PESTANAS.size():
		draw_rect(PESTANAS[i], Color8(74, 52, 102) if i == _pagina else Color8(42, 31, 61))
		draw_string(Juego.fuente, PESTANAS[i].position + Vector2(0, 11), Idioma.t(["CARTAS", "OBJETOS"][i]), HORIZONTAL_ALIGNMENT_CENTER,
				PESTANAS[i].size.x, 8, COLOR_ORO if i == _pagina else COLOR_GRIS)
	for i in (_cartas.size() if _pagina == 0 else 0):
		draw_texture(_tex_cartas[_cartas[i]] if Progreso.carta_libre(_cartas[i]) else _cerrada, _caja_carta(i).position)
	for i in (_objetos.size() if _pagina == 1 else 0):
		var caja := _caja_objeto(i)
		draw_rect(caja, Color8(42, 31, 61))
		var tinte := Color.WHITE if Progreso.objeto_libre(_objetos[i]) else Color(0.08, 0.06, 0.12)
		draw_texture(_tex_objetos[_objetos[i]], caja.position + Vector2(6, 6), tinte)
	var ids: Array = ObjetosDB.TRANSFORMACIONES.keys() if _pagina == 1 else []
	for i in ids.size():
		var caja := _caja_transformacion(i)
		var conocida: bool = Progreso.transformaciones.has(ids[i])
		draw_rect(caja, Color8(42, 31, 61))
		var nombre: String = Idioma.t(ObjetosDB.TRANSFORMACIONES[ids[i]].nombre) if conocida else "???"
		draw_string(Juego.fuente, caja.position + Vector2(0, 11), nombre, HORIZONTAL_ALIGNMENT_CENTER, caja.size.x, 8,
				COLOR_ORO if conocida else COLOR_GRIS)
		_dibujar_piezas(ids[i], caja, conocida)
	# Las marcas van a la derecha de la línea del título, una al lado de la otra.
	var derecha := 596.0
	if Progreso.victorias_extremo > 0:
		var extremo := Idioma.t("EXTREMO SUPERADO: %d") % Progreso.victorias_extremo
		draw_string(Juego.fuente, Vector2(0, Y_INFO), extremo, HORIZONTAL_ALIGNMENT_RIGHT, derecha, 8, Color8(214, 61, 79))
		derecha -= Juego.fuente.get_string_size(extremo, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 12.0
	if Progreso.mejor_infinito > 0:
		draw_string(Juego.fuente, Vector2(0, Y_INFO), Idioma.t("RÉCORD INFINITO: PISO %d") % Progreso.mejor_infinito,
				HORIZONTAL_ALIGNMENT_RIGHT, derecha, 8, Color8(247, 198, 74))
	draw_string(Juego.fuente, Vector2(44, Y_INFO), _titulo_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO)
	draw_multiline_string(Juego.fuente, Vector2(44, Y_INFO + 13.0), _texto_info, HORIZONTAL_ALIGNMENT_LEFT, 552, 8, 3, COLOR_CREMA)
	draw_rect(CAJA_VOLVER, Color8(42, 31, 61))
	draw_string(Juego.fuente, Vector2(CAJA_VOLVER.position.x, 350), Idioma.t("VOLVER"), HORIZONTAL_ALIGNMENT_CENTER,
			CAJA_VOLVER.size.x, 8, COLOR_CREMA)
	if Mando.activo:
		_dibujar_mando()


## Las piezas de una transformación: en color las que ya has visto, en sombra las demás.
func _dibujar_piezas(id: String, caja: Rect2, conocida: bool) -> void:
	var piezas: Array = ObjetosDB.TRANSFORMACIONES[id].piezas
	var paso := 16.0
	var x0 := caja.get_center().x - (piezas.size() * paso - 4.0) * 0.5
	for j in piezas.size():
		var vista: bool = conocida or Progreso.visto("objetos", piezas[j])
		var tex: Texture2D = _tex_objetos[piezas[j]]
		var tinte := Color.WHITE if vista else Color(0.3, 0.27, 0.36)
		draw_texture(tex, Vector2(x0 + j * paso, caja.position.y + 16 + (12 - tex.get_height()) * 0.5), tinte)


## Con el mando: los botones de las pestañas a los lados y un marco dorado en la casilla.
func _dibujar_mando() -> void:
	var izq: Rect2 = PESTANAS[0]
	var der: Rect2 = PESTANAS[PESTANAS.size() - 1]
	draw_string(Juego.fuente, Vector2(izq.position.x - 40, izq.position.y + 11), Mando.nombre("pestana_izq"),
			HORIZONTAL_ALIGNMENT_RIGHT, 36, 8, COLOR_GRIS)
	draw_string(Juego.fuente, Vector2(der.end.x + 4, der.position.y + 11), Mando.nombre("pestana_der"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS)
	draw_string(Juego.fuente, Vector2(CAJA_VOLVER.end.x + 6, 350), Mando.nombre("volver"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS)
	var cajas := _casillas()
	if _cursor >= 0 and _cursor < cajas.size():
		draw_rect(cajas[_cursor].grow(2.0), COLOR_ORO, false, 1.0)
