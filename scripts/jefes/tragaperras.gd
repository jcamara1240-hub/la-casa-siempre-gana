class_name JefeTragaperras
extends Jefe
## Tira de la palanca y lo que salga decide el ataque: se puede leer y prepararse.

enum Estado { ESPERA, TIRADA, ATAQUE }
const SIETE := 0
const CAMPANA := 1

var _estado := Estado.ESPERA
var _reloj := 1.2
var _rodillos: Array[Sprite2D] = []
var _resultado: Array = []
var _rafagas := 0
var _rafaga_t := 0.0


func _configurar() -> void:
	nombre = "LA TRAGAPERRAS"
	vida_base = 300.0
	texture = load("res://assets/personajes/jefe.png")
	hframes = 3
	var textura: Texture2D = load("res://assets/personajes/rodillos.png")
	for i in 3:
		var r := Sprite2D.new()
		r.texture = textura
		r.hframes = 3
		r.position = Vector2(-7 + i * 8 - 1, -2)
		r.scale = Vector2(0.8, 1.0)
		add_child(r)
		_rodillos.append(r)


func _comportamiento(delta: float, horda: Horda) -> void:
	var ritmo := 1.35 if enfadado() else 1.0
	_reloj -= delta * ritmo
	match _estado:
		Estado.ESPERA:
			frame = 0
			position += (_blanco(horda).global_position - position).normalized() * vel * delta
			if _reloj <= 0.0:
				_estado = Estado.TIRADA
				_reloj = 1.1
				_resultado = [randi() % 3, randi() % 3, randi() % 3]
		Estado.TIRADA:
			frame = 1
			for i in 3:
				var parado := _reloj < 0.75 - i * 0.3
				_rodillos[i].frame = _resultado[i] if parado else int(_t * 18.0 + i) % 3
			if _reloj <= 0.0:
				_estado = Estado.ATAQUE
				_reloj = 0.7
				_rafaga_t = 0.0
				_rafagas = 3 if enfadado() else 2
		Estado.ATAQUE:
			frame = 2
			_rafaga_t -= delta * ritmo
			if _rafaga_t <= 0.0 and _rafagas > 0:
				_rafagas -= 1
				_rafaga_t = 0.32
				_premio(horda)
			if _rafagas <= 0 and _reloj <= 0.0:
				_estado = Estado.ESPERA
				_reloj = 1.4


func _premio(horda: Horda) -> void:
	var triple: bool = _resultado[0] == _resultado[1] and _resultado[1] == _resultado[2]
	var simbolo: int = _resultado[1] if _resultado.count(_resultado[1]) >= 2 else _resultado[0]
	match simbolo:
		SIETE:
			_anillo(horda, 22 if triple else 14, 100.0, _t, "moneda")
		CAMPANA:
			_invocar(horda, ["ficha", "dado", "ficha", "dado"] if triple else ["ficha", "dado"])
			_abanico(horda, 3, 0.5, 90.0, "moneda")
		_:
			_abanico(horda, 7 if triple else 5, 0.2, 125.0, "moneda")
