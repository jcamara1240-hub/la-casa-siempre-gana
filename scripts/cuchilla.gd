class_name Cuchilla
extends Sprite2D
## Da vueltas alrededor del jugador y corta lo que toque, sin repetir enseguida.

const RADIO := 25.0
const VAIVEN := 17.0  # entra y sale: así también corta a lo que tienes pegado
const GIRO := 7.0
const REPETIR_SEG := 0.3

var _ataque: Dictionary
var _angulo := 0.0
var _vida := 1.0
var _dueno: Ataques
var _ultimos := {}
var _t := 0.0


func iniciar(ataque: Dictionary, angulo: float, dueno: Ataques) -> void:
	_ataque = ataque
	_angulo = angulo
	_vida = ataque.duracion
	_dueno = dueno
	position = _dueno.jugador.global_position + Vector2.RIGHT.rotated(angulo) * RADIO


func _physics_process(delta: float) -> void:
	_t += delta
	_vida -= delta
	if _vida <= 0.0:
		queue_free()
		return
	_angulo += GIRO * delta
	var radio_actual := RADIO + sin(_t * 9.0) * VAIVEN
	position = _dueno.jugador.global_position + Vector2.RIGHT.rotated(_angulo) * radio_actual
	rotation += 14.0 * delta
	for e in _dueno.horda.en_radio(position, 7.0):
		if _t - float(_ultimos.get(e, -1.0)) >= REPETIR_SEG:
			_ultimos[e] = _t
			_dueno.golpear(e, _ataque, (e.position - _dueno.jugador.global_position).normalized() * 70.0)
