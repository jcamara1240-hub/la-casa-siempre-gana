class_name Apuestas
extends RefCounted
## Las reglas de la sala de apuestas (tragaperras y ruleta), sin nada de dibujo.
##
## Cada tirada sale de la semilla de la sala y del número de tirada, no del azar común:
## recargar la partida no sirve para repetirla (la sala guarda cuántas llevas) y en el
## reto diario la tercera tirada de esa sala es la misma para todos. Lo que ganas o
## pierdes se aplica en el momento de pagar; el panel solo lo enseña después.

# ---------------------------------------------------------------- tragaperras
const PRECIO_BASE := 5  # la primera tirada del piso 1
const PRECIO_PISO := 2  # +2 por cada piso más
const PRECIO_SUBIDA := 4  # cada tirada en la misma sala cuesta 4 más que la anterior
const SIMBOLOS := ["siete", "moneda", "corazon", "carta", "diamante", "ordago", "calavera", "gato", "pistola", "antifaz"]
## Resultado, probabilidad (suman 1) y el símbolo de los rodillos. "monedas" va en veces el precio pagado.
const TABLA := [
	{"id": "777", "prob": 0.02, "simbolo": "siete", "monedas": 10},  # premio gordo: y además un objeto
	{"id": "monedas", "prob": 0.12, "simbolo": "moneda", "monedas": 3},
	{"id": "pareja", "prob": 0.16, "simbolo": "moneda", "monedas": 1},  # dos monedas: recuperas lo puesto
	{"id": "corazon", "prob": 0.05, "simbolo": "corazon"},
	{"id": "carta", "prob": 0.06, "simbolo": "carta"},
	{"id": "objeto", "prob": 0.03, "simbolo": "diamante"},
	{"id": "ordago", "prob": 0.04, "simbolo": "ordago"},
	{"id": "nada", "prob": 0.32, "simbolo": ""},
	{"id": "herida", "prob": 0.04, "simbolo": "calavera"},
	{"id": "maldicion", "prob": 0.05, "simbolo": "gato"},
	{"id": "emboscada", "prob": 0.05, "simbolo": "pistola"},
	{"id": "ladron", "prob": 0.06, "simbolo": "antifaz", "monedas": -2},
]
const MALOS := ["herida", "maldicion", "emboscada", "ladron"]
## Con suerte (Trébol, Pata de Conejo...) un resultado malo puede quedarse en nada.
const SALVA_POR_SUERTE := 0.3
const SALVA_MAX := 0.6
const CORAZON_LLENO := 2  # con la vida llena, el corazón se paga a esto por el precio
const OBJETO_AGOTADO := 5  # si ya no quedan objetos, se pagan a esto por el precio
const CARTA_SOBRANTE := 12  # con la fila llena y otra carta ya esperando, se cobra en monedas
const SUERTE_CARTA := 0.5  # las cartas de la máquina salen algo mejores que las del suelo

# Lo que vale cada premio en monedas (precios de la tienda), solo para el valor esperado.
const VALOR_CORAZON := 18.0
const VALOR_CARTA := 18.0
const VALOR_OBJETO := 30.0
const VALOR_ORDAGO := 20.0
const VALOR_MALDICION := 10.0  # una carta tuya cambiada por otra común
const VALOR_EMBOSCADA := 5.0  # una pelea corta: arriesgas vida, pero sueltan alguna moneda

# ---------------------------------------------------------------- ruleta
## La rueda europea, en su orden, y los números rojos.
const RUEDA := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14,
	31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const ROJOS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const FICHAS := [5, 10, 25]  # lo que se puede apostar al rojo o al negro (y "todo")
const APUESTA_CERO := 5  # al cero se juega siempre lo mismo...
const PAGO_CERO := 36  # ...y se cobra 36 veces (35 a 1, lo de una ruleta de verdad)
const TIRADAS_RULETA := 8  # luego el crupier cierra la mesa
const MINIMO_RUINA := 20  # para el logro de perderlo todo hay que jugarse algo de verdad


# ---------------------------------------------------------------- comunes
static func azar_de(sala: Dictionary, maquina: String) -> RandomNumberGenerator:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash("%d-%s-%d" % [int(sala.get("semilla", 0)), maquina, tiradas(sala, maquina)])
	return azar


static func tiradas(sala: Dictionary, maquina: String) -> int:
	return int(sala.get("tiradas_" + maquina, 0))


static func _contar_tirada(sala: Dictionary, maquina: String) -> void:
	sala["tiradas_" + maquina] = tiradas(sala, maquina) + 1


## Quita vida sin matar nunca: como mucho te deja en medio corazón. Devuelve lo quitado.
static func _quitar_vida(cantidad: int) -> int:
	var quitada := clampi(cantidad, 0, Juego.vida_titular() - 1)
	Juego.poner_vida(Juego.titular, Juego.vida_titular() - quitada, Juego.vida_max_titular())
	return quitada


# ---------------------------------------------------------------- tragaperras
static func precio_tragaperras(sala: Dictionary, piso: int) -> int:
	return PRECIO_BASE + PRECIO_PISO * (maxi(piso, 1) - 1) + PRECIO_SUBIDA * tiradas(sala, "tragaperras")


static func fila(id: String) -> Dictionary:
	for f in TABLA:
		if f.id == id:
			return f
	return {}


## tirada entre 0 y 1 -> id del resultado.
static func elegir_resultado(tirada: float) -> String:
	var acumulado := 0.0
	for f in TABLA:
		acumulado += float(f.prob)
		if tirada < acumulado:
			return f.id
	return "nada"


static func prob_salvar(suerte: float) -> float:
	return clampf(SALVA_POR_SUERTE * suerte, 0.0, SALVA_MAX)


## Una tirada entera: cobra, decide, aplica y devuelve lo que ha pasado
## ({"ok", "id", "rodillos", "texto", "bueno", ...}). "ok" es false si no te llega.
static func tirar_tragaperras(sala: Dictionary) -> Dictionary:
	var precio := precio_tragaperras(sala, Juego.piso)
	if Juego.oro < precio or sala.get("emboscada", false):
		return {"ok": false}
	Juego.gastar_oro(precio)
	var azar := azar_de(sala, "tragaperras")
	_contar_tirada(sala, "tragaperras")
	var id := elegir_resultado(azar.randf())
	var salva := azar.randf()  # se tira siempre: con o sin suerte, lo demás sale igual
	var salvado := false
	if MALOS.has(id) and salva < prob_salvar(Juego.stat("suerte")):
		salvado = true
	var r := aplicar_tragaperras("nada" if salvado else id, precio, sala, azar)
	r["rodillos"] = rodillos(id, azar, salvado)
	r["precio"] = precio
	if salvado:
		r["texto"] = Idioma.t("¡CASI! TU SUERTE TE LIBRA DE ALGO PEOR.")
		r["salvado"] = true
	return r


## Lo que enseñan los tres rodillos para ese resultado (sin dar a entender otro premio).
static func rodillos(id: String, azar: RandomNumberGenerator, salvado := false) -> Array:
	var f := fila(id)
	if salvado:
		# Dos malos y el tercero se queda a medias: se ve lo que ha estado a punto de pasar.
		var otro := _otro_simbolo([f.simbolo, "moneda"], azar)
		var lista: Array = [f.simbolo, f.simbolo, otro]
		return lista
	match id:
		"nada":
			var lista: Array = []
			while lista.size() < 3:
				var s: String = SIMBOLOS[azar.randi() % SIMBOLOS.size()]
				# Ni dos monedas (eso es premio) ni tres iguales.
				if lista.has(s) or (s == "moneda" and lista.has("moneda")):
					continue
				lista.append(s)
			return lista
		"pareja":
			var lista: Array = ["moneda", "moneda", "moneda"]
			lista[azar.randi() % 3] = _otro_simbolo(["moneda"], azar)
			return lista
	return [f.simbolo, f.simbolo, f.simbolo]


static func _otro_simbolo(evitar: Array, azar: RandomNumberGenerator) -> String:
	var libres: Array = SIMBOLOS.filter(func(s): return not evitar.has(s))
	return libres[azar.randi() % libres.size()]


## Aplica un resultado de la tabla. Lo usa la tirada y, una a una, las pruebas.
static func aplicar_tragaperras(id: String, precio: int, sala: Dictionary, azar: RandomNumberGenerator) -> Dictionary:
	var r := {"ok": true, "id": id, "bueno": not MALOS.has(id) and id != "nada", "texto": ""}
	match id:
		"777":
			var monedas := precio * int(fila(id).monedas)
			Juego.ganar_oro(monedas)
			var objeto := Juego.robar_objeto()
			if objeto != "":
				Juego.dar_objeto(objeto)
				r["objeto"] = objeto
				r["texto"] = Idioma.t("¡PREMIO GORDO! +%d MONEDAS Y %s.") % [monedas, ObjetosDB.nombre(objeto).to_upper()]
			else:
				r["texto"] = Idioma.t("¡PREMIO GORDO! +%d MONEDAS.") % monedas
			Juego.marcar_logro("premio_gordo")
		"monedas":
			var monedas := precio * int(fila(id).monedas)
			Juego.ganar_oro(monedas)
			r["texto"] = Idioma.t("TRES MONEDAS: +%d.") % monedas
		"pareja":
			Juego.ganar_oro(precio)
			r["texto"] = Idioma.t("DOS MONEDAS: RECUPERAS LO PUESTO.")
		"corazon":
			if Juego.vida_titular() < Juego.vida_max_titular():
				Juego.curar(2)
				r["texto"] = Idioma.t("TRES CORAZONES: RECUPERAS UNO.")
			else:
				Juego.ganar_oro(precio * CORAZON_LLENO)
				r["texto"] = Idioma.t("TRES CORAZONES, PERO ESTÁS ENTERO: +%d MONEDAS.") % (precio * CORAZON_LLENO)
		"carta":
			var carta: String = Juego.robar_cartas(1, SUERTE_CARTA)[0]
			r["carta"] = carta
			if Juego.anadir_carta(carta):
				r["texto"] = Idioma.t("UNA CARTA PARA TU FILA: %s.") % CartasDB.nombre(carta).to_upper()
			elif String(sala.get("carta_pendiente", "")) == "":
				sala["carta_pendiente"] = carta
				r["texto"] = Idioma.t("UNA CARTA: %s. AL SALIR ELIGES DÓNDE PONERLA.") % CartasDB.nombre(carta).to_upper()
			else:
				Juego.ganar_oro(CARTA_SOBRANTE)
				r.erase("carta")
				r["texto"] = Idioma.t("OTRA CARTA Y NO TE CABE: TE LA COMPRAN POR %d.") % CARTA_SOBRANTE
		"objeto":
			var objeto := Juego.robar_objeto()
			if objeto != "":
				Juego.dar_objeto(objeto)
				r["objeto"] = objeto
				r["texto"] = Idioma.t("TRES DIAMANTES: %s.") % ObjetosDB.nombre(objeto).to_upper()
			else:
				Juego.ganar_oro(precio * OBJETO_AGOTADO)
				r["texto"] = Idioma.t("TRES DIAMANTES: +%d MONEDAS.") % (precio * OBJETO_AGOTADO)
		"ordago":
			Juego.ganar_ordagos(1)
			r["texto"] = Idioma.t("TRES ÓRDAGOS: UNO MÁS PARA LA RESERVA.")
		"herida":
			var quitada := _quitar_vida(2)
			if quitada > 0:
				r["texto"] = Idioma.t("TRES CALAVERAS: PIERDES UN CORAZÓN.") if quitada == 2 else Idioma.t("TRES CALAVERAS: PIERDES MEDIO CORAZÓN.")
			else:
				r = aplicar_tragaperras("ladron", precio, sala, azar)
				r["id"] = id
		"maldicion":
			r["texto"] = _maldecir(azar, r)
		"emboscada":
			sala["emboscada"] = true
			sala["limpia"] = false
			r["texto"] = Idioma.t("TRES PISTOLAS: LOS MATONES DE LA CASA VIENEN A COBRAR.")
		"ladron":
			var quita := mini(precio * -int(fila("ladron").monedas), Juego.oro)
			Juego.gastar_oro(quita)
			r["monedas_perdidas"] = quita
			r["texto"] = Idioma.t("UN CARTERISTA TE ROBA %d MONEDAS.") % quita if quita > 0 else Idioma.t("UN CARTERISTA... PERO YA NO LLEVAS NADA.")
		_:
			r["texto"] = Idioma.t("NADA. LA MÁQUINA SE QUEDA TU DINERO.")
	return r


## Gato negro: una carta de tu fila se cambia por otra común del mismo tipo.
## Así nunca te quedas sin ataques, pero puedes perder esa legendaria que tanto te costó.
static func _maldecir(azar: RandomNumberGenerator, r: Dictionary) -> String:
	var ranuras: Array = []
	for i in Juego.cartas.size():
		if Juego.cartas[i] != "":
			ranuras.append(i)
	if ranuras.is_empty():
		return Idioma.t("UN GATO NEGRO... PERO NO TIENES CARTAS QUE MALDECIR.")
	var ranura: int = ranuras[azar.randi() % ranuras.size()]
	var vieja: String = Juego.cartas[ranura]
	var tipo: int = CartasDB.CARTAS[vieja].tipo
	var comunes: Array = CartasDB.CARTAS.keys().filter(func(id): return id != vieja and CartasDB.CARTAS[id].tipo == tipo and CartasDB.CARTAS[id].rareza == 0 and not Juego.carta_al_tope(id, ranura))
	if comunes.is_empty():
		return Idioma.t("UN GATO NEGRO... PERO NO TIENES CARTAS QUE MALDECIR.")
	var nueva: String = comunes[azar.randi() % comunes.size()]
	Juego.sustituir_carta(ranura, nueva)
	r["maldita"] = [vieja, nueva]
	return Idioma.t("UN GATO NEGRO: %s SE CONVIERTE EN %s.") % [CartasDB.nombre(vieja).to_upper(), CartasDB.nombre(nueva).to_upper()]


## Valor esperado de una tirada en monedas: [solo monedas, contando premios y castigos].
## Los premios que no son monedas se cuentan a precio de tienda (VALOR_*).
static func valor_esperado(precio: int, suerte := 0.0) -> Array:
	var salvar := prob_salvar(suerte)
	var monedas := -float(precio)
	var total := -float(precio)
	for f in TABLA:
		var p: float = f.prob
		if MALOS.has(f.id):
			p *= 1.0 - salvar
		var en_monedas := float(precio * int(f.get("monedas", 0)))
		monedas += p * en_monedas
		var extra := 0.0
		match f.id:
			"777", "objeto": extra = VALOR_OBJETO
			"corazon": extra = VALOR_CORAZON
			"carta": extra = VALOR_CARTA
			"ordago": extra = VALOR_ORDAGO
			"herida": extra = -VALOR_CORAZON
			"maldicion": extra = -VALOR_MALDICION
			"emboscada": extra = -VALOR_EMBOSCADA
		total += p * (en_monedas + extra)
	return [monedas, total]


# ---------------------------------------------------------------- ruleta
static func color_de(numero: int) -> String:
	if numero == 0:
		return "cero"
	return "rojo" if ROJOS.has(numero) else "negro"


static func mesa_abierta(sala: Dictionary) -> bool:
	return tiradas(sala, "ruleta") < TIRADAS_RULETA and not sala.get("emboscada", false)


## Sin monedas para la ficha más pequeña puedes jugarte un corazón (si te queda más de uno).
static func puede_apostar_corazon() -> bool:
	return Juego.oro < FICHAS[0] and Juego.vida_titular() > 2


## apuesta: "rojo", "negro" o "cero". cantidad: monedas; con_corazon: te juegas un corazón.
## Devuelve {"ok", "numero", "gana", "texto", ...}.
static func jugar_ruleta(sala: Dictionary, apuesta: String, cantidad: int, con_corazon := false) -> Dictionary:
	if not mesa_abierta(sala) or not ["rojo", "negro", "cero"].has(apuesta):
		return {"ok": false}
	if apuesta == "cero":
		cantidad = APUESTA_CERO
		con_corazon = false
	if con_corazon:
		if not puede_apostar_corazon() or apuesta == "cero":
			return {"ok": false}
		cantidad = 0
	elif cantidad <= 0 or not Juego.gastar_oro(cantidad):
		return {"ok": false}
	var todo := not con_corazon and Juego.oro == 0
	var azar := azar_de(sala, "ruleta")
	_contar_tirada(sala, "ruleta")
	var numero := azar.randi_range(0, 36)
	var gana := color_de(numero) == apuesta
	var r := {"ok": true, "numero": numero, "gana": gana, "apuesta": apuesta, "cantidad": cantidad, "corazon": con_corazon}
	if con_corazon:
		if gana:
			Juego.poner_vida(Juego.titular, Juego.vida_titular() + 2, Juego.vida_max_titular() + 2)
			r["texto"] = Idioma.t("¡%d! GANAS UN CORAZÓN MÁS.") % numero
		else:
			_quitar_vida(2)
			r["texto"] = Idioma.t("%d. LA CASA SE QUEDA TU CORAZÓN.") % numero
		return r
	if gana:
		var premio := cantidad * (PAGO_CERO if apuesta == "cero" else 2)
		Juego.ganar_oro(premio)
		r["premio"] = premio
		r["texto"] = Idioma.t("¡%d! COBRAS %d.") % [numero, premio]
	else:
		r["texto"] = Idioma.t("%d. LA CASA SIEMPRE GANA.") % numero
		if todo and cantidad >= MINIMO_RUINA:
			Juego.marcar_logro("a_la_ruina")
			r["texto"] = Idioma.t("%d. LO HAS PERDIDO TODO.") % numero
	return r
