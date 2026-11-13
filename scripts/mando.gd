class_name Mando
extends RefCounted
## Todo lo del mando (Xbox, PlayStation, Switch, Steam Deck...) en un solo sitio: qué botón
## hace qué, la zona muerta del stick, si lo último que se ha tocado es el mando y la vibración.
## Los eventos de mando se leen a mano, igual que las teclas físicas: no hace falta tocar el
## mapa de entradas del proyecto. Para cambiar un botón basta con tocar las constantes de aquí.
##
## Los botones van por POSICIÓN (numeración de SDL, la que usa Godot): JOY_BUTTON_A es el de
## abajo (A en Xbox, Cruz en PlayStation, B en Switch), JOY_BUTTON_B el de la derecha, etc.

# ------------------------------------------------------------ mapeo de la partida
const VOLTERETA := [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER]
const ORDAGO := [JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER]
const INTERACTUAR := [JOY_BUTTON_Y]  # como la E: volcar mesas y comprar
const PAUSA := [JOY_BUTTON_START]
const CARTAS := [JOY_BUTTON_BACK]  # entra y sale del modo de ordenar la fila de cartas
# Los gatillos también valen: el derecho rueda y el izquierdo lanza el órdago.
const GATILLO_VOLTERETA := JOY_AXIS_TRIGGER_RIGHT
const GATILLO_ORDAGO := JOY_AXIS_TRIGGER_LEFT

# ------------------------------------------------------------ mapeo de los menús
# Cada botón hace de una tecla, y así los menús siguen leyendo "teclas" como siempre.
const TECLAS_MENU := {
	JOY_BUTTON_DPAD_UP: KEY_UP,
	JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
	JOY_BUTTON_DPAD_LEFT: KEY_LEFT,
	JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
	JOY_BUTTON_A: KEY_ENTER,  # aceptar
	JOY_BUTTON_B: KEY_ESCAPE,  # volver
	JOY_BUTTON_X: KEY_X,  # cambiar el modo en la selección de personaje
	JOY_BUTTON_Y: KEY_Y,
	JOY_BUTTON_START: KEY_ENTER,
	JOY_BUTTON_BACK: KEY_ESCAPE,
	JOY_BUTTON_LEFT_SHOULDER: KEY_PAGEUP,  # pestañas
	JOY_BUTTON_RIGHT_SHOULDER: KEY_PAGEDOWN,
}

# ------------------------------------------------------------ sticks
const ZONA_MUERTA := 0.22  # por debajo de esto el stick no cuenta (los sticks gastados derivan)
const UMBRAL_MENU := 0.55  # inclinar el stick más que esto es como pulsar la cruceta
const REARME_MENU := 0.3  # y hay que soltarlo por debajo de esto para volver a "pulsar"
const UMBRAL_GATILLO := 0.5

# ------------------------------------------------------------ vibración
const VIBRAR_GOLPE := [0.35, 0.55, 0.2]  # débil, fuerte, segundos
const VIBRAR_ORDAGO := [0.5, 0.3, 0.25]

## Lo último que se ha tocado es el mando: las ayudas enseñan sus botones.
static var activo := false
static var dispositivo := 0
static var familia := "xbox"  # "xbox", "playstation" o "nintendo": solo cambia los nombres
## Se guarda en ajustes.cfg (lo hace Juego).
static var vibracion := true
## La fila de cartas tiene el mando: el stick no mueve al jugador.
static var bloqueado := false
## En cooperativo, el mando que está ordenando la fila (-1: cualquiera, como en solitario).
static var bloqueado_disp := -1
static var vibraciones := 0  # cuántas se han pedido (lo miran las pruebas)

static var _ejes := {}  # Vector2i(dispositivo, eje) -> valor
static var _botones := {}  # Vector2i(dispositivo, botón) -> true mientras está pulsado
static var _inclinado := {}  # Vector2i(dispositivo, eje) -> -1, 0 o 1 (stick como cruceta, gatillos)
static var _ultimo: InputEvent
static var _resultado := {"tecla": KEY_NONE, "accion": ""}


## Lo llama main con cada evento. Lo demás también pasa por aquí (y no se procesa dos veces).
static func observar(evento: InputEvent) -> void:
	_procesar(evento)


## La tecla de menú que equivale al evento: la propia tecla, o la del botón del mando.
## KEY_NONE si no es nada (o es una tecla soltada o repetida).
static func tecla(evento: InputEvent, admitir_eco := false) -> Key:
	if evento is InputEventKey:
		if not evento.pressed or (evento.echo and not admitir_eco):
			return KEY_NONE
		return evento.keycode
	return _procesar(evento).tecla


## Como tecla(), pero solo para el mando: con el teclado devuelve KEY_NONE.
static func tecla_mando(evento: InputEvent) -> Key:
	if not es_mando(evento):
		return KEY_NONE
	return _procesar(evento).tecla


## La acción de la partida que pide el evento: "voltereta", "ordago", "interactuar", "pausa",
## "cartas" o "" si no es un botón (o gatillo) del mando recién pulsado.
static func accion(evento: InputEvent) -> String:
	if not es_mando(evento):
		return ""
	return _procesar(evento).accion


static func es_mando(evento: InputEvent) -> bool:
	return evento is InputEventJoypadButton or evento is InputEventJoypadMotion


## ¿Está la fila de cartas quitándole el stick a ese mando? En cooperativo, solo al que ordena.
static func bloquea(disp: int) -> bool:
	return bloqueado and (bloqueado_disp < 0 or bloqueado_disp == disp)


## La tecla de menú de los paneles (eventos, elegir carta, qué carta cambiar): la del mando y,
## si "con_teclado" (en cooperativo, donde el J2 del teclado repartido no tiene ratón), también
## la del teclado: flechas o WASD mueven, Intro, E o Fin aceptan y Esc o Retroceso vuelven.
static func tecla_panel(evento: InputEvent, con_teclado: bool) -> Key:
	if es_mando(evento):
		return tecla_mando(evento)
	if not con_teclado or not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return KEY_NONE
	var k: Key = evento.physical_keycode if evento.physical_keycode != KEY_NONE else evento.keycode
	match k:
		KEY_UP, KEY_W: return KEY_UP
		KEY_DOWN, KEY_S: return KEY_DOWN
		KEY_LEFT, KEY_A: return KEY_LEFT
		KEY_RIGHT, KEY_D: return KEY_RIGHT
		KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_END, KEY_DELETE, KEY_KP_0: return KEY_ENTER
		KEY_ESCAPE, KEY_BACKSPACE: return KEY_ESCAPE
	return KEY_NONE


## Hacia dónde empuja el mando: el stick izquierdo (analógico, con zona muerta) o la cruceta.
## Sin decir cuál, el último que se ha tocado; en cooperativo, cada jugador mira el suyo.
static func direccion(disp := -1) -> Vector2:
	if disp < 0:
		disp = dispositivo
	var stick := Vector2(_eje(JOY_AXIS_LEFT_X, disp), _eje(JOY_AXIS_LEFT_Y, disp))
	var largo := stick.length()
	if largo > ZONA_MUERTA:
		# Lo que sobra de la zona muerta se reparte de 0 a 1: sin saltos al salir de ella.
		return stick / largo * clampf((largo - ZONA_MUERTA) / (1.0 - ZONA_MUERTA), 0.0, 1.0)
	var cruceta := Vector2(
		float(_pulsado(JOY_BUTTON_DPAD_RIGHT, disp)) - float(_pulsado(JOY_BUTTON_DPAD_LEFT, disp)),
		float(_pulsado(JOY_BUTTON_DPAD_DOWN, disp)) - float(_pulsado(JOY_BUTTON_DPAD_UP, disp)))
	return cruceta.normalized()


## Una vibración suave, si hay mando en uso y no está desactivada en Opciones.
## Con "disp" vibra ese mando en concreto (cooperativo: el de quien recibe el golpe).
static func vibrar(datos: Array, disp := -1) -> void:
	if not vibracion:
		return
	if disp < 0:
		if not activo:
			return
		disp = dispositivo
	vibraciones += 1
	ultimo_vibrado = disp
	Input.start_joy_vibration(disp, datos[0], datos[1], datos[2])


## Al desconectarse un mando se olvida lo que tenía pulsado (si no, el jugador seguiría andando).
static func olvidar(disp: int) -> void:
	for tabla in [_ejes, _botones, _inclinado]:
		for clave in tabla.keys():
			if clave.x == disp:
				tabla.erase(clave)


## El nombre del botón de una acción, según la marca del mando: "A", "CRUZ", "B"...
## Acciones: aceptar, volver, voltereta, ordago, interactuar, pausa, cartas, pestana_izq, pestana_der.
static func nombre(que: String) -> String:
	var boton: int = {
		"aceptar": JOY_BUTTON_A, "volver": JOY_BUTTON_B, "voltereta": VOLTERETA[0],
		"ordago": ORDAGO[0], "interactuar": INTERACTUAR[0], "pausa": PAUSA[0], "cartas": CARTAS[0],
		"pestana_izq": JOY_BUTTON_LEFT_SHOULDER, "pestana_der": JOY_BUTTON_RIGHT_SHOULDER,
	}.get(que, JOY_BUTTON_A)
	return nombre_boton(boton)


static func nombre_boton(boton: int) -> String:
	var nombres: Dictionary
	match familia:
		"playstation":
			nombres = {JOY_BUTTON_A: "CRUZ", JOY_BUTTON_B: "CÍRCULO", JOY_BUTTON_X: "CUADRADO", JOY_BUTTON_Y: "TRIÁNGULO",
				JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_START: "OPTIONS", JOY_BUTTON_BACK: "SHARE"}
		"nintendo":
			# Mismas posiciones, otras letras: el de abajo en Switch es la B.
			nombres = {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
				JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R", JOY_BUTTON_START: "+", JOY_BUTTON_BACK: "-"}
		_:
			nombres = {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
				JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "START", JOY_BUTTON_BACK: "SELECT"}
	return Idioma.t(String(nombres.get(boton, "?")))


## Por el nombre que da el sistema: Sony y Nintendo cambian los nombres; todo lo demás, Xbox.
static func familia_de(nombre_mando: String) -> String:
	var n := nombre_mando.to_lower()
	for pista in ["playstation", "dualshock", "dualsense", "sony", "ps3", "ps4", "ps5"]:
		if pista in n:
			return "playstation"
	for pista in ["nintendo", "switch", "joy-con", "joycon", "pro controller"]:
		if pista in n:
			return "nintendo"
	return "xbox"


# ------------------------------------------------------------ cooperativo: de quién es cada evento
# Lo que maneja cada jugador ("entrada"): un mando (su número, 0 o más) o un trozo del teclado.
const TODO := -10  # un solo jugador: teclado, ratón, cualquier mando y la pantalla táctil
const TECLADO := -1  # el teclado entero y el ratón
const TECLADO_IZQ := -2  # teclado compartido, J1: WASD, Espacio, Mayús izq., Q, E (y el ratón)
const TECLADO_DER := -3  # teclado compartido, J2: flechas, Ctrl dcho./Intro, Mayús dcha., Fin
## Las teclas de la mitad derecha (J2 con el teclado compartido). Las demás son de la izquierda.
const TECLAS_DERECHA := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_END,
	KEY_DELETE, KEY_KP_0, KEY_BACKSPACE, KEY_5, KEY_KP_5]
const J2_VOLTERETA := [KEY_ENTER, KEY_KP_ENTER]  # y Ctrl derecho
const J2_INTERACTUAR := [KEY_END, KEY_DELETE, KEY_KP_0]
static var ultimo_vibrado := -1  # el mando de la última vibración (lo miran las pruebas)


## La entrada de la que viene un evento: el número del mando, o el trozo de teclado.
static func entrada_de(evento: InputEvent) -> int:
	if es_mando(evento):
		return evento.device
	if evento is InputEventKey:
		var k: Key = evento.physical_keycode if evento.physical_keycode != KEY_NONE else evento.keycode
		if TECLAS_DERECHA.has(k):
			return TECLADO_DER
		if (k == KEY_CTRL or k == KEY_SHIFT) and evento.location == KEY_LOCATION_RIGHT:
			return TECLADO_DER
		return TECLADO_IZQ
	if evento is InputEventMouse:
		return TECLADO_IZQ
	return TODO


## ¿Es este evento de esa entrada?
static func es_de(entrada: int, evento: InputEvent) -> bool:
	match entrada:
		TODO:
			return true
		TECLADO:
			return evento is InputEventKey or evento is InputEventMouse
		TECLADO_IZQ, TECLADO_DER:
			return (evento is InputEventKey or evento is InputEventMouse) and entrada_de(evento) == entrada
	return es_mando(evento) and evento.device == entrada


static func es_teclado(entrada: int) -> bool:
	return entrada == TECLADO or entrada == TECLADO_IZQ or entrada == TECLADO_DER


# ------------------------------------------------------------ por dentro
static func _eje(eje: int, disp := -1) -> float:
	return float(_ejes.get(Vector2i(dispositivo if disp < 0 else disp, eje), 0.0))


static func _pulsado(boton: int, disp := -1) -> bool:
	return _botones.has(Vector2i(dispositivo if disp < 0 else disp, boton))


## Apunta el estado del mando y traduce el evento una sola vez (el mismo evento lo miran
## varios nodos: main, la fila, el jugador, los menús).
static func _procesar(evento: InputEvent) -> Dictionary:
	if evento == _ultimo:
		return _resultado
	_ultimo = evento
	_resultado = {"tecla": KEY_NONE, "accion": ""}
	if evento is InputEventJoypadButton:
		var clave := Vector2i(evento.device, evento.button_index)
		if evento.pressed:
			_botones[clave] = true
			_usar(evento.device)
			_resultado.tecla = TECLAS_MENU.get(evento.button_index, KEY_NONE)
			_resultado.accion = _accion_de_boton(evento.button_index)
		else:
			_botones.erase(clave)
	elif evento is InputEventJoypadMotion:
		_mover_eje(evento)
	elif evento is InputEventKey or evento is InputEventScreenTouch:
		activo = false
	elif evento is InputEventMouseButton and evento.pressed:
		activo = false
	elif evento is InputEventMouseMotion and evento.relative.length() > 2.0:
		activo = false
	return _resultado


static func _accion_de_boton(boton: int) -> String:
	if boton in VOLTERETA:
		return "voltereta"
	if boton in ORDAGO:
		return "ordago"
	if boton in INTERACTUAR:
		return "interactuar"
	if boton in PAUSA:
		return "pausa"
	if boton in CARTAS:
		return "cartas"
	return ""


static func _mover_eje(evento: InputEventJoypadMotion) -> void:
	var clave := Vector2i(evento.device, evento.axis)
	var valor: float = evento.axis_value
	_ejes[clave] = valor
	var antes: int = _inclinado.get(clave, 0)
	if evento.axis == GATILLO_VOLTERETA or evento.axis == GATILLO_ORDAGO:
		# El gatillo cuenta al apretarlo pasado la mitad; para repetir hay que soltarlo.
		if antes == 0 and valor > UMBRAL_GATILLO:
			_inclinado[clave] = 1
			_usar(evento.device)
			_resultado.accion = "voltereta" if evento.axis == GATILLO_VOLTERETA else "ordago"
		elif valor < REARME_MENU:
			_inclinado[clave] = 0
		return
	if absf(valor) > ZONA_MUERTA:
		_usar(evento.device)
	if evento.axis != JOY_AXIS_LEFT_X and evento.axis != JOY_AXIS_LEFT_Y:
		return
	# El stick izquierdo en los menús hace de cruceta: un "pulso" cada vez que se inclina.
	var ahora := 0
	if absf(valor) > UMBRAL_MENU:
		ahora = 1 if valor > 0.0 else -1
	elif absf(valor) > REARME_MENU:
		ahora = antes  # en medio: se queda como estaba
	_inclinado[clave] = ahora
	if ahora != 0 and ahora != antes:
		if evento.axis == JOY_AXIS_LEFT_X:
			_resultado.tecla = KEY_RIGHT if ahora > 0 else KEY_LEFT
		else:
			_resultado.tecla = KEY_DOWN if ahora > 0 else KEY_UP


static func _usar(disp: int) -> void:
	activo = true
	if disp != dispositivo or familia == "xbox":
		familia = familia_de(Input.get_joy_name(disp))
	dispositivo = disp
