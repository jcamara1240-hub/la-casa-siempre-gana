class_name Enemigo
extends Sprite2D
## Un enemigo de la horda. Sin físicas: la horda los mueve a todos a mano,
## porque en el navegador cientos de cuerpos físicos irían a tirones.

const TIPOS := {
	"ficha": {"vida": 6.0, "vel": 44.0, "radio": 6.0, "oro": 0.35},
	"dado": {"vida": 4.0, "vel": 86.0, "radio": 5.0, "oro": 0.45},
	"sota": {"vida": 14.0, "vel": 30.0, "radio": 6.0, "oro": 0.8},
	"naipe": {"vida": 7.0, "vel": 34.0, "radio": 5.0, "oro": 0.5},
	"ficha_grande": {"vida": 30.0, "vel": 28.0, "radio": 11.0, "oro": 1.0},
	"joker": {"vida": 18.0, "vel": 0.0, "radio": 6.0, "oro": 1.0},
	"cubilete": {"vida": 26.0, "vel": 14.0, "radio": 7.0, "oro": 1.0},
	"portero": {"vida": 55.0, "vel": 38.0, "radio": 9.0, "oro": 1.0},
	"ficha_oro": {"vida": 22.0, "vel": 74.0, "radio": 6.0, "oro": 0.0},
	"camara": {"vida": 20.0, "vel": 0.0, "radio": 7.0, "oro": 0.8},
	"ratero": {"vida": 9.0, "vel": 100.0, "radio": 5.0, "oro": 0.5},
	"dado_bomba": {"vida": 10.0, "vel": 66.0, "radio": 6.0, "oro": 0.5},
	"reina": {"vida": 24.0, "vel": 26.0, "radio": 6.0, "oro": 1.0},
	"crupier": {"vida": 16.0, "vel": 42.0, "radio": 6.0, "oro": 0.8},
	"maton": {"vida": 36.0, "vel": 30.0, "radio": 8.0, "oro": 1.0},
	"botones": {"vida": 12.0, "vel": 50.0, "radio": 6.0, "oro": 0.6},
}
# Ritmo (ronda 2): ya avisa main con una marca en el suelo antes de crearlos, así que
# aparecen casi al momento (antes 0,4 s), corren un 25 % más y sus balas van más rápido
# (antes x1,1). En extremo, donde un golpe mata, las balas no suben tanto.
const NACIMIENTO_SEG := 0.25
const VEL_RITMO := 1.45  # hardcore: antes 1,25
const VEL_RITMO_EXTREMO := 1.25  # donde un golpe mata, tocarte no puede ser tan fácil
const VEL_BALAS := 1.6  # hardcore: antes 1,3
const VEL_BALAS_EXTREMO := 1.3  # antes 1,15
const CADENCIA := 0.6  # las esperas entre ataques: hardcore, antes 0,84
const ORO_RITMO := 0.5  # vienen más: cada uno suelta algo menos, para que el oro no se dispare
const TOPE_INVOCADOS := 75
# Lo que tarda cada uno de los nuevos en avisar (fotograma 3) antes de atacar.
const AVISO_CRUPIER := 0.36
const AVISO_MATON := 0.48
const AVISO_BOTONES := 0.32
# Al recibir un golpe: cuánto se nota el empujón y cuánto se aplasta el dibujo.
const RETROCESO_EXTRA := 1.35
# Mecánicas hardcore de los enemigos.
const DESESPERO := 1.35  # los últimos de la sala corren y atacan más deprisa
const ANIMO := 1.25  # lo que un élite acelera a los que tiene cerca
const ANIMO_RADIO := 80.0
const PRISA_MAX := 1.5
const CORTE_SEG := 0.7  # con cuánta antelación te cortan el paso las fichas
const PLACAJE_AVISO := 0.5
const PLACAJE_SEG := 0.45
const PLACAJE_VEL := 300.0
const VENGANZA_ELITE := 10  # balas que suelta un élite al morir
const VENGANZA_BOMBA := 6  # y un dado bomba, si lo matas antes de que llegue
const APLASTE := 0.32

var tipo := ""
var vida := 1.0
var vida_max := 1.0
var vel := 40.0
var radio := 6.0
var oro_prob := 0.3
var muerto := false
var empuje := Vector2.ZERO
var monedas_al_morir := 0
var elite := false
var hace_contacto := true
var desesperado := false

var _t := 0.0
var _nacer := NACIMIENTO_SEG
var _flash := 0.0
var _quema_t := 0.0
var _quema_dps := 0.0
var _quema_tick := 0.0
var _frio_t := 0.0
var _accion := 1.5
var _modo := 0
var _dir_embestida := Vector2.ZERO
var _fase := 0.0
var _rafaga := 0
var _aturdido_t := 0.0
var _aplaste := 0.0  # 1 recién golpeado, 0 en reposo
var _aplaste_dir := Vector2.ZERO
var _aplaste_fuerza := 1.0  # los jefes se aplastan menos
var _escala_base := Vector2.ONE
var _animo_t := 0.0
var _aura_t := 0.0
var _reventado := false


func configurar(nombre: String, multiplicador_vida: float) -> void:
	var datos: Dictionary = TIPOS[nombre]
	tipo = nombre
	vida = float(datos.vida) * multiplicador_vida
	vida_max = vida
	vel = float(datos.vel) * (VEL_RITMO_EXTREMO if Juego.extremo else VEL_RITMO)
	radio = datos.radio
	oro_prob = float(datos.oro) * ORO_RITMO
	texture = load("res://assets/personajes/%s.png" % nombre)
	hframes = 4
	_fase = randf() * TAU
	_accion = randf_range(1.0, 2.6)
	modulate.a = 0.0


## Un enemigo de élite: dorado, grande, duro y con premio.
func hacer_elite() -> void:
	elite = true
	vida *= 3.0
	vida_max = vida
	scale = Vector2.ONE * 1.4
	radio *= 1.3
	self_modulate = Color(1.0, 0.82, 0.4)
	monedas_al_morir += 2
	oro_prob = 1.0


## Lo que multiplica la velocidad de las balas enemigas.
static func ritmo_balas() -> float:
	# Hardcore: cada piso las balas van un 5 % más rápidas.
	return (VEL_BALAS_EXTREMO if Juego.extremo else VEL_BALAS) * (1.0 + 0.05 * (Juego.piso - 1)) * Juego.balas_sala


func activo() -> bool:
	return _nacer <= 0.0 and not muerto


func nacer_ya() -> void:
	_nacer = 0.15


func actualizar(delta: float, horda: Horda) -> void:
	_t += delta
	if _nacer > 0.0:
		_nacer -= delta
		modulate.a = 1.0 - clampf(_nacer / NACIMIENTO_SEG, 0.0, 1.0) * 0.8
		return
	_tick_estados(delta, horda)
	_tick_aplaste(delta)
	if muerto:
		return
	if _aturdido_t > 0.0:
		_aturdido(delta)
		return
	_animo_t = maxf(_animo_t - delta, 0.0)
	if elite:
		_animar_vecinos(delta, horda)
	var factor := (0.45 if _frio_t > 0.0 else 1.0) * _prisa()
	var hacia := horda.jugador.global_position - position
	var dist := hacia.length()
	var direccion: Vector2 = hacia / maxf(dist, 0.001)
	var movimiento := _decidir(direccion, dist, delta * factor, horda)
	position += (movimiento * factor + empuje) * delta
	empuje = empuje.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	if tipo != "ficha" and tipo != "ficha_grande" and tipo != "ficha_oro" and tipo != "camara":
		flip_h = hacia.x < 0.0


## Cada tipo decide aquí cómo se mueve. Devuelve su velocidad.
func _decidir(direccion: Vector2, dist: float, delta: float, horda: Horda) -> Vector2:
	frame = int(_t * 9.0) % 4
	match tipo:
		"ficha":
			return _cortar_paso(direccion, dist, horda)
		"dado":
			# Vuela en zigzag: más difícil de esquivar que de matar.
			return direccion.rotated(sin(_t * 5.0 + _fase) * 0.9) * vel
		"sota":
			return _sota(direccion, dist, delta, horda)
		"naipe":
			return _naipe(direccion, delta)
		"joker":
			_joker(direccion, delta, horda)
			return Vector2.ZERO
		"cubilete":
			_cubilete(delta, horda)
			return direccion * vel
		"ficha_oro":
			# Sale corriendo y suelta un buen premio si la pillas.
			monedas_al_morir = 8
			return -direccion.rotated(sin(_t * 2.0 + _fase) * 0.8) * vel
		"camara":
			_camara(direccion, delta, horda)
			return Vector2.ZERO
		"ratero":
			return _ratero(direccion, dist)
		"dado_bomba":
			if dist < 24.0:
				_explotar(horda)
			return direccion * vel
		"reina":
			_reina(delta, horda)
			return direccion * vel
		"portero":
			return _portero(direccion, dist, delta)
		"crupier":
			return _crupier(direccion, dist, delta, horda)
		"maton":
			return _maton(direccion, delta, horda)
		"botones":
			return _botones(direccion, dist, delta, horda)
	return direccion * vel


## Para pintar el aviso: hacia dónde va a salir el ataque que prepara y hasta dónde llega
## (ZERO si no prepara ninguno). Solo los que atacan en línea recta.
func aviso_linea() -> Vector2:
	if _modo != 1:
		return Vector2.ZERO
	match tipo:
		"naipe": return _dir_embestida * 112.0
		"portero": return _dir_embestida * PLACAJE_VEL * PLACAJE_SEG
		"maton": return _dir_embestida * 170.0
	return Vector2.ZERO


## Cuánto más deprisa va ahora mismo: animado por un élite o desesperado por ser de los últimos.
func _prisa() -> float:
	return minf((ANIMO if _animo_t > 0.0 else 1.0) * (DESESPERO if desesperado else 1.0), PRISA_MAX)


## Los últimos de la sala no se dejan cazar tranquilamente.
func desesperar() -> void:
	if desesperado or tipo == "ficha_oro":
		return
	desesperado = true
	if _flash <= 0.0:
		modulate = _color_base()


## Un élite manda: los que tiene cerca aprietan el paso mientras siga vivo.
func _animar_vecinos(delta: float, horda: Horda) -> void:
	_aura_t -= delta
	if _aura_t > 0.0:
		return
	_aura_t = 0.4
	for otro in horda.en_radio(position, ANIMO_RADIO):
		if otro != self and not (otro is Jefe):
			otro._animo_t = 0.7


## Lo que pasa justo al morir. Un élite se venga con un anillo de balas, y un dado bomba
## revienta aunque no haya llegado hasta ti. El último de la sala no: ya has ganado.
func al_morir(horda: Horda) -> void:
	if horda.enemigos.is_empty() or tipo == "jefe":
		return
	var balas := VENGANZA_ELITE if elite else VENGANZA_BOMBA if tipo == "dado_bomba" and not _reventado else 0
	var giro := randf() * TAU
	for i in balas:
		horda.ataques.bala_enemiga(position, Vector2.RIGHT.rotated(giro + TAU * i / balas) * 95.0 * ritmo_balas(), "moneda")
	if balas > 0:
		Sonido.tocar("explosion", 1.5, -8.0)


## Adónde apuntar para dar a alguien que se mueve.
func _adelantar(horda: Horda, segundos: float) -> Vector2:
	var destino: Vector2 = horda.jugador.global_position
	if horda.jugador is CharacterBody2D:
		destino += (horda.jugador as CharacterBody2D).velocity * segundos
	return destino


## La mitad de las fichas no te persigue: va a donde vas a estar, y te cierra la salida.
func _cortar_paso(direccion: Vector2, dist: float, horda: Horda) -> Vector2:
	if sin(_fase) < 0.0 or dist < 40.0:
		return direccion * vel
	var hacia := _adelantar(horda, minf(dist / maxf(vel, 1.0), CORTE_SEG)) - position
	return (hacia.normalized() if hacia.length() > 1.0 else direccion) * vel


## El Portero te placa: se para, tiembla un momento y sale lanzado en línea recta.
func _portero(direccion: Vector2, dist: float, delta: float) -> Vector2:
	_accion -= delta
	match _modo:
		1:  # aviso: tiembla, y deja de seguirte con la mirada justo antes de salir
			rotation = sin(_t * 40.0) * 0.14
			if _accion > 0.12:
				_dir_embestida = direccion
			if _accion <= 0.0:
				_modo = 2
				_accion = PLACAJE_SEG
				rotation = 0.0
			return Vector2.ZERO
		2:
			if _accion <= 0.0:
				_modo = 0
				_accion = randf_range(2.4, 3.4) * CADENCIA
			return _dir_embestida * PLACAJE_VEL
	if _accion <= 0.0 and dist > 50.0 and dist < 180.0:
		_modo = 1
		_accion = PLACAJE_AVISO
		Sonido.tocar("aviso", 0.8, -4.0)
	# Cuanto más cerca te ve, más aprieta el paso.
	return direccion * vel * (1.6 if dist < 90.0 else 1.0)


## A un lado o al otro, y de vez en cuando cambia: así no se queda quieto a tiro.
func _de_lado(direccion: Vector2) -> Vector2:
	return direccion.orthogonal() * (1.0 if sin(_t * 0.8 + _fase) >= 0.0 else -1.0)


## El Crupier reparte desde lejos: guarda la distancia y suelta un abanico de tres naipes.
func _crupier(direccion: Vector2, dist: float, delta: float, horda: Horda) -> Vector2:
	_accion -= delta
	if _modo == 1:
		frame = 3  # aviso
		if _accion <= 0.0:
			_modo = 0
			_accion = randf_range(2.0, 2.8) * CADENCIA
			for i in 3:
				horda.ataques.bala_enemiga(position, direccion.rotated((i - 1) * 0.28) * 105.0 * ritmo_balas(), "naipe_bala")
		return Vector2.ZERO
	frame = int(_t * 7.0) % 3
	if _accion <= 0.0:
		_modo = 1
		_accion = AVISO_CRUPIER
	if dist < 105.0:
		return -direccion * vel
	if dist > 160.0:
		return direccion * vel
	return _de_lado(direccion) * vel * 0.8


## El Matón se planta, avisa y suelta una ráfaga de cinco balas en fila.
func _maton(direccion: Vector2, delta: float, horda: Horda) -> Vector2:
	_accion -= delta
	match _modo:
		1:  # aviso: te sigue con la mirada y deja de hacerlo justo antes de disparar
			frame = 3
			if _accion > 0.15:
				_dir_embestida = direccion
			if _accion <= 0.0:
				_modo = 2
				_rafaga = 5
				_accion = 0.0
			return Vector2.ZERO
		2:  # ráfaga, siempre en la misma línea
			frame = 3
			if _accion <= 0.0:
				_accion = 0.08
				horda.ataques.bala_enemiga(position, _dir_embestida * 150.0 * ritmo_balas(), "moneda")
				_rafaga -= 1
				if _rafaga <= 0:
					_modo = 0
					_accion = randf_range(2.8, 3.6) * CADENCIA
			return Vector2.ZERO
	frame = int(_t * 6.0) % 3
	if _accion <= 0.0:
		_modo = 1
		_accion = AVISO_MATON
	return direccion * vel


## El Botones lanza granadas: un círculo en el suelo donde vas a estar, que revienta al rato.
func _botones(direccion: Vector2, dist: float, delta: float, horda: Horda) -> Vector2:
	_accion -= delta
	if _modo == 1:
		frame = 3
		if _accion <= 0.0:
			_modo = 0
			_accion = randf_range(3.2, 4.2) * CADENCIA
			var destino: Vector2 = horda.jugador.position
			if horda.jugador is CharacterBody2D:
				destino += (horda.jugador as CharacterBody2D).velocity * 0.35
			var zona := Sala.INTERIOR.grow(-20.0)
			horda.ataques.zona_peligro(destino.clamp(zona.position, zona.end), 24.0, 1.0)
		return Vector2.ZERO
	frame = int(_t * 8.0) % 3
	if _accion <= 0.0:
		_modo = 1
		_accion = AVISO_BOTONES
	if dist < 80.0:
		return -direccion * vel
	if dist > 140.0:
		return direccion * vel
	return _de_lado(direccion) * vel * 0.6


func _camara(direccion: Vector2, delta: float, horda: Horda) -> void:
	_accion -= delta
	if _accion <= 0.0:
		_accion = randf_range(1.5, 2.1) * CADENCIA
		# Hardcore: la cámara ya no dispara a donde estás, sino a donde vas.
		var rapidez := 120.0 * ritmo_balas()
		var hacia := _adelantar(horda, position.distance_to(horda.jugador.global_position) / rapidez * 0.8) - position
		horda.ataques.bala_enemiga(position, (hacia.normalized() if hacia.length() > 1.0 else direccion) * rapidez, "moneda")


## Roba unas monedas y huye: si lo eliminas, las recuperas.
func _ratero(direccion: Vector2, dist: float) -> Vector2:
	if _modo == 0 and dist < 15.0:
		var botin := mini(5, Juego.oro)
		Juego.gastar_oro(botin)
		monedas_al_morir += botin
		_modo = 1
	return (-direccion if _modo == 1 else direccion) * vel


func _explotar(horda: Horda) -> void:
	for i in 12:  # antes 10
		horda.ataques.bala_enemiga(position, Vector2.RIGHT.rotated(TAU * i / 12.0) * 110.0 * ritmo_balas(), "moneda")
	Sonido.tocar("explosion", 1.3, -6.0)
	_reventado = true
	vida = 0.0
	muerto = true


func _reina(delta: float, horda: Horda) -> void:
	_accion -= delta
	if _accion > 0.0:
		return
	_accion = 2.2 * CADENCIA
	for otro in horda.en_radio(position, 70.0):
		if otro != self and otro.vida < otro.vida_max and not (otro is Jefe):
			otro.vida = minf(otro.vida + otro.vida_max * 0.25, otro.vida_max)


func _sota(direccion: Vector2, dist: float, delta: float, horda: Horda) -> Vector2:
	_accion -= delta
	frame = 3 if _accion < 0.35 else int(_t * 6.0) % 3
	if _accion <= 0.0:
		_accion = randf_range(1.7, 2.6) * CADENCIA
		horda.ataques.bala_enemiga(position, direccion * 95.0 * ritmo_balas(), "naipe_bala")
	if dist < 75.0:
		return -direccion * vel
	if dist < 130.0:
		return direccion.orthogonal() * sin(_fase) * vel
	return direccion * vel


func _naipe(direccion: Vector2, delta: float) -> Vector2:
	_accion -= delta
	match _modo:
		0:  # se acerca despacio
			if _accion <= 0.0:
				_modo = 1
				_accion = 0.4
			return direccion * vel
		1:  # avisa, parado y en amarillo
			frame = 3
			_dir_embestida = direccion
			if _accion <= 0.0:
				_modo = 2
				_accion = 0.34
			return Vector2.ZERO
	if _accion <= 0.0:
		_modo = 0
		_accion = randf_range(1.2, 2.2) * CADENCIA
	return _dir_embestida * 330.0


func _joker(direccion: Vector2, delta: float, horda: Horda) -> void:
	_accion -= delta
	if _accion > 0.0:
		return
	_accion = randf_range(2.2, 3.0) * CADENCIA
	var zona := Sala.INTERIOR.grow(-16.0)
	var objetivo: Vector2 = horda.jugador.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(85.0, 130.0)
	position = objetivo.clamp(zona.position, zona.end)
	var hacia: Vector2 = (horda.jugador.global_position - position).normalized()
	if hacia == Vector2.ZERO:
		hacia = direccion
	for i in 5:
		horda.ataques.bala_enemiga(position, hacia.rotated((i - 2) * 0.22) * 100.0 * ritmo_balas(), "naipe_bala")


func _cubilete(delta: float, horda: Horda) -> void:
	_accion -= delta
	if _accion > 0.0:
		return
	_accion = randf_range(3.5, 4.5) * CADENCIA
	if horda.enemigos.size() < TOPE_INVOCADOS:
		for i in 2:
			horda.crear("dado", position + Vector2.RIGHT.rotated(randf() * TAU) * 14.0).nacer_ya()


func _tick_estados(delta: float, horda: Horda) -> void:
	if _flash > 0.0:
		_flash -= delta
		modulate = Color(4, 4, 4) if _flash > 0.0 else _color_base()
	if _frio_t > 0.0:
		_frio_t -= delta
		if _frio_t <= 0.0 and _flash <= 0.0:
			modulate = _color_base()
	if _quema_t > 0.0:
		_quema_t -= delta
		_quema_tick -= delta
		if _quema_tick <= 0.0:
			_quema_tick = 0.5
			horda.danar(self, _quema_dps * 0.5, Vector2.ZERO, Color8(240, 129, 60))


func _color_base() -> Color:
	if _aturdido_t > 0.0:
		return Color(1.0, 0.95, 0.6)
	if desesperado:
		return Color(1.0, 0.72, 0.72)
	if _frio_t > 0.0:
		return Color(0.6, 0.85, 1.0)
	if _quema_t > 0.0:
		return Color(1.0, 0.7, 0.55)
	return Color.WHITE


func aplicar_golpe(dano: float, retroceso: Vector2) -> void:
	vida -= dano
	if tipo != "portero":
		empuje += retroceso * RETROCESO_EXTRA
	_flash = 0.07
	modulate = Color(4, 4, 4)
	# Se aplasta en la dirección del golpe y recupera la forma enseguida.
	if _aplaste <= 0.0:
		_escala_base = scale
	_aplaste = 1.0
	_aplaste_dir = retroceso


## Ni se mueve ni ataca durante seg segundos (solo le arrastra el empujón que lleve).
func aturdir(seg: float) -> void:
	if seg <= 0.0 or muerto:
		return
	_aturdido_t = maxf(_aturdido_t, seg)
	if _flash <= 0.0:
		modulate = _color_base()


func esta_aturdido() -> bool:
	return _aturdido_t > 0.0


func _aturdido(delta: float) -> void:
	_aturdido_t -= delta
	position += empuje * delta
	empuje = empuje.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	# Tiembla de un lado a otro mientras está grogui.
	rotation = sin(_t * 30.0) * 0.18
	if _aturdido_t <= 0.0:
		rotation = 0.0
		if _flash <= 0.0:
			modulate = _color_base()


func _tick_aplaste(delta: float) -> void:
	if _aplaste <= 0.0:
		return
	_aplaste = maxf(_aplaste - delta * 8.0, 0.0)
	var s := _aplaste * APLASTE * _aplaste_fuerza
	var forma := Vector2(1.0 + s, 1.0 - s * 0.8)
	if absf(_aplaste_dir.y) > absf(_aplaste_dir.x):
		forma = Vector2(forma.y, forma.x)
	scale = _escala_base * forma


func aplicar_quemadura(dps: float) -> void:
	_quema_dps = max(_quema_dps, dps)
	_quema_t = 3.0


func aplicar_frio() -> void:
	_frio_t = 1.6
