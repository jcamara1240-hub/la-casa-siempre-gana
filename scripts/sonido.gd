class_name Sonido
extends Node
## Efectos y música. Se usa con Sonido.tocar("moneda") desde cualquier sitio.

const EFECTOS := [
	"disparo", "carta", "rayo", "explosion", "golpe", "muerte", "dano", "moneda", "puerta_cierra", "puerta_abre",
	"comprar", "carta_coger", "objeto", "transformacion", "tick", "mult", "clic", "mover", "jefe_aparece",
	"jefe_muere", "bajar", "victoria", "derrota", "ganar", "perder", "mezclar",
]
const MUSICAS := ["menu", "piso", "jefe", "victoria"]
const VOCES := 14
const SEPARACION_MS := 45  # si suenan veinte golpes a la vez, solo se oyen unos pocos

static var _yo: Sonido

var _efectos := {}
var _musicas := {}
var _voces: Array[AudioStreamPlayer] = []
var _siguiente_voz := 0
var _ultimo := {}
var _reproductor_musica: AudioStreamPlayer
var _musica_actual := ""


static func tocar(nombre: String, tono := 1.0, ajuste_db := 0.0) -> void:
	if _yo != null:
		_yo._tocar(nombre, tono, ajuste_db)


static func musica(nombre: String) -> void:
	if _yo != null:
		_yo._poner_musica(nombre)


static func aplicar_volumenes(musica_lineal: float, efectos_lineal: float) -> void:
	_poner_bus("Musica", musica_lineal)
	_poner_bus("Efectos", efectos_lineal)


static func _poner_bus(nombre: String, lineal: float) -> void:
	var i := AudioServer.get_bus_index(nombre)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, nombre)
		AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_mute(i, lineal <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lineal, 0.001)))


func _ready() -> void:
	_yo = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sonido.aplicar_volumenes(Juego.volumen_musica, Juego.volumen_efectos)
	for nombre in EFECTOS:
		_efectos[nombre] = load("res://assets/sonido/%s.wav" % nombre)
	for nombre in MUSICAS:
		var pista: AudioStreamWAV = load("res://assets/sonido/musica_%s.wav" % nombre)
		pista.loop_mode = AudioStreamWAV.LOOP_FORWARD
		pista.loop_begin = 0
		pista.loop_end = int(pista.get_length() * pista.mix_rate)
		_musicas[nombre] = pista
	for _i in VOCES:
		var voz := AudioStreamPlayer.new()
		voz.bus = "Efectos"
		add_child(voz)
		_voces.append(voz)
	_reproductor_musica = AudioStreamPlayer.new()
	_reproductor_musica.bus = "Musica"
	add_child(_reproductor_musica)


func _tocar(nombre: String, tono: float, ajuste_db: float) -> void:
	var ahora := Time.get_ticks_msec()
	if ahora - int(_ultimo.get(nombre, -1000)) < SEPARACION_MS:
		return
	_ultimo[nombre] = ahora
	var voz := _voces[_siguiente_voz]
	_siguiente_voz = (_siguiente_voz + 1) % VOCES
	voz.stream = _efectos[nombre]
	voz.pitch_scale = tono
	voz.volume_db = ajuste_db
	voz.play()


func _poner_musica(nombre: String) -> void:
	if nombre == _musica_actual:
		return
	_musica_actual = nombre
	if nombre == "":
		_reproductor_musica.stop()
		return
	_reproductor_musica.stream = _musicas[nombre]
	_reproductor_musica.play()
