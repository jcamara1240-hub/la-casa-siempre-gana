class_name Director
extends RefCounted
## La dificultad procedural. Cada sala sale de una tirada: cómo se reparte el presupuesto
## entre las oleadas (en porcentajes), qué parte de una oleada hay que matar para que entre
## la siguiente, si la sala trae una regla propia y cuánto se desvía del presupuesto normal.
## Encima va la presión, que depende de cómo juegas: si limpias sin que te toquen, la casa
## aprieta; si te están dando una paliza, afloja un poco. Nunca baja de PRESION_MIN.

const PRESION_INICIAL := 1.0
const PRESION_MIN := 0.85
const PRESION_MAX := 1.7
const SUBE_LIMPIA := 0.07  # una sala sin recibir un golpe
const SUBE_RAPIDA := 0.05  # y además dentro del tiempo de la propina
const BAJA_GOLPE := 0.05  # por cada golpe recibido en la sala
const VARIACION := 0.18  # lo que se desvía el presupuesto de una sala a otra
const SALAS_SIN_REGLA := 2  # las primeras salas de la partida no traen regla propia

## "reparto": la parte del presupuesto que se lleva cada oleada (suma 1).
## "umbral": la parte de lo que hay vivo que tienes que matar para que entre la siguiente.
const PERFILES := [
	{"nombre": "GOTEO", "reparto": [0.25, 0.25, 0.25, 0.25], "umbral": 0.5, "peso": 3.0},
	{"nombre": "CRESCENDO", "reparto": [0.15, 0.3, 0.55], "umbral": 0.6, "peso": 3.0},
	{"nombre": "AVALANCHA", "reparto": [0.55, 0.3, 0.15], "umbral": 0.7, "peso": 2.0},
	{"nombre": "EMBOSCADA", "reparto": [0.3, 0.7], "umbral": 0.8, "peso": 1.5},
	{"nombre": "ASEDIO", "reparto": [0.12, 0.16, 0.2, 0.24, 0.28], "umbral": 0.4, "peso": 1.5},
]

## Las reglas que puede traer una sala. Cada una toca un solo mando, para que se entienda.
const REGLAS := {
	"rapidos": {"nombre": "MESA CALIENTE", "desc": "LOS ENEMIGOS CORREN MÁS.", "peso": 1.5},
	"duros": {"nombre": "FICHAS DE PLOMO", "desc": "LOS ENEMIGOS AGUANTAN MÁS.", "peso": 1.5},
	"elites": {"nombre": "SALA VIP", "desc": "MUCHOS MÁS ÉLITES.", "peso": 1.2},
	"balas": {"nombre": "LLUVIA DE NAIPES", "desc": "LAS BALAS VAN MÁS RÁPIDAS.", "peso": 1.2},
	"enjambre": {"nombre": "CASA LLENA", "desc": "MUCHOS MÁS ENEMIGOS, PERO MÁS FLOJOS.", "peso": 1.0},
}
const REGLA_VEL := 1.2
const REGLA_VIDA := 1.4
const REGLA_ELITES := 3.0
const REGLA_BALAS := 1.2
const ENJAMBRE_PRESUPUESTO := 1.7
const ENJAMBRE_VIDA := 0.55


## El plan de una sala. Todo sale de azar (el de la sala, ver Juego.azar_para), así que el
## reto diario reparte las mismas tiradas a todo el mundo. La presión, que es lo único
## personal, en el reto diario va fija (Juego.presion_sala).
static func plan_sala(azar: RandomNumberGenerator, salas_limpiadas: int, piso: int, presion: float) -> Dictionary:
	var perfil: Dictionary = _elegir(azar, PERFILES)
	var regla := ""
	var prob := clampf(0.2 + (piso - 1) * 0.06 + (presion - 1.0) * 0.5, 0.0, 0.75)
	# Las dos tiradas se hacen siempre, haya regla o no: así no se descoloca el azar.
	var tirada := azar.randf()
	var candidata: String = _elegir_clave(azar, REGLAS)
	if salas_limpiadas >= SALAS_SIN_REGLA and tirada < prob:
		regla = candidata
	var presupuesto := (1.0 + azar.randf_range(-VARIACION, VARIACION)) * presion
	var vida := lerpf(1.0, presion, 0.5)
	match regla:
		"duros": vida *= REGLA_VIDA
		"enjambre":
			presupuesto *= ENJAMBRE_PRESUPUESTO
			vida *= ENJAMBRE_VIDA
	return {
		"perfil": perfil.nombre, "reparto": perfil.reparto, "umbral": perfil.umbral, "regla": regla,
		"presupuesto": presupuesto, "vida": vida,
		"vel": REGLA_VEL if regla == "rapidos" else 1.0,
		"elites": REGLA_ELITES if regla == "elites" else 1.0,
		"balas": REGLA_BALAS if regla == "balas" else 1.0,
	}


## Las cláusulas del Contrato de la Casa que tocan el plan de la sala.
## "oleadas": hay que matar menos de cada oleada para que entre la siguiente (se pisan).
const CONTRATO_UMBRAL := 0.7


static func aplicar_contrato(plan: Dictionary, contrato: Array) -> Dictionary:
	if contrato.has("oleadas"):
		plan.umbral = float(plan.umbral) * CONTRATO_UMBRAL
	return plan


## La presión después de una sala: sube si la has bordado y baja con cada golpe.
static func ajustar(presion: float, golpes: int, a_tiempo: bool) -> float:
	if golpes <= 0:
		presion += SUBE_LIMPIA + (SUBE_RAPIDA if a_tiempo else 0.0)
	else:
		presion -= BAJA_GOLPE * golpes
	return clampf(presion, PRESION_MIN, PRESION_MAX)


## Reparte un total entre las oleadas según los porcentajes. No se pierde nada al redondear.
static func repartir(total: int, reparto: Array) -> Array:
	var partes: Array = []
	var dado := 0
	for i in reparto.size():
		var parte := total - dado if i == reparto.size() - 1 else roundi(total * float(reparto[i]))
		parte = maxi(parte, 1)
		partes.append(parte)
		dado += parte
	return partes


static func _elegir(azar: RandomNumberGenerator, filas: Array) -> Dictionary:
	var suma := 0.0
	for f in filas:
		suma += float(f.peso)
	var tirada := azar.randf() * suma
	for f in filas:
		tirada -= float(f.peso)
		if tirada <= 0.0:
			return f
	return filas[0]


static func _elegir_clave(azar: RandomNumberGenerator, tabla: Dictionary) -> String:
	var suma := 0.0
	for k in tabla:
		suma += float(tabla[k].peso)
	var tirada := azar.randf() * suma
	for k in tabla:
		tirada -= float(tabla[k].peso)
		if tirada <= 0.0:
			return k
	return tabla.keys()[0]
