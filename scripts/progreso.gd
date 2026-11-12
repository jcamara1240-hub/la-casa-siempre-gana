class_name Progreso
extends RefCounted
## Lo que se conserva entre partidas: desbloqueos, jefes vencidos y mesas.

const RUTA := "user://progreso.cfg"
# Las comunes salen siempre. Las raras y legendarias que no están aquí las abren los jefes.
const RARAS_INICIALES := ["cuchilla", "explosion", "nova", "doble", "rebote", "eco", "escalera", "subir", "doble_nada",
	"tommy", "dinamita", "trucada", "pelos", "fiebre"]
const OBJETOS_INICIALES := ["herradura", "zapatos", "gafas", "whisky", "tarjeta", "saco", "iman", "seguro",
	"tirantes", "petaca", "gatillo", "naipe_manga", "chaleco", "espuelas", "cronometro", "campana"]

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
# Un intento puntuable por día: el primero que empiezas. Los demás son de práctica.
static var reto_empezado := ""  # fecha del último intento puntuable empezado
static var reto_detalle: Dictionary = {}  # resumen del intento puntuable de reto_fecha
static var reto_practica_fecha := ""
static var reto_practica := 0  # mejor marca de práctica de reto_practica_fecha
# Mesas por personaje (como las stakes de Balatro por mazo). mesa_max se queda como la más
# alta abierta con cualquiera, para las partidas guardadas y lo que lo mire de antes.
static var mesa_max_pj: Dictionary = {}  # personaje -> mesa más alta que puede elegir
static var mesa_ganada_pj: Dictionary = {}  # personaje -> mesa más alta ganada (su pegatina)
# Contrato de la Casa: lo que firmó cada personaje la última vez y su récord de calor ganado.
static var contrato_pj: Dictionary = {}  # personaje -> Array de cláusulas
static var calor_pj: Dictionary = {}  # personaje -> calor más alto con el que ha ganado
# Premios del calor, solo de aspecto: dorsos de carta y traje de gala de cada personaje.
static var dorso := 0  # el dorso elegido (0: el de siempre)
static var traje_pj: Dictionary = {}  # personaje -> true si lleva el traje de gala
const UMBRALES_DORSO := [3, 7, 12]  # calor (con cualquiera) que abre cada dorso nuevo
const UMBRAL_TRAJE := 5  # calor con ese personaje que abre su traje de gala


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
	reto_empezado = cfg.get_value("progreso", "reto_empezado", "")
	reto_detalle = cfg.get_value("progreso", "reto_detalle", {})
	reto_practica_fecha = cfg.get_value("progreso", "reto_practica_fecha", "")
	reto_practica = cfg.get_value("progreso", "reto_practica", 0)
	mesa_max_pj = cfg.get_value("progreso", "mesa_max_pj", {})
	mesa_ganada_pj = cfg.get_value("progreso", "mesa_ganada_pj", {})
	contrato_pj = cfg.get_value("progreso", "contrato_pj", {})
	calor_pj = cfg.get_value("progreso", "calor_pj", {})
	dorso = cfg.get_value("progreso", "dorso", 0)
	traje_pj = cfg.get_value("progreso", "traje_pj", {})
	if not cfg.has_section_key("progreso", "mesa_max_pj"):
		migrar_mesas()


## Progreso de antes de las mesas por personaje: nadie pierde nada. Todos los personajes que ya
## tenía abiertos pueden elegir las mismas mesas que antes (el mesa_max global). La pegatina
## (mesa ganada) solo se sabe seguro si ganó un único personaje; si ganaron varios, se les
## pone la Mesa Blanca, que seguro ganaron.
static func migrar_mesas() -> void:
	mesa_max_pj = {}
	mesa_ganada_pj = {}
	if mesa_max > 0:
		for pj in personajes:
			mesa_max_pj[pj] = mesa_max
	for pj in personajes_ganadores:
		mesa_max_pj[pj] = maxi(int(mesa_max_pj.get(pj, 0)), mini(1, PersonajesDB.MESAS.size() - 1))
		mesa_ganada_pj[pj] = maxi(mesa_max - 1, 0) if personajes_ganadores.size() == 1 else 0


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
	cfg.set_value("progreso", "reto_empezado", reto_empezado)
	cfg.set_value("progreso", "reto_detalle", reto_detalle)
	cfg.set_value("progreso", "reto_practica_fecha", reto_practica_fecha)
	cfg.set_value("progreso", "reto_practica", reto_practica)
	cfg.set_value("progreso", "mesa_max_pj", mesa_max_pj)
	cfg.set_value("progreso", "mesa_ganada_pj", mesa_ganada_pj)
	cfg.set_value("progreso", "contrato_pj", contrato_pj)
	cfg.set_value("progreso", "calor_pj", calor_pj)
	cfg.set_value("progreso", "dorso", dorso)
	cfg.set_value("progreso", "traje_pj", traje_pj)
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


static func al_ganar(mesa: int, extremo := false, personaje := "tahur", calor := 0) -> Array:
	var nuevo: Array = []
	victorias += 1
	if not personajes_ganadores.has(personaje):
		personajes_ganadores.append(personaje)
	if extremo:
		victorias_extremo += 1
	_abrir_personaje("heredera", nuevo)
	# La mesa ganada abre la siguiente, pero solo para este personaje.
	mesa_ganada_pj[personaje] = maxi(mesa_ganada(personaje), mesa)
	var abierta := mesa_elegible(personaje)
	if mesa >= abierta and abierta < PersonajesDB.MESAS.size() - 1:
		mesa_max_pj[personaje] = mesa + 1
		mesa_max = maxi(mesa_max, mesa + 1)
		nuevo.append({"tipo": "mesa", "id": str(mesa + 1)})
	if calor > calor_record(personaje):
		var dorsos_antes := dorsos_libres()
		var traje_antes := traje_libre(personaje)
		calor_pj[personaje] = calor
		for i in range(dorsos_antes, dorsos_libres()):
			nuevo.append({"tipo": "dorso", "id": str(i)})
		if traje_libre(personaje) and not traje_antes:
			nuevo.append({"tipo": "traje", "id": personaje})
	guardar()
	return nuevo


## La mesa más alta que puede elegir un personaje: la siguiente a la más alta que ha ganado.
static func mesa_elegible(personaje: String) -> int:
	return clampi(int(mesa_max_pj.get(personaje, 0)), 0, PersonajesDB.MESAS.size() - 1)


## La mesa más alta que ha ganado (-1 si aún ninguna): la pegatina de su retrato.
static func mesa_ganada(personaje: String) -> int:
	return int(mesa_ganada_pj.get(personaje, -1))


# ---------------------------------------------------------------- Contrato de la Casa
## Se puede firmar con un personaje que ya ha ganado alguna vez.
static func contrato_disponible(personaje: String) -> bool:
	return personajes_ganadores.has(personaje)


static func contrato(personaje: String) -> Array:
	var lista: Array = contrato_pj.get(personaje, [])
	return lista.filter(func(c): return PersonajesDB.CLAUSULAS.has(c))


static func firmar(personaje: String, clausulas: Array) -> void:
	contrato_pj[personaje] = clausulas.duplicate()
	guardar()


static func calor_record(personaje: String) -> int:
	return int(calor_pj.get(personaje, 0))


static func calor_maximo() -> int:
	var maximo := 0
	for pj in calor_pj:
		maximo = maxi(maximo, int(calor_pj[pj]))
	return maximo


## Cuántos dorsos hay para elegir, contando el de siempre.
static func dorsos_libres() -> int:
	return 1 + UMBRALES_DORSO.filter(func(u): return calor_maximo() >= u).size()


static func traje_libre(personaje: String) -> bool:
	return calor_record(personaje) >= UMBRAL_TRAJE


static func lleva_traje(personaje: String) -> bool:
	return traje_libre(personaje) and bool(traje_pj.get(personaje, false))


## El dibujo de las cartas que caen al suelo, con el dorso elegido.
static func ruta_dorso() -> String:
	var n := clampi(dorso, 0, dorsos_libres() - 1)
	return "res://assets/objetos/carta_suelo.png" if n == 0 else "res://assets/objetos/carta_suelo_%d.png" % n


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


## ¿El próximo intento de esa fecha cuenta? Solo si aún no has empezado ninguno puntuable.
static func reto_puntuable(fecha: String) -> bool:
	return reto_empezado != fecha


## Al empezar el intento puntuable ya queda gastado, aunque lo abandones: así no se puede
## reiniciar hasta que salga una buena partida.
static func empezar_reto_puntuable(fecha: String) -> void:
	reto_empezado = fecha
	guardar()


## El intento puntuable terminado: su marca y su resumen (piso, tiempo...) para enseñarlo.
static func registrar_reto_puntuable(resumen: Dictionary) -> void:
	var fecha := String(resumen.get("fecha", ""))
	var antes := reto_mejor_hoy(fecha)
	registrar_reto(fecha, int(resumen.get("puntos", 0)))
	if int(resumen.get("puntos", 0)) >= antes:
		reto_detalle = resumen.duplicate()
	guardar()


static func registrar_practica(fecha: String, puntos: int) -> void:
	if reto_practica_fecha != fecha:
		reto_practica_fecha = fecha
		reto_practica = puntos
	else:
		reto_practica = maxi(reto_practica, puntos)
	guardar()


static func practica_hoy(fecha: String) -> int:
	return reto_practica if reto_practica_fecha == fecha else 0


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
