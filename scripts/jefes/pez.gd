class_name JefePez
extends Jefe
## El Pez Rojo: en el póker, el "pez" es el que paga la mesa. Siempre el primer jefe.

enum Modo { NADAR, BURBUJAS, AVISO, EMBESTIDA }

var _estado := Modo.NADAR
var _reloj := 1.4
var _rafagas := 0
var _rafaga_t := 0.0
var _dir := Vector2.RIGHT


func _configurar() -> void:
	nombre = "EL PEZ ROJO"
	vida_base = 200.0
	radio = 20.0
	vel = 36.0
	texture = load("res://assets/personajes/pez_rojo.png")
	hframes = 3


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.3 if enfadado() else 1.0
	_reloj -= delta * ritmo
	var hacia: Vector2 = (horda.jugador.global_position - position).normalized()
	match _estado:
		Modo.NADAR:
			frame = int(_t * 5.0) % 2
			position += (hacia * vel + Vector2(0, sin(_t * 3.0) * 22.0)) * delta
			flip_h = hacia.x < 0.0
			if _reloj <= 0.0:
				if randf() < 0.5:
					_estado = Modo.BURBUJAS
					_rafagas = 3 if enfadado() else 2
					_rafaga_t = 0.1
				else:
					_estado = Modo.AVISO
					_reloj = 0.7
		Modo.BURBUJAS:
			frame = 2
			_rafaga_t -= delta * ritmo
			if _rafaga_t <= 0.0:
				_rafagas -= 1
				_rafaga_t = 0.5
				_anillo(horda, 10, 70.0, _t, "burbuja")
				if _rafagas <= 0:
					_volver()
		Modo.AVISO:
			frame = 2
			position.x += sin(_t * 60.0) * 1.2
			_dir = hacia
			flip_h = hacia.x < 0.0
			if _reloj <= 0.0:
				_estado = Modo.EMBESTIDA
				_reloj = 0.62
		Modo.EMBESTIDA:
			frame = 1
			position += _dir * 330.0 * delta
			var zona := Sala.INTERIOR.grow(-radio - 3.0)
			if _reloj <= 0.0 or not zona.has_point(position):
				_anillo(horda, 8, 80.0, 0.0, "burbuja")
				_volver()


func _volver() -> void:
	_estado = Modo.NADAR
	_reloj = 1.5
