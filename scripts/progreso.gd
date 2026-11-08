class_name Progreso
extends RefCounted
## Lo que se conserva entre partidas: desbloqueos, jefes vencidos y mesas.

const RUTA := "user://progreso.cfg"
const RARAS_INICIALES := ["cuchilla", "explosion", "nova", "doble", "rebote", "eco", "escalera", "subir", "doble_nada"]
const OBJETOS_INICIALES := ["herradura", "zapatos", "gafas", "whisky", "tarjeta", "saco", "iman", "seguro"]

static var partidas := 0
static var victorias := 0
static var mesa_max := 0
static var jefes_vencidos: Array = []
static var cartas_extra: Array = []
static var objetos_extra: Array = []
static var personajes: Array = ["tahur"]
static var transformaciones: Array = []


static func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return
	partidas = cfg.get_value("progreso", "partidas", 0)
	victorias = cfg.get_value("progreso", "victorias", 0)
	mesa_max = cfg.get_value("progreso", "mesa_max", 0)
	jefes_vencidos = cfg.get_value("progreso", "jefes_vencidos", [])
	cartas_extra = cfg.get_value("progreso", "cartas_extra", [])
	objetos_extra = cfg.get_value("progreso", "objetos_extra", [])
	personajes = cfg.get_value("progreso", "personajes", ["tahur"])
	transformaciones = cfg.get_value("progreso", "transformaciones", [])


static func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progreso", "partidas", partidas)
	cfg.set_value("progreso", "victorias", victorias)
	cfg.set_value("progreso", "mesa_max", mesa_max)
	cfg.set_value("progreso", "jefes_vencidos", jefes_vencidos)
	cfg.set_value("progreso", "cartas_extra", cartas_extra)
	cfg.set_value("progreso", "objetos_extra", objetos_extra)
	cfg.set_value("progreso", "personajes", personajes)
	cfg.set_value("progreso", "transformaciones", transformaciones)
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
	for _i in 2:
		if cartas.is_empty():
			break
		var id: String = cartas.pop_at(azar.randi() % cartas.size())
		cartas_extra.append(id)
		nuevo.append({"tipo": "carta", "id": id})
	var objetos: Array = ObjetosDB.OBJETOS.keys().filter(func(id): return not objeto_libre(id))
	if not objetos.is_empty():
		var id: String = objetos[azar.randi() % objetos.size()]
		objetos_extra.append(id)
		nuevo.append({"tipo": "objeto", "id": id})
	if jefe == "pez":
		_abrir_personaje("borracho", nuevo)
	if jefes_vencidos.size() >= 3:
		_abrir_personaje("crupier", nuevo)
	guardar()
	return nuevo


static func al_ganar(mesa: int) -> Array:
	var nuevo: Array = []
	victorias += 1
	_abrir_personaje("heredera", nuevo)
	if mesa >= mesa_max and mesa_max < PersonajesDB.MESAS.size() - 1:
		mesa_max = mesa + 1
		nuevo.append({"tipo": "mesa", "id": str(mesa_max)})
	guardar()
	return nuevo


static func al_terminar_partida() -> void:
	partidas += 1
	guardar()


static func anotar_transformacion(id: String) -> void:
	if not transformaciones.has(id):
		transformaciones.append(id)
		guardar()


static func _abrir_personaje(id: String, nuevo: Array) -> void:
	if not personajes.has(id):
		personajes.append(id)
		nuevo.append({"tipo": "personaje", "id": id})
