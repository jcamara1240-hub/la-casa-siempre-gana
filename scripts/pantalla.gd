class_name Pantalla
extends Control
## El final de la partida. Si ganas: tres sietes, lluvia de monedas y marcador.
## Si pierdes, solo el marcador. Enter salta la animación y, ya terminada, sale.

signal aceptada
signal seguir_infinito

const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)
const COLOR_ROJO := Color8(214, 61, 79)
const COLOR_FONDO := Color8(20, 16, 30)

const FIN_RODILLOS := 2.5
const SEG_POR_DATO := 0.55
const SEG_POR_DESBLOQUEO := 0.2
const POR_FILA := 16
const ANCHO_CASILLA := 36.0
const MAX_NOVEDADES := 32
const CAJA_SEGUIR := Rect2(120, 334, 190, 18)
const CAJA_MENU := Rect2(330, 334, 190, 18)

var _gano := false
var _opcion := 0
var _t := 0.0
var _inicio_datos := 0.4
var _inicio_novedades := 0.0
var _fin := 0.0
var _datos: Array = []
var _novedades: Array = []
var _monedas: Array = []
var _sonados := {}
var _tex_rodillos: Texture2D
var _tex_moneda: Texture2D
var _tex_jugador: Texture2D
var _tex_cerrada: Texture2D
var _tex_trofeo: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false
	_tex_rodillos = load("res://assets/personajes/rodillos.png")
	_tex_moneda = load("res://assets/objetos/moneda.png")
	_tex_cerrada = load("res://assets/cartas/_hueco.png")
	_tex_trofeo = load("res://assets/objetos/trofeo.png")


func mostrar_final(gano: bool) -> void:
	_gano = gano
	_opcion = 0
	_t = 0.0
	_sonados.clear()
	_monedas.clear()
	_tex_jugador = PersonajesDB.textura(Juego.personaje)
	_preparar_datos()
	_preparar_novedades()
	_inicio_datos = FIN_RODILLOS + 0.9 if gano else 0.5
	_inicio_novedades = _inicio_datos + _datos.size() * SEG_POR_DATO + 0.3
	_fin = _inicio_novedades + _novedades.size() * SEG_POR_DESBLOQUEO
	visible = true


func animacion_terminada() -> bool:
	return _t >= _fin


func _preparar_datos() -> void:
	var minutos := int(Juego.tiempo_partida) / 60
	var segundos := int(Juego.tiempo_partida) % 60
	_datos = [
		{"texto": "ENEMIGOS", "valor": Juego.enemigos_eliminados},
		{"texto": "MEJOR COMBO", "valor": roundi(Juego.mejor_combo)},
		{"texto": "MONEDAS GANADAS", "valor": Juego.oro_total},
		{"texto": "PUNTOS", "valor": Juego.puntos_reto(_gano)} if Juego.diario else {"texto": "OBJETOS", "valor": Juego.objetos.size()},
		{"texto": "TIEMPO", "fijo": "%d:%02d" % [minutos, segundos]},
		{"texto": "PERSONAJE", "fijo": PersonajesDB.nombre(Juego.personaje).to_upper()},
		{"texto": "MESA", "fijo": _nombre_mesa()},
	]
	# En el reto la mesa es siempre la misma: en su sitio, los golpes, que restan puntos.
	if Juego.diario:
		_datos[-1] = {"texto": "GOLPES RECIBIDOS", "valor": Juego.golpes}
	if Juego.infinito:
		_datos.append({"texto": "RÉCORD INFINITO", "valor": Progreso.mejor_infinito})


func _nombre_mesa() -> String:
	if Juego.imposible:
		return Idioma.t("IMPOSIBLE")
	return Idioma.t("EXTREMO") if Juego.extremo else Idioma.t(PersonajesDB.MESAS[Juego.mesa].nombre).to_upper()


## Tras ganar se puede seguir bajando, salvo en el reto diario: su marca ya está hecha.
func _hay_oferta() -> bool:
	return _gano and not Juego.diario and animacion_terminada()


func _elegir(opcion: int) -> void:
	Sonido.tocar("clic")
	visible = false
	if opcion == 0:
		seguir_infinito.emit()
	else:
		aceptada.emit()


## Se cargan aquí y no al pintar: una textura cargada durante _draw sale en blanco.
func _preparar_novedades() -> void:
	_novedades = []
	for n in Juego.novedades.slice(0, MAX_NOVEDADES):
		var entrada: Dictionary = n.duplicate()
		match String(n.tipo):
			"carta":
				entrada["tex"] = CartasDB.textura(n.id)
				entrada["nombre"] = CartasDB.nombre(n.id)
			"objeto":
				entrada["tex"] = ObjetosDB.textura(n.id)
				entrada["nombre"] = ObjetosDB.nombre(n.id)
			"personaje":
				entrada["tex"] = PersonajesDB.textura(n.id)
				entrada["nombre"] = PersonajesDB.nombre(n.id)
			"logro":
				entrada["tex"] = _tex_trofeo
				entrada["nombre"] = LogrosDB.nombre(n.id)
			"mesa":
				entrada["nombre"] = Idioma.t(PersonajesDB.MESAS[int(n.id)].nombre)
		_novedades.append(entrada)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_sonar()
	if _gano and _t > FIN_RODILLOS:
		_mover_monedas(delta)
	queue_redraw()


func _una_vez(clave: String) -> bool:
	if _sonados.has(clave):
		return false
	_sonados[clave] = true
	return true


func _sonar() -> void:
	if _gano:
		for i in 3:
			if _t >= _parada(i) and _una_vez("rodillo%d" % i):
				Sonido.tocar("mult", 1.0 + i * 0.25)
		if _t >= FIN_RODILLOS and _una_vez("premio"):
			Sonido.tocar("victoria")
			Sonido.tocar("explosion", 0.7)
			Sonido.musica("victoria")
	for i in _datos.size():
		if _t >= _inicio_datos + i * SEG_POR_DATO and _una_vez("dato%d" % i):
			Sonido.tocar("tick", 1.0 + i * 0.12)
	for i in _novedades.size():
		if _t >= _inicio_novedades + i * SEG_POR_DESBLOQUEO and _una_vez("nov%d" % i):
			Sonido.tocar("carta_coger", 1.0 + (i % 8) * 0.08, -4.0)


func _parada(i: int) -> float:
	return 1.0 + i * 0.6


func _mover_monedas(delta: float) -> void:
	if _monedas.size() < 170 and randf() < delta * 90.0:
		_monedas.append({"pos": Vector2(randf_range(0.0, 640.0), -10.0), "vel": randf_range(70.0, 190.0), "fase": randf() * 4.0})
	for m in _monedas:
		m.pos.y += m.vel * delta
		m.fase += delta * 11.0
		if m.pos.y > 370.0:
			m.pos = Vector2(randf_range(0.0, 640.0), -10.0)


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		if not _hay_oferta():
			_avanzar()
		elif CAJA_SEGUIR.has_point(evento.position):
			_elegir(0)
		elif CAJA_MENU.has_point(evento.position):
			_elegir(1)


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	if _hay_oferta():
		match evento.keycode:
			KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D:
				_opcion = 1 - _opcion
				Sonido.tocar("clic")
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_elegir(_opcion)
			KEY_ESCAPE:
				_elegir(1)
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if evento.keycode not in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		return
	get_viewport().set_input_as_handled()
	_avanzar()


func _avanzar() -> void:
	if animacion_terminada():
		visible = false
		aceptada.emit()
	else:
		_t = _fin
		for i in 3:
			_sonados["rodillo%d" % i] = true
		_sonados["premio"] = true
		if _gano:
			Sonido.musica("victoria")
		for i in _datos.size():
			_sonados["dato%d" % i] = true
		for i in _novedades.size():
			_sonados["nov%d" % i] = true


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), COLOR_FONDO)
	if _gano:
		_dibujar_monedas()
		_dibujar_rodillos()
	if not _gano or _t >= FIN_RODILLOS:
		_dibujar_titulo()
	if _t >= _inicio_datos:
		_dibujar_datos()
		_dibujar_jugador()
	if _t >= _inicio_novedades and not _novedades.is_empty():
		_dibujar_novedades()
	if _hay_oferta():
		_dibujar_oferta()
	elif animacion_terminada() and fmod(_t, 1.0) < 0.65:
		draw_string(Juego.fuente, Vector2(0, 352), Idioma.t("TOCA PARA CONTINUAR") if Juego.tactil else Idioma.t("PULSA ENTER"), HORIZONTAL_ALIGNMENT_CENTER, 640, 8, Color8(108, 207, 148))


func _dibujar_oferta() -> void:
	var cajas := [CAJA_SEGUIR, CAJA_MENU]
	var textos := [Idioma.t("SEGUIR: MODO INFINITO"), Idioma.t("SALIR AL MENÚ")]
	for i in 2:
		var elegida := i == _opcion
		draw_rect(cajas[i], Color8(143, 35, 64) if elegida and i == 0 else Color8(74, 52, 102) if elegida else Color8(42, 31, 61))
		draw_rect(cajas[i], COLOR_ORO if elegida else COLOR_GRIS, false, 1.0)
		draw_string(Juego.fuente, cajas[i].position + Vector2(0, 13), textos[i], HORIZONTAL_ALIGNMENT_CENTER, cajas[i].size.x, 8, COLOR_CREMA)


func _dibujar_monedas() -> void:
	for m in _monedas:
		var marco := int(m.fase) % 4
		draw_texture_rect_region(_tex_moneda, Rect2(m.pos, Vector2(8, 8)), Rect2(marco * 8, 0, 8, 8), Color(1, 1, 1, 0.55))


func _dibujar_rodillos() -> void:
	# Grandes al centro y, al salir los tres sietes, suben a acompañar al título.
	var avance := smoothstep(FIN_RODILLOS, FIN_RODILLOS + 0.5, _t)
	var escala: float = lerpf(5.0, 2.0, avance)
	var y: float = lerpf(130.0, 62.0, avance)
	var lado := 10.0 * escala
	var hueco := 3.0 * escala
	var total := lado * 3.0 + hueco * 2.0
	var x0 := 320.0 - total * 0.5
	draw_rect(Rect2(x0 - hueco, y - hueco, total + hueco * 2.0, lado + hueco * 2.0), Color8(143, 35, 64))
	for i in 3:
		var caja := Rect2(x0 + i * (lado + hueco), y, lado, lado)
		draw_rect(caja.grow(1.0), Color8(20, 16, 30))
		draw_rect(caja, COLOR_CREMA)
		var simbolo := 0 if _t >= _parada(i) else int(_t * 20.0 + i) % 3
		draw_texture_rect_region(_tex_rodillos, caja, Rect2(simbolo * 10, 0, 10, 10))
	if _t < FIN_RODILLOS:
		draw_string(Juego.fuente_grande, Vector2(0, 220), Idioma.t("JACKPOT"), HORIZONTAL_ALIGNMENT_CENTER, 640, 16, COLOR_GRIS)


func _dibujar_titulo() -> void:
	var titulo := Idioma.t("HAS DESBANCADO A LA CASA") if _gano else Idioma.t("LA CASA GANA")
	var ancho := Juego.fuente_grande.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 2.0
	var origen := Vector2(320.0 - ancho * 0.5, 46.0)
	var principal := COLOR_ORO if _gano else COLOR_ROJO
	for capa in [[Vector2(2, 2), Color8(143, 35, 64) if _gano else Color8(42, 31, 61)], [Vector2.ZERO, principal]]:
		draw_set_transform(origen + capa[0], 0.0, Vector2(2, 2))
		draw_string(Juego.fuente_grande, Vector2.ZERO, titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, capa[1])
	draw_set_transform(Vector2.ZERO)
	var frase: String
	if _gano:
		frase = Idioma.t("POR ESTA VEZ, LA CASA HA PERDIDO.")
	else:
		frase = (Idioma.t("HAS LLEGADO AL PISO %d EN EL MODO INFINITO.") % Juego.piso) if Juego.infinito else (Idioma.t("HAS CAÍDO EN EL PISO %d DE %d.") % [Juego.piso, Juego.PISOS_TOTALES])
	draw_string(Juego.fuente, Vector2(0, 100), frase, HORIZONTAL_ALIGNMENT_CENTER, 640, 8, COLOR_CREMA)
	if Juego.diario:
		var nota := Idioma.t("RETO DEL %s") % Juego.fecha_reto
		if not Juego.reto_puntuable:
			nota += "  " + Idioma.t("PRÁCTICA: ESTE INTENTO NO PUNTÚA")
		draw_string(Juego.fuente, Vector2(0, 112), nota, HORIZONTAL_ALIGNMENT_CENTER, 640, 8, COLOR_GRIS)


func _dibujar_datos() -> void:
	var x := 150.0
	for i in _datos.size():
		var inicio := _inicio_datos + i * SEG_POR_DATO
		if _t < inicio:
			continue
		var y := 122.0 + i * 13.0
		var dato: Dictionary = _datos[i]
		draw_string(Juego.fuente, Vector2(x, y), Idioma.t(dato.texto), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS)
		var texto: String
		if dato.has("fijo"):
			texto = dato.fijo
		else:
			# El número sube como un contador de tragaperras.
			var avance := clampf((_t - inicio) / (SEG_POR_DATO * 0.85), 0.0, 1.0)
			texto = str(roundi(float(dato.valor) * avance))
		draw_string(Juego.fuente, Vector2(x, y), texto, HORIZONTAL_ALIGNMENT_RIGHT, 220, 8, COLOR_CREMA)


func _dibujar_jugador() -> void:
	var y := 122.0 + (sin(_t * 8.0) * 4.0 if _gano else 0.0)
	var columna := 2 + int(_t * 9.0) % 4 if _gano else int(_t * 2.0) % 2
	draw_texture_rect_region(_tex_jugador, Rect2(430, y, 80, 80), Rect2(columna * 16, 0, 16, 16))


func _dibujar_novedades() -> void:
	draw_string(Juego.fuente, Vector2(0, 222), Idioma.t("DESBLOQUEADO"), HORIZONTAL_ALIGNMENT_CENTER, 640, 8, COLOR_ORO)
	var filas: int = ceili(float(_novedades.size()) / POR_FILA)
	var ultimo := -1
	for i in _novedades.size():
		var inicio := _inicio_novedades + i * SEG_POR_DESBLOQUEO
		if _t < inicio:
			break
		ultimo = i
		var en_fila: int = mini(POR_FILA, _novedades.size() - (i / POR_FILA) * POR_FILA)
		var x0 := 320.0 - en_fila * ANCHO_CASILLA * 0.5 + 2.0
		var p := Vector2(x0 + (i % POR_FILA) * ANCHO_CASILLA, 228.0 + (i / POR_FILA) * 47.0)
		var salto := (1.0 - clampf((_t - inicio) / 0.15, 0.0, 1.0)) * 8.0
		_dibujar_novedad(_novedades[i], p + Vector2(0, -salto))
	if ultimo >= 0:
		var nombre: String = _novedades[ultimo].nombre
		draw_string(Juego.fuente, Vector2(0, 232.0 + filas * 47.0), nombre.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 640, 8, COLOR_CREMA)


func _dibujar_novedad(n: Dictionary, p: Vector2) -> void:
	match String(n.tipo):
		"carta":
			draw_texture(n.tex, p)
		"objeto", "logro":
			draw_texture(_tex_cerrada, p)
			draw_texture(n.tex, p + Vector2(10, 16))
		"personaje":
			draw_texture(_tex_cerrada, p)
			draw_texture_rect_region(n.tex, Rect2(p + Vector2(0, 6), Vector2(32, 32)), Rect2(0, 0, 16, 16))
		"mesa":
			draw_texture(_tex_cerrada, p)
			draw_rect(Rect2(p + Vector2(6, 12), Vector2(20, 20)), COLOR_ORO)
