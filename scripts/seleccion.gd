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
var _mesa_deseada := 0  # la última que eligió el jugador: al cambiar de personaje se recorta


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false
	_ids = PersonajesDB.PERSONAJES.keys()
	for id in _ids:
		_texturas[id] = PersonajesDB.textura(id)


func abrir() -> void:
	_abrir_coop()
	_mesa_deseada = maxi(_mesa_deseada, _mesa)
	_mesa = mini(_mesa_deseada, Progreso.mesa_elegible(_ids[_indice]))
	_contrato = false
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
	_mesa = wrapi(_mesa + sentido, 0, Progreso.mesa_elegible(_ids[_indice]) + 1)
	_mesa_deseada = _mesa
	Sonido.tocar("mover")


## Las mesas van por personaje: al cambiar, la mesa elegida se recorta a las que tiene abiertas.
func _elegir_personaje(i: int) -> void:
	_indice = wrapi(i, 0, _ids.size())
	_mesa = mini(_mesa_deseada, Progreso.mesa_elegible(_ids[_indice]))
	Sonido.tocar("mover")


func _gui_input(evento: InputEvent) -> void:
	if not (evento is InputEventMouseButton) or not evento.pressed or evento.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = evento.position
	if _contrato:
		_contrato_clic(p)
		return
	for i in _ids.size():
		if _caja(i).has_point(p):
			_elegir_personaje(i)
	if CAJA_CONTRATO.has_point(p):
		_abrir_contrato()
	elif FLECHA_IZQ.has_point(p):
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
	if not visible:
		return
	if _evento_coop(evento):
		get_viewport().set_input_as_handled()
		return
	if _contrato:
		if _contrato_tecla(Mando.tecla(evento)):
			get_viewport().set_input_as_handled()
		return
	# Con el mando: cruceta o stick, A empieza, B vuelve, X cambia el modo e Y abre el contrato.
	match Mando.tecla(evento):
		KEY_LEFT, KEY_A:
			_elegir_personaje(_indice - 1)
		KEY_RIGHT, KEY_D:
			_elegir_personaje(_indice + 1)
		KEY_Y, KEY_C:
			_abrir_contrato()
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
	if Mando.activo:
		estado += "  (%s)" % Mando.nombre_boton(JOY_BUTTON_X)
	_centrado(Juego.fuente, 8, Idioma.t("MODO: %s") % estado, CAJA_EXTREMO.position.x, CAJA_EXTREMO.size.x, 293, COLOR_CREMA)
	var libre := Progreso.personaje_libre(_ids[_indice])
	draw_rect(CAJA_EMPEZAR, Color8(122, 90, 160) if libre else Color8(42, 31, 61))
	_centrado(Juego.fuente, 8, Idioma.t("EMPEZAR"), CAJA_EMPEZAR.position.x, CAJA_EMPEZAR.size.x, 315, COLOR_CREMA if libre else COLOR_GRIS)
	draw_rect(CAJA_VOLVER, Color8(42, 31, 61))
	_centrado(Juego.fuente, 8, Idioma.t("VOLVER"), CAJA_VOLVER.position.x, CAJA_VOLVER.size.x, 339, COLOR_CREMA)
	_dibujar_caja_contrato()
	_dibujar_coop()
	if _contrato:
		_dibujar_contrato()


func _dibujar_personaje(i: int) -> void:
	var caja := _caja(i)
	var id: String = _ids[i]
	var datos: Dictionary = PersonajesDB.PERSONAJES[id]
	var libre := Progreso.personaje_libre(id)
	draw_rect(caja, Color8(42, 31, 61))
	draw_rect(caja, COLOR_ORO if i == _indice else Color8(74, 52, 102), false, 1.0)
	if not _j2.is_empty() and i == int(_j2.indice):
		draw_rect(caja.grow(-2.0), COLOR_J2, false, 1.0)
	_dibujar_pegatina(caja, id)
	var con_j2 := not _j2.is_empty() and i == int(_j2.indice)
	var columna := int(_t * 2.5) % 2 if i != _indice and not con_j2 else 2 + int(_t * 8.0) % 4
	var tinte := Color.WHITE if libre else Color(0.08, 0.06, 0.12)
	if con_j2 and i == _indice:
		tinte = TINTE_J2  # los dos con el mismo: el J2 irá teñido
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
		_dibujar_requisito(id, x, ancho, caja.position.y + 150)


# ---------------------------------------------------------------- pegatinas y Contrato de la Casa
const CAJA_CONTRATO := Rect2(436, 282, 196, 16)
const COLORES_MESA := [Color8(247, 236, 210), Color8(214, 61, 79), Color8(47, 138, 107), Color8(20, 16, 30), Color8(247, 198, 74)]
const COLOR_CALOR := Color8(240, 129, 60)
const NOMBRES_DORSO := ["CLÁSICO", "TAPETE", "MEDIANOCHE", "ORO"]
const FILA_CONTRATO := 21.0

var _contrato := false  # el panel del contrato está abierto
var _c_indice := 0
var _c_firmadas: Array = []
var _c_items: Array = []
var _dorsos_tex: Array = []


## En la esquina del retrato, una ficha del color de la mesa más alta ganada con él; en la
## otra, su récord de calor del Contrato de la Casa.
func _dibujar_pegatina(caja: Rect2, id: String) -> void:
	var ganada := Progreso.mesa_ganada(id)
	if ganada >= 0:
		var c := Vector2(caja.end.x - 10.0, caja.position.y + 10.0)
		var color: Color = COLORES_MESA[clampi(ganada, 0, COLORES_MESA.size() - 1)]
		draw_circle(c, 6.0, COLOR_GRIS if ganada == 3 else COLOR_FONDO)
		draw_circle(c, 5.0, color)
		for k in 4:  # las muescas del canto de la ficha
			draw_rect(Rect2(c + Vector2.from_angle(k * PI * 0.5) * 4.0 - Vector2(0.5, 0.5), Vector2(1, 1)), COLOR_CREMA if ganada != 0 else COLOR_GRIS)
		draw_circle(c, 2.0, color.darkened(0.3) if ganada != 3 else COLOR_GRIS)
	var record := Progreso.calor_record(id)
	if record > 0:
		Hud.dibujar_llama(self, caja.position + Vector2(8, 14))
		draw_string(Juego.fuente, caja.position + Vector2(13, 14), str(record), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_CALOR)


func _puede_contrato() -> bool:
	var id: String = _ids[_indice]
	return _modo == 0 and Progreso.personaje_libre(id) and Progreso.contrato_disponible(id)


func _dibujar_caja_contrato() -> void:
	var id: String = _ids[_indice]
	var texto: String
	var color := COLOR_GRIS
	if not Progreso.personaje_libre(id) or not Progreso.contrato_disponible(id):
		texto = Idioma.t("CONTRATO: GANA UNA VEZ CON ÉL")
	elif _modo != 0:
		texto = Idioma.t("CONTRATO: SOLO EN MODO NORMAL")
	else:
		texto = Idioma.t("CONTRATO: CALOR %d") % PersonajesDB.calor_de(Progreso.contrato(id))
		color = COLOR_CREMA
		if Mando.activo:
			texto += "  (%s)" % Mando.nombre_boton(JOY_BUTTON_Y)
		elif not Juego.tactil:
			texto += "  (C)"
	draw_rect(CAJA_CONTRATO, Color8(42, 31, 61))
	draw_rect(CAJA_CONTRATO, COLOR_CALOR if color == COLOR_CREMA else Color8(74, 52, 102), false, 1.0)
	_centrado(Juego.fuente, 8, texto, CAJA_CONTRATO.position.x, CAJA_CONTRATO.size.x, 293, color)


func _abrir_contrato() -> void:
	if not _puede_contrato():
		Sonido.tocar("perder")
		return
	if _dorsos_tex.is_empty():
		_dorsos_tex.append(load("res://assets/objetos/carta_suelo.png"))
		for n in range(1, NOMBRES_DORSO.size()):
			_dorsos_tex.append(load("res://assets/objetos/carta_suelo_%d.png" % n))
	_contrato = true
	_c_firmadas = Progreso.contrato(_ids[_indice])
	_c_items = PersonajesDB.CLAUSULAS.keys() + ["dorso", "traje", "listo"]
	_c_indice = 0
	Sonido.tocar("clic")


## Al cerrar se firma lo marcado (se recuerda para la próxima partida con este personaje).
func _cerrar_contrato() -> void:
	var id: String = _ids[_indice]
	Progreso.firmar(id, _c_firmadas)
	_texturas[id] = PersonajesDB.textura(id)
	_contrato = false
	Sonido.tocar("clic")


func _activar_contrato(item: String, sentido: int) -> void:
	var id: String = _ids[_indice]
	match item:
		"listo":
			_cerrar_contrato()
		"dorso":
			Progreso.dorso = wrapi(clampi(Progreso.dorso, 0, Progreso.dorsos_libres() - 1) + sentido, 0, Progreso.dorsos_libres())
			Sonido.tocar("mover")
		"traje":
			if not Progreso.traje_libre(id):
				Sonido.tocar("perder")
				return
			Progreso.traje_pj[id] = not Progreso.lleva_traje(id)
			_texturas[id] = PersonajesDB.textura(id)
			Sonido.tocar("mover")
		_:
			if _c_firmadas.has(item):
				_c_firmadas.erase(item)
				Sonido.tocar("clic")
			else:
				_c_firmadas.append(item)
				Sonido.tocar("mult", 1.0 + 0.1 * PersonajesDB.calor_de(_c_firmadas))


## Teclado y mando: arriba y abajo eligen, A (Enter) marca, los lados cambian dorso y traje,
## B (Esc) o Y (C) cierran firmando.
func _contrato_tecla(tecla: Key) -> bool:
	match tecla:
		KEY_UP, KEY_W:
			_c_indice = wrapi(_c_indice - 1, 0, _c_items.size())
			Sonido.tocar("mover")
		KEY_DOWN, KEY_S:
			_c_indice = wrapi(_c_indice + 1, 0, _c_items.size())
			Sonido.tocar("mover")
		KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
			if _c_items[_c_indice] in ["dorso", "traje"]:
				_activar_contrato(_c_items[_c_indice], -1 if tecla in [KEY_LEFT, KEY_A] else 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_activar_contrato(_c_items[_c_indice], 1)
		KEY_ESCAPE, KEY_Y, KEY_C:
			_cerrar_contrato()
		_:
			return false
	return true


func _caja_item(i: int) -> Rect2:
	var n := PersonajesDB.CLAUSULAS.size()
	if i < n:
		return Rect2(110, 46 + i * FILA_CONTRATO, 420, FILA_CONTRATO - 2.0)
	if i == n:
		return Rect2(170, 236, 300, 16)
	if i == n + 1:
		return Rect2(170, 256, 300, 16)
	return Rect2(240, 280, 160, 18)


func _contrato_clic(p: Vector2) -> void:
	for i in _c_items.size():
		if _caja_item(i).has_point(p):
			_c_indice = i
			_activar_contrato(_c_items[i], 1)
			return


func _dibujar_contrato() -> void:
	var id: String = _ids[_indice]
	draw_rect(Rect2(0, 0, 640, 360), COLOR_FONDO)
	_centrado(Juego.fuente_grande, 16, Idioma.t("CONTRATO DE LA CASA"), 0, 640, 24, COLOR_CALOR)
	var calor := PersonajesDB.calor_de(_c_firmadas)
	_centrado(Juego.fuente, 8, Idioma.t("%s   CALOR: %d   RÉCORD: %d") % [PersonajesDB.nombre(id).to_upper(), calor, Progreso.calor_record(id)],
			0, 640, 38, COLOR_CREMA)
	var claves: Array = PersonajesDB.CLAUSULAS.keys()
	for i in _c_items.size():
		var caja := _caja_item(i)
		var elegida := i == _c_indice
		draw_rect(caja, Color8(74, 52, 102) if elegida else Color8(42, 31, 61))
		draw_rect(caja, COLOR_ORO if elegida else Color8(74, 52, 102), false, 1.0)
		if i < claves.size():
			_dibujar_clausula(caja, claves[i])
	var n := claves.size()
	_centrado(Juego.fuente, 8, Idioma.t("PREMIOS: DORSOS NUEVOS CON CALOR %d, %d Y %d. TRAJE DE GALA CON CALOR %d.") % (Progreso.UMBRALES_DORSO + [Progreso.UMBRAL_TRAJE]),
			0, 640, 230, COLOR_GRIS)
	var dorso := clampi(Progreso.dorso, 0, Progreso.dorsos_libres() - 1)
	var caja_dorso := _caja_item(n)
	_centrado(Juego.fuente, 8, "<  " + Idioma.t("DORSO: %s (%d DE %d)") % [Idioma.t(NOMBRES_DORSO[dorso]), Progreso.dorsos_libres(), NOMBRES_DORSO.size()] + "  >",
			caja_dorso.position.x, caja_dorso.size.x, caja_dorso.position.y + 11, COLOR_CREMA)
	draw_texture(_dorsos_tex[dorso], caja_dorso.position + Vector2(-24, -3))
	var caja_traje := _caja_item(n + 1)
	var texto_traje := Idioma.t("TRAJE: DE GALA") if Progreso.lleva_traje(id) else Idioma.t("TRAJE: EL DE SIEMPRE")
	if not Progreso.traje_libre(id):
		texto_traje = Idioma.t("TRAJE DE GALA: GANA CON CALOR %d") % Progreso.UMBRAL_TRAJE
	_centrado(Juego.fuente, 8, texto_traje, caja_traje.position.x, caja_traje.size.x, caja_traje.position.y + 11,
			COLOR_CREMA if Progreso.traje_libre(id) else COLOR_GRIS)
	draw_texture_rect_region(_texturas[id], Rect2(caja_traje.position + Vector2(-24, 0), Vector2(16, 16)), Rect2(0, 0, 16, 16))
	var caja_listo := _caja_item(n + 2)
	_centrado(Juego.fuente, 8, Idioma.t("FIRMAR"), caja_listo.position.x, caja_listo.size.x, caja_listo.position.y + 12, COLOR_CREMA)
	var ayuda: String
	if Mando.activo:
		ayuda = Idioma.t("%s: MARCAR   %s: FIRMAR Y VOLVER") % [Mando.nombre("aceptar"), Mando.nombre("volver")]
	elif Juego.tactil:
		ayuda = Idioma.t("TOCA UNA CLÁUSULA PARA MARCARLA")
	else:
		ayuda = Idioma.t("ENTER: MARCAR   ESC: FIRMAR Y VOLVER")
	_centrado(Juego.fuente, 8, ayuda, 0, 640, 314, COLOR_GRIS)
	_centrado(Juego.fuente, 8, Idioma.t("NO VALE EN EL RETO DIARIO, EL EXTREMO NI EL IMPOSIBLE."), 0, 640, 328, COLOR_GRIS)


func _dibujar_clausula(caja: Rect2, clave: String) -> void:
	var datos: Dictionary = PersonajesDB.CLAUSULAS[clave]
	var firmada := _c_firmadas.has(clave)
	var casilla := Rect2(caja.position + Vector2(6, 5), Vector2(9, 9))
	draw_rect(casilla, COLOR_FONDO)
	draw_rect(casilla, COLOR_CALOR if firmada else COLOR_GRIS, false, 1.0)
	if firmada:
		draw_rect(casilla.grow(-2.0), COLOR_CALOR)
	draw_string(Juego.fuente, caja.position + Vector2(22, 9), Idioma.t(datos.nombre), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO if firmada else COLOR_CREMA)
	draw_string(Juego.fuente, caja.position + Vector2(22, 17), Idioma.t(datos.desc), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS)
	for k in int(datos.calor):
		Hud.dibujar_llama(self, caja.end - Vector2(10.0 + k * 9.0, 6.0))


## Cuánto te falta para abrir un personaje: una barra y el recuento ("734/1000").
func _dibujar_requisito(id: String, x: float, ancho: float, y: float) -> void:
	var p := Progreso.progreso_personaje(id)
	var barra := Rect2(x + 6, y, ancho - 12, 5)
	draw_rect(barra, Color8(20, 16, 30))
	draw_rect(Rect2(barra.position, Vector2(barra.size.x * clampf(float(p.x) / maxi(p.y, 1), 0.0, 1.0), barra.size.y)), COLOR_ORO)
	_centrado(Juego.fuente, 8, "%d/%d" % [p.x, p.y], x, ancho, y + 16, COLOR_GRIS)


# ---------------------------------------------------------------- cooperativo local
## Un segundo jugador se une pulsando en OTRO dispositivo: START en otro mando, o Ctrl derecho
## en el teclado (si el J1 va con mando, el J2 se queda el teclado entero; si no, se lo reparten:
## J1 WASD y J2 flechas). Cualquier otra tecla o botón de otro dispositivo es el J1 que cambia
## de mando a teclado o al revés: así nadie se une sin querer.
## Cada uno elige su personaje; la mesa, el modo y el contrato los elige el J1.
const COLOR_J2 := Color8(111, 195, 232)
const TINTE_J2 := Color(0.72, 0.9, 1.3)

var entrada_j1 := Mando.TECLADO
var _j2: Dictionary = {}  # {} o {"entrada": de Mando, "indice": su personaje}


## Lo que necesita main para empezar en cooperativo ({} si el J2 no está).
func config_coop() -> Dictionary:
	if _j2.is_empty() or not hay_coop():
		return {}
	return {"personaje2": _ids[int(_j2.indice)], "entrada1": entrada_j1, "entrada2": int(_j2.entrada)}


## En el móvil sin mandos no se ofrece: hace falta un mando o un teclado.
func hay_coop() -> bool:
	return not (Juego.tactil and Input.get_connected_joypads().is_empty())


func j2_unido() -> bool:
	return not _j2.is_empty()


func _abrir_coop() -> void:
	if not Input.joy_connection_changed.is_connected(_al_cambiar_mando):
		Input.joy_connection_changed.connect(_al_cambiar_mando)
	var e1 := Mando.dispositivo if Mando.activo else Mando.TECLADO
	if _j2.is_empty():
		entrada_j1 = e1
		return
	# El J2 sigue unido de la partida anterior, salvo que ya no esté su mando.
	var e2 := int(_j2.entrada)
	if e2 >= 0 and not Input.get_connected_joypads().has(e2):
		_j2 = {}
		entrada_j1 = e1
	elif e2 == Mando.TECLADO_DER:
		entrada_j1 = Mando.TECLADO_IZQ
	elif e1 != e2:
		entrada_j1 = e1


func _al_cambiar_mando(disp: int, conectado: bool) -> void:
	if not conectado and not _j2.is_empty() and int(_j2.entrada) == disp:
		_salir_j2()


func _unir_j2(entrada: int) -> void:
	var i := _indice
	_j2 = {"entrada": entrada, "indice": i}
	if not Progreso.personaje_libre(_ids[i]):
		_mover_j2(1)
	Sonido.tocar("mult", 1.2)


func _salir_j2() -> void:
	if _j2.is_empty():
		return
	if int(_j2.entrada) == Mando.TECLADO_DER:
		entrada_j1 = Mando.TECLADO
	_j2 = {}
	Sonido.tocar("clic")


## El J2 solo puede elegir personajes desbloqueados.
func _mover_j2(sentido: int) -> void:
	var i := int(_j2.indice)
	for _k in _ids.size():
		i = wrapi(i + sentido, 0, _ids.size())
		if Progreso.personaje_libre(_ids[i]):
			break
	_j2.indice = i
	Sonido.tocar("mover")


## Devuelve true si el evento era del J2 (o para unirse) y ya está atendido.
func _evento_coop(evento: InputEvent) -> bool:
	if not hay_coop():
		return false
	if _j2.is_empty():
		return _mirar_union(evento)
	var e2 := int(_j2.entrada)
	if Mando.es_de(e2, evento):
		var tecla := Mando.tecla(evento)
		if evento is InputEventKey and evento.pressed and not evento.echo:
			tecla = evento.physical_keycode
		match tecla:
			KEY_LEFT, KEY_A:
				_mover_j2(-1)
			KEY_RIGHT, KEY_D:
				_mover_j2(1)
			KEY_ESCAPE, KEY_BACKSPACE:
				_salir_j2()
		return true  # lo del J2 no lo ve el J1
	# Un tercer mando no maneja el menú del J1 (el teclado sí, si no es del J2).
	if Mando.es_mando(evento) and evento.device != entrada_j1:
		return true
	return false


func _mirar_union(evento: InputEvent) -> bool:
	if evento is InputEventJoypadButton and evento.pressed and evento.device != entrada_j1:
		if Mando.PAUSA.has(evento.button_index):
			_unir_j2(evento.device)
			return true
		entrada_j1 = evento.device  # el J1 ha cogido el mando
		return false
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return false
	if evento.physical_keycode == KEY_CTRL and evento.location == KEY_LOCATION_RIGHT:
		if entrada_j1 >= 0:
			_unir_j2(Mando.TECLADO)
		else:
			entrada_j1 = Mando.TECLADO_IZQ
			_unir_j2(Mando.TECLADO_DER)
		return true
	entrada_j1 = Mando.TECLADO  # el J1 ha vuelto al teclado
	return false


## Arriba, encima del título: cómo unirse, o quién es el J2 y cómo salirse.
func _dibujar_coop() -> void:
	if not hay_coop():
		return
	if _j2.is_empty():
		var texto := Idioma.t("J2: PULSA %s EN OTRO MANDO O CTRL DCHO. PARA UNIRTE") % Mando.nombre("pausa")
		_centrado(Juego.fuente, 8, texto, 0, 640, 10, COLOR_J2 if int(_t * 2.0) % 2 == 0 else COLOR_GRIS)
		return
	var e2 := int(_j2.entrada)
	var salir: String
	if e2 >= 0:
		salir = Mando.nombre("volver")
	elif e2 == Mando.TECLADO_DER:
		salir = Idioma.t("RETROCESO")
	else:
		salir = "ESC"
	var texto := Idioma.t("J2: %s  (%s: SALIRSE)") % [PersonajesDB.nombre(_ids[int(_j2.indice)]).to_upper(), salir]
	_centrado(Juego.fuente, 8, texto, 0, 640, 10, COLOR_J2)
	# Las etiquetas encima de cada caja elegida.
	var c1 := _caja(_indice)
	var c2 := _caja(int(_j2.indice))
	draw_string(Juego.fuente, c1.position + Vector2(3, 9), Idioma.t("J1"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO)
	draw_string(Juego.fuente, c2.position + Vector2(3, 18 if c1 == c2 else 9), Idioma.t("J2"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_J2)
	if e2 == Mando.TECLADO_DER:
		_centrado(Juego.fuente, 8, Idioma.t("J1: WASD, ESPACIO, Q, E   J2: FLECHAS, CTRL DCHO., MAYÚS DCHA., FIN"), 0, 640, 236, COLOR_GRIS)
