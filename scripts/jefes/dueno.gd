class_name JefeDueno
extends Jefe
## El Dueño del Casino: siempre el último. A mitad de combate saca a su seguridad.

enum Estado { ANDAR, ATAQUE }
const ATAQUES := 5

var _estado := Estado.ANDAR
var _reloj := 1.2
var _turno := 0
var _segunda_fase := false
var _rafagas := 0
var _rafaga_t := 0.0


func _configurar() -> void:
	nombre = "EL DUEÑO DEL CASINO"
	vida_base = 380.0
	radio = 22.0
	vel = 32.0
	texture = load("res://assets/personajes/dueno.png")
	hframes = 3


func _comportamiento(delta: float, horda: Horda) -> void:
	if enfadado() and not _segunda_fase:
		_segunda_fase = true
		_letrero.text = Idioma.t("¡SEGURIDAD!")
		_invocar(horda, ["portero", "portero", "joker", "camara"])
		_anillo(horda, 30, 120.0, 0.0, "naipe_bala")
	var ritmo := 1.4 if _segunda_fase else 1.0
	_reloj -= delta * ritmo
	match _estado:
		Estado.ANDAR:
			frame = int(_t * 4.0) % 2
			position += (_blanco(horda).global_position - position).normalized() * vel * delta
			if _reloj <= 0.0:
				_estado = Estado.ATAQUE
				_turno = (_turno + 1) % ATAQUES
				_rafagas = 3
				_rafaga_t = 0.0
				_reloj = 0.6
		Estado.ATAQUE:
			frame = 2
			_rafaga_t -= delta * ritmo
			if _rafaga_t <= 0.0 and _rafagas > 0:
				_rafagas -= 1
				_rafaga_t = 0.42
				_golpear(horda)
			if _rafagas <= 0 and _reloj <= 0.0:
				_estado = Estado.ANDAR
				_reloj = 1.2
				_letrero.text = ""


func _golpear(horda: Horda) -> void:
	match _turno:
		0: _anillo(horda, 18, 105.0, _rafagas * 0.17, "moneda")
		1: _abanico(horda, 7, 0.18, 135.0, "naipe_negro")
		2: _muro(horda, _rafagas % 2 == 0, "naipe_bala")
		3:
			var zona := Sala.INTERIOR.grow(-30.0)
			for i in 3:
				var p: Vector2 = horda.objetivo_por_turno(i).global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, 90.0)
				horda.ataques.zona_peligro(p.clamp(zona.position, zona.end), 32.0, 0.9)
		4:
			_invocar(horda, ["dado_bomba", "ficha"])
			_anillo(horda, 10, 90.0, _t, "burbuja")
