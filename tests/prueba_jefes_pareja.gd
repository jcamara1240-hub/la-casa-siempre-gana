extends SceneTree
## Jefes en pareja: más ritmo, ataque extra al más lejano y furia con poca vida.

var _fallos := 0
var m


func _initialize() -> void:
	_correr.call_deferred()


func _ok(c: bool, que: String) -> void:
	print("bien: " if c else "MAL:  ", que)
	if not c:
		_fallos += 1


func _esperar(n: int) -> void:
	for i in n:
		await physics_frame


func _nueva(pareja: bool) -> void:
	if m != null:
		m.queue_free()
		await process_frame
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._pantalla.visible = false
	m._menu.cerrar()
	if pareja:
		m._coop_cfg = {"personaje2": "tahur", "entrada1": -1, "entrada2": 1}
	m.empezar_partida("tahur", 0, false, false)
	await _esperar(3)
	m._empezar_jefe()
	await _esperar(3)


func _correr() -> void:
	await _nueva(false)
	var h = m._horda
	var j = h.jefe
	var r_solo: float = j.ritmo()
	_ok(not root.get_node("/root/Juego").coop, "solitario: sin coop")
	_ok(not j.furioso() and j.dano_golpe() == 1, "solitario: no furioso, golpe 1")
	j._nacer = 0.0
	j.vida = 0.25 * j.vida_max
	var antes: int = h.enemigos.size()
	await _esperar(10)
	_ok(not j.furioso() and j.dano_golpe() == 1, "solitario con poca vida: sin furia")
	_ok(j._letrero_pareja == null, "solitario: sin letrero de pareja")
	_ok(h.enemigos.size() <= antes, "solitario: sin invocados")

	await _nueva(true)
	h = m._horda
	j = h.jefe
	var Juego = root.get_node("/root/Juego")
	_ok(Juego.coop and h.jugadores.size() == 2, "pareja: hay dos jugadores")
	j._nacer = 0.0
	var r_pareja: float = j.ritmo()
	_ok(absf(r_pareja / r_solo - 1.15) < 0.001, "ritmo en pareja = x1,15 (%.3f)" % (r_pareja / r_solo))
	_ok(not j.furioso() and j.dano_golpe() == 1, "pareja con vida llena: no furioso")
	# Abanico extra al J2 lejano.
	m.jugador.global_position = j.position + Vector2(20, 0)
	m.jugador2.global_position = j.position + Vector2(0, 150)
	var n0: int = h.ataques._balas_enemigas.size()
	j._ataque_pareja(h, 1)
	var nuevas: Array = h.ataques._balas_enemigas.slice(n0)
	_ok(nuevas.size() >= 5, "ataque de pareja suelta balas (%d)" % nuevas.size())
	var hacia := 0
	for b in nuevas:
		if b._vel.y > 40.0 and absf(b._vel.angle_to(Vector2.DOWN)) < 0.5:
			hacia += 1
	_ok(hacia >= 3, "el abanico va hacia el J2 lejano (%d balas)" % hacia)
	# Furia.
	j.vida = 0.25 * j.vida_max
	var e0: int = h.enemigos.size()
	await _esperar(5)
	_ok(j.furioso(), "con 25 % de vida se pone furioso")
	_ok(j.dano_golpe() == 2, "furioso: dano_golpe == 2")
	_ok(h.enemigos.size() >= e0 + 3, "salen los invocados (%d -> %d)" % [e0, h.enemigos.size()])
	_ok(j._letrero_pareja != null and j._letrero_pareja.text != "", "letrero de furia")
	var e1: int = h.enemigos.size()
	await _esperar(5)
	_ok(h.enemigos.size() <= e1 + 1, "la furia invoca una sola vez")
	await _propios()
	print("FALLOS ", _fallos)
	quit(1 if _fallos > 0 else 0)


func _zonas(h) -> int:
	var n := 0
	for c in h.ataques.get_children():
		if c.has_method("iniciar"):
			n += 1
	return n


## Ataque propio de Pez, Ruleta y Dueño: solo en pareja.
func _propios() -> void:
	for pareja in [false, true]:
		await _nueva(pareja)
		var h = m._horda
		for id in ["pez", "ruleta", "dueno"]:
			var j = load("res://scripts/jefe.gd").crear(id)
			m.add_child(j)
			j.preparar(1.0)
			j._nacer = 0.0
			j.position = Vector2(240, 135)
			m.jugador.global_position = j.position + Vector2(20, 0)
			if pareja:
				m.jugador2.global_position = j.position + Vector2(0, 110)
			j.vida = 0.25 * j.vida_max
			j.actualizar(0.02, h)  # arranca la furia si toca
			j._reloj_pareja = 0.0
			var z0 := _zonas(h)
			j.actualizar(0.02, h)
			var nuevas := _zonas(h) - z0
			if pareja:
				_ok(j._turno_pareja == 1 and nuevas > 0, "%s en pareja: ataque propio (%d zonas)" % [id, nuevas])
				_ok(j._rotulo_t > 0.0, "%s en pareja: rotulo de aviso" % id)
			else:
				_ok(j._turno_pareja == 0 and j._rotulo_t == 0.0, "%s solitario: sin ataque de pareja" % id)
			j.queue_free()
			for c in h.ataques.get_children():
				if c.has_method("iniciar"):
					c.queue_free()
