extends SceneTree
## Enemigos raros y élites: probabilidades, modificadores, botín, logros y determinismo.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_rangos.gd

const NORMAL := 0  # Enemigo.Rango
const RARO := 1
const ELITE := 2
const CORAZON := 1  # Recogible.Clase
const CARTA := 2

var _fallos := 0


func _ok(cond: bool, texto: String) -> void:
	print(("bien: " if cond else "MAL: ") + texto)
	if not cond:
		_fallos += 1


func _initialize() -> void:
	_correr.call_deferred()


func _esperar(n: int) -> void:
	for _i in n:
		await physics_frame


func _correr() -> void:
	var J: Node = root.get_node("Juego")
	var E = load("res://scripts/enemigo.gd")
	var P = load("res://scripts/progreso.gd")
	var I = load("res://scripts/idioma.gd")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._menu.cerrar()
	m.empezar_partida("tahur", 0)
	await _esperar(3)
	var horda = m._horda
	var yo = m.jugador
	yo.invulnerable = true
	m._motor.activo = false  # que tus cartas no maten a los de la prueba

	# ---- probabilidades: los raros más que los élites, y suben con piso, mesa e infinito
	var base: Vector2 = E.prob_rangos(1, 0, 0)
	_ok(base.x > base.y and base.y > 0.0, "piso 1: los raros salen más que los élites")
	var piso4: Vector2 = E.prob_rangos(4, 0, 0)
	var mesa3: Vector2 = E.prob_rangos(1, 3, 0)
	var infinito: Vector2 = E.prob_rangos(5, 0, 3)
	_ok(piso4.x > base.x and piso4.y > base.y, "suben con el piso")
	_ok(mesa3.x > base.x and mesa3.y > base.y, "suben con la mesa de dificultad")
	_ok(infinito.x > E.prob_rangos(5, 0, 0).x and infinito.y > E.prob_rangos(5, 0, 0).y, "suben con los pisos infinitos")
	var tope: Vector2 = E.prob_rangos(40, 4, 30, 3.0)
	_ok(tope.x <= E.PROB_RARO_MAX and tope.y <= E.PROB_ELITE_MAX and tope.x + tope.y < 1.0, "tienen tope")
	_ok(is_equal_approx(E.prob_rangos(2, 0, 0, 2.0).y, E.prob_rangos(2, 0, 0).y * 2.0), "la SALA VIP las multiplica")

	# ---- tiradas: deterministas, con un modificador el raro y dos distintos el élite
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 1234
	b.seed = 1234
	var iguales := true
	var raros := 0
	var elites := 0
	var mods_bien := true
	var prob: Vector2 = E.prob_rangos(3, 1, 0)
	for i in 2000:
		var tipo: String = ["ficha", "dado", "maton", "botones", "joker", "camara"][i % 6]
		var x: Array = E.tirar_rango(a, tipo, prob)
		var y: Array = E.tirar_rango(b, tipo, prob)
		if x != y:
			iguales = false
		match int(x[0]):
			RARO:
				raros += 1
				mods_bien = mods_bien and x[1].size() == 1
			ELITE:
				elites += 1
				mods_bien = mods_bien and x[1].size() == 2 and x[1][0] != x[1][1]
			NORMAL:
				mods_bien = mods_bien and x[1].is_empty()
		for mod in x[1]:
			mods_bien = mods_bien and E.mods_validos(tipo).has(mod)
	_ok(iguales, "con la misma semilla salen los mismos rangos y modificadores")
	_ok(raros > elites and elites > 0, "en la práctica también: %d raros, %d élites de 2000" % [raros, elites])
	_ok(absf(raros / 2000.0 - prob.x) < 0.04 and absf(elites / 2000.0 - prob.y) < 0.03, "y en la proporción pedida")
	_ok(mods_bien, "raro con un modificador, élite con dos distintos, y siempre válidos para su tipo")
	var sin_elite := true
	for i in 300:
		if int(E.tirar_rango(a, "ficha", Vector2(0.3, 0.6), true, false)[0]) == ELITE:
			sin_elite = false
	_ok(sin_elite, "al principio del piso 1 no salen élites")
	_ok(not E.mods_validos("joker").has("salto") and not E.mods_validos("camara").has("veloz")
		and not E.mods_validos("dado_bomba").has("explosivo") and not E.mods_validos("ficha_oro").has("divisor"),
		"no se dan modificadores sin sentido (bufón que ya salta, cámara quieta...)")

	# ---- la oleada entera sale igual con la misma semilla (reto diario)
	# Los rangos se deciden al planear la sala, con el azar de la sala.
	J.piso = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var oleadas_1: Array = m._planificar_oleadas(rng)
	var rangos_1: Array = m._elites.duplicate(true)
	rng.seed = 777
	var oleadas_2: Array = m._planificar_oleadas(rng)
	var rangos_2: Array = m._elites.duplicate(true)
	_ok(oleadas_1 == oleadas_2 and rangos_1 == rangos_2 and not oleadas_1.is_empty(), "la misma semilla da las mismas oleadas con los mismos rangos")
	var hubo_rango := false
	for semilla in 20:
		rng.seed = semilla
		m._planificar_oleadas(rng)
		for oleada in m._elites:
			for r in oleada:
				if int(r[0]) > 0:
					hubo_rango = true
	m._por_nacer.clear()
	m._soltar_oleada(oleadas_1[0], rangos_1[0])
	var nacen: Array = m._por_nacer.map(func(p): return [p[4], p[5]])
	m._por_nacer.clear()
	_ok(nacen == rangos_1[0].slice(0, nacen.size()), "la oleada nace con los rangos que traía el plan")
	_ok(hubo_rango, "y en el piso 3 trae algún raro o élite")

	# ---- un raro
	var raro = horda.crear("ficha", Sala.CENTRO + Vector2(100, 0), 1.0)
	var vida_normal: float = raro.vida
	raro.hacer_rango(RARO, ["veloz"])
	_ok(is_equal_approx(raro.vida, vida_normal * E.VIDA_RARO) and raro.rango == RARO and not raro.elite, "el raro aguanta más")
	_ok(raro.material != null and raro.material == E.material_rango(RARO), "lleva el contorno de su rango (material compartido)")
	_ok(raro.etiqueta() == "VELOZ" and raro.monedas_al_morir >= 1, "su etiqueta es el modificador, y suelta algo más")
	var lento = horda.crear("ficha", Sala.CENTRO + Vector2(120, 0), 1.0)
	_ok(is_equal_approx(raro.vel, lento.vel * E.VELOZ), "Veloz: corre más")

	# ---- un élite: nombre propio y dos modificadores
	var elite = horda.crear("ficha", Sala.CENTRO + Vector2(-100, 0), 1.0)
	elite.hacer_rango(ELITE, ["blindado", "veloz"])
	_ok(elite.elite and elite.rango == ELITE and elite.mods.size() == 2, "el élite sigue siendo élite y lleva dos modificadores")
	_ok(elite.nombre_rango == "Ficha Blindada y Veloz", "nombre propio con el género bien: " + elite.nombre_rango)
	_ok(elite.monedas_al_morir >= 4 and elite.oro_prob >= 1.0, "botín garantizado de monedas")
	_ok(E.nombre_de("maton", ["escudo", "rastro"]) == "Matón Escudado y Ardiente", "y en masculino")
	I.actual = "en"
	_ok(E.nombre_de("ficha", ["blindado", "veloz"]) == "Armored Swift Chip", "y en inglés")
	I.actual = "es"
	_ok(elite.etiqueta() == "FICHA BLINDADA Y VELOZ", "al aparecer enseña su nombre")
	elite._t = 10.0
	_ok(elite.etiqueta() == "BLINDADO+VELOZ", "y luego sus dos modificadores")
	var traducido := true
	for mod in E.MODS:
		for clave in ["corto", "m", "f"]:
			traducido = traducido and I.EN.has(E.MODS[mod][clave])
	for tipo in E.NOMBRES_RANGO:
		traducido = traducido and I.EN.has(E.NOMBRES_RANGO[tipo][0])
	_ok(traducido, "modificadores y nombres tienen traducción")

	# ---- blindado y escudo
	_ok(is_equal_approx(elite.reducir_dano(10.0, Vector2.ZERO), 10.0 * E.BLINDAJE), "Blindado: el primer golpe apenas entra")
	_ok(is_equal_approx(elite.reducir_dano(10.0, Vector2.ZERO), 10.0) and not elite.blindado(), "el segundo, entero")
	var escudo = horda.crear("maton", Sala.CENTRO + Vector2(0, 60), 1.0)
	escudo.hacer_rango(RARO, ["escudo"])
	escudo._mirando = Vector2.RIGHT  # mira hacia la derecha: de frente le llegan golpes que empujan a la izquierda
	_ok(is_equal_approx(escudo.reducir_dano(10.0, Vector2.LEFT * 50.0), 10.0 * E.ESCUDO_FRENTE), "Escudo: de frente entra poco")
	_ok(is_equal_approx(escudo.reducir_dano(10.0, Vector2.RIGHT * 50.0), 10.0), "por la espalda, entero")
	var antes: float = escudo.vida
	horda.danar(escudo, 10.0, Vector2.LEFT * 50.0)
	_ok(is_equal_approx(antes - escudo.vida, 10.0 * E.ESCUDO_FRENTE), "y la horda aplica la reducción al dañar")

	# ---- vampírico: cura a los de al lado
	var herido = horda.crear("sota", Sala.CENTRO + Vector2(-40, 60), 1.0)
	var vampiro = horda.crear("sota", Sala.CENTRO + Vector2(-30, 60), 1.0)
	vampiro.hacer_rango(RARO, ["vampirico"])
	herido.vida = herido.vida_max * 0.3
	var vida_herido: float = herido.vida
	await _esperar(int(E.VAMPIRO_SEG * 60.0) + 30)
	_ok(herido.vida > vida_herido, "Vampírico: cura a los que tiene cerca")

	# ---- divisor y explosivo, al morir
	var viejos: Array = horda.enemigos.duplicate()
	horda.crear("ficha", Sala.CENTRO + Vector2(200, 80), 1.0)  # que la sala no se quede vacía y acabe la pelea
	for e in viejos:
		e.muerto = true
	await _esperar(2)
	var divisor = horda.crear("sota", Sala.CENTRO + Vector2(-150, -40), 1.0)
	divisor.hacer_rango(RARO, ["divisor"])
	divisor._nacer = 0.0
	var cuantos: int = horda.enemigos.size()
	var vida_divisor: float = divisor.vida_max
	divisor.muerto = true
	await _esperar(1)
	var mitades: Array = horda.enemigos.filter(func(e): return e.tipo == "sota")
	_ok(horda.enemigos.size() == cuantos + 1 and mitades.size() == 2, "Divisor: se parte en dos")
	_ok(mitades.all(func(e): return e.rango == NORMAL and is_equal_approx(e.vida_max, vida_divisor * E.DIVISOR_VIDA)), "dos pequeños, sin rango y con menos vida")
	var zonas_antes: int = m._ataques.get_children().filter(func(n): return n.get_script() == load("res://scripts/zona_peligro.gd")).size()
	var bomba = horda.crear("dado", Sala.CENTRO + Vector2(-150, 40), 1.0)
	bomba.hacer_rango(RARO, ["explosivo"])
	bomba._nacer = 0.0
	bomba.muerto = true
	await _esperar(1)
	var zonas: int = m._ataques.get_children().filter(func(n): return n.get_script() == load("res://scripts/zona_peligro.gd")).size()
	_ok(zonas > zonas_antes, "Explosivo: al morir deja una explosión que avisa")
	var ardiente = horda.crear("ficha", Sala.CENTRO + Vector2(150, -60), 1.0)
	ardiente.hacer_rango(RARO, ["rastro"])
	await _esperar(70)
	var zonas_rastro: int = m._ataques.get_children().filter(func(n): return n.get_script() == load("res://scripts/zona_peligro.gd")).size()
	_ok(zonas_rastro > zonas, "Ardiente: deja fuego por donde pasa")
	var saltarin = horda.crear("ficha", Sala.CENTRO + Vector2(-200, -60), 1.0)
	saltarin.hacer_rango(RARO, ["salto"])
	saltarin._nacer = 0.0
	saltarin._salto_t = 0.01
	var desde: Vector2 = saltarin.position
	await _esperar(3)
	_ok(saltarin.position.distance_to(desde) > 20.0, "Esquivo: se teletransporta un trecho")

	# ---- botín y logros del élite
	P.logros.erase("elite_limpio")
	P.contadores.erase("raros")
	var raro_muerto = horda.crear("ficha", Sala.CENTRO, 1.0)
	raro_muerto.hacer_rango(RARO, ["veloz"])
	m._al_morir_rango(raro_muerto)
	_ok(int(P.contadores.get("raros", 0)) == 1, "los raros se cuentan para su logro")
	P.contadores["raros"] = 50
	J.revisar_logros()
	_ok(P.logros.has("cazador_raros"), "50 raros: logro Cazarrarezas")
	var sucio = horda.crear("ficha", Sala.CENTRO, 1.0)
	sucio.hacer_rango(ELITE, ["veloz", "escudo"])
	sucio.golpes_al_nacer = m._golpes_sala - 1  # te dio antes de morir
	m._al_morir_rango(sucio)
	_ok(not P.logros.has("elite_limpio"), "matar un élite que te ha dado no cuenta")
	var limpio = horda.crear("ficha", Sala.CENTRO, 1.0)
	limpio.hacer_rango(ELITE, ["veloz", "escudo"])
	limpio.golpes_al_nacer = m._golpes_sala
	m._al_morir_rango(limpio)
	_ok(P.logros.has("elite_limpio"), "matarlo sin recibir daño: logro Trato VIP")
	for r in m._recogibles.get_children():
		r.free()
	J.azar.seed = 99
	for i in 40:
		var e = E.new()  # fuera de la horda: solo hace falta para el botín
		e.position = Sala.CENTRO + Vector2(i * 3, 0)
		e.configurar("ficha", 1.0)
		e.hacer_rango(ELITE, ["veloz", "escudo"])
		m._al_morir_rango(e)
		e.free()
	await process_frame
	var clases: Array = m._recogibles.get_children().map(func(r): return r.clase)
	_ok(clases.has(CARTA) and clases.has(CORAZON), "los élites sueltan a veces carta y a veces corazón")
	var proporcion: float = clases.size() / 40.0
	_ok(proporcion > 0.3 and proporcion < 0.75, "más o menos la mitad de las veces (%d de 40)" % clases.size())
	for r in m._recogibles.get_children():
		r.free()
	# El corazón cura medio y, con la vida llena, se queda en el suelo.
	J.vida = J.vida_max - 2
	var corazon = m._crear_recogible(CORAZON, "res://assets/objetos/corazon.png", yo.position + Vector2(150, 0))
	await process_frame
	m.recogido(corazon)
	_ok(J.vida == J.vida_max - 1 and corazon.is_queued_for_deletion(), "el corazón del élite cura medio")
	var otro = m._crear_recogible(CORAZON, "res://assets/objetos/corazon.png", yo.position + Vector2(-150, 0))
	await process_frame
	J.vida = J.vida_max
	m.recogido(otro)
	_ok(not otro.is_queued_for_deletion(), "con la vida llena no se gasta")
	otro.free()

	# ---- los camareros salen con uno de tres uniformes, siempre el mismo en el mismo sitio
	var uniformes := {}
	var mismo := true
	for i in 30:
		var p := Sala.CENTRO + Vector2(i * 7 - 100, (i % 5) * 11 - 20)
		var c1 = horda.crear("botones", p, 1.0)
		var c2 = horda.crear("botones", p, 1.0)
		uniformes[c1.texture.resource_path] = true
		mismo = mismo and c1.texture == c2.texture
		c1.muerto = true
		c2.muerto = true
	_ok(uniformes.size() == 3, "tres uniformes de camarero: %s" % str(uniformes.keys()))
	_ok(mismo, "el uniforme sale del sitio de nacimiento (no gasta azar)")

	# ---- rendimiento: una horda de 70 con un tercio de raros y élites no se atasca
	for e in horda.enemigos:
		e.muerto = true
	await _esperar(2)
	J.azar.seed = 5
	for i in 70:
		var e = horda.crear(["ficha", "dado", "sota", "botones", "maton"][i % 5], Sala.CENTRO + Vector2((i % 10) * 30 - 150, (i / 10) * 25 - 80), 1.0)
		if i % 3 == 0:
			var t: Array = E.tirar_rango(J.azar, e.tipo, Vector2(0.5, 0.5))
			e.hacer_rango(maxi(int(t[0]), RARO), t[1] if not t[1].is_empty() else ["veloz"])
	var reloj := Time.get_ticks_usec()
	await _esperar(60)
	var ms := (Time.get_ticks_usec() - reloj) / 1000.0 / 60.0
	print("  fotograma medio con 70 enemigos (23 con rango): %.2f ms" % ms)
	_ok(ms < 16.0, "la horda con rangos cabe de sobra en un fotograma")

	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)
