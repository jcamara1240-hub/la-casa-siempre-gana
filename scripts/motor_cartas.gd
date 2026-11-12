class_name MotorCartas
extends Node
## Cada ciclo lee la fila, calcula el combo y ejecuta las cartas una a una.

signal ciclo_empezado(plan: Dictionary)
signal paso_ejecutado(paso: Dictionary)
signal ciclo_terminado

# Ciclo más corto que en la ronda 1 (0,85 s, 0,1 s entre cartas y 0,55 s de reparto).
const DURACION_CICLO := 0.62
const HUECO_MAX := 0.07
const REPARTO := 0.4  # lo que pueden ocupar los huecos entre cartas en un ciclo
const ESPERA_MIN := 0.1

var ataques: Ataques
var activo := false

var _espera := 0.2
var _cola: Array = []
var _hueco := 0.1
var _pasos_ciclo := 0


func parar() -> void:
	activo = false
	_cola.clear()
	_espera = 0.15  # antes 0,3: al cerrarse la sala las cartas arrancan ya
	ciclo_terminado.emit()


## La Fiebre acelera el ciclo un 15 % por nivel (y el desatado, x1,5), encima de los objetos.
func _duracion_ciclo() -> float:
	return DURACION_CICLO / (1.0 + Juego.stat("ciclo")) / Juego.factor_fiebre()


func _physics_process(delta: float) -> void:
	if not activo:
		return
	_espera -= delta
	if _espera > 0.0:
		return
	if _cola.is_empty():
		_nuevo_ciclo()
		if _cola.is_empty():
			return
	var paso: Dictionary = _cola.pop_front()
	if not paso.ataque.is_empty():
		ataques.lanzar(paso.ataque)
	paso_ejecutado.emit(paso)
	_espera = _hueco
	if _cola.is_empty():
		_espera = maxf(_duracion_ciclo() - _hueco * _pasos_ciclo, ESPERA_MIN)


func _nuevo_ciclo() -> void:
	var plan := Combo.resolver(Juego.cartas, Juego.contexto_combo(true))
	# Récord: supera (en número entero) el mejor combo que ya llevabas en la partida.
	plan["record"] = Juego.mejor_combo > 0.0 and roundi(plan.total) > roundi(Juego.mejor_combo)
	plan["duracion"] = _duracion_ciclo()
	Juego.mejor_combo = maxf(Juego.mejor_combo, plan.total)
	if plan.coste > 0:
		Juego.gastar_oro(mini(plan.coste, Juego.oro))
	ciclo_empezado.emit(plan)
	_cola = plan.pasos.duplicate()
	if Juego.azar_combate.randf() < Juego.stat("doble_ciclo"):
		_cola += plan.pasos
	_pasos_ciclo = _cola.size()
	_hueco = minf(HUECO_MAX, REPARTO / maxf(1.0, float(_pasos_ciclo))) / Juego.factor_fiebre()
	_espera = 0.0
	if _cola.is_empty():
		_espera = _duracion_ciclo()
