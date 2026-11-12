class_name Horda
extends Node2D
## Mueve a todos los enemigos y responde a "¿quién hay cerca de este punto?".
## Para eso reparte a los enemigos en una rejilla, que se rehace en cada fotograma.

signal enemigo_muerto(posicion: Vector2, oro_prob: float, tipo: String, monedas: int, elite: bool)
signal danio_hecho(posicion: Vector2, cantidad: float, color: Color)
## Justo antes de enemigo_muerto, solo para raros y élites (botín y logros de rango).
signal rango_muerto(enemigo: Enemigo)

const CELDA := 32.0

var jugador: Node2D
## Todos los jugadores (en cooperativo, dos; el primero es "jugador"). Lo pone main.
var jugadores: Array = []
var ataques: Ataques
var sala: Sala
var enemigos: Array = []
var jefe: Jefe = null

var _rejilla: Dictionary = {}
var _puro_t := 0.5


func limpiar() -> void:
	for e in enemigos:
		e.queue_free()
	enemigos.clear()
	_rejilla.clear()
	jefe = null


func crear(tipo: String, posicion: Vector2, multiplicador_vida := 1.0) -> Enemigo:
	var e := Enemigo.new()
	e.position = posicion  # antes de configurar: el uniforme del camarero sale de aquí
	e.configurar(tipo, multiplicador_vida)
	add_child(e)
	enemigos.append(e)
	return e


func anadir_jefe(nuevo: Jefe) -> void:
	jefe = nuevo
	add_child(nuevo)
	enemigos.append(nuevo)


func _physics_process(delta: float) -> void:
	_rehacer_rejilla()
	for e in enemigos.duplicate():
		e.actualizar(delta, self)
	_separar_y_contener()
	_comprobar_contacto()
	_humo_del_puro(delta)
	_retirar_muertos()


func _rehacer_rejilla() -> void:
	_rejilla.clear()
	for e in enemigos:
		var c := _celda(e.position)
		if not _rejilla.has(c):
			_rejilla[c] = []
		_rejilla[c].append(e)


func _celda(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELDA), floori(p.y / CELDA))


func en_radio(centro: Vector2, radio: float) -> Array:
	var encontrados: Array = []
	var margen := radio + 26.0  # el jefe es grande: se mira un poco más lejos
	var cmin := _celda(centro - Vector2(margen, margen))
	var cmax := _celda(centro + Vector2(margen, margen))
	for y in range(cmin.y, cmax.y + 1):
		for x in range(cmin.x, cmax.x + 1):
			var lista = _rejilla.get(Vector2i(x, y))
			if lista == null:
				continue
			for e in lista:
				if e.activo() and e.position.distance_to(centro) <= radio + e.radio:
					encontrados.append(e)
	return encontrados


func mas_cercanos(centro: Vector2, cuantos: int, excluir := {}) -> Array:
	var candidatos: Array = []
	for e in enemigos:
		if e.activo() and not excluir.has(e):
			candidatos.append(e)
	candidatos.sort_custom(func(a, b):
		return a.position.distance_squared_to(centro) < b.position.distance_squared_to(centro))
	return candidatos.slice(0, cuantos)


func danar(e: Enemigo, dano: float, retroceso: Vector2, color := Color8(247, 236, 210)) -> void:
	if e.muerto:
		return
	# La Bala de Plata: más daño a quien de verdad aguanta.
	if e.elite or e is Jefe:
		dano *= 1.0 + Juego.stat("dano_gordos")
	dano = e.reducir_dano(dano, retroceso)  # blindaje y escudo de los raros y élites
	e.aplicar_golpe(dano, retroceso)
	Sonido.tocar("golpe", randf_range(0.85, 1.2), -5.0)
	danio_hecho.emit(e.position + Vector2(0, -8), dano, color)
	if e.vida <= 0.0:
		e.muerto = true


func _separar_y_contener() -> void:
	for e in enemigos:
		if e is Jefe:
			continue
		var c := _celda(e.position)
		for y in range(c.y - 1, c.y + 2):
			for x in range(c.x - 1, c.x + 2):
				var lista = _rejilla.get(Vector2i(x, y))
				if lista == null:
					continue
				for otro in lista:
					if otro == e:
						continue
					var d: Vector2 = e.position - otro.position
					var minimo: float = e.radio + otro.radio
					var l := d.length()
					if l < minimo and l > 0.001:
						e.position += d / l * (minimo - l) * 0.5
		for caja in sala.solidos:
			e.position = Sala.sacar_de_caja(e.position, e.radio, caja)
		# Las mesas, de pie o volcadas, se rodean igual que las columnas.
		for caja in sala.cajas_mesas:
			e.position = Sala.sacar_de_caja(e.position, e.radio, caja)
		var zona := Sala.INTERIOR.grow(-e.radio)
		e.position = e.position.clamp(zona.position, zona.end)


## El órdago: todos salen despedidos desde el centro y se quedan un momento aturdidos.
## Los de cerca vuelan más lejos. Los jefes no se mueven y apenas se aturden.
func empujar_todos(centro: Vector2, fuerza: float, aturdir_seg := 0.0) -> void:
	for e in enemigos:
		if e.muerto:
			continue
		var d: Vector2 = e.position - centro
		var largo := d.length()
		var dir: Vector2 = d / largo if largo > 0.001 else Vector2.RIGHT.rotated(randf() * TAU)
		if not (e is Jefe):
			e.empuje += dir * fuerza * clampf(1.0 - largo / 420.0, 0.35, 1.0)
		if aturdir_seg > 0.0:
			e.aturdir(aturdir_seg)


## Con position y no global_position: el temblor de pantalla mueve el Mundo entero
## (jugador y enemigos a la vez) y no debe cambiar quién toca a quién.
func _comprobar_contacto() -> void:
	if jugadores.size() > 1:
		for j in jugadores:
			if not j.caido:
				_contacto_con(j)
		return
	_contacto_con(jugador)


func _contacto_con(j: Node2D) -> void:
	for e in en_radio(j.position, 5.0):
		if e.hace_contacto:
			j.recibir_golpe(1, causa_de(e))
			break


## A quién va a por un enemigo (o apunta una bala) que está en "pos": al jugador en pie más
## cercano. Con uno solo, siempre a él. Son dos distancias: nada que ordenar.
func objetivo_para(pos: Vector2) -> Node2D:
	if jugadores.size() <= 1:
		return jugador
	var mejor: Node2D = null
	var mejor_d := INF
	for j in jugadores:
		if j.caido:
			continue
		var d: float = pos.distance_squared_to(j.position)
		if d < mejor_d:
			mejor_d = d
			mejor = j
	return mejor if mejor != null else jugador


## Los jugadores en pie (en solitario, el de siempre).
func vivos() -> Array:
	if jugadores.size() <= 1:
		return [jugador]
	return jugadores.filter(func(j): return not j.caido)


## Para los ataques que se reparten (las botellas del Coctelero): uno y otro, por turnos.
func objetivo_por_turno(turno: int) -> Node2D:
	var lista := vivos()
	return lista[posmod(turno, lista.size())] if not lista.is_empty() else jugador


## Lo que se apunta como causa del golpe que da este enemigo (o el jefe de la sala).
static func causa_de(e: Enemigo) -> Dictionary:
	if e is Jefe:
		return {"tipo": "jefe", "id": e.id_jefe}
	return {"tipo": "enemigo", "id": e.tipo, "rango": e.rango}


func _humo_del_puro(delta: float) -> void:
	if Juego.stat("puro") <= 0.0:
		return
	_puro_t -= delta
	if _puro_t > 0.0:
		return
	_puro_t = 0.5
	for j in vivos():
		for e in en_radio(j.position, 42.0):
			e.aplicar_quemadura(3.0)


func _retirar_muertos() -> void:
	var nacen: Array = []
	var mitades: Array = []
	var hubo_bajas := false
	var i := enemigos.size() - 1
	while i >= 0:
		var e = enemigos[i]
		if e.muerto:
			enemigos.remove_at(i)
			Juego.enemigos_eliminados += 1
			Sonido.tocar("muerte", randf_range(0.85, 1.2), -4.0)
			e.al_morir(self)
			if e.rango > 0:
				rango_muerto.emit(e)
				if e.tiene_mod("divisor") and not enemigos.is_empty():
					mitades.append([e.tipo, e.position, e.vida_max, e.vel])
			enemigo_muerto.emit(e.position, e.oro_prob, e.tipo, e.monedas_al_morir, e.elite)
			if e.tipo == "ficha_grande":
				nacen.append(e.position)
			if e == jefe:
				jefe = null
			e.queue_free()
			hubo_bajas = true
		i -= 1
	# Al romperse, una ficha grande se convierte en tres pequeñas.
	for p in nacen:
		for k in 3:
			crear("ficha", p + Vector2.RIGHT.rotated(TAU * k / 3.0) * 8.0).nacer_ya()
	# Un divisor se parte en dos más pequeños, sin rango ni premio.
	for m in mitades:
		for k in 2:
			if enemigos.size() >= Enemigo.TOPE_INVOCADOS:
				break
			var mitad := crear(m[0], m[1] + Vector2.RIGHT.rotated(PI * k + 0.6) * 9.0)
			mitad.vida = float(m[2]) * Enemigo.DIVISOR_VIDA
			mitad.vida_max = mitad.vida
			mitad.vel = m[3]
			mitad.scale = Vector2.ONE * 0.8
			mitad.radio *= 0.8
			mitad.oro_prob *= 0.5
			mitad.nacer_ya()
	# La rejilla no puede quedarse con enemigos que ya no existen.
	if hubo_bajas:
		_rehacer_rejilla()
