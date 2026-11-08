class_name ObjetosDB
extends RefCounted
## Objetos pasivos, al estilo Isaac: los recoges y te cambian la partida para siempre.
## No ocupan ranura. Cada "efecto" suma a una estadística de Juego.

const PRECIO := 30

const OBJETOS := {
	"trebol": {"nombre": "Trébol de Cuatro Hojas", "desc": "Salen cartas mejores y +10% de golpe doble.", "efecto": {"suerte": 1.0, "crit": 0.1}},
	"herradura": {"nombre": "Herradura", "desc": "+1 corazón y te cura del todo.", "efecto": {"vida_max": 2}},
	"dado_cargado": {"nombre": "Dado Cargado", "desc": "+15% de golpe doble.", "efecto": {"crit": 0.15}},
	"zapatos": {"nombre": "Zapatos de Charol", "desc": "Te mueves un 20% más rápido.", "efecto": {"velocidad": 0.2}},
	"traje": {"nombre": "Traje de Etiqueta", "desc": "Tras un golpe eres invulnerable más tiempo.", "efecto": {"invulnerable": 0.5}},
	"gafas": {"nombre": "Gafas de Sol", "desc": "Las balas enemigas van un 25% más lentas.", "efecto": {"bala_lenta": 0.25}},
	"puro": {"nombre": "Puro Habano", "desc": "El humo quema a los enemigos que se te acercan.", "efecto": {"puro": 1.0}},
	"whisky": {"nombre": "Whisky Doble", "desc": "Los ciclos de cartas son un 15% más rápidos.", "efecto": {"ciclo": 0.15}},
	"reloj": {"nombre": "Reloj de Oro", "desc": "Los ciclos un 10% más rápidos y +5 monedas.", "efecto": {"ciclo": 0.1, "monedas": 5}},
	"tarjeta": {"nombre": "Tarjeta VIP", "desc": "Todo cuesta un 30% menos en la tienda.", "efecto": {"descuento": 0.3}},
	"saco": {"nombre": "Saco de Monedas", "desc": "Cada sala limpiada te da 3 monedas.", "efecto": {"monedas_sala": 3}},
	"iman": {"nombre": "Imán", "desc": "Atraes las monedas desde mucho más lejos.", "efecto": {"iman": 1.0}},
	"cartera": {"nombre": "Cartera de Piel", "desc": "Al bajar de piso cobras un 25% de intereses.", "efecto": {"intereses": 0.25}},
	"ficha_vip": {"nombre": "Ficha VIP", "desc": "+1 ranura para cartas.", "efecto": {"ranura": 1}},
	"baraja_doble": {"nombre": "Baraja Doble", "desc": "20% de que un ciclo se ejecute dos veces.", "efecto": {"doble_ciclo": 0.2}},
	"anillo_sello": {"nombre": "Anillo de Sello", "desc": "Todos tus ataques hacen +1 de daño.", "efecto": {"dano_global": 1.0}},
	"baston": {"nombre": "Bastón de Caballero", "desc": "Te mueves un 10% más rápido y aguantas mejor los golpes.", "efecto": {"velocidad": 0.1, "invulnerable": 0.2}},
	"pajarita": {"nombre": "Pajarita", "desc": "La tienda te cuesta un 15% menos.", "efecto": {"descuento": 0.15}},
	"cerveza": {"nombre": "Jarra de Cerveza", "desc": "Ciclos un 20% más rápidos, pero andas un 10% más lento.", "efecto": {"ciclo": 0.2, "velocidad": -0.1}},
	"pata_conejo": {"nombre": "Pata de Conejo", "desc": "Salen cartas mejores y +5% de golpe doble.", "efecto": {"suerte": 1.0, "crit": 0.05}},
	"fajo": {"nombre": "Fajo de Billetes", "desc": "+30 monedas al momento.", "efecto": {"monedas": 30}},
	"manga": {"nombre": "Manga de Tahúr", "desc": "+10% de ciclo doble y +5% de golpe doble.", "efecto": {"doble_ciclo": 0.1, "crit": 0.05}},
	"corbata": {"nombre": "Corbata Roja", "desc": "Ataques con +1 de daño y un 5% más de velocidad.", "efecto": {"dano_global": 1.0, "velocidad": 0.05}},
	"antifaz": {"nombre": "Antifaz", "desc": "Tras un golpe eres invulnerable mucho más tiempo.", "efecto": {"invulnerable": 0.6}},
	"guantes": {"nombre": "Guantes Blancos", "desc": "Atraes las monedas y ganas 1 extra por sala.", "efecto": {"iman": 1.0, "monedas_sala": 1}},
	"chapa": {"nombre": "Chapa de Seguridad", "desc": "Las balas enemigas van un 15% más lentas.", "efecto": {"bala_lenta": 0.15}},
	"mechero": {"nombre": "Mechero de Oro", "desc": "Todos tus ataques queman a los enemigos.", "efecto": {"quema_global": 1.0}},
	"seguro": {"nombre": "Seguro de la Banca", "desc": "Ignoras el primer golpe de cada sala.", "efecto": {"seguro": 1.0}},
}

# Isaac-style: reúne las piezas necesarias de un conjunto y te transformas.
const TRANSFORMACIONES := {
	"mafioso": {"nombre": "El Mafioso", "desc": "Todos tus ataques hacen +2 de daño.", "color": "#a89a8e",
		"piezas": ["traje", "puro", "whisky", "gafas"], "necesarias": 3, "efecto": {"dano_global": 2.0}},
	"suertudo": {"nombre": "El Suertudo", "desc": "Tus golpes dobles hacen daño triple.", "color": "#6ccf94",
		"piezas": ["trebol", "herradura", "dado_cargado", "ficha_vip"], "necesarias": 3, "efecto": {"crit_mult": 1.0, "crit": 0.05}},
	"magnate": {"nombre": "El Magnate", "desc": "Cada moneda que recoges vale doble.", "color": "#f7c64a",
		"piezas": ["tarjeta", "saco", "cartera", "reloj", "iman"], "necesarias": 3, "efecto": {"moneda_extra": 1.0}},
	"fullero": {"nombre": "El Fullero", "desc": "+30% de que un ciclo se ejecute dos veces.", "color": "#d63d4f",
		"piezas": ["baraja_doble", "dado_cargado", "ficha_vip"], "necesarias": 2, "efecto": {"doble_ciclo": 0.3}},
	"bribon": {"nombre": "El Bribón", "desc": "Golpe doble +15%. Nadie lo ha visto venir.", "color": "#7a5aa0",
		"piezas": ["manga", "antifaz", "guantes"], "necesarias": 2, "efecto": {"crit": 0.15}},
	"gran_jefe": {"nombre": "El Gran Jefe", "desc": "Todos tus ataques hacen +3 de daño.", "color": "#f0813c",
		"piezas": ["anillo_sello", "corbata", "baston", "pajarita"], "necesarias": 3, "efecto": {"dano_global": 3.0}},
	"noctambulo": {"nombre": "El Noctámbulo", "desc": "+15% de velocidad y más invulnerabilidad.", "color": "#6fc3e8",
		"piezas": ["zapatos", "gafas", "reloj", "traje"], "necesarias": 3, "efecto": {"velocidad": 0.15, "invulnerable": 0.4}},
}


## La descripción con sus piezas, para que el jugador sepa qué buscar.
static func descripcion_transformacion(id: String) -> String:
	var datos: Dictionary = TRANSFORMACIONES[id]
	var piezas: Array = datos.piezas.map(func(p): return nombre(p))
	return "%s %s %s" % [Idioma.t(datos.desc), Idioma.t("REÚNE %d DE:") % int(datos.necesarias), ", ".join(piezas)]


static func nombre(id: String) -> String:
	return Idioma.t(OBJETOS[id].nombre)


static func descripcion(id: String) -> String:
	return Idioma.t(OBJETOS[id].desc)


static func textura(id: String) -> Texture2D:
	return load("res://assets/pasivos/%s.png" % id)
