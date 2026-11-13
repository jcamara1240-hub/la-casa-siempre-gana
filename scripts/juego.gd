extends Node
## Estado de la partida. Es un autoload: vive mientras dura el juego.

signal estado_cambiado
signal cartas_cambiadas
signal transformacion_obtenida(id: String)
signal logro_obtenido(id: String)
signal fiebre_cambiada(nivel: int)
signal desatado_cambiado(activo: bool)
## Te falta una pieza para esa transformación (ya filtrado por ObjetosDB.pista_permitida).
signal a_un_paso(id: String)

const VIDA_INICIAL := 8
const RANURAS_INICIALES := 5
const RANURAS_MAX := 8
const RANURAS_IMPOSIBLE := 2
const COPIAS_MAX := 2  # de una misma carta en la fila
const PISOS_TOTALES := 5
const RUTA_AJUSTES := "user://ajustes.cfg"
const JEFES_CASINO := ["tragaperras", "ruleta", "baccarat", "blackjack", "dados", "revolver", "bingo", "trilero", "cajero", "coctelero", "poker"]

# Multiplicador extra de vida de los jefes en cada piso.
const REFUERZO_JEFE := [1.0, 1.5, 2.2, 3.0, 4.0]
const OBJETOS_PROHIBIDOS_EXTREMO := ["herradura", "seguro", "chaleco", "trofeo_caza"]

const STATS_BASE := {
	"crit": 0.0, "suerte": 0.0, "velocidad": 0.0, "invulnerable": 0.0, "bala_lenta": 0.0, "puro": 0.0,
	"ciclo": 0.0, "descuento": 0.0, "monedas_sala": 0.0, "iman": 0.0, "intereses": 0.0,
	"doble_ciclo": 0.0, "seguro": 0.0, "dano_global": 0.0, "crit_mult": 0.0, "moneda_extra": 0.0,
	"tambaleo": 0.0, "golpe_monedas": 0.0, "quema_global": 0.0,
	"voltereta_rapida": 0.0, "ordago_extra": 0.0, "ordago_dano": 0.0, "voltereta_dano": 0.0,
	"fiebre_dura": 0.0, "voltereta_bala": 0.0, "mesas": 0.0, "retroceso": 0.0,
	"chaleco": 0.0, "espuelas": 0.0, "propina_extra": 0.0, "elite_cura": 0.0, "dano_gordos": 0.0,
	"roce_extra": 0.0, "campana": 0.0, "espejo": 0.0,
}

# Órdagos: los "limpia-pantallas". Se rellenan al bajar de piso.
const ORDAGOS_BASE := 2
# Fiebre: las bajas seguidas la suben; cada nivel acelera el ciclo de cartas.
# Sube antes y se enfría antes que en la ronda 1 (0,14 / 2,5 s / 0,9 / 12 %): se vive en el filo.
const FIEBRE_MAX := 3.0
const FIEBRE_POR_BAJA := 0.2  # cinco bajas por nivel
const FIEBRE_POR_JEFE := 1.0
const FIEBRE_POR_PELOS := 0.35  # rozar una bala rodando
const FIEBRE_POR_ROCE := 0.22  # una bala que te pasa rozando SIN rodar: más riesgo, más premio
const FIEBRE_ESPERA := 1.1  # segundos sin matar antes de que empiece a bajar
const FIEBRE_CAIDA := 1.2  # niveles por segundo, cuando ya baja
const FIEBRE_ACELERA := 0.15  # +15 % de velocidad de ciclo por nivel
const FIEBRE_AL_LIMITE := 1.5  # con un corazón o menos la fiebre sube un 50 % más deprisa
const VOLTERETA_RECIENTE := 2.0  # lo que cuenta como "acabas de rodar" para las cartas
# Desatado: aguantar la fiebre al máximo un momento suelta unos segundos de frenesí.
const DESATADO_CARGA := 0.8  # segundos seguidos al máximo para que salte
const DESATADO_SEG := 5.0
const DESATADO_POR_BAJA := 0.3  # cada baja mientras dura lo alarga (hasta DESATADO_SEG)
const DESATADO_CICLO := 1.5  # las cartas, aún más rápidas
const DESATADO_VELOCIDAD := 1.2  # y el jugador también
const VELOCIDAD_AL_LIMITE := 1.15

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
var imposible := false
var infinito := false
var transformaciones: Array = []
## Las cláusulas del Contrato de la Casa de esta partida (ver PersonajesDB.CLAUSULAS).
var contrato: Array = []
var novedades: Array = []  # lo desbloqueado en esta partida
var tiempo_partida := 0.0
var mejor_combo := 0.0
var oro_total := 0
var orden_jefes: Array = []
var cartas: Array = []
var objetos: Array = []
var stats: Dictionary = STATS_BASE.duplicate()
var azar := RandomNumberGenerator.new()
## El azar de dentro de la pelea (combos, botín, dónde nace cada uno). Va aparte para que
## lo que pase en un combate no descoloque las tiradas de la mazmorra (mapas, tiendas, oleadas).
var azar_combate := RandomNumberGenerator.new()
## Reto diario: la fecha (UTC) de la mazmorra que se juega, si cuenta para la marca
## y los golpes recibidos, que restan puntos.
var fecha_reto := ""
var reto_puntuable := false
var golpes := 0
var ordagos := ORDAGOS_BASE
## La presión del Director: sube si limpias salas sin que te toquen y baja si te dan.
var presion := Director.PRESION_INICIAL
## Solo para pintar: qué parte de la sala llevas matada (-1 fuera de una pelea de oleadas)
## y lo que acelera las balas la regla de la sala.
var progreso_sala := -1.0
var balas_sala := 1.0
var fiebre := 0.0  # de 0 a 3: el nivel es la parte entera
var ultima_voltereta := -100.0  # tiempo_partida de la última voltereta
var desatado := false  # lo lee todo el mundo; solo lo cambia este archivo
var en_combate := false  # lo mantiene main.gd: hay pelea en la sala
## Lo último que te hizo daño, para que el Dueño lo comente al final:
## {"tipo": "jefe"/"enemigo"/"bala", "id": ..., "rango": 0-2, "apuestas": true si fue en esa sala}.
var ultima_causa: Dictionary = {}

var _fiebre_espera := 0.0
var _al_maximo_t := 0.0  # lo que lleva la fiebre al máximo, para el desatado
var _desatado_t := 0.0

var fuente: Font
var fuente_grande: Font

# Ajustes que se recuerdan entre partidas.
var pantalla_completa := false
var sacudida := true
var numeros_dano := true
var volumen_musica := 0.6
var volumen_efectos := 0.8
var desglose_ciclo := true  # la cuenta de cada carta encima de la fila ("+5", "x2")

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
	var por_defecto := OS.get_locale_language() if Idioma.IDIOMAS.has(OS.get_locale_language()) else "en"
	var idioma: String = cfg.get_value("ajustes", "idioma", por_defecto) if hay else por_defecto
	Idioma.actual = idioma if Idioma.IDIOMAS.has(idioma) else "es"
	if hay:
		sacudida = cfg.get_value("ajustes", "sacudida", true)
		numeros_dano = cfg.get_value("ajustes", "numeros_dano", true)
		pantalla_completa = cfg.get_value("ajustes", "pantalla_completa", false)
		volumen_musica = cfg.get_value("ajustes", "volumen_musica", 0.6)
		volumen_efectos = cfg.get_value("ajustes", "volumen_efectos", 0.8)
		Mando.vibracion = cfg.get_value("ajustes", "vibracion", true)
		desglose_ciclo = cfg.get_value("ajustes", "desglose_ciclo", true)
	_aplicar_pantalla()


func guardar_ajustes() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ajustes", "idioma", Idioma.actual)
	cfg.set_value("ajustes", "sacudida", sacudida)
	cfg.set_value("ajustes", "numeros_dano", numeros_dano)
	cfg.set_value("ajustes", "pantalla_completa", pantalla_completa)
	cfg.set_value("ajustes", "volumen_musica", volumen_musica)
	cfg.set_value("ajustes", "volumen_efectos", volumen_efectos)
	cfg.set_value("ajustes", "vibracion", Mando.vibracion)
	cfg.set_value("ajustes", "desglose_ciclo", desglose_ciclo)
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


func nueva_partida(semilla := 0, id_personaje := "", id_mesa := -1, modo_extremo := false, reto_diario := false, modo_imposible := false) -> void:
	# El imposible es un extremo con aún menos sitio para las cartas.
	extremo = modo_extremo or modo_imposible
	imposible = modo_imposible
	infinito = false
	diario = reto_diario
	if id_personaje != "":
		personaje = id_personaje
	if id_mesa >= 0:
		mesa = id_mesa
	if semilla == 0:
		azar.randomize()
	else:
		azar.seed = semilla
	azar_combate.randomize()
	if not reto_diario:
		fecha_reto = ""
		reto_puntuable = false
	golpes = 0
	ultima_causa = {}
	_sin_coop()
	var datos: Dictionary = PersonajesDB.PERSONAJES[personaje]
	# El contrato firmado en la selección; ni el reto, ni el extremo, ni el imposible lo llevan.
	contrato = [] if reto_diario or extremo or not Progreso.contrato_disponible(personaje) else Progreso.contrato(personaje)
	# En modo extremo hay un solo corazón, y un golpe se lo lleva entero.
	vida_max = 2 if extremo else int(datos.vida) - (2 if mesa >= 4 else 0)
	if clausula("corazon"):
		vida_max = maxi(vida_max - 2, 2)
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
	ordagos = ORDAGOS_BASE
	presion = Director.PRESION_INICIAL
	progreso_sala = -1.0
	balas_sala = 1.0
	_reiniciar_ritmo()
	cartas = datos.cartas.duplicate()
	var ranuras_iniciales := RANURAS_IMPOSIBLE if imposible else int(datos.get("ranuras", RANURAS_INICIALES))
	if clausula("ranura"):
		ranuras_iniciales = maxi(ranuras_iniciales - 1, cartas.size())
	while cartas.size() < ranuras_iniciales:
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
	# El pez abre y el Dueño cierra, siempre; en medio, tres al azar.
	orden_jefes = ["pez"] + resto.slice(0, PISOS_TOTALES - 2) + ["dueno"]
	cartas_cambiadas.emit()
	estado_cambiado.emit()


## La fecha del reto es la de UTC: así cambia a la vez en todo el mundo.
func fecha_hoy() -> String:
	return Time.get_date_string_from_system(true)


## El reto diario de una fecha: el Tahúr en la Mesa Verde, sin extremo, y la mazmorra sale de la fecha.
func nueva_partida_reto(fecha: String, puntuable: bool) -> void:
	nueva_partida(semilla_de("reto:" + fecha), "tahur", 1, false, true)
	fecha_reto = fecha
	reto_puntuable = puntuable


## Una semilla estable a partir de un texto: la misma en cualquier máquina y versión de Godot
## (String.hash es djb2). Nunca 0, que para nueva_partida significa "al azar".
static func semilla_de(texto: String) -> int:
	var h := texto.hash()
	return h if h != 0 else 1


## Un azar propio para una cosa concreta de una sala (su plan, su tienda, su cofre...).
## Sale de la semilla de la sala, así que no depende del orden en que pasen las cosas.
static func azar_para(semilla: int, etiqueta: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = semilla_de("%d:%s" % [semilla, etiqueta])
	return r


## La presión con la que se planea una sala. En el reto diario es fija: todo el mundo
## se encuentra las mismas oleadas, juegue como juegue.
func presion_sala() -> float:
	return Director.PRESION_INICIAL if diario else presion


## Qué cartas y objetos pueden salir. En el reto diario, solo los de partida para todos:
## lo que tengas desbloqueado no cambia lo que encuentras.
func carta_en_bolsa(id: String) -> bool:
	if diario:
		return CartasDB.CARTAS[id].rareza == 0 or Progreso.RARAS_INICIALES.has(id)
	return Progreso.carta_libre(id)


func objeto_en_bolsa(id: String) -> bool:
	if diario:
		return Progreso.OBJETOS_INICIALES.has(id)
	return Progreso.objeto_libre(id)


# Puntos del reto diario. Fórmula fija (el servidor la recalcula igual, ver servidor/esquema.sql):
#   1000 por piso superado (5 si ganas) + 5000 por ganar + 2 por baja + 1 por moneda ganada
#   - 100 por golpe recibido + al ganar, 3 por cada segundo por debajo de 25 minutos.
#   Nunca baja de 0.
const PUNTOS_PISO := 1000
const PUNTOS_VICTORIA := 5000
const PUNTOS_BAJA := 2
const PUNTOS_MONEDA := 1
const PUNTOS_GOLPE := 100
const PUNTOS_SEGUNDO := 3
const SEGUNDOS_BONO := 1500


static func calcular_puntos(pisos: int, gano: bool, segundos: int, bajas: int, monedas: int, golpes_recibidos: int) -> int:
	var total := pisos * PUNTOS_PISO + bajas * PUNTOS_BAJA + monedas * PUNTOS_MONEDA - golpes_recibidos * PUNTOS_GOLPE
	if gano:
		total += PUNTOS_VICTORIA + maxi(SEGUNDOS_BONO - segundos, 0) * PUNTOS_SEGUNDO
	return maxi(total, 0)


## Pisos superados: los anteriores al que estás, o los cinco si ganas.
func pisos_superados(gano: bool) -> int:
	return PISOS_TOTALES if gano else piso - 1


func puntos_reto(gano: bool) -> int:
	return calcular_puntos(pisos_superados(gano), gano, int(tiempo_partida), enemigos_eliminados, oro_total, golpes)


## Todo lo que se guarda (y se envía a la tabla mundial) de un reto terminado.
func resumen_reto(gano: bool) -> Dictionary:
	return {
		"fecha": fecha_reto, "modo": "diario", "puntos": puntos_reto(gano), "piso": piso,
		"pisos": pisos_superados(gano), "gano": gano, "tiempo": int(tiempo_partida),
		"bajas": enemigos_eliminados, "monedas": oro_total, "golpes": golpes,
	}


# ---------------------------------------------------------------- guardado
const CAMPOS_PARTIDA := ["vida", "vida_max", "oro", "piso", "enemigos_eliminados", "racha", "personaje", "mesa", "extremo",
	"diario", "imposible", "infinito", "deuda", "orden_jefes", "cartas", "objetos", "stats", "transformaciones", "novedades", "tiempo_partida",
	"mejor_combo", "oro_total", "ordagos", "presion", "fecha_reto", "reto_puntuable", "golpes", "contrato",
	"coop", "personaje2", "vida2", "vida_max2"]


func volcar() -> Dictionary:
	var datos := {"azar_seed": azar.seed, "azar_state": azar.state}
	for campo in CAMPOS_PARTIDA:
		datos[campo] = get(campo)
	return datos


func restaurar(datos: Dictionary) -> void:
	# Las partidas guardadas antes de que existieran los órdagos empiezan con los de siempre.
	ordagos = ORDAGOS_BASE
	contrato = []  # las guardadas antes del Contrato de la Casa no traen ninguno
	_sin_coop()  # ni las de antes del cooperativo traen segundo jugador
	_reiniciar_ritmo()
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
		"afeitado": int(c.get("por_los_pelos", 0)) >= 50,
		"mal_perdedor": int(c.get("mesas", 0)) >= 20,
		"roces": int(c.get("roces", 0)) >= 100,
		"desatado": int(c.get("desatados", 0)) >= 25,
		"servicio": int(c.get("propinas", 0)) >= 25,
		"cazador_raros": int(c.get("raros", 0)) >= 50,
		"mesa_oro": gano and mesa >= 4, "extremo": gano and extremo,
		"reto": diario,
		"cartas": Progreso.cartas_libres() >= CartasDB.CARTAS.size(),
	}
	for id in condiciones:
		if condiciones[id]:
			marcar_logro(id)


func jefe_del_piso() -> String:
	# En el modo infinito la lista crece: cada cinco pisos vuelve el Dueño.
	while infinito and orden_jefes.size() < piso:
		orden_jefes.append("dueno" if orden_jefes.size() % PISOS_TOTALES == PISOS_TOTALES - 1 else _jefe_infinito())
	return orden_jefes[clampi(piso - 1, 0, orden_jefes.size() - 1)]


func contexto_combo(con_azar := false) -> Dictionary:
	# En cooperativo, la vida que cuenta es la del que va peor de los que siguen en pie.
	var v := vida if not coop else (vida2 if vida <= 0 else (vida if vida2 <= 0 else mini(vida, vida2)))
	var ctx := {"monedas": oro, "racha": racha, "vida": v, "dano_global": stat("dano_global"),
		"fiebre": nivel_fiebre(), "voltereta": rodo_hace_poco(), "ordagos": ordagos}
	if con_azar:
		ctx["azar"] = azar_combate
	return ctx


# ---------------------------------------------------------------- fiebre, voltereta y órdagos
func _reiniciar_ritmo() -> void:
	fiebre = 0.0
	_fiebre_espera = 0.0
	ultima_voltereta = -100.0
	_al_maximo_t = 0.0
	_poner_desatado(false)
	en_combate = false


func nivel_fiebre() -> int:
	return clampi(floori(fiebre), 0, int(FIEBRE_MAX))


## Lo que acelera el ciclo de cartas: 1.0 sin fiebre, 1.45 al máximo y x1.5 desatado.
func factor_fiebre() -> float:
	return (1.0 + FIEBRE_ACELERA * nivel_fiebre()) * (DESATADO_CICLO if desatado else 1.0)


## Te queda un corazón o menos. En extremo siempre es así, y por eso no cuenta.
## En cooperativo, sin decir quién: si alguno de los dos que siguen en pie lo está.
func al_limite(i := -1) -> bool:
	if extremo:
		return false
	if i < 0 and coop:
		return al_limite(0) or al_limite(1)
	var v := vida_de(maxi(i, 0))
	return v > 0 and v <= 2


## Lo que queda de desatado, de 1.0 (recién empezado) a 0.0.
func desatado_resto() -> float:
	return clampf(_desatado_t / DESATADO_SEG, 0.0, 1.0) if desatado else 0.0


## Lo que multiplica la velocidad del jugador ahora mismo (al límite, desatado).
func factor_velocidad(i := -1) -> float:
	return (VELOCIDAD_AL_LIMITE if al_limite(i) else 1.0) * (DESATADO_VELOCIDAD if desatado else 1.0)


## Cuánto aprieta la partida ahora mismo, de 0.0 a 1.0: para la música y los efectos.
func intensidad() -> float:
	var valor := 0.45 * fiebre / FIEBRE_MAX
	if en_combate:
		valor += 0.3
	if al_limite():
		valor += 0.2
	if desatado:
		valor = maxf(valor, 0.85 + 0.15 * desatado_resto())
	return clampf(valor, 0.0, 1.0)


func subir_fiebre(cantidad: float) -> void:
	var antes := nivel_fiebre()
	if al_limite():
		cantidad *= FIEBRE_AL_LIMITE
	fiebre = minf(fiebre + cantidad, FIEBRE_MAX)
	_fiebre_espera = FIEBRE_ESPERA * (1.0 + stat("fiebre_dura"))
	_avisar_fiebre(antes)


## Cada baja mientras estás desatado lo estira un poco: se encadena si sigues matando.
func alargar_desatado() -> void:
	if desatado:
		_desatado_t = minf(_desatado_t + DESATADO_POR_BAJA, DESATADO_SEG)


## Si pasas un rato sin matar, la fiebre se va enfriando. Aquí corre también el desatado.
func enfriar_fiebre(delta: float) -> void:
	_mirar_desatado(delta)
	if fiebre <= 0.0 or desatado:
		return
	_fiebre_espera -= delta
	if _fiebre_espera > 0.0:
		return
	var antes := nivel_fiebre()
	fiebre = maxf(fiebre - FIEBRE_CAIDA / (1.0 + stat("fiebre_dura")) * delta, 0.0)
	_avisar_fiebre(antes)


## Al máximo un rato seguido: desatado. Al acabar, la fiebre baja un escalón.
func _mirar_desatado(delta: float) -> void:
	if desatado:
		_desatado_t -= delta
		if _desatado_t <= 0.0:
			var antes := nivel_fiebre()
			_poner_desatado(false)
			fiebre = minf(fiebre, FIEBRE_MAX - 1.0)
			_fiebre_espera = FIEBRE_ESPERA
			_avisar_fiebre(antes)
		return
	if fiebre >= FIEBRE_MAX and en_combate:
		_al_maximo_t += delta
		if _al_maximo_t >= DESATADO_CARGA:
			_desatado_t = DESATADO_SEG
			_poner_desatado(true)
	else:
		_al_maximo_t = 0.0


func _poner_desatado(activo: bool) -> void:
	_al_maximo_t = 0.0
	if not activo:
		_desatado_t = 0.0
	if desatado == activo:
		return
	desatado = activo
	desatado_cambiado.emit(activo)
	estado_cambiado.emit()


## Un golpe te la quita entera (y corta el desatado).
func vaciar_fiebre() -> void:
	_poner_desatado(false)
	if fiebre <= 0.0:
		return
	var antes := nivel_fiebre()
	fiebre = 0.0
	_fiebre_espera = 0.0
	_avisar_fiebre(antes)


func _avisar_fiebre(antes: int) -> void:
	if nivel_fiebre() == antes:
		return
	fiebre_cambiada.emit(nivel_fiebre())
	estado_cambiado.emit()  # la barra recalcula la previsión del combo


func rodo_hace_poco() -> bool:
	return tiempo_partida - ultima_voltereta <= VOLTERETA_RECIENTE


func gastar_ordago() -> bool:
	if ordagos <= 0:
		return false
	ordagos -= 1
	estado_cambiado.emit()
	return true


func ganar_ordagos(cuantos: int) -> void:
	ordagos += cuantos
	estado_cambiado.emit()


## Al bajar de piso: vuelves a tener al menos los de base (más los de tus objetos).
func rellenar_ordagos() -> void:
	ordagos = maxi(ordagos, ORDAGOS_BASE + int(stat("ordago_extra")))
	estado_cambiado.emit()


## ¿Lleva esta partida esa cláusula del Contrato de la Casa?
func clausula(id: String) -> bool:
	return contrato.has(id)


## El calor de la partida: la suma de sus cláusulas.
func calor() -> int:
	return PersonajesDB.calor_de(contrato)


func stat(nombre: String) -> float:
	return float(stats.get(nombre, 0.0))


func tiene_objeto(id: String) -> bool:
	return objetos.has(id)


func dar_objeto(id: String) -> void:
	var cerca_antes := ObjetosDB.a_un_paso(objetos, transformaciones)
	objetos.append(id)
	if Progreso.ver("objetos", id):
		Progreso.guardar()
	var efecto: Dictionary = ObjetosDB.OBJETOS[id].efecto
	for clave in efecto:
		match String(clave):
			"vida_max":
				vida_max += int(efecto[clave])
				if not coop or vida > 0:  # al caído no lo levanta un objeto
					vida = vida_max
				if coop:  # los corazones de un objeto son para los dos
					vida_max2 += int(efecto[clave])
					if vida2 > 0:
						vida2 = vida_max2
			"ranura":
				anadir_ranura()
			"monedas":
				oro += int(efecto[clave])
			"ordagos":
				ordagos += int(efecto[clave])
			_:
				stats[clave] = float(stats.get(clave, 0.0)) + float(efecto[clave])
	_comprobar_transformaciones()
	for t in ObjetosDB.a_un_paso(objetos, transformaciones):
		if not cerca_antes.has(t) and ObjetosDB.pista_permitida(t):
			a_un_paso.emit(t)
	estado_cambiado.emit()


## Con get: una partida guardada antes de añadir una estadística no la trae.
func _sumar_efecto(efecto: Dictionary) -> void:
	for clave in efecto:
		stats[clave] = float(stats.get(clave, 0.0)) + float(efecto[clave])


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
	poner_vida(titular, mini(vida_titular(), vida_max_titular() - 2), vida_max_titular() - 2)
	ganar_oro(30)


func pedir_prestamo() -> void:
	deuda = 60
	ganar_oro(40)


func _jefe_infinito() -> String:
	var candidatos: Array = JEFES_CASINO.filter(func(id): return id != orden_jefes[-1])
	return candidatos[azar.randi() % candidatos.size()]


## Pisos jugados más allá del final normal. Todo el modo infinito escala con esto.
func pisos_extra() -> int:
	return maxi(piso - PISOS_TOTALES, 0) if infinito else 0


func empezar_infinito() -> void:
	infinito = true
	novedades = []


## Multiplicador de la vida de los jefes según el piso: al final vas muy fuerte.
func refuerzo_jefe() -> float:
	# Con solo dos ranuras no llegas a esos daños, así que el imposible no lo lleva.
	if imposible:
		return 1.0
	var base: float = REFUERZO_JEFE[clampi(piso - 1, 0, REFUERZO_JEFE.size() - 1)]
	return base * pow(1.35, pisos_extra())


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
	marcar_logro("deudor")
	if coop:  # a medias: medio corazón de cada uno
		vida_max = maxi(vida_max - 1, 2)
		vida = mini(vida, vida_max)
		vida_max2 = maxi(vida_max2 - 1, 2)
		vida2 = mini(vida2, vida_max2)
		estado_cambiado.emit()
		return Idioma.t("EL PRESTAMISTA OS COBRA MEDIO CORAZÓN A CADA UNO")
	vida_max = maxi(vida_max - 2, 2)
	vida = mini(vida, vida_max)
	estado_cambiado.emit()
	return Idioma.t("EL PRESTAMISTA TE COBRA UN CORAZÓN")


## Un objeto que aún no tengas. Devuelve "" si ya los tienes todos.
## Baraja la bolsa entera y da el primero que no tengas: con el mismo azar sale lo mismo
## a todo el mundo, salvo que ya lo lleves (y el azar gastado no depende de lo que lleves).
func robar_objeto(excluir := [], rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = azar
	var bolsa: Array = []
	for id in ObjetosDB.OBJETOS:
		if extremo and OBJETOS_PROHIBIDOS_EXTREMO.has(id):
			continue
		if imposible and id == "ficha_vip":
			continue
		if objeto_en_bolsa(id):
			bolsa.append(id)
	for i in range(bolsa.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = bolsa[i]
		bolsa[i] = bolsa[j]
		bolsa[j] = t
	for id in bolsa:
		if not objetos.has(id) and not excluir.has(id):
			return id
	return ""


func precio_final(base: int) -> int:
	var recargo := 1.3 if mesa >= 3 else 1.0
	if clausula("recargo"):
		recargo *= 1.3
	return maxi(1, roundi(base * recargo * (1.0 - minf(stat("descuento"), 0.8))))


func hay_hueco() -> bool:
	return cartas.has("")


## Cuántas copias de esa carta hay en la fila. "sin": una ranura que no cuenta
## (la que vas a cambiar: cambiar una copia por otra igual no suma).
func copias(id: String, sin := -1) -> int:
	var n := 0
	for i in cartas.size():
		if i != sin and cartas[i] == id:
			n += 1
	return n


## Ya llevas todas las copias que caben de esa carta: ni sale ni se puede poner otra.
func carta_al_tope(id: String, sin := -1) -> bool:
	return copias(id, sin) >= COPIAS_MAX


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


## Las ranuras que caben como mucho en esta partida.
func ranuras_tope() -> int:
	return RANURAS_IMPOSIBLE if imposible else RANURAS_MAX


func anadir_ranura() -> void:
	if cartas.size() < ranuras_tope():
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


## "i": de qué jugador (0 J1, 1 J2); sin decirlo, el titular (en solitario, siempre J1).
func curar(cantidad: int, i := -1) -> void:
	if i < 0:
		i = titular
	poner_vida(i, mini(vida_de(i) + cantidad, vida_max_de(i)), vida_max_de(i))


func herir(cantidad: int, i := -1) -> void:
	if i < 0:
		i = titular
	poner_vida(i, 0 if extremo else maxi(vida_de(i) - cantidad, 0), vida_max_de(i))
	racha = 0
	estado_cambiado.emit()


## Saca cartas distintas entre sí. Con suerte > 0 salen más raras (tesoros).
## Las que ya llevas repetidas hasta el tope no salen: se tiran y se vuelve a sacar,
## así quien no lleva ninguna al tope ve lo mismo que antes con el mismo azar.
func robar_cartas(cuantas: int, suerte := 0.0, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = azar
	var bolsa: Array = CartasDB.CARTAS.keys().filter(func(id): return carta_en_bolsa(id))
	var elegidas: Array = []
	var suerte_total := suerte + stat("suerte")
	while elegidas.size() < cuantas and not bolsa.is_empty():
		var pesos: Array = []
		var suma := 0.0
		for id in bolsa:
			var peso: float = CartasDB.PESO_RAREZA[CartasDB.CARTAS[id].rareza]
			if CartasDB.CARTAS[id].rareza > 0:
				peso *= 1.0 + suerte_total
			suma += peso
			pesos.append(peso)
		var tirada := rng.randf() * suma
		for j in bolsa.size():
			tirada -= pesos[j]
			if tirada <= 0.0 or j == bolsa.size() - 1:
				if not carta_al_tope(bolsa[j]):
					elegidas.append(bolsa[j])
				bolsa.remove_at(j)
				break
	return elegidas


# ---------------------------------------------------------------- cooperativo
## Dos jugadores en la misma sala. Lo de la partida (cartas, oro, objetos, Fiebre, órdagos)
## es de los dos; cada uno tiene sus corazones: los del J1 son vida y vida_max (como siempre)
## y los del J2, vida2 y vida_max2. El J2 elige su personaje solo por su aspecto y su vida.
var coop := false
var personaje2 := ""
var vida2 := 0
var vida_max2 := 0
## Quién maneja lo que se abra (tienda, evento, apuestas): 0 el J1, 1 el J2. Lo pone main.
var titular := 0


func _sin_coop() -> void:
	coop = false
	personaje2 = ""
	vida2 = 0
	vida_max2 = 0
	titular = 0


## Tras nueva_partida: entra el J2 con su personaje (mismas reglas de vida que el J1).
func activar_coop(id2: String) -> void:
	coop = true
	personaje2 = id2 if PersonajesDB.PERSONAJES.has(id2) else personaje
	var datos: Dictionary = PersonajesDB.PERSONAJES[personaje2]
	vida_max2 = 2 if extremo else int(datos.vida) - (2 if mesa >= 4 else 0)
	if clausula("corazon"):
		vida_max2 = maxi(vida_max2 - 2, 2)
	vida2 = vida_max2
	titular = 0
	estado_cambiado.emit()


## Se sigue en solitario (el J2 no ha vuelto a unirse al continuar).
func quitar_coop() -> void:
	_sin_coop()
	estado_cambiado.emit()


func vida_de(i: int) -> int:
	return vida2 if i == 1 and coop else vida


func vida_max_de(i: int) -> int:
	return vida_max2 if i == 1 and coop else vida_max


func vida_titular() -> int:
	return vida_de(titular)


func vida_max_titular() -> int:
	return vida_max_de(titular)


func poner_vida(i: int, nueva: int, nueva_max: int) -> void:
	if i == 1 and coop:
		vida2 = nueva
		vida_max2 = nueva_max
	else:
		vida = nueva
		vida_max = nueva_max
	estado_cambiado.emit()


## Una cura para el equipo (el jefe vencido, el élite con el Collar): a los que sigan en pie.
func curar_equipo(cantidad: int) -> void:
	if vida > 0:
		curar(cantidad, 0)
	if coop and vida2 > 0:
		curar(cantidad, 1)
