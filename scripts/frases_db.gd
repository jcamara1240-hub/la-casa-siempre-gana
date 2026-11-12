class_name FrasesDB
extends RefCounted
## Lo que dice el Dueño del casino al acabar la partida, según qué te mató y cómo.
##
## Cada frase lleva sus condiciones en "si" (todas tienen que cumplirse) y una prioridad:
## entre las que valen se prefieren las que aún no has visto y, de esas, las más concretas
## (un jefe pesa más que "has caído en el piso 1", y eso más que una frase de relleno).
## Sin "gano" en las condiciones, la frase es solo para cuando pierdes.
##
## Condiciones: "gano": true, "jefe": id, "enemigo": tipo, "rango": 1 (raro) o 2 (élite),
## "apuestas": true (caíste en la sala de apuestas), "piso_max"/"piso_min": n,
## "racha_min": derrotas seguidas, "modo": "diario", "infinito" o "extremo" (incluye imposible).

const FRASES := {
	# Jefes
	"jefe_pez": {"si": {"jefe": "pez"}, "prio": 5, "texto": "EL PEZ ROJO ERA EL APERITIVO. Y EL QUE HA COMIDO ES ÉL."},
	"jefe_tragaperras": {"si": {"jefe": "tragaperras"}, "prio": 5, "texto": "LA MÁQUINA NO TE ODIA. SIMPLEMENTE ESTÁ PROGRAMADA ASÍ."},
	"jefe_ruleta": {"si": {"jefe": "ruleta"}, "prio": 5, "texto": "LA BOLA SIEMPRE CAE DONDE YO QUIERO."},
	"jefe_baccarat": {"si": {"jefe": "baccarat"}, "prio": 5, "texto": "LA MOSCA REPARTE MEJOR QUE MEDIA PLANTILLA. SE LO RECUERDO A MENUDO."},
	"jefe_blackjack": {"si": {"jefe": "blackjack"}, "prio": 5, "texto": "TÚ TE PASASTE DE 21. LA BANCA NO SE PASA NUNCA."},
	"jefe_dados": {"si": {"jefe": "dados"}, "prio": 5, "texto": "LOS DADOS NO TIENEN MEMORIA. YO SÍ, Y PIENSO RECORDAR ESTO."},
	"jefe_revolver": {"si": {"jefe": "revolver"}, "prio": 5, "texto": "SEIS RECÁMARAS, Y TÚ SIEMPRE DELANTE DE LA PEOR."},
	"jefe_bingo": {"si": {"jefe": "bingo"}, "prio": 5, "texto": "¡LÍNEA! ¡BINGO! Y TÚ, A LA CALLE."},
	"jefe_trilero": {"si": {"jefe": "trilero"}, "prio": 5, "texto": "LA BOLITA NUNCA ESTUVO DEBAJO DE NINGÚN CUBILETE."},
	"jefe_cajero": {"si": {"jefe": "cajero"}, "prio": 5, "texto": "LA CAJA REGISTRADORA TE HA COBRADO LA ENTRADA. CON INTERESES."},
	"jefe_coctelero": {"si": {"jefe": "coctelero"}, "prio": 5, "texto": "TU ÚLTIMA COPA DE LA NOCHE. INVITA LA CASA."},
	"jefe_poker": {"si": {"jefe": "poker"}, "prio": 5, "texto": "TU CARA DE PÓKER NECESITA PRÁCTICA. TUS PIERNAS, TAMBIÉN."},
	"jefe_dueno": {"si": {"jefe": "dueno"}, "prio": 6, "texto": "LLEGAR HASTA MÍ TIENE MÉRITO. SALIR, NINGUNO LO HA CONSEGUIDO."},
	# Rangos y enemigos concretos
	"elite": {"si": {"rango": 2}, "prio": 4, "texto": "ESE ÉLITE COBRA MÁS QUE TÚ. AHORA YA SABES POR QUÉ."},
	"elite_2": {"si": {"rango": 2}, "prio": 4, "texto": "LOS DORADOS SON PERSONAL DE CONFIANZA. NO SE TOCAN."},
	"raro": {"si": {"rango": 1}, "prio": 3, "texto": "UN RARO. QUÉ MALA SUERTE TAN POCO FRECUENTE."},
	"dado_bomba": {"si": {"enemigo": "dado_bomba"}, "prio": 3, "texto": "EL DADO BOMBA SACÓ UN SEIS. PARA ÉL, CLARO."},
	"ratero": {"si": {"enemigo": "ratero"}, "prio": 3, "texto": "UN RATERO TE HA QUITADO LO ÚNICO QUE TE QUEDABA."},
	"maton": {"si": {"enemigo": "maton"}, "prio": 3, "texto": "EL MATÓN SOLO HACÍA SU TRABAJO. Y LO HACE MUY BIEN."},
	"ficha": {"si": {"enemigo": "ficha"}, "prio": 3, "texto": "UNA FICHA. TE HA TUMBADO UNA FICHA. LO DEJO POR ESCRITO."},
	"camara": {"si": {"enemigo": "camara"}, "prio": 3, "texto": "LA CÁMARA LO HA GRABADO TODO. SALDRÁ EN LA CENA DE EMPRESA."},
	# Sala de apuestas
	"apuestas": {"si": {"apuestas": true}, "prio": 4, "texto": "QUIEN JUEGA EN MI SALA DE APUESTAS YA HA PERDIDO. LO DEMÁS ES PAPELEO."},
	"apuestas_2": {"si": {"apuestas": true}, "prio": 4, "texto": "LA EMBOSCADA VENÍA EN LA LETRA PEQUEÑA."},
	# Pisos
	"piso_1": {"si": {"piso_max": 1}, "prio": 2, "texto": "¿YA? SI AÚN NO HABÍAS PEDIDO NI UNA COPA."},
	"piso_1_b": {"si": {"piso_max": 1}, "prio": 2, "texto": "EL PRIMER PISO ES EL VESTÍBULO. HAS CAÍDO EN EL VESTÍBULO."},
	"piso_hondo": {"si": {"piso_min": 4}, "prio": 2, "texto": "TAN CERCA DE MI DESPACHO... CASI ME LEVANTO A SALUDAR."},
	"piso_hondo_2": {"si": {"piso_min": 4}, "prio": 2, "texto": "HAS BAJADO MUCHO. LA SUBIDA HASTA EL MENÚ SE HACE LARGA."},
	# Rachas de derrotas
	"racha_3": {"si": {"racha_min": 3}, "prio": 3, "texto": "OTRA VEZ TÚ. EMPIEZO A GUARDARTE MESA."},
	"racha_3_b": {"si": {"racha_min": 3}, "prio": 3, "texto": "LA CONSTANCIA ES UNA VIRTUD. AQUÍ, ADEMÁS, ES UN NEGOCIO."},
	"racha_6": {"si": {"racha_min": 6}, "prio": 4, "texto": "A ESTAS ALTURAS DEBERÍA PAGARTE YO A TI. NO LO HARÉ."},
	# Modos
	"modo_diario": {"si": {"modo": "diario"}, "prio": 3, "texto": "MUCHOS HAN PERDIDO EL RETO DE HOY. TÚ, CON ESTILO PROPIO."},
	"modo_infinito": {"si": {"modo": "infinito"}, "prio": 3, "texto": "EN EL MODO INFINITO NO HAY SALIDA. SOLO HAY MÁS PISOS."},
	"modo_extremo": {"si": {"modo": "extremo"}, "prio": 3, "texto": "UN GOLPE Y A CASA. LO PONÍA EN LA PUERTA."},
	# Victorias
	"gano": {"si": {"gano": true}, "prio": 1, "texto": "ENHORABUENA. LA CASA HA TOMADO NOTA DE TU CARA."},
	"gano_2": {"si": {"gano": true}, "prio": 1, "texto": "HAS GANADO. DISFRÚTALO: NO SUELE REPETIRSE."},
	"gano_extremo": {"si": {"gano": true, "modo": "extremo"}, "prio": 3, "texto": "SIN UN RASGUÑO DE SOBRA. A PARTIR DE HOY TE VIGILO YO."},
	"gano_diario": {"si": {"gano": true, "modo": "diario"}, "prio": 3, "texto": "HOY GANAS TÚ. MAÑANA CAMBIO LAS CERRADURAS."},
	# Para cualquier derrota
	"general_1": {"si": {}, "prio": 0, "texto": "LA CASA SIEMPRE GANA. ESTÁ EN EL NOMBRE."},
	"general_2": {"si": {}, "prio": 0, "texto": "NO TE LO TOMES COMO ALGO PERSONAL. ES ESTADÍSTICA."},
	"general_3": {"si": {}, "prio": 0, "texto": "TU FICHA ESTÁ EN LA MESA. Y AHÍ SE QUEDA."},
	"general_4": {"si": {}, "prio": 0, "texto": "GRACIAS POR JUGAR. LA SALIDA ESTÁ DETRÁS DE LA ENTRADA."},
	"general_5": {"si": {}, "prio": 0, "texto": "LA PRÓXIMA VEZ, ORDENA MEJOR LAS CARTAS."},
	"general_6": {"si": {}, "prio": 0, "texto": "EL GUARDARROPA TE DEVUELVE EL ABRIGO. LA DIGNIDAD, NO."},
}


## Lo que sabe el Dueño de la partida que acaba de terminar.
static func contexto_actual(gano: bool) -> Dictionary:
	var modo := "normal"
	if Juego.diario:
		modo = "diario"
	elif Juego.infinito:
		modo = "infinito"
	elif Juego.extremo:
		modo = "extremo"
	return {"gano": gano, "causa": Juego.ultima_causa, "piso": Juego.piso, "modo": modo,
		"racha": int(Progreso.contadores.get("derrotas_seguidas", 0))}


static func cumple(id: String, ctx: Dictionary) -> bool:
	var si: Dictionary = FRASES[id].si
	if bool(si.get("gano", false)) != bool(ctx.get("gano", false)):
		return false
	var causa: Dictionary = ctx.get("causa", {})
	for clave in si:
		match String(clave):
			"jefe":
				if causa.get("tipo", "") != "jefe" or causa.get("id", "") != si.jefe:
					return false
			"enemigo":
				if causa.get("tipo", "") != "enemigo" or causa.get("id", "") != si.enemigo:
					return false
			"rango":
				if causa.get("tipo", "") != "enemigo" or int(causa.get("rango", 0)) != int(si.rango):
					return false
			"apuestas":
				if not causa.get("apuestas", false):
					return false
			"piso_max":
				if int(ctx.get("piso", 1)) > int(si.piso_max) or ctx.get("modo", "") == "infinito":
					return false
			"piso_min":
				if int(ctx.get("piso", 1)) < int(si.piso_min) or ctx.get("modo", "") == "infinito":
					return false
			"racha_min":
				if int(ctx.get("racha", 0)) < int(si.racha_min):
					return false
			"modo":
				if ctx.get("modo", "") != si.modo:
					return false
	return true


## El id de la frase que toca (o "" si ninguna vale): primero las no vistas y, de esas,
## las de más prioridad; entre las empatadas, al azar.
static func elegir(ctx: Dictionary, vistas: Array, rng: RandomNumberGenerator) -> String:
	var validas: Array = FRASES.keys().filter(func(id): return cumple(id, ctx))
	if validas.is_empty():
		return ""
	var nuevas: Array = validas.filter(func(id): return not vistas.has(id))
	var bolsa: Array = nuevas if not nuevas.is_empty() else validas
	var mejor := -1
	for id in bolsa:
		mejor = maxi(mejor, int(FRASES[id].prio))
	var top: Array = bolsa.filter(func(id): return int(FRASES[id].prio) == mejor)
	return top[rng.randi() % top.size()]


static func texto(id: String) -> String:
	return Idioma.t(FRASES[id].texto) if FRASES.has(id) else ""
