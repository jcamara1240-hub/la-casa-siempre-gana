extends CharacterBody2D
## El protagonista. Solo se mueve (y rueda): los ataques los lanzan las cartas.

signal golpeado
signal voltereta(direccion: Vector2)
signal por_los_pelos
signal roce(posicion: Vector2)

# Tras un golpe, menos respiro que antes (1,1 s): todo va más rápido, pero sigue siendo justo.
const INVULNERABLE_SEG := 0.5  # hardcore: antes 0,8
const GOLPE_DOBLE_PISO := 3
# La voltereta: corta, muy rápida, invulnerable y encadenable (antes 0,32 s, 285 y 0,55 s).
const VOLTERETA_SEG := 0.24
const VOLTERETA_ENFRIAMIENTO := 0.3
const VOLTERETA_VEL := 430.0  # antes 370
const VOLTERETA_MEMORIA := 0.2  # si la pides un poco antes de tiempo, sale en cuanto se pueda
const PELOS_RADIO := 14.0  # una bala enemiga a menos de esto mientras ruedas: ¡por los pelos!
# El roce: una bala que pasa a menos de esto sin tocarte (te toca a 7) y sin rodar.
const ROCE_RADIO := 17.0
const ROCE_TOCA := 7.5
const REMATE_ENFRIAMIENTO := 0.1  # cada baja recorta la espera de la siguiente voltereta
const RADIO_CUERPO := 6.0
const CENTRO_CUERPO := Vector2(0, 2)  # donde está la caja de choque, respecto al dibujo

# Mucho más ágil (antes 138 y 1700): arranca y frena en seco.
@export var velocidad := 210.0  # antes 168: se sentía lento
@export var aceleracion := 4600.0

var invulnerable := false  # lo usa la prueba automática
var seguro_listo := false
var arrastre := Vector2.ZERO  # lo que tira de ti: la Caja Registradora, por ejemplo
# Los pone main: para volcar mesas, dañar al rodar y mirar las balas cercanas.
var sala: Sala
var horda: Horda
var ataques: Ataques

var _invulnerable_t := 0.0
var _anim_t := 0.0
var _fila := 0
var _mirando_izquierda := false
var _ultima_direccion := Vector2.DOWN
var _rodar_t := 0.0
var _rodar_dir := Vector2.ZERO
var _enfriamiento := 0.0
var _pedida := 0.0
var _pelos_hecho := false
var _rodados := {}  # enemigos ya atropellados en esta voltereta
var _aterrizaje := 0.0
var _patada := Vector2.ZERO  # el dibujo retrocede un poco al disparar

@onready var _sprite: Sprite2D = $Sprite


func _physics_process(delta: float) -> void:
	var direccion := _leer_direccion()
	if direccion != Vector2.ZERO:
		_ultima_direccion = direccion
	_enfriamiento = maxf(_enfriamiento - delta, 0.0)
	_pedida = maxf(_pedida - delta, 0.0)
	if _pedida > 0.0 and not rodando() and _enfriamiento <= 0.0:
		_empezar_voltereta(direccion)
	if rodando():
		_rodar(delta)
	else:
		var tope := velocidad * (1.0 + Juego.stat("velocidad")) * Juego.factor_velocidad()
		if Juego.rodo_hace_poco():
			tope *= 1.0 + Juego.stat("espuelas")
		velocity = velocity.move_toward(direccion * tope, aceleracion * delta)
	_mirar_roces()
	var propia := velocity
	velocity += arrastre
	arrastre = Vector2.ZERO
	move_and_slide()
	velocity = propia
	# Las mesas no son cuerpos físicos: se sale de ellas a mano, como los enemigos.
	if sala != null and not sala.cajas_mesas.is_empty():
		position = sala.sacar_de_mesas(position + CENTRO_CUERPO, RADIO_CUERPO) - CENTRO_CUERPO
	_animar(direccion, delta)
	_animar_cuerpo(delta)
	if _invulnerable_t > 0.0:
		_invulnerable_t -= delta
		_sprite.visible = fmod(_invulnerable_t, 0.14) > 0.05 or _invulnerable_t <= 0.0


func _unhandled_input(evento: InputEvent) -> void:
	var pide := false
	if evento is InputEventKey and evento.pressed and not evento.echo:
		pide = evento.physical_keycode == KEY_SPACE or evento.physical_keycode == KEY_SHIFT
	elif evento is InputEventMouseButton and evento.pressed:
		pide = evento.button_index == MOUSE_BUTTON_RIGHT
	elif Mando.es_mando(evento):
		pide = Mando.accion(evento) == "voltereta"
	if pide:
		pedir_voltereta()
		get_viewport().set_input_as_handled()


func recibir_golpe(cantidad := 1) -> void:
	if _invulnerable_t > 0.0 or invulnerable or rodando():
		return
	_invulnerable_t = INVULNERABLE_SEG + Juego.stat("invulnerable")
	if seguro_listo:
		seguro_listo = false
		return
	Juego.vaciar_fiebre()
	var coste := int(Juego.stat("golpe_monedas"))
	if coste > 0 and not Juego.extremo and Juego.gastar_oro(coste):
		Sonido.tocar("perder")
		return
	# En el modo infinito, cada cuatro pisos extra los golpes quitan un corazón más.
	# Hardcore: desde el piso 3 cada golpe se lleva un corazón entero.
	Juego.herir(cantidad + Juego.pisos_extra() / 4 + (1 if Juego.piso >= GOLPE_DOBLE_PISO and Juego.stat("chaleco") <= 0.0 else 0))
	# El Espejo de Mano: el golpe te lo llevas, pero la sala se queda sin balas.
	if Juego.stat("espejo") > 0.0 and ataques != null:
		ataques.borrar_balas_enemigas()
	Sonido.tocar("dano")
	golpeado.emit()


## Un respiro sin que nada te toque (el órdago, por ejemplo). Parpadea como tras un golpe.
func proteger(seg: float) -> void:
	_invulnerable_t = maxf(_invulnerable_t, seg)


func aplicar_personaje() -> void:
	_sprite.texture = PersonajesDB.textura(Juego.personaje)
	_sprite.modulate = Color.WHITE


func teñir(color: Color) -> void:
	_sprite.modulate = color


# ------------------------------------------------------------ voltereta
func rodando() -> bool:
	return _rodar_t > 0.0


## Lista para rodar ya mismo (sin contar la que esté en marcha).
func voltereta_lista() -> bool:
	return not rodando() and _enfriamiento <= 0.0


## Teclado, ratón, mando, botón táctil o el bot: se apunta y sale en cuanto se pueda.
func pedir_voltereta() -> void:
	_pedida = VOLTERETA_MEMORIA


func _empezar_voltereta(direccion: Vector2) -> void:
	_pedida = 0.0
	_rodar_dir = (direccion if direccion != Vector2.ZERO else _ultima_direccion).normalized()
	_rodar_t = VOLTERETA_SEG
	_pelos_hecho = false
	_rodados.clear()
	Juego.ultima_voltereta = Juego.tiempo_partida
	Sonido.tocar("voltereta", randf_range(0.95, 1.1))
	# As en la Manga: al rodar sueltas naipes en todas direcciones.
	if Juego.stat("voltereta_bala") > 0.0 and ataques != null:
		ataques.ataque_suelto("nova", 3.0, 6, position)
	voltereta.emit(_rodar_dir)


func _rodar(delta: float) -> void:
	_rodar_t -= delta
	var avance := 1.0 - _rodar_t / VOLTERETA_SEG
	# Sale disparado y frena al final: así se nota el impulso.
	velocity = _rodar_dir * VOLTERETA_VEL * lerpf(1.2, 0.65, avance) * (1.0 + Juego.stat("velocidad") * 0.5) * (Juego.DESATADO_VELOCIDAD if Juego.desatado else 1.0)
	_mirar_pelos()
	_atropellar()
	if sala != null:
		sala.volcar_cerca(position + CENTRO_CUERPO, RADIO_CUERPO + 2.0, horda)
	if _rodar_t <= 0.0:
		_rodar_t = 0.0
		_aterrizaje = 1.0
		_enfriamiento = VOLTERETA_ENFRIAMIENTO * (1.0 - clampf(Juego.stat("voltereta_rapida"), 0.0, 0.8))


func _mirar_pelos() -> void:
	if _pelos_hecho or ataques == null:
		return
	if ataques.balas_enemigas_cerca(position, PELOS_RADIO) > 0:
		_pelos_hecho = true
		Juego.subir_fiebre(Juego.FIEBRE_POR_PELOS * (1.0 + Juego.stat("roce_extra")))
		Sonido.tocar("por_los_pelos")
		por_los_pelos.emit()


## Una baja: la siguiente voltereta llega antes. Matar te da movimiento.
func remate() -> void:
	_enfriamiento = maxf(_enfriamiento - REMATE_ENFRIAMIENTO, 0.0)


## El roce: una bala que se acerca mucho y se aleja sin tocarte, sin rodar. Una vez por bala.
## La distancia de cada bala se apunta en ella misma (meta), así no se toca proyectil.gd.
func _mirar_roces() -> void:
	if ataques == null:
		return
	var lista = ataques.get("_balas_enemigas")
	if not (lista is Array):
		return
	var centro := position  # las balas y tú colgáis del mismo Mundo (el temblor no cuenta)
	var lejos := ROCE_RADIO * 2.0
	# Rodando o parpadeando no hay roce: las que pasen ahora ya no cuentan.
	var vale := not rodando() and _invulnerable_t <= 0.0 and not invulnerable
	for p in lista:
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		var d: float = p.position.distance_to(centro)
		if d > lejos:
			if p.has_meta("roce_d"):
				p.remove_meta("roce_d")
			continue
		if p.has_meta("rozada"):
			continue
		if not vale:
			if d < ROCE_RADIO:
				p.set_meta("rozada", true)
			continue
		var antes: float = p.get_meta("roce_d", INF)
		p.set_meta("roce_d", minf(antes, d))
		# Ya se aleja: su punto más cercano fue un roce y no un golpe.
		if d > antes and antes < ROCE_RADIO and antes >= ROCE_TOCA:
			p.set_meta("rozada", true)
			_rozar(p.position)


func _rozar(donde: Vector2) -> void:
	Juego.subir_fiebre(Juego.FIEBRE_POR_ROCE * (1.0 + Juego.stat("roce_extra")))
	Sonido.tocar("roce", randf_range(0.95, 1.15))
	roce.emit(donde)


## Zapatos de Claqué: rodar a través de un enemigo le hace daño (una vez por voltereta).
func _atropellar() -> void:
	var fuerza := Juego.stat("voltereta_dano")
	if fuerza <= 0.0 or horda == null:
		return
	var dano := (6.0 + (Juego.piso - 1) * 5.0) * fuerza
	for e in horda.en_radio(position + CENTRO_CUERPO, RADIO_CUERPO):
		if _rodados.has(e):
			continue
		_rodados[e] = true
		horda.danar(e, dano, _rodar_dir * 160.0)
		e.aturdir(0.35)


## El dibujo da un pequeño respingo hacia atrás (solo visual: no te mueve).
func patada(direccion: Vector2, fuerza: float) -> void:
	_patada = (-direccion * fuerza).limit_length(3.0)


# ------------------------------------------------------------ dibujo
func _leer_direccion() -> Vector2:
	var x := _eje(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT)
	var y := _eje(KEY_W, KEY_UP, KEY_S, KEY_DOWN)
	# normalized() evita que en diagonal se corra más que en línea recta.
	var direccion := Vector2(x, y).normalized()
	# El mando: stick analógico (con zona muerta) o cruceta. Salvo si está ordenando cartas.
	if direccion == Vector2.ZERO and not Mando.bloqueado:
		direccion = Mando.direccion()
	if Juego.direccion_tactil != Vector2.ZERO:
		direccion = Juego.direccion_tactil
	if Juego.stat("tambaleo") > 0.0 and direccion != Vector2.ZERO:
		direccion = direccion.rotated(sin(_anim_t * 3.2) * 0.55)
	return direccion


func _eje(neg_1: Key, neg_2: Key, pos_1: Key, pos_2: Key) -> float:
	var negativo := Input.is_physical_key_pressed(neg_1) or Input.is_physical_key_pressed(neg_2)
	var positivo := Input.is_physical_key_pressed(pos_1) or Input.is_physical_key_pressed(pos_2)
	return float(positivo) - float(negativo)


func _animar(direccion: Vector2, delta: float) -> void:
	if rodando():
		direccion = _rodar_dir
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


## La vuelta de campana al rodar, el aplastón al aterrizar y el respingo al disparar.
func _animar_cuerpo(delta: float) -> void:
	_patada = _patada.lerp(Vector2.ZERO, clampf(delta * 18.0, 0.0, 1.0))
	if rodando():
		var avance := 1.0 - _rodar_t / VOLTERETA_SEG
		var giro := TAU * avance
		_sprite.rotation = giro if _rodar_dir.x >= 0.0 else -giro
		var s := sin(avance * PI)
		_sprite.scale = Vector2(1.0 + 0.22 * s, 1.0 - 0.18 * s)
	else:
		_sprite.rotation = 0.0
		_aterrizaje = maxf(_aterrizaje - delta * 6.0, 0.0)
		_sprite.scale = Vector2(1.0 + 0.2 * _aterrizaje, 1.0 - 0.15 * _aterrizaje)
	_sprite.position = _patada.round()
