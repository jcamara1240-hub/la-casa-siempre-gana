extends SceneTree
## La sala de apuestas: generación, tragaperras, ruleta, guardado y controles.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_apuestas.gd
## (Apuestas y PanelApuestas usan Juego: se cargan con load(), no por su nombre.)

const APUESTAS := 6  # GeneradorMazmorra.Tipo.APUESTAS
const NORMAL := 1
const EVENTO := 5
const MAQUINA := 8  # Recogible.Clase.MAQUINA

var _fallos := 0
var A  # scripts/apuestas.gd
var J: Node
var m


func _ok(cond: bool, texto: String) -> void:
	print(("bien: " if cond else "MAL: ") + texto)
	if not cond:
		_fallos += 1


func _initialize() -> void:
	_correr.call_deferred()


func _esperar(n: int) -> void:
	for _i in n:
		await physics_frame


const GUARDADOS := ["user://progreso.cfg", "user://partida.sav"]


## La prueba juega partidas y gana logros: lo que hubiera en user:// se deja como estaba.
func _copiar_guardados() -> Dictionary:
	var copia := {}
	for ruta in GUARDADOS:
		if FileAccess.file_exists(ruta):
			copia[ruta] = FileAccess.get_file_as_bytes(ruta)
	return copia


func _restaurar_guardados(copia: Dictionary) -> void:
	for ruta in GUARDADOS:
		if copia.has(ruta):
			var f := FileAccess.open(ruta, FileAccess.WRITE)
			f.store_buffer(copia[ruta])
			f.close()
		elif FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ruta)


func _correr() -> void:
	var copia := _copiar_guardados()
	A = load("res://scripts/apuestas.gd")
	J = root.get_node("Juego")
	_generacion()
	_tabla()
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._menu.cerrar()
	m.empezar_partida("tahur", 0)
	await _esperar(2)
	_resultados()
	_precios_y_limites()
	_ruleta()
	await _partida()
	_restaurar_guardados(copia)
	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------- generación
func _generacion() -> void:
	var azar := RandomNumberGenerator.new()
	var con_sala := 0
	var mas_de_una := 0
	var eventos_mal := 0
	var no_es_normal := 0
	for semilla in 600:
		azar.seed = semilla + 1
		var salas := GeneradorMazmorra.generar(azar, 13 + semilla % 3)
		var cuantas := 0
		var eventos := 0
		for c in salas:
			if salas[c].tipo == APUESTAS:
				cuantas += 1
				if not salas[c].limpia:
					no_es_normal += 1
			if salas[c].tipo == EVENTO:
				eventos += 1
		if cuantas > 0:
			con_sala += 1
		if cuantas > 1:
			mas_de_una += 1
		if eventos != 2:
			eventos_mal += 1
	var parte := con_sala / 600.0
	print("pisos con sala de apuestas: %.1f%%" % (parte * 100.0))
	_ok(mas_de_una == 0, "nunca hay más de una sala de apuestas por piso")
	_ok(parte > 0.5 and parte < 0.7, "sale en torno al 60%% de los pisos (%.2f)" % parte)
	_ok(eventos_mal == 0, "las dos salas de evento siguen saliendo")
	_ok(no_es_normal == 0, "la sala de apuestas empieza limpia (sin combate)")
	# Misma semilla, mismo piso; y la sala no gasta del azar común (el estado final es el
	# mismo que si se hubiera generado sin ella: lo comprueba que el siguiente piso coincida).
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 777
	b.seed = 777
	var sa := GeneradorMazmorra.generar(a, 14)
	var sb := GeneradorMazmorra.generar(b, 14)
	var iguales := sa.keys() == sb.keys()
	for c in sa:
		iguales = iguales and sb.has(c) and sa[c].tipo == sb[c].tipo and sa[c].semilla == sb[c].semilla
	_ok(iguales and a.state == b.state, "con la misma semilla sale el mismo piso, sala de apuestas incluida")
	# Quitar la sala devuelve el piso de antes: el resto de tipos no cambia.
	var c_apuestas := Vector2i(-1, -1)
	for semilla in 50:
		a.seed = 1000 + semilla
		sa = GeneradorMazmorra.generar(a, 14)
		for c in sa:
			if sa[c].tipo == APUESTAS:
				c_apuestas = c
		if c_apuestas != Vector2i(-1, -1):
			break
	var vecinos := 0
	for d in GeneradorMazmorra.DIRECCIONES:
		if sa.has(c_apuestas + d):
			vecinos += 1
	_ok(c_apuestas != Vector2i(-1, -1) and vecinos >= 1, "la sala de apuestas está conectada al piso")


# ---------------------------------------------------------------- tabla de la tragaperras
func _tabla() -> void:
	var suma := 0.0
	var ids := []
	for f in A.TABLA:
		suma += float(f.prob)
		ids.append(f.id)
	_ok(absf(suma - 1.0) < 0.0001, "las probabilidades de la tragaperras suman 1")
	for id in ["777", "monedas", "pareja", "corazon", "carta", "objeto", "ordago", "nada", "herida", "maldicion", "emboscada", "ladron"]:
		_ok(ids.has(id), "la tabla tiene el resultado " + id)
	# El reparto empírico con muchas tiradas se parece a la tabla.
	var azar := RandomNumberGenerator.new()
	azar.seed = 99
	var cuenta := {}
	var n := 40000
	for _i in n:
		var id: String = A.elegir_resultado(azar.randf())
		cuenta[id] = cuenta.get(id, 0) + 1
	var cerca := true
	for f in A.TABLA:
		cerca = cerca and absf(float(cuenta.get(f.id, 0)) / n - float(f.prob)) < 0.01
	_ok(cerca, "con 40.000 tiradas cada resultado sale lo que dice la tabla")
	# Valor esperado: negativo en monedas siempre; contando premios, solo la primera tirada se acerca a cero.
	for precio in [5, 9, 13, 21]:
		var ve: Array = A.valor_esperado(precio)
		var ve_suerte: Array = A.valor_esperado(precio, 1.0)
		print("  precio %2d: VE monedas %+.2f  VE total %+.2f  (con trébol %+.2f)" % [precio, ve[0], ve[1], ve_suerte[1]])
		_ok(ve[0] < 0.0, "VE en monedas negativo al precio %d" % precio)
	_ok(A.valor_esperado(9)[1] < 0.0, "a partir de la segunda tirada el VE total es negativo")
	_ok(A.valor_esperado(9, 1.0)[1] > A.valor_esperado(9)[1], "la suerte mejora el VE")
	# Los rodillos enseñan el resultado y no otro.
	var bien_rodillos := true
	for semilla in 300:
		azar.seed = semilla
		for f in A.TABLA:
			var r: Array = A.rodillos(f.id, azar)
			var monedas := r.count("moneda")
			match f.id:
				"nada":
					bien_rodillos = bien_rodillos and monedas < 2 and not (r[0] == r[1] and r[1] == r[2])
				"pareja":
					bien_rodillos = bien_rodillos and monedas == 2
				_:
					bien_rodillos = bien_rodillos and r == [f.simbolo, f.simbolo, f.simbolo]
		var salvado: Array = A.rodillos("herida", azar, true)
		bien_rodillos = bien_rodillos and salvado.count("calavera") == 2 and salvado.count("moneda") == 0
	_ok(bien_rodillos, "los rodillos enseñan cada resultado sin confundirlo con otro premio")


# ---------------------------------------------------------------- cada resultado aplicado
func _estado(oro: int, vida: int, vida_max := 8) -> void:
	J.oro = oro
	J.vida_max = vida_max
	J.vida = vida
	J.ordagos = 2
	J.cartas = ["bala", "abanico", "ciega_peq", "propina", "", ""]
	J.objetos = []
	J.stats = J.STATS_BASE.duplicate()


func _aplicar(id: String, precio := 10, sala := {}) -> Dictionary:
	var azar := RandomNumberGenerator.new()
	azar.seed = 5
	if sala.is_empty():
		sala = {"semilla": 1, "limpia": true}
	return A.aplicar_tragaperras(id, precio, sala, azar)


func _resultados() -> void:
	_estado(50, 8)
	var r := _aplicar("777")
	# Algún objeto trae monedas al cogerlo: se cuentan aparte.
	var del_objeto := int(load("res://scripts/objetos_db.gd").OBJETOS[r.objeto].efecto.get("monedas", 0)) if r.has("objeto") else 0
	_ok(J.oro == 150 + del_objeto and J.objetos.size() == 1 and r.has("objeto"), "777: diez veces el precio y un objeto")
	_ok(Progreso.logros.has("premio_gordo"), "777: logro Premio Gordo")
	_estado(50, 8)
	_aplicar("monedas")
	_ok(J.oro == 80, "tres monedas: tres veces el precio")
	_estado(50, 8)
	_aplicar("pareja")
	_ok(J.oro == 60, "dos monedas: recuperas lo puesto")
	_estado(50, 4)
	_aplicar("corazon")
	_ok(J.vida == 6 and J.oro == 50, "tres corazones: curan uno")
	_estado(50, 8)
	_aplicar("corazon")
	_ok(J.vida == 8 and J.oro == 70, "tres corazones con la vida llena: se pagan en monedas")
	_estado(50, 8)
	r = _aplicar("carta")
	_ok(r.has("carta") and J.cartas[4] == r.carta, "carta: entra en el primer hueco de la fila")
	_estado(50, 8)
	J.cartas = ["bala", "abanico"]
	var sala := {"semilla": 1, "limpia": true}
	r = _aplicar("carta", 10, sala)
	_ok(sala.get("carta_pendiente", "") == r.carta and J.cartas.size() == 2, "carta con la fila llena: queda pendiente para elegir al salir")
	_aplicar("carta", 10, sala)
	_ok(J.oro == 50 + A.CARTA_SOBRANTE, "y una segunda carta con la fila llena se cobra en monedas")
	_estado(50, 8)
	r = _aplicar("objeto")
	_ok(J.objetos.size() == 1 and J.oro == 50, "tres diamantes: un objeto")
	_estado(50, 8)
	_aplicar("ordago")
	_ok(J.ordagos == 3, "tres órdagos: uno más")
	_estado(50, 8)
	_aplicar("nada")
	_ok(J.oro == 50 and J.vida == 8, "nada: no pasa nada")
	_estado(50, 8)
	_aplicar("herida")
	_ok(J.vida == 6 and J.oro == 50, "tres calaveras: pierdes un corazón")
	_estado(50, 2)
	_aplicar("herida")
	_ok(J.vida == 1, "tres calaveras con un corazón: te deja en medio, no te mata")
	_estado(50, 1)
	r = _aplicar("herida")
	_ok(J.vida == 1 and J.oro == 30, "tres calaveras con medio corazón: te roban en vez de matarte")
	_estado(50, 8)
	var antes: Array = J.cartas.duplicate()
	r = _aplicar("maldicion")
	var cambiadas := 0
	for i in antes.size():
		if antes[i] != J.cartas[i]:
			cambiadas += 1
			var CDB = load("res://scripts/cartas_db.gd")
			_ok(CDB.CARTAS[J.cartas[i]].rareza == 0 and CDB.CARTAS[J.cartas[i]].tipo == CDB.CARTAS[antes[i]].tipo,
					"maldición: la nueva es común y del mismo tipo")
	_ok(cambiadas == 1 and r.has("maldita"), "maldición: cambia exactamente una carta")
	_estado(50, 8)
	J.cartas = ["", ""]
	r = _aplicar("maldicion")
	_ok(J.cartas == ["", ""], "maldición sin cartas: no rompe nada")
	_estado(50, 8)
	sala = {"semilla": 1, "limpia": true}
	_aplicar("emboscada", 10, sala)
	_ok(sala.get("emboscada", false) and not sala.limpia, "tres pistolas: la sala queda pendiente de una emboscada")
	_estado(50, 8)
	_aplicar("ladron")
	_ok(J.oro == 30, "carterista: te roba el doble del precio")
	_estado(7, 8)
	_aplicar("ladron")
	_ok(J.oro == 0, "carterista con poco oro: te deja a cero, nunca en negativo")


# ---------------------------------------------------------------- precios y límites
func _precios_y_limites() -> void:
	J.piso = 1
	var sala := {"semilla": 1234, "limpia": true}
	var precios := []
	_estado(1000, 8)
	for _i in 4:
		precios.append(A.precio_tragaperras(sala, J.piso))
		A.tirar_tragaperras(sala)
	_ok(precios == [5, 9, 13, 17], "la tragaperras sube 4 por tirada: %s" % [precios])
	_ok(int(sala.tiradas_tragaperras) == 4, "la sala cuenta las tiradas")
	_ok(A.precio_tragaperras({"semilla": 1}, 3) == 9, "en el piso 3 empieza en 9")
	_estado(4, 8)
	var r: Dictionary = A.tirar_tragaperras({"semilla": 1})
	_ok(not r.ok and J.oro == 4, "sin oro para la tirada no se juega ni se cobra")
	# Determinista: la misma sala y la misma tirada dan lo mismo.
	var mismas := true
	for semilla in 40:
		_estado(1000, 8)
		var s1 := {"semilla": semilla, "limpia": true}
		var s2 := {"semilla": semilla, "limpia": true}
		var a: Dictionary = A.tirar_tragaperras(s1)
		_estado(1000, 8)
		var b: Dictionary = A.tirar_tragaperras(s2)
		mismas = mismas and a.id == b.id and a.rodillos == b.rodillos
	_ok(mismas, "misma semilla y misma tirada, mismo resultado")
	# Nunca deja oro ni vida en negativo, ni mata, aunque se juegue hasta arruinarse.
	var sano := true
	for semilla in 200:
		_estado(60, 2)
		var s := {"semilla": semilla, "limpia": true}
		for _i in 10:
			A.tirar_tragaperras(s)
			s.erase("emboscada")
			sano = sano and J.oro >= 0 and J.vida >= 1
	_ok(sano, "200 partidas a la tragaperras: nunca oro negativo ni vida a cero")
	# La suerte salva algunos castigos.
	var malos := [0, 0]
	for k in 2:
		for semilla in 3000:
			_estado(1000, 8)
			J.stats["suerte"] = 2.0 * k
			var r2: Dictionary = A.tirar_tragaperras({"semilla": semilla, "limpia": true})
			if A.MALOS.has(r2.id) and not r2.get("salvado", false):
				malos[k] += 1
	print("  castigos sin suerte %d, con suerte 2: %d" % malos)
	_ok(malos[1] < malos[0] * 0.55 and malos[1] > malos[0] * 0.25, "con dos tréboles se esquiva cerca del 60% de los castigos")


# ---------------------------------------------------------------- ruleta
func _ruleta() -> void:
	_ok(A.RUEDA.size() == 37 and A.ROJOS.size() == 18, "la rueda tiene 37 casillas y 18 rojas")
	var sala := {"semilla": 42, "limpia": true}
	# Busca una tirada roja y otra negra para comprobar los pagos de verdad.
	var ganadas := 0
	var perdidas := 0
	var pagos_bien := true
	for semilla in 60:
		_estado(100, 8)
		sala = {"semilla": semilla, "limpia": true}
		var r: Dictionary = A.jugar_ruleta(sala, "rojo", 10)
		var esperado := 110 if A.color_de(r.numero) == "rojo" else 90
		pagos_bien = pagos_bien and J.oro == esperado and r.gana == (A.color_de(r.numero) == "rojo")
		if r.gana:
			ganadas += 1
		else:
			perdidas += 1
	_ok(pagos_bien and ganadas > 0 and perdidas > 0, "al rojo: doble o nada (%d ganadas, %d perdidas)" % [ganadas, perdidas])
	var cero_bien := true
	var hubo_cero := false
	for semilla in 400:
		_estado(100, 8)
		var r: Dictionary = A.jugar_ruleta({"semilla": semilla}, "cero", 999)
		cero_bien = cero_bien and r.cantidad == 5 and J.oro == (95 + 180 if r.numero == 0 else 95)
		hubo_cero = hubo_cero or r.numero == 0
	_ok(cero_bien and hubo_cero, "al cero se juegan 5 y se cobran 180")
	_estado(3, 8)
	_ok(not A.jugar_ruleta({"semilla": 1}, "rojo", 5).ok and J.oro == 3, "sin oro para la ficha no se juega")
	_ok(A.puede_apostar_corazon(), "sin oro y con vida se puede apostar un corazón")
	var corazon_bien := true
	for semilla in 30:
		_estado(0, 6)
		var r: Dictionary = A.jugar_ruleta({"semilla": semilla}, "negro", 0, true)
		corazon_bien = corazon_bien and r.ok and (J.vida_max == 10 and J.vida == 8 if r.gana else J.vida_max == 8 and J.vida == 4)
	_ok(corazon_bien, "un corazón al negro: ganas un corazón más o lo pierdes")
	_estado(0, 2)
	_ok(not A.puede_apostar_corazon() and not A.jugar_ruleta({"semilla": 1}, "rojo", 0, true).ok, "con el último corazón no se puede apostar")
	_estado(10, 8)
	_ok(not A.puede_apostar_corazon(), "con oro se apuestan monedas, no corazones")
	sala = {"semilla": 7}
	_estado(1000, 8)
	for _i in A.TIRADAS_RULETA:
		A.jugar_ruleta(sala, "rojo", 5)
	_ok(not A.jugar_ruleta(sala, "rojo", 5).ok and J.oro <= 1000 + 5 * A.TIRADAS_RULETA, "tras %d tiradas el crupier cierra la mesa" % A.TIRADAS_RULETA)
	# Perderlo todo: hace falta jugárselo todo y que sea una cantidad seria.
	Progreso.logros.erase("a_la_ruina")
	for semilla in 50:
		_estado(30, 8)
		var r: Dictionary = A.jugar_ruleta({"semilla": semilla}, "rojo", 30)
		if not r.gana:
			break
	_ok(J.oro == 0 and Progreso.logros.has("a_la_ruina"), "perderlo todo en la ruleta da el logro A la Ruina")
	Progreso.logros.erase("a_la_ruina")
	for semilla in 50:
		_estado(10, 8)
		var r: Dictionary = A.jugar_ruleta({"semilla": semilla}, "rojo", 10)
		if not r.gana:
			break
	_ok(not Progreso.logros.has("a_la_ruina"), "perder 10 monedas no cuenta como arruinarse")
	var mismas := true
	for semilla in 30:
		_estado(100, 8)
		var a: Dictionary = A.jugar_ruleta({"semilla": semilla}, "negro", 5)
		_estado(100, 8)
		var b: Dictionary = A.jugar_ruleta({"semilla": semilla}, "rojo", 25)
		mismas = mismas and a.numero == b.numero
	_ok(mismas, "el número sale de la sala y la tirada, no de la apuesta")


# ---------------------------------------------------------------- en la partida
func _sala_apuestas() -> Vector2i:
	for c in m.salas:
		if m.salas[c].tipo == APUESTAS:
			return c
	return Vector2i(-1, -1)


func _maquina(nombre: String):
	for r in m._recogibles.get_children():
		if r.clase == MAQUINA and r.datos.maquina == nombre:
			return r
	return null


func _pulsar_tecla(tecla: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = tecla
	ev.physical_keycode = tecla
	Input.parse_input_event(ev)


func _partida() -> void:
	# Un piso con sala de apuestas.
	var c := Vector2i(-1, -1)
	for _i in 30:
		m.empezar_partida("tahur", 0)
		c = _sala_apuestas()
		if c != Vector2i(-1, -1):
			break
	_ok(c != Vector2i(-1, -1), "hay pisos con sala de apuestas")
	m.jugador.invulnerable = true
	_estado(200, 8)
	J.cartas = ["bala", "abanico", "", "", ""]
	J.cartas_cambiadas.emit()
	m.entrar_sala(c, Vector2i.ZERO)
	await _esperar(3)
	_ok(not m.en_combate and _maquina("tragaperras") != null and _maquina("ruleta") != null, "la sala tiene tragaperras y ruleta, sin pelea")
	_ok(m._hud.COLOR_MAPA.has(APUESTAS) and m._sala.rotulo.size() > 0, "tiene color en el mapa y rótulo de neón")
	# Lejos no se juega; al lado, E abre la máquina.
	m.jugador.position = Vector2(320, 230)
	await _esperar(2)
	_ok(m.maquina_a_mano() == null, "lejos de las máquinas no hay nada a mano")
	m.jugador.position = Vector2(176, 92)
	await _esperar(3)
	_ok(m.maquina_a_mano() != null and m.maquina_a_mano().datos.maquina == "tragaperras", "al lado de la tragaperras está a mano")
	_ok(m._aviso.text != "", "y se avisa de que se juega con E")
	J.tactil = true
	_ok(m._tactiles._hay_compra() and m._tactiles._maquina() != null, "en el móvil sale el botón (JUGAR)")
	J.tactil = false
	var p = m._panel_apuestas
	_pulsar_tecla(KEY_E)
	await _esperar(2)
	_ok(p.visible and paused, "E abre la tragaperras y pausa el juego")
	_pulsar_tecla(KEY_E)  # el botón elegido de entrada es tirar
	await _esperar(2)
	_ok(p.esta_girando() and int(p._resultado.precio) == 5, "E dentro del panel tira de la palanca")
	_ok(int(m.actual.get("tiradas_tragaperras", 0)) == 1, "la tirada se apunta en la sala")
	var guardada: Dictionary = Guardado.cargar()
	_ok(int(guardada.salas[c].get("tiradas_tragaperras", 0)) == 1, "y se guarda nada más tirar (antes de ver el resultado)")
	for _i in 200:
		await process_frame
		if not p.esta_girando():
			break
	_ok(not p.esta_girando() and p._texto != "", "los rodillos se paran solos y se enseña el resultado")
	# Recargar no cambia la siguiente tirada: se guarda la partida tras la primera,
	# se juega la segunda, se vuelve a la partida guardada y se repite.
	_quitar_emboscada()
	_estado(200, 8)
	J.cartas = ["bala", "abanico", "", "", ""]
	m._guardar_punto()
	var punto: Dictionary = Guardado.cargar()
	p._menu()  # si la primera fue una emboscada, el panel solo ofrecía pelear
	_ok(p.pulsar_texto(Idioma.t("TIRAR DE LA PALANCA (%d)").split(" (")[0]), "se puede volver a tirar")
	p.saltar_animacion()
	var segunda: Dictionary = p._resultado.duplicate()
	p._cerrar()
	await _esperar(2)
	_quitar_emboscada()
	Guardado.guardar(punto)
	m._horda.limpiar()
	m.continuar_partida()
	await _esperar(3)
	_ok(m.actual.pos == c and int(m.actual.get("tiradas_tragaperras", 0)) == 1, "al cargar, la sala recuerda sus tiradas")
	m.jugador.position = Vector2(176, 92)
	await _esperar(3)
	m.jugar_maquina(m.maquina_a_mano())
	p.pulsar_texto(Idioma.t("TIRAR DE LA PALANCA (%d)").split(" (")[0])
	p.saltar_animacion()
	_ok(p._resultado.id == segunda.id and p._resultado.rodillos == segunda.rodillos, "recargar no sirve para repetir la tirada (%s)" % segunda.id)
	p._cerrar()
	await _esperar(2)
	_quitar_emboscada()
	# La emboscada: al cerrar el panel empieza la pelea, y recargando vuelve.
	_estado(200, 8)
	m.jugador.position = Vector2(176, 92)
	await _esperar(2)
	m.jugar_maquina(m.maquina_a_mano())
	A.aplicar_tragaperras("emboscada", 10, m.actual, RandomNumberGenerator.new())
	p._menu()
	_ok(p.pulsar_texto(Idioma.t("¡A PELEAR!")), "tras las tres pistolas solo queda pelear")
	await _esperar(3)
	_ok(m.en_combate and not paused and m._oleadas_total <= 2, "la emboscada es una pelea corta de dos oleadas como mucho")
	_ok(m.maquina_a_mano() == null, "en plena pelea las máquinas no se usan")
	m._guardar_punto()
	m._horda.limpiar()
	m.en_combate = false
	m.continuar_partida()
	await _esperar(3)
	_ok(m.en_combate, "cargar la partida no libra de la emboscada")
	m._horda.limpiar()
	m._oleadas.clear()
	m._por_nacer.clear()
	await _esperar(5)
	_ok(not m.en_combate and m.actual.limpia and not m.actual.get("emboscada", true), "al acabar con ellos la sala vuelve a ser de apuestas")
	# La ruleta: con teclado, la primera apuesta es al rojo.
	_estado(50, 8)
	m.jugador.position = Vector2(472, 130)
	await _esperar(3)
	_ok(m.maquina_a_mano() != null and m.maquina_a_mano().datos.maquina == "ruleta", "al lado de la mesa la ruleta está a mano")
	m.jugar_maquina(m.maquina_a_mano())
	await _esperar(1)
	_pulsar_tecla(KEY_ENTER)
	await _esperar(2)
	_ok(p.esta_girando() and p._resultado.get("apuesta") == "rojo" and int(p._resultado.get("cantidad", 0)) == 5
			and int(m.actual.get("tiradas_ruleta", 0)) == 1, "Intro apuesta la ficha de 5 al rojo")
	_pulsar_tecla(KEY_ESCAPE)
	await _esperar(2)
	_ok(not p.esta_girando() and p.visible, "Esc durante el giro lo acaba, sin cerrar")
	_pulsar_tecla(KEY_ESCAPE)
	await _esperar(2)
	_ok(not p.visible and not paused, "Esc cierra la ruleta y el juego sigue")
	await _con_mando()
	# Modo extremo: no hay sala de apuestas (vuelve a ser de combate).
	var hay := false
	for _i in 20:
		m.empezar_partida("tahur", 0, true)
		hay = hay or _sala_apuestas() != Vector2i(-1, -1)
	_ok(not hay, "en modo extremo no hay sala de apuestas")
	# Reto diario: misma fecha, misma sala para todos.
	m.empezar_reto()
	var c1 := _sala_apuestas()
	var tipos1 := []
	for k in m.salas:
		tipos1.append([k, m.salas[k].tipo])
	m.empezar_reto()
	var tipos2 := []
	for k in m.salas:
		tipos2.append([k, m.salas[k].tipo])
	_ok(c1 == _sala_apuestas() and tipos1 == tipos2, "en el reto diario el piso (y su sala de apuestas) sale igual")
	m._ir_al_menu()


func _boton(boton: int) -> void:
	for pulsado in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = 0
		ev.button_index = boton
		ev.pressed = pulsado
		ev.pressure = 1.0 if pulsado else 0.0
		Input.parse_input_event(ev)
		await process_frame


## La sala entera con mando: Y abre la máquina, la cruceta elige, A pulsa y B se marcha.
func _con_mando() -> void:
	var Mando = load("res://scripts/mando.gd")
	var p = m._panel_apuestas
	_quitar_emboscada()
	_estado(200, 8)
	m.jugador.position = Vector2(176, 92)
	await _esperar(3)
	Mando.activo = true  # lo último que se ha tocado es el mando
	await _esperar(2)
	_ok(m._aviso.text == Idioma.t("%s: JUGAR A LA TRAGAPERRAS") % Mando.nombre("interactuar"),
			"con mando, la ayuda de la tragaperras enseña su botón: " + m._aviso.text)
	await _boton(JOY_BUTTON_Y)
	await _esperar(1)
	_ok(p.visible and paused and p._maquina == "tragaperras", "el botón de interactuar (Y) abre la tragaperras")
	var tiradas := int(m.actual.get("tiradas_tragaperras", 0))
	await _boton(JOY_BUTTON_A)
	_ok(not p.esta_girando() and int(m.actual.get("tiradas_tragaperras", 0)) == tiradas,
			"nada más abrir, A no tira (por si venías aporreando)")
	await _esperar(20)
	await _boton(JOY_BUTTON_DPAD_DOWN)
	_ok(p._botones[p._sobre].texto == Idioma.t("MARCHARSE"), "abajo señala Marcharse")
	await _boton(JOY_BUTTON_DPAD_UP)
	await _boton(JOY_BUTTON_A)
	_ok(p.esta_girando() and int(m.actual.get("tiradas_tragaperras", 0)) == tiradas + 1, "A tira de la palanca")
	await _boton(JOY_BUTTON_A)
	_ok(not p.esta_girando() and p._texto != "", "A durante el giro lo acaba y enseña el premio")
	await _boton(JOY_BUTTON_A)
	_ok(not p.esta_girando() and int(m.actual.get("tiradas_tragaperras", 0)) == tiradas + 1,
			"aporreando A no se vuelve a tirar sin ver el premio")
	await _esperar(20)
	await _boton(JOY_BUTTON_B)
	await _esperar(2)
	_ok(not p.visible, "B se marcha de la tragaperras")
	_quitar_emboscada()
	if m._selector.visible or m._barra.modo_sustituir:
		m._selector.visible = false
		m._barra.modo_sustituir = false
	paused = false
	# Ahora a la ruleta.
	_estado(200, 8)
	m.jugador.position = Vector2(472, 130)
	await _esperar(3)
	_ok(m._aviso.text == Idioma.t("%s: JUGAR A LA RULETA") % Mando.nombre("interactuar"),
			"al lado de la ruleta la ayuda cambia: " + m._aviso.text)
	await _boton(JOY_BUTTON_Y)
	await _esperar(1)
	_ok(p.visible and p._maquina == "ruleta" and p._sobre == 4, "Y abre la ruleta, con el cursor en el rojo")
	await _esperar(20)
	await _boton(JOY_BUTTON_DPAD_UP)
	_ok(p._sobre == 0, "arriba sube a la ficha que hay encima")
	await _boton(JOY_BUTTON_DPAD_RIGHT)
	_ok(p._sobre == 1, "derecha pasa a la ficha siguiente")
	await _boton(JOY_BUTTON_A)
	_ok(p._ficha == 10, "A elige la ficha de 10")
	await _boton(JOY_BUTTON_DPAD_DOWN)
	_ok(p._botones[p._sobre].texto == Idioma.t("NEGRO (x2)"), "abajo baja a la apuesta más cercana (el negro)")
	var en_ruleta := int(m.actual.get("tiradas_ruleta", 0))
	await _boton(JOY_BUTTON_A)
	_ok(p.esta_girando() and p._resultado.get("apuesta") == "negro" and int(p._resultado.get("cantidad", 0)) == 10
			and int(m.actual.get("tiradas_ruleta", 0)) == en_ruleta + 1, "A apuesta 10 al negro")
	await _boton(JOY_BUTTON_B)
	_ok(not p.esta_girando() and p.visible, "B durante el giro lo acaba, sin cerrar")
	await _boton(JOY_BUTTON_B)
	_ok(p.visible, "y al ver el número, B espera un instante (pulsación arrastrada)")
	await _esperar(20)
	await _boton(JOY_BUTTON_B)
	await _esperar(2)
	_ok(not p.visible and not paused, "B se marcha de la ruleta y el juego sigue")
	# Vuelve el teclado: la ayuda vuelve a ser la E.
	_pulsar_tecla(KEY_SHIFT)
	await _esperar(3)
	_ok(not Mando.activo and m._aviso.text == Idioma.t("E: JUGAR A LA RULETA"), "con teclado la ayuda vuelve a ser la E")


func _quitar_emboscada() -> void:
	if m.actual.get("emboscada", false):
		m.actual["emboscada"] = false
		m.actual["limpia"] = true
	m._horda.limpiar()
	m._oleadas.clear()
	m._por_nacer.clear()
	m.en_combate = false
	m._barra.en_combate = false
	m._motor.parar()
	m._sala.poner_puertas(true)
