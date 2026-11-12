class_name GeneradorMazmorra
extends RefCounted
## Coloca las salas de un piso en una cuadrícula.
##
## Una sala nueva solo puede tener un vecino al nacer. Así el mapa sale en forma
## de árbol, con callejones sin salida, y ahí van las salas especiales.

enum Tipo { INICIO, NORMAL, TESORO, TIENDA, JEFE, EVENTO, APUESTAS }  # los nuevos, siempre al final: se guardan como enteros

const ANCHO := 7
const ALTO := 5
const INICIO := Vector2i(3, 2)
const DIRECCIONES: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const PROB_APUESTAS := 0.6  # pisos con sala de apuestas (tragaperras y ruleta)


static func generar(azar: RandomNumberGenerator, cuantas := 11) -> Dictionary:
	for _intento in 500:
		var celdas := _hacer_celdas(azar, cuantas)
		if celdas.size() < cuantas:
			continue
		var distancias := _distancias(celdas)
		var extremos: Array = []
		for c in celdas:
			if c != INICIO and _vecinos(c, celdas) == 1:
				extremos.append(c)
		if extremos.size() < 3:
			continue
		extremos.sort_custom(func(a, b): return distancias[a] > distancias[b])
		return _montar(celdas, extremos, azar)
	push_error("No se pudo generar el piso")
	return {}


static func _hacer_celdas(azar: RandomNumberGenerator, cuantas: int) -> Dictionary:
	var celdas := {INICIO: true}
	var frontera: Array = [INICIO]
	while celdas.size() < cuantas and not frontera.is_empty():
		var origen: Vector2i = frontera[azar.randi() % frontera.size()]
		var candidatas: Array = []
		for d in DIRECCIONES:
			var q := origen + d
			if _dentro(q) and not celdas.has(q) and _vecinos(q, celdas) == 1:
				candidatas.append(q)
		if candidatas.is_empty():
			frontera.erase(origen)
			continue
		var nueva: Vector2i = candidatas[azar.randi() % candidatas.size()]
		celdas[nueva] = true
		frontera.append(nueva)
	return celdas


static func _montar(celdas: Dictionary, extremos: Array, azar: RandomNumberGenerator) -> Dictionary:
	var salas := {}
	for c in celdas:
		salas[c] = {
			"pos": c, "tipo": Tipo.NORMAL, "limpia": false, "visitada": false,
			"semilla": azar.randi(), "tienda": [], "cofre_abierto": false,
		}
	salas[INICIO].tipo = Tipo.INICIO
	salas[INICIO].limpia = true
	salas[extremos[0]].tipo = Tipo.JEFE
	salas[extremos[1]].tipo = Tipo.TESORO
	salas[extremos[2]].tipo = Tipo.TIENDA
	for especial in [extremos[1], extremos[2]]:
		salas[especial].limpia = true
	_poner_eventos(salas, azar)
	_poner_apuestas(salas, extremos)
	return salas


## Dos salas normales se convierten en sala de evento: sin combate, solo tentaciones.
static func _poner_eventos(salas: Dictionary, azar: RandomNumberGenerator) -> void:
	var normales: Array = salas.keys().filter(func(c): return salas[c].tipo == Tipo.NORMAL)
	for _i in mini(2, normales.size()):
		var elegida: Vector2i = normales.pop_at(azar.randi() % normales.size())
		salas[elegida].tipo = Tipo.EVENTO
		salas[elegida].limpia = true


## La sala de apuestas: como mucho una por piso. Sale de la semilla de la sala de inicio,
## que ya viene del azar del piso: así no gasta tiradas del azar común (el resto del piso
## queda igual que antes) y en el reto diario es la misma para todos.
static func _poner_apuestas(salas: Dictionary, extremos: Array) -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash(int(salas[INICIO].semilla) * 31 + 7)
	if azar.randf() >= PROB_APUESTAS:
		return
	# Mejor en un callejón sin salida que sobre; si no hay, en cualquier sala normal.
	var normal := func(c): return salas[c].tipo == Tipo.NORMAL
	var candidatas: Array = extremos.slice(3).filter(normal)
	if candidatas.is_empty():
		candidatas = salas.keys().filter(normal)
	if candidatas.is_empty():
		return
	var elegida: Vector2i = candidatas[azar.randi() % candidatas.size()]
	salas[elegida].tipo = Tipo.APUESTAS
	salas[elegida].limpia = true


static func _dentro(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < ANCHO and c.y < ALTO


static func _vecinos(c: Vector2i, celdas: Dictionary) -> int:
	var total := 0
	for d in DIRECCIONES:
		if celdas.has(c + d):
			total += 1
	return total


static func _distancias(celdas: Dictionary) -> Dictionary:
	var dist := {INICIO: 0}
	var cola: Array = [INICIO]
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		for d in DIRECCIONES:
			var q := c + d
			if celdas.has(q) and not dist.has(q):
				dist[q] = dist[c] + 1
				cola.append(q)
	return dist
