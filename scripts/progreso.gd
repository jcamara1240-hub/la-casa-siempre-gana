class_name Progreso
extends RefCounted
## Lo que se conserva entre partidas: desbloqueos, jefes vencidos y mesas.

const RUTA := "user://progreso.cfg"
const RARAS_INICIALES := ["cuchilla", "explosion", "nova", "doble", "rebote", "eco", "escalera", "subir", "doble_nada"]
const OBJETOS_INICIALES := ["herradura", "zapatos", "gafas", "whisky", "tarjeta", "saco", "iman", "seguro"]

static var partidas := 0
static var victorias := 0
static var victorias_extremo := 0
static var mejor_infinito := 0
static var mesa_max := 0
static var jefes_vencidos: Array = []
static var cartas_extra: Array = []
static var objetos_extra: Array = []
static var personajes: Array = ["tahur"]
static var transformaciones: Array = []
static var logros: Array = []
static var contadores: Dictionary = {}
static var personajes_ganadores: Array = []
static var reto_fecha := ""
static var reto_mejor := 0


static func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return
	partidas = cfg.get_value("progreso", "partidas", 0)
	victorias = cfg.get_value("progreso", "victorias", 0)
	victorias_extremo = cfg.get_value("progreso", "victorias_extremo", 0)
	mejor_infinito = cfg.get_value("progreso", "mejor_infinito", 0)
	mesa_max = cfg.get_value("progreso", "mesa_max", 0)
	jefes_vencidos = cfg.get_value("progreso", "jefes_vencidos", [])
	cartas_extra = cfg.get_value("progreso", "cartas_extra", [])
	objetos_extra = cfg.get_value("progreso", "objetos_extra", [])
	personajes = cfg.get_value("progreso", "personajes", ["tahur"])
	transformaciones = cfg.get_value("progreso", "transformaciones", [])
	logros = cfg.get_value("progreso", "logros", [])
	contadores = cfg.get_value("progreso", "contadores", {})
	personajes_ganadores = cfg.get_value("progreso", "personajes_ganadores", [])
	reto_fecha = cfg.get_value("progreso", "reto_fecha", "")
	reto_mejor = cfg.get_value("progreso", "reto_mejor", 0)


static func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progreso", "partidas", partidas)
	cfg.set_value("progreso", "victorias", victorias)
	cfg.set_value("progreso", "victorias_extremo", victorias_extremo)
	cfg.set_value("progreso", "mejor_infinito", mejor_infinito)
	cfg.set_value("progreso", "mesa_max", mesa_max)
	cfg.set_value("progreso", "jefes_vencidos", jefes_vencidos)
	cfg.set_value("progreso", "cartas_extra", cartas_extra)
	cfg.set_value("progreso", "objetos_extra", objetos_extra)
	cfg.set_value("progreso", "personajes", personajes)
	cfg.set_value("progreso", "transformaciones", transformaciones)
	cfg.set_value("progreso", "logros", logros)
	cfg.set_value("progreso", "contadores", contadores)
	cfg.set_value("progreso", "personajes_ganadores", personajes_ganadores)
	cfg.set_value("progreso", "reto_fecha", reto_fecha)
	cfg.set_value("progreso", "reto_mejor", reto_mejor)
	cfg.save(RUTA)


static func carta_libre(id: String) -> bool:
	return CartasDB.CARTAS[id].rareza == 0 or RARAS_INICIALES.has(id) or cartas_extra.has(id)


static func objeto_libre(id: String) -> bool:
	return OBJETOS_INICIALES.has(id) or objetos_extra.has(id)


static func personaje_libre(id: String) -> bool:
	return personajes.has(id)


static func cartas_libres() -> int:
	return CartasDB.CARTAS.keys().filter(func(id): return carta_libre(id)).size()


static func objetos_libres() -> int:
	return ObjetosDB.OBJETOS.keys().filter(func(id): return objeto_libre(id)).size()


## Cada jefe vencido abre dos cartas y un objeto. Devuelve lo nuevo, para enseñarlo.
static func al_vencer_jefe(jefe: String, azar: RandomNumberGenerator) -> Array:
	var nuevo: Array = []
	if not jefes_vencidos.has(jefe):
		jefes_vencidos.append(jefe)
	var cartas: Array = CartasDB.CARTAS.keys().filter(func(id): return not carta_libre(id))
	for _i in 3:
		if cartas.is_empty():
			break
		var id: String = cartas.pop_at(azar.randi() % cartas.size())
		cartas_extra.append(id)
		nuevo.append({"tipo": "carta", "id": id})
	var objetos: Array = ObjetosDB.OBJETOS.keys().filter(func(id): return not objeto_libre(id))
	for _i in 2:
		if objetos.is_empty():
			break
		var id: String = objetos.pop_at(azar.randi() % objetos.size())
		objetos_extra.append(id)
		nuevo.append({"tipo": "objeto", "id": id})
	if jefe == "pez":
		_abrir_personaje("borracho", nuevo)
	if jefes_vencidos.size() >= 3:
		_abrir_personaje("crupier", nuevo)
	guardar()
	return nuevo


static func al_ganar(mesa: int, extremo := false, personaje := "tahur") -> Array:
	var nuevo: Array = []
	victorias += 1
	if not personajes_ganadores.has(personaje):
		personajes_ganadores.append(personaje)
	if extremo:
		victorias_extremo += 1
	_abrir_personaje("heredera", nuevo)
	if mesa >= mesa_max and mesa_max < PersonajesDB.MESAS.size() - 1:
		mesa_max = mesa + 1
		nuevo.append({"tipo": "mesa", "id": str(mesa_max)})
	guardar()
	return nuevo


static func registrar_infinito(piso: int) -> void:
	mejor_infinito = maxi(mejor_infinito, piso)
	guardar()


static func al_terminar_partida() -> Array:
	var nuevo: Array = []
	partidas += 1
	if int(contadores.get("enemigos", 0)) >= 1000:
		_abrir_personaje("guarda", nuevo)
	guardar()
	return nuevo


static func sumar(clave: String, cantidad: int) -> void:
	contadores[clave] = int(contadores.get(clave, 0)) + cantidad


static func reto_mejor_hoy(fecha: String) -> int:
	return reto_mejor if reto_fecha == fecha else 0


## Anota la marca del reto: se queda la mejor de cada día.
static func registrar_reto(fecha: String, puntos: int) -> void:
	if reto_fecha != fecha:
		reto_fecha = fecha
		reto_mejor = puntos
	else:
		reto_mejor = maxi(reto_mejor, puntos)
	guardar()


static func anotar_transformacion(id: String) -> Array:
	var nuevo: Array = []
	if not transformaciones.has(id):
		transformaciones.append(id)
		_abrir_personaje("mago", nuevo)
		guardar()
	return nuevo


static func _abrir_personaje(id: String, nuevo: Array) -> void:
	if not personajes.has(id):
		personajes.append(id)
		nuevo.append({"tipo": "personaje", "id": id})
