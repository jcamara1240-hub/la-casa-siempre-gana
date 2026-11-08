class_name MotorCartas
extends Node
## Cada ciclo lee la fila, calcula el combo y ejecuta las cartas una a una.

signal ciclo_empezado(plan: Dictionary)
signal paso_ejecutado(paso: Dictionary)
signal ciclo_terminado

const DURACION_CICLO := 0.85

var ataques: Ataques
var activo := false

var _espera := 0.2
var _cola: Array = []
var _hueco := 0.1
var _pasos_ciclo := 0


func parar() -> void:
	activo = false
	_cola.clear()
	_espera = 0.3
	ciclo_terminado.emit()


func _duracion_ciclo() -> float:
	return DURACION_CICLO / (1.0 + Juego.stat("ciclo"))


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
		_espera = maxf(_duracion_ciclo() - _hueco * _pasos_ciclo, 0.15)


func _nuevo_ciclo() -> void:
	var plan := Combo.resolver(Juego.cartas, Juego.contexto_combo(true))
	Juego.mejor_combo = maxf(Juego.mejor_combo, plan.total)
	if plan.coste > 0:
		Juego.gastar_oro(mini(plan.coste, Juego.oro))
	ciclo_empezado.emit(plan)
	_cola = plan.pasos.duplicate()
	if Juego.azar.randf() < Juego.stat("doble_ciclo"):
		_cola += plan.pasos
	_pasos_ciclo = _cola.size()
	_hueco = minf(0.1, 0.55 / maxf(1.0, float(_pasos_ciclo)))
	_espera = 0.0
	if _cola.is_empty():
		_espera = _duracion_ciclo()
