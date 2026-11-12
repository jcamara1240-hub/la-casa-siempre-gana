class_name PanelEvento
extends Control
## Las salas de evento: trileros, doble o nada, prestamista y barra.

signal cerrado(carta: String)

enum Fase { MENU, ENSENAR, MEZCLA, ELEGIR, RESULTADO, LANZANDO, FIN }

const TIPOS := ["trileros", "doble_nada", "prestamista", "barra", "mendigo", "caja_fuerte"]
const APUESTAS := [5, 10, 20]
const PAGO_TRILEROS := 2.5
const RONDAS_TRILEROS := 3
const PROB_DOBLAR := 0.47
const MAX_DOBLES := 5
const X_COPAS := [220.0, 320.0, 420.0]
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)

var _tipo := ""
var _fase := Fase.MENU
var _texto := ""
var _botones: Array = []
var _sobre := -1
var _reloj := 0.0
var _rondas := 0
var _apuesta := 0
var _pote := 0
var _dobles := 0
var _usos := 0
var _carta := ""
var _copas := [0.0, 1.0, 2.0]  # en qué hueco está cada copa
var _bola := 1
var _revelar := -1
var _mezclas := 0
var _ritmo := 0.3
var _a := 0
var _b := 1
## El azar de los juegos de la sala. Sale de la semilla de la sala: en el reto diario la misma
## jugada da el mismo resultado a todo el mundo (y recargar la partida no cambia la suerte).
var _azar := RandomNumberGenerator.new()
var _tex_copa: Texture2D = load("res://assets/objetos/copa_trile.png")
var _tex_moneda: Texture2D = load("res://assets/objetos/moneda.png")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 304)
	visible = false


func abrir(tipo: String, azar: RandomNumberGenerator = null) -> void:
	_tipo = tipo
	if azar != null:
		_azar = azar
	else:
		_azar.randomize()
	_carta = ""
	_rondas = 0
	_usos = 0
	_pote = 0
	_dobles = 0
	_revelar = -1
	_copas = [0.0, 1.0, 2.0]
	visible = true
	_menu_inicial()


func _boton(texto: String, accion: Callable, activo := true) -> void:
	_botones.append({"texto": texto, "accion": accion, "activo": activo})


func _salir() -> void:
	_boton(Idioma.t("MARCHARSE"), _cerrar)


func _cerrar() -> void:
	Sonido.tocar("clic")
	visible = false
	cerrado.emit(_carta)


func _ir_a(fase: Fase, texto: String) -> void:
	_fase = fase
	_texto = texto
	_botones.clear()
	_sobre = -1


func _titulo() -> String:
	match _tipo:
		"trileros": return Idioma.t("LOS TRILEROS")
		"doble_nada": return Idioma.t("DOBLE O NADA")
		"prestamista": return Idioma.t("EL PRESTAMISTA")
		"mendigo": return Idioma.t("EL MENDIGO")
		"caja_fuerte": return Idioma.t("LA CAJA FUERTE")
	return Idioma.t("LA BARRA")


func _menu_inicial() -> void:
	match _tipo:
		"trileros":
			_ir_a(Fase.MENU, Idioma.t("SIGUE LA MONEDA. SI ACIERTAS, COBRAS DOS VECES Y MEDIA."))
			_botones_apuesta(_apostar_trileros)
		"doble_nada":
			_ir_a(Fase.MENU, Idioma.t("PON TUS MONEDAS Y VE DOBLANDO. SI FALLAS, LO PIERDES TODO."))
			_botones_apuesta(_apostar_doble)
		"prestamista":
			_menu_prestamista()
		"barra":
			_menu_barra()
		"mendigo":
			_ir_a(Fase.MENU, Idioma.t("UNA AYUDITA, QUE SE LO DEVUELVO EN LA PRÓXIMA MANO."))
			_boton(Idioma.t("DAR 10 MONEDAS"), _dar_mendigo, Juego.oro >= 10)
			_salir()
		"caja_fuerte":
			_ir_a(Fase.MENU, Idioma.t("TRES CAJAS Y UNA SOLA LLAVE. NO TODAS TRAEN COSAS BUENAS."))
			for letra in ["A", "B", "C"]:
				_boton(Idioma.t("ABRIR LA CAJA %s") % letra, _abrir_caja)
			_salir()


func _botones_apuesta(accion: Callable) -> void:
	for cantidad in APUESTAS:
		_boton(Idioma.t("APOSTAR %d") % cantidad, accion.bind(cantidad), Juego.oro >= cantidad)
	_salir()


# ---------------------------------------------------------------- trileros
func _apostar_trileros(cantidad: int) -> void:
	Juego.gastar_oro(cantidad)
	Sonido.tocar("clic")
	_apuesta = cantidad
	_bola = _azar.randi() % 3
	_revelar = _bola
	_ir_a(Fase.ENSENAR, Idioma.t("MIRA BIEN..."))
	_reloj = 0.9


func _empezar_mezcla() -> void:
	_revelar = -1
	_mezclas = 6 + _rondas * 3
	_ritmo = 0.3 - _rondas * 0.06
	_ir_a(Fase.MEZCLA, Idioma.t("MEZCLANDO..."))
	_siguiente_cruce()


func _siguiente_cruce() -> void:
	_mezclas -= 1
	_reloj = _ritmo
	_a = _azar.randi() % 3
	_b = (_a + 1 + _azar.randi() % 2) % 3
	Sonido.tocar("mezclar")


func _terminar_cruce() -> void:
	var t: float = _copas[_a]
	_copas[_a] = _copas[_b]
	_copas[_b] = t


func _elegir(copa: int) -> void:
	_revelar = copa
	_rondas += 1
	var acierto := copa == _bola
	if acierto:
		var premio := floori(_apuesta * PAGO_TRILEROS)
		Juego.ganar_oro(premio)
		Juego.marcar_logro("trilero")
		Sonido.tocar("ganar")
		_ir_a(Fase.RESULTADO, Idioma.t("¡BIEN VISTO! COBRAS %d.") % premio)
	else:
		Sonido.tocar("perder")
		_ir_a(Fase.RESULTADO, Idioma.t("LA CASA SIEMPRE GANA."))
	if _rondas < RONDAS_TRILEROS:
		_boton(Idioma.t("OTRA RONDA"), _otra_ronda)
	_salir()


func _otra_ronda() -> void:
	_revelar = -1
	_menu_inicial()


# ---------------------------------------------------------------- doble o nada
func _apostar_doble(cantidad: int) -> void:
	Juego.gastar_oro(cantidad)
	Sonido.tocar("clic")
	_pote = cantidad
	_menu_doble(Idioma.t("EN JUEGO: %d") % _pote)


func _menu_doble(texto: String) -> void:
	_ir_a(Fase.MENU, texto)
	_boton(Idioma.t("DOBLAR"), _lanzar, _dobles < MAX_DOBLES)
	_boton(Idioma.t("COBRAR %d") % _pote, _cobrar)


func _lanzar() -> void:
	Sonido.tocar("mezclar")
	_ir_a(Fase.LANZANDO, Idioma.t("LA MONEDA ESTÁ EN EL AIRE..."))
	_reloj = 0.8


func _resolver_lanzamiento() -> void:
	if _azar.randf() < PROB_DOBLAR:
		_pote *= 2
		_dobles += 1
		if _dobles >= MAX_DOBLES:
			Juego.marcar_logro("doble_cinco")
		Sonido.tocar("ganar")
		_menu_doble(Idioma.t("¡CARA! EN JUEGO: %d") % _pote)
	else:
		_pote = 0
		Sonido.tocar("perder")
		_ir_a(Fase.FIN, Idioma.t("CRUZ. LO HAS PERDIDO TODO."))
		_salir()


func _cobrar() -> void:
	Juego.ganar_oro(_pote)
	Sonido.tocar("comprar")
	_ir_a(Fase.FIN, Idioma.t("TE LLEVAS %d MONEDAS.") % _pote)
	_pote = 0
	_salir()


# ---------------------------------------------------------------- prestamista
func _menu_prestamista() -> void:
	_ir_a(Fase.MENU, Idioma.t("YO SIEMPRE TENGO DINERO. OTRA COSA ES LO QUE ME DES A CAMBIO."))
	_boton(Idioma.t("VENDER UN CORAZÓN: +30 MONEDAS"), _vender_corazon, Juego.vida_max > 2)
	_boton(Idioma.t("PRÉSTAMO: +40 AHORA, DEBES 60 AL BAJAR DE PISO"), _prestamo, Juego.deuda == 0)
	_salir()


func _vender_corazon() -> void:
	Juego.vender_corazon()
	Sonido.tocar("comprar")
	_ir_a(Fase.FIN, Idioma.t("UN PLACER HACER NEGOCIOS."))
	_salir()


func _prestamo() -> void:
	Juego.pedir_prestamo()
	Sonido.tocar("comprar")
	_ir_a(Fase.FIN, Idioma.t("SI NO PAGAS, TE COBRO UN CORAZÓN."))
	_salir()


# ---------------------------------------------------------------- mendigo y caja fuerte
func _dar_mendigo() -> void:
	Juego.gastar_oro(10)
	Juego.marcar_logro("mendigo")
	var objeto := Juego.robar_objeto([], _azar) if _azar.randf() < 0.5 else ""
	if objeto != "":
		Juego.dar_objeto(objeto)
		Sonido.tocar("objeto")
		_ir_a(Fase.FIN, Idioma.t("A CAMBIO TE DA ESTO: %s.") % ObjetosDB.nombre(objeto).to_upper())
	else:
		Sonido.tocar("clic")
		_ir_a(Fase.FIN, Idioma.t("TE LO AGRADECE MUCHO. Y YA ESTÁ."))
	_salir()


func _abrir_caja() -> void:
	var texto := ""
	match _azar.randi() % 3:
		0:
			Juego.ganar_oro(25)
			Sonido.tocar("ganar")
			texto = Idioma.t("DENTRO HAY 25 MONEDAS.")
		1:
			_carta = Juego.robar_cartas(1, 1.0, _azar)[0]
			Sonido.tocar("carta_coger")
			texto = Idioma.t("DENTRO HAY UNA CARTA: %s.") % CartasDB.nombre(_carta).to_upper()
		_:
			Juego.gastar_oro(Juego.oro / 2)
			Sonido.tocar("perder")
			texto = Idioma.t("ERA UNA TRAMPA: PIERDES LA MITAD DE TUS MONEDAS.")
	_ir_a(Fase.FIN, texto)
	_salir()


# ---------------------------------------------------------------- barra
func _menu_barra() -> void:
	_ir_a(Fase.MENU, Idioma.t("¿QUÉ TE PONGO?"))
	_boton(Idioma.t("COPA DE LA CASA (8): CURA UN CORAZÓN"), _copa, Juego.oro >= 8 and Juego.vida < Juego.vida_max and _usos < 2)
	_boton(Idioma.t("CHUPITO MISTERIOSO (5)"), _chupito, Juego.oro >= 5 and _usos < 2)
	_salir()


func _copa() -> void:
	Juego.gastar_oro(8)
	Juego.curar(2)
	_usos += 1
	Sonido.tocar("ganar")
	_menu_barra()


func _chupito() -> void:
	Juego.gastar_oro(5)
	_usos += 1
	var texto := ""
	match _azar.randi() % 4:
		0:
			Juego.curar(2)
			texto = Idioma.t("SIENTA BIEN: RECUPERAS UN CORAZÓN.")
			Sonido.tocar("ganar")
		1:
			Juego.ganar_oro(15)
			texto = Idioma.t("ENCUENTRAS 15 MONEDAS EN EL FONDO DEL VASO.")
			Sonido.tocar("ganar")
		2:
			_carta = Juego.robar_cartas(1, 0.0, _azar)[0]
			texto = Idioma.t("APARECE UNA CARTA BAJO EL POSAVASOS: %s.") % CartasDB.nombre(_carta).to_upper()
			Sonido.tocar("carta_coger")
		_:
			if Juego.vida > 1:
				Juego.herir(1)
			texto = Idioma.t("NO DEBISTE BEBER ESO: PIERDES MEDIO CORAZÓN.")
			Sonido.tocar("perder")
	_ir_a(Fase.FIN, texto)
	_salir()


# ---------------------------------------------------------------- animación y entrada
func _process(delta: float) -> void:
	if not visible:
		return
	queue_redraw()
	if _fase not in [Fase.ENSENAR, Fase.MEZCLA, Fase.LANZANDO]:
		return
	_reloj -= delta
	if _reloj > 0.0:
		return
	match _fase:
		Fase.ENSENAR:
			_empezar_mezcla()
		Fase.MEZCLA:
			_terminar_cruce()
			if _mezclas > 0:
				_siguiente_cruce()
			else:
				_ir_a(Fase.ELEGIR, Idioma.t("¿DÓNDE ESTÁ? HAZ CLIC EN UNA COPA."))
		Fase.LANZANDO:
			_resolver_lanzamiento()


func _x_copa(i: int) -> float:
	var hueco: float = _copas[i]
	if _fase == Fase.MEZCLA and (i == _a or i == _b):
		var otro: int = _b if i == _a else _a
		var avance := 1.0 - clampf(_reloj / _ritmo, 0.0, 1.0)
		hueco = lerpf(_copas[i], _copas[otro], avance)
	return lerpf(X_COPAS[0], X_COPAS[2], hueco / 2.0)


func _y_arco(i: int) -> float:
	if _fase != Fase.MEZCLA or (i != _a and i != _b):
		return 0.0
	var avance := 1.0 - clampf(_reloj / _ritmo, 0.0, 1.0)
	return sin(avance * PI) * (-14.0 if i == _a else 14.0)


func _caja_copa(i: int) -> Rect2:
	return Rect2(_x_copa(i) - 18.0, 118.0, 36.0, 44.0)


func _caja_boton(i: int) -> Rect2:
	return Rect2(150.0, 208.0 + i * 20.0, 340.0, 17.0)


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		_sobre = _boton_en(evento.position)
	elif evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		if _fase == Fase.ELEGIR:
			for i in 3:
				if _caja_copa(i).has_point(evento.position):
					_elegir(i)
					return
		var b := _boton_en(evento.position)
		if b != -1 and _botones[b].activo:
			_botones[b].accion.call()


func _boton_en(p: Vector2) -> int:
	for i in _botones.size():
		if _caja_boton(i).has_point(p):
			return i
	return -1


## Lo usa el bot de pruebas: hace una acción válida cualquiera. Devuelve false si toca esperar.
func actuar_al_azar() -> bool:
	if _fase == Fase.ELEGIR:
		_elegir(randi() % 3)
		return true
	var validos: Array = _botones.filter(func(b): return b.activo)
	if validos.is_empty():
		return false
	validos[randi() % validos.size()].accion.call()
	return true


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 304), Color(0.06, 0.05, 0.1, 0.9))
	draw_string(Juego.fuente_grande, Vector2(0, 42), _titulo(), HORIZONTAL_ALIGNMENT_CENTER, 640, 16, COLOR_ORO)
	draw_multiline_string(Juego.fuente, Vector2(60, 66), _texto, HORIZONTAL_ALIGNMENT_CENTER, 520, 8, 2, COLOR_CREMA)
	draw_texture_rect_region(_tex_moneda, Rect2(296, 80, 8, 8), Rect2(0, 0, 8, 8))
	draw_string(Juego.fuente, Vector2(308, 88), str(Juego.oro), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_ORO)
	match _tipo:
		"trileros": _dibujar_trileros()
		"doble_nada": _dibujar_doble()
	for i in _botones.size():
		var caja := _caja_boton(i)
		var activo: bool = _botones[i].activo
		var color := Color8(122, 90, 160) if i == _sobre and activo else Color8(42, 31, 61)
		draw_rect(caja, color)
		draw_rect(caja, Color8(74, 52, 102), false, 1.0)
		draw_string(Juego.fuente, caja.position + Vector2(0, 12), _botones[i].texto, HORIZONTAL_ALIGNMENT_CENTER,
				caja.size.x, 8, COLOR_CREMA if activo else Color8(120, 110, 120))


func _dibujar_trileros() -> void:
	draw_rect(Rect2(170, 150, 300, 22), Color8(31, 92, 80))
	var hay_moneda := _revelar != -1 or _fase == Fase.RESULTADO
	if hay_moneda:
		draw_texture_rect_region(_tex_moneda, Rect2(_x_copa(_bola) - 8, 146, 16, 16), Rect2(0, 0, 8, 8))
	for i in 3:
		var subir := -26.0 if i == _revelar or (_fase == Fase.RESULTADO and i == _bola) else 0.0
		var y := 124.0 + subir + _y_arco(i)
		var resaltar := _fase == Fase.ELEGIR and _caja_copa(i).has_point(get_local_mouse_position())
		draw_texture(_tex_copa, Vector2(_x_copa(i) - 16.0, y), Color(1.25, 1.25, 1.25) if resaltar else Color.WHITE)


func _dibujar_doble() -> void:
	var ancho := 32.0
	if _fase == Fase.LANZANDO:
		ancho = 4.0 + abs(sin(_reloj * 16.0)) * 28.0
	draw_texture_rect_region(_tex_moneda, Rect2(320 - ancho * 0.5, 118, ancho, 32), Rect2(0, 0, 8, 8))
	if _pote > 0:
		draw_string(Juego.fuente_grande, Vector2(0, 182), str(_pote), HORIZONTAL_ALIGNMENT_CENTER, 640, 16, COLOR_ORO)
