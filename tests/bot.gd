extends SceneTree
## Juega partidas enteras cruzando las puertas de verdad.
##   godot --headless --fixed-fps 60 --path . -s res://tests/bot.gd -- modo=invencible partidas=1
##   godot --headless --fixed-fps 60 --path . -s res://tests/bot.gd -- modo=normal partidas=20
## Con capturas=DIRECTORIO guarda imágenes (necesita pantalla).

# Mismos valores que Recogible.Clase: nombrar esa clase aquí la compilaría antes que los autoloads.
const CARTA := 2
const COFRE := 3
const ARTICULO := 5
const OBJETO := 6
const TIPO_EVENTO := 5

var m
var J: Node
var _args := {}
var _visitadas := {}
var _capturas := ""
var _tomadas := {}
var _pulsadas := {}
var _partida := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var t := a.split("=")
		_args[t[0]] = t[1]
	_capturas = _args.get("capturas", "")
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = 1.0
	_correr.call_deferred()


func _correr() -> void:
	J = root.get_node("Juego")
	var partidas := int(_args.get("partidas", "1"))
	var invencible: bool = _args.get("modo", "invencible") == "invencible"
	var victorias := 0
	var informe: Array = []
	for n in partidas:
		var res: Dictionary = await _jugar(invencible)
		if res.gana:
			victorias += 1
		informe.append(res)
		print("partida %d: %s vida=%d oro=%d cartas=%s total=%d muertos=%d piso=%d objetos=%d" % [
			n, "GANA" if res.gana else "pierde", res.vida, res.oro, res.cartas, res.total, res.muertos, res.salas, res.objetos])
	print("VICTORIAS %d/%d" % [victorias, partidas])
	quit()


func _jugar(invencible: bool) -> Dictionary:
	if m != null:
		m.queue_free()
		await process_frame
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	await _captura("portada")
	m._pantalla.visible = false
	m._menu.cerrar()
	var ids: Array = ["tahur", "borracho", "crupier", "heredera", "mago", "guarda"]
	m.empezar_partida(ids[_partida % ids.size()], int(_args.get("mesa", "0")))
	_partida += 1
	m.jugador.invulnerable = invencible
	_visitadas = {GeneradorMazmorra.INICIO: true}
	await _esperar(5)
	await _captura("inicio")
	while not _acabada():
		_visitadas = {GeneradorMazmorra.INICIO: true}
		await _recorrer(GeneradorMazmorra.INICIO, Vector2i.ZERO)
	var plan := Combo.resolver(J.cartas)
	return {"gana": J.vida > 0, "vida": J.vida, "oro": J.oro,
		"cartas": ",".join(J.cartas), "total": plan.total, "muertos": J.enemigos_eliminados, "salas": J.piso, "objetos": J.objetos.size()}


func _acabada() -> bool:
	return m._pantalla.visible


## Recorre el árbol de salas. El jefe se deja para el final.
func _recorrer(c: Vector2i, _desde: Vector2i) -> bool:
	if await _resolver_sala():
		return true
	var hijos: Array = []
	for d in GeneradorMazmorra.DIRECCIONES:
		var q: Vector2i = c + d
		if m.salas.has(q) and not _visitadas.has(q):
			hijos.append(d)
	hijos.sort_custom(func(a, b): return _lleva_al_jefe(c + a, c) and not _lleva_al_jefe(c + b, c) == false and false)
	var finales: Array = []
	for d in hijos:
		if _lleva_al_jefe(c + d, c):
			finales.append(d)
	for d in hijos:
		if not finales.has(d):
			finales.push_front(d)
	for d in finales:
		var q: Vector2i = c + d
		_visitadas[q] = true
		if await _cruzar(d):
			return true
		if await _recorrer(q, c):
			return true
		if await _cruzar(-d):
			return true
		if await _resolver_sala():
			return true
	return false


func _lleva_al_jefe(c: Vector2i, padre: Vector2i) -> bool:
	if m.salas[c].tipo == GeneradorMazmorra.Tipo.JEFE:
		return true
	for d in GeneradorMazmorra.DIRECCIONES:
		var q: Vector2i = c + d
		if q != padre and m.salas.has(q) and _lleva_al_jefe(q, c):
			return true
	return false


func _cruzar(d: Vector2i) -> bool:
	_soltar_teclas()
	var destino: Vector2i = m.actual.pos + d
	m.jugador.position = Sala.HUECOS[d].get_center() + Vector2(d) * 8.0
	for _i in 200:
		await physics_frame
		if _acabada():
			return true
		if m.actual.pos == destino and not m._cambiando_sala:
			await _esperar(3)
			return false
		if m.actual.pos != destino and not m._cambiando_sala:
			m.jugador.position = Sala.HUECOS[d].get_center() + Vector2(d) * 8.0
	push_error("no se pudo cruzar la puerta %s en %s pausa=%s selector=%s sustituir=%s combate=%s cambiando=%s jugador=%s piso=%s" % [d, m.actual.pos, paused, m._selector.visible, m._barra.modo_sustituir, m.en_combate, m._cambiando_sala, m.jugador.position, J.piso])
	quit(2)
	return true


func _resolver_sala() -> bool:
	if _args.has("traza"):
		print("sala ", m.actual.pos, " tipo ", m.actual.tipo, " pausa ", paused, " combate ", m.en_combate)
	var marcas := {GeneradorMazmorra.Tipo.TIENDA: "tienda", GeneradorMazmorra.Tipo.TESORO: "tesoro"}
	if marcas.has(m.actual.tipo):
		await _esperar(4)
		await _captura(marcas[m.actual.tipo])
	if m.actual.tipo == TIPO_EVENTO and not m.actual.get("evento_hecho", false):
		await _jugar_evento()
	var t := 0
	while m.en_combate:
		await physics_frame
		t += 1
		if _acabada():
			return true
		_esquivar(t > 60 * 45)
		if _args.has("traza") and t % 600 == 0:
			print(m.actual.pos, " t=", t, " vivos=", m._horda.enemigos.size(), " oleadas=", m._oleadas.size(), " pausa=", paused, " jugador=", m.jugador.position, " motor=", m._motor.activo, " hijos_ataques=", m._ataques.get_child_count(), " e0=", m._horda.enemigos[0].vida if m._horda.enemigos.size()>0 else -1, " ", m._horda.enemigos[0]._nacer if m._horda.enemigos.size()>0 else -1, " ", m._horda.enemigos[0].position if m._horda.enemigos.size()>0 else Vector2.ZERO, " fps=", Engine.get_frames_per_second(), " efectos=", m._efectos.get_child_count(), " cola=", m._motor._cola.size(), " esp=", m._motor._espera)
		if t == 360:
			await _captura("combate" if m.actual.tipo != GeneradorMazmorra.Tipo.JEFE else "jefe")
		if t > 60 * 300:
			push_error("sala interminable en %s: %s, jugador %s, columnas %s, cartas %s, enemigos %s" % [m.actual.pos, m.actual.tipo, m.jugador.position, m._sala.solidos.size(), J.cartas, m._horda.enemigos.map(func(e): return [e.tipo, e.position, e.activo()])])
			quit(3)
			return true
	_soltar_teclas()
	await _esperar(70)
	for r in m._recogibles.get_children():
		if not is_instance_valid(r):
			continue
		if r.clase == COFRE and not m.actual.cofre_abierto:
			m.jugador.position = r.position
			await _esperar(4)
			await _atender_objetos()
	await _atender_objetos()
	_ordenar_cartas()
	if m.actual.tipo == GeneradorMazmorra.Tipo.TIENDA:
		await _comprar()
	if m.actual.tipo == GeneradorMazmorra.Tipo.JEFE and m.actual.limpia:
		m.jugador.position = Sala.CENTRO + Vector2(0, 60)
		await _esperar(10)
		m.jugador.position = Sala.CENTRO
		await _esperar(10)
		return true
	return _acabada()


func _jugar_evento() -> void:
	m.jugador.position = Sala.CENTRO
	await _esperar(4)
	await _captura("evento")
	var pasos := 0
	while m._panel.visible:
		pasos += 1
		if pasos > 6000:
			push_error("evento sin salida: %s" % m.actual.evento)
			quit(4)
			return
		m._panel.actuar_al_azar()
		await _esperar(5)
	m.jugador.position = Sala.CENTRO + Vector2(0, 80)
	await _esperar(3)
	await _atender_objetos()


func _atender_objetos() -> void:
	for r in m._recogibles.get_children():
		if not is_instance_valid(r):
			continue
		if r.clase == CARTA or r.clase == OBJETO:
			m.jugador.position = r.position
			await _esperar(3)
	await _esperar(4)
	if m._selector.visible:
		await _captura("selector")
		m._selector.elegida.emit(_mejor(m._selector._ids))
		await _esperar(2)
	if m._barra.modo_sustituir:
		await _captura("sustituir")
		var peor := _peor_ranura()
		if peor >= 0 and _valor(m._carta_pendiente) > _valor(J.cartas[peor]):
			m._barra.sustitucion_elegida.emit(peor)
		if m._barra.modo_sustituir:
			m._barra.sustitucion_cancelada.emit()
		await _esperar(2)


func _valor(id: String) -> float:
	var c: Dictionary = CartasDB.CARTAS[id]
	return float(c.rareza) * 2.0 + (1.5 if c.tipo == CartasDB.Tipo.MULTIPLICADOR else (1.0 if c.tipo == CartasDB.Tipo.ATAQUE else 0.0))


func _mejor(ids: Array) -> String:
	var mejor: String = ids[0]
	for id in ids:
		if _valor(id) > _valor(mejor):
			mejor = id
	return mejor


func _peor_ranura() -> int:
	var peor := -1
	for i in J.cartas.size():
		if peor == -1 or _valor(J.cartas[i]) < _valor(J.cartas[peor]):
			peor = i
	return peor


## Modificadores delante de cada ataque y multiplicadores al final.
func _ordenar_cartas() -> void:
	var mods: Array = []
	var ataques: Array = []
	var mults: Array = []
	var huecos := 0
	for id in J.cartas:
		if id == "":
			huecos += 1
			continue
		match CartasDB.CARTAS[id].tipo:
			CartasDB.Tipo.MODIFICADOR: mods.append(id)
			CartasDB.Tipo.ATAQUE: ataques.append(id)
			CartasDB.Tipo.MULTIPLICADOR: mults.append(id)
	var fila: Array = []
	for a in ataques:
		if not mods.is_empty():
			fila.append(mods.pop_front())
		fila.append(a)
	fila = mods + fila + mults
	for _i in huecos:
		fila.append("")
	J.cartas = fila
	J.cartas_cambiadas.emit()


func _comprar() -> void:
	for r in m._recogibles.get_children():
		if not is_instance_valid(r) or r.clase != ARTICULO or r.is_queued_for_deletion() or r.datos.id == "_rebarajar":
			continue
		if J.oro >= int(r.datos.precio):
			m.comprar(r)
			await _esperar(2)
			await _atender_objetos()


func _esquivar(perseguir := false) -> void:
	var yo: Vector2 = m.jugador.position
	var huida := Vector2.ZERO
	for e in m._horda.en_radio(yo, 90.0):
		var d: Vector2 = yo - e.position
		huida += d / maxf(d.length_squared(), 1.0)
	huida += (Sala.CENTRO - yo) * 0.00006
	var cerca: Array = m._horda.en_radio(yo, 90.0)
	if cerca.is_empty() or perseguir:
		var lista: Array = m._horda.mas_cercanos(yo, 1)
		if not lista.is_empty():
			huida = (lista[0].position - yo).normalized()
	_pulsar(KEY_D, huida.x > 0.002)
	_pulsar(KEY_A, huida.x < -0.002)
	_pulsar(KEY_S, huida.y > 0.002)
	_pulsar(KEY_W, huida.y < -0.002)


func _pulsar(tecla: Key, si: bool) -> void:
	if _pulsadas.get(tecla, false) == si:
		return
	_pulsadas[tecla] = si
	var e := InputEventKey.new()
	e.physical_keycode = tecla
	e.pressed = si
	Input.parse_input_event(e)


func _soltar_teclas() -> void:
	for t in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_pulsar(t, false)


func _esperar(n: int) -> void:
	for _i in n:
		await physics_frame


func _captura(nombre: String) -> void:
	if _capturas == "" or _tomadas.has(nombre):
		return
	_tomadas[nombre] = true
	var escala := Engine.time_scale
	Engine.time_scale = 1.0
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [_capturas, nombre])
	Engine.time_scale = escala
