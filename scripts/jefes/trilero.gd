class_name JefeTrilero
extends Jefe
## El Trilero Mayor: mezcla tres copas y tienes que PISAR la buena para que sea vulnerable.

enum Estado { ENSENAR, MEZCLA, ELEGIR, VULNERABLE }
const HUECOS := [Vector2(170, 130), Vector2(320, 130), Vector2(470, 130)]
const RADIO_PISAR := 24.0

var _estado := Estado.ENSENAR
var _reloj := 1.2
var _copas: Array[Sprite2D] = []
var _orden := [0, 1, 2]  # qué hueco ocupa cada copa; la 0 es la buena
var _cruces := 0
var _a := 0
var _b := 1
var _bala_t := 0.0


func _configurar() -> void:
	nombre = "EL TRILERO MAYOR"
	vida_base = 320.0
	radio = 18.0
	hace_contacto = false
	texture = load("res://assets/objetos/copa_trile.png")
	scale = Vector2(1.5, 1.5)
	for i in 2:
		var c := Sprite2D.new()
		c.texture = texture
		c.scale = scale
		c.top_level = true
		add_child(c)
		_copas.append(c)


func _pos(copa: int) -> Vector2:
	return HUECOS[_orden[copa]]


func _colocar() -> void:
	position = _pos(0)
	_copas[0].global_position = _pos(1)
	_copas[1].global_position = _pos(2)


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.25 if enfadado() else 1.0
	_reloj -= delta * ritmo
	match _estado:
		Estado.ENSENAR:
			_colocar()
			_letrero.text = Idioma.t("¡AQUÍ!")
			if _reloj <= 0.0:
				_letrero.text = ""
				_cruces = 7 if enfadado() else 5
				_cruzar()
		Estado.MEZCLA:
			_animar_cruce()
			if _reloj <= 0.0:
				var t: int = _orden[_a]
				_orden[_a] = _orden[_b]
				_orden[_b] = t
				_colocar()
				if _cruces > 0:
					_cruzar()
				else:
					_estado = Estado.ELEGIR
					_reloj = 4.0
		Estado.ELEGIR:
			_colocar()
			_bala_t -= delta
			if _bala_t <= 0.0:
				_bala_t = 0.9
				for c in 3:
					_disparar_desde(horda, _pos(c))
			_mirar_pisada(horda)
			if _reloj <= 0.0:
				_anillo(horda, 16, 100.0, _t, "moneda")
				_reiniciar()
		Estado.VULNERABLE:
			_colocar()
			modulate = Color(1.3, 1.3, 0.8) if _flash <= 0.0 else modulate
			if _reloj <= 0.0:
				modulate = Color.WHITE
				_reiniciar()


func _cruzar() -> void:
	_estado = Estado.MEZCLA
	_cruces -= 1
	_reloj = 0.32
	_a = randi() % 3
	_b = (_a + 1 + randi() % 2) % 3


func _animar_cruce() -> void:
	var avance := 1.0 - clampf(_reloj / 0.32, 0.0, 1.0)
	var puntos := [_pos(0), _pos(1), _pos(2)]
	puntos[_a] = _pos(_a).lerp(_pos(_b), avance) + Vector2(0, sin(avance * PI) * -24.0)
	puntos[_b] = _pos(_b).lerp(_pos(_a), avance) + Vector2(0, sin(avance * PI) * 24.0)
	position = puntos[0]
	_copas[0].global_position = puntos[1]
	_copas[1].global_position = puntos[2]


func _disparar_desde(horda: Horda, origen: Vector2) -> void:
	var hacia: Vector2 = (_blanco(horda).global_position - origen).normalized()
	horda.ataques.bala_enemiga(origen, hacia * 105.0, "moneda")


## En cooperativo vale cualquiera de los dos: la buena la pisa uno, las malas cualquiera.
func _mirar_pisada(horda: Horda) -> void:
	for j in horda.vivos():
		_mirar_pisada_de(horda, j.global_position)
		if _estado != Estado.ELEGIR:
			return


func _mirar_pisada_de(horda: Horda, yo: Vector2) -> void:
	if yo.distance_to(_pos(0)) < RADIO_PISAR:
		_estado = Estado.VULNERABLE
		_reloj = 4.0
		_letrero.text = Idioma.t("¡PILLADO!")
		Sonido.tocar("ganar")
		return
	for c in [1, 2]:
		if yo.distance_to(_pos(c)) < RADIO_PISAR:
			for i in 12:
				horda.ataques.bala_enemiga(_pos(c), Vector2.RIGHT.rotated(TAU * i / 12.0) * 110.0, "moneda")
			Sonido.tocar("perder")
			_reiniciar()
			return


func _reiniciar() -> void:
	_estado = Estado.ENSENAR
	_reloj = 1.2
	_letrero.text = ""


func aplicar_golpe(dano: float, retroceso: Vector2) -> void:
	super.aplicar_golpe(dano * (1.0 if _estado == Estado.VULNERABLE else 0.2), retroceso)


## La mezcla (hay que poder seguirla con la vista) y el rato pillado van a su ritmo.
func _acelera() -> bool:
	return _estado != Estado.VULNERABLE and _estado != Estado.MEZCLA
