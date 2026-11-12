class_name JefeBlackjack
extends Jefe
## Va pidiendo cartas y cada una es un ataque. Si se pasa de 21 queda aturdido:
## es el momento de pegarle, porque recibe más daño.

enum Estado { PEDIR, ATURDIDO, BLACKJACK }
const DANO_ATURDIDO := 1.6

var _estado := Estado.PEDIR
var _reloj := 1.2
var _suma := 0
var _rafagas := 0
var _rafaga_t := 0.0


func _configurar() -> void:
	nombre = "EL REY DEL 21"
	vida_base = 360.0
	vel = 26.0
	texture = load("res://assets/personajes/rey_blackjack.png")
	hframes = 3


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.25 if enfadado() else 1.0
	_reloj -= delta * ritmo
	match _estado:
		Estado.PEDIR:
			frame = 1 if _reloj < 0.3 else 0
			position += (horda.jugador.global_position - position).normalized() * vel * delta
			if _reloj <= 0.0:
				_pedir_carta(horda)
		Estado.ATURDIDO:
			frame = 2
			modulate = Color(0.75, 0.75, 0.85) if _flash <= 0.0 else modulate
			if _reloj <= 0.0:
				_reiniciar()
		Estado.BLACKJACK:
			frame = 1
			_rafaga_t -= delta * ritmo
			if _rafaga_t <= 0.0 and _rafagas > 0:
				_rafagas -= 1
				_rafaga_t = 0.34
				_anillo(horda, 20, 105.0, _rafagas * 0.16, "naipe_bala")
			if _rafagas <= 0 and _reloj <= 0.0:
				_reiniciar()


func _pedir_carta(horda: Horda) -> void:
	var carta := randi_range(2, 11)
	_suma += carta
	_reloj = 0.85
	if _suma > 21:
		_estado = Estado.ATURDIDO
		_reloj = 2.8
		_letrero.text = Idioma.t("%d SE PASA") % _suma
		return
	if _suma == 21:
		_estado = Estado.BLACKJACK
		_reloj = 1.3
		_rafagas = 3
		_rafaga_t = 0.0
		_letrero.text = Idioma.t("BLACKJACK")
		return
	_letrero.text = str(_suma)
	# Cuanto más alta la carta, más naipes te tira.
	_abanico(horda, carta, 0.16, 115.0, "naipe_bala")
	# La banca se planta con 17 o más, y entonces lanza todo lo que tiene.
	if _suma >= 17 and randf() < 0.5:
		_letrero.text = Idioma.t("SE PLANTA %d") % _suma
		_anillo(horda, _suma, 100.0, _t, "naipe_bala")
		_suma = 0


func _reiniciar() -> void:
	_estado = Estado.PEDIR
	_suma = 0
	_reloj = 1.2
	_letrero.text = ""
	modulate = Color.WHITE


func aplicar_golpe(dano: float, retroceso: Vector2) -> void:
	super.aplicar_golpe(dano * (DANO_ATURDIDO if _estado == Estado.ATURDIDO else 1.0), retroceso)


## Cuando se pasa de 21 queda vendido: ese rato no se acorta.
func _acelera() -> bool:
	return _estado != Estado.ATURDIDO
