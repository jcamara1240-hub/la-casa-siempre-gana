class_name JefeCoctelero
extends Jefe
## El Coctelero lanza botellas: donde caen, el suelo arde un buen rato.

enum Estado { BAILAR, AGITAR, LANZAR }

var _estado := Estado.BAILAR
var _reloj := 1.6
var _botellas := 0
var _bote_t := 0.0


func _configurar() -> void:
	nombre = "EL COCTELERO"
	vida_base = 320.0
	vel = 62.0
	texture = load("res://assets/personajes/coctelero.png")
	hframes = 4


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.3 if enfadado() else 1.0
	_reloj -= delta * ritmo
	match _estado:
		Estado.BAILAR:
			frame = int(_t * 5.0) % 2
			var c := Sala.CENTRO + Vector2(cos(_t * 1.3) * 190.0, sin(_t * 2.1) * 75.0)
			position += (c - position).limit_length(vel * delta)
			if _reloj <= 0.0:
				_estado = Estado.AGITAR
				_reloj = 0.8
		Estado.AGITAR:
			frame = 2 + int(_t * 20.0) % 2
			position.x += sin(_t * 70.0) * 1.5
			if _reloj <= 0.0:
				_estado = Estado.LANZAR
				_botellas = 5 if enfadado() else 4
				_bote_t = 0.0
		Estado.LANZAR:
			frame = 2
			_bote_t -= delta * ritmo
			if _bote_t <= 0.0 and _botellas > 0:
				_botellas -= 1
				_bote_t = 0.3
				_lanzar(horda)
			if _botellas <= 0 and _bote_t <= 0.0:
				_abanico(horda, 7, 0.2, 115.0, "burbuja")
				_estado = Estado.BAILAR
				_reloj = 1.8


func _lanzar(horda: Horda) -> void:
	var zona := Sala.INTERIOR.grow(-28.0)
	# En cooperativo, una botella para cada uno por turnos.
	var punto: Vector2 = horda.objetivo_por_turno(_botellas / 2).global_position
	if _botellas % 2 == 1:
		punto += Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 120.0)
	horda.ataques.zona_peligro(punto.clamp(zona.position, zona.end), 30.0, 0.8, 2.6)
