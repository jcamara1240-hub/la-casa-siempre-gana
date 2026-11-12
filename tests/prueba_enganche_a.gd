extends SceneTree
## Otra mano y siguiente desbloqueo, racha del reto y resultado para compartir, frases del
## Dueño (con la causa de la muerte), requisitos visibles y pistas de transformación.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_enganche_a.gd

var _fallos := 0
var J: Node
var m
var _copia_progreso := PackedByteArray()
var _habia_progreso := false
var F  # FrasesDB, con load(): usa Juego y este script se compila antes que los autoloads


func _initialize() -> void:
	_correr.call_deferred()


func _ok(c: bool, que: String) -> void:
	print("ok  " if c else "MAL ", que)
	if not c:
		_fallos += 1


func _correr() -> void:
	J = root.get_node("Juego")
	F = load("res://scripts/frases_db.gd")
	# Las pruebas no tocan tus desbloqueos: se guarda el archivo tal cual y se devuelve al final.
	_habia_progreso = FileAccess.file_exists("user://progreso.cfg")
	if _habia_progreso:
		_copia_progreso = FileAccess.get_file_as_bytes("user://progreso.cfg")
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._menu.cerrar()
	_progreso_limpio()

	comprobar_objetivo()
	await comprobar_otra_mano()
	comprobar_racha()
	comprobar_compartir()
	comprobar_frases()
	await comprobar_causa()
	comprobar_requisitos()
	await comprobar_pistas()

	m._ir_al_menu()
	if _habia_progreso:
		var f := FileAccess.open("user://progreso.cfg", FileAccess.WRITE)
		f.store_buffer(_copia_progreso)
		f.close()
	else:
		DirAccess.remove_absolute("user://progreso.cfg")
	Progreso.cargar()
	DirAccess.remove_absolute("user://partida.sav")
	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)


func _progreso_limpio() -> void:
	Progreso.partidas = 0
	Progreso.victorias = 0
	Progreso.mesa_max = 0
	Progreso.jefes_vencidos = []
	Progreso.personajes = ["tahur"]
	Progreso.transformaciones = []
	Progreso.contadores = {}
	Progreso.vistos = {}
	Progreso.reto_racha = 0
	Progreso.reto_ultimo = ""


# ------------------------------------------------------------ 1. siguiente desbloqueo
func comprobar_objetivo() -> void:
	_progreso_limpio()
	var o := Progreso.siguiente_objetivo()
	_ok(String(o.get("texto", "")).begins_with(PersonajesDB.nombre("borracho").to_upper()) and int(o.meta) == 1,
		"de primeras, el siguiente es El Borracho (vence al Pez Rojo)")
	Progreso.contadores["enemigos"] = 800
	o = Progreso.siguiente_objetivo()
	_ok(int(o.actual) == 800 and int(o.meta) == 1000, "con 800 bajas manda el Gorila: 800/1000")
	Progreso.contadores["enemigos"] = 10
	Progreso.jefes_vencidos = ["pez", "ruleta"]
	Progreso.personajes = ["tahur", "borracho"]
	o = Progreso.siguiente_objetivo()
	_ok(int(o.actual) == 2 and int(o.meta) == 3, "luego La Crupier: 2/3 jefes")
	Progreso.personajes = PersonajesDB.PERSONAJES.keys()
	o = Progreso.siguiente_objetivo()
	_ok(String(o.texto).contains(Idioma.t("Mesa Roja").to_upper()), "con todos los personajes, la mesa siguiente")
	Progreso.mesa_max = PersonajesDB.MESAS.size() - 1
	_ok(Progreso.siguiente_objetivo().is_empty(), "con todo abierto no hay objetivo")
	_progreso_limpio()


# ------------------------------------------------------------ 1. otra mano
func comprobar_otra_mano() -> void:
	var p = m._pantalla
	m.empezar_partida("tahur", 0, true, false)
	await physics_frame
	p.mostrar_final(false)
	_ok(p.opciones() == ["otra", "menu"], "al perder: otra mano y salir")
	p.mostrar_final(true)
	_ok(p.opciones() == ["infinito", "otra", "menu"], "al ganar: infinito, otra mano y salir")
	J.diario = true
	_ok(p.opciones().is_empty(), "en el reto diario no se ofrece nada")
	J.diario = false
	p._t = p._fin
	_ok(p._hay_oferta() and p._caja_opcion(0).end.x < p._caja_opcion(1).position.x and p._caja_opcion(2).end.x <= 640.0,
		"tres botones en fila, dentro de la pantalla")
	# Con ratón: clic en OTRA MANO.
	J.piso = 3
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	clic.position = p._caja_opcion(1).get_center()
	p._gui_input(clic)
	await physics_frame
	_ok(not p.visible and not paused and J.extremo and not J.imposible and J.piso == 1 and J.personaje == "tahur",
		"clic en OTRA MANO: otra partida en extremo con el mismo personaje")
	m.empezar_partida("tahur", 0, false, true)
	await physics_frame
	m._otra_mano()
	await physics_frame
	_ok(J.imposible and J.extremo, "otra mano respeta el imposible")


# ------------------------------------------------------------ 3. racha del reto
func comprobar_racha() -> void:
	_progreso_limpio()
	Progreso.registrar_reto("2026-03-01", 100)
	Progreso.registrar_reto("2026-03-02", 100)
	Progreso.registrar_reto("2026-03-03", 100)
	_ok(Progreso.reto_racha == 3, "tres días seguidos: racha 3")
	Progreso.registrar_reto("2026-03-03", 300)
	_ok(Progreso.reto_racha == 3, "el mismo día no suma")
	_ok(Progreso.racha_viva("2026-03-04") == 3, "al día siguiente sigue viva")
	_ok(Progreso.racha_viva("2026-03-06") == 0, "con un hueco ya no se enseña")
	Progreso.registrar_reto("2026-03-06", 100)
	_ok(Progreso.reto_racha == 1, "tras un hueco vuelve a 1, sin más castigo")
	Progreso.registrar_reto("2026-02-28", 100)
	Progreso.registrar_reto("2026-03-01", 100)
	_ok(Progreso.reto_racha == 2, "también cruzando de mes")
	Progreso.guardar()
	Progreso.reto_racha = 0
	Progreso.cargar()
	_ok(Progreso.reto_racha == 2 and Progreso.reto_ultimo == "2026-03-01", "la racha se guarda en progreso.cfg")


func comprobar_compartir() -> void:
	var reto = m._reto
	var hoy: String = J.fecha_hoy()
	var antes := Progreso.reto_ultimo
	Progreso.reto_fecha = hoy
	Progreso.reto_mejor = 23410
	Progreso.reto_detalle = {"fecha": hoy, "puntos": 23410, "piso": 4, "gano": false, "tiempo": 600, "bajas": 1, "monedas": 1, "golpes": 1}
	Progreso.reto_ultimo = hoy
	Progreso.reto_racha = 3
	Idioma.actual = "es"
	reto.abrir()
	_ok(reto.puede_copiar(), "con el reto de hoy hecho se puede copiar")
	reto.tocar(reto.CAJA_COPIAR.get_center())
	var t: String = reto._copiado
	_ok(t.contains("23.410 pts") and t.contains("piso 4/5") and t.contains("racha: 3 días") and t.contains(hoy)
			and t.contains("https://hellboy1240.itch.io/la-casa-siempre-gana"), "el texto para compartir: " + t.replace("\n", " | "))
	Idioma.actual = "en"
	reto._copiado = ""
	reto.tecla(KEY_C)
	_ok(reto._copiado.contains("23,410 pts") and reto._copiado.contains("streak: 3 days"), "en inglés, y también con la tecla C")
	Idioma.actual = "es"
	Progreso.reto_detalle = {}
	_ok(not reto.puede_copiar(), "sin reto de hoy no hay nada que copiar")
	reto.visible = false
	Progreso.reto_ultimo = antes


# ------------------------------------------------------------ 5. el Dueño
func comprobar_frases() -> void:
	var fuente: Font = load("res://assets/fuente/pixel.fnt")
	var ids: Array = F.FRASES.keys()
	_ok(ids.size() >= 40, "hay %d frases" % ids.size())
	var mal := []
	for id in ids:
		var es: String = F.FRASES[id].texto
		if not Idioma.EN.has(es):
			mal.append(id)
			continue
		for texto in [es, Idioma.EN[es]]:
			for i in texto.length():
				if not fuente.has_char(texto.unicode_at(i)):
					mal.append(id)
			if fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > 560.0:
				mal.append(id + " (larga)")
	_ok(mal.is_empty(), "todas traducidas, con letras de la fuente y en una línea (%s)" % [mal])
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var base := {"gano": false, "piso": 3, "modo": "normal", "racha": 0, "causa": {}}
	var ctx := base.duplicate()
	ctx.causa = {"tipo": "jefe", "id": "ruleta"}
	_ok(F.elegir(ctx, [], r) == "jefe_ruleta", "si te mata la Ruleta, habla de la Ruleta")
	ctx.causa = {"tipo": "enemigo", "id": "ficha", "rango": 2}
	_ok(F.elegir(ctx, [], r) in ["elite", "elite_2"], "un élite pesa más que el tipo de enemigo")
	_ok(F.elegir(ctx, ["elite", "elite_2"], r) == "ficha", "las vistas pasan detrás: luego, la de la ficha")
	ctx.causa = {"tipo": "enemigo", "id": "dado", "rango": 0, "apuestas": true}
	_ok(F.elegir(ctx, [], r).begins_with("apuestas"), "morir en la sala de apuestas")
	ctx = base.duplicate()
	ctx.piso = 1
	_ok(F.elegir(ctx, [], r).begins_with("piso_1"), "caer en el piso 1")
	ctx.racha = 7
	_ok(F.elegir(ctx, [], r) == "racha_6", "una racha larga de derrotas")
	ctx = base.duplicate()
	ctx.gano = true
	var todas_gano := true
	for _i in 20:
		if not F.FRASES[F.elegir(ctx, [], r)].si.get("gano", false):
			todas_gano = false
	_ok(todas_gano, "al ganar solo salen frases de victoria")
	ctx.modo = "extremo"
	_ok(F.elegir(ctx, [], r) == "gano_extremo", "ganar en extremo tiene la suya")
	ctx = base.duplicate()
	ctx.modo = "infinito"
	ctx.piso = 1
	_ok(F.elegir(ctx, [], r) == "modo_infinito", "en el infinito no se habla del piso 1")
	var vistas := []
	for _i in 6:
		vistas.append(F.elegir(base, vistas, r))
	_ok(vistas.size() == 6 and _sin_repetir(vistas), "las generales rotan sin repetirse")


func _sin_repetir(lista: Array) -> bool:
	var vistos := {}
	for x in lista:
		if vistos.has(x):
			return false
		vistos[x] = true
	return true


func comprobar_causa() -> void:
	_progreso_limpio()
	m.empezar_partida("tahur", 0)
	await physics_frame
	J.vida = 1
	J.extremo = false
	var e = m._horda.crear("dado_bomba", m.jugador.position)
	e.hacer_rango(2, ["veloz", "blindado"])
	m.jugador._invulnerable_t = 0.0
	for _i in 30:
		await physics_frame
		if m._pantalla.visible:
			break
	_ok(m._pantalla.visible, "un enemigo te toca y mueres")
	_ok(J.ultima_causa.get("tipo") == "enemigo" and J.ultima_causa.get("id") == "dado_bomba" and int(J.ultima_causa.get("rango")) == 2,
		"queda apuntado quién fue: %s" % [J.ultima_causa])
	_ok(m._pantalla.frase() in ["elite", "elite_2"] and Progreso.visto("frases", m._pantalla.frase()),
		"el Dueño comenta el élite, y la frase queda vista")
	_ok(int(Progreso.contadores.get("derrotas_seguidas", 0)) == 1, "cuenta una derrota seguida")
	# Una bala de un jefe se apunta al jefe.
	m._pantalla.visible = false
	m.empezar_partida("tahur", 0)
	await physics_frame
	var jefe = load("res://scripts/jefe.gd").crear("bingo")
	jefe.position = Vector2(500, 200)
	m._horda.anadir_jefe(jefe)
	jefe.preparar(1.0)
	await physics_frame
	var causa: Dictionary = m._ataques.causa_en(Vector2(100, 100))
	_ok(causa.get("tipo") == "jefe" and causa.get("id") == "bingo", "con jefe en la sala, sus balas son suyas")
	m._horda.limpiar()
	m._ataques.limpiar()
	_ok(m._ataques.causa_en(Vector2(100, 100)).get("tipo") == "bala", "sin nadie cerca, una bala sin dueño")


# ------------------------------------------------------------ 6. requisitos visibles
func comprobar_requisitos() -> void:
	_progreso_limpio()
	Progreso.contadores["enemigos"] = 734
	_ok(Progreso.progreso_personaje("guarda") == Vector2i(734, 1000), "el Gorila: 734/1000")
	Progreso.jefes_vencidos = ["pez"]
	_ok(Progreso.progreso_personaje("crupier") == Vector2i(1, 3) and Progreso.progreso_personaje("borracho") == Vector2i(1, 1),
		"la Crupier 1/3 y el Borracho 1/1")
	m._seleccion.abrir()
	m._seleccion._indice = PersonajesDB.PERSONAJES.keys().find("guarda")
	m._seleccion.queue_redraw()
	m._seleccion.visible = false
	var col = m._coleccion
	col.abrir()
	var cerrada := ""
	for i in col._cartas.size():
		if not Progreso.carta_libre(col._cartas[i]):
			cerrada = col._cartas[i]
			col._mirar(col._caja_carta(i).get_center())
			break
	_ok(cerrada != "" and col._titulo_info.contains(Idioma.t(CartasDB.NOMBRE_RAREZA[CartasDB.CARTAS[cerrada].rareza]))
			and col._texto_info.contains(Idioma.t("LA ABRE UN JEFE: CADA JEFE QUE VENCES ABRE 3 CARTAS AL AZAR."))
			and col._texto_info.contains("%d/%d" % [Progreso.cartas_libres(), col._cartas.size()]),
		"una carta cerrada dice su rareza, cómo se abre y el recuento")
	col._cambiar_pagina(1)
	for i in col._objetos.size():
		if not Progreso.objeto_libre(col._objetos[i]):
			col._mirar(col._caja_objeto(i).get_center())
			break
	_ok(col._texto_info.contains(Idioma.t("LO ABRE UN JEFE: CADA JEFE QUE VENCES ABRE 2 OBJETOS AL AZAR.")), "un objeto cerrado, igual")
	col.visible = false


# ------------------------------------------------------------ 7. pistas de transformación
func comprobar_pistas() -> void:
	_progreso_limpio()
	_ok(ObjetosDB.a_un_paso(["traje", "puro"], []) == ["mafioso"], "traje y puro: a un paso del Mafioso")
	_ok(ObjetosDB.completa("whisky", ["traje", "puro"], []) == "mafioso", "el whisky lo completaría")
	_ok(ObjetosDB.completa("whisky", ["traje", "puro"], ["mafioso"]) == "", "si ya lo eres, no")
	m.empezar_partida("tahur", 0)
	await physics_frame
	var avisos := []
	var apuntar := func(id: String) -> void: avisos.append(id)
	J.a_un_paso.connect(apuntar)
	J.dar_objeto("traje")
	J.dar_objeto("puro")
	_ok(avisos.is_empty(), "la primera vez no se avisa: se descubre jugando")
	_ok(Progreso.visto("objetos", "traje"), "lo que coges queda como pieza vista")
	m.empezar_partida("tahur", 0)
	await physics_frame
	Progreso.transformaciones = ["mafioso"]
	J.dar_objeto("traje")
	J.dar_objeto("puro")
	_ok(avisos == ["mafioso"], "ya conocida: A UN PASO DE EL MAFIOSO")
	_ok(m._hud.aviso_actual() == "paso:mafioso", "y sale en la caja de avisos")
	_ok(m.objeto_completa("whisky") == "mafioso", "el whisky de la tienda brillaría")
	m._crear_objeto_suelo("whisky", Vector2(200, 200))
	await process_frame
	var con_brillo := false
	for r in m._recogibles.get_children():
		if r.datos.get("id", "") == "whisky":
			for h in r.get_children():
				if "centro" in h and "radio" in h:
					con_brillo = true
	_ok(con_brillo, "el objeto del tesoro lleva brillo")
	Progreso.transformaciones = []
	Progreso.partidas = 10
	m.empezar_partida("tahur", 0)
	await physics_frame
	avisos.clear()
	J.dar_objeto("trebol")
	J.dar_objeto("herradura")
	_ok(avisos == ["suertudo"], "con 10 partidas también se avisa de las no descubiertas")
	J.a_un_paso.disconnect(apuntar)
	# La colección: piezas vistas de una transformación sin descubrir.
	Progreso.partidas = 0
	var col = m._coleccion
	col.abrir()
	col._cambiar_pagina(1)
	var i: int = ObjetosDB.TRANSFORMACIONES.keys().find("mafioso")
	col._mirar(col._caja_transformacion(i).get_center())
	_ok(col._titulo_info == "???" and col._texto_info.contains(Idioma.t("PIEZAS VISTAS: %d/%d") % [3, 4])
			and col._texto_info.contains(ObjetosDB.nombre("traje").to_upper()) and not col._texto_info.contains(ObjetosDB.nombre("gafas").to_upper()),
		"sin descubrir: traje, puro y el whisky ofrecido; las gafas no (" + col._texto_info + ")")
	col.visible = false
