class_name Online
extends Node
## La tabla mundial del reto diario. Lo crea main.gd por código (no es un autoload).
##
## Habla con un proyecto de Supabase (ver servidor/README.md) por su API REST: cada cosa
## es una llamada a una función SQL (POST /rest/v1/rpc/<función>). Si no hay online.cfg,
## o le falta la URL o la clave anónima, todo esto queda apagado: no se ve nada y no se hace
## ni una petición. Nunca bloquea el juego: todo va por señales y con tiempo máximo.
##
## La cuenta es anónima, una por dispositivo: un identificador al azar guardado en user://
## y un token que da el servidor. Encima, un nombre público que elige el jugador.

signal tabla_lista(datos: Dictionary)  # datos.tipo: "dia" o "historico"
signal tabla_fallida(tipo: String, motivo: String)  # motivo: "sin_conexion" o "servidor"
signal nombre_resultado(ok: bool, error: String)
signal envio_terminado(ok: bool, error: String)

## Se mira primero el de user:// (cómodo para probar) y luego el que va dentro del juego.
const RUTAS_CONFIG := ["user://online.cfg", "res://online.cfg"]
const RUTA_CUENTA := "user://cuenta.cfg"
## Súbela con cada versión que cambie el reto: el servidor solo acepta las que tenga activas.
const VERSION := "1.7"
const TIEMPO_MAXIMO := 8.0  # segundos por petición
const REINTENTO := 60.0  # cada cuánto se reintenta la cola de envíos pendientes
const LIMITE_TABLA := 50
const NOMBRE_MIN := 3
const NOMBRE_MAX := 16
## Filtro básico de insultos (ES/EN). Se compara con el nombre en minúsculas, sin acentos,
## sin guiones y deshaciendo el "leet" (0→o, 1→i...). El servidor tiene la misma lista.
const PALABRAS_FEAS := ["puta", "puto", "mierda", "cabron", "gilipollas", "maricon", "marica", "polla",
	"zorra", "joder", "follar", "subnormal", "retrasado", "pendejo", "culero", "verga", "chinga", "nazi",
	"hitler", "fuck", "shit", "bitch", "cunt", "nigger", "nigga", "faggot", "whore", "slut", "asshole",
	"retard", "rape", "penis", "admin"]

var activo := false
var url := ""
var clave := ""
var secreto := ""
var rutas_config: Array = RUTAS_CONFIG
var ruta_cuenta := RUTA_CUENTA
## Cuántas peticiones se han lanzado (lo miran las pruebas: apagado tiene que ser 0).
var peticiones_hechas := 0
var ultimo_error := ""

var dispositivo := ""
var token := ""
var jugador_id := ""
var nombre := ""
var _pendientes: Array = []
var _registrando := false
var _al_registrar: Array = []  # lo que espera a tener cuenta
var _enviando := false
var _reintento_t := 0.0


func _ready() -> void:
	# El menú pausa el árbol: aun así las peticiones tienen que avanzar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cargar_config()
	if activo:
		_cargar_cuenta()
		_procesar_cola()


func _process(delta: float) -> void:
	if not activo or _pendientes.is_empty() or _enviando:
		return
	_reintento_t -= delta
	if _reintento_t <= 0.0:
		_procesar_cola()


# ---------------------------------------------------------------- configuración
func _cargar_config() -> void:
	for ruta in rutas_config:
		if not FileAccess.file_exists(ruta):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(ruta) != OK:
			continue
		configurar(String(cfg.get_value("online", "url", "")), String(cfg.get_value("online", "clave_anonima", "")),
				String(cfg.get_value("online", "secreto", "")))
		return
	activo = false


## La URL del proyecto (https://xxxx.supabase.co), su clave anónima (pública) y el secreto
## con el que se firman los envíos. Sin URL o sin clave, todo apagado.
func configurar(nueva_url: String, nueva_clave: String, nuevo_secreto := "") -> void:
	url = nueva_url.strip_edges().trim_suffix("/")
	clave = nueva_clave.strip_edges()
	secreto = nuevo_secreto.strip_edges()
	activo = url != "" and clave != ""
	if activo and is_inside_tree():
		_cargar_cuenta()


# ---------------------------------------------------------------- cuenta
func _cargar_cuenta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ruta_cuenta) == OK:
		dispositivo = String(cfg.get_value("cuenta", "dispositivo", ""))
		token = String(cfg.get_value("cuenta", "token", ""))
		jugador_id = String(cfg.get_value("cuenta", "jugador", ""))
		nombre = String(cfg.get_value("cuenta", "nombre", ""))
		_pendientes = cfg.get_value("cola", "pendientes", [])
	if dispositivo == "":
		dispositivo = Crypto.new().generate_random_bytes(16).hex_encode()
		_guardar_cuenta()


func _guardar_cuenta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("cuenta", "dispositivo", dispositivo)
	cfg.set_value("cuenta", "token", token)
	cfg.set_value("cuenta", "jugador", jugador_id)
	cfg.set_value("cuenta", "nombre", nombre)
	cfg.set_value("cola", "pendientes", _pendientes)
	cfg.save(ruta_cuenta)


func necesita_nombre() -> bool:
	return activo and nombre == ""


func pendientes() -> int:
	return _pendientes.size()


## Pide cuenta al servidor si aún no hay token, y luego llama a `siguiente(ok)`.
func _con_cuenta(siguiente: Callable) -> void:
	if token != "":
		siguiente.call(true)
		return
	_al_registrar.append(siguiente)
	if _registrando:
		return
	_registrando = true
	_llamar("registrar", {"p_dispositivo": dispositivo}, _al_registrarse)


func _al_registrarse(red: bool, datos: Dictionary) -> void:
	_registrando = false
	var ok: bool = red and datos.get("ok", false)
	if ok:
		token = String(datos.get("token", ""))
		jugador_id = String(datos.get("jugador", ""))
		var del_servidor = datos.get("nombre", null)
		if del_servidor is String and del_servidor != "":
			nombre = del_servidor
		_guardar_cuenta()
	var esperando := _al_registrar
	_al_registrar = []
	for siguiente in esperando:
		siguiente.call(ok and token != "")


# ---------------------------------------------------------------- nombre
## "" si vale; si no, por qué no: "nombre_corto", "nombre_largo", "nombre_invalido" o "nombre_feo".
static func revisar_nombre(texto: String) -> String:
	var n := limpiar_nombre(texto)
	if n.length() < NOMBRE_MIN:
		return "nombre_corto"
	if n.length() > NOMBRE_MAX:
		return "nombre_largo"
	var regex := RegEx.create_from_string("^[A-Z0-9Ñ-]+$")
	if regex.search(n) == null:
		return "nombre_invalido"
	var plano := _normalizar(n)
	for palabra in PALABRAS_FEAS:
		if plano.contains(palabra):
			return "nombre_feo"
	return ""


## Mayúsculas, sin tildes y los espacios como guiones: así se guarda y se enseña
## (la fuente del juego no tiene guion bajo).
static func limpiar_nombre(texto: String) -> String:
	var n := texto.strip_edges().to_upper()
	for par in [["Á", "A"], ["É", "E"], ["Í", "I"], ["Ó", "O"], ["Ú", "U"], ["Ü", "U"], [" ", "-"]]:
		n = n.replace(par[0], par[1])
	return n


static func _normalizar(n: String) -> String:
	var t := n.to_lower()
	for par in [["ñ", "n"], ["0", "o"], ["1", "i"], ["3", "e"], ["4", "a"], ["5", "s"], ["7", "t"], ["8", "b"], ["-", ""]]:
		t = t.replace(par[0], par[1])
	return t


func elegir_nombre(texto: String) -> void:
	var error := revisar_nombre(texto)
	if not activo:
		error = "apagado"
	if error != "":
		nombre_resultado.emit(false, error)
		return
	var limpio := limpiar_nombre(texto)
	_con_cuenta(func(ok: bool) -> void:
		if not ok:
			nombre_resultado.emit(false, "sin_conexion")
			return
		_llamar("poner_nombre", {"p_token": token, "p_nombre": limpio}, _al_poner_nombre))


func _al_poner_nombre(red: bool, datos: Dictionary) -> void:
	if not red:
		nombre_resultado.emit(false, "sin_conexion")
		return
	if not datos.get("ok", false):
		nombre_resultado.emit(false, String(datos.get("error", "servidor")))
		return
	nombre = String(datos.get("nombre", ""))
	_guardar_cuenta()
	nombre_resultado.emit(true, "")
	_procesar_cola()


# ---------------------------------------------------------------- envío de puntuaciones
## Al terminar el intento puntuable del reto. Va a la cola y se envía en cuanto se pueda.
func enviar_reto(resumen: Dictionary) -> void:
	if not activo:
		return
	var envio := resumen.duplicate()
	envio["version"] = VERSION
	_pendientes.append(envio)
	_guardar_cuenta()
	_procesar_cola()


## El texto que se firma. El servidor monta exactamente el mismo (servidor/esquema.sql).
static func texto_firma(tok: String, e: Dictionary) -> String:
	return "%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%s" % [tok, String(e.fecha), String(e.modo), int(e.puntos), int(e.piso),
		int(e.pisos), 1 if e.gano else 0, int(e.tiempo), int(e.bajas), int(e.monedas), int(e.golpes), String(e.version)]


static func firmar(clave_secreta: String, texto: String) -> String:
	if clave_secreta == "":
		return ""
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, clave_secreta.to_utf8_buffer(), texto.to_utf8_buffer()).hex_encode()


func _procesar_cola() -> void:
	if not activo or _enviando or _pendientes.is_empty():
		return
	_enviando = true
	_reintento_t = REINTENTO
	_con_cuenta(func(ok: bool) -> void:
		if not ok:
			_enviando = false
			return
		_enviar(_pendientes[0]))


func _enviar(e: Dictionary) -> void:
	var cuerpo := {
		"p_token": token, "p_fecha": e.fecha, "p_modo": e.modo, "p_puntos": int(e.puntos), "p_piso": int(e.piso),
		"p_pisos": int(e.pisos), "p_gano": bool(e.gano), "p_tiempo": int(e.tiempo), "p_bajas": int(e.bajas),
		"p_monedas": int(e.monedas), "p_golpes": int(e.golpes), "p_version": String(e.version),
		"p_firma": firmar(secreto, texto_firma(token, e)),
	}
	_llamar("enviar_puntuacion", cuerpo, _al_enviar)


func _al_enviar(red: bool, datos: Dictionary) -> void:
	_enviando = false
	if not red:
		# Sin red: se queda en la cola y se reintenta más tarde.
		envio_terminado.emit(false, "sin_conexion")
		return
	var error := String(datos.get("error", ""))
	if error == "token":
		# La cuenta ya no existe en el servidor: se pide otra y se reintenta.
		token = ""
		_guardar_cuenta()
		_reintento_t = 1.0
		envio_terminado.emit(false, error)
		return
	# Aceptada, repetida o rechazada para siempre (fuera de plazo, versión vieja...): fuera de la cola.
	if not _pendientes.is_empty():
		_pendientes.pop_front()
	_guardar_cuenta()
	var ok: bool = datos.get("ok", false)
	ultimo_error = "" if ok else error
	envio_terminado.emit(ok, error)
	if not _pendientes.is_empty():
		_procesar_cola()


# ---------------------------------------------------------------- tablas
## Los 50 mejores de esa fecha y tu posición (aunque estés más abajo).
func pedir_tabla(fecha: String) -> void:
	if not activo:
		return
	# Mirar no crea cuenta: sin token simplemente no viene tu fila.
	_llamar("tabla_diaria", {"p_fecha": fecha, "p_modo": "diario", "p_token": token, "p_limite": LIMITE_TABLA},
			_al_recibir_tabla.bind("dia"))


## La mejor marca de un día de cada jugador, de siempre.
func pedir_historico() -> void:
	if not activo:
		return
	_llamar("tabla_historica", {"p_token": token, "p_limite": LIMITE_TABLA}, _al_recibir_tabla.bind("historico"))


func _al_recibir_tabla(red: bool, datos: Dictionary, tipo: String) -> void:
	if not red:
		tabla_fallida.emit(tipo, "sin_conexion")
		return
	if not datos.get("ok", false):
		tabla_fallida.emit(tipo, "servidor")
		return
	datos["tipo"] = tipo
	tabla_lista.emit(datos)


## Borra la cuenta del servidor (nombre y puntuaciones) y la de este dispositivo.
func borrar_cuenta() -> void:
	if not activo or token == "":
		return
	_llamar("borrar_cuenta", {"p_token": token}, func(_red: bool, _datos: Dictionary) -> void: pass)
	token = ""
	jugador_id = ""
	nombre = ""
	_pendientes = []
	_guardar_cuenta()


# ---------------------------------------------------------------- HTTP
## Una petición a una función del servidor. `al_acabar(red_ok, datos)`: red_ok es false si
## no hubo respuesta útil (sin conexión, tiempo agotado, CORS, error 5xx o JSON roto).
func _llamar(funcion: String, cuerpo: Dictionary, al_acabar: Callable) -> void:
	if not activo:
		al_acabar.call(false, {})
		return
	var http := HTTPRequest.new()
	http.timeout = TIEMPO_MAXIMO
	add_child(http)
	var cabeceras := PackedStringArray(["Content-Type: application/json", "apikey: " + clave])
	# Las claves anónimas antiguas son un JWT y van también como Bearer; las nuevas
	# ("sb_publishable_...") no son JWT y basta con la cabecera apikey.
	if clave.begins_with("eyJ"):
		cabeceras.append("Authorization: Bearer " + clave)
	http.request_completed.connect(_al_completar.bind(http, al_acabar))
	peticiones_hechas += 1
	var error := http.request("%s/rest/v1/rpc/%s" % [url, funcion], cabeceras, HTTPClient.METHOD_POST, JSON.stringify(cuerpo))
	if error != OK:
		http.queue_free()
		al_acabar.call(false, {})


func _al_completar(resultado: int, codigo: int, _cabeceras: PackedStringArray, cuerpo: PackedByteArray,
		http: HTTPRequest, al_acabar: Callable) -> void:
	http.queue_free()
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo == 0 or codigo >= 500:
		al_acabar.call(false, {})
		return
	var datos = JSON.parse_string(cuerpo.get_string_from_utf8())
	if not (datos is Dictionary):
		# PostgREST devuelve {"message": ...} en los errores 4xx: cuenta como respuesta, pero mala.
		al_acabar.call(codigo < 400, {"ok": false, "error": "servidor"})
		return
	if codigo >= 400 and not datos.has("ok"):
		datos = {"ok": false, "error": "servidor", "detalle": datos.get("message", "")}
	al_acabar.call(true, datos)
