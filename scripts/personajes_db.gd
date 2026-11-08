class_name PersonajesDB
extends RefCounted
## Los personajes jugables y las mesas (niveles de dificultad).

const PERSONAJES := {
	"tahur": {"nombre": "El Tahúr", "desc": "Sus cartas están marcadas: +10% de golpe doble.",
		"cartas": ["bala", "abanico"], "vida": 8, "oro": 0, "efecto": {"crit": 0.1}, "requisito": ""},
	"borracho": {"nombre": "El Borracho", "desc": "Ciclos un 30% más rápidos, pero anda haciendo eses.",
		"cartas": ["molotov", "rayo"], "vida": 10, "oro": 0, "efecto": {"ciclo": 0.3, "tambaleo": 1.0},
		"requisito": "Vence al Pez Rojo."},
	"crupier": {"nombre": "La Crupier", "desc": "La tienda le cuesta un 25% menos.",
		"cartas": ["reparto", "propina"], "vida": 6, "oro": 20, "efecto": {"descuento": 0.25},
		"requisito": "Vence a 3 jefes distintos."},
	"heredera": {"nombre": "La Heredera", "desc": "Si le golpean paga 8 monedas en vez de vida.",
		"cartas": ["bala", "hucha"], "vida": 4, "oro": 40, "efecto": {"golpe_monedas": 8.0},
		"requisito": "Gana una partida."},
	"mago": {"nombre": "El Ilusionista", "desc": "Empieza con una ranura de más.",
		"cartas": ["boomerang", "doble"], "vida": 8, "oro": 0, "efecto": {}, "ranuras": 6,
		"requisito": "Consigue una transformación."},
	"guarda": {"nombre": "El Gorila", "desc": "Mucha vida, pero anda más despacio.",
		"cartas": ["taco", "bala"], "vida": 14, "oro": 0, "efecto": {"velocidad": -0.15},
		"requisito": "Elimina a 1.000 enemigos en total."},
}

const JEFES := {
	"pez": "EL PEZ ROJO", "tragaperras": "LA TRAGAPERRAS", "ruleta": "LA RULETA",
	"baccarat": "LA MOSCA CRUPIER", "blackjack": "EL REY DEL 21",
	"dados": "LOS DADOS LOCOS", "revolver": "EL REVÓLVER", "bingo": "LA BINGO",
	"trilero": "EL TRILERO MAYOR", "cajero": "LA CAJA REGISTRADORA", "coctelero": "EL COCTELERO",
	"poker": "EL JUGADOR DE PÓKER", "dueno": "EL DUEÑO DEL CASINO",
}

const MESAS := [
	{"nombre": "Mesa Blanca", "desc": "Las reglas de siempre."},
	{"nombre": "Mesa Roja", "desc": "Enemigos con un 25% más de vida."},
	{"nombre": "Mesa Verde", "desc": "Lo anterior y más enemigos en cada sala."},
	{"nombre": "Mesa Negra", "desc": "Lo anterior y la tienda un 30% más cara."},
	{"nombre": "Mesa de Oro", "desc": "Lo anterior, jefes más duros y un corazón menos."},
]


static func nombre(id: String) -> String:
	return Idioma.t(PERSONAJES[id].nombre)


static func descripcion(id: String) -> String:
	return Idioma.t(PERSONAJES[id].desc)


static func textura(id: String) -> Texture2D:
	return load("res://assets/personajes/pj_%s.png" % id)
