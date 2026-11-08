class_name Sala
extends Node2D
## Dibuja una sala y crea sus paredes. Mide lo mismo que la zona de juego (640x304).

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
]

var solidos: Array = []  # Rect2 de las columnas: los enemigos las esquivan empujándose.

var _datos: Dictionary
var _vecinas: Dictionary
var _puertas_abiertas := true
var _cuerpos_puerta: Dictionary = {}
var _casillas_suelo: Array = []

@onready var _suelos: Texture2D = load("res://assets/baldosas/suelos.png")
@onready var _tapa: Texture2D = load("res://assets/baldosas/muro_tapa.png")
@onready var _cara: Texture2D = load("res://assets/baldosas/muro_cara.png")
@onready var _puertas: Texture2D = load("res://assets/baldosas/puertas.png")
@onready var _columna: Texture2D = load("res://assets/baldosas/columna.png")


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
	poner_puertas(true)
	queue_redraw()


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


func _draw() -> void:
	if _datos.is_empty():
		return
	var fila_suelo := 0
	match _datos.tipo:
		GeneradorMazmorra.Tipo.TIENDA, GeneradorMazmorra.Tipo.EVENTO: fila_suelo = 1
		GeneradorMazmorra.Tipo.JEFE: fila_suelo = 2
		GeneradorMazmorra.Tipo.TESORO: fila_suelo = 3
	for y in 19:
		for x in 40:
			var destino := Rect2(x * 16, y * 16, 16, 16)
			if y == 1 and x > 0 and x < 39:
				draw_texture_rect(_cara, destino, false)
			elif y < 2 or y == 18 or x == 0 or x == 39:
				draw_texture_rect(_tapa, destino, false)
			else:
				var variante: int = _casillas_suelo[y * 40 + x]
				draw_texture_rect_region(_suelos, destino, Rect2(variante * 16, fila_suelo * 16, 16, 16))
	for caja in solidos:
		draw_texture(_columna, Vector2(caja.position.x, caja.position.y - 12))
	for d in _vecinas:
		_dibujar_puerta(d)


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
