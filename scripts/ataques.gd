class_name Ataques
extends Node2D
## Convierte cada ataque del combo en balas, rayos, cuchillas y explosiones.

signal explosion_hecha

const VEL_BALA := 260.0

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


func limpiar() -> void:
	for h in get_children():
		h.queue_free()


func lanzar(a: Dictionary) -> void:
	var origen := jugador.global_position
	var objetivo: Array = horda.mas_cercanos(origen, 1)
	if objetivo.is_empty():
		return
	var hacia: Vector2 = (objetivo[0].position - origen).normalized()
	match String(a.id):
		"rayo": Sonido.tocar("rayo")
		"explosion", "molotov", "lluvia", "jackpot": Sonido.tocar("explosion", randf_range(0.9, 1.15), -3.0)
		_: Sonido.tocar("carta", randf_range(0.95, 1.2))
	match String(a.id):
		"bala", "dados", "bola", "as_picas":
			_abanico(a, origen, hacia, 0.16, 1.1)
		"reparto":
			_abanico(a, origen, hacia, 0.05, 0.9)
		"abanico":
			_abanico(a, origen, hacia, 0.3, 0.55)
		"boomerang":
			_abanico(a, origen, hacia, 0.25, 1.0)
		"nova":
			for i in a.n:
				_bala(a, origen, Vector2.RIGHT.rotated(TAU * i / a.n + hacia.angle()), 0.7)
		"rayo":
			_rayo(a, origen)
		"explosion", "molotov", "lluvia", "jackpot":
			for e in horda.mas_cercanos(origen, a.n):
				_explotar(a, e.position)
		"cuchilla":
			for i in a.n:
				_cuchilla(a, TAU * i / a.n)


func _abanico(a: Dictionary, origen: Vector2, hacia: Vector2, apertura: float, vida: float) -> void:
	for i in a.n:
		var desvio: float = (i - (a.n - 1) * 0.5) * apertura
		_bala(a, origen, hacia.rotated(desvio), vida)


func _bala(a: Dictionary, origen: Vector2, direccion: Vector2, vida: float) -> void:
	var p := Proyectil.new()
	p.texture = _tex_bala
	p.position = origen
	p.iniciar_jugador(direccion * VEL_BALA, a, vida, self)
	add_child(p)


func bala_enemiga(origen: Vector2, velocidad: Vector2, clase := "moneda") -> void:
	var p := Proyectil.new()
	p.texture = _tex_enemigas[clase]
	p.position = origen
	p.iniciar_enemigo(velocidad * (1.0 - Juego.stat("bala_lenta")), self)
	Sonido.tocar("disparo", randf_range(0.8, 1.1), -9.0)
	add_child(p)


func golpear(e: Enemigo, a: Dictionary, retroceso: Vector2) -> void:
	var dano: float = a.dano
	if a.azar:
		# Un dado: entre la cuarta parte y casi el doble de lo apuntado.
		dano *= float(randi_range(1, 7)) / 4.0
	var color := Color8(247, 236, 210)
	if randf() < float(a.crit) + Juego.stat("crit"):
		dano *= 2.0 + Juego.stat("crit_mult")
		color = Color8(247, 198, 74)
	if a.oro > 0:
		e.oro_prob = 1.0
	horda.danar(e, dano, retroceso, color)
	if a.quema > 0:
		e.aplicar_quemadura(max(1.0, a.dano * 0.4) * a.quema)
	if a.frio > 0:
		e.aplicar_frio()


func _rayo(a: Dictionary, origen: Vector2) -> void:
	var vistos := {}
	var punto := origen
	var trazo := PackedVector2Array([to_local(origen)])
	for _i in a.n:
		var lista: Array = horda.mas_cercanos(punto, 1, vistos)
		if lista.is_empty():
			break
		var e: Enemigo = lista[0]
		if e.position.distance_to(punto) > 170.0:
			break
		vistos[e] = true
		var medio := (punto + e.position) * 0.5 + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		trazo.append(to_local(medio))
		trazo.append(to_local(e.position))
		golpear(e, a, Vector2.ZERO)
		punto = e.position
	if trazo.size() > 1:
		_dibujar_rayo(trazo)


func _dibujar_rayo(trazo: PackedVector2Array) -> void:
	var linea := Line2D.new()
	linea.points = trazo
	linea.width = 2.0
	linea.default_color = Color8(247, 198, 74)
	add_child(linea)
	var nucleo := Line2D.new()
	nucleo.points = trazo
	nucleo.width = 1.0
	nucleo.default_color = Color8(247, 236, 210)
	linea.add_child(nucleo)
	var tw := linea.create_tween()
	tw.tween_property(linea, "modulate:a", 0.0, 0.16)
	tw.tween_callback(linea.queue_free)


func _explotar(a: Dictionary, centro: Vector2) -> void:
	for e in horda.en_radio(centro, a.radio):
		golpear(e, a, (e.position - centro).normalized() * 90.0)
	var fx := Sprite2D.new()
	fx.texture = _tex_explosion
	fx.hframes = 6
	fx.position = centro
	fx.scale = Vector2.ONE * (a.radio / 34.0)
	add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "frame", 5, 0.26)
	tw.tween_callback(fx.queue_free)
	explosion_hecha.emit()


func _cuchilla(a: Dictionary, angulo: float) -> void:
	var c := Cuchilla.new()
	c.texture = _tex_cuchilla
	c.iniciar(a, angulo, self)
	add_child(c)
