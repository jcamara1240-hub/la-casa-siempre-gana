extends SceneTree
## Voltereta, órdago, mesas volcables, fiebre y los enemigos nuevos.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_mecanicas.gd

const NORMAL := 1  # GeneradorMazmorra.Tipo.NORMAL
const DE_PIE := 0  # Mesa.Estado
const VOLCADA := 1
const ROTA := 2

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
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._menu.cerrar()
	m.empezar_partida("tahur", 0)
	await _esperar(3)

	# ---- contexto del combo y guardado
	var ctx: Dictionary = J.contexto_combo()
	_ok(ctx.has("fiebre") and ctx.has("voltereta") and ctx.has("ordagos"), "el contexto del combo trae fiebre, voltereta y órdagos")
	_ok(J.ordagos == 2, "se empieza con dos órdagos")
	J.ordagos = 5
	var datos: Dictionary = J.volcar()
	J.ordagos = 0
	J.restaurar(datos)
	_ok(J.ordagos == 5, "los órdagos se guardan con la partida")
	J.ordagos = 0
	J.rellenar_ordagos()
	_ok(J.ordagos == 2, "al bajar de piso se rellenan hasta dos")
	if load("res://scripts/objetos_db.gd").OBJETOS.has("petaca"):
		J.dar_objeto("petaca")
		_ok(J.ordagos == 3, "la Petaca da un órdago al momento")
		J.ordagos = 0
		J.rellenar_ordagos()
		_ok(J.ordagos == 3, "y otro más en cada piso")

	# ---- fiebre
	J.vaciar_fiebre()
	var lento: float = m._motor._duracion_ciclo()
	J.subir_fiebre(3.0)
	_ok(J.nivel_fiebre() == 3, "la fiebre llega al nivel 3 y no pasa de ahí")
	_ok(m._motor._duracion_ciclo() < lento * 0.8, "con fiebre el ciclo de cartas va más rápido")
	J.enfriar_fiebre(1.0)
	_ok(J.nivel_fiebre() == 3, "la fiebre no baja enseguida")
	J.enfriar_fiebre(5.0)
	_ok(J.fiebre < 3.0, "si pasas un rato sin matar, baja")
	J.subir_fiebre(2.0)
	m.jugador.recibir_golpe(1)
	_ok(J.fiebre == 0.0, "un golpe la vacía")
	_ok(m._jugo._parada > 0.0, "recibir un golpe para el tiempo un instante")
	m._jugo.limpiar()  # que la parada no alargue lo que viene

	# ---- voltereta
	m.jugador._invulnerable_t = 0.0
	m.jugador.pedir_voltereta()
	await _esperar(2)
	_ok(m.jugador.rodando(), "la voltereta empieza")
	var vida_antes: int = J.vida
	m.jugador.recibir_golpe(1)
	_ok(J.vida == vida_antes, "rodando no te hacen daño")
	_ok(J.contexto_combo().voltereta, "las cartas saben que acabas de rodar")
	await _esperar(22)
	_ok(not m.jugador.rodando(), "la voltereta se acaba sola")
	_ok(not m.jugador.voltereta_lista(), "y hay que esperar un poco para la siguiente")
	await _esperar(40)
	_ok(m.jugador.voltereta_lista(), "luego se puede volver a rodar")

	# ---- mesas (en una sala de prueba, sin pasar por main)
	var sala = m._sala
	var semilla := -1
	for s in 300:
		sala.construir({"pos": Vector2i(50, 50), "tipo": NORMAL, "semilla": s}, {})
		if not sala.mesas.is_empty():
			semilla = s
			break
	_ok(semilla >= 0, "hay salas normales con mesas")
	if semilla >= 0:
		var donde: Vector2 = sala.mesas[0].centro
		sala.construir({"pos": Vector2i(50, 50), "tipo": NORMAL, "semilla": semilla}, {})
		_ok(sala.mesas[0].centro == donde, "la misma sala pone las mesas en el mismo sitio")
		var mesa = sala.mesas[0]
		var dentro: Vector2 = mesa.caja.get_center()
		_ok(not mesa.caja.grow(5.9).has_point(sala.sacar_de_mesas(dentro, 6.0)), "una mesa no deja que la atravieses")
		_ok(not sala.bloquea_bala(dentro), "de pie no para balas")
		var abajo: Vector2 = dentro + Vector2(0, mesa.caja.size.y * 0.5 + 6.0)
		_ok(sala.volcar_cerca(abajo, 8.0, null), "con E al lado se vuelca")
		_ok(mesa.estado == VOLCADA and mesa.direccion == Vector2.UP, "cae hacia el lado contrario al tuyo")
		var paradas := 0
		while paradas < 100 and sala.bloquea_bala(mesa.caja.get_center()):
			paradas += 1
		_ok(paradas == 6 and mesa.estado == ROTA, "volcada para seis balas y se rompe")
		_ok(not sala.bloquea_bala(mesa.caja.get_center()), "rota ya no para nada")
		_ok(sala.cajas_mesas.size() == sala.mesas.size() - 1, "rota ya no estorba")
		var guardadas: Array = sala._datos.get("mesas", [])
		_ok(not guardadas.is_empty() and int(guardadas[0][0]) == ROTA, "la sala recuerda cómo quedaron sus mesas")
	m.entrar_sala(m.actual.pos, Vector2i.ZERO)  # vuelve a montar la sala de verdad
	await _esperar(2)
	_ok(not m._sala.bloquea_bala(Sala.CENTRO), "sin mesas volcadas las balas pasan")

	# ---- roce: una bala que pasa muy cerca sin rodar da fiebre (una vez por bala)
	var P = load("res://scripts/progreso.gd")
	var yo = m.jugador
	J.vida = J.vida_max
	yo.invulnerable = false
	yo._invulnerable_t = 0.0
	yo.position = Sala.CENTRO
	yo.velocity = Vector2.ZERO
	await _esperar(30)  # que acabe cualquier voltereta pendiente
	J.vaciar_fiebre()
	var roces_antes := int(P.contadores.get("roces", 0))
	var vida_roce: int = J.vida
	var avisos := [0]
	yo.roce.connect(func(_p): avisos[0] += 1)
	m._ataques.bala_enemiga(yo.global_position + Vector2(-90, 12), Vector2(260, 0), "moneda")
	await _esperar(50)
	_ok(J.vida == vida_roce, "la bala del roce no te toca")
	_ok(avisos[0] == 1 and int(P.contadores.get("roces", 0)) == roces_antes + 1, "una bala que pasa rozando cuenta como roce, una sola vez")
	_ok(is_equal_approx(J.fiebre, J.FIEBRE_POR_ROCE), "el roce da fiebre")
	m._ataques.bala_enemiga(yo.global_position + Vector2(-90, 40), Vector2(260, 0), "moneda")
	await _esperar(50)
	_ok(avisos[0] == 1, "una bala lejana no es un roce")
	yo.pedir_voltereta()
	await _esperar(1)
	m._ataques.bala_enemiga(yo.global_position + Vector2(-14, 12), Vector2(260, 0), "moneda")
	await _esperar(40)
	_ok(avisos[0] == 1, "rodando no hay roce (eso ya es ¡por los pelos!)")
	yo.position = Sala.CENTRO
	await _esperar(30)

	# ---- al límite
	J.vida = J.vida_max
	_ok(not J.al_limite() and is_equal_approx(J.factor_velocidad(), 1.0), "con vida de sobra no estás al límite")
	J.vida = 2
	_ok(J.al_limite() and J.factor_velocidad() > 1.05, "con un corazón estás al límite y corres más")
	J.vaciar_fiebre()
	J.subir_fiebre(J.FIEBRE_POR_BAJA)
	_ok(J.fiebre > J.FIEBRE_POR_BAJA * 1.2, "al límite la fiebre sube más deprisa")
	J.extremo = true
	_ok(not J.al_limite(), "en extremo no cuenta como al límite")
	J.extremo = false
	J.vida = J.vida_max
	J.vaciar_fiebre()

	# ---- desatado: aguantar la fiebre al máximo suelta el frenesí
	var cambios: Array = []
	J.desatado_cambiado.connect(func(a): cambios.append(a))
	var ciclo_max: float = 0.0
	J.en_combate = true
	J.subir_fiebre(3.0)
	ciclo_max = m._motor._duracion_ciclo()
	_ok(not J.desatado, "al llegar al máximo aún no se desata")
	await _esperar(int(J.DESATADO_CARGA * 60.0) + 6)
	_ok(J.desatado and cambios == [true], "aguantando la fiebre al máximo se desata (y lo avisa)")
	_ok(J.desatado_resto() > 0.8 and J.desatado_resto() <= 1.0, "desatado_resto empieza casi lleno")
	_ok(m._motor._duracion_ciclo() < ciclo_max * 0.8, "desatado, las cartas van aún más rápido")
	_ok(J.factor_velocidad() > 1.1, "desatado, el jugador corre más")
	_ok(J.intensidad() >= 0.85 and J.intensidad() <= 1.0, "desatado, la intensidad está casi al máximo")
	await _esperar(30)
	var resto: float = J.desatado_resto()
	J.alargar_desatado()
	_ok(J.desatado_resto() > resto, "cada baja lo alarga")
	J._desatado_t = 0.05
	await _esperar(6)
	_ok(not J.desatado and J.nivel_fiebre() == 2 and cambios == [true, false], "al acabar, la fiebre baja un escalón")
	J.subir_fiebre(3.0)
	await _esperar(int(J.DESATADO_CARGA * 60.0) + 6)
	_ok(J.desatado, "se puede volver a desatar")
	yo._invulnerable_t = 0.0
	yo.recibir_golpe(1)
	_ok(not J.desatado and J.fiebre == 0.0, "un golpe corta el desatado")
	m._jugo.limpiar()
	J.en_combate = false
	J.vida = J.vida_max
	_ok(J.intensidad() < 0.5, "sin pelea ni fiebre la intensidad es baja")

	# ---- remate: cada baja recorta la espera de la voltereta
	yo._enfriamiento = 0.3
	m._al_morir_enemigo(Sala.CENTRO + Vector2(40, 0), 0.0, "ficha", 0)
	_ok(yo._enfriamiento < 0.3 - 0.05, "una baja acerca la siguiente voltereta")
	_ok(m._jugo._parada <= 0.0, "una baja normal no para el tiempo")
	m._al_morir_enemigo(Sala.CENTRO + Vector2(40, 0), 0.0, "ficha", 0, true)
	_ok(m._jugo._parada > 0.0, "una élite sí, un instante")
	m._jugo.limpiar()

	# ---- jefes con más ritmo (y más aún enfadados), salvo cuando están vendidos
	var JefeS = load("res://scripts/jefe.gd")
	var pez = JefeS.crear("pez")
	pez.preparar(1.0)
	var ritmo_calmado: float = pez.ritmo()
	pez.vida = pez.vida_max * 0.4
	_ok(ritmo_calmado > 1.1 and pez.ritmo() > ritmo_calmado, "los jefes van más rápido, y enfadados aún más")
	var bj = JefeS.crear("blackjack")
	bj.preparar(1.0)
	bj._estado = 1  # Estado.ATURDIDO: pasado de 21
	_ok(is_equal_approx(bj.ritmo(), 1.0), "el rato en que el jefe está vendido no se acorta")
	pez.free()
	bj.free()

	# ---- nacimientos: tope de enemigos, y en extremo nacen más lejos
	m._por_nacer.clear()
	var muchos: Array = []
	for i in 200:
		muchos.append("ficha")
	m._soltar_oleada(muchos)
	_ok(m._por_nacer.size() == m.MAX_ENEMIGOS, "nunca hay más de MAX_ENEMIGOS entre vivos y por nacer")
	m._por_nacer.clear()
	yo.position = Sala.CENTRO
	J.extremo = true
	var lejos_extremo := true
	for i in 60:
		if m._punto_de_nacimiento(J.azar).distance_to(yo.position) < m.NACER_CERCA_EXTREMO - 0.5:
			lejos_extremo = false
	J.extremo = false
	_ok(lejos_extremo, "en extremo nacen más lejos (un golpe mata)")
	J.en_combate = true
	var con_pelea: float = J.intensidad()
	J.en_combate = false
	_ok(con_pelea > J.intensidad(), "la intensidad sube cuando hay pelea")

	# ---- oleadas con aviso y propina por rapidez
	yo.invulnerable = true
	var normales: Array = []
	for c in m.salas:
		if m.salas[c].tipo == NORMAL and not m.salas[c].limpia:
			normales.append(c)
	_ok(normales.size() >= 2, "hay salas normales para probar la propina")
	if normales.size() >= 2:
		m.entrar_sala(normales[0], Vector2i.ZERO)
		await _esperar(6)
		_ok(m.en_combate and J.en_combate, "al cerrarse la sala, Juego sabe que hay pelea")
		_ok(m._por_nacer.size() > 0 and m._horda.enemigos.is_empty(), "la oleada primero se avisa en el suelo")
		_ok(m._crono.visible and m._propina_t > 0.0, "corre el reloj de la propina")
		await _esperar(int((m.AVISO_NACER + m.AVISO_PRIMERA) * 60.0) + 10)
		_ok(m._horda.enemigos.size() > 0, "tras el aviso, nacen")
		var cerca := true
		for e in m._horda.enemigos:
			var d: float = e.position.distance_to(yo.position)
			if d < m.NACER_CERCA - 12.0 or d > m.NACER_LEJOS + 12.0:
				cerca = false
		_ok(cerca, "nacen cerca del jugador, pero no encima")
		var propinas := int(P.contadores.get("propinas", 0))
		var oro_antes: int = J.oro
		yo.position = Sala.CENTRO + Vector2(0, 90)  # lejos de la carta que pueda soltar
		m._oleadas.clear()
		m._por_nacer.clear()
		for e in m._horda.enemigos:
			e.muerto = true
		await _esperar(3)
		_ok(not m.en_combate and not J.en_combate, "sala limpia: se acaba la pelea")
		_ok(Engine.time_scale < 0.9, "la última baja de la sala va a cámara lenta (breve)")
		_ok(int(P.contadores.get("propinas", 0)) == propinas + 1 and J.oro >= oro_antes + 1 + J.piso, "limpiarla rápido da propina")
		_ok(not m._crono.visible, "y el reloj se esconde")
		m._cerrar_selector()
		m.entrar_sala(normales[1], Vector2i.ZERO)
		await _esperar(6)
		m._sala_t = 999.0
		yo.position = Sala.CENTRO + Vector2(0, 90)
		m._oleadas.clear()
		m._por_nacer.clear()
		for e in m._horda.enemigos:
			e.muerto = true
		await _esperar(3)
		_ok(int(P.contadores.get("propinas", 0)) == propinas + 1, "si tardas, no hay propina")
		m._cerrar_selector()  # por si al acabar soltó una carta justo donde estás
		m.entrar_sala(GeneradorMazmorra.INICIO, Vector2i.ZERO)
		await _esperar(2)

	# ---- enemigos nuevos y órdago
	m.jugador.invulnerable = true
	m.en_combate = true  # como en una sala cerrada: si no, el órdago no se lanza
	var nuevos: Array = []
	for i in 3:
		nuevos.append(m._horda.crear(["crupier", "maton", "botones"][i], m.jugador.position + Vector2(70 + i * 25, 0)))
	await _esperar(300)  # cinco segundos: les da tiempo a avisar y atacar
	_ok(nuevos.all(func(e): return is_instance_valid(e) and not e.muerto), "crupier, matón y botones andan y atacan sin errores")
	J.ordagos = 1
	m.lanzar_ordago()
	_ok(J.ordagos == 0, "el órdago se gasta")
	_ok(nuevos.all(func(e): return e.esta_aturdido() and e.empuje.length() > 50.0), "aturde y aparta a todos")
	m.lanzar_ordago()
	_ok(J.ordagos == 0, "sin órdagos no pasa nada")
	m._jugo.parar(0.1, true)
	m.quizas_pausar()
	await process_frame
	await process_frame
	_ok(is_equal_approx(Engine.time_scale, 1.0), "al pausar el tiempo vuelve a su ritmo")
	m._menu.cerrar()
	m._reanudar()
	m._jugo.camara_lenta(2.0, 0.3)
	m._jugo.limpiar()
	_ok(is_equal_approx(Engine.time_scale, 1.0), "al cambiar de sala no queda cámara lenta")
	m._horda.limpiar()
	m.en_combate = false

	# ---- tope de copias: como mucho dos de cada carta en la fila
	J.cartas = ["bala", "bala", "abanico", "", ""]
	_ok(J.carta_al_tope("bala") and not J.carta_al_tope("abanico"), "con dos balas, la bala está al tope y el abanico no")
	_ok(not J.carta_al_tope("bala", 0), "la ranura que vas a cambiar no cuenta")
	var sale_bala := false
	for s_tope in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = s_tope
		if J.robar_cartas(3, 0.0, rng).has("bala"):
			sale_bala = true
	_ok(not sale_bala, "una carta al tope ya no sale en tiendas ni cofres")
	var oro_tope: int = J.oro
	m._dar_carta("bala")
	_ok(J.copias("bala") == 2, "no se puede poner una tercera copia aunque haya hueco")
	_ok(J.oro > oro_tope, "la tercera copia se paga en monedas")
	m._dar_carta("abanico")
	_ok(J.copias("abanico") == 2, "la segunda copia sí entra")
	J.cartas = ["bala", "bala", "abanico", "abanico", "doble"]
	m._carta_pendiente = "bala"
	m._barra.modo_sustituir = true
	m._al_sustituir(4)
	_ok(J.cartas[4] == "doble" and m._barra.modo_sustituir, "al sustituir tampoco cuela la tercera copia")
	m._cerrar_selector()

	# ---- la tienda no cobra por nada
	J.imposible = true
	J.cartas = ["bala", "abanico"]
	J.oro = 500
	var ranura = load("res://scripts/recogible.gd").new()
	ranura.datos = {"id": m.ARTICULO_RANURA, "precio": 10}
	m.comprar(ranura, m.jugador)
	_ok(J.oro == 500 and J.cartas.size() == 2, "en el imposible la ranura no se cobra: no cabe")
	J.imposible = false
	ranura.free()
	m.actual["tienda"] = [{"id": "bala", "precio": 5, "vendido": true}, {"id": m.ARTICULO_REBARAJAR, "precio": 3}]
	var rebarajar = load("res://scripts/recogible.gd").new()
	rebarajar.datos = m.actual.tienda[1]
	m.comprar(rebarajar, m.jugador)
	_ok(J.oro == 500, "rebarajar sin cartas a la venta no se cobra")
	rebarajar.free()

	# ---- la deuda en cooperativo: medio corazón de cada uno
	J.activar_coop("tahur")
	J.oro = 0
	J.deuda = 60
	var max1: int = J.vida_max
	var max2: int = J.vida_max2
	J.cobrar_deuda()
	_ok(J.vida_max == max1 - 1 and J.vida_max2 == max2 - 1 and J.vida <= J.vida_max and J.vida2 <= J.vida_max2, "la deuda cobra medio corazón a cada jugador")
	J.quitar_coop()

	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
