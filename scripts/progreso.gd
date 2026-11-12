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
# Racha de días seguidos jugando el reto (sin castigo: si se corta, vuelve a empezar en 1).
static var reto_racha := 0
static var reto_ultimo := ""  # fecha del último reto puntuable terminado
## Lo que ya has visto alguna vez: "objetos" (piezas de transformación) y "frases" del Dueño.
static var vistos: Dictionary = {}
# Un intento puntuable por día: el primero que empiezas. Los demás son de práctica.
static var reto_empezado := ""  # fecha del último intento puntuable empezado
static var reto_detalle: Dictionary = {}  # resumen del intento puntuable de reto_fecha
static var reto_practica_fecha := ""
static var reto_practica := 0  # mejor marca de práctica de reto_practica_fecha


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
	reto_racha = cfg.get_value("progreso", "reto_racha", 0)
	reto_ultimo = cfg.get_value("progreso", "reto_ultimo", "")
	vistos = cfg.get_value("progreso", "vistos", {})
	reto_empezado = cfg.get_value("progreso", "reto_empezado", "")
	reto_detalle = cfg.get_value("progreso", "reto_detalle", {})
	reto_practica_fecha = cfg.get_value("progreso", "reto_practica_fecha", "")
	reto_practica = cfg.get_value("progreso", "reto_practica", 0)


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
	cfg.set_value("progreso", "reto_racha", reto_racha)
	cfg.set_value("progreso", "reto_ultimo", reto_ultimo)
	cfg.set_value("progreso", "vistos", vistos)
	cfg.set_value("progreso", "reto_empezado", reto_empezado)
	cfg.set_value("progreso", "reto_detalle", reto_detalle)
	cfg.set_value("progreso", "reto_practica_fecha", reto_practica_fecha)
	cfg.set_value("progreso", "reto_practica", reto_practica)
	cfg.save(RUTA)


static func carta_libre(id: String) -> bool:
	return CartasDB.CARTAS[id].rareza == 0 or RARAS_INICIALES.has(id) or cartas_extra.has(id)


static func objeto_libre(id: String) -> bool:
	return OBJETOS_INICIALES.has(id) or objetos_extra.has(id)


static func personaje_libre(id: String) -> bool:
	return personajes.has(id)


## Lo que llevas hacia el requisito de un personaje: x = actual, y = meta.
static func progreso_personaje(id: String) -> Vector2i:
	match id:
		"borracho": return Vector2i(1 if jefes_vencidos.has("pez") else 0, 1)
		"crupier": return Vector2i(mini(jefes_vencidos.size(), 3), 3)
		"heredera": return Vector2i(mini(victorias, 1), 1)
		"mago": return Vector2i(mini(transformaciones.size(), 1), 1)
		"guarda": return Vector2i(mini(int(contadores.get("enemigos", 0)), 1000), 1000)
	return Vector2i(1, 1)


## El desbloqueo pendiente más cercano, para la pantalla final: {"texto", "actual", "meta"},
## o vacío si ya está todo. Primero un contador que vaya por más de las tres cuartas partes;
## si no, el siguiente personaje en el orden en que suelen abrirse; luego la mesa siguiente.
static func siguiente_objetivo() -> Dictionary:
	var orden := ["borracho", "crupier", "mago", "heredera", "guarda"]
	var pendientes: Array = []
	for id in orden:
		if personajes.has(id) or not PersonajesDB.PERSONAJES.has(id):
			continue
		var p := progreso_personaje(id)
		pendientes.append({"texto": "%s: %s" % [PersonajesDB.nombre(id).to_upper(), Idioma.t(PersonajesDB.PERSONAJES[id].requisito).to_upper().trim_suffix(".")],
			"actual": p.x, "meta": p.y})
	for p in pendientes:
		if int(p.meta) > 1 and float(p.actual) >= float(p.meta) * 0.75:
			return p
	if not pendientes.is_empty():
		return pendientes[0]
	if mesa_max < PersonajesDB.MESAS.size() - 1:
		return {"texto": Idioma.t("%s: GANA EN LA %s") % [Idioma.t(PersonajesDB.MESAS[mesa_max + 1].nombre).to_upper(),
			Idioma.t(PersonajesDB.MESAS[mesa_max].nombre).to_upper()], "actual": 0, "meta": 1}
	return {}


## Anota algo como visto (ver "vistos"). Devuelve true si es la primera vez.
static func ver(tipo: String, id: String) -> bool:
	var lista: Array = vistos.get(tipo, [])
	if lista.has(id):
		return false
	lista.append(id)
	vistos[tipo] = lista
	return true


static func visto(tipo: String, id: String) -> bool:
	return (vistos.get(tipo, []) as Array).has(id)


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
	_sumar_racha(fecha)
	if reto_fecha != fecha:
		reto_fecha = fecha
		reto_mejor = puntos
	else:
		reto_mejor = maxi(reto_mejor, puntos)
	guardar()


## Si el último reto fue ayer, la racha sube; si fue hoy, se queda; si no, vuelve a 1.
static func _sumar_racha(fecha: String) -> void:
	if reto_ultimo == fecha:
		return
	reto_racha = reto_racha + 1 if dias_entre(reto_ultimo, fecha) == 1 else 1
	reto_ultimo = fecha


## La racha que sigue viva en esa fecha (jugaste hoy o ayer); si no, 0. No se castiga perderla.
static func racha_viva(fecha: String) -> int:
	var d := dias_entre(reto_ultimo, fecha)
	return reto_racha if d == 0 or d == 1 else 0


## Días de una fecha (AAAA-MM-DD) a otra. Un número muy grande si alguna no vale.
static func dias_entre(desde: String, hasta: String) -> int:
	if desde.length() != 10 or hasta.length() != 10:
		return 99999
	var a := Time.get_unix_time_from_datetime_string(desde + "T00:00:00")
	var b := Time.get_unix_time_from_datetime_string(hasta + "T00:00:00")
	return roundi((b - a) / 86400.0)


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
