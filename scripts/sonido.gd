class_name Sonido
extends Node
## Efectos y música. Se usa con Sonido.tocar("moneda") desde cualquier sitio.
## La música aprieta sola: con Juego.intensidad() sube de tono y entra una capa de percusión,
## y al límite suena un latido a tempo. Sin buses propios: todo con volume_db y pitch_scale.

const EFECTOS := [
	"disparo", "carta", "rayo", "explosion", "golpe", "muerte", "dano", "moneda", "puerta_cierra", "puerta_abre",
	"comprar", "carta_coger", "objeto", "transformacion", "tick", "mult", "clic", "mover", "jefe_aparece",
	"jefe_muere", "bajar", "victoria", "derrota", "ganar", "perder", "mezclar",
	"voltereta", "ordago", "mesa", "mesa_rota", "escopeta", "metralleta", "laser", "mina", "barrido", "fiebre",
	"por_los_pelos", "impacto_fuerte", "casquillo",
	"roce", "latido", "desatado", "oleada", "remate", "aviso",
]
const MUSICAS := ["menu", "piso", "jefe", "victoria"]
## Las pistas que se aceleran, con su tempo (para el latido). Su capa es musica_<nombre>_capa.wav.
const TEMPO := {"piso": 128.0, "jefe": 152.0}
const VOCES := 20
const SEPARACION_MS := 45  # si suenan veinte golpes a la vez, solo se oyen unos pocos
const SEPARACION := {"muerte": 50, "aviso": 70, "casquillo": 60, "roce": 70, "metralleta": 35}

## 2: no se pierde nunca. 1: importa. Lo que no está aquí (0) es el ruido de la pelea.
const PRIORIDAD := {
	"dano": 2, "perder": 2, "ordago": 2, "remate": 2, "desatado": 2, "jefe_aparece": 2, "jefe_muere": 2,
	"derrota": 2, "victoria": 2, "transformacion": 2,
	"fiebre": 1, "oleada": 1, "roce": 1, "por_los_pelos": 1, "objeto": 1, "comprar": 1, "carta_coger": 1,
	"puerta_cierra": 1, "puerta_abre": 1, "bajar": 1, "mult": 1, "ganar": 1, "explosion": 1, "escopeta": 1,
	"laser": 1, "rayo": 1, "mesa": 1, "mesa_rota": 1, "voltereta": 1, "impacto_fuerte": 1,
}
## Voces que puede llenar cada prioridad: siempre quedan unas libres para lo importante.
const TOPE_PRIORIDAD := [10, 16, VOCES]
## Cuántas veces a la vez puede sonar un mismo efecto (si no está, 3). Los gordos, una:
## si se repiten, vuelven a empezar en vez de sumarse (dos remates juntos saturan).
const TOPE_IGUALES := {"golpe": 4, "muerte": 4, "casquillo": 2, "aviso": 2, "roce": 2, "clic": 2,
	"dano": 1, "remate": 1, "desatado": 1, "ordago": 1, "oleada": 1}
## El pico de cada WAV (el que le da tools/generar_sonidos.py al guardarlo): para saber cuánto suma la mezcla.
const PICO := {
	"disparo": 0.45, "carta": 0.4, "rayo": 0.45, "explosion": 0.8, "golpe": 0.48, "muerte": 0.5, "dano": 0.8,
	"moneda": 0.4, "puerta_cierra": 0.8, "puerta_abre": 0.6, "comprar": 0.5, "carta_coger": 0.7, "objeto": 0.55,
	"transformacion": 0.6, "tick": 0.35, "mult": 0.5, "clic": 0.35, "mover": 0.3, "jefe_aparece": 0.8,
	"jefe_muere": 0.85, "bajar": 0.7, "victoria": 0.6, "derrota": 0.75, "ganar": 0.5, "perder": 0.55, "mezclar": 0.3,
	"voltereta": 0.35, "ordago": 0.85, "mesa": 0.65, "mesa_rota": 0.65, "escopeta": 0.8, "metralleta": 0.4,
	"laser": 0.4, "mina": 0.35, "barrido": 0.42, "fiebre": 0.45, "por_los_pelos": 0.45, "impacto_fuerte": 0.7,
	"casquillo": 0.25, "roce": 0.32, "latido": 0.7, "desatado": 0.75, "oleada": 0.7, "remate": 0.85, "aviso": 0.22,
}
## Si lo que ya suena (picos que se van apagando) más lo nuevo pasa de aquí, lo de prioridad 0 y 1
## entra más bajo, hasta TECHO_MAX_DB. Sin limitador en el bus (en la web no lo hay), esto evita saturar.
const TECHO := 0.7
const TECHO_MAX_DB := 12.0
## Lo que suena sin parar cambia un poco de tono cada vez, para no cansar.
const VARIAR := ["golpe", "muerte", "disparo", "carta", "metralleta", "casquillo", "aviso", "moneda",
	"impacto_fuerte", "escopeta", "barrido", "mesa", "roce"]
const VARIACION := [0.0, 0.03, -0.025, 0.05, -0.04, 0.015]
## Bajas o roces seguidos suben de tono: [semitonos por paso, pasos máximos, pasos que se pierden por segundo].
const CADENAS := {"muerte": [0.6, 8.0, 3.0], "roce": [1.0, 5.0, 1.5]}
## Lo que hace que el ruido de golpes se aparte un momento.
const AGACHAN := ["dano", "perder", "ordago", "remate", "desatado", "jefe_aparece", "jefe_muere"]
const AGACHAR_DB := 7.0

const SUBIDA_TONO := 0.1  # pitch_scale extra de la música con la intensidad al máximo
const SUBIDA_DESATADO := 0.05
const TONO_LENTO := 0.9  # en cámara lenta la música también se arrastra
const FUERA_DE_COMBATE_DB := -3.0
const EN_PAUSA_DB := -5.0
const AL_LIMITE_DB := -1.5  # deja sitio al latido
const CAPA_DB := -1.0
const LATIDO_DB := -9.0

static var _yo: Sonido

var _efectos := {}
var _largo := {}
var _musicas := {}
var _capas := {}
var _voces: Array[AudioStreamPlayer] = []
var _nombre_voz: Array[String] = []
var _prio_voz := PackedInt32Array()
var _inicio_voz := PackedInt64Array()
var _fin_voz := PackedInt64Array()
var _base_db := PackedFloat32Array()
var _nivel_voz := PackedFloat32Array()  # pico que suelta cada voz al empezar, ya con su volumen
var _carga := 0.0
var _ultimo := {}
var _avisados := {}
var _vueltas := {}
var _cadena := {}
var _activas_bajas := 0
var _agachado := 0.0
var _agachado_puesto := 0.0
var _agachado_hasta := 0
var _db_efectos := 0.0

var _reproductor_musica: AudioStreamPlayer
var _capa: AudioStreamPlayer
var _latido: AudioStreamPlayer
var _musica_actual := ""
var _largo_musica := 0.0
var _db_musica := 0.0
var _ajuste_musica := 0.0
var _ganancia_capa := 0.0
var _tono := 1.0
var _nivel := 0.0  # la intensidad por escalones, para que la música no ondule con cada baja
var _pos_musica := 0.0  # segundos de pista, llevados a mano para ir a tempo
var _ultimo_pulso := -1
var _lento := 0.0
var _tras_lento := 0.0
var _revisar := 0.0
var _ultimo_us := 0
var _latiendo := false
var _latido_ms := 0  # cuándo empezó el último latido que ha sonado

# Lo que se lee de Juego en cada fotograma.
var _pausado := false
var _combate := false
var _limite := false
var _desatado := false
var _intensidad := 0.0


static func tocar(nombre: String, tono := 1.0, ajuste_db := 0.0) -> void:
	if _yo != null:
		_yo._tocar(nombre, tono, ajuste_db)


static func musica(nombre: String) -> void:
	if _yo != null:
		_yo._poner_musica(nombre)


static func aplicar_volumenes(musica_lineal: float, efectos_lineal: float) -> void:
	if _yo != null:
		_yo._db_efectos = _a_db(efectos_lineal)
		_yo._db_musica = _a_db(musica_lineal)
		_yo._aplicar_musica(true)


## El latido que se oye, de 0 a 1 (un golpe y otro más flojo detrás), para que lo que late en
## pantalla vaya con el sonido. Si no está sonando, uno de reserva a 75 por minuto.
static func latido() -> float:
	var t := fmod(Time.get_ticks_msec() / 1000.0, 0.8)
	if _yo != null and _yo._latiendo:
		t = float(Time.get_ticks_msec() - _yo._latido_ms) / 1000.0 * _yo._latido.pitch_scale
	return minf(exp(-pow(t / 0.05, 2.0)) + 0.6 * exp(-pow((t - 0.18) / 0.045, 2.0)), 1.0)


## Sin buses propios a propósito: en la versión web, los creados por código dejan mudo el audio.
static func _a_db(lineal: float) -> float:
	return linear_to_db(lineal) if lineal > 0.001 else -80.0


func _ready() -> void:
	_yo = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for nombre in EFECTOS:
		var efecto: AudioStream = load("res://assets/sonido/%s.wav" % nombre)
		_efectos[nombre] = efecto
		if efecto != null:
			_largo[nombre] = efecto.get_length()
	for nombre in MUSICAS:
		_musicas[nombre] = _en_bucle(load("res://assets/sonido/musica_%s.wav" % nombre))
	for nombre in TEMPO:
		var ruta := "res://assets/sonido/musica_%s_capa.wav" % nombre
		if ResourceLoader.exists(ruta):
			_capas[nombre] = _en_bucle(load(ruta))
	for _i in VOCES:
		var voz := AudioStreamPlayer.new()
		add_child(voz)
		_voces.append(voz)
		_nombre_voz.append("")
	_prio_voz.resize(VOCES)
	_inicio_voz.resize(VOCES)
	_fin_voz.resize(VOCES)
	_base_db.resize(VOCES)
	_nivel_voz.resize(VOCES)
	_reproductor_musica = AudioStreamPlayer.new()
	add_child(_reproductor_musica)
	_capa = AudioStreamPlayer.new()
	_capa.volume_db = -80.0
	add_child(_capa)
	_latido = AudioStreamPlayer.new()
	_latido.stream = _efectos.get("latido")
	add_child(_latido)
	_ultimo_us = Time.get_ticks_usec()
	Sonido.aplicar_volumenes(Juego.volumen_musica, Juego.volumen_efectos)


## Al cerrar, nada sonando: si no, el servidor de audio se queda con las pistas.
func _exit_tree() -> void:
	for reproductor in _voces + [_reproductor_musica, _capa, _latido]:
		reproductor.stop()
		reproductor.stream = null
	if _yo == self:
		_yo = null


func _en_bucle(pista: AudioStreamWAV) -> AudioStreamWAV:
	pista.loop_mode = AudioStreamWAV.LOOP_FORWARD
	pista.loop_begin = 0
	pista.loop_end = int(pista.get_length() * pista.mix_rate)
	return pista


# ------------------------------------------------------------ efectos
func _tocar(nombre: String, tono: float, ajuste_db: float) -> void:
	# Un nombre que no existe no debe tumbar la partida: se avisa una vez y no suena.
	var efecto: AudioStream = _efectos.get(nombre)
	if efecto == null:
		if not _avisados.has(nombre):
			_avisados[nombre] = true
			push_warning("Sonido desconocido: %s" % nombre)
		return
	var ahora := Time.get_ticks_msec()
	if CADENAS.has(nombre):
		# El azar del que llama se suaviza para que la subida se note.
		tono = (1.0 + (tono - 1.0) * 0.4) * _subir_cadena(nombre)
	if ahora - int(_ultimo.get(nombre, -100000)) < int(SEPARACION.get(nombre, SEPARACION_MS)):
		return
	_ultimo[nombre] = ahora
	var prioridad: int = PRIORIDAD.get(nombre, 0)
	var i := _elegir_voz(nombre, prioridad, ahora)
	if i < 0:
		return
	tono = clampf(tono * _variacion(nombre) * _empuje(nombre), 0.3, 3.0)
	var db := ajuste_db + _db_efectos
	if prioridad == 0:
		db -= minf(_activas_bajas * 0.6, 4.8)  # con mucho jaleo, cada golpe suena un poco más bajo
	var pico: float = PICO.get(nombre, 0.8)
	if prioridad <= 1:
		var nuevo := pico * db_to_linear(db)
		if _carga + nuevo > TECHO:
			db += maxf(linear_to_db(minf(maxf(TECHO - _carga, TECHO * 0.15) / nuevo, 1.0)), -TECHO_MAX_DB)
	var voz := _voces[i]
	voz.stream = efecto
	voz.pitch_scale = tono
	voz.volume_db = db - (_agachado if prioridad == 0 else 0.0)
	voz.play()
	_nombre_voz[i] = nombre
	_prio_voz[i] = prioridad
	_inicio_voz[i] = ahora
	_fin_voz[i] = ahora + int(float(_largo.get(nombre, 1.0)) / tono * 1000.0) + 30
	_base_db[i] = db
	_nivel_voz[i] = pico * db_to_linear(db)
	if AGACHAN.has(nombre):
		_agachado = AGACHAR_DB
		_agachado_hasta = ahora + 160


## Una voz libre si la hay; si no, la más vieja de lo menos importante. Lo importante nunca se roba.
func _elegir_voz(nombre: String, prioridad: int, ahora: int) -> int:
	var tope: int = TOPE_PRIORIDAD[prioridad]
	var libre := -1
	var iguales := 0
	var igual_vieja := -1
	var ocupadas := 0
	var robable := -1
	_activas_bajas = 0
	_carga = 0.0
	for i in VOCES:
		if _fin_voz[i] <= ahora:
			if libre < 0:
				libre = i
			continue
		# Lo que aporta esta voz ahora: su pico, que se apaga a lo largo de lo que dura.
		var dura := maxi(_fin_voz[i] - 30 - _inicio_voz[i], 1)
		_carga += _nivel_voz[i] * exp(-3.0 * float(ahora - _inicio_voz[i]) / float(dura))
		if _prio_voz[i] == 0:
			_activas_bajas += 1
		if _nombre_voz[i] == nombre:
			iguales += 1
			if igual_vieja < 0 or _inicio_voz[i] < _inicio_voz[igual_vieja]:
				igual_vieja = i
		if _prio_voz[i] <= prioridad:
			ocupadas += 1
			if robable < 0 or _prio_voz[i] < _prio_voz[robable] \
					or (_prio_voz[i] == _prio_voz[robable] and _inicio_voz[i] < _inicio_voz[robable]):
				robable = i
	if iguales >= int(TOPE_IGUALES.get(nombre, 3)):
		return igual_vieja
	if ocupadas >= tope or libre < 0:
		return robable
	return libre


func _variacion(nombre: String) -> float:
	if not VARIAR.has(nombre):
		return 1.0
	var vuelta: int = (int(_vueltas.get(nombre, randi())) + 1) % VARIACION.size()
	_vueltas[nombre] = vuelta
	return 1.0 + VARIACION[vuelta]


## Con la Fiebre alta los golpes y las bajas suenan más agudos.
func _empuje(nombre: String) -> float:
	if nombre != "golpe" and nombre != "muerte":
		return 1.0
	return 1.0 + 0.025 * Juego.nivel_fiebre() + (0.03 if _desatado else 0.0)


func _subir_cadena(nombre: String) -> float:
	var datos: Array = CADENAS[nombre]
	var pasos := minf(float(_cadena.get(nombre, 0.0)) + 1.0, float(datos[1]))
	_cadena[nombre] = pasos
	return pow(2.0, floorf(pasos - 1.0) * float(datos[0]) / 12.0)


# ------------------------------------------------------------ cada fotograma
func _process(_delta: float) -> void:
	# Tiempo de verdad: Engine.time_scale (cámara lenta, paradas) no afecta al audio.
	var ahora_us := Time.get_ticks_usec()
	var dt := clampf(float(ahora_us - _ultimo_us) / 1000000.0, 0.0, 0.1)
	_ultimo_us = ahora_us
	_leer_estado()
	for nombre in _cadena:
		_cadena[nombre] = maxf(float(_cadena[nombre]) - dt * float(CADENAS[nombre][2]), 0.0)
	_mover_agachado(dt, Time.get_ticks_msec())
	_mover_musica(dt)
	_mover_latido(dt)


## Lee el estado que publica Juego; lo que aún no exista se sustituye por algo razonable.
func _leer_estado() -> void:
	_pausado = get_tree().paused
	var combate: Variant = Juego.get("en_combate")
	_combate = combate == true if combate != null else true
	_desatado = Juego.get("desatado") == true
	_limite = Juego.has_method("al_limite") and Juego.call("al_limite") == true
	if Juego.has_method("intensidad"):
		_intensidad = clampf(float(Juego.call("intensidad")), 0.0, 1.0)
	else:
		_intensidad = clampf(Juego.fiebre / 3.0 * 0.8 + (0.2 if _limite else 0.0) + (1.0 if _desatado else 0.0), 0.0, 1.0)


func _mover_agachado(dt: float, ahora: int) -> void:
	if ahora > _agachado_hasta:
		_agachado = maxf(_agachado - dt * 22.0, 0.0)
	if absf(_agachado - _agachado_puesto) < 0.15 and (_agachado > 0.0 or _agachado_puesto == 0.0):
		return
	_agachado_puesto = _agachado
	for i in VOCES:
		if _prio_voz[i] == 0 and _fin_voz[i] > ahora:
			_voces[i].volume_db = _base_db[i] - _agachado


# ------------------------------------------------------------ música
func _poner_musica(nombre: String) -> void:
	if nombre == _musica_actual or (nombre != "" and not _musicas.has(nombre)):
		return
	_musica_actual = nombre
	_capa.stop()
	_ganancia_capa = 0.0
	_pos_musica = 0.0
	if not TEMPO.has(nombre):
		_tono = 1.0
		_nivel = 0.0
	if nombre == "":
		_reproductor_musica.stop()
		_largo_musica = 0.0
		return
	_reproductor_musica.stream = _musicas[nombre]
	_largo_musica = _reproductor_musica.stream.get_length()
	_reproductor_musica.pitch_scale = _tono
	_capa.pitch_scale = _tono
	_aplicar_musica(true)
	# Las dos pistas arrancan en la misma mezcla: así la capa va clavada a la música.
	AudioServer.lock()
	_reproductor_musica.play()
	if _capas.has(nombre):
		_capa.stream = _capas[nombre]
		_capa.play()
	AudioServer.unlock()


func _mover_musica(dt: float) -> void:
	var dinamica := TEMPO.has(_musica_actual)
	if not _pausado:
		# Por escalones y con margen: sube o baja solo cuando la intensidad cambia de verdad.
		var objetivo := _intensidad if _combate else 0.0
		if absf(objetivo - _nivel) > 0.15 or (objetivo < 0.05 and _nivel > 0.0):
			_nivel = snappedf(objetivo, 0.25)
		# Cámara lenta larga (no las paradas de un instante): la música se arrastra con ella.
		if Engine.time_scale < 0.65:
			_lento += dt
		else:
			if _lento > 0.16:
				_tras_lento = 0.4
			_lento = 0.0
		_tras_lento = maxf(_tras_lento - dt, 0.0)
		if dinamica:
			var tono_obj := 1.0 + SUBIDA_TONO * _nivel
			if _desatado and _combate:
				tono_obj += SUBIDA_DESATADO
			var rapidez := 1.0 if tono_obj > _tono else 0.7
			if _desatado and tono_obj > _tono:
				rapidez = 3.0
			if _lento > 0.16:
				tono_obj *= TONO_LENTO
				rapidez = 6.0
			elif _tras_lento > 0.0:
				rapidez = 6.0
			_tono = lerpf(_tono, tono_obj, 1.0 - exp(-dt * rapidez))
	elif dinamica:
		# En pausa (menú de pausa, tienda, elegir carta) la música se relaja poco a poco.
		_tono = lerpf(_tono, 1.0, 1.0 - exp(-dt * 0.7))
	var ajuste := 0.0
	var ganancia := 0.0
	if dinamica:
		if _pausado:
			ajuste = EN_PAUSA_DB
		elif not _combate:
			ajuste = FUERA_DE_COMBATE_DB
		elif _limite:
			ajuste = AL_LIMITE_DB
		if _combate and not _pausado:
			ganancia = smoothstep(0.25, 0.75, _nivel)
			if _limite:
				ganancia = maxf(ganancia, 0.5)
			if _desatado:
				ganancia = 1.0
	_ajuste_musica = move_toward(_ajuste_musica, ajuste, dt * 6.0)
	_ganancia_capa = move_toward(_ganancia_capa, ganancia, dt * (1.6 if ganancia > _ganancia_capa else 0.6))
	if absf(_reproductor_musica.pitch_scale - _tono) > 0.0004:
		_reproductor_musica.pitch_scale = _tono
		_capa.pitch_scale = _tono
	_aplicar_musica(false)
	_llevar_tempo(dt)


func _aplicar_musica(siempre: bool) -> void:
	if _reproductor_musica == null:
		return
	var base := _db_musica + _ajuste_musica - _agachado * 0.4
	var db_musica := maxf(base, -80.0)
	var db_capa := -80.0
	if _ganancia_capa > 0.004:
		db_capa = maxf(base + CAPA_DB + linear_to_db(_ganancia_capa), -80.0)
	if siempre or absf(_reproductor_musica.volume_db - db_musica) > 0.05:
		_reproductor_musica.volume_db = db_musica
	if siempre or absf(_capa.volume_db - db_capa) > 0.05:
		_capa.volume_db = db_capa


## Reloj propio de la pista (vale también en la web); se corrige con lo que diga el reproductor.
func _llevar_tempo(dt: float) -> void:
	if _musica_actual == "" or _largo_musica <= 0.0:
		return
	_pos_musica = fposmod(_pos_musica + dt * _reproductor_musica.pitch_scale, _largo_musica)
	var real := _reproductor_musica.get_playback_position()
	if real > 0.0:
		var error := wrapf(real - _pos_musica, -_largo_musica * 0.5, _largo_musica * 0.5)
		if absf(error) < 0.3:
			_pos_musica = fposmod(_pos_musica + error * 0.15, _largo_musica)
	# Si la capa se ha ido de sitio, se recoloca mientras no se oye.
	_revisar -= dt
	if _revisar <= 0.0 and _capa.playing and _ganancia_capa < 0.004:
		_revisar = 2.0
		var capa := _capa.get_playback_position()
		if real > 0.5 and capa > 0.0 and absf(real - capa) > 0.04 and absf(real - capa) < _largo_musica - 0.5:
			_capa.seek(real)


# ------------------------------------------------------------ latido
## Al límite y en combate: un latido clavado al pulso de la música, cada dos pulsos y,
## cuando aprieta, en cada pulso. Se corta al salir de ese estado, al pausar o al acabar.
func _mover_latido(dt: float) -> void:
	var pulso := 60.0 / float(TEMPO.get(_musica_actual, 120.0))
	var indice := int(floorf(_pos_musica / pulso))
	var activo := _limite and _combate and not _pausado and TEMPO.has(_musica_actual) and _latido.stream != null
	_latiendo = activo
	if activo:
		var cada := 1 if (_intensidad >= 0.6 or _desatado) else 2
		if indice != _ultimo_pulso and indice % cada == 0:
			_latido.volume_db = LATIDO_DB + 3.0 * _intensidad + _db_efectos
			_latido.pitch_scale = 1.0 + 0.04 * _intensidad
			_latido.play()
			_latido_ms = Time.get_ticks_msec()
	elif _latido.playing:
		# Fuera del estado: el que estaba sonando se apaga en un momento, sin chasquido.
		_latido.volume_db -= dt * 300.0
		if _latido.volume_db < -50.0:
			_latido.stop()
	_ultimo_pulso = indice
