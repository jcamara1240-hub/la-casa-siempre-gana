class_name Sala
extends Node2D
## Dibuja una sala y crea sus paredes. Mide lo mismo que la zona de juego (640x304).
## Ojo: no debe nombrar a Juego (ni a clases que lo usen): las pruebas usan Sala antes
## de que existan los autoloads.

signal mesa_volcada(posicion: Vector2, direccion: Vector2)
signal mesa_rota(posicion: Vector2)
signal mesa_golpeada(posicion: Vector2)

const INTERIOR := Rect2(16, 32, 608, 256)
const CENTRO := Vector2(320, 160)

# Hueco y marco de cada puerta, por dirección.
const HUECOS := {
	Vector2i.UP: Rect2(304, 0, 32, 32),
	Vector2i.DOWN: Rect2(304, 288, 32, 16),
	Vector2i.LEFT: Rect2(0, 144, 16, 32),
	Vector2i.RIGHT: Rect2(624, 144, 16, 32),
}
# Plantillas de columnas: posiciones en casillas relativas al centro.
const PLANTILLAS := [
	[],
	[Vector2i(-6, -2), Vector2i(6, -2), Vector2i(-6, 2), Vector2i(6, 2)],
	[Vector2i(-10, 0), Vector2i(10, 0)],
	[Vector2i(-4, -3), Vector2i(4, -3), Vector2i(-4, 3), Vector2i(4, 3), Vector2i(-12, 0), Vector2i(12, 0)],
	[Vector2i(-8, -3), Vector2i(8, 3)],
	[Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-3, 3), Vector2i(3, 3)],
	[Vector2i(-12, -3), Vector2i(-12, 3), Vector2i(12, -3), Vector2i(12, 3), Vector2i(-6, 0), Vector2i(6, 0)],
	[Vector2i(-9, -2), Vector2i(-5, 2), Vector2i(5, -2), Vector2i(9, 2)],
	[Vector2i(0, -3), Vector2i(0, 3), Vector2i(-13, 0), Vector2i(13, 0)],
]

# Cuántas mesas de póker puede tener una sala normal (sale de la semilla de la sala).
const MESAS_POSIBLES := [0, 1, 1, 2, 2]
# Donde aparece el jugador al entrar por cada puerta: ahí no se pone ninguna mesa.
const ENTRADAS := [Vector2(320, 272), Vector2(320, 50), Vector2(606, 160), Vector2(34, 160)]

# Cada piso con su estilo: la luz de los apliques, qué cuelga de la pared (celdas de
# adornos.png), la alfombra (fondo y borde), el zócalo y lo que se gasta el suelo. El tinte
# tiñe suelo y muros: cada piso se reconoce de un vistazo (azul, verde, oro, granate).
const ESTILOS_PISO := [
	{"tinte": Color(1.0, 1.0, 1.0), "luz": Color(1.0, 0.78, 0.42), "aplique": 7, "pared": [8, 0, 3, 8], "alfombra": [Color8(58, 40, 78), Color8(122, 90, 160)], "zocalo": Color8(20, 16, 30), "desgaste": 18},
	{"tinte": Color(0.62, 0.84, 1.0), "luz": Color(0.42, 0.85, 1.0), "aplique": 5, "pared": [1, 2, 0], "alfombra": [Color8(30, 40, 80), Color8(46, 111, 176)], "zocalo": Color8(46, 111, 176), "desgaste": 9},
	{"tinte": Color(0.66, 0.95, 0.78), "luz": Color(1.0, 0.88, 0.55), "aplique": 4, "pared": [3, 0, 2], "alfombra": [Color8(24, 72, 62), Color8(47, 138, 107)], "zocalo": Color8(31, 92, 80), "desgaste": 9},
	{"tinte": Color(1.0, 0.86, 0.64), "luz": Color(1.0, 0.8, 0.45), "aplique": 4, "pared": [2, 1, 3, 0], "alfombra": [Color8(84, 44, 34), Color8(247, 198, 74)], "zocalo": Color8(240, 129, 60), "desgaste": 6, "aranas": true},
	{"tinte": Color(1.0, 0.7, 0.66), "luz": Color(1.0, 0.55, 0.4), "aplique": 6, "pared": [1, 2], "alfombra": [Color8(84, 24, 46), Color8(214, 61, 79)], "zocalo": Color8(143, 35, 64), "desgaste": 6, "cortinas": Color8(143, 35, 64)},
]
# El rótulo de neón de las salas especiales: celda de adornos.png y color.
const ROTULOS := {
	GeneradorMazmorra.Tipo.TIENDA: [12, Color(0.42, 0.95, 0.6)],
	GeneradorMazmorra.Tipo.TESORO: [13, Color(1.0, 0.8, 0.3)],
	GeneradorMazmorra.Tipo.EVENTO: [14, Color(0.45, 0.85, 1.0)],
	GeneradorMazmorra.Tipo.JEFE: [15, Color(1.0, 0.3, 0.36)],
}
const COLOR_SOMBRA := Color(0.03, 0.02, 0.07, 0.42)
# El contorno del rombo de la moqueta, píxel a píxel.
const ROMBO_MOQUETA := [Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, -3), Vector2i(0, 3),
	Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(1, -2), Vector2i(2, -1),
	Vector2i(-2, 1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(2, 1)]
const COLOR_HOLLIN := Color(0.05, 0.03, 0.09)

var solidos: Array = []  # Rect2 de las columnas: los enemigos las esquivan empujándose.
var mesas: Array = []  # Mesa
var cajas_mesas: Array = []  # Rect2 de las mesas que aún chocan (de pie o volcadas)
# Lo pone main al entrar: daño al volcarlas y refuerzo del Tapete Reforzado.
var dano_mesas := 6.0
var refuerzo_mesas := 0.0
# Para el ambiente (lo lee el jugo): cambia en cada construir, y el piso lo pone ambientar().
var version := 0
var piso := 1
var luces: Array = []  # [posición, radio, color, parpadeo 0..1, fase]
var rotulo: Array = []  # [celda, posición, color] o vacío

var _volcadas := 0
var _datos: Dictionary
var _vecinas: Dictionary
var _puertas_abiertas := true
var _cuerpos_puerta: Dictionary = {}
var _casillas_suelo: Array = []
var _pared: Array = []  # [celda, x] de lo que cuelga en la pared de arriba
var _esquinas: Array = []  # [celda, posición] en el suelo, solo en salas sin pelea
var _alfombras: Array = []  # [Rect2, fondo, borde, redonda]
var _manchas: Array = []  # [posición, radio, alfa]
var _motas: Array = []  # [posición, color]
var _cortinas: Color = Color.TRANSPARENT
static var _tex_moqueta: ImageTexture  # la misma para todas las salas

@onready var _suelos: Texture2D = load("res://assets/baldosas/suelos.png")
@onready var _tapa: Texture2D = load("res://assets/baldosas/muro_tapa.png")
@onready var _cara: Texture2D = load("res://assets/baldosas/muro_cara.png")
@onready var _puertas: Texture2D = load("res://assets/baldosas/puertas.png")
@onready var _columna: Texture2D = load("res://assets/baldosas/columna.png")
@onready var _adornos: Texture2D = load("res://assets/baldosas/adornos.png") if ResourceLoader.exists("res://assets/baldosas/adornos.png") else null


func construir(datos: Dictionary, salas: Dictionary) -> void:
	_datos = datos
	_vecinas = {}
	for d in HUECOS:
		var c: Vector2i = datos.pos + d
		if salas.has(c):
			_vecinas[d] = salas[c]
	for hijo in get_children():
		hijo.queue_free()
	solidos.clear()
	mesas.clear()
	cajas_mesas.clear()
	_volcadas = 0
	_cuerpos_puerta.clear()

	var azar := RandomNumberGenerator.new()
	azar.seed = datos.semilla
	_casillas_suelo.clear()
	for y in 19:
		for x in 40:
			var tirada := azar.randi() % 100
			_casillas_suelo.append(0 if tirada < 55 else (1 if tirada < 80 else (2 if tirada < 95 else 3)))

	_crear_muros()
	if datos.tipo == GeneradorMazmorra.Tipo.NORMAL:
		var plantilla: Array = PLANTILLAS[azar.randi() % PLANTILLAS.size()]
		for casilla in plantilla:
			var centro := CENTRO + Vector2(casilla) * 16.0
			var caja := Rect2(centro - Vector2(8, 4), Vector2(16, 12))
			solidos.append(caja)
			_crear_solido(caja)
		# Después de las columnas, con el mismo azar: el suelo y las columnas no cambian.
		_crear_mesas(azar)
	poner_puertas(true)
	version += 1
	_preparar_adornos()
	queue_redraw()


## El piso lo sabe el juego, no la sala: se lo dice el jugo al entrar (cambia luces y adornos).
func ambientar(nuevo_piso: int) -> void:
	piso = maxi(nuevo_piso, 1)
	if not _datos.is_empty():
		_preparar_adornos()
	queue_redraw()


func tipo_sala() -> int:
	return int(_datos.get("tipo", GeneradorMazmorra.Tipo.NORMAL))


func _estilo() -> Dictionary:
	return ESTILOS_PISO[(piso - 1) % ESTILOS_PISO.size()]


# ------------------------------------------------------------ mesas de póker
func _crear_mesas(azar: RandomNumberGenerator) -> void:
	var cuantas: int = MESAS_POSIBLES[azar.randi() % MESAS_POSIBLES.size()]
	var zona := INTERIOR.grow(-40.0)
	var guardadas: Array = _datos.get("mesas", [])
	for _intento in 30:
		if mesas.size() >= cuantas:
			break
		var c := Vector2(azar.randf_range(zona.position.x, zona.end.x), azar.randf_range(zona.position.y, zona.end.y)).snapped(Vector2(8, 8))
		if not _sitio_para_mesa(c):
			continue
		var m := Mesa.new()
		m.iniciar(c)
		if mesas.size() < guardadas.size():
			m.restaurar(guardadas[mesas.size()], refuerzo_mesas)
		m.volcada.connect(_al_volcar_mesa)
		m.rota.connect(_al_romper_mesa)
		add_child(m)
		mesas.append(m)
	_rehacer_cajas_mesas()


## Lejos del centro, de las entradas, de las columnas y de otras mesas: nadie se queda encerrado.
func _sitio_para_mesa(c: Vector2) -> bool:
	if c.distance_to(CENTRO) < 52.0:
		return false
	for p in ENTRADAS:
		if c.distance_to(p) < 64.0:
			return false
	for caja in solidos:
		if caja.grow(34.0).has_point(c):
			return false
	for m in mesas:
		if m.centro.distance_to(c) < 72.0:
			return false
	return true


func _rehacer_cajas_mesas() -> void:
	cajas_mesas.clear()
	_volcadas = 0
	for m in mesas:
		if m.solida():
			cajas_mesas.append(m.caja)
		if m.para_balas():
			_volcadas += 1


func _al_volcar_mesa(m: Mesa) -> void:
	_rehacer_cajas_mesas()
	_guardar_mesas()
	queue_redraw()  # su sombra cambia
	mesa_volcada.emit(m.centro, m.direccion)


func _al_romper_mesa(m: Mesa) -> void:
	_rehacer_cajas_mesas()
	_guardar_mesas()
	queue_redraw()
	mesa_rota.emit(m.centro)


## Al volver a una sala, las mesas siguen como las dejaste.
func _guardar_mesas() -> void:
	_datos["mesas"] = mesas.map(func(m): return m.volcar_datos())


## Lo consulta cada bala enemiga: true si ha chocado con una mesa volcada (y la mesa lo cuenta).
func bloquea_bala(p: Vector2) -> bool:
	if _volcadas == 0:
		return false
	for m in mesas:
		if m.para_balas() and m.caja.has_point(p):
			m.recibir_bala()
			mesa_golpeada.emit(p)
			return true
	return false


## La mesa de pie que tienes al lado, o null.
func mesa_cerca(p: Vector2, alcance: float) -> Mesa:
	for m in mesas:
		if m.estado == Mesa.Estado.DE_PIE and m.caja.grow(alcance).has_point(p):
			return m
	return null


## Vuelca la mesa de pie que toques: cae hacia el lado contrario al tuyo. horda puede ser null.
func volcar_cerca(p: Vector2, alcance: float, horda) -> bool:
	var m := mesa_cerca(p, alcance)
	if m == null:
		return false
	m.volcar(cardinal(m.centro - p), horda, dano_mesas, refuerzo_mesas)
	return true


## Saca un círculo (el jugador) de las mesas sólidas. Las mesas están lejos de paredes
## y columnas, así que empujar por el lado más corto nunca te mete en otra cosa.
func sacar_de_mesas(p: Vector2, r: float) -> Vector2:
	for caja in cajas_mesas:
		p = sacar_de_caja(p, r, caja)
	return p


static func sacar_de_caja(p: Vector2, r: float, caja: Rect2) -> Vector2:
	var grande: Rect2 = caja.grow(r)
	if not grande.has_point(p):
		return p
	var izq := p.x - grande.position.x
	var der := grande.end.x - p.x
	var arr := p.y - grande.position.y
	var aba := grande.end.y - p.y
	var menor: float = min(izq, der, arr, aba)
	if menor == izq:
		p.x = grande.position.x
	elif menor == der:
		p.x = grande.end.x
	elif menor == arr:
		p.y = grande.position.y
	else:
		p.y = grande.end.y
	return p


## La dirección de las cuatro (arriba, abajo, izquierda, derecha) que más se parece a v.
static func cardinal(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, 1.0 if v.y >= 0.0 else -1.0)


func _crear_muros() -> void:
	for d in HUECOS:
		var lado := _rect_lado(d)
		if not _vecinas.has(d):
			_crear_solido(lado)
			continue
		var hueco: Rect2 = HUECOS[d]
		if d == Vector2i.UP or d == Vector2i.DOWN:
			_crear_solido(Rect2(lado.position, Vector2(hueco.position.x - lado.position.x, lado.size.y)))
			_crear_solido(Rect2(Vector2(hueco.end.x, lado.position.y), Vector2(lado.end.x - hueco.end.x, lado.size.y)))
		else:
			_crear_solido(Rect2(lado.position, Vector2(lado.size.x, hueco.position.y - lado.position.y)))
			_crear_solido(Rect2(Vector2(lado.position.x, hueco.end.y), Vector2(lado.size.x, lado.end.y - hueco.end.y)))
		_cuerpos_puerta[d] = _crear_solido(hueco)


func _rect_lado(d: Vector2i) -> Rect2:
	match d:
		Vector2i.UP: return Rect2(0, 0, 640, 32)
		Vector2i.DOWN: return Rect2(0, 288, 640, 16)
		Vector2i.LEFT: return Rect2(0, 0, 16, 304)
	return Rect2(624, 0, 16, 304)


func _crear_solido(caja: Rect2) -> CollisionShape2D:
	var cuerpo := StaticBody2D.new()
	cuerpo.position = caja.get_center()
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = caja.size
	forma.shape = rect
	cuerpo.add_child(forma)
	add_child(cuerpo)
	return forma


func poner_puertas(abiertas: bool) -> void:
	_puertas_abiertas = abiertas
	for d in _cuerpos_puerta:
		_cuerpos_puerta[d].set_deferred("disabled", abiertas)
	queue_redraw()


func puerta_abierta(d: Vector2i) -> bool:
	return _puertas_abiertas and _vecinas.has(d)


# ------------------------------------------------------------ adornos (solo aspecto)
## Lo que decora la sala sale de su semilla (con otro azar: columnas y mesas no cambian)
## y del piso. Nada de esto choca, y en el suelo todo es oscuro y de poco contraste.
func _preparar_adornos() -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash(int(_datos.get("semilla", 0)) * 7919 + 13)
	var estilo := _estilo()
	var tipo := tipo_sala()
	var t := GeneradorMazmorra.Tipo
	luces.clear()
	rotulo = []
	_pared.clear()
	_esquinas.clear()
	_alfombras.clear()
	_manchas.clear()
	_motas.clear()
	_cortinas = estilo.get("cortinas", Color.TRANSPARENT)
	if tipo == t.JEFE:
		_cortinas = Color8(143, 35, 64)
	elif tipo == t.TIENDA:
		_cortinas = Color8(31, 92, 80)
	var arriba_libre := not _vecinas.has(Vector2i.UP)
	if ROTULOS.has(tipo):
		rotulo = [ROTULOS[tipo][0], Vector2(320.0 if arriba_libre else 256.0, 24.0), ROTULOS[tipo][1]]
	# Pared de arriba: apliques con su luz y, entre ellos, cuadros o rejillas.
	var huecos_pared := [128.0, 192.0, 256.0, 320.0, 384.0, 448.0, 512.0]
	var luz: Color = estilo.luz
	for i in huecos_pared.size():
		var x: float = huecos_pared[i]
		if not arriba_libre and absf(x - 320.0) < 40.0:
			continue
		if not rotulo.is_empty() and absf(x - rotulo[1].x) < 20.0:
			continue
		if i % 2 == 0:
			_pared.append([int(estilo.aplique), x])
			var parpadeo := 0.45 if piso == 1 or int(estilo.aplique) == 5 else 0.12
			luces.append([Vector2(x, 30), Vector2(120, 92), Color(luz, 0.26), parpadeo, azar.randf() * TAU])
		elif azar.randf() < 0.8:
			var lista: Array = estilo.pared
			_pared.append([int(lista[azar.randi() % lista.size()]), x])
	if estilo.get("aranas", false):
		for x in [200.0, 440.0]:
			luces.append([Vector2(x, 150), Vector2(230, 150), Color(luz, 0.13), 0.04, azar.randf() * TAU])
	# El suelo: alfombras, desgaste y alguna ficha perdida.
	var fondo: Color = estilo.alfombra[0]
	var borde: Color = estilo.alfombra[1]
	var oro := Color8(247, 198, 74)
	match tipo:
		t.NORMAL:
			if azar.randf() < 0.6:
				var an := float(azar.randi_range(9, 17)) * 16.0
				var al := float(azar.randi_range(4, 7)) * 16.0
				var c := (CENTRO + Vector2(azar.randf_range(-90.0, 90.0), azar.randf_range(-20.0, 20.0))).snapped(Vector2(8, 8))
				var caja := Rect2(c - Vector2(an, al) * 0.5, Vector2(an, al)).intersection(INTERIOR.grow(-14.0))
				_alfombras.append([caja, fondo, borde, false])
		t.JEFE:
			_alfombras.append([Rect2(300, 168, 40, 120), Color8(96, 22, 44), oro, false])
			_alfombras.append([Rect2(262, 62, 116, 112), Color8(96, 22, 44), oro, true])
			for x in [276.0, 364.0]:
				luces.append([Vector2(x, 30), Vector2(110, 120), Color(1.0, 0.3, 0.3, 0.3), 0.2, azar.randf() * TAU])
			luces.append([Vector2(320, 118), Vector2(150, 110), Color(1.0, 0.45, 0.4, 0.16), 0.0, 0.0])
			# Dos focos bajos a los lados: la arena no se queda en negro fuera de la alfombra.
			for x in [150.0, 490.0]:
				luces.append([Vector2(x, 214), Vector2(200, 120), Color(luz, 0.09), 0.05, azar.randf() * TAU])
		t.TIENDA:
			_alfombras.append([Rect2(48, 100, 544, 72), Color8(20, 60, 52), oro, false])
			luces.append([Vector2(320, 132), Vector2(600, 110), Color(1.0, 0.95, 0.8, 0.16), 0.0, 0.0])
			_esquinas = [[9, Vector2(40, 54)], [9, Vector2(600, 54)], [9, Vector2(40, 270)], [9, Vector2(600, 270)]]
		t.TESORO:
			_alfombras.append([Rect2(224, 120, 192, 80), Color8(84, 44, 34), oro, false])
			for x in [274.0, 366.0]:
				luces.append([Vector2(x, 160), Vector2(96, 72), Color(1.0, 0.85, 0.45, 0.28), 0.0, 0.0])
			_esquinas = [[10, Vector2(214, 114)], [10, Vector2(426, 114)], [10, Vector2(214, 198)], [10, Vector2(426, 198)]]
		t.EVENTO:
			_alfombras.append([Rect2(272, 116, 96, 88), Color8(30, 40, 80), Color8(111, 195, 232), true])
			luces.append([Vector2(320, 160), Vector2(130, 100), Color(0.6, 0.85, 1.0, 0.22), 0.0, 0.0])
			_esquinas = [[11, Vector2(40, 54)], [11, Vector2(600, 54)]]
		_:
			_alfombras.append([Rect2(264, 128, 112, 64), fondo, borde, false])
			_esquinas = [[9, Vector2(40, 54)], [9, Vector2(600, 54)]]
	var desgaste: int = estilo.desgaste + (6 if tipo == t.NORMAL else 0)
	for _i in desgaste:
		var p := Vector2(azar.randf_range(INTERIOR.position.x + 8, INTERIOR.end.x - 8), azar.randf_range(INTERIOR.position.y + 8, INTERIOR.end.y - 8))
		_manchas.append([p, azar.randf_range(4.0, 13.0), azar.randf_range(0.05, 0.11)])
	var colores_ficha := [Color8(214, 61, 79), Color8(47, 138, 107), Color8(46, 111, 176), Color8(247, 198, 74)]
	for _i in azar.randi_range(4, 9):
		var p := Vector2(azar.randf_range(INTERIOR.position.x + 6, INTERIOR.end.x - 6), azar.randf_range(INTERIOR.position.y + 6, INTERIOR.end.y - 6)).floor()
		_motas.append([p, Color(colores_ficha[azar.randi() % colores_ficha.size()], 0.32)])


func _draw() -> void:
	if _datos.is_empty():
		return
	var fila_suelo := 0
	match _datos.tipo:
		GeneradorMazmorra.Tipo.TIENDA, GeneradorMazmorra.Tipo.EVENTO: fila_suelo = 1
		GeneradorMazmorra.Tipo.JEFE: fila_suelo = 2
		GeneradorMazmorra.Tipo.TESORO: fila_suelo = 3
	# Los muros siempre llevan el tinte del piso; el suelo, solo el normal y el del jefe
	# (la tienda, el tesoro y el evento tienen su propio color).
	var tinte: Color = _estilo().get("tinte", Color.WHITE)
	var tinte_suelo: Color = tinte if fila_suelo == 0 or fila_suelo == 2 else Color.WHITE
	for y in 19:
		for x in 40:
			var destino := Rect2(x * 16, y * 16, 16, 16)
			if y == 1 and x > 0 and x < 39:
				draw_texture_rect(_cara, destino, false, tinte)
			elif y < 2 or y == 18 or x == 0 or x == 39:
				draw_texture_rect(_tapa, destino, false, tinte)
			else:
				var variante: int = _casillas_suelo[y * 40 + x]
				draw_texture_rect_region(_suelos, destino, Rect2(variante * 16, fila_suelo * 16, 16, 16), tinte_suelo)
	_dibujar_suelo()
	_dibujar_sombras()
	for caja in solidos:
		draw_texture(_columna, Vector2(caja.position.x, caja.position.y - 12))
	_dibujar_pared()
	for d in _vecinas:
		_dibujar_puerta(d)
	_dibujar_rotulo()


## Penumbra al pie de los muros, alfombras, manchas de desgaste y fichas perdidas.
func _dibujar_suelo() -> void:
	for i in 6:
		var a := 0.3 * (1.0 - i / 6.0)
		draw_rect(Rect2(16, 32 + i * 2, 608, 2), Color(COLOR_HOLLIN, a))
		draw_rect(Rect2(16 + i * 2, 32, 2, 256), Color(COLOR_HOLLIN, a * 0.7))
		draw_rect(Rect2(622 - i * 2, 32, 2, 256), Color(COLOR_HOLLIN, a * 0.7))
		draw_rect(Rect2(16, 286 - i, 608, 1), Color(COLOR_HOLLIN, a * 0.6))
	_dibujar_moqueta()
	for alfombra in _alfombras:
		_dibujar_alfombra(alfombra[0], alfombra[1], alfombra[2], alfombra[3])
	for m in _manchas:
		draw_circle(m[0], m[1], Color(COLOR_HOLLIN, m[2]))
		draw_circle(m[0] + Vector2(m[1] * 0.3, -m[1] * 0.2), m[1] * 0.55, Color(COLOR_HOLLIN, m[2]))
	for mota in _motas:
		draw_rect(Rect2(mota[0], Vector2(2, 1)), mota[1])
		draw_rect(Rect2(mota[0] + Vector2(0, 1), Vector2(2, 1)), Color(mota[1].darkened(0.4), mota[1].a))


## La moqueta de casino: un rombo hueco cada 32 píxeles, al tresbolillo, casi del color
## del suelo. Da textura sin competir con nada que se mueva. Es una sola textura (se hace
## una vez) pintada de una vez con el color del piso: no cuesta nada por fotograma.
func _dibujar_moqueta() -> void:
	if tipo_sala() != GeneradorMazmorra.Tipo.NORMAL and tipo_sala() != GeneradorMazmorra.Tipo.INICIO:
		return
	if _tex_moqueta == null:
		_tex_moqueta = _hacer_moqueta()
	draw_texture(_tex_moqueta, INTERIOR.position, Color(_estilo().alfombra[1], 0.14))


static func _hacer_moqueta() -> ImageTexture:
	var img := Image.create(int(INTERIOR.size.x), int(INTERIOR.size.y), false, Image.FORMAT_RGBA8)
	for fila in 8:
		var y := 16 + fila * 32
		var desfase := 16 if fila % 2 == 1 else 0
		for columna in 19:
			var x := 16 + desfase + columna * 32
			if x > int(INTERIOR.size.x) - 8:
				continue
			for o: Vector2i in ROMBO_MOQUETA:
				img.set_pixel(x + o.x, y + o.y, Color.WHITE)
			img.set_pixel(x, y, Color(1, 1, 1, 0.6))
	return ImageTexture.create_from_image(img)


func _dibujar_alfombra(caja: Rect2, fondo: Color, borde: Color, redonda: bool) -> void:
	if redonda:
		var c := caja.get_center()
		var r := minf(caja.size.x, caja.size.y) * 0.5
		draw_circle(c, r, Color(fondo, 0.72))
		draw_arc(c, r - 3.0, 0.0, TAU, 56, Color(borde, 0.5), 1.0)
		draw_arc(c, r - 6.0, 0.0, TAU, 56, Color(borde, 0.22), 1.0)
		for i in 12:
			_rombo(c + Vector2.RIGHT.rotated(TAU * i / 12.0) * (r - 11.0), Color(borde, 0.3))
		return
	draw_rect(caja, Color(fondo, 0.72))
	draw_rect(caja.grow(-2.0), Color(borde, 0.45), false, 1.0)
	draw_rect(caja.grow(-5.0), Color(borde, 0.2), false, 1.0)
	for x in range(int(caja.position.x) + 12, int(caja.end.x) - 8, 16):
		_rombo(Vector2(x, caja.position.y + 10.0), Color(borde, 0.28))
		_rombo(Vector2(x, caja.end.y - 10.0), Color(borde, 0.28))
	# Flecos en los lados cortos.
	for y in range(int(caja.position.y) + 3, int(caja.end.y) - 2, 3):
		draw_rect(Rect2(caja.position.x - 2.0, y, 2, 1), Color(borde, 0.35))
		draw_rect(Rect2(caja.end.x, y, 2, 1), Color(borde, 0.35))


func _rombo(p: Vector2, color: Color) -> void:
	p = p.floor()
	draw_rect(Rect2(p.x - 1, p.y, 3, 1), color)
	draw_rect(Rect2(p.x, p.y - 1, 1, 3), color)


func _elipse(centro: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_set_transform(centro, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx, color)
	draw_set_transform(Vector2.ZERO)


## Las sombras de lo que no se mueve: columnas, mesas y adornos de las esquinas.
func _dibujar_sombras() -> void:
	for caja in solidos:
		_elipse(Vector2(caja.get_center().x + 1.0, caja.end.y + 1.0), 11.0, 4.0, COLOR_SOMBRA)
	for m in mesas:
		match m.estado:
			Mesa.Estado.DE_PIE:
				_elipse(m.centro + Vector2(0, 10), 17.0, 5.0, COLOR_SOMBRA)
			Mesa.Estado.VOLCADA:
				_elipse(Vector2(m.caja.get_center().x, m.caja.end.y + 1.0), m.caja.size.x * 0.5 + 3.0, 4.0, COLOR_SOMBRA)
			_:
				_elipse(m.centro + Vector2(0, 8), 15.0, 4.0, Color(COLOR_SOMBRA, 0.25))
	if _adornos == null:
		return
	for e in _esquinas:
		_elipse(e[1] + Vector2(0, 7), 7.0, 2.5, COLOR_SOMBRA)
		draw_texture_rect_region(_adornos, Rect2(e[1] - Vector2(8, 8), Vector2(16, 16)), Rect2(e[0] * 16, 0, 16, 16))


## Zócalo, cortinas, cuadros y apliques en la cara del muro de arriba.
func _dibujar_pared() -> void:
	var zocalo: Color = _estilo().zocalo
	draw_rect(Rect2(16, 29, 608, 3), zocalo.darkened(0.45))
	draw_rect(Rect2(16, 29, 608, 1), zocalo.lightened(0.1))
	if _cortinas.a > 0.0:
		var centro_x := 320.0
		for x in [centro_x - 52.0, centro_x + 32.0, 100.0, 520.0]:
			_cortina(x, _cortinas)
	if _adornos == null:
		return
	for cosa in _pared:
		draw_texture_rect_region(_adornos, Rect2(cosa[1] - 8.0, 16, 16, 16), Rect2(cosa[0] * 16, 0, 16, 16))


func _cortina(x: float, color: Color) -> void:
	var oscuro := color.darkened(0.45)
	for i in 10:
		var alto := 13.0 if i % 2 == 0 else 12.0
		draw_rect(Rect2(x + i * 2, 16, 2, alto), color if i % 2 == 0 else oscuro)
	draw_rect(Rect2(x, 16, 20, 1), oscuro.darkened(0.4))
	draw_rect(Rect2(x + 1, 24, 18, 1), Color8(247, 198, 74))


## El rótulo apagado (cristal oscuro sobre su placa); el jugo le pone la luz encima.
func _dibujar_rotulo() -> void:
	if rotulo.is_empty() or _adornos == null:
		return
	var p: Vector2 = rotulo[1]
	draw_rect(Rect2(p.x - 10, 17, 20, 13), Color8(20, 16, 30))
	draw_rect(Rect2(p.x - 10, 17, 20, 13), Color8(74, 52, 102), false, 1.0)
	draw_texture_rect_region(_adornos, Rect2(p - Vector2(8, 8), Vector2(16, 16)), Rect2(rotulo[0] * 16, 0, 16, 16), Color(rotulo[2].darkened(0.55), 1.0))


func _dibujar_puerta(d: Vector2i) -> void:
	var fila := _fila_puerta(_vecinas[d])
	var columna := 0 if _puertas_abiertas else 1
	var origen := Rect2(columna * 32, fila * 32, 32, 32)
	var hueco: Rect2 = HUECOS[d]
	match d:
		Vector2i.UP:
			draw_texture_rect_region(_puertas, hueco, origen)
		Vector2i.DOWN:
			# La parte baja del marco, vista desde arriba: se voltea en vertical.
			draw_set_transform(Vector2(304, 304), 0.0, Vector2(1, -1))
			draw_texture_rect_region(_puertas, Rect2(0, 0, 32, 16), Rect2(origen.position, Vector2(32, 16)))
			draw_set_transform(Vector2.ZERO)
		Vector2i.LEFT:
			draw_set_transform(Vector2(0, 176), -PI / 2.0)
			draw_texture_rect_region(_puertas, Rect2(0, 0, 32, 16), Rect2(origen.position, Vector2(32, 16)))
			draw_set_transform(Vector2.ZERO)
		Vector2i.RIGHT:
			draw_set_transform(Vector2(640, 144), PI / 2.0)
			draw_texture_rect_region(_puertas, Rect2(0, 0, 32, 16), Rect2(origen.position, Vector2(32, 16)))
			draw_set_transform(Vector2.ZERO)


func _fila_puerta(vecina: Dictionary) -> int:
	var tipo: int = vecina.tipo
	if _datos.tipo == GeneradorMazmorra.Tipo.JEFE or tipo == GeneradorMazmorra.Tipo.JEFE:
		return 3
	if _datos.tipo == GeneradorMazmorra.Tipo.TESORO or tipo == GeneradorMazmorra.Tipo.TESORO:
		return 1
	if _datos.tipo == GeneradorMazmorra.Tipo.TIENDA or tipo == GeneradorMazmorra.Tipo.TIENDA:
		return 2
	return 0
