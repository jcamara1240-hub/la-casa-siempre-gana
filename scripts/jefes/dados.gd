class_name JefeDados
extends Jefe
## Los Dados Locos: botan por la sala y, al pararse, la suma decide. Un 7 es lo peor.

enum Estado { BOTAR, TIRADA, ATAQUE }

var _estado := Estado.BOTAR
var _reloj := 2.0
var _vel := Vector2(150, 110)
var _a := 1
var _b := 1
var _rafagas := 0
var _rafaga_t := 0.0


func _configurar() -> void:
	nombre = "LOS DADOS LOCOS"
	vida_base = 330.0
	texture = load("res://assets/personajes/dados.png")
	hframes = 4


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.3 if enfadado() else 1.0
	_reloj -= delta * ritmo
	frame = int(_t * 12.0) % 4
	match _estado:
		Estado.BOTAR:
			position += _vel * delta * ritmo
			var zona := Sala.INTERIOR.grow(-radio - 2.0)
			if position.x <= zona.position.x or position.x >= zona.end.x:
				_vel.x = -_vel.x
			if position.y <= zona.position.y or position.y >= zona.end.y:
				_vel.y = -_vel.y
			if _reloj <= 0.0:
				_estado = Estado.TIRADA
				_reloj = 0.8
				_a = randi_range(1, 6)
				_b = randi_range(1, 6)
				_letrero.text = "%d + %d" % [_a, _b]
		Estado.TIRADA:
			frame = 0
			if _reloj <= 0.0:
				_estado = Estado.ATAQUE
				_rafagas = 3 if _a + _b == 7 else 1
				_rafaga_t = 0.0
				_reloj = 0.7
		Estado.ATAQUE:
			frame = 0
			_rafaga_t -= delta * ritmo
			if _rafaga_t <= 0.0 and _rafagas > 0:
				_rafagas -= 1
				_rafaga_t = 0.35
				_lanzar(horda)
			if _rafagas <= 0 and _reloj <= 0.0:
				_estado = Estado.BOTAR
				_reloj = 2.0
				_letrero.text = ""
				_vel = Vector2.RIGHT.rotated(randf() * TAU) * 180.0


func _lanzar(horda: Horda) -> void:
	var suma := _a + _b
	if suma == 7:
		_anillo(horda, 22, 105.0, _rafagas * 0.2, "moneda")
	elif _a == _b:
		_invocar(horda, ["dado", "dado", "dado_bomba"])
		_anillo(horda, 12, 90.0, _t, "moneda")
	else:
		_abanico(horda, suma, 0.14, 120.0, "moneda")
