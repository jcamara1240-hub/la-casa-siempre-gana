class_name Jefe
extends Enemigo
## Lo común a todos los jefes. Cada uno concreto vive en scripts/jefes/.

const NACER_JEFE := 0.6  # antes 0,8
# Ritmo de los jefes: todo su comportamiento corre más deprisa (y más aún enfadados).
# Encima va el ritmo propio de cada jefe al enfadarse (x1,25-1,4).
const RITMO_JEFE := 1.4
const RITMO_JEFE_EXTREMO := 1.2
const RITMO_ENFADADO := 1.2
# Anillos más densos: los pequeños llevan un 15 % más de balas (los grandes ya van llenos).
const DENSIDAD := 1.4
const DENSIDAD_HASTA := 28
const MURO_VEL := 220.0  # antes 190
const NOMBRES := PersonajesDB.JEFES

var nombre := "JEFE"
var vida_base := 300.0

var _letrero: Label


static func crear(id: String) -> Jefe:
	match id:
		"pez": return JefePez.new()
		"tragaperras": return JefeTragaperras.new()
		"ruleta": return JefeRuleta.new()
		"baccarat": return JefeBaccarat.new()
		"blackjack": return JefeBlackjack.new()
		"dados": return JefeDados.new()
		"revolver": return JefeRevolver.new()
		"bingo": return JefeBingo.new()
		"trilero": return JefeTrilero.new()
		"cajero": return JefeCajero.new()
		"coctelero": return JefeCoctelero.new()
		"poker": return JefePoker.new()
		"dueno": return JefeDueno.new()
	push_error("Jefe desconocido: " + id)
	return JefePez.new()


const DANO_MAX_SEGUNDO := 0.10  # parte de su vida que puede perder por segundo

const ATURDIR_ESPERA := 3.0

var _dano_segundo := 0.0
var _reloj_dano := 1.0
var _aturdible_t := 0.0


func preparar(multiplicador: float) -> void:
	tipo = "jefe"
	radio = 21.0
	vel = 24.0
	oro_prob = 0.0
	_aplaste_fuerza = 0.4
	_configurar()
	vida = vida_base * multiplicador
	vida_max = vida
	_nacer = NACER_JEFE
	modulate.a = 0.0
	_letrero = Label.new()
	_letrero.position = Vector2(-40, -40)
	_letrero.size = Vector2(80, 9)
	_letrero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letrero.add_theme_color_override("font_color", Color8(247, 198, 74))
	_letrero.top_level = false
	add_child(_letrero)


func _configurar() -> void:
	pass


func _comportamiento(_delta: float, _horda: Horda) -> void:
	pass


func actualizar(delta: float, horda: Horda) -> void:
	_reloj_dano -= delta
	if _reloj_dano <= 0.0:
		_reloj_dano = 1.0
		_dano_segundo = 0.0
	_t += delta
	_aturdible_t = maxf(_aturdible_t - delta, 0.0)
	if _nacer > 0.0:
		_nacer -= delta
		modulate.a = 1.0 - clampf(_nacer / NACER_JEFE, 0.0, 1.0) * 0.8
		return
	_tick_estados(delta, horda)
	_tick_aplaste(delta)
	if _aturdido_t > 0.0:
		_aturdido_t -= delta
		if _aturdido_t <= 0.0 and _flash <= 0.0:
			modulate = _color_base()
		return
	if not muerto:
		_comportamiento(delta * ritmo(), horda)
		var zona := Sala.INTERIOR.grow(-radio - 2.0)
		position = position.clamp(zona.position, zona.end)


## A un jefe un órdago solo le hace parpadear un instante, y como mucho una vez cada
## tres segundos: si no, un combo que aturde en cada golpe lo dejaría congelado.
func aturdir(seg: float) -> void:
	if _aturdible_t > 0.0:
		return
	_aturdible_t = ATURDIR_ESPERA
	super.aturdir(seg * 0.15)


func enfadado() -> bool:
	return vida < vida_max * 0.5


## Lo que se acelera su comportamiento ahora mismo.
func ritmo() -> float:
	if not _acelera():
		return 1.0
	return (RITMO_JEFE_EXTREMO if Juego.extremo else RITMO_JEFE) * (RITMO_ENFADADO if enfadado() else 1.0)


## Los momentos en que el jefe está vendido (aturdido, pillado) no se acortan.
func _acelera() -> bool:
	return true


func aplicar_golpe(dano: float, _retroceso: Vector2) -> void:
	# Por muy bestia que sea el combo, desde el piso 2 no se les revienta de un golpe.
	if Juego.piso >= 2:
		# En el modo infinito ese tope baja: cada jefe aguanta más que el anterior.
		var tope := maxf(DANO_MAX_SEGUNDO * pow(0.93, Juego.pisos_extra()), 0.03)
		var disponible := maxf(vida_max * tope - _dano_segundo, 0.0)
		dano = minf(dano, disponible)
		_dano_segundo += dano
	super.aplicar_golpe(dano, Vector2.ZERO)


## Los ayudantes de balas van más rápidos que los números de cada jefe (ritmo_balas).
func _anillo(horda: Horda, cuantas: int, velocidad: float, giro: float, clase: String) -> void:
	if cuantas <= DENSIDAD_HASTA and not Juego.extremo:
		cuantas = roundi(cuantas * DENSIDAD)
	for i in cuantas:
		horda.ataques.bala_enemiga(position, Vector2.RIGHT.rotated(giro + TAU * i / cuantas) * velocidad * ritmo_balas(), clase)


func _abanico(horda: Horda, cuantas: int, apertura: float, velocidad: float, clase: String) -> void:
	var hacia: Vector2 = (horda.jugador.global_position - position).normalized()
	for i in cuantas:
		horda.ataques.bala_enemiga(position, hacia.rotated((i - (cuantas - 1) * 0.5) * apertura) * velocidad * ritmo_balas(), clase)


## Un muro de balas que cruza la sala y deja un hueco para pasar.
func _muro(horda: Horda, vertical: bool, clase: String) -> void:
	var zona := Sala.INTERIOR
	var total := int((zona.size.y if vertical else zona.size.x) / 18.0)
	var hueco := randi_range(2, total - 5)
	var desde_inicio := randf() < 0.5
	for i in total:
		if i >= hueco and i < hueco + 4:
			continue
		var base := 9.0 + i * 18.0
		if vertical:
			var x := zona.position.x + 4.0 if desde_inicio else zona.end.x - 4.0
			horda.ataques.bala_enemiga(Vector2(x, zona.position.y + base), Vector2(MURO_VEL if desde_inicio else -MURO_VEL, 0.0), clase)
		else:
			var y := zona.position.y + 4.0 if desde_inicio else zona.end.y - 4.0
			horda.ataques.bala_enemiga(Vector2(zona.position.x + base, y), Vector2(0.0, MURO_VEL if desde_inicio else -MURO_VEL), clase)


func _invocar(horda: Horda, tipos: Array) -> void:
	if horda.enemigos.size() >= Enemigo.TOPE_INVOCADOS:
		return
	for t in tipos:
		horda.crear(t, position + Vector2.RIGHT.rotated(randf() * TAU) * 44.0)
