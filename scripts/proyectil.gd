class_name Proyectil
extends Sprite2D

var _vel := Vector2.ZERO
var _vida := 1.0
var _ataque: Dictionary = {}
var _dueno: Ataques
var _enemigo := false
var _golpeados := {}
var _perfora := 0
var _rebote := 0
var _vuelve := false
var _de_vuelta := false
var _giro_t := 0.0


func iniciar_jugador(velocidad: Vector2, ataque: Dictionary, vida: float, dueno: Ataques) -> void:
	_vel = velocidad
	_ataque = ataque
	_vida = vida
	_dueno = dueno
	_perfora = ataque.perfora
	_rebote = ataque.rebote
	_vuelve = ataque.vuelve
	_giro_t = vida * 0.45


func iniciar_enemigo(velocidad: Vector2, dueno: Ataques) -> void:
	_vel = velocidad
	_vida = 4.0
	_dueno = dueno
	_enemigo = true


func _physics_process(delta: float) -> void:
	if _vuelve and not _enemigo:
		_mover_boomerang(delta)
	position += _vel * delta
	_vida -= delta
	if _vida <= 0.0 or not Sala.INTERIOR.grow(8.0).has_point(position):
		queue_free()
		return
	if _enemigo:
		if position.distance_to(_dueno.jugador.global_position) < 7.0:
			_dueno.jugador.recibir_golpe(1)
			queue_free()
		return
	for e in _dueno.horda.en_radio(position, 3.0):
		if _golpeados.has(e):
			continue
		_golpeados[e] = true
		_dueno.golpear(e, _ataque, _vel.normalized() * 60.0)
		if _rebote > 0:
			_rebote -= 1
			var siguiente: Array = _dueno.horda.mas_cercanos(position, 1, _golpeados)
			if siguiente.is_empty():
				queue_free()
				return
			_vel = (siguiente[0].position - position).normalized() * _vel.length()
			_vida = max(_vida, 0.6)
			return
		if _perfora > 0:
			_perfora -= 1
			continue
		queue_free()
		return


func _mover_boomerang(delta: float) -> void:
	_giro_t -= delta
	rotation += 18.0 * delta
	if _giro_t > 0.0:
		return
	if not _de_vuelta:
		_de_vuelta = true
		_golpeados.clear()  # a la vuelta puede volver a golpear
		_vida = 2.0
	var hacia: Vector2 = _dueno.jugador.global_position - position
	if hacia.length() < 10.0:
		queue_free()
		return
	_vel = hacia.normalized() * _vel.length()
