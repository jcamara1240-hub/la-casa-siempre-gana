class_name Combo
extends RefCounted
## El corazón del juego: convierte una fila de cartas en un plan de ataque.
##
## Se lee de izquierda a derecha:
##   - Un modificador se guarda y lo gasta el siguiente ataque.
##   - Un ataque se apunta con lo que llevara acumulado.
##   - Un multiplicador solo afecta a lo que ya está apuntado (lo de su izquierda).
##
## Cada paso lleva además su aporte al total, para enseñar la cuenta carta a carta:
## "aporte" es "suma", "mult" o "" (no cambia el total) y "valor" lo que suma o multiplica.
## Rehaciendo la cuenta con esos pasos, en orden, sale exactamente "total".
##
## "ctx" lleva lo que depende de la partida (monedas, racha, vida, fiebre, voltereta,
## órdagos y azar). Sin azar se usa el valor medio: así la barra enseña una previsión
## sin tirar la moneda. Esta clase no toca la escena, así que se puede probar sola.

const PROB_RULETA := 6  # la Ruleta Rusa acierta una de cada seis
const PREMIO_RULETA := 6.0


static func _pendiente_vacio() -> Dictionary:
	return {"dano": 0.0, "pct": 0.0, "n": 0, "perfora": 0, "rebote": 0, "quema": 0, "frio": 0,
		"crit": 0.0, "oro": 0, "busca": 0, "empuje": 0, "metralla": 0, "calibre": 0, "ranuras": []}


## Un ataque fuera de la fila (lo lanzan los objetos), con todos sus campos.
static func ataque_suelto(id: String, dano: float, n: int) -> Dictionary:
	if not CartasDB.CARTAS.has(id) or CartasDB.CARTAS[id].tipo != CartasDB.Tipo.ATAQUE:
		id = "bala"
	var a := _crear_ataque(id, CartasDB.CARTAS[id], _pendiente_vacio(), {"dano": 0.0, "perfora": 0}, {})
	a.dano = dano
	a.n = n
	a.premio = false
	return a


static func resolver(fila: Array, ctx := {}) -> Dictionary:
	var pendiente := _pendiente_vacio()
	var aura := {"dano": float(ctx.get("dano_global", 0.0)), "perfora": 0}
	var ataques: Array = []
	var pasos: Array = []
	var total := 0.0
	var coste := 0
	var efectivas: Array = []  # lo que hay a la izquierda, con los comodines ya resueltos
	var multiplicadores := _contar_multiplicadores(fila)

	for i in fila.size():
		var id: String = fila[i]
		if id == "":
			continue
		var sin_copia := false
		if id == "comodin":
			if efectivas.is_empty():
				sin_copia = true
			else:
				id = efectivas[-1]
		var carta: Dictionary = CartasDB.CARTAS[id]
		var paso := {"ranura": i, "tipo": carta.tipo, "texto": "", "ataque": {}, "sin_efecto": sin_copia,
			"aporte": "", "valor": 0.0}

		if not sin_copia:
			match carta.tipo:
				CartasDB.Tipo.MODIFICADOR:
					_aplicar_modificador(carta, pendiente, aura, ctx, pasos.size(), efectivas.size())
					paso.texto = carta.nombre

				CartasDB.Tipo.ATAQUE:
					var ataque := _crear_ataque(id, carta, pendiente, aura, ctx)
					ataques.append(ataque)
					pendiente = _pendiente_vacio()
					total += ataque.dano * ataque.n
					paso.ataque = ataque
					paso.texto = "+%d" % roundi(ataque.dano * ataque.n)
					paso.aporte = "suma"
					paso.valor = ataque.dano * ataque.n

				CartasDB.Tipo.MULTIPLICADOR:
					if carta.mult == "eco":
						if ataques.is_empty():
							paso.sin_efecto = true
						else:
							var copia: Dictionary = ataques[-1].duplicate()
							copia.dano = copia.dano * 0.5
							ataques.append(copia)
							total += copia.dano * copia.n
							paso.ataque = copia
							paso.texto = "+%d" % roundi(copia.dano * copia.n)
							paso.aporte = "suma"
							paso.valor = copia.dano * copia.n
					else:
						var factor := _factor(carta, ataques.size(), efectivas, i, fila, multiplicadores, ctx)
						if ataques.is_empty() or is_equal_approx(factor, 1.0):
							paso.sin_efecto = true
						else:
							for a in ataques:
								a.dano *= factor
							total *= factor
							paso.aporte = "mult"
							paso.valor = factor
							if carta.mult == "casa":
								coste += 1
						paso.texto = "x%s" % _numero(factor)
			efectivas.append(id)

		paso["total"] = total
		pasos.append(paso)

	# Los modificadores que se quedan sin ataque a su derecha no hacen nada: se avisa.
	for indice in pendiente.ranuras:
		pasos[indice].sin_efecto = true

	return {"pasos": pasos, "ataques": ataques, "total": total, "coste": coste}


static func _contar_multiplicadores(fila: Array) -> int:
	var cuantos := 0
	for id in fila:
		if id != "" and CartasDB.CARTAS[id].tipo == CartasDB.Tipo.MULTIPLICADOR and CartasDB.CARTAS[id].mult != "eco":
			cuantos += 1
	return cuantos


static func _aplicar_modificador(carta: Dictionary, p: Dictionary, aura: Dictionary, ctx: Dictionary, indice: int, a_la_izquierda: int) -> void:
	match String(carta.mod):
		"aura":
			aura.dano += float(carta.valor)
			return
		"aura_perfora":
			aura.perfora += int(carta.valor)
			return
		"resto":
			p.dano += floorf(float(ctx.get("monedas", 0)) / float(carta.valor))
		"comodin":
			return
		"corte":
			p.n += int(carta.valor)
			p.pct -= 0.3
		"sobre":
			p.dano += float(a_la_izquierda)
		"mano":
			p.dano += float(carta.valor)
			p.quema += 1
		"calibre":
			p.dano += float(carta.valor)
			p.calibre += 1
		_:
			p[carta.mod] += carta.valor
	p.ranuras.append(indice)


static func _crear_ataque(id: String, carta: Dictionary, p: Dictionary, aura: Dictionary, ctx: Dictionary) -> Dictionary:
	var perfora: int = int(carta.get("perfora", 0)) + p.perfora + aura.perfora
	var rebote: int = int(carta.get("rebote", 0)) + p.rebote
	var a := {
		"id": id,
		"dano": (float(carta.dano) + p.dano + aura.dano) * (1.0 + p.pct),
		"n": int(carta.n) + p.n,
		"perfora": perfora,
		"rebote": rebote,
		"quema": int(carta.get("quema", 0)) + p.quema,
		"frio": p.frio,
		"crit": p.crit + float(carta.get("crit", 0.0)),
		"oro": p.oro,
		"azar": carta.get("azar", false),
		"vuelve": carta.get("vuelve", false),
		"radio": float(carta.get("radio", 34.0)),
		"duracion": 0.9,
		"busca": int(p.busca),
		"empuje": int(p.empuje),
		"metralla": int(p.metralla),
		"calibre": int(p.calibre),
		"paredes": int(carta.get("paredes", 0)),  # rebotes contra las paredes de la sala
		"premio": false,  # la Ruleta Rusa ha salido x6
	}
	# Atravesar y rebotar no significan nada en un ataque sin proyectil: se traducen.
	match id:
		"rayo":
			a.n += p.rebote + p.perfora / 2
		"explosion", "molotov", "lluvia", "jackpot", "bola8", "dinamita", "mina", "botella":
			a.radio += 7.0 * (p.perfora + p.rebote)
		"cuchilla", "ruleta_gira":
			a.duracion += 0.2 * (p.perfora + p.rebote)
		"laser":
			# El láser ya lo atraviesa todo: atravesar lo ensancha y rebotar lo refleja en las paredes.
			a.radio = 4.0 + 3.0 * p.perfora
			a.paredes += p.rebote
		"ruleta_rusa":
			var azar = ctx.get("azar")
			if azar == null:
				a.dano *= (PROB_RULETA - 1 + PREMIO_RULETA) / PROB_RULETA  # previsión: el daño medio
			elif azar.randi_range(1, PROB_RULETA) == PROB_RULETA:
				a.dano *= PREMIO_RULETA
				a.premio = true
	return a


static func _factor(carta: Dictionary, n_ataques: int, izquierda: Array, ranura: int, fila: Array, multiplicadores: int, ctx: Dictionary) -> float:
	var valor := float(carta.get("valor", 1.0))
	match String(carta.mult):
		"escalera":
			return 1.0 + valor * n_ataques
		"iguales":
			return valor if _max_repetidas(izquierda) >= int(carta.cuantas) else 1.0
		"full":
			return valor if _hay_full(izquierda) else 1.0
		"color":
			return valor if _mismo_tipo(izquierda) else 1.0
		"cara_cruz":
			var azar = ctx.get("azar")
			if azar == null:
				return 2.0
			return 3.0 if azar.randf() < 0.5 else 1.0
		"all_in":
			return valor if ranura == fila.size() - 1 and not fila.has("") else 1.0
		"doble_pareja":
			return valor if _repeticiones(izquierda).values().filter(func(v): return v >= 2).size() >= 2 else 1.0
		"carta_alta":
			return valor if n_ataques == 1 else 1.0
		"siete":
			return valor if izquierda.size() == 7 else 1.0
		"tres_ataques":
			return valor if n_ataques == 3 else 1.0
		"bancarrota":
			return valor if int(ctx.get("monedas", 1)) == 0 else 1.0
		"mesa_llena":
			return 1.0 + valor * fila.filter(func(c): return c != "").size()
		"rojo_negro":
			return valor if ranura % 2 == 0 else 1.0
		"racha":
			return 1.0 + valor * int(ctx.get("racha", 0))
		"hucha":
			return 1.0 + valor * floori(float(ctx.get("monedas", 0)) / 10.0)
		"mano_muerta":
			return valor if int(ctx.get("vida", 99)) <= 2 else 1.0
		"solitario":
			return valor if multiplicadores == 1 else 1.0
		"casa":
			return valor if int(ctx.get("monedas", 1)) > 0 else 1.0
		"fiebre":
			return 1.0 + valor * clampi(int(ctx.get("fiebre", 0)), 0, 3)
		"voltereta":
			return valor if bool(ctx.get("voltereta", false)) else 1.0
		"ordago":
			return 1.0 + valor * maxi(int(ctx.get("ordagos", 0)), 0)
	return valor


static func _repeticiones(ids: Array) -> Dictionary:
	var cuenta := {}
	for id in ids:
		cuenta[id] = int(cuenta.get(id, 0)) + 1
	return cuenta


static func _max_repetidas(ids: Array) -> int:
	var maximo := 0
	for v in _repeticiones(ids).values():
		maximo = maxi(maximo, v)
	return maximo


static func _hay_full(ids: Array) -> bool:
	var valores: Array = _repeticiones(ids).values()
	valores.sort()
	return valores.size() >= 2 and valores[-1] >= 3 and valores[-2] >= 2


static func _mismo_tipo(ids: Array) -> bool:
	if ids.size() < 3:
		return false
	for id in ids:
		if CartasDB.CARTAS[id].tipo != CartasDB.CARTAS[ids[0]].tipo:
			return false
	return true


static func _numero(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else "%.2f" % v if is_equal_approx(fmod(v * 4.0, 2.0), 1.0) else "%.1f" % v
