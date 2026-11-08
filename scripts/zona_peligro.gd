class_name ZonaPeligro
extends Node2D
## Un círculo rojo que avisa y, al llenarse, hace daño a quien siga dentro.

var _radio := 30.0
var _retardo := 1.0
var _t := 0.0
var _dueno: Ataques
var _duracion := 0.0


func iniciar(centro: Vector2, radio: float, retardo: float, dueno: Ataques, duracion := 0.0) -> void:
	_duracion = duracion
	position = centro
	_radio = radio
	_retardo = retardo
	_dueno = dueno


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t < _retardo:
		return
	if _duracion > 0.0:
		# El charco sigue quemando hasta que se apaga.
		if position.distance_to(_dueno.jugador.global_position) <= _radio:
			_dueno.jugador.recibir_golpe(1)
		if _t >= _retardo + _duracion:
			queue_free()
		return
	if position.distance_to(_dueno.jugador.global_position) <= _radio:
		_dueno.jugador.recibir_golpe(1)
	Sonido.tocar("explosion", randf_range(1.1, 1.4), -8.0)
	_dueno.explosion_hecha.emit()
	queue_free()


func _draw() -> void:
	if _duracion > 0.0 and _t >= _retardo:
		draw_circle(Vector2.ZERO, _radio, Color(0.94, 0.51, 0.24, 0.55))
		draw_arc(Vector2.ZERO, _radio, 0.0, TAU, 28, Color8(247, 198, 74), 1.0)
		return
	var avance := clampf(_t / _retardo, 0.0, 1.0)
	draw_arc(Vector2.ZERO, _radio, 0.0, TAU, 28, Color8(214, 61, 79), 1.0)
	draw_circle(Vector2.ZERO, _radio * avance, Color(0.84, 0.24, 0.31, 0.35))
