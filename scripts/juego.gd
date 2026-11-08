extends Node
## Estado de la partida. Es un autoload: vive mientras dura el juego.

signal estado_cambiado
signal cartas_cambiadas
signal transformacion_obtenida(id: String)
signal logro_obtenido(id: String)

const VIDA_INICIAL := 8
const RANURAS_INICIALES := 5
const RANURAS_MAX := 8
const PISOS_TOTALES := 5
const RUTA_AJUSTES := "user://ajustes.cfg"
const JEFES_CASINO := ["tragaperras", "ruleta", "baccarat", "blackjack", "dados", "revolver", "bingo"]

const OBJETOS_PROHIBIDOS_EXTREMO := ["herradura", "seguro"]

const STATS_BASE := {
	"crit": 0.0, "suerte": 0.0, "velocidad": 0.0, "invulnerable": 0.0, "bala_lenta": 0.0, "puro": 0.0,
	"ciclo": 0.0, "descuento": 0.0, "monedas_sala": 0.0, "iman": 0.0, "intereses": 0.0,
	"doble_ciclo": 0.0, "seguro": 0.0, "dano_global": 0.0, "crit_mult": 0.0, "moneda_extra": 0.0,
	"tambaleo": 0.0, "golpe_monedas": 0.0, "quema_global": 0.0,
}

var vida := VIDA_INICIAL
var vida_max := VIDA_INICIAL
var oro := 0
var piso := 1
var enemigos_eliminados := 0
var racha := 0
var personaje := "tahur"
var mesa := 0
var deuda := 0
var extremo := false
var diario := false
var transformaciones: Array = []
var novedades: Array = []  # lo desbloqueado en esta partida
var tiempo_partida := 0.0
var mejor_combo := 0.0
var oro_total := 0
var orden_jefes: Array = []
var cartas: Array = []
var objetos: Array = []
var stats: Dictionary = STATS_BASE.duplicate()
var azar := RandomNumberGenerator.new()

var fuente: Font
var fuente_grande: Font

# Ajustes que se recuerdan entre partidas.
var pantalla_completa := false
var sacudida := true
var numeros_dano := true
var volumen_musica := 0.6
var volumen_efectos := 0.8

# Pantallas táctiles
var tactil := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
var direccion_tactil := Vector2.ZERO


func _ready() -> void:
	fuente = load("res://assets/fuente/pixel.fnt")
	fuente_grande = load("res://assets/fuente/pixel2.fnt")
	var tema := ThemeDB.get_default_theme()
	tema.default_font = fuente
	tema.default_font_size = 8
	ThemeDB.fallback_font = fuente
	ThemeDB.fallback_font_size = 8
	cargar_ajustes()
	Progreso.cargar()
	nueva_partida()


func cargar_ajustes() -> void:
	var cfg := ConfigFile.new()
	var hay := cfg.load(RUTA_AJUSTES) == OK
	var por_defecto := "es" if OS.get_locale_language() == "es" else "en"
	var idioma: String = cfg.get_value("ajustes", "idioma", por_defecto) if hay else por_defecto
	Idioma.actual = idioma if Idioma.IDIOMAS.has(idioma) else "es"
	if hay:
		sacudida = cfg.get_value("ajustes", "sacudida", true)
		numeros_dano = cfg.get_value("ajustes", "numeros_dano", true)
		pantalla_completa = cfg.get_value("ajustes", "pantalla_completa", false)
		volumen_musica = cfg.get_value("ajustes", "volumen_musica", 0.6)
		volumen_efectos = cfg.get_value("ajustes", "volumen_efectos", 0.8)
	_aplicar_pantalla()


func guardar_ajustes() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ajustes", "idioma", Idioma.actual)
	cfg.set_value("ajustes", "sacudida", sacudida)
	cfg.set_value("ajustes", "numeros_dano", numeros_dano)
	cfg.set_value("ajustes", "pantalla_completa", pantalla_completa)
	cfg.set_value("ajustes", "volumen_musica", volumen_musica)
	cfg.set_value("ajustes", "volumen_efectos", volumen_efectos)
	cfg.save(RUTA_AJUSTES)


func cambiar_volumenes(musica: float, efectos: float) -> void:
	volumen_musica = clampf(musica, 0.0, 1.0)
	volumen_efectos = clampf(efectos, 0.0, 1.0)
	Sonido.aplicar_volumenes(volumen_musica, volumen_efectos)
	guardar_ajustes()


func cambiar_idioma(codigo: String) -> void:
	Idioma.actual = codigo
	guardar_ajustes()


func cambiar_pantalla_completa(activar: bool) -> void:
	pantalla_completa = activar
	_aplicar_pantalla()
	guardar_ajustes()


func _aplicar_pantalla() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED)


func nueva_partida(semilla := 0, id_personaje := "", id_mesa := -1, modo_extremo := false, reto_diario := false) -> void:
	extremo = modo_extremo
	diario = reto_diario
	if id_personaje != "":
		personaje = id_personaje
	if id_mesa >= 0:
		mesa = id_mesa
	if semilla == 0:
		azar.randomize()
	else:
		azar.seed = semilla
	var datos: Dictionary = PersonajesDB.PERSONAJES[personaje]
	# En modo extremo hay un solo corazón, y un golpe se lo lleva entero.
	vida_max = 2 if extremo else int(datos.vida) - (2 if mesa >= 4 else 0)
	vida = vida_max
	oro = int(datos.oro)
	piso = 1
	racha = 0
	deuda = 0
	transformaciones = []
	novedades = []
	tiempo_partida = 0.0
	mejor_combo = 0.0
	oro_total = 0
	enemigos_eliminados = 0
	cartas = datos.cartas.duplicate()
	while cartas.size() < int(datos.get("ranuras", RANURAS_INICIALES)):
		cartas.append("")
	objetos = []
	stats = STATS_BASE.duplicate()
	_sumar_efecto(datos.efecto)
	# El primer jefe es siempre el pez; los demás cambian de orden en cada partida.
	var resto: Array = JEFES_CASINO.duplicate()
	for i in range(resto.size() - 1, 0, -1):
		var j := azar.randi_range(0, i)
		var t = resto[i]
		resto[i] = resto[j]
		resto[j] = t
	orden_jefes = ["pez"] + resto.slice(0, PISOS_TOTALES - 1)
	cartas_cambiadas.emit()
	estado_cambiado.emit()


func fecha_hoy() -> String:
	return Time.get_date_string_from_system(true)


func puntos_reto(gano: bool) -> int:
	return (piso - 1) * 1000 + (5000 if gano else 0) + enemigos_eliminados * 2 + mini(roundi(mejor_combo), 3000) + oro_total


# ---------------------------------------------------------------- guardado
const CAMPOS_PARTIDA := ["vida", "vida_max", "oro", "piso", "enemigos_eliminados", "racha", "personaje", "mesa", "extremo",
	"diario", "deuda", "orden_jefes", "cartas", "objetos", "stats", "transformaciones", "novedades", "tiempo_partida",
	"mejor_combo", "oro_total"]


func volcar() -> Dictionary:
	var datos := {"azar_seed": azar.seed, "azar_state": azar.state}
	for campo in CAMPOS_PARTIDA:
		datos[campo] = get(campo)
	return datos


func restaurar(datos: Dictionary) -> void:
	for campo in CAMPOS_PARTIDA:
		if datos.has(campo):
			set(campo, datos[campo])
	azar.seed = datos.azar_seed
	azar.state = datos.azar_state
	cartas_cambiadas.emit()
	estado_cambiado.emit()


# ---------------------------------------------------------------- logros
func marcar_logro(id: String) -> void:
	if not Progreso.logros.has(id):
		Progreso.logros.append(id)
		Progreso.guardar()
		novedades.append({"tipo": "logro", "id": id})
		logro_obtenido.emit(id)


func revisar_logros(gano := false) -> void:
	var c: Dictionary = Progreso.contadores
	var e := int(c.get("enemigos", 0))
	Progreso.contadores["combo"] = maxi(int(c.get("combo", 0)), roundi(mejor_combo))
	var combo := int(Progreso.contadores["combo"])
	var condiciones := {
		"primera_sangre": e >= 1, "cien": e >= 100, "mil": e >= 1000, "cinco_mil": e >= 5000,
		"pez": Progreso.jefes_vencidos.has("pez"),
		"tres_jefes": Progreso.jefes_vencidos.size() >= 3,
		"todos_jefes": Progreso.jefes_vencidos.size() >= PersonajesDB.JEFES.size(),
		"combo_100": combo >= 100, "combo_1000": combo >= 1000, "combo_5000": combo >= 5000,
		"rico": oro_total >= 500, "objetos": objetos.size() >= 10,
		"transformacion": not Progreso.transformaciones.is_empty(),
		"todas_transf": Progreso.transformaciones.size() >= ObjetosDB.TRANSFORMACIONES.size(),
		"fila_llena": cartas.size() == RANURAS_MAX and not cartas.has(""),
		"ganar": Progreso.victorias >= 1, "tres_victorias": Progreso.victorias >= 3,
		"todos_ganan": Progreso.personajes_ganadores.size() >= 4,
		"mesa_oro": gano and mesa >= 4, "extremo": gano and extremo,
		"reto": diario,
		"cartas": Progreso.cartas_libres() >= CartasDB.CARTAS.size(),
	}
	for id in condiciones:
		if condiciones[id]:
			marcar_logro(id)


func jefe_del_piso() -> String:
	return orden_jefes[clampi(piso - 1, 0, orden_jefes.size() - 1)]


func contexto_combo(con_azar := false) -> Dictionary:
	var ctx := {"monedas": oro, "racha": racha, "vida": vida, "dano_global": stat("dano_global")}
	if con_azar:
		ctx["azar"] = azar
	return ctx


func stat(nombre: String) -> float:
	return float(stats.get(nombre, 0.0))


func tiene_objeto(id: String) -> bool:
	return objetos.has(id)


func dar_objeto(id: String) -> void:
	objetos.append(id)
	var efecto: Dictionary = ObjetosDB.OBJETOS[id].efecto
	for clave in efecto:
		match String(clave):
			"vida_max":
				vida_max += int(efecto[clave])
				vida = vida_max
			"ranura":
				anadir_ranura()
			"monedas":
				oro += int(efecto[clave])
			_:
				stats[clave] = float(stats[clave]) + float(efecto[clave])
	_comprobar_transformaciones()
	estado_cambiado.emit()


func _sumar_efecto(efecto: Dictionary) -> void:
	for clave in efecto:
		stats[clave] = float(stats[clave]) + float(efecto[clave])


func _comprobar_transformaciones() -> void:
	for id in ObjetosDB.TRANSFORMACIONES:
		if transformaciones.has(id):
			continue
		var datos: Dictionary = ObjetosDB.TRANSFORMACIONES[id]
		var tengo: int = datos.piezas.filter(func(p): return objetos.has(p)).size()
		if tengo >= int(datos.necesarias):
			transformaciones.append(id)
			_sumar_efecto(datos.efecto)
			novedades += Progreso.anotar_transformacion(id)
			transformacion_obtenida.emit(id)


func vender_corazon() -> void:
	vida_max -= 2
	vida = mini(vida, vida_max)
	ganar_oro(30)


func pedir_prestamo() -> void:
	deuda = 60
	ganar_oro(40)


## Al bajar de piso se paga lo que se debe. Devuelve el texto del cartel, o "".
func cobrar_deuda() -> String:
	if deuda == 0:
		return ""
	var a_pagar := deuda
	deuda = 0
	if oro >= a_pagar:
		oro -= a_pagar
		estado_cambiado.emit()
		return Idioma.t("PAGAS TU DEUDA")
	vida_max = maxi(vida_max - 2, 2)
	vida = mini(vida, vida_max)
	estado_cambiado.emit()
	marcar_logro("deudor")
	return Idioma.t("EL PRESTAMISTA TE COBRA UN CORAZÓN")


## Un objeto que aún no tengas. Devuelve "" si ya los tienes todos.
func robar_objeto(excluir := []) -> String:
	var libres: Array = []
	for id in ObjetosDB.OBJETOS:
		if extremo and OBJETOS_PROHIBIDOS_EXTREMO.has(id):
			continue
		if not objetos.has(id) and not excluir.has(id) and Progreso.objeto_libre(id):
			libres.append(id)
	if libres.is_empty():
		return ""
	return libres[azar.randi() % libres.size()]


func precio_final(base: int) -> int:
	var recargo := 1.3 if mesa >= 3 else 1.0
	return maxi(1, roundi(base * recargo * (1.0 - minf(stat("descuento"), 0.8))))


func hay_hueco() -> bool:
	return cartas.has("")


func anadir_carta(id: String) -> bool:
	var i := cartas.find("")
	if i == -1:
		return false
	cartas[i] = id
	cartas_cambiadas.emit()
	return true


func sustituir_carta(ranura: int, id: String) -> void:
	cartas[ranura] = id
	cartas_cambiadas.emit()


## Sin ningún ataque en la fila una sala cerrada no se podría terminar nunca.
func dejaria_sin_ataques(ranura: int, id_nueva: String) -> bool:
	if CartasDB.CARTAS[id_nueva].tipo == CartasDB.Tipo.ATAQUE:
		return false
	for i in cartas.size():
		if i != ranura and cartas[i] != "" and CartasDB.CARTAS[cartas[i]].tipo == CartasDB.Tipo.ATAQUE:
			return false
	return true


func mover_carta(origen: int, destino: int) -> void:
	cartas = fila_con_movimiento(origen, destino)
	cartas_cambiadas.emit()


## La fila tal como quedaría, sin tocarla: sirve para enseñar el combo mientras arrastras.
func fila_con_movimiento(origen: int, destino: int) -> Array:
	var copia := cartas.duplicate()
	var id: String = copia[origen]
	copia.remove_at(origen)
	copia.insert(destino, id)
	return copia


func anadir_ranura() -> void:
	if cartas.size() < RANURAS_MAX:
		cartas.append("")
		cartas_cambiadas.emit()


func ganar_oro(cantidad: int) -> void:
	oro += cantidad
	oro_total += cantidad
	estado_cambiado.emit()


func gastar_oro(cantidad: int) -> bool:
	if oro < cantidad:
		return false
	oro -= cantidad
	estado_cambiado.emit()
	return true


func curar(cantidad: int) -> void:
	vida = mini(vida + cantidad, vida_max)
	estado_cambiado.emit()


func herir(cantidad: int) -> void:
	vida = 0 if extremo else maxi(vida - cantidad, 0)
	racha = 0
	estado_cambiado.emit()


## Saca cartas distintas entre sí. Con suerte > 0 salen más raras (tesoros).
func robar_cartas(cuantas: int, suerte := 0.0) -> Array:
	var bolsa: Array = CartasDB.CARTAS.keys().filter(func(id): return Progreso.carta_libre(id))
	var elegidas: Array = []
	var suerte_total := suerte + stat("suerte")
	for _i in cuantas:
		var pesos: Array = []
		var suma := 0.0
		for id in bolsa:
			var peso: float = CartasDB.PESO_RAREZA[CartasDB.CARTAS[id].rareza]
			if CartasDB.CARTAS[id].rareza > 0:
				peso *= 1.0 + suerte_total
			suma += peso
			pesos.append(peso)
		var tirada := azar.randf() * suma
		for j in bolsa.size():
			tirada -= pesos[j]
			if tirada <= 0.0:
				elegidas.append(bolsa[j])
				bolsa.remove_at(j)
				break
	return elegidas
