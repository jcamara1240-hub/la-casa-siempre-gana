class_name Dinamita
extends Sprite2D
## Un cartucho que vuela hasta el enemigo, chisporrotea un momento y revienta en área.
## Fotogramas: la mecha parpadea entre los dos.

const VUELO_SEG := 0.3
const MECHA_SEG := 0.6  # desde que sale de la mano hasta que revienta
const ALTURA := 14.0

var _ataque: Dictionary
var _dueno: Ataques
var _desde := Vector2.ZERO
var _hasta := Vector2.ZERO
var _objetivo: Enemigo = null
var _busca := false
var _t := 0.0
var _hecha := false


func iniciar(ataque: Dictionary, desde: Vector2, objetivo: Enemigo, dueno: Ataques) -> void:
	_ataque = ataque
	_dueno = dueno
	_desde = desde
	_objetivo = objetivo
	_hasta = objetivo.position
	_busca = int(ataque.get("busca", 0)) > 0
	position = desde
	hframes = 2
	scale = Vector2.ONE * (1.0 + 0.3 * int(ataque.get("calibre", 0)))


func _physics_process(delta: float) -> void:
	_t += delta
	frame = int(_t * 14.0) % 2
	# Con Bala Trucada sigue a su objetivo y se le queda pegada.
	if _busca and is_instance_valid(_objetivo) and _objetivo.activo():
		_hasta = _objetivo.position
	if _t < VUELO_SEG:
		var avance := _t / VUELO_SEG
		position = _desde.lerp(_hasta, avance) + Vector2(0.0, -sin(avance * PI) * ALTURA)
		rotation += 16.0 * delta
		return
	position = _hasta
	# Parpadea en rojo justo antes de reventar.
	modulate = Color(2.0, 0.8, 0.7) if int(_t * 20.0) % 2 == 0 else Color.WHITE
	if _t >= MECHA_SEG:
		estallar()


func estallar() -> void:
	if _hecha:
		return
	_hecha = true
	_dueno.estallar(_ataque, position)
	queue_free()
