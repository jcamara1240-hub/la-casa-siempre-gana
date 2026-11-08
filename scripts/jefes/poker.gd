class_name JefePoker
extends Jefe
## El Jugador de Póker te lanza muros de cartas con un hueco. Y a veces se tira un farol.

enum Estado { ESPERAR, AVISAR, MUROS }

var _estado := Estado.ESPERAR
var _reloj := 1.3
var _muros := 0
var _muro_t := 0.0
var _farol := false


func _configurar() -> void:
	nombre = "EL JUGADOR DE PÓKER"
	vida_base = 340.0
	vel = 30.0
	texture = load("res://assets/personajes/poker.png")
	hframes = 2


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.25 if enfadado() else 1.0
	_reloj -= delta * ritmo
	match _estado:
		Estado.ESPERAR:
			frame = 0
			position += (Sala.CENTRO + Vector2(0, -60) - position).limit_length(vel * delta)
			if _reloj <= 0.0:
				_estado = Estado.AVISAR
				_reloj = 0.9
				_farol = randf() < 0.3
				_letrero.text = Idioma.t("VOY CON TODO")
		Estado.AVISAR:
			frame = 1
			if _reloj <= 0.0:
				_letrero.text = ""
				if _farol:
					# Era un farol: en vez de muros, una sola ráfaga directa.
					_letrero.text = Idioma.t("FAROL")
					_abanico(horda, 9, 0.12, 170.0, "naipe_negro")
					_estado = Estado.ESPERAR
					_reloj = 1.4
				else:
					_estado = Estado.MUROS
					_muros = 4 if enfadado() else 3
					_muro_t = 0.0
		Estado.MUROS:
			frame = 0
			_muro_t -= delta * ritmo
			if _muro_t <= 0.0 and _muros > 0:
				_muros -= 1
				_muro_t = 1.0
				_muro(horda, randi() % 2 == 0, "naipe_bala")
			if _muros <= 0 and _muro_t <= 0.0:
				_estado = Estado.ESPERAR
				_reloj = 1.3
				_letrero.text = ""
