class_name Ataques
extends Node2D
## Convierte cada ataque del combo en balas, rayos, cuchillas y explosiones.

signal explosion_hecha
## Una vez por ataque lanzado. fuerza: 1 normal, 2 gordo, 3 enorme.
signal disparo(origen: Vector2, direccion: Vector2, fuerza: float)
## En cada golpe a un enemigo.
signal impacto(posicion: Vector2, direccion: Vector2, critico: bool)
signal explosion_en(centro: Vector2, radio: float)

# Más rápidas que antes (260) y con la vida acortada en proporción: llegan igual de lejos.
const VEL_BALA := 340.0
const ACORTA := 260.0 / VEL_BALA
const TOPE_MINAS := 8
const TOPE_ESQUIRLAS := 48
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_LASER := Color8(214, 61, 79)

var horda: Horda
var jugador: Node2D

var _tex_bala: Texture2D = load("res://assets/efectos/bala.png")
var _tex_enemigas := {
	"moneda": load("res://assets/efectos/bala_enemiga.png"),
	"burbuja": load("res://assets/efectos/burbuja.png"),
	"naipe_bala": load("res://assets/efectos/naipe_bala.png"),
	"naipe_negro": load("res://assets/efectos/naipe_negro.png"),
}
var _tex_cuchilla: Texture2D = load("res://assets/efectos/cuchilla.png")
var _tex_explosion: Texture2D = load("res://assets/efectos/explosion.png")
var _tex_perdigon: Texture2D = load("res://assets/efectos/perdigon.png")
var _tex_corcho: Texture2D = load("res://assets/efectos/corcho.png")
var _tex_dinamita: Texture2D = load("res://assets/efectos/dinamita.png")
var _tex_mina: Texture2D = load("res://assets/efectos/mina.png")
var _tex_barrido: Texture2D = load("res://assets/efectos/barrido.png")
var _tex_esquirla: Texture2D = load("res://assets/efectos/esquirla.png")

var _suma := CanvasItemMaterial.new()  # para los brillos: suma luz en vez de tapar

var _balas_enemigas: Array = []  # se apuntan aquí para no recorrer todos los hijos
var _minas: Array = []  # de la más vieja a la más nueva
var _esquirlas := 0


func _ready() -> void:
	_suma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func limpiar() -> void:
	for h in get_children():
		h.queue_free()
	_balas_enemigas.clear()
	_minas.clear()


func lanzar(a: Dictionary) -> void:
	_lanzar_desde(a, jugador.global_position, true)


## Un ataque fuera del combo (lo usan los objetos, p. ej. los naipes al rodar).
func ataque_suelto(id: String, dano: float, n: int, origen: Vector2) -> void:
	_lanzar_desde(Combo.ataque_suelto(id, dano, n), origen, false)


func _lanzar_desde(a: Dictionary, origen: Vector2, del_jugador: bool) -> void:
	var objetivo: Array = horda.mas_cercanos(origen, 1)
	var hacia := Vector2.RIGHT.rotated(randf() * TAU)
	if not objetivo.is_empty():
		hacia = (objetivo[0].position - origen).normalized()
	elif del_jugador:
		return
	if hacia == Vector2.ZERO:
		hacia = Vector2.RIGHT
	_sonar(a)
	disparo.emit(origen, hacia, _fuerza(a))
	match String(a.id):
		"bala", "dados", "bola", "dardo":
			_abanico(a, origen, hacia, 0.16, 1.1 * ACORTA)
		"as_picas":
			_abanico(a, origen, hacia, 0.16, 1.1 * ACORTA, null, VEL_BALA * 1.2, 130.0)
		"ruleta_rusa":
			_ruleta(a, origen, hacia)
		"billete":
			_abanico(a, origen, hacia, 0.07, 0.9 * ACORTA)
		"taco":
			_abanico(a, origen, hacia, 0.1, 0.4 * ACORTA, null, VEL_BALA, 130.0)
		"reparto":
			_abanico(a, origen, hacia, 0.05, 0.9 * ACORTA)
		"abanico":
			_abanico(a, origen, hacia, 0.3, 0.55 * ACORTA)
		"boomerang":
			_abanico(a, origen, hacia, 0.25, 1.0 * ACORTA)
		"recortada":
			_recortada(a, origen, hacia)
		"tommy":
			_rafaga(a, origen, hacia, del_jugador)
		"corcho":
			_corcho(a, origen, hacia)
		"nova":
			for i in a.n:
				_bala(a, origen, Vector2.RIGHT.rotated(TAU * i / a.n + hacia.angle()), 0.7 * ACORTA)
		"rayo":
			_rayo(a, origen)
		"laser":
			_lasers(a, origen, hacia)
		"explosion", "molotov", "lluvia", "jackpot", "bola8":
			for e in _objetivos_area(a, origen):
				_explotar(a, e.position)
		"dinamita":
			for e in _objetivos_area(a, origen):
				_lanzar_dinamita(a, origen, e)
		"mina":
			_minar(a, origen, hacia)
		"botella":
			_barrido(a, origen, hacia)
		"cuchilla", "ruleta_gira":
			for i in a.n:
				_cuchilla(a, TAU * i / a.n)


## Cada arma con su sonido.
func _sonar(a: Dictionary) -> void:
	match String(a.id):
		"rayo":
			Sonido.tocar("rayo")
		"explosion", "molotov", "lluvia", "jackpot", "bola8":
			Sonido.tocar("explosion", randf_range(0.9, 1.15), -3.0)
		"recortada":
			Sonido.tocar("escopeta", randf_range(0.92, 1.08))
		"tommy":
			pass  # suena cada bala de la ráfaga
		"laser":
			Sonido.tocar("laser", randf_range(0.95, 1.05))
		"mina":
			Sonido.tocar("mina", randf_range(0.95, 1.1), -4.0)
		"botella":
			Sonido.tocar("barrido", randf_range(0.9, 1.1))
		"dinamita":
			Sonido.tocar("carta", 0.7, -2.0)
		"corcho":
			Sonido.tocar("disparo", 1.6, -2.0)
		"ruleta_rusa":
			if a.get("premio", false):
				Sonido.tocar("impacto_fuerte", 0.8)
				Sonido.tocar("disparo", 0.7)
			else:
				Sonido.tocar("disparo", 1.0, -3.0)
		"as_picas":
			Sonido.tocar("carta", 0.8)
		_:
			Sonido.tocar("carta", randf_range(0.95, 1.2))
	if int(a.get("calibre", 0)) > 0:
		Sonido.tocar("impacto_fuerte", 0.7, -8.0)


func _fuerza(a: Dictionary) -> float:
	match String(a.id):
		"jackpot", "laser":
			return 3.0
		"recortada", "as_picas", "dinamita":
			return 2.0
		"ruleta_rusa":
			return 3.0 if a.get("premio", false) else 1.0
	return 2.0 if int(a.get("calibre", 0)) > 0 else 1.0


## Gran Calibre agranda las áreas, los rayos y las cuchillas.
func _escala(a: Dictionary) -> float:
	return 1.0 + 0.25 * int(a.get("calibre", 0))


# ------------------------------------------------------------ balas del jugador
func _abanico(a: Dictionary, origen: Vector2, hacia: Vector2, apertura: float, vida: float,
		tex: Texture2D = null, vel := VEL_BALA, empuje := 65.0) -> void:
	for i in a.n:
		var desvio: float = (i - (a.n - 1) * 0.5) * apertura
		_bala(a, origen, hacia.rotated(desvio), vida, tex, vel, empuje)


func _bala(a: Dictionary, origen: Vector2, direccion: Vector2, vida: float,
		tex: Texture2D = null, vel := VEL_BALA, empuje := 65.0) -> void:
	add_child(_preparar_bala(a, origen, direccion, vida, tex, vel, empuje))


## Crea la bala sin soltarla todavía, por si hay que retocarla.
func _preparar_bala(a: Dictionary, origen: Vector2, direccion: Vector2, vida: float,
		tex: Texture2D = null, vel := VEL_BALA, empuje := 65.0) -> Proyectil:
	var p := Proyectil.new()
	p.texture = tex if tex != null else _tex_bala
	p.position = origen
	var calibre := int(a.get("calibre", 0))
	if calibre > 0:
		# Más gorda y más lenta, pero llega igual de lejos.
		var lenta := 1.0 + 0.35 * calibre
		vel /= lenta
		vida *= lenta
		p.radio_golpe += 3.0 * calibre
		p.escala = 1.0 + 0.6 * calibre
	if int(a.get("busca", 0)) > 0:
		vida *= 1.5  # le da tiempo a perseguir
	p.empuje = empuje
	p.fuerte = calibre > 0 or bool(a.get("premio", false)) or float(a.dano) >= 12.0
	p.iniciar_jugador(direccion * vel, a, vida, self)
	return p


## Seis perdigones en abanico ancho: poco alcance y mucho empujón.
func _recortada(a: Dictionary, origen: Vector2, hacia: Vector2) -> void:
	var apertura := 1.0 / maxf(float(a.n) - 1.0, 1.0)
	for i in a.n:
		var desvio: float = (i - (a.n - 1) * 0.5) * apertura + randf_range(-0.05, 0.05)
		_bala(a, origen, hacia.rotated(desvio), randf_range(0.26, 0.34) * ACORTA, _tex_perdigon,
				VEL_BALA * randf_range(1.05, 1.25), 115.0)


## La metralleta suelta sus balas de una en una; si la lanzas tú, apunta cada vez.
func _rafaga(a: Dictionary, origen: Vector2, hacia: Vector2, del_jugador: bool) -> void:
	var tanda := Node.new()  # al limpiar la sala se va con ella y la ráfaga se corta
	add_child(tanda)
	var tw := tanda.create_tween()
	for _i in a.n:
		tw.tween_callback(_bala_rafaga.bind(a, origen, hacia, del_jugador))
		tw.tween_interval(0.055)
	tw.tween_callback(tanda.queue_free)


func _bala_rafaga(a: Dictionary, origen: Vector2, hacia: Vector2, del_jugador: bool) -> void:
	if del_jugador:
		origen = jugador.global_position
		var cerca: Array = horda.mas_cercanos(origen, 1)
		if not cerca.is_empty() and cerca[0].position != origen:
			hacia = (cerca[0].position - origen).normalized()
	Sonido.tocar("metralleta", randf_range(0.92, 1.08), -4.0)
	_bala(a, origen, hacia.rotated(randf_range(-0.13, 0.13)), 1.0 * ACORTA, null, VEL_BALA * 1.15, 50.0)


## Una bala; si sale el premio, roja, más gorda y más rápida.
func _ruleta(a: Dictionary, origen: Vector2, hacia: Vector2) -> void:
	var premio := bool(a.get("premio", false))
	for i in a.n:
		var desvio: float = (i - (a.n - 1) * 0.5) * 0.16
		var p := _preparar_bala(a, origen, hacia.rotated(desvio), 1.1 * ACORTA, null,
				VEL_BALA * (1.3 if premio else 1.0), 150.0 if premio else 65.0)
		if premio:
			p.modulate = Color(1.7, 0.45, 0.4)
			p.escala *= 1.5
		add_child(p)


## El corcho rebota en las paredes (y en los enemigos) y empuja fuerte.
func _corcho(a: Dictionary, origen: Vector2, hacia: Vector2) -> void:
	for i in a.n:
		var desvio: float = (i - (a.n - 1) * 0.5) * 0.2
		var p := _preparar_bala(a, origen, hacia.rotated(desvio), 2.6, _tex_corcho, 230.0, 170.0)
		p.giro = 16.0
		add_child(p)


## Tres esquirlas por cada Metralla, al 40% del daño. Las esquirlas no sueltan más.
func soltar_metralla(a: Dictionary, punto: Vector2, direccion: Vector2, excluir: Enemigo = null) -> void:
	var cuantas := 3 * int(a.get("metralla", 0))
	if cuantas <= 0:
		return
	var esquirla := a.duplicate()
	esquirla["id"] = "esquirla"
	esquirla["dano"] = float(a.dano) * 0.4
	for campo in ["metralla", "busca", "calibre", "paredes", "perfora", "rebote"]:
		esquirla[campo] = 0
	esquirla["vuelve"] = false
	esquirla["premio"] = false
	for _i in cuantas:
		if _esquirlas >= TOPE_ESQUIRLAS:
			return
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		if direccion != Vector2.ZERO:
			dir = direccion.rotated(randf_range(-1.1, 1.1))
		var p := _preparar_bala(esquirla, punto, dir, 0.32 * ACORTA, _tex_esquirla, VEL_BALA * randf_range(0.8, 1.0), 40.0)
		p.giro = 22.0
		if excluir != null:
			p.ignorar(excluir)
		_esquirlas += 1
		p.tree_exiting.connect(_olvidar_esquirla)
		add_child(p)


func _olvidar_esquirla() -> void:
	_esquirlas = maxi(_esquirlas - 1, 0)


# ------------------------------------------------------------ balas enemigas
func bala_enemiga(origen: Vector2, velocidad: Vector2, clase := "moneda") -> void:
	var p := Proyectil.new()
	p.texture = _tex_enemigas.get(clase, _tex_enemigas["moneda"])
	p.position = origen
	p.iniciar_enemigo(velocidad * (1.0 - Juego.stat("bala_lenta")), self)
	Sonido.tocar("disparo", randf_range(0.8, 1.1), -9.0)
	_balas_enemigas.append(p)
	p.tree_exiting.connect(_olvidar_bala.bind(p))
	add_child(p)


func _olvidar_bala(p: Proyectil) -> void:
	_balas_enemigas.erase(p)


## El órdago: todas las balas enemigas se desvanecen. Devuelve cuántas había.
func borrar_balas_enemigas() -> int:
	var cuantas := 0
	for p in _balas_enemigas:
		if is_instance_valid(p):
			p.anular()
			cuantas += 1
	_balas_enemigas.clear()
	return cuantas


func balas_enemigas_cerca(centro: Vector2, radio: float) -> int:
	var cuantas := 0
	var radio2 := radio * radio
	for p in _balas_enemigas:
		if p.position.distance_squared_to(centro) <= radio2:
			cuantas += 1
	return cuantas


# ------------------------------------------------------------ golpes
func golpear(e: Enemigo, a: Dictionary, retroceso: Vector2) -> void:
	if e.muerto:
		return
	var dano: float = a.dano
	if a.azar:
		# Un dado: entre la cuarta parte y casi el doble de lo apuntado.
		dano *= float(randi_range(1, 7)) / 4.0
	var color := COLOR_CREMA
	var critico := false
	if randf() < float(a.crit) + Juego.stat("crit"):
		dano *= 2.0 + Juego.stat("crit_mult")
		color = COLOR_ORO
		critico = true
	if a.oro > 0:
		e.oro_prob = 1.0
	var direccion := retroceso.normalized()
	if direccion == Vector2.ZERO:
		direccion = (e.position - jugador.global_position).normalized()
	var empujon := int(a.get("empuje", 0))
	if empujon > 0:
		# Empujón: el triple de retroceso (aunque el ataque no empujara) y un momento aturdido.
		if retroceso == Vector2.ZERO:
			retroceso = direccion * 60.0
		retroceso *= 1.0 + 2.0 * empujon
		e.aturdir(minf(0.5 * empujon, 1.0))
	retroceso *= 1.0 + Juego.stat("retroceso")
	horda.danar(e, dano, retroceso, color)
	var quema: float = a.quema + Juego.stat("quema_global")
	if quema > 0.0:
		e.aplicar_quemadura(max(1.0, a.dano * 0.4) * quema)
	if a.frio > 0:
		e.aplicar_frio()
	if critico or a.get("premio", false):
		Sonido.tocar("impacto_fuerte", randf_range(0.9, 1.1), -6.0)
	impacto.emit(e.position, direccion, critico)


## Un aviso en el suelo que, pasado un momento, explota: lo usa el Bingo.
func zona_peligro(centro: Vector2, radio: float, retardo: float, duracion := 0.0) -> void:
	var z := ZonaPeligro.new()
	z.iniciar(centro, radio, retardo, self, duracion)
	add_child(z)


# ------------------------------------------------------------ rayos
func _rayo(a: Dictionary, origen: Vector2) -> void:
	# Con Bala Trucada el neón salta mucho más lejos.
	var alcance := 300.0 if int(a.get("busca", 0)) > 0 else 170.0
	var vistos := {}
	var punto := origen
	var trazo := PackedVector2Array([to_local(origen)])
	var ultimo: Enemigo = null
	for _i in a.n:
		var lista: Array = horda.mas_cercanos(punto, 1, vistos)
		if lista.is_empty():
			break
		var e: Enemigo = lista[0]
		if e.position.distance_to(punto) > alcance:
			break
		vistos[e] = true
		var medio := (punto + e.position) * 0.5 + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		trazo.append(to_local(medio))
		trazo.append(to_local(e.position))
		golpear(e, a, Vector2.ZERO)
		punto = e.position
		ultimo = e
	if trazo.size() > 1:
		_dibujar_rayo(trazo, COLOR_ORO, 2.0 * _escala(a), 0.16)
	if ultimo != null:
		soltar_metralla(a, ultimo.position, Vector2.ZERO, ultimo)


func _dibujar_rayo(trazo: PackedVector2Array, color := COLOR_ORO, ancho := 2.0, vida := 0.16) -> void:
	var linea := Line2D.new()
	linea.points = trazo
	linea.width = ancho
	linea.default_color = color
	add_child(linea)
	# El brillo: la misma línea, ancha y sumando luz, por detrás.
	var halo := Line2D.new()
	halo.points = trazo
	halo.width = ancho * 3.5 + 2.0
	halo.default_color = Color(color, 0.24)
	halo.joint_mode = Line2D.LINE_JOINT_ROUND
	halo.begin_cap_mode = Line2D.LINE_CAP_ROUND
	halo.end_cap_mode = Line2D.LINE_CAP_ROUND
	halo.material = _suma
	halo.show_behind_parent = true
	linea.add_child(halo)
	var nucleo := Line2D.new()
	nucleo.points = trazo
	nucleo.width = maxf(1.0, ancho * 0.4)
	nucleo.default_color = COLOR_CREMA
	linea.add_child(nucleo)
	var tw := linea.create_tween()
	tw.tween_property(linea, "modulate:a", 0.0, vida)
	tw.tween_callback(linea.queue_free)


## Uno o varios láseres: cada uno hacia un enemigo distinto, si los hay.
func _lasers(a: Dictionary, origen: Vector2, hacia: Vector2) -> void:
	var ancho: float = float(a.radio) * (1.0 + 0.6 * int(a.get("calibre", 0)))
	var direcciones: Array = []
	if int(a.get("busca", 0)) > 0:
		direcciones.append(_mejor_linea(origen, ancho))
	for e in horda.mas_cercanos(origen, a.n):
		if direcciones.size() >= a.n:
			break
		var d: Vector2 = (e.position - origen).normalized()
		if d != Vector2.ZERO:
			direcciones.append(d)
	while direcciones.size() < a.n:
		direcciones.append(hacia.rotated(0.2 * direcciones.size()))
	for rumbo in direcciones:
		_laser(a, origen, rumbo, ancho)


## Un rayo recto hasta la pared que golpea a todo lo que cruza; con Carambola se refleja.
func _laser(a: Dictionary, origen: Vector2, direccion: Vector2, ancho: float) -> void:
	var sala := Sala.INTERIOR
	var p := origen.clamp(sala.position, sala.end)
	var d := direccion
	var trazo := PackedVector2Array([to_local(p)])
	var metralla_hecha := false
	for _tramo in int(a.get("paredes", 0)) + 1:
		var fin := _hasta_pared(p, d)
		for e in horda.enemigos.duplicate():
			if e.activo() and _cerca_de_tramo(e, p, fin, ancho):
				golpear(e, a, d * 50.0)
				if not metralla_hecha:
					metralla_hecha = true
					soltar_metralla(a, e.position, d, e)
		trazo.append(to_local(fin))
		# Rebota en la pared que ha tocado.
		if absf(fin.x - sala.position.x) < 0.5 or absf(fin.x - sala.end.x) < 0.5:
			d.x = -d.x
		else:
			d.y = -d.y
		p = fin
	_dibujar_rayo(trazo, COLOR_LASER, 3.0 + ancho * 0.5, 0.22)


## Dónde choca con la pared de la sala un rayo que sale de p hacia d.
func _hasta_pared(p: Vector2, d: Vector2) -> Vector2:
	var sala := Sala.INTERIOR
	var tx := INF
	var ty := INF
	if d.x > 0.0001:
		tx = (sala.end.x - p.x) / d.x
	elif d.x < -0.0001:
		tx = (sala.position.x - p.x) / d.x
	if d.y > 0.0001:
		ty = (sala.end.y - p.y) / d.y
	elif d.y < -0.0001:
		ty = (sala.position.y - p.y) / d.y
	return p + d * maxf(minf(tx, ty), 0.0)


func _cerca_de_tramo(e: Enemigo, desde: Vector2, hasta: Vector2, ancho: float) -> bool:
	var punto := Geometry2D.get_closest_point_to_segment(e.position, desde, hasta)
	return punto.distance_to(e.position) <= ancho + e.radio


## Bala Trucada en el láser: de los enemigos cercanos, apunta al que deja más en fila.
func _mejor_linea(origen: Vector2, ancho: float) -> Vector2:
	var mejor := Vector2.ZERO
	var mejor_cuenta := -1
	for c in horda.mas_cercanos(origen, 6):
		var d: Vector2 = (c.position - origen).normalized()
		if d == Vector2.ZERO:
			continue
		var fin := _hasta_pared(origen, d)
		var cuenta := 0
		for e in horda.enemigos:
			if e.activo() and _cerca_de_tramo(e, origen, fin, ancho):
				cuenta += 1
		if cuenta > mejor_cuenta:
			mejor_cuenta = cuenta
			mejor = d
	return mejor if mejor != Vector2.ZERO else Vector2.RIGHT


# ------------------------------------------------------------ áreas
## A quién le cae la explosión. Con Bala Trucada, a los grupos más apretados.
func _objetivos_area(a: Dictionary, origen: Vector2) -> Array:
	var cuantos: int = a.n
	if int(a.get("busca", 0)) <= 0:
		return horda.mas_cercanos(origen, cuantos)
	var candidatos: Array = horda.mas_cercanos(origen, maxi(8, cuantos * 2))
	var vecinos := {}
	for e in candidatos:
		vecinos[e] = horda.en_radio(e.position, a.radio).size()
	candidatos.sort_custom(func(x, y): return vecinos[x] > vecinos[y])
	return candidatos.slice(0, cuantos)


## Una explosión con su sonido: la usan la dinamita y las fichas trampa.
func estallar(a: Dictionary, centro: Vector2) -> void:
	Sonido.tocar("explosion", randf_range(0.95, 1.2), -3.0)
	_explotar(a, centro)


func _explotar(a: Dictionary, centro: Vector2) -> void:
	var radio: float = float(a.radio) * _escala(a)
	for e in horda.en_radio(centro, radio):
		golpear(e, a, (e.position - centro).normalized() * 100.0)
	var fx := Sprite2D.new()
	fx.texture = _tex_explosion
	fx.hframes = 6
	fx.position = centro
	fx.scale = Vector2.ONE * (radio / 34.0)
	add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "frame", 5, 0.26)
	tw.tween_callback(fx.queue_free)
	explosion_hecha.emit()
	explosion_en.emit(centro, radio)
	soltar_metralla(a, centro, Vector2.ZERO)


func _lanzar_dinamita(a: Dictionary, origen: Vector2, objetivo: Enemigo) -> void:
	var d := Dinamita.new()
	d.texture = _tex_dinamita
	d.iniciar(a, origen, objetivo, self)
	add_child(d)


## Las fichas trampa se quedan junto a ti, un poco por detrás.
func _minar(a: Dictionary, origen: Vector2, hacia: Vector2) -> void:
	var zona := Sala.INTERIOR.grow(-6.0)
	for i in a.n:
		var lado: Vector2 = hacia.orthogonal() * ((i - (a.n - 1) * 0.5) * 14.0)
		var punto := origen - hacia * 6.0 + lado + Vector2(randf_range(-3, 3), randf_range(-3, 3))
		# Con demasiadas en el suelo, la más vieja revienta para dejar sitio.
		while _minas.size() >= TOPE_MINAS:
			var vieja = _minas.pop_front()
			if is_instance_valid(vieja):
				vieja.estallar()
		var m := Mina.new()
		m.texture = _tex_mina
		m.iniciar(a, punto.clamp(zona.position, zona.end), self)
		_minas.append(m)
		m.tree_exiting.connect(_olvidar_mina.bind(m))
		add_child(m)


func _olvidar_mina(m: Mina) -> void:
	_minas.erase(m)


# ------------------------------------------------------------ cuerpo a cuerpo
## La botella barre un arco hacia el enemigo más cercano; con Bala Trucada, a tu alrededor entero.
func _barrido(a: Dictionary, origen: Vector2, hacia: Vector2) -> void:
	var alcance: float = float(a.radio) * _escala(a)
	var completo := int(a.get("busca", 0)) > 0
	var primero: Enemigo = null
	for e in horda.en_radio(origen, alcance):
		var hacia_e: Vector2 = e.position - origen
		if completo or hacia_e.length() < 10.0 or absf(hacia.angle_to(hacia_e)) <= 1.35:
			var empujon: Vector2 = hacia_e.normalized() if hacia_e.length() > 0.5 else hacia
			golpear(e, a, empujon * 210.0)
			if primero == null:
				primero = e
	_dibujar_barrido(origen, hacia, alcance)
	if completo:
		_dibujar_barrido(origen, -hacia, alcance)
	if primero != null:
		soltar_metralla(a, primero.position, hacia, primero)


## El tajo del dibujo es un arco de radio 14.5 centrado en la celda y mirando a +X.
func _dibujar_barrido(origen: Vector2, hacia: Vector2, alcance: float) -> void:
	var fx := Sprite2D.new()
	fx.texture = _tex_barrido
	fx.hframes = 4
	fx.position = origen
	fx.rotation = hacia.angle()
	fx.scale = Vector2.ONE * (alcance / 14.5)
	add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "frame", 3, 0.15)
	tw.tween_callback(fx.queue_free)


func _cuchilla(a: Dictionary, angulo: float) -> void:
	var c := Cuchilla.new()
	c.texture = _tex_cuchilla
	c.iniciar(a, angulo, self)
	add_child(c)
