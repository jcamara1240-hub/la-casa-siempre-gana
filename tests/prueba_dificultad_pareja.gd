extends SceneTree
## Dificultad con pareja: enemigos más rápidos y agresivos, élites con doble daño; en solitario, igual.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_dificultad_pareja.gd

var _fallos := 0
var J: Node
var m


func _initialize() -> void:
	_correr.call_deferred()


func _ok(condicion: bool, que: String) -> void:
	print("bien: " if condicion else "MAL:  ", que)
	if not condicion:
		_fallos += 1


func _esperar(n: int) -> void:
	for i in n:
		await physics_frame


func _cerca(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _correr() -> void:
	J = root.get_node("Juego")
	DirAccess.remove_absolute("user://partida.sav")
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._pantalla.visible = false
	m._menu.cerrar()
	m._coop_cfg = {"personaje2": "tahur", "entrada1": -1, "entrada2": 1}
	m.empezar_partida("tahur", 0, false, false)
	await _esperar(3)
	var E: GDScript = load("res://scripts/enemigo.gd")
	var h = m._horda
	_ok(J.coop, "la partida es cooperativa")
	# Proporciones pareja / solitario.
	var vel_p: float = h.crear("dado", Vector2(300, 200)).vel
	var cad_p: float = E.cadencia()
	var bal_p: float = E.ritmo_balas()
	J.coop = false
	var vel_s: float = h.crear("dado", Vector2(300, 200)).vel
	var cad_s: float = E.cadencia()
	var bal_s: float = E.ritmo_balas()
	_ok(_cerca(vel_p / vel_s, 1.12), "velocidad x1,12 con pareja (%.3f)" % (vel_p / vel_s))
	_ok(_cerca(cad_p / cad_s, 0.8), "cadencia x0,8 con pareja (%.3f)" % (cad_p / cad_s))
	_ok(_cerca(bal_p / bal_s, 1.1), "balas x1,1 con pareja (%.3f)" % (bal_p / bal_s))
	var el_s = h.crear("dado", Vector2(300, 200))
	el_s.hacer_elite()
	_ok(el_s.dano_golpe() == 1, "en solitario el élite pega 1")
	_ok(not el_s.etiqueta().begins_with("x2 "), "en solitario sin x2 en la etiqueta")
	_ok(el_s.self_modulate == Color(1.0, 0.82, 0.4), "en solitario el élite sigue dorado")
	J.coop = true
	# Objetivos: cámara al lejano, dado al cercano.
	var j1 = m.jugador
	var j2 = m.jugador2
	j1.position = Vector2(100, 160)
	j2.position = Vector2(420, 160)
	var cam = h.crear("camara", Vector2(150, 160))
	var dado = h.crear("dado", Vector2(150, 160))
	_ok(cam._blanco(h) == j2, "la cámara apunta al lejano")
	_ok(dado._blanco(h) == j1, "el dado va al cercano")
	J.coop = false
	_ok(cam._blanco(h) == j1, "en solitario la cámara apunta al de siempre")
	J.coop = true
	# Élite: contacto quita 2, su bala lleva dano 2, etiqueta y color.
	h.limpiar()
	await _esperar(1)
	J.piso = 1
	j1.invulnerable = false
	j1._invulnerable_t = 0.0
	j1.position = Vector2(300, 200)
	j2.position = Vector2(100, 100)
	var el = h.crear("dado", Vector2(200, 60))
	el.hacer_rango(E.Rango.ELITE, [])
	el.nacer_ya()
	el.hace_contacto = true
	await _esperar(14)  # termina de nacer y la rejilla se rehace
	j1._invulnerable_t = 0.0
	el.aturdir(5.0)
	el.position = j1.position
	await _esperar(1)
	j1._invulnerable_t = 0.0
	_ok(el.dano_golpe() == 2, "élite con pareja: dano_golpe 2")
	_ok(el.etiqueta().begins_with("x2 "), "etiqueta empieza por x2")
	_ok(el.self_modulate == E.COLOR_ELITE_PAREJA, "color rojizo")
	_ok(int(h.ataques.causa_en(el.position).get("dano", 1)) == 2, "la bala del élite lleva dano 2")
	var antes: int = J.vida
	h._contacto_con(j1)
	_ok(antes - J.vida == 2, "el contacto del élite quita 2 (%d -> %d)" % [antes, J.vida])
	var normal = h.crear("dado", Vector2(300, 200))
	_ok(normal.dano_golpe() == 1, "un normal sigue quitando 1")
	h.limpiar()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
