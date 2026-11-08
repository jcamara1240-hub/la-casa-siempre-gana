extends CharacterBody2D
## El protagonista. Solo se mueve: los ataques los lanzan las cartas.

signal golpeado

const INVULNERABLE_SEG := 1.1

@export var velocidad := 130.0
@export var aceleracion := 1200.0

var invulnerable := false  # lo usa la prueba automática
var seguro_listo := false

var _invulnerable_t := 0.0
var _anim_t := 0.0
var _fila := 0
var _mirando_izquierda := false

@onready var _sprite: Sprite2D = $Sprite


func _physics_process(delta: float) -> void:
	var direccion := _leer_direccion()
	velocity = velocity.move_toward(direccion * velocidad * (1.0 + Juego.stat("velocidad")), aceleracion * delta)
	move_and_slide()
	_animar(direccion, delta)
	if _invulnerable_t > 0.0:
		_invulnerable_t -= delta
		_sprite.visible = fmod(_invulnerable_t, 0.14) > 0.05 or _invulnerable_t <= 0.0


func recibir_golpe(cantidad := 1) -> void:
	if _invulnerable_t > 0.0 or invulnerable:
		return
	_invulnerable_t = INVULNERABLE_SEG + Juego.stat("invulnerable")
	if seguro_listo:
		seguro_listo = false
		return
	var coste := int(Juego.stat("golpe_monedas"))
	if coste > 0 and Juego.gastar_oro(coste):
		Sonido.tocar("perder")
		return
	Juego.herir(cantidad)
	Sonido.tocar("dano")
	golpeado.emit()


func aplicar_personaje() -> void:
	_sprite.texture = PersonajesDB.textura(Juego.personaje)
	_sprite.modulate = Color.WHITE


func teñir(color: Color) -> void:
	_sprite.modulate = color


func _leer_direccion() -> Vector2:
	var x := _eje(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT)
	var y := _eje(KEY_W, KEY_UP, KEY_S, KEY_DOWN)
	# normalized() evita que en diagonal se corra más que en línea recta.
	var direccion := Vector2(x, y).normalized()
	if Juego.stat("tambaleo") > 0.0 and direccion != Vector2.ZERO:
		direccion = direccion.rotated(sin(_anim_t * 3.2) * 0.55)
	return direccion


func _eje(neg_1: Key, neg_2: Key, pos_1: Key, pos_2: Key) -> float:
	var negativo := Input.is_physical_key_pressed(neg_1) or Input.is_physical_key_pressed(neg_2)
	var positivo := Input.is_physical_key_pressed(pos_1) or Input.is_physical_key_pressed(pos_2)
	return float(positivo) - float(negativo)


func _animar(direccion: Vector2, delta: float) -> void:
	if direccion != Vector2.ZERO:
		if abs(direccion.x) > 0.01:
			_fila = 2
			_mirando_izquierda = direccion.x < 0.0
		else:
			_fila = 0 if direccion.y > 0.0 else 1
	_anim_t += delta
	var columna: int
	if direccion == Vector2.ZERO:
		columna = int(_anim_t * 2.5) % 2
	else:
		columna = 2 + int(_anim_t * 10.0) % 4
	_sprite.frame = _fila * 6 + columna
	_sprite.flip_h = _fila == 2 and _mirando_izquierda
