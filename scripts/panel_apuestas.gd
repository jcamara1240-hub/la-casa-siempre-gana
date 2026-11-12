class_name PanelApuestas
extends Control
## La tragaperras y la ruleta de la sala de apuestas. Las reglas están en Apuestas: aquí
## se apuesta, se anima y se enseña lo que ha salido. Con ratón (o dedo) se pulsa en los
## botones; con teclado, flechas para elegir y E, Intro o Espacio para pulsar. Esc sale.
## Con mando, la cruceta o el stick eligen (arriba y abajo cambian de fila), A pulsa y B sale.

signal cerrado
signal jugada  # después de cada tirada: main guarda la partida y ya no vale recargar

enum Fase { MENU, GIRANDO }

const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_ROJO := Color8(214, 61, 79)
const COLOR_NEGRO := Color8(20, 16, 30)
const COLOR_VERDE := Color8(47, 138, 107)
const COLOR_GRIS := Color8(120, 110, 120)
const COLOR_FONDO := Color(0.06, 0.05, 0.1, 0.92)
# Tragaperras: cuándo se para cada rodillo, a qué velocidad giran y dónde se dibujan.
const PARADA_RODILLOS := [0.85, 1.25, 1.65]
const VELOCIDAD_RODILLO := 16.0  # símbolos por segundo
const LADO := 32.0  # cada símbolo, a doble tamaño
const MUEBLE := Rect2(232, 50, 176, 142)
const X_RODILLOS := [246.0, 298.0, 350.0]
const VENTANA := Vector2(44, 84)
const Y_VENTANA := 82.0
# Ruleta: la rueda a la izquierda, el tapete a la derecha.
const DURACION_RULETA := 3.2
const CENTRO_RUEDA := Vector2(150, 122)
const RADIO_RUEDA := 64.0
const TAPETE := Vector2(262, 70)  # esquina del tapete de números
const CASILLA := Vector2(28, 16)
const MAX_HISTORIAL := 10

var _maquina := ""
var _sala: Dictionary = {}
var _fase := Fase.MENU
var _texto := ""
var _color_texto := COLOR_CREMA
var _botones: Array = []  # {texto, accion, activo, caja, marcado}
var _sobre := -1
var _reloj := 0.0
var _resultado: Dictionary = {}
var _oro_visto := -1  # mientras gira se enseña lo de antes: el resultado no se adelanta
var _vida_visto := -1
var _vida_max_visto := -1
var _destello := 0.0  # el panel se ilumina un momento con los premios buenos
var _t := 0.0
var _seguro := 0.0  # con el mando, un instante en el que A y B no hacen nada (ver Selector)
# Tragaperras
var _rodillos: Array = ["siete", "siete", "siete"]
var _giro: Array = [0.0, 0.0, 0.0]
var _parado: Array = [true, true, true]
var _rebote: Array = [0.0, 0.0, 0.0]
var _tira: Array = []  # el orden de los símbolos pintados en cada rodillo
# Ruleta
var _ficha := 5  # 0 = todo lo que llevas
var _angulo_rueda := 0.0
var _rueda_inicio := 0.0
var _rueda_vueltas := 0.0
var _bola_vueltas := 0.0
var _bola_casilla := 0
var _ultima_casilla := -1
var _ultimo_tic := 0

var _tex_simbolos: Texture2D = load("res://assets/objetos/simbolos_tragaperras.png")
var _tex_moneda: Texture2D = load("res://assets/objetos/moneda.png")
var _tex_corazon: Texture2D = load("res://assets/objetos/corazon.png")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 304)
	visible = false
	var azar := RandomNumberGenerator.new()
	azar.seed = 4242
	for _i in 3:
		var tira: Array = []
		for _vuelta in 2:
			var simbolos: Array = range(Apuestas.SIMBOLOS.size())
			for i in range(simbolos.size() - 1, 0, -1):
				var j := azar.randi_range(0, i)
				var t = simbolos[i]
				simbolos[i] = simbolos[j]
				simbolos[j] = t
			tira.append_array(simbolos)
		_tira.append(tira)


func abrir(maquina: String, sala: Dictionary) -> void:
	_maquina = maquina
	_sala = sala
	_resultado = {}
	_oro_visto = -1
	_vida_visto = -1
	_vida_max_visto = -1
	_destello = 0.0
	_parado = [true, true, true]
	_ficha = Apuestas.FICHAS[0]
	_seguro = Selector.SEGURO_MANDO
	visible = true
	if _maquina == "tragaperras":
		_texto = Idioma.t("TRES IGUALES EN LA LÍNEA. CADA TIRADA CUESTA MÁS QUE LA ANTERIOR.")
	else:
		_texto = Idioma.t("ELIGE FICHA Y COLOR. AL CERO SE PAGA TREINTA Y SEIS VECES.")
	_color_texto = COLOR_CREMA
	_menu()


func esta_girando() -> bool:
	return _fase == Fase.GIRANDO


func _cerrar() -> void:
	if _fase == Fase.GIRANDO:
		return
	Sonido.tocar("clic")
	visible = false
	cerrado.emit()


func _boton(texto: String, accion: Callable, activo: bool, caja: Rect2, marcado := false) -> void:
	_botones.append({"texto": texto, "accion": accion, "activo": activo, "caja": caja, "marcado": marcado})


func _menu() -> void:
	_fase = Fase.MENU
	_botones.clear()
	if _sala.get("emboscada", false) and not _sala.get("limpia", true):
		_boton(Idioma.t("¡A PELEAR!"), _cerrar, true, Rect2(240, 236, 160, 18))
		_sobre = 0
		return
	if _maquina == "tragaperras":
		var precio := Apuestas.precio_tragaperras(_sala, Juego.piso)
		_boton(Idioma.t("TIRAR DE LA PALANCA (%d)") % precio, _tirar, Juego.oro >= precio, Rect2(220, 222, 200, 18))
		_boton(Idioma.t("MARCHARSE"), _cerrar, true, Rect2(240, 246, 160, 18))
		_sobre = _primer_activo()
	else:
		_menu_ruleta()
		# Con teclado se empieza en "rojo": la ficha ya viene elegida.
		_sobre = 4 if _botones[4].activo else _primer_activo()


func _menu_ruleta() -> void:
	var abierta := Apuestas.mesa_abierta(_sala)
	var corazon := Apuestas.puede_apostar_corazon()
	if _ficha > 0 and Juego.oro < _ficha:
		_ficha = Apuestas.FICHAS[0]
		for f in Apuestas.FICHAS:
			if Juego.oro >= f:
				_ficha = f
	for i in Apuestas.FICHAS.size():
		var f: int = Apuestas.FICHAS[i]
		var se_puede := abierta and Juego.oro >= f
		_boton(Idioma.t("FICHA %d") % f, _elegir_ficha.bind(f), se_puede, Rect2(150 + i * 86, 212, 80, 18), se_puede and _ficha == f)
	var todo := abierta and Juego.oro >= Apuestas.FICHAS[0]
	_boton(Idioma.t("TODO (%d)") % Juego.oro, _elegir_ficha.bind(0), todo, Rect2(150 + 3 * 86, 212, 80, 18), todo and _ficha == 0)
	var cantidad := _cantidad()
	if corazon:
		_boton(Idioma.t("UN CORAZÓN AL ROJO"), _apostar.bind("rojo", true), abierta, Rect2(132, 236, 120, 18))
		_boton(Idioma.t("UN CORAZÓN AL NEGRO"), _apostar.bind("negro", true), abierta, Rect2(260, 236, 120, 18))
	else:
		var puede := abierta and cantidad > 0 and Juego.oro >= cantidad
		_boton(Idioma.t("ROJO (x2)"), _apostar.bind("rojo", false), puede, Rect2(132, 236, 120, 18))
		_boton(Idioma.t("NEGRO (x2)"), _apostar.bind("negro", false), puede, Rect2(260, 236, 120, 18))
	_boton(Idioma.t("CERO: %d PAGA x%d") % [Apuestas.APUESTA_CERO, Apuestas.PAGO_CERO], _apostar.bind("cero", false),
			abierta and Juego.oro >= Apuestas.APUESTA_CERO, Rect2(388, 236, 120, 18))
	_boton(Idioma.t("MARCHARSE"), _cerrar, true, Rect2(240, 260, 160, 18))


func _cantidad() -> int:
	return Juego.oro if _ficha == 0 else _ficha


func _primer_activo() -> int:
	for i in _botones.size():
		if _botones[i].activo:
			return i
	return -1


## Lo que se enseña mientras gira: lo de antes de cobrar el premio (lo pagado sí se ve).
func _congelar(oro_antes: int, vida_antes: int, vida_max_antes: int, pagado: int) -> void:
	_oro_visto = oro_antes - pagado
	_vida_visto = vida_antes
	_vida_max_visto = vida_max_antes


func _oro() -> int:
	return Juego.oro if _oro_visto < 0 else _oro_visto


# ---------------------------------------------------------------- tragaperras
func _tirar() -> void:
	var oro_antes: int = Juego.oro
	var vida_antes: int = Juego.vida
	var vida_max_antes: int = Juego.vida_max
	var r := Apuestas.tirar_tragaperras(_sala)
	if not r.get("ok", false):
		return
	_congelar(oro_antes, vida_antes, vida_max_antes, int(r.precio))
	_resultado = r
	_fase = Fase.GIRANDO
	_botones.clear()
	_sobre = -1
	_texto = ""
	_reloj = 0.0
	for i in 3:
		_parado[i] = false
		_rebote[i] = 0.0
	Sonido.tocar("comprar")
	Sonido.tocar("mezclar")
	jugada.emit()


func _parar_rodillo(i: int) -> void:
	_parado[i] = true
	_rodillos[i] = _resultado.rodillos[i]
	_rebote[i] = 0.18
	Sonido.tocar("rodillo", 1.0 + i * 0.06)


func _revelar() -> void:
	_oro_visto = -1
	_vida_visto = -1
	_vida_max_visto = -1
	_texto = String(_resultado.get("texto", ""))
	var bueno: bool = _resultado.get("bueno", false)
	var id := String(_resultado.get("id", ""))
	_color_texto = COLOR_ORO if bueno else (COLOR_ROJO if Apuestas.MALOS.has(id) and not _resultado.get("salvado", false) else COLOR_CREMA)
	if id == "777" or (_maquina == "ruleta" and _resultado.get("apuesta", "") == "cero" and _resultado.get("gana", false)):
		Sonido.tocar("premio_gordo")
		_destello = 1.0
	elif bueno or _resultado.get("gana", false):
		Sonido.tocar("ganar")
		_destello = 0.5
	elif id == "nada" or _resultado.get("salvado", false):
		Sonido.tocar("clic")
	else:
		Sonido.tocar("perder")
	if _resultado.has("objeto"):
		Sonido.tocar("objeto")
	# Si vienes aporreando A para acabar la animación, no vuelves a tirar sin ver el premio.
	_seguro = Selector.SEGURO_MANDO
	_menu()


# ---------------------------------------------------------------- ruleta
func _elegir_ficha(f: int) -> void:
	Sonido.tocar("clic")
	_ficha = f
	var antes := _sobre
	_menu()
	_sobre = antes


func _apostar(apuesta: String, con_corazon: bool) -> void:
	var oro_antes: int = Juego.oro
	var vida_antes: int = Juego.vida
	var vida_max_antes: int = Juego.vida_max
	var r := Apuestas.jugar_ruleta(_sala, apuesta, _cantidad(), con_corazon)
	if not r.get("ok", false):
		return
	_congelar(oro_antes, vida_antes, vida_max_antes, int(r.cantidad))
	_resultado = r
	var historial: Array = _sala.get("historial_ruleta", [])
	historial.push_front(int(r.numero))
	_sala["historial_ruleta"] = historial.slice(0, MAX_HISTORIAL)
	_fase = Fase.GIRANDO
	_botones.clear()
	_sobre = -1
	_texto = Idioma.t("NO VA MÁS.")
	_color_texto = COLOR_CREMA
	_reloj = 0.0
	_rueda_inicio = _angulo_rueda
	_rueda_vueltas = TAU * (1.2 + randf() * 0.4)
	_bola_vueltas = TAU * 4.0
	_bola_casilla = Apuestas.RUEDA.find(int(r.numero))
	_ultima_casilla = -1
	Sonido.tocar("comprar")
	jugada.emit()


## Ángulo de una casilla de la rueda (sin girar).
static func _angulo_casilla(i: int) -> float:
	return TAU * float(i) / Apuestas.RUEDA.size() - PI * 0.5


func _avance_ruleta() -> float:
	var u := clampf(_reloj / DURACION_RULETA, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


func _angulo_bola() -> float:
	var k := _avance_ruleta()
	# La bola gira al revés que la rueda y frena hasta caer en su casilla.
	return _angulo_rueda + _angulo_casilla(_bola_casilla) + (1.0 - k) * _bola_vueltas


func _radio_bola() -> float:
	var k := _avance_ruleta()
	var caida := clampf((k - 0.7) / 0.3, 0.0, 1.0)
	return lerpf(RADIO_RUEDA - 6.0, RADIO_RUEDA - 17.0, caida) + (sin(_reloj * 40.0) * 1.5 if caida > 0.0 and caida < 1.0 else 0.0)


# ---------------------------------------------------------------- tiempo y entrada
func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_seguro = maxf(_seguro - delta, 0.0)
	_destello = maxf(_destello - delta * 1.5, 0.0)
	for i in 3:
		_rebote[i] = maxf(_rebote[i] - delta, 0.0)
	queue_redraw()
	if _fase != Fase.GIRANDO:
		return
	_reloj += delta
	if _maquina == "tragaperras":
		for i in 3:
			if not _parado[i]:
				_giro[i] += VELOCIDAD_RODILLO * delta
				if _reloj >= PARADA_RODILLOS[i]:
					_parar_rodillo(i)
		if _parado.all(func(p): return p):
			_revelar()
		return
	_angulo_rueda = _rueda_inicio - _rueda_vueltas * _avance_ruleta()
	var relativo := fposmod(_angulo_bola() - _angulo_rueda + PI * 0.5, TAU)
	var casilla := int(relativo / TAU * Apuestas.RUEDA.size())
	if casilla != _ultima_casilla:
		_ultima_casilla = casilla
		if Time.get_ticks_msec() - _ultimo_tic > 45:
			_ultimo_tic = Time.get_ticks_msec()
			Sonido.tocar("bola", randf_range(0.9, 1.15))
	if _reloj >= DURACION_RULETA:
		_rueda_inicio = _angulo_rueda
		_revelar()


## Para las pruebas y las capturas: acaba la animación de golpe.
func saltar_animacion() -> void:
	if _fase != Fase.GIRANDO:
		return
	if _maquina == "tragaperras":
		for i in 3:
			if not _parado[i]:
				_parar_rodillo(i)
	else:
		_reloj = DURACION_RULETA
		_angulo_rueda = _rueda_inicio - _rueda_vueltas
		_rueda_inicio = _angulo_rueda
	_revelar()


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		var b := _boton_en(evento.position)
		if b != -1:
			_sobre = b
	elif evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var b := _boton_en(evento.position)
		if b != -1:
			_pulsar(b)
		elif _fase == Fase.GIRANDO:
			saltar_animacion()  # con prisa: un clic fuera de los botones la acaba
		accept_event()


func _unhandled_input(evento: InputEvent) -> void:
	if visible and Mando.es_mando(evento):
		var tecla := Mando.tecla_mando(evento)
		if tecla != KEY_NONE:
			get_viewport().set_input_as_handled()
			_entrada_mando(tecla)
		return
	if not visible or not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	get_viewport().set_input_as_handled()
	match evento.physical_keycode:
		KEY_ESCAPE:
			if _fase == Fase.GIRANDO:
				saltar_animacion()
			else:
				_cerrar()
		KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _fase == Fase.GIRANDO:
				saltar_animacion()
			elif _sobre != -1:
				_pulsar(_sobre)
		KEY_LEFT, KEY_UP, KEY_A, KEY_W:
			_mover_seleccion(-1)
		KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S, KEY_TAB:
			_mover_seleccion(1)


## Con el mando: la cruceta o el stick recorren los botones que se pueden pulsar (arriba y
## abajo saltan de fila: fichas, apuestas, marcharse), A pulsa y B se marcha. Mientras gira,
## A o B acaban la animación. Al abrir y al ver un premio, A y B esperan un instante.
func _entrada_mando(tecla: Key) -> void:
	if _fase == Fase.GIRANDO:
		if tecla == KEY_ENTER or tecla == KEY_ESCAPE:
			saltar_animacion()
		return
	match tecla:
		KEY_LEFT: _mover_mando(Vector2.LEFT)
		KEY_RIGHT: _mover_mando(Vector2.RIGHT)
		KEY_UP: _mover_mando(Vector2.UP)
		KEY_DOWN: _mover_mando(Vector2.DOWN)
		KEY_ENTER:
			if _seguro > 0.0:
				return
			if _sobre == -1 or not _botones[_sobre].activo:
				_sobre = _primer_activo()
			else:
				_pulsar(_sobre)
		KEY_ESCAPE:
			if _seguro > 0.0:
				return
			_cerrar()


## El botón activo más cercano hacia ese lado (por filas); si no hay ninguno, el siguiente
## en orden, como con el teclado.
func _mover_mando(hacia: Vector2) -> void:
	if _sobre == -1 or _sobre >= _botones.size():
		_sobre = _primer_activo()
		return
	var desde: Vector2 = _botones[_sobre].caja.get_center()
	var mejor := -1
	var mejor_d := INF
	for i in _botones.size():
		if i == _sobre or not _botones[i].activo:
			continue
		var d: Vector2 = _botones[i].caja.get_center() - desde
		var avance := d.dot(hacia)
		var lado := absf(d.dot(hacia.orthogonal()))
		if avance <= 2.0 or (hacia.x != 0.0 and lado > 4.0):
			continue  # a izquierda y derecha, solo en la misma fila
		var dist := avance + lado * 0.5
		if dist < mejor_d:
			mejor_d = dist
			mejor = i
	if mejor == -1:
		_mover_seleccion(1 if hacia.x + hacia.y > 0.0 else -1)
		return
	_sobre = mejor
	Sonido.tocar("mover")


func _mover_seleccion(paso: int) -> void:
	var n := _botones.size()
	if n == 0:
		return
	var i := _sobre
	for _k in n:
		i = posmod(i + paso, n)
		if _botones[i].activo:
			_sobre = i
			Sonido.tocar("mover")
			return


func _pulsar(i: int) -> void:
	if i < 0 or i >= _botones.size() or not _botones[i].activo:
		return
	_botones[i].accion.call()


func _boton_en(p: Vector2) -> int:
	for i in _botones.size():
		if _botones[i].caja.has_point(p):
			return i
	return -1


## Pulsa el botón con ese texto (o que empiece así). Lo usan las pruebas.
func pulsar_texto(inicio: String) -> bool:
	for i in _botones.size():
		if String(_botones[i].texto).begins_with(inicio) and _botones[i].activo:
			_pulsar(i)
			return true
	return false


# ---------------------------------------------------------------- dibujo
func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 304), COLOR_FONDO)
	if _destello > 0.0:
		draw_rect(Rect2(0, 0, 640, 304), Color(COLOR_ORO, 0.18 * _destello))
	var titulo := Idioma.t("LA TRAGAPERRAS") if _maquina == "tragaperras" else Idioma.t("LA RULETA")
	draw_string(Juego.fuente_grande, Vector2(0, 26), titulo, HORIZONTAL_ALIGNMENT_CENTER, 640, 16, COLOR_ORO)
	_dibujar_bolsa()
	if _maquina == "tragaperras":
		_dibujar_tragaperras()
	else:
		_dibujar_ruleta()
	draw_multiline_string(Juego.fuente, Vector2(40, 204), _texto, HORIZONTAL_ALIGNMENT_CENTER, 560, 8, 2, _color_texto)
	for i in _botones.size():
		var b: Dictionary = _botones[i]
		var caja: Rect2 = b.caja
		var activo: bool = b.activo
		var color := Color8(42, 31, 61)
		if b.marcado:
			color = Color8(122, 90, 40)
		if i == _sobre and activo:
			color = Color8(122, 90, 160)
		draw_rect(caja, color)
		draw_rect(caja, COLOR_ORO if b.marcado else Color8(74, 52, 102), false, 1.0)
		draw_string(Juego.fuente, caja.position + Vector2(0, 12), b.texto, HORIZONTAL_ALIGNMENT_CENTER,
				caja.size.x, 8, COLOR_CREMA if activo else COLOR_GRIS)


## Monedas y corazones, debajo del título.
func _dibujar_bolsa() -> void:
	var texto := str(_oro())
	var ancho := Juego.fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var vida_max: int = Juego.vida_max if _vida_max_visto < 0 else _vida_max_visto
	var vida: int = Juego.vida if _vida_visto < 0 else _vida_visto
	var corazones := vida_max / 2
	var total := 10.0 + ancho + 10.0 + corazones * 10.0
	var x := roundf(320.0 - total * 0.5)
	draw_texture_rect_region(_tex_moneda, Rect2(x, 33, 8, 8), Rect2(0, 0, 8, 8))
	draw_string(Juego.fuente, Vector2(x + 11, 41), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO)
	x += 10.0 + ancho + 10.0
	for i in corazones:
		var puntos := vida - i * 2
		var columna := 0 if puntos >= 2 else (1 if puntos == 1 else 2)
		draw_texture_rect_region(_tex_corazon, Rect2(x + i * 10, 34, 9, 7), Rect2(columna * 9, 0, 9, 7))


func _simbolo(nombre: String, destino: Rect2, tinte := Color.WHITE) -> void:
	var i := Apuestas.SIMBOLOS.find(nombre)
	draw_texture_rect_region(_tex_simbolos, destino, Rect2(i * 16, 0, 16, 16), tinte)


## Un símbolo del rodillo recortado a la ventana (a doble tamaño).
func _simbolo_recortado(indice: int, y: float, ventana: Rect2) -> void:
	var destino := Rect2(ventana.position.x + (ventana.size.x - LADO) * 0.5, y, LADO, LADO)
	var visible_r := destino.intersection(ventana)
	if visible_r.size.y <= 0.0:
		return
	var origen := Rect2(indice * 16, (visible_r.position.y - destino.position.y) * 0.5, 16, visible_r.size.y * 0.5)
	draw_texture_rect_region(_tex_simbolos, visible_r, origen)


func _dibujar_tragaperras() -> void:
	# El mueble: marquesina con bombillas, tres ventanas y la palanca.
	draw_rect(MUEBLE.grow(3.0), Color8(143, 35, 64))
	draw_rect(MUEBLE, COLOR_ROJO.darkened(0.15))
	draw_rect(Rect2(MUEBLE.position, Vector2(MUEBLE.size.x, 24)), COLOR_ORO.darkened(0.2))
	draw_string(Juego.fuente_grande, MUEBLE.position + Vector2(0, 18), "7 7 7", HORIZONTAL_ALIGNMENT_CENTER, MUEBLE.size.x, 16, COLOR_ROJO)
	var girando := _fase == Fase.GIRANDO
	for k in 12:
		var encendida := (int(_t * (12.0 if girando else 3.0)) + k) % 3 == 0
		var p := MUEBLE.position + Vector2(8 + k * 14.5, 3)
		draw_rect(Rect2(p, Vector2(3, 3)), COLOR_CREMA if encendida else Color8(240, 129, 60))
	for i in 3:
		var ventana := Rect2(X_RODILLOS[i], Y_VENTANA, VENTANA.x, VENTANA.y)
		draw_rect(ventana.grow(2.0), COLOR_NEGRO)
		draw_rect(ventana, COLOR_CREMA)
		var centro_y := ventana.get_center().y - LADO * 0.5
		if _parado[i]:
			var tira: Array = _tira[i]
			var actual := Apuestas.SIMBOLOS.find(_rodillos[i])
			var j := tira.find(actual)
			var bote := sin(_rebote[i] / 0.18 * PI) * 5.0 if _rebote[i] > 0.0 else 0.0
			for k in [-1, 0, 1]:
				var indice: int = actual if k == 0 else tira[posmod(j + k, tira.size())]
				_simbolo_recortado(indice, centro_y + k * (LADO + 4.0) + bote, ventana)
		else:
			var tira: Array = _tira[i]
			var base := int(floor(_giro[i]))
			var resto: float = _giro[i] - base
			for k in [-2, -1, 0, 1]:
				var indice: int = tira[posmod(base - k, tira.size())]
				_simbolo_recortado(indice, centro_y + (k + resto) * (LADO + 4.0), ventana)
		# Sombra arriba y abajo: parece un tambor.
		draw_rect(Rect2(ventana.position, Vector2(ventana.size.x, 10)), Color(0, 0, 0, 0.28))
		draw_rect(Rect2(ventana.position.x, ventana.end.y - 10, ventana.size.x, 10), Color(0, 0, 0, 0.28))
	var linea_y := Y_VENTANA + VENTANA.y * 0.5
	draw_rect(Rect2(MUEBLE.position.x + 6, linea_y, MUEBLE.size.x - 12, 1), Color(COLOR_ROJO, 0.7))
	draw_rect(Rect2(MUEBLE.position.x + 30, MUEBLE.end.y - 18, MUEBLE.size.x - 60, 8), COLOR_NEGRO)
	# La palanca baja al tirar y vuelve sola.
	var tiron := clampf(1.0 - _reloj / 0.35, 0.0, 1.0) if girando else 0.0
	var arriba := MUEBLE.position + Vector2(MUEBLE.size.x + 10, 50)
	var bola := arriba + Vector2(0, -30 + 52 * tiron)
	draw_rect(Rect2(arriba.x - 2, arriba.y - 2, 6, 12), Color8(168, 154, 142))
	draw_line(arriba + Vector2(1, 4), bola, Color8(168, 154, 142), 2.0)
	draw_circle(bola, 5.0, COLOR_ROJO)
	draw_circle(bola + Vector2(-1.5, -1.5), 1.5, COLOR_CREMA)
	_dibujar_premios()


## La tabla de premios: los buenos a la izquierda, los malos a la derecha.
func _dibujar_premios() -> void:
	var precio := Apuestas.precio_tragaperras(_sala, Juego.piso)
	var buenos := [["siete", 3, Idioma.t("x10 Y UN OBJETO")], ["moneda", 3, Idioma.t("x3 LO PUESTO")],
		["moneda", 2, Idioma.t("RECUPERAS LO PUESTO")], ["corazon", 3, Idioma.t("UN CORAZÓN")], ["carta", 3, Idioma.t("UNA CARTA")],
		["diamante", 3, Idioma.t("UN OBJETO")], ["ordago", 3, Idioma.t("UN ÓRDAGO")]]
	var malos := [["calavera", 3, Idioma.t("PIERDES UN CORAZÓN")], ["gato", 3, Idioma.t("TE MALDICE UNA CARTA")],
		["pistola", 3, Idioma.t("EMBOSCADA")], ["antifaz", 3, Idioma.t("TE ROBAN %d") % (precio * 2)]]
	draw_string(Juego.fuente, Vector2(16, 58), Idioma.t("PREMIOS"), HORIZONTAL_ALIGNMENT_CENTER, 200, 8, COLOR_ORO)
	draw_string(Juego.fuente, Vector2(424, 58), Idioma.t("CASTIGOS"), HORIZONTAL_ALIGNMENT_CENTER, 200, 8, COLOR_ROJO)
	for i in buenos.size():
		_fila_premio(Vector2(18, 64 + i * 18), buenos[i], COLOR_CREMA)
	for i in malos.size():
		_fila_premio(Vector2(430, 64 + i * 18), malos[i], COLOR_CREMA)
	var suerte := Apuestas.prob_salvar(Juego.stat("suerte"))
	if suerte > 0.0:
		draw_multiline_string(Juego.fuente, Vector2(430, 150), Idioma.t("TU SUERTE ESQUIVA UN %d%% DE LOS CASTIGOS.") % roundi(suerte * 100.0),
				HORIZONTAL_ALIGNMENT_LEFT, 190, 8, 2, Color8(108, 207, 148))
	draw_string(Juego.fuente, Vector2(430, 186), Idioma.t("TIRADAS: %d") % Apuestas.tiradas(_sala, "tragaperras"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS)


func _fila_premio(p: Vector2, fila: Array, color: Color) -> void:
	for k in 3:
		var nombre: String = fila[0] if k < int(fila[1]) else ""
		var caja := Rect2(p + Vector2(k * 17, 0), Vector2(16, 16))
		draw_rect(caja, Color8(42, 31, 61))
		if nombre != "":
			_simbolo(nombre, caja)
		else:
			draw_string(Juego.fuente, caja.position + Vector2(0, 12), "?", HORIZONTAL_ALIGNMENT_CENTER, 16, 8, COLOR_GRIS)
	draw_string(Juego.fuente, p + Vector2(56, 12), fila[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)


func _color_numero(n: int) -> Color:
	match Apuestas.color_de(n):
		"cero": return COLOR_VERDE
		"rojo": return COLOR_ROJO
	return COLOR_NEGRO


func _dibujar_ruleta() -> void:
	var c := CENTRO_RUEDA
	var n := Apuestas.RUEDA.size()
	draw_circle(c, RADIO_RUEDA + 6.0, Color8(84, 44, 34))
	draw_circle(c, RADIO_RUEDA + 3.0, Color8(240, 129, 60).darkened(0.35))
	draw_circle(c, RADIO_RUEDA, Color8(42, 31, 61))
	var paso := TAU / n
	for i in n:
		var a0 := _angulo_rueda + _angulo_casilla(i) - paso * 0.5
		var puntos := PackedVector2Array()
		for k in 4:
			puntos.append(c + Vector2.RIGHT.rotated(a0 + paso * k / 3.0) * (RADIO_RUEDA - 12.0))
		for k in 4:
			puntos.append(c + Vector2.RIGHT.rotated(a0 + paso * (3 - k) / 3.0) * (RADIO_RUEDA - 26.0))
		draw_colored_polygon(puntos, _color_numero(Apuestas.RUEDA[i]))
		draw_line(c + Vector2.RIGHT.rotated(a0) * (RADIO_RUEDA - 26.0), c + Vector2.RIGHT.rotated(a0) * (RADIO_RUEDA - 12.0), COLOR_ORO.darkened(0.3), 1.0)
	draw_arc(c, RADIO_RUEDA - 12.0, 0.0, TAU, 64, COLOR_ORO.darkened(0.3), 1.0)
	draw_circle(c, RADIO_RUEDA - 26.0, Color8(84, 44, 34))
	draw_circle(c, RADIO_RUEDA - 32.0, Color8(31, 92, 80))
	for k in 4:
		var a := _angulo_rueda * 1.0 + k * PI * 0.5
		draw_line(c, c + Vector2.RIGHT.rotated(a) * (RADIO_RUEDA - 30.0), COLOR_ORO, 2.0)
	draw_circle(c, 5.0, COLOR_ORO)
	var hay_bola := _fase == Fase.GIRANDO or not _resultado.is_empty()
	if hay_bola:
		var a := _angulo_bola() if _fase == Fase.GIRANDO else _angulo_rueda + _angulo_casilla(_bola_casilla)
		var r := _radio_bola() if _fase == Fase.GIRANDO else RADIO_RUEDA - 17.0
		var bola := c + Vector2.RIGHT.rotated(a) * r
		draw_circle(bola + Vector2(1, 1), 3.0, Color(0, 0, 0, 0.4))
		draw_circle(bola, 3.0, COLOR_CREMA)
	if _fase == Fase.MENU and not _resultado.is_empty():
		var numero := int(_resultado.numero)
		draw_circle(c, 15.0, _color_numero(numero))
		draw_arc(c, 15.0, 0.0, TAU, 32, COLOR_ORO, 1.5)
		draw_string(Juego.fuente_grande, c + Vector2(-20, 6), str(numero), HORIZONTAL_ALIGNMENT_CENTER, 40, 16, COLOR_CREMA)
	_dibujar_tapete()


## El tapete de números, el historial y cuántas tiradas quedan.
func _dibujar_tapete() -> void:
	var ganador := -1
	if _fase == Fase.MENU and not _resultado.is_empty():
		ganador = int(_resultado.numero)
	var cero := Rect2(TAPETE, Vector2(CASILLA.x, CASILLA.y * 3))
	draw_rect(cero.grow(2.0), Color8(31, 92, 80).darkened(0.3))
	_casilla_tapete(cero, 0, ganador)
	for col in 12:
		for fila in 3:
			var numero := col * 3 + (3 - fila)
			var caja := Rect2(TAPETE + Vector2(CASILLA.x * (col + 1), CASILLA.y * fila), CASILLA)
			_casilla_tapete(caja, numero, ganador)
	var fondo := Rect2(TAPETE + Vector2(0, CASILLA.y * 3 + 4), Vector2(CASILLA.x * 13, 18))
	var mitad := fondo.size.x * 0.5
	draw_rect(Rect2(fondo.position, Vector2(mitad - 1, fondo.size.y)), COLOR_ROJO.darkened(0.2))
	draw_rect(Rect2(fondo.position + Vector2(mitad + 1, 0), Vector2(mitad - 1, fondo.size.y)), COLOR_NEGRO)
	draw_rect(fondo, COLOR_ORO.darkened(0.3), false, 1.0)
	draw_string(Juego.fuente, fondo.position + Vector2(0, 12), Idioma.t("ROJO"), HORIZONTAL_ALIGNMENT_CENTER, mitad, 8, COLOR_CREMA)
	draw_string(Juego.fuente, fondo.position + Vector2(mitad, 12), Idioma.t("NEGRO"), HORIZONTAL_ALIGNMENT_CENTER, mitad, 8, COLOR_CREMA)
	# Lo último que ha salido, de izquierda (lo más reciente) a derecha.
	var historial: Array = _sala.get("historial_ruleta", [])
	var desde := 0 if _fase == Fase.MENU else 1  # mientras gira no se enseña lo que va a salir
	var y := fondo.end.y + 22
	draw_string(Juego.fuente, Vector2(TAPETE.x, y - 4), Idioma.t("ÚLTIMOS:"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS)
	for i in range(desde, historial.size()):
		var p := Vector2(TAPETE.x + 64 + (i - desde) * 22, y - 8)
		var numero := int(historial[i])
		draw_circle(p, 9.0, _color_numero(numero))
		draw_string(Juego.fuente, p + Vector2(-10, 4), str(numero), HORIZONTAL_ALIGNMENT_CENTER, 20, 8, COLOR_CREMA)
	var quedan := Apuestas.TIRADAS_RULETA - Apuestas.tiradas(_sala, "ruleta")
	var aviso := Idioma.t("EL CRUPIER HA CERRADO LA MESA.") if quedan <= 0 else Idioma.t("QUEDAN %d TIRADAS EN ESTA MESA.") % quedan
	draw_string(Juego.fuente, Vector2(TAPETE.x, y + 20), aviso, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS if quedan > 0 else COLOR_ROJO)


func _casilla_tapete(caja: Rect2, numero: int, ganador: int) -> void:
	var color := _color_numero(numero)
	if numero == ganador:
		color = color.lightened(0.35 + 0.25 * sin(_t * 10.0))
	draw_rect(caja, color)
	draw_rect(caja, COLOR_ORO.darkened(0.3) if numero != ganador else COLOR_ORO, false, 1.0)
	draw_string(Juego.fuente, caja.position + Vector2(0, caja.size.y * 0.5 + 4), str(numero), HORIZONTAL_ALIGNMENT_CENTER, caja.size.x, 8, COLOR_CREMA)
