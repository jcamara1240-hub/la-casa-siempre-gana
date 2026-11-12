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
	z_index = 2  # es un aviso: por encima del posproceso, como las balas enemigas


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
		# El charco: late y burbujea mientras quema.
		var latido := 0.5 + 0.5 * sin(_t * 12.0)
		draw_circle(Vector2.ZERO, _radio, Color(0.94, 0.51, 0.24, 0.45 + 0.12 * latido))
		draw_circle(Vector2.ZERO, _radio * 0.6, Color(0.97, 0.78, 0.29, 0.18 + 0.1 * latido))
		draw_arc(Vector2.ZERO, _radio, 0.0, TAU, 32, Color8(247, 198, 74), 1.0)
		return
	var avance := clampf(_t / _retardo, 0.0, 1.0)
	# Cuanto más lleno, más deprisa parpadea el borde: se lee de reojo cuándo revienta.
	var parpadea := avance > 0.6 and int(_t * (10.0 + avance * 20.0)) % 2 == 0
	draw_circle(Vector2.ZERO, _radio, Color(0.84, 0.24, 0.31, 0.12))
	draw_circle(Vector2.ZERO, _radio * avance, Color(0.84, 0.24, 0.31, 0.3 + 0.15 * avance))
	draw_arc(Vector2.ZERO, _radio, 0.0, TAU, 32, Color8(247, 236, 210) if parpadea else Color8(214, 61, 79), 1.0)
	draw_arc(Vector2.ZERO, _radio * avance, 0.0, TAU, 32, Color(0.97, 0.78, 0.29, 0.7), 1.0)
