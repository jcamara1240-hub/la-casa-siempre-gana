class_name Mina
extends Sprite2D
## Una ficha trampa: se queda en el suelo, se arma y revienta cuando un enemigo la pisa.
## Fotogramas: 0 apagada, 1 encendida.

const ARMADO_SEG := 0.3
const VIDA_SEG := 9.0
const BUSCA_RADIO := 90.0
const BUSCA_VEL := 45.0

var _ataque: Dictionary
var _dueno: Ataques
var _t := 0.0
var _pisada := 10.0
var _busca := false
var _busca_t := 0.0
var _rumbo := Vector2.ZERO
var _hecha := false


func iniciar(ataque: Dictionary, posicion: Vector2, dueno: Ataques) -> void:
	_ataque = ataque
	_dueno = dueno
	position = posicion
	hframes = 2
	frame = 0
	scale = Vector2.ONE * (1.0 + 0.3 * int(ataque.get("calibre", 0)))
	_pisada = float(ataque.radio) * 0.45  # salta cuando lo tienen encima; el estallido llega más lejos
	_busca = int(ataque.get("busca", 0)) > 0


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= VIDA_SEG:
		queue_free()
		return
	if _t < ARMADO_SEG:
		return
	# Armada: parpadea, más deprisa cuando está a punto de apagarse.
	var ritmo := 4.0 if _t < VIDA_SEG - 1.5 else 12.0
	frame = int(_t * ritmo) % 2
	modulate.a = clampf((VIDA_SEG - _t) / 0.5, 0.0, 1.0)
	if _busca:
		_perseguir(delta)
	if not _dueno.horda.en_radio(position, _pisada).is_empty():
		estallar()


func estallar() -> void:
	if _hecha:
		return
	_hecha = true
	_dueno.estallar(_ataque, position)
	queue_free()


## Bala Trucada: la ficha se arrastra despacio hacia el enemigo más cercano.
func _perseguir(delta: float) -> void:
	_busca_t -= delta
	if _busca_t <= 0.0:
		_busca_t = 0.25
		_rumbo = Vector2.ZERO
		var mejor := BUSCA_RADIO * BUSCA_RADIO
		for e in _dueno.horda.en_radio(position, BUSCA_RADIO):
			var d: float = position.distance_squared_to(e.position)
			if d < mejor:
				mejor = d
				_rumbo = (e.position - position).normalized()
	position += _rumbo * BUSCA_VEL * delta
	var zona := Sala.INTERIOR.grow(-4.0)
	position = position.clamp(zona.position, zona.end)
