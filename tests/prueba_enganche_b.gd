extends SceneTree
## Desglose del ciclo de cartas, pegatinas de mesa por personaje y Contrato de la Casa.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_enganche_b.gd
## Deja progreso.cfg y ajustes.cfg como estaban.

var _fallos := 0
var J: Node
var m: Node
var _copia_progreso := ""
var _copia_ajustes := ""


func _initialize() -> void:
	_correr.call_deferred()


func _ok(c: bool, que: String) -> void:
	print("bien: " if c else "MAL:  ", que)
	if not c:
		_fallos += 1


func _leer(ruta: String) -> String:
	return FileAccess.get_file_as_string(ruta) if FileAccess.file_exists(ruta) else ""


func _escribir(ruta: String, texto: String) -> void:
	if texto == "":
		DirAccess.remove_absolute(ruta)
		return
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


func _tecla(codigo: Key) -> void:
	for pulsada in [true, false]:
		var e := InputEventKey.new()
		e.keycode = codigo
		e.physical_keycode = codigo
		e.pressed = pulsada
		Input.parse_input_event(e)
		await process_frame


func _boton(boton: int) -> void:
	for pulsado in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = boton
		e.pressed = pulsado
		e.pressure = 1.0 if pulsado else 0.0
		Input.parse_input_event(e)
		await process_frame


func _correr() -> void:
	_copia_progreso = _leer("user://progreso.cfg")
	_copia_ajustes = _leer("user://ajustes.cfg")
	J = root.get_node("Juego")
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	m._menu.cerrar()
	_desglose()
	await _opcion_desglose()
	_migracion()
	_mesas_por_personaje()
	await _seleccion_mesas()
	_contrato_partida()
	_calor_y_premios()
	await _contrato_pantalla()
	# Todo como estaba.
	_escribir("user://progreso.cfg", _copia_progreso)
	_escribir("user://ajustes.cfg", _copia_ajustes)
	Progreso.cargar()
	J.cargar_ajustes()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------- 2. desglose del ciclo
func _ciclo(barra, fila: Array, record := false) -> Dictionary:
	var plan := Combo.resolver(fila)
	plan["record"] = record
	barra._al_empezar_ciclo(plan)
	for paso in plan.pasos:
		barra._al_ejecutar_paso(paso)
	return plan


func _desglose() -> void:
	var barra = m._barra
	J.desglose_ciclo = true
	barra._desde_desglose = 99.0
	barra._total_desglose = -1
	var antes: int = barra.desgloses
	_ciclo(barra, ["afilar", "bala", "doble_nada"])
	_ok(barra.desgloses == antes + 1, "un ciclo nuevo se desglosa")
	_ok(barra._aporte_texto[1] == "+8" and barra._aporte_texto[2] == "X2" and barra._aporte_t[0] == 0.0,
		"cada carta enseña su aporte: +8 y X2 (el modificador no suma nada)")
	_ok(barra._pop_t > 0.0 and not barra._pop_record, "el total da un salto al final, sin oro si no es récord")
	_ciclo(barra, ["afilar", "bala", "doble_nada"])
	_ok(barra.desgloses == antes + 1, "el mismo total enseguida no se vuelve a desglosar")
	barra._desde_desglose = 0.7
	_ciclo(barra, ["afilar", "bala", "doble_nada"])
	_ok(barra.desgloses == antes + 1, "ni a los 0,7 s si el total no cambia")
	_ciclo(barra, ["bala", "bala", "doble_nada"])
	_ok(barra.desgloses == antes + 2, "si el total cambia, sí (pasado el mínimo)")
	barra._desde_desglose = 0.1
	_ciclo(barra, ["bala", "bala", "bala", "doble_nada"])
	_ok(barra.desgloses == antes + 2, "pero no antes del mínimo")
	_ciclo(barra, ["bala", "bala", "bala", "doble_nada", "doble_nada"], true)
	_ok(barra.desgloses == antes + 3 and barra._pop_record, "un récord se desglosa siempre, en oro")
	barra._desde_desglose = 99.0
	J.desglose_ciclo = false
	_ciclo(barra, ["bala", "doble_nada", "doble_nada"])
	_ok(barra.desgloses == antes + 3, "con la opción quitada no se desglosa")
	J.desglose_ciclo = true
	# El motor marca el récord: supera el mejor combo que ya llevabas.
	var motor = m._motor
	var planes: Array = []
	var apuntar := func(p): planes.append(p)
	motor.ciclo_empezado.connect(apuntar)
	J.cartas = ["bala", "doble_nada", "", "", ""]
	J.mejor_combo = 5.0
	motor._nuevo_ciclo()
	J.mejor_combo = 50.0
	motor._nuevo_ciclo()
	motor.ciclo_empezado.disconnect(apuntar)
	motor._cola.clear()
	_ok(planes.size() == 2 and planes[0].record and not planes[1].record, "el motor marca cuándo un ciclo es récord")


func _opcion_desglose() -> void:
	var menu = m._menu
	menu.abrir_principal()
	menu._activar("opciones", 1)
	_ok("desglose" in menu._items, "la opción está en Opciones")
	menu._indice = menu._items.find("desglose")
	await _tecla(KEY_ENTER)
	var cfg := ConfigFile.new()
	_ok(not J.desglose_ciclo and cfg.load("user://ajustes.cfg") == OK and cfg.get_value("ajustes", "desglose_ciclo") == false,
		"Enter la quita y se guarda en ajustes.cfg")
	await _boton(JOY_BUTTON_A)
	_ok(J.desglose_ciclo, "y con el mando se vuelve a poner")
	menu.cerrar()


# ---------------------------------------------------------------- 4. pegatinas de mesa
func _migracion() -> void:
	var viejo := ConfigFile.new()
	viejo.set_value("progreso", "mesa_max", 3)
	viejo.set_value("progreso", "personajes", ["tahur", "borracho", "heredera"])
	viejo.set_value("progreso", "personajes_ganadores", ["tahur"])
	viejo.save("user://progreso.cfg")
	Progreso.cargar()
	_ok(Progreso.mesa_elegible("tahur") == 3 and Progreso.mesa_elegible("borracho") == 3 and Progreso.mesa_elegible("heredera") == 3,
		"progreso antiguo: todos los que tenía abiertos conservan sus mesas")
	_ok(Progreso.mesa_ganada("tahur") == 2 and Progreso.mesa_ganada("borracho") == -1,
		"la pegatina del único ganador es la mesa anterior a la abierta")
	_ok(Progreso.mesa_elegible("guarda") == 0, "los que se abran después empiezan en la Blanca")
	viejo.set_value("progreso", "personajes_ganadores", ["tahur", "borracho"])
	viejo.save("user://progreso.cfg")
	Progreso.cargar()
	_ok(Progreso.mesa_ganada("tahur") == 0 and Progreso.mesa_ganada("borracho") == 0 and Progreso.mesa_elegible("borracho") == 3,
		"con varios ganadores, pegatina blanca (la segura) y las mesas intactas")
	Progreso.guardar()
	Progreso.cargar()
	_ok(Progreso.mesa_elegible("borracho") == 3 and Progreso.mesa_ganada("borracho") == 0, "ya migrado se guarda y se carga igual")


func _mesas_por_personaje() -> void:
	Progreso.mesa_max = 0
	Progreso.mesa_max_pj = {}
	Progreso.mesa_ganada_pj = {}
	Progreso.personajes = ["tahur", "borracho"]
	Progreso.al_ganar(1, false, "tahur")
	_ok(Progreso.mesa_ganada("tahur") == 1 and Progreso.mesa_elegible("tahur") == 2, "ganar en la Roja con el Tahúr abre su Verde")
	_ok(Progreso.mesa_elegible("borracho") == 0 and Progreso.mesa_ganada("borracho") == -1,
		"ganar con el Tahúr en la Roja no abre la Verde al Borracho")
	var nuevo := Progreso.al_ganar(0, false, "borracho")
	_ok(Progreso.mesa_elegible("borracho") == 1 and nuevo.any(func(n): return n.tipo == "mesa" and n.id == "1"), "el Borracho abre la suya")
	Progreso.al_ganar(0, false, "tahur")
	_ok(Progreso.mesa_ganada("tahur") == 1 and Progreso.mesa_elegible("tahur") == 2, "ganar en una mesa más baja no quita nada")
	for _i in 6:
		Progreso.al_ganar(Progreso.mesa_elegible("tahur"), false, "tahur")
	_ok(Progreso.mesa_elegible("tahur") == 4 and Progreso.mesa_ganada("tahur") == 4, "la Mesa de Oro es el tope")


func _seleccion_mesas() -> void:
	var sel = m._seleccion
	sel._indice = 0  # Tahúr: hasta la de Oro
	sel._mesa = 0
	sel._mesa_deseada = 0
	sel.abrir()
	for _i in 3:
		sel._cambiar_mesa(1)
	_ok(sel._mesa == 3, "el Tahúr elige la Mesa Negra")
	sel._elegir_personaje(1)  # Borracho: hasta la Roja
	_ok(sel._mesa == 1, "al pasar al Borracho se recorta a su mesa más alta")
	sel._cambiar_mesa(1)
	_ok(sel._mesa == 0, "y no pasa de ahí (da la vuelta)")
	sel._cambiar_mesa(-1)
	sel._mesa_deseada = 3
	sel._elegir_personaje(0)
	_ok(sel._mesa == 3, "al volver al Tahúr recupera la que había elegido")
	sel.queue_redraw()
	await process_frame
	sel.visible = false


# ---------------------------------------------------------------- 8. Contrato de la Casa
func _contrato_partida() -> void:
	Progreso.personajes = ["tahur", "borracho", "heredera"]
	Progreso.personajes_ganadores = ["tahur"]
	Progreso.firmar("tahur", ["corazon", "ranura", "recargo", "inventada"])
	_ok(Progreso.contrato("tahur") == ["corazon", "ranura", "recargo"], "las cláusulas que no existen se ignoran")
	J.nueva_partida(0, "tahur", 0)
	_ok(J.calor() == 6, "calor: 2 + 3 + 1 = 6 (%d)" % J.calor())
	_ok(J.vida_max == 6 and J.cartas.size() == 4 and J.precio_final(100) == 130,
		"un corazón menos, una ranura menos y la tienda un 30% más cara")
	J.nueva_partida(0, "tahur", 4)
	_ok(J.vida_max == 4 and J.precio_final(100) == 169, "se suma encima de la mesa (Oro: dos corazones menos, recargo doble)")
	var guardado: Dictionary = J.volcar()
	J.nueva_partida(0, "tahur", 0, true)
	_ok(J.contrato.is_empty() and J.vida_max == 2, "en extremo no hay contrato")
	J.nueva_partida(0, "tahur", 0, false, false, true)
	_ok(J.contrato.is_empty(), "en imposible tampoco")
	J.nueva_partida_reto("2026-11-12", false)
	_ok(J.contrato.is_empty() and J.calor() == 0, "ni en el reto diario")
	Progreso.firmar("borracho", ["plomo"])
	J.nueva_partida(0, "borracho", 0)
	_ok(J.contrato.is_empty(), "sin haber ganado con él, no hay contrato")
	J.restaurar(guardado)
	_ok(J.contrato == ["corazon", "ranura", "recargo"] and J.calor() == 6, "el contrato se guarda con la partida")
	var vieja: Dictionary = guardado.duplicate()
	vieja.erase("contrato")
	J.restaurar(vieja)
	_ok(J.contrato.is_empty(), "una partida guardada de antes no trae contrato")
	var plan := {"umbral": 0.6}
	Director.aplicar_contrato(plan, ["oleadas"])
	_ok(is_equal_approx(plan.umbral, 0.42), "Prisas: la oleada siguiente entra antes")
	# Sin botiquín: la tienda no vende corazones.
	Progreso.firmar("tahur", ["sin_cura"])
	J.nueva_partida(0, "tahur", 0)
	m.actual = {"tienda": [], "semilla": 7}
	m._llenar_tienda()
	_ok(not m.actual.tienda.any(func(a): return a.id == "_corazon"), "Sin botiquín: no hay corazón en la tienda")
	Progreso.firmar("tahur", [])
	J.nueva_partida(0, "tahur", 0)
	m.actual = {"tienda": [], "semilla": 7}
	m._llenar_tienda()
	_ok(m.actual.tienda.any(func(a): return a.id == "_corazon"), "sin contrato, sí")
	m.actual = {}
	var claves := []
	for c in PersonajesDB.CLAUSULAS:
		var d: Dictionary = PersonajesDB.CLAUSULAS[c]
		if int(d.calor) < 1 or int(d.calor) > 3 or not Idioma.EN.has(d.nombre) or not Idioma.EN.has(d.desc):
			claves.append(c)
	_ok(PersonajesDB.CLAUSULAS.size() >= 6 and PersonajesDB.CLAUSULAS.size() <= 8 and claves.is_empty(),
		"6-8 cláusulas con calor de 1 a 3, traducidas (mal: %s)" % [claves])


func _calor_y_premios() -> void:
	Progreso.calor_pj = {}
	Progreso.traje_pj = {}
	Progreso.dorso = 0
	_ok(Progreso.dorsos_libres() == 1 and Progreso.ruta_dorso().ends_with("carta_suelo.png"), "sin calor, solo el dorso de siempre")
	var nuevo := Progreso.al_ganar(0, false, "tahur", 6)
	_ok(Progreso.calor_record("tahur") == 6, "récord de calor del Tahúr: 6")
	_ok(nuevo.any(func(n): return n.tipo == "dorso" and n.id == "1") and nuevo.any(func(n): return n.tipo == "traje" and n.id == "tahur"),
		"calor 6 abre el primer dorso y el traje de gala")
	_ok(Progreso.dorsos_libres() == 2 and not Progreso.traje_libre("borracho"), "el traje es por personaje; los dorsos, de todos")
	nuevo = Progreso.al_ganar(0, false, "tahur", 2)
	_ok(Progreso.calor_record("tahur") == 6 and not nuevo.any(func(n): return n.tipo == "dorso"), "un calor más bajo no cambia el récord")
	Progreso.dorso = 1
	_ok(ResourceLoader.exists(Progreso.ruta_dorso()) and Progreso.ruta_dorso().ends_with("carta_suelo_1.png"), "el dorso elegido existe")
	Progreso.dorso = 3
	_ok(Progreso.ruta_dorso().ends_with("carta_suelo_1.png"), "un dorso sin abrir no se usa")
	Progreso.traje_pj["tahur"] = true
	_ok(PersonajesDB.textura("tahur").resource_path.ends_with("pj_tahur_gala.png"), "con el traje, el dibujo de gala")
	Progreso.traje_pj["borracho"] = true
	_ok(PersonajesDB.textura("borracho").resource_path.ends_with("pj_borracho.png"), "sin ganarlo, el traje no se pone")
	for id in PersonajesDB.PERSONAJES:
		_ok(ResourceLoader.exists("res://assets/personajes/pj_%s_gala.png" % id), "existe el traje de gala de " + id)
	for n in range(1, 4):
		_ok(ResourceLoader.exists("res://assets/objetos/carta_suelo_%d.png" % n), "existe el dorso %d" % n)
	Progreso.traje_pj = {}
	# En la partida: HUD y pantalla final enseñan el calor.
	Progreso.firmar("tahur", ["plomo", "jefes"])
	J.nueva_partida(0, "tahur", 1)
	_ok(m._pantalla._nombre_mesa().contains(Idioma.t("CALOR %d") % 3), "la pantalla final pone el calor junto a la mesa")


func _contrato_pantalla() -> void:
	var sel = m._seleccion
	Progreso.firmar("tahur", [])
	sel._indice = 0
	sel._modo = 0
	sel.abrir()
	await _tecla(KEY_C)
	_ok(sel._contrato, "C abre el contrato")
	await _tecla(KEY_ENTER)
	await _tecla(KEY_DOWN)
	await _tecla(KEY_ENTER)
	_ok(sel._c_firmadas.size() == 2, "Enter marca cláusulas")
	await _tecla(KEY_UP)
	await _tecla(KEY_ENTER)
	_ok(sel._c_firmadas.size() == 1, "y la desmarca")
	await _tecla(KEY_ESCAPE)
	_ok(not sel._contrato and sel.visible and Progreso.contrato("tahur").size() == 1, "Esc cierra firmando, sin salir de la selección")
	await _boton(JOY_BUTTON_Y)
	_ok(sel._contrato, "Y del mando lo abre")
	for _i in PersonajesDB.CLAUSULAS.size() + 2:
		await _boton(JOY_BUTTON_DPAD_DOWN)
	_ok(sel._c_items[sel._c_indice] == "listo", "la cruceta baja hasta Firmar")
	await _boton(JOY_BUTTON_A)
	_ok(not sel._contrato, "A en Firmar lo cierra")
	# Con el ratón (y el dedo): tocar una cláusula la marca.
	sel._abrir_contrato()
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	clic.position = sel._caja_item(PersonajesDB.CLAUSULAS.size() - 1).get_center()
	sel._gui_input(clic)
	_ok(sel._c_firmadas.has("ranura"), "un clic marca la cláusula")
	clic.position = sel._caja_item(sel._c_items.size() - 1).get_center()
	sel._gui_input(clic)
	_ok(not sel._contrato and Progreso.contrato("tahur").has("ranura"), "un clic en Firmar la guarda")
	sel._elegir_personaje(1)  # el Borracho no ha ganado
	sel._abrir_contrato()
	_ok(not sel._contrato, "sin ganar con él no se abre")
	sel._elegir_personaje(0)
	sel._modo = 1
	sel._abrir_contrato()
	_ok(not sel._contrato, "en extremo tampoco")
	sel._modo = 0
	sel.visible = false
