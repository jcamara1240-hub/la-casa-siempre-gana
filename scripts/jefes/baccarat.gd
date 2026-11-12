class_name JefeBaccarat
extends Jefe
## La Mosca Crupier reparte una mano de baccarat y ataca según quién gane.

enum Estado { VOLAR, REPARTO, PUNTO, BANCA, EMPATE }

var _estado := Estado.VOLAR
var _reloj := 1.6
var _rafagas := 0
var _rafaga_t := 0.0


func _configurar() -> void:
	nombre = "LA MOSCA CRUPIER"
	vida_base = 340.0
	radio = 17.0
	vel = 70.0
	texture = load("res://assets/personajes/mosca.png")
	hframes = 3


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.3 if enfadado() else 1.0
	_reloj -= delta * ritmo
	match _estado:
		Estado.VOLAR:
			frame = int(_t * 14.0) % 2
			var hacia: Vector2 = (_blanco(horda).global_position - position).normalized()
			position += hacia.rotated(sin(_t * 2.6) * 1.3) * vel * delta
			if _reloj <= 0.0:
				_estado = Estado.REPARTO
				_reloj = 0.9
				_repartir()
		Estado.REPARTO:
			frame = 2
			if _reloj <= 0.0:
				_resolver()
		_:
			frame = int(_t * 14.0) % 2
			_rafaga_t -= delta * ritmo
			if _rafaga_t <= 0.0 and _rafagas > 0:
				_rafagas -= 1
				_rafaga_t = 0.38
				_atacar(horda)
			if _rafagas <= 0 and _reloj <= 0.0:
				_estado = Estado.VOLAR
				_reloj = 1.6
				_letrero.text = ""


var _punto := 0
var _banca := 0


func _repartir() -> void:
	_punto = randi() % 10
	_banca = randi() % 10
	_letrero.text = Idioma.t("PUNTO %d  BANCA %d") % [_punto, _banca]


func _resolver() -> void:
	_rafaga_t = 0.0
	_reloj = 0.8
	# Un 8 o un 9 es "natural": la mano gana con más fuerza.
	_rafagas = 4 if maxi(_punto, _banca) >= 8 else 3
	if _punto > _banca:
		_estado = Estado.PUNTO
	elif _banca > _punto:
		_estado = Estado.BANCA
	else:
		_estado = Estado.EMPATE


func _atacar(horda: Horda) -> void:
	match _estado:
		Estado.PUNTO:
			_abanico(horda, 5, 0.22, 130.0, "naipe_negro")
		Estado.BANCA:
			_anillo(horda, 14, 95.0, _t, "naipe_bala")
		Estado.EMPATE:
			_abanico(horda, 5, 0.22, 130.0, "naipe_negro")
			_anillo(horda, 14, 95.0, _t, "naipe_bala")
			if _rafagas == 0:
				_invocar(horda, ["dado", "dado", "dado"])
