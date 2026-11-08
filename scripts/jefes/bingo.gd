class_name JefeBingo
extends Jefe
## La Bingo saca bolas, y cada una marca en el suelo un círculo que va a explotar.

enum Estado { MOVER, CANTAR }

var _estado := Estado.MOVER
var _reloj := 1.2
var _bolas := 0
var _bola_t := 0.0


func _configurar() -> void:
	nombre = "LA BINGO"
	vida_base = 340.0
	texture = load("res://assets/personajes/bingo.png")
	hframes = 4


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.3 if enfadado() else 1.0
	_reloj -= delta * ritmo
	frame = int(_t * (16.0 if _estado == Estado.CANTAR else 6.0)) % 4
	match _estado:
		Estado.MOVER:
			var destino := Sala.CENTRO + Vector2(cos(_t * 0.7) * 170.0, sin(_t * 1.1) * 70.0)
			position += (destino - position).limit_length(55.0 * delta)
			if _reloj <= 0.0:
				_estado = Estado.CANTAR
				_bolas = 6 if enfadado() else 4
				_bola_t = 0.0
				_letrero.text = Idioma.t("¡LÍNEA!")
		Estado.CANTAR:
			_bola_t -= delta * ritmo
			if _bola_t <= 0.0 and _bolas > 0:
				_bolas -= 1
				_bola_t = 0.32
				_cantar_bola(horda)
			if _bolas <= 0 and _bola_t <= 0.0:
				_estado = Estado.MOVER
				_reloj = 1.5
				_letrero.text = ""
				_anillo(horda, 12, 85.0, _t, "moneda")


func _cantar_bola(horda: Horda) -> void:
	var zona := Sala.INTERIOR.grow(-30.0)
	var jugador: Vector2 = horda.jugador.global_position
	# Una de cada dos va a por ti; las otras te cierran el paso.
	var punto := jugador if _bolas % 2 == 0 else jugador + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(50.0, 110.0)
	horda.ataques.zona_peligro(punto.clamp(zona.position, zona.end), 34.0, 1.0)
