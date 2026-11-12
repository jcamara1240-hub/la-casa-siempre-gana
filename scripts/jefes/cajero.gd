class_name JefeCajero
extends Jefe
## La Caja Registradora te aspira hacia ella y se cobra todo lo que te alcanza.

enum Estado { ANDAR, ASPIRAR, ESCUPIR }

var _estado := Estado.ANDAR
var _reloj := 1.5
var _rafagas := 0
var _rafaga_t := 0.0


func _configurar() -> void:
	nombre = "LA CAJA REGISTRADORA"
	vida_base = 330.0
	vel = 34.0
	texture = load("res://assets/personajes/cajero.png")
	hframes = 3


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.3 if enfadado() else 1.0
	_reloj -= delta * ritmo
	var jugador: Node2D = _blanco(horda)
	var hacia: Vector2 = (jugador.global_position - position).normalized()
	match _estado:
		Estado.ANDAR:
			frame = int(_t * 4.0) % 2
			position += hacia * vel * delta
			if _reloj <= 0.0:
				_estado = Estado.ASPIRAR
				_reloj = 2.0
				_letrero.text = Idioma.t("¡A CAJA!")
		Estado.ASPIRAR:
			frame = 2
			# Aspira a todos los que sigan en pie, cada uno hacia la caja.
			for j in horda.vivos():
				j.arrastre = -(j.global_position - position).normalized() * 85.0
			if int(_t * 10.0) % 3 == 0:
				var a := randf() * TAU
				horda.ataques.bala_enemiga(position + Vector2.RIGHT.rotated(a) * 170.0, Vector2.LEFT.rotated(a) * 120.0, "moneda")
			if _reloj <= 0.0:
				_estado = Estado.ESCUPIR
				_rafagas = 4 if enfadado() else 3
				_rafaga_t = 0.0
				_reloj = 0.5
				_letrero.text = ""
		Estado.ESCUPIR:
			frame = 2
			_rafaga_t -= delta * ritmo
			if _rafaga_t <= 0.0 and _rafagas > 0:
				_rafagas -= 1
				_rafaga_t = 0.3
				_anillo(horda, 14, 125.0, _t, "moneda")
			if _rafagas <= 0 and _reloj <= 0.0:
				_estado = Estado.ANDAR
				_reloj = 1.6
