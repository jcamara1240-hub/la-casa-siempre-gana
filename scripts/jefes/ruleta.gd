class_name JefeRuleta
extends Jefe
## Rueda rebotando por la sala. Cuando se para, el color decide: rojo, negro o el temido cero.

enum Estado { RODAR, NO_VA_MAS, ROJO, NEGRO, VERDE }

var _estado := Estado.RODAR
var _reloj := 2.4
var _vel := Vector2(110, 80)
var _emision := 0.0
var _giro := 0.0
var _rafagas := 0
var _bola: Sprite2D


func _configurar() -> void:
	nombre = "LA RULETA"
	vida_base = 320.0
	texture = load("res://assets/personajes/ruleta.png")
	hframes = 4
	_bola = Sprite2D.new()
	_bola.texture = load("res://assets/efectos/bala.png")
	add_child(_bola)


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.3 if enfadado() else 1.0
	_reloj -= delta * ritmo
	_bola.position = Vector2.RIGHT.rotated(_t * (9.0 if _estado == Estado.NO_VA_MAS else 3.0)) * 15.0
	match _estado:
		Estado.RODAR:
			frame = int(_t * 14.0) % 4
			_rodar(delta * ritmo)
			if _reloj <= 0.0:
				_estado = Estado.NO_VA_MAS
				_reloj = 0.9
				_letrero.text = Idioma.t("NO VA MÁS")
		Estado.NO_VA_MAS:
			frame = int(_t * 5.0) % 4
			if _reloj <= 0.0:
				_lanzar_bola()
		Estado.ROJO:
			_emision -= delta * ritmo
			if _emision <= 0.0:
				_emision = 0.07
				_giro += 0.42
				horda.ataques.bala_enemiga(position, Vector2.RIGHT.rotated(_giro) * 95.0, "moneda")
				horda.ataques.bala_enemiga(position, Vector2.LEFT.rotated(_giro) * 95.0, "moneda")
			if _reloj <= 0.0:
				_volver()
		Estado.NEGRO:
			_emision -= delta * ritmo
			if _emision <= 0.0 and _rafagas > 0:
				_rafagas -= 1
				_emision = 0.42
				_abanico(horda, 5, 0.24, 125.0, "naipe_negro")
			if _rafagas <= 0 and _reloj <= 0.0:
				_volver()
		Estado.VERDE:
			_emision -= delta * ritmo
			if _emision <= 0.0 and _rafagas > 0:
				_rafagas -= 1
				_emision = 0.45
				_anillo(horda, 24, 90.0, _rafagas * 0.13, "moneda")
			if _rafagas <= 0 and _reloj <= 0.0:
				_invocar(horda, ["ficha", "ficha", "naipe", "naipe"])
				_volver()


func _rodar(delta: float) -> void:
	position += _vel * delta
	var zona := Sala.INTERIOR.grow(-radio - 2.0)
	if position.x <= zona.position.x or position.x >= zona.end.x:
		_vel.x = -_vel.x
	if position.y <= zona.position.y or position.y >= zona.end.y:
		_vel.y = -_vel.y


func _lanzar_bola() -> void:
	var numero := randi() % 37
	_emision = 0.0
	if numero == 0:
		_estado = Estado.VERDE
		_reloj = 1.5
		_rafagas = 3
		_letrero.text = Idioma.t("0 VERDE")
	elif numero % 2 == 0:
		_estado = Estado.NEGRO
		_reloj = 1.4
		_rafagas = 3
		_letrero.text = Idioma.t("%d NEGRO") % numero
	else:
		_estado = Estado.ROJO
		_reloj = 1.5
		_letrero.text = Idioma.t("%d ROJO") % numero


func _volver() -> void:
	_estado = Estado.RODAR
	_reloj = 2.4
	_letrero.text = ""
	_vel = Vector2.RIGHT.rotated(randf() * TAU) * 135.0
