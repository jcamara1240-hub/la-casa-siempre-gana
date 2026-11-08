class_name Menu
extends Control
## Menú principal, opciones y pausa. Funciona con ratón y con teclado.

signal jugar
signal continuar
signal ir_a_portada
signal ver_coleccion

enum Vista { PRINCIPAL, OPCIONES, PAUSA }

const ANCHO_BOTON := 260.0
const ALTO_BOTON := 18.0
const SEPARACION := 22.0
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_FONDO := Color8(20, 16, 30)

var _vista := Vista.PRINCIPAL
var _desde_pausa := false
var _items: Array = []
var _indice := 0
var _caen: Array = []
var _cartas_fondo: Array = []
var solo_titulo := false  # para el final del tráiler


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	for id in CartasDB.CARTAS:
		_cartas_fondo.append(CartasDB.textura(id))
	for i in 16:
		_caen.append(_nueva_carta(randf_range(-60.0, 360.0)))


func abrir_principal() -> void:
	_desde_pausa = false
	_ir_a(Vista.PRINCIPAL)
	visible = true


func abrir_pausa() -> void:
	_desde_pausa = true
	_ir_a(Vista.PAUSA)
	visible = true


func cerrar() -> void:
	visible = false


func _ir_a(vista: Vista) -> void:
	_vista = vista
	_indice = 0
	var web := OS.has_feature("web")
	match vista:
		Vista.PRINCIPAL:
			# En el navegador un juego no puede cerrar la pestaña: el botón no haría nada.
			_items = ["jugar", "coleccion", "opciones"] if web else ["jugar", "coleccion", "opciones", "salir"]
		Vista.PAUSA:
			_items = ["continuar", "opciones", "portada"]
		Vista.OPCIONES:
			_items = ["idioma", "musica", "efectos", "sacudida", "numeros", "volver"]
			if not web:
				_items.insert(3, "pantalla")
	queue_redraw()


func _nueva_carta(y: float) -> Dictionary:
	return {
		"pos": Vector2(randf_range(10.0, 630.0), y),
		"vel": randf_range(14.0, 34.0),
		"giro": randf_range(-0.8, 0.8),
		"ang": randf() * TAU,
		"tex": _cartas_fondo[randi() % _cartas_fondo.size()],
	}


func _process(delta: float) -> void:
	if not visible:
		return
	for i in _caen.size():
		var c: Dictionary = _caen[i]
		c.pos.y += c.vel * delta
		c.ang += c.giro * delta
		if c.pos.y > 400.0:
			_caen[i] = _nueva_carta(-40.0)
	queue_redraw()


func _inicio_botones() -> float:
	return 148.0 if _vista == Vista.PRINCIPAL else 104.0


func _caja(i: int) -> Rect2:
	return Rect2(320.0 - ANCHO_BOTON * 0.5, _inicio_botones() + i * SEPARACION, ANCHO_BOTON, ALTO_BOTON)


func _boton_en(p: Vector2) -> int:
	for i in _items.size():
		if _caja(i).has_point(p):
			return i
	return -1


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		var i := _boton_en(evento.position)
		if i != -1 and i != _indice:
			_indice = i
			Sonido.tocar("mover")
	elif evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var i := _boton_en(evento.position)
		if i != -1:
			_indice = i
			_activar(_items[i], 1)


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match evento.keycode:
		KEY_UP, KEY_W:
			_indice = wrapi(_indice - 1, 0, _items.size())
			Sonido.tocar("mover")
		KEY_DOWN, KEY_S:
			_indice = wrapi(_indice + 1, 0, _items.size())
			Sonido.tocar("mover")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_activar(_items[_indice], 1)
		KEY_LEFT, KEY_A:
			_cambiar_con_flechas(-1)
		KEY_RIGHT, KEY_D:
			_cambiar_con_flechas(1)
		KEY_ESCAPE:
			_atras()
		_:
			return
	get_viewport().set_input_as_handled()


func _cambiar_con_flechas(sentido: int) -> void:
	if _vista == Vista.OPCIONES and _items[_indice] != "volver":
		_activar(_items[_indice], sentido)


func _atras() -> void:
	match _vista:
		Vista.OPCIONES:
			_ir_a(Vista.PAUSA if _desde_pausa else Vista.PRINCIPAL)
		Vista.PAUSA:
			cerrar()
			continuar.emit()


func _activar(id: String, sentido: int) -> void:
	Sonido.tocar("clic")
	match id:
		"coleccion":
			cerrar()
			ver_coleccion.emit()
		"musica":
			Juego.cambiar_volumenes(_siguiente_volumen(Juego.volumen_musica, sentido), Juego.volumen_efectos)
		"efectos":
			Juego.cambiar_volumenes(Juego.volumen_musica, _siguiente_volumen(Juego.volumen_efectos, sentido))
		"jugar":
			cerrar()
			jugar.emit()
		"continuar":
			cerrar()
			continuar.emit()
		"opciones":
			_ir_a(Vista.OPCIONES)
		"portada":
			ir_a_portada.emit()
		"salir":
			get_tree().quit()
		"volver":
			_atras()
		"idioma":
			var i := Idioma.IDIOMAS.find(Idioma.actual)
			Juego.cambiar_idioma(Idioma.IDIOMAS[wrapi(i + sentido, 0, Idioma.IDIOMAS.size())])
		"pantalla":
			Juego.cambiar_pantalla_completa(not Juego.pantalla_completa)
		"sacudida":
			Juego.sacudida = not Juego.sacudida
			Juego.guardar_ajustes()
		"numeros":
			Juego.numeros_dano = not Juego.numeros_dano
			Juego.guardar_ajustes()


## Va de diez en diez y da la vuelta: con Enter se puede llegar a cualquier valor.
func _siguiente_volumen(actual: float, sentido: int) -> float:
	var pasos := wrapi(roundi(actual * 10.0) + sentido, 0, 11)
	return pasos / 10.0


func _si_no(valor: bool) -> String:
	return Idioma.t("SÍ") if valor else Idioma.t("NO")


func _texto(id: String) -> String:
	match id:
		"jugar": return Idioma.t("JUGAR")
		"coleccion": return Idioma.t("COLECCIÓN")
		"musica": return Idioma.t("MÚSICA: %d%%") % roundi(Juego.volumen_musica * 100.0)
		"efectos": return Idioma.t("EFECTOS: %d%%") % roundi(Juego.volumen_efectos * 100.0)
		"opciones": return Idioma.t("OPCIONES")
		"salir": return Idioma.t("SALIR")
		"continuar": return Idioma.t("CONTINUAR")
		"portada": return Idioma.t("MENÚ PRINCIPAL")
		"volver": return Idioma.t("VOLVER")
		"idioma": return Idioma.t("IDIOMA: %s") % Idioma.NOMBRES[Idioma.actual]
		"pantalla": return Idioma.t("PANTALLA COMPLETA: %s") % _si_no(Juego.pantalla_completa)
		"sacudida": return Idioma.t("SACUDIDA DE PANTALLA: %s") % _si_no(Juego.sacudida)
		"numeros": return Idioma.t("NÚMEROS DE DAÑO: %s") % _si_no(Juego.numeros_dano)
	return id


func _draw() -> void:
	if _desde_pausa:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.06, 0.05, 0.1, 0.88))
	else:
		_dibujar_fondo()
	var cabecera := ""
	match _vista:
		Vista.PRINCIPAL: _dibujar_titulo()
		Vista.OPCIONES: cabecera = Idioma.t("OPCIONES")
		Vista.PAUSA: cabecera = Idioma.t("PAUSA")
	if cabecera != "":
		var ancho := Juego.fuente_grande.get_string_size(cabecera, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(Juego.fuente_grande, Vector2(320.0 - ancho * 0.5, 92), cabecera,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_ORO)
	for i in _items.size():
		_dibujar_boton(i)
	if _vista == Vista.PRINCIPAL and not solo_titulo:
		_dibujar_instrucciones()


func _dibujar_fondo() -> void:
	draw_rect(Rect2(0, 0, 640, 360), COLOR_FONDO)
	for c in _caen:
		draw_set_transform(c.pos, c.ang)
		draw_texture(c.tex, Vector2(-16, -22), Color(0.42, 0.38, 0.5))
	draw_set_transform(Vector2.ZERO)


func _dibujar_titulo() -> void:
	var titulo := Idioma.t("LA CASA SIEMPRE GANA")
	var ancho := Juego.fuente_grande.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 2.0
	var origen := Vector2(320.0 - ancho * 0.5, 104)
	for capa in [[Vector2(2, 2), Color8(143, 35, 64)], [Vector2.ZERO, COLOR_ORO]]:
		draw_set_transform(origen + capa[0], 0.0, Vector2(2, 2))
		draw_string(Juego.fuente_grande, Vector2.ZERO, titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, capa[1])
	draw_set_transform(Vector2.ZERO)


func _dibujar_boton(i: int) -> void:
	var caja := _caja(i)
	var elegido := i == _indice
	draw_rect(caja, Color8(122, 90, 160) if elegido else Color8(42, 31, 61))
	draw_rect(caja, COLOR_ORO if elegido else Color8(74, 52, 102), false, 1.0)
	draw_string(Juego.fuente, Vector2(caja.position.x, caja.position.y + 12), _texto(_items[i]),
			HORIZONTAL_ALIGNMENT_CENTER, caja.size.x, 8, COLOR_CREMA)


func _dibujar_instrucciones() -> void:
	var lineas := [
		"MUÉVETE CON WASD O LAS FLECHAS. TU PERSONAJE ATACA SOLO.",
		"CADA CICLO, TUS CARTAS SE EJECUTAN DE IZQUIERDA A DERECHA.",
		"EL ORDEN IMPORTA: PONLAS BIEN ENTRE SALA Y SALA.",
	]
	for i in lineas.size():
		draw_string(Juego.fuente, Vector2(0, 300 + i * 12), Idioma.t(lineas[i]), HORIZONTAL_ALIGNMENT_CENTER, 640, 8,
				Color8(168, 154, 142))
