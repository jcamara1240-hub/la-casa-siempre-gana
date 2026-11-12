class_name Proyectil
extends Sprite2D
## Una bala: del jugador (golpea a los enemigos) o enemiga (golpea al jugador).

const GIRO_BUSCA := 7.0  # radianes por segundo que puede torcer una bala trucada
const RADIO_BUSCA := 120.0

# Se ajustan antes de soltarla.
var radio_golpe := 3.0
var empuje := 60.0
var escala := 1.0
var fuerte := false  # deja estela y parpadea
var giro := 0.0  # vueltas sobre sí misma (corcho, esquirlas); 0 = mira hacia donde va

var _vel := Vector2.ZERO
var _vida := 1.0
var _ataque: Dictionary = {}
var _dueno: Ataques
var _enemigo := false
var _golpeados := {}
var _perfora := 0
var _rebote := 0
var _vuelve := false
var _de_vuelta := false
var _giro_t := 0.0
var _busca := false
var _busca_t := 0.0
var _objetivo: Enemigo = null
var _paredes := 0
var _metralla := false
var _anulada := false
var _t := 0.0
var causa: Dictionary = {}  # quién la disparó (solo las enemigas), ver Ataques.causa_en
var casa: Node2D  # adonde vuelve un boomerang (el jugador que lo lanzó)


func iniciar_jugador(velocidad: Vector2, ataque: Dictionary, vida: float, dueno: Ataques) -> void:
	_vel = velocidad
	_ataque = ataque
	_vida = vida
	_dueno = dueno
	_perfora = ataque.perfora
	_rebote = ataque.rebote
	_vuelve = ataque.vuelve
	_giro_t = vida * 0.45
	_busca = int(ataque.get("busca", 0)) > 0
	_busca_t = randf() * 0.1  # para que no busquen todas en el mismo fotograma
	_paredes = int(ataque.get("paredes", 0))
	_metralla = int(ataque.get("metralla", 0)) > 0


func iniciar_enemigo(velocidad: Vector2, dueno: Ataques) -> void:
	_vel = velocidad
	_vida = 4.0
	_dueno = dueno
	_enemigo = true


func _ready() -> void:
	if _enemigo:
		z_index = 2  # por encima del posproceso y de los efectos: siempre se ve
		return
	if giro == 0.0 and not _vuelve:
		# Estirada en la dirección del vuelo: parece que va más deprisa.
		rotation = _vel.angle()
		scale = Vector2(1.25, 0.85) * escala
	else:
		scale = Vector2.ONE * escala


## Para que una esquirla no vuelva a darle al que acaba de reventar.
func ignorar(e: Enemigo) -> void:
	_golpeados[e] = true


## El órdago la borra: deja de hacer daño y se desvanece.
func anular() -> void:
	if _anulada:
		return
	_anulada = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 2.2, 0.14)
	tw.parallel().tween_property(self, "modulate", Color(1.6, 1.4, 0.8, 0.0), 0.14)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if _anulada:
		return
	_t += delta
	if _vuelve and not _enemigo:
		_mover_boomerang(delta)
	elif _busca:
		_perseguir(delta)
	position += _vel * delta
	_vida -= delta
	if _paredes > 0 and not Sala.INTERIOR.has_point(position):
		_rebotar_en_pared()
	if _vida <= 0.0 or not Sala.INTERIOR.grow(8.0).has_point(position):
		queue_free()
		return
	if _enemigo:
		_actuar_enemiga()
		return
	if giro != 0.0:
		rotation += giro * delta
	elif not _vuelve:
		rotation = _vel.angle()
	if fuerte:
		self_modulate = Color(1.5, 1.3, 0.95) if int(_t * 25.0) % 2 == 0 else Color.WHITE
	for e in _dueno.horda.en_radio(position, radio_golpe):
		if _golpeados.has(e):
			continue
		_golpeados[e] = true
		_dueno.golpear(e, _ataque, _vel.normalized() * empuje)
		if _metralla:
			_metralla = false
			_dueno.soltar_metralla(_ataque, position, _vel.normalized(), e)
		if _rebote > 0:
			_rebote -= 1
			var siguiente: Array = _dueno.horda.mas_cercanos(position, 1, _golpeados)
			if siguiente.is_empty():
				queue_free()
				return
			_vel = (siguiente[0].position - position).normalized() * _vel.length()
			_vida = maxf(_vida, 0.6 * Ataques.ACORTA)
			return
		if _perfora > 0:
			_perfora -= 1
			continue
		if _paredes > 0:
			# El corcho también rebota en los enemigos, y eso gasta un rebote.
			_paredes -= 1
			var fuera: Vector2 = (position - e.position).normalized()
			if fuera == Vector2.ZERO:
				fuera = -_vel.normalized()
			_vel = _vel.bounce(fuera) if _vel.dot(fuera) < 0.0 else fuera * _vel.length()
			_golpeados = {e: true}
			return
		queue_free()
		return


## Las balas enemigas: las paran las mesas y no tocan a quien está rodando.
func _actuar_enemiga() -> void:
	if _dueno.horda.sala.bloquea_bala(position):
		queue_free()
		return
	var tocado := _dueno.jugador_tocado(position, 7.0)
	if tocado != null:
		tocado.recibir_golpe(1, causa)
		queue_free()


func _rebotar_en_pared() -> void:
	var sala := Sala.INTERIOR
	if position.x < sala.position.x or position.x > sala.end.x:
		_vel.x = -_vel.x
	if position.y < sala.position.y or position.y > sala.end.y:
		_vel.y = -_vel.y
	position = position.clamp(sala.position, sala.end)
	_paredes -= 1
	_golpeados.clear()  # tras rebotar puede volver a dar a los mismos
	_vida = maxf(_vida, 0.8 * Ataques.ACORTA)
	Sonido.tocar("clic", randf_range(1.3, 1.6), -8.0)


## Bala Trucada: tuerce poco a poco hacia el enemigo más cercano.
func _perseguir(delta: float) -> void:
	_busca_t -= delta
	if _busca_t <= 0.0:
		_busca_t = 0.12
		_objetivo = _mas_cercano()
	if not is_instance_valid(_objetivo) or not _objetivo.activo():
		return
	var falta := _vel.angle_to(_objetivo.position - position)
	var maximo := GIRO_BUSCA * delta
	_vel = _vel.rotated(clampf(falta, -maximo, maximo))


func _mas_cercano() -> Enemigo:
	var mejor: Enemigo = null
	var mejor_d := RADIO_BUSCA * RADIO_BUSCA
	for e in _dueno.horda.en_radio(position, RADIO_BUSCA):
		if _golpeados.has(e):
			continue
		var d: float = position.distance_squared_to(e.position)
		if d < mejor_d:
			mejor_d = d
			mejor = e
	return mejor


func _draw() -> void:
	# Estela que gira con la bala (se dibuja una vez): todas las tuyas la llevan, las
	# fuertes más larga y dorada. Así se lee hacia dónde va y lo deprisa que va.
	if _enemigo or _vuelve or giro != 0.0:
		return
	var largo := 13.0 if fuerte else 8.0
	draw_line(Vector2(-3.0, 0.0), Vector2(-3.0 - largo, 0.0), Color(1.0, 0.75, 0.35, 0.5 if fuerte else 0.3), 2.0)
	draw_line(Vector2(-3.0, 0.0), Vector2(-3.0 - largo * 0.55, 0.0), Color(1.0, 0.95, 0.8, 0.8 if fuerte else 0.55), 1.0)


func _mover_boomerang(delta: float) -> void:
	_giro_t -= delta
	rotation += 18.0 * delta
	if _giro_t > 0.0:
		return
	if not _de_vuelta:
		_de_vuelta = true
		_golpeados.clear()  # a la vuelta puede volver a golpear
		_vida = 2.0
	var hacia: Vector2 = (casa if is_instance_valid(casa) else _dueno.jugador).global_position - position
	if hacia.length() < 10.0:
		queue_free()
		return
	_vel = hacia.normalized() * _vel.length()
