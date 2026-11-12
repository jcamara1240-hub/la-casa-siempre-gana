class_name Cuchilla
extends Sprite2D
## Da vueltas alrededor del jugador y corta lo que toque, sin repetir enseguida.

const RADIO := 25.0
const VAIVEN := 17.0  # entra y sale: así también corta a lo que tienes pegado
const GIRO := 7.0
const REPETIR_SEG := 0.3
const ACERCA := 22.0  # con Bala Trucada, la órbita se inclina hacia el enemigo más cercano

var _ataque: Dictionary
var _angulo := 0.0
var _vida := 1.0
var _dueno: Ataques
var _ultimos := {}
var _t := 0.0
var _radio_golpe := 7.0
var _busca := false
var _busca_t := 0.0
var _foco := Vector2.ZERO
var _foco_deseado := Vector2.ZERO
var _metralla := false


func iniciar(ataque: Dictionary, angulo: float, dueno: Ataques) -> void:
	_ataque = ataque
	_angulo = angulo
	_vida = ataque.duracion
	_dueno = dueno
	var calibre := int(ataque.get("calibre", 0))
	_radio_golpe = 7.0 + 3.0 * calibre
	scale = Vector2.ONE * (1.0 + 0.4 * calibre)
	_busca = int(ataque.get("busca", 0)) > 0
	_metralla = int(ataque.get("metralla", 0)) > 0
	position = _dueno.jugador.global_position + Vector2.RIGHT.rotated(angulo) * RADIO


func _physics_process(delta: float) -> void:
	_t += delta
	_vida -= delta
	if _vida <= 0.0:
		queue_free()
		return
	_angulo += GIRO * delta
	if _busca:
		_buscar(delta)
	var centro: Vector2 = _dueno.jugador.global_position + _foco
	var radio_actual := RADIO + sin(_t * 9.0) * VAIVEN
	position = centro + Vector2.RIGHT.rotated(_angulo) * radio_actual
	rotation += 14.0 * delta
	for e in _dueno.horda.en_radio(position, _radio_golpe):
		if _t - float(_ultimos.get(e, -1.0)) >= REPETIR_SEG:
			_ultimos[e] = _t
			_dueno.golpear(e, _ataque, (e.position - _dueno.jugador.global_position).normalized() * 75.0)
			if _metralla:
				_metralla = false
				_dueno.soltar_metralla(_ataque, e.position, (e.position - centro).normalized(), e)


## Cada poco mira quién tiene más cerca y desplaza la órbita hacia él.
func _buscar(delta: float) -> void:
	_busca_t -= delta
	if _busca_t <= 0.0:
		_busca_t = 0.2
		var jugador: Vector2 = _dueno.jugador.global_position
		var mejor := 90.0 * 90.0
		_foco_deseado = Vector2.ZERO
		for e in _dueno.horda.en_radio(jugador, 90.0):
			var d: float = jugador.distance_squared_to(e.position)
			if d < mejor:
				mejor = d
				_foco_deseado = (e.position - jugador).limit_length(ACERCA)
	_foco = _foco.lerp(_foco_deseado, clampf(delta * 8.0, 0.0, 1.0))
