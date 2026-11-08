class_name JefeRevolver
extends Jefe
## El Revólver: ruleta rusa. Gira el tambor y aprieta el gatillo: click, click... ¡bang!

enum Estado { GIRAR, GATILLO, BANG }

var _estado := Estado.GIRAR
var _reloj := 1.4
var _bala := 0
var _recamara := 0
var _rafagas := 0


func _configurar() -> void:
	nombre = "EL REVÓLVER"
	vida_base = 350.0
	vel = 30.0
	texture = load("res://assets/personajes/revolver.png")
	hframes = 6


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.35 if enfadado() else 1.0
	_reloj -= delta * ritmo
	match _estado:
		Estado.GIRAR:
			frame = int(_t * 18.0) % 6
			position += (horda.jugador.global_position - position).normalized() * vel * delta
			if _reloj <= 0.0:
				_estado = Estado.GATILLO
				_reloj = 0.55
				_bala = randi_range(1, 6)
				_recamara = 0
		Estado.GATILLO:
			frame = _recamara
			if _reloj <= 0.0:
				_recamara += 1
				_reloj = 0.55
				if _recamara == _bala:
					_estado = Estado.BANG
					_letrero.text = Idioma.t("¡BANG!")
					_rafagas = 4
				else:
					_letrero.text = Idioma.t("CLIC")
					_abanico(horda, 3, 0.25, 135.0, "moneda")
		Estado.BANG:
			if _reloj <= 0.0 and _rafagas > 0:
				_rafagas -= 1
				_reloj = 0.28
				_anillo(horda, 26, 115.0, _rafagas * 0.12, "naipe_negro")
			elif _reloj <= 0.0:
				_estado = Estado.GIRAR
				_reloj = 1.6
				_letrero.text = ""
