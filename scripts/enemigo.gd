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
}
const NACIMIENTO_SEG := 0.55
const TOPE_INVOCADOS := 60

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


func configurar(nombre: String, multiplicador_vida: float) -> void:
	var datos: Dictionary = TIPOS[nombre]
	tipo = nombre
	vida = float(datos.vida) * multiplicador_vida
	vida_max = vida
	vel = datos.vel
	radio = datos.radio
	oro_prob = datos.oro
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
	monedas_al_morir += 3
	oro_prob = 1.0


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
	if muerto:
		return
	var factor := 0.45 if _frio_t > 0.0 else 1.0
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
			# Cuanto más cerca te ve, más aprieta el paso.
			return direccion * vel * (1.6 if dist < 90.0 else 1.0)
	return direccion * vel


func _camara(direccion: Vector2, delta: float, horda: Horda) -> void:
	_accion -= delta
	if _accion <= 0.0:
		_accion = randf_range(1.8, 2.5)
		horda.ataques.bala_enemiga(position, direccion * 120.0, "moneda")


## Roba unas monedas y huye: si lo eliminas, las recuperas.
func _ratero(direccion: Vector2, dist: float) -> Vector2:
	if _modo == 0 and dist < 15.0:
		var botin := mini(5, Juego.oro)
		Juego.gastar_oro(botin)
		monedas_al_morir += botin
		_modo = 1
	return (-direccion if _modo == 1 else direccion) * vel


func _explotar(horda: Horda) -> void:
	for i in 8:
		horda.ataques.bala_enemiga(position, Vector2.RIGHT.rotated(TAU * i / 8.0) * 110.0, "moneda")
	Sonido.tocar("explosion", 1.3, -6.0)
	vida = 0.0
	muerto = true


func _reina(delta: float, horda: Horda) -> void:
	_accion -= delta
	if _accion > 0.0:
		return
	_accion = 2.2
	for otro in horda.en_radio(position, 70.0):
		if otro != self and otro.vida < otro.vida_max and not (otro is Jefe):
			otro.vida = minf(otro.vida + otro.vida_max * 0.25, otro.vida_max)


func _sota(direccion: Vector2, dist: float, delta: float, horda: Horda) -> Vector2:
	_accion -= delta
	frame = 3 if _accion < 0.35 else int(_t * 6.0) % 3
	if _accion <= 0.0:
		_accion = randf_range(2.0, 3.0)
		horda.ataques.bala_enemiga(position, direccion * 95.0, "naipe_bala")
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
		_accion = randf_range(1.2, 2.2)
	return _dir_embestida * 270.0


func _joker(direccion: Vector2, delta: float, horda: Horda) -> void:
	_accion -= delta
	if _accion > 0.0:
		return
	_accion = randf_range(2.2, 3.0)
	var zona := Sala.INTERIOR.grow(-16.0)
	var objetivo: Vector2 = horda.jugador.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(85.0, 130.0)
	position = objetivo.clamp(zona.position, zona.end)
	var hacia: Vector2 = (horda.jugador.global_position - position).normalized()
	if hacia == Vector2.ZERO:
		hacia = direccion
	for i in 5:
		horda.ataques.bala_enemiga(position, hacia.rotated((i - 2) * 0.22) * 100.0, "naipe_bala")


func _cubilete(delta: float, horda: Horda) -> void:
	_accion -= delta
	if _accion > 0.0:
		return
	_accion = randf_range(3.5, 4.5)
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
	if _frio_t > 0.0:
		return Color(0.6, 0.85, 1.0)
	if _quema_t > 0.0:
		return Color(1.0, 0.7, 0.55)
	return Color.WHITE


func aplicar_golpe(dano: float, retroceso: Vector2) -> void:
	vida -= dano
	if tipo != "portero":
		empuje += retroceso
	_flash = 0.07
	modulate = Color(4, 4, 4)


func aplicar_quemadura(dps: float) -> void:
	_quema_dps = max(_quema_dps, dps)
	_quema_t = 3.0


func aplicar_frio() -> void:
	_frio_t = 1.6
