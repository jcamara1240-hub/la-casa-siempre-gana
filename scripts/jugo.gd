class_name Jugo
extends Node2D
## El "jugo": lo que hace que cada golpe se note. Paradas de un instante, sacudidas con
## dirección, fogonazos, chispas, casquillos, trozos de ficha, cámara lenta y destellos.
## Solo es sensación: no cambia nada de la partida.
##
## Las partículas no son nodos: viven en listas y cada capa las pinta de una vez en su
## _draw, con un tope, para que vaya fluido en el navegador aunque haya setenta enemigos.
## El ambiente (sombras, luces, restos en el suelo y posproceso) vive en ambiente.gd.

const Ambiente := preload("res://scripts/ambiente.gd")
const TOPE_SUELO := 180
const TOPE_AIRE := 130
const TOPE_TEXTOS := 40
const CHISPAS_POR_FOTOGRAMA := 8
const ESCALA_PARADA := 0.05  # durante una parada el tiempo casi se detiene
const PARADA_MAX := 0.14
const PARADA_RESPIRO := 0.3  # tras una parada, un rato sin paradas pequeñas
const PATADA_MAX := 5.0  # lo más que se desplaza la cámara al empujarla
const GRAVEDAD := 520.0  # para lo que salta y cae: casquillos y trozos
const COLOR_CRITICO := Color8(247, 198, 74)
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_FIEBRE := Color8(240, 129, 60)
const COLOR_ROJO := Color8(214, 61, 79)
const COLOR_HUMO := Color(0.32, 0.27, 0.4, 0.5)  # se ve, pero no ensucia la sala
const FANTASMA_DESATADO := 0.05  # cada cuánto deja una copia el jugador desatado
const CASQUILLO_CADA_MS := 40  # como mucho 25 casquillos por segundo


## Una capa de dibujo: pinta todas sus partículas en un solo _draw.
class Capa extends Node2D:
	var particulas: Array = []
	var habia := false

	func _draw() -> void:
		for p in particulas:
			_pintar(p)
		draw_set_transform(Vector2.ZERO)

	func _pintar(p: Dictionary) -> void:
		var k: float = p.t / p.vida
		var color: Color = p.color
		if k > p.desvanece:
			color.a *= 1.0 - (k - p.desvanece) / (1.0 - p.desvanece)
		if p.has("queda"):
			# Lo que se queda en el suelo se va apagando al caer, hasta el tono de los restos:
			# así no pega un salto al pasar a la capa del ambiente.
			var asienta := clampf((k - 0.5) * 2.0, 0.0, 1.0)
			color = color.lerp(Color(color.darkened(0.55), color.a * 0.7), asienta)
		var escala: float = lerpf(p.escala, p.escala_fin, minf(p.t / p.crece, 1.0))
		var donde: Vector2 = p.pos + Vector2(0.0, -p.z)
		if p.has("texto"):
			draw_set_transform(donde, 0.0, Vector2(escala, escala))
			var base := Vector2(-p.ancho * 0.5, 0.0)
			draw_string(p.fuente, base + Vector2(1, 1), p.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, p.tam, Color(0.08, 0.06, 0.12, color.a))
			draw_string(p.fuente, base, p.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, p.tam, color)
			return
		if p.has("arco"):
			# Un trozo de aro que crece: el roce de una bala, el anillo de una muerte.
			draw_set_transform(donde, p.rot, Vector2(1.0, p.arco_aplaste))
			draw_arc(Vector2.ZERO, p.arco * escala, -p.arco_abre, p.arco_abre, 12, color, p.arco_ancho)
			return
		var region: Rect2 = p.region
		if p.anim > 1:
			region.position.x += mini(int(k * p.anim), p.anim - 1) * region.size.x
		draw_set_transform(donde, p.rot, Vector2(-escala if p.espejo else escala, escala * p.get("aplaste", 1.0)))
		draw_texture_rect_region(p.tex, Rect2(-region.size * 0.5, region.size), region, color)


var _mundo: Node2D
var _jugador  # el de player.gd (sin tipo: no tiene class_name)
var _sprite_jugador: Sprite2D
var _amb  # Ambiente: sombras, luces, restos y posproceso
var _suelo: Capa  # debajo de todos: polvo, estela, casquillos y trozos
var _aire: Capa
var _brillo: Capa  # se suma a la luz: fogonazos, chispas y la onda del órdago
var _textos: Capa
var _todas: Array = []  # las capas que existen ya
var _destello: ColorRect

var _tex_fogonazo: Texture2D
var _tex_chispa: Texture2D
var _tex_casquillo: Texture2D
var _tex_polvo: Texture2D
var _tex_trozos: Texture2D
var _tex_onda: Texture2D

var _parada := 0.0
var _respiro := 0.0
var _lenta := 0.0
var _lenta_total := 1.0
var _lenta_escala := 1.0
var _temblor := 0.0
var _patada := Vector2.ZERO
var _destello_t := 0.0
var _destello_dur := 1.0
var _destello_color := Color.TRANSPARENT
var _chispas_fotograma := 0
var _fantasma_t := 0.0
var _rodaba := false
var _otro  # cooperativo: el J2 (o null). Su estela, su luz y su sombra, como las del J1.
var _otro_fantasma_t := 0.0
var _otro_rodaba := false
var _critico_fotograma := -1
var _critico_pos := Vector2.ZERO
var _ultimo_casquillo := 0


## Un recurso que quizá aún no exista: null en vez de un error.
static func textura(ruta: String) -> Texture2D:
	if ResourceLoader.exists(ruta):
		return load(ruta)
	return null


func _ready() -> void:
	# Siempre activo para poder devolver el tiempo a su ritmo al pausar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_aire = Capa.new()
	add_child(_aire)
	_brillo = Capa.new()
	var suma := CanvasItemMaterial.new()
	suma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_brillo.material = suma
	add_child(_brillo)
	_textos = Capa.new()
	_textos.z_index = 5  # hasta preparar(): luego pasa a la capa alta del ambiente
	add_child(_textos)
	_todas = [_aire, _brillo, _textos]
	_tex_fogonazo = textura("res://assets/efectos/fogonazo.png")
	_tex_chispa = textura("res://assets/efectos/chispa.png")
	_tex_casquillo = textura("res://assets/efectos/casquillo.png")
	_tex_polvo = textura("res://assets/efectos/polvo.png")
	_tex_trozos = textura("res://assets/efectos/ficha_rota.png")
	_tex_onda = textura("res://assets/efectos/onda.png")


## mundo: lo que tiembla. ui: la interfaz (hoy no se usa). jugador: para la estela.
func preparar(mundo: Node2D, ui: Node, jugador) -> void:
	_mundo = mundo
	_jugador = jugador
	_sprite_jugador = jugador.get_node("Sprite")
	_amb = Ambiente.new()
	add_child(_amb)
	_amb.preparar(mundo, ui, jugador, self)  # pone restos, luz y sombras justo sobre la sala
	_suelo = Capa.new()
	mundo.add_child(_suelo)
	mundo.move_child(_suelo, 4)  # encima de las sombras, debajo de todo lo demás
	_todas.append(_suelo)
	# El destello y los números van encima del posproceso pero debajo del jugador y de las
	# balas enemigas: ningún efecto tapa lo que te puede dar. (ui ya no hace falta.)
	var alta: Node2D = _amb.capa_alta()
	_destello = ColorRect.new()
	_destello.position = -Vector2.ONE * Ambiente.MARGEN_POST
	_destello.size = Vector2(640.0 + Ambiente.MARGEN_POST * 2.0, 304.0 + Ambiente.MARGEN_POST)
	_destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_destello.color = Color(1, 1, 1, 0)
	alta.add_child(_destello)
	if _textos != null and _textos.get_parent() == self:
		remove_child(_textos)
		_textos.z_index = 0
		alta.add_child(_textos)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Al cambiar de sala, al acabar la partida o al volver al menú.
func limpiar() -> void:
	for capa in _todas:
		capa.particulas.clear()
		capa.queue_redraw()
	if _amb != null:
		_amb.limpiar()
	_parada = 0.0
	_respiro = 0.0
	_lenta = 0.0
	Engine.time_scale = 1.0
	_temblor = 0.0
	_patada = Vector2.ZERO
	if _mundo != null:
		_mundo.position = Vector2.ZERO
	_destello_t = 0.0
	if _destello != null:
		_destello.color.a = 0.0


func _process(delta: float) -> void:
	if get_tree().paused:
		# En los menús el tiempo va a su ritmo, y al volver no queda nada a medias.
		_parada = 0.0
		_lenta = 0.0
		Engine.time_scale = 1.0
		if _destello != null:
			_destello.color.a = 0.0
		return
	# Lo que dura de verdad este fotograma, sin la cámara lenta.
	var real := delta / maxf(Engine.time_scale, 0.001)
	_aplicar_tiempo(real)
	_aplicar_sacudida(real)
	_aplicar_destello(real)
	_seguir_voltereta(delta)
	_chispas_fotograma = 0
	for capa in _todas:
		_mover(capa.particulas, delta)
		var hay: bool = not capa.particulas.is_empty()
		if hay or capa.habia:
			capa.queue_redraw()
		capa.habia = hay


# ------------------------------------------------------------ tiempo
## Una parada de un instante (hit-stop). No se suman: manda la más larga.
## Las pequeñas se saltan si acaba de haber otra; forzar la hace igualmente.
func parar(seg: float, forzar := false) -> void:
	if not forzar and _respiro > 0.0:
		return
	_parada = maxf(_parada, minf(seg, PARADA_MAX))
	_respiro = maxf(_respiro, _parada + PARADA_RESPIRO)


## Un momento de cine: franjas negras, la cámara se acerca a pos y la sala da un latigazo de luz.
func cine(seg: float, pos: Vector2, zoom := 0.07) -> void:
	if _amb == null:
		return
	_amb.cine(seg)
	_amb.golpe_zoom(zoom, pos)
	_amb.pulso(1.0)


func golpe_jugador() -> void:
	if _amb != null:
		_amb.golpe()


func camara_lenta(seg: float, escala: float) -> void:
	if _lenta > 0.0 and _lenta_escala <= escala and _lenta >= seg:
		return
	_lenta = seg
	_lenta_total = seg
	_lenta_escala = escala
	# Las cámaras lentas gordas (el remate de un jefe) se acercan un poco.
	if escala <= 0.3 and _amb != null and _jugador != null:
		_amb.golpe_zoom(0.04, _jugador.position)


func _aplicar_tiempo(real: float) -> void:
	_parada = maxf(_parada - real, 0.0)
	_respiro = maxf(_respiro - real, 0.0)
	_lenta = maxf(_lenta - real, 0.0)
	var escala := 1.0
	if _lenta > 0.0:
		# En el último tercio vuelve poco a poco a la velocidad normal.
		escala = lerpf(1.0, _lenta_escala, clampf(_lenta / (_lenta_total * 0.35), 0.0, 1.0))
	if _parada > 0.0:
		escala = minf(escala, ESCALA_PARADA)
	# Se fija en cada fotograma: así nunca se queda colgado un valor viejo.
	Engine.time_scale = escala


# ------------------------------------------------------------ cámara y pantalla
## Temblor de pantalla; con dirección, además la empuja hacia ese lado.
func sacudir(fuerza: float, direccion := Vector2.ZERO) -> void:
	if not Juego.sacudida:
		return
	_temblor = maxf(_temblor, fuerza)
	if direccion != Vector2.ZERO:
		_patada = (_patada + direccion.normalized() * fuerza * 0.6).limit_length(PATADA_MAX)


## El retroceso de la cámara al disparar: se va un poco hacia atrás.
func empujar_camara(direccion: Vector2, fuerza: float) -> void:
	if not Juego.sacudida or direccion == Vector2.ZERO:
		return
	_patada = (_patada - direccion.normalized() * fuerza).limit_length(PATADA_MAX)


func _aplicar_sacudida(real: float) -> void:
	if _mundo == null:
		return
	if not Juego.sacudida:
		_temblor = 0.0
		_patada = Vector2.ZERO
		_mundo.position = Vector2.ZERO
		return
	_temblor = maxf(0.0, _temblor - real * 30.0)
	_patada = _patada.lerp(Vector2.ZERO, clampf(real * 12.0, 0.0, 1.0))
	var desvio := Vector2.ZERO
	if _temblor > 0.0:
		desvio = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * ceilf(_temblor * 0.4)
	_mundo.position = (desvio + _patada).round()


## Un fogonazo de color sobre la sala. Sin sacudida (ajuste de accesibilidad), más suave.
func destello(color: Color, seg := 0.18) -> void:
	if _destello == null:
		return
	_destello_color = color
	if not Juego.sacudida:
		_destello_color.a *= 0.5
	_destello_dur = maxf(seg, 0.01)
	_destello_t = _destello_dur


func _aplicar_destello(real: float) -> void:
	if _destello == null or _destello_t <= 0.0:
		return
	_destello_t = maxf(_destello_t - real, 0.0)
	var c := _destello_color
	c.a *= _destello_t / _destello_dur
	_destello.color = c


# ------------------------------------------------------------ respuestas a las señales
## Ataques.disparo: fogonazo, casquillo, retroceso del dibujo y de la cámara.
func al_disparar(origen: Vector2, direccion: Vector2, fuerza: float) -> void:
	if direccion == Vector2.ZERO:
		return
	var dir := direccion.normalized()
	fogonazo(origen, dir, fuerza)
	casquillo(origen, dir)
	if _amb != null:
		_amb.luz(origen + dir * 6.0, 26.0 + 10.0 * fuerza, Color(1.0, 0.8, 0.45, 0.35 + 0.1 * fuerza), 0.08 + 0.03 * fuerza)
	if fuerza >= 2.0:
		casquillo(origen, dir)
		sacudir(1.5 * fuerza, -dir)
	empujar_camara(dir, 0.8 * fuerza)
	if _jugador != null:
		var quien = _jugador
		if _otro != null and is_instance_valid(_otro) and _otro.position.distance_squared_to(origen) < _jugador.position.distance_squared_to(origen):
			quien = _otro
		quien.patada(dir, 1.0 + fuerza * 0.5)
	if fuerza >= 3.0:
		parar(0.03)


## Ataques.impacto: chispas; los golpes dobles, más grandes y con una parada mínima.
func al_impactar(posicion: Vector2, direccion: Vector2, critico: bool) -> void:
	chispas(posicion, direccion, critico)
	if critico:
		_critico_fotograma = Engine.get_physics_frames()
		_critico_pos = posicion
		parar(0.02)
		if _amb != null:
			_amb.luz(posicion, 22.0, Color(1.0, 0.85, 0.4, 0.45), 0.12)
		_disco(posicion, 0.5, 0.08, Color(1.0, 0.95, 0.7, 0.9))


## Ataques.explosion_en: sacude según lo grande que sea, empuja la cámara desde el centro,
## y deja onda, humo, luz y una quemadura en el suelo.
func al_explotar(centro: Vector2, radio: float) -> void:
	var dir := Vector2.ZERO
	if _jugador != null:
		dir = _jugador.position - centro
	sacudir(clampf(radio / 10.0, 2.0, 6.0), dir)
	for i in 3:
		chispas(centro + Vector2.RIGHT.rotated(randf() * TAU) * radio * 0.5, Vector2.RIGHT.rotated(randf() * TAU), false)
	polvo(centro, 2)
	_anillo(centro, radio, 0.24, Color(1.0, 0.8, 0.5, 0.8))
	_disco(centro, radio / 26.0, 0.06, Color(1.0, 0.95, 0.8, 0.6))
	humo(centro, clampi(int(radio / 12.0), 2, 5), radio * 0.5)
	if _amb != null:
		_amb.luz(centro, radio * 2.4, Color(1.0, 0.6, 0.3, 0.55), 0.3)
		_amb.quemadura(centro, radio)
		if radio >= 45.0:
			_amb.golpe_zoom(0.015, centro)


func al_rodar(direccion: Vector2, quien = null) -> void:
	if quien == null:
		quien = _jugador
	if quien != null:
		polvo(quien.position + Vector2(0, 6), 4, direccion)


## Cooperativo: el segundo jugador también deja estela, tiene luz y sombra (null lo quita).
func poner_segundo(j2) -> void:
	_otro = j2
	if _amb != null:
		_amb.otros = [] if j2 == null else [j2]


## Para los números de daño: ¿acaba de haber un golpe doble aquí mismo?
func fue_critico(posicion: Vector2) -> bool:
	return _critico_fotograma == Engine.get_physics_frames() and posicion.distance_to(_critico_pos) < 24.0


## La estela mientras ruedas o vas desatado, y el polvo al aterrizar.
func _seguir_voltereta(delta: float) -> void:
	if _jugador == null:
		return
	var rueda: bool = _jugador.rodando()
	var desatado: bool = Juego.get("desatado") == true
	if rueda or desatado:
		_fantasma_t -= delta
		if _fantasma_t <= 0.0:
			_fantasma_t = 0.035 if rueda else FANTASMA_DESATADO
			if desatado:
				fantasma(_sprite_jugador, Color(1.0, 0.7, 0.35, 0.5) if randf() < 0.5 else Color(1.0, 0.45, 0.6, 0.45))
			else:
				fantasma(_sprite_jugador)
	if not rueda and _rodaba:
		polvo(_jugador.position + Vector2(0, 6), 3)
	_rodaba = rueda
	if _otro == null or not is_instance_valid(_otro):
		return
	var rueda2: bool = _otro.rodando()
	if rueda2 or (desatado and not _otro.caido):
		_otro_fantasma_t -= delta
		if _otro_fantasma_t <= 0.0:
			_otro_fantasma_t = 0.035 if rueda2 else FANTASMA_DESATADO
			fantasma(_otro.get_node("Sprite"), Color(0.75, 0.85, 1.0, 0.45) if rueda2 else Color(1.0, 0.7, 0.35, 0.5), _otro)
	if not rueda2 and _otro_rodaba:
		polvo(_otro.position + Vector2(0, 6), 3)
	_otro_rodaba = rueda2


# ------------------------------------------------------------ lo nuevo que llama main
## Al entrar en cada sala: se ambienta con su tipo y su piso y se va lo de la anterior.
func al_entrar_sala(tipo: int, piso: int) -> void:
	if _amb != null:
		_amb.entrar_sala(tipo, piso)


## Una marca en el suelo, que se cierra, donde va a aparecer un enemigo dentro de seg.
func aviso_nacimiento(pos: Vector2, seg: float) -> void:
	if _amb != null:
		_amb.marca_nacimiento(pos, seg)


## Una bala te ha pasado rozando: un arco de chispa a tu lado, hacia donde venía.
func roce(pos: Vector2) -> void:
	if _brillo == null:
		return
	var centro: Vector2 = _jugador.position if _jugador != null else pos
	var hacia := pos - centro
	if hacia.length() < 0.5:
		hacia = Vector2.UP
	# Por fuera del dibujo del jugador (mide 16): si no, el arco queda tapado.
	var p := _nueva(null, 1, centro, 0.18)
	p["arco"] = 12.0
	p["arco_abre"] = 0.8
	p["arco_ancho"] = 1.0
	p["arco_aplaste"] = 1.0
	p.rot = hacia.angle()
	p.escala = 0.85
	p.escala_fin = 1.6
	p.crece = 0.18
	p.color = Color(0.75, 0.9, 1.0, 0.95)
	p.desvanece = 0.3
	if _brillo.particulas.size() < TOPE_AIRE:
		_brillo.particulas.append(p)
	chispas(centro + hacia.normalized() * 7.0, hacia, false)
	if _amb != null:
		_amb.luz(centro, 18.0, Color(0.6, 0.85, 1.0, 0.4), 0.12)


## Una baja especial (la última de la sala, una élite, una encadenada): más que una normal.
func remate(pos: Vector2) -> void:
	_disco(pos, 1.4, 0.08, Color(1.0, 1.0, 0.95, 0.8))
	_anillo(pos, 34.0, 0.3, Color(1.0, 0.85, 0.5, 0.9))
	_anillo(pos, 20.0, 0.22, Color(1.0, 0.5, 0.4, 0.7))
	trozos(pos, 10, 1.4)
	for i in 3:
		chispas(pos, Vector2.RIGHT.rotated(TAU * i / 3.0 + randf()), true)
	if _amb != null:
		_amb.luz(pos, 90.0, Color(1.0, 0.75, 0.45, 0.6), 0.35)
		_amb.golpe_zoom(0.02, pos)
	sacudir(4.0)


## Entra una oleada nueva: un rótulo breve arriba del todo.
func oleada(numero: int, total: int) -> void:
	if _amb != null:
		_amb.oleada(numero, total)


# ------------------------------------------------------------ partículas
func _nueva(tex: Texture2D, cuadros: int, pos: Vector2, vida: float) -> Dictionary:
	var region := Rect2()
	if tex != null:
		region = Rect2(0, 0, float(tex.get_width()) / cuadros, tex.get_height())
	return {"tex": tex, "region": region, "anim": cuadros, "pos": pos, "vel": Vector2.ZERO,
		"z": 0.0, "vz": 0.0, "cae": false, "rot": 0.0, "giro": 0.0, "friccion": 0.0,
		"escala": 1.0, "escala_fin": 1.0, "crece": vida, "t": 0.0, "vida": vida,
		"desvanece": 0.6, "color": Color.WHITE, "espejo": false}


## Un fotograma concreto de la tira, sin animar.
func _cuadro_fijo(p: Dictionary, cuadro: int) -> void:
	var region: Rect2 = p.region
	region.position.x = cuadro * region.size.x
	p.region = region
	p.anim = 1


func _mover(lista: Array, delta: float) -> void:
	var i := lista.size() - 1
	while i >= 0:
		var p: Dictionary = lista[i]
		p.t += delta
		if p.t >= p.vida:
			# Lo que se queda en el suelo pasa a los restos del ambiente.
			if p.get("queda", false) and _amb != null:
				_amb.pieza(p)
			# Se quita cambiándola por la última: no hay que mover toda la lista.
			lista[i] = lista[lista.size() - 1]
			lista.pop_back()
			i -= 1
			continue
		p.pos += p.vel * delta
		p.rot += p.giro * delta
		if p.friccion > 0.0:
			p.vel = p.vel.lerp(Vector2.ZERO, clampf(delta * p.friccion, 0.0, 1.0))
		if p.cae:
			p.vz -= GRAVEDAD * delta
			p.z += p.vz * delta
			if p.z <= 0.0:
				p.z = 0.0
				if p.vz < -60.0:  # rebota una vez, flojito
					p.vz = -p.vz * 0.35
					p.vel *= 0.5
					p.giro *= 0.5
				else:
					p.vz = 0.0
					p.vel = Vector2.ZERO
					p.giro = 0.0
		i -= 1


func fogonazo(pos: Vector2, dir: Vector2, fuerza: float) -> void:
	if _tex_fogonazo == null or _brillo.particulas.size() >= TOPE_AIRE:
		return
	var p := _nueva(_tex_fogonazo, 3, pos + dir * 7.0, 0.06 + 0.02 * fuerza)
	p.rot = dir.angle()
	p.escala = 0.7 + 0.3 * fuerza
	p.escala_fin = p.escala
	p.desvanece = 0.7
	_brillo.particulas.append(p)


func chispas(pos: Vector2, dir: Vector2, critico := false) -> void:
	if _tex_chispa == null or _chispas_fotograma >= CHISPAS_POR_FOTOGRAMA:
		return
	_chispas_fotograma += 1
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT.rotated(randf() * TAU)
	for i in (3 if critico else 1):
		if _brillo.particulas.size() >= TOPE_AIRE:
			return
		var p := _nueva(_tex_chispa, 4, pos, 0.14 if critico else 0.11)
		p.rot = d.angle() + randf_range(-0.5, 0.5) + ((i - 1) * 0.8 if critico else 0.0)
		p.escala = 1.5 if critico else 1.0
		p.escala_fin = p.escala
		p.vel = d * 25.0
		p.friccion = 10.0
		if critico:
			p.color = Color(1.2, 1.0, 0.5)
		_brillo.particulas.append(p)


func casquillo(pos: Vector2, dir: Vector2) -> void:
	if _tex_casquillo == null or _suelo == null or _suelo.particulas.size() >= TOPE_SUELO:
		return
	# Con la metralleta desatada saldrían decenas por segundo: uno cada poco basta para
	# que se note, y el suelo (y el sonido) no se saturan.
	var ahora := Time.get_ticks_msec()
	if ahora - _ultimo_casquillo < CASQUILLO_CADA_MS:
		return
	_ultimo_casquillo = ahora
	var p := _nueva(_tex_casquillo, 1, pos, randf_range(0.8, 1.1))
	var lado := dir.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	p.vel = lado * randf_range(30.0, 60.0) - dir * randf_range(10.0, 30.0)
	p.z = 6.0
	p.vz = randf_range(90.0, 140.0)
	p.cae = true
	p.giro = randf_range(-22.0, 22.0)
	p.desvanece = 1.0
	p["queda"] = true  # se queda en el suelo el resto de la sala
	_suelo.particulas.append(p)
	Sonido.tocar("casquillo", randf_range(0.9, 1.3), -16.0)


## El estallido de una ficha al morir: destello, un aro y trozos de colores que saltan,
## rebotan y se quedan en el suelo.
func trozos(pos: Vector2, cuantos: int, fuerza := 1.0) -> void:
	var grande := cuantos >= 9
	_disco(pos, 0.9 if grande else 0.6, 0.07, Color(1.0, 1.0, 1.0, 0.9))
	_anillo(pos, 16.0 if grande else 10.0, 0.18, Color(COLOR_CREMA, 0.75))
	if _amb != null:
		_amb.luz(pos, 40.0 if grande else 26.0, Color(1.0, 0.8, 0.6, 0.35), 0.16)
	if _tex_trozos == null or _suelo == null:
		return
	# Con el suelo ya muy lleno (muchas bajas seguidas), la mitad de trozos: se sigue viendo
	# el estallido y no se dispara el coste.
	if _suelo.particulas.size() > TOPE_SUELO * 0.5:
		cuantos = ceili(cuantos * 0.5)
	for i in cuantos:
		if _suelo.particulas.size() >= TOPE_SUELO:
			return
		var p := _nueva(_tex_trozos, 4, pos, randf_range(0.6, 0.95))
		_cuadro_fijo(p, randi() % 4)
		p.vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 110.0) * fuerza
		p.z = 4.0
		p.vz = randf_range(80.0, 170.0)
		p.cae = true
		p.giro = randf_range(-16.0, 16.0)
		p.desvanece = 1.0
		p["queda"] = true
		_suelo.particulas.append(p)


func polvo(pos: Vector2, cuantos: int, dir := Vector2.ZERO) -> void:
	if _tex_polvo == null or _suelo == null:
		return
	for i in cuantos:
		if _suelo.particulas.size() >= TOPE_SUELO:
			return
		var p := _nueva(_tex_polvo, 4, pos + Vector2(randf_range(-4, 4), randf_range(-2, 2)), randf_range(0.28, 0.4))
		p.vel = -dir * randf_range(10.0, 30.0) + Vector2(randf_range(-12, 12), randf_range(-14, -4))
		p.friccion = 4.0
		p.escala = 0.8
		p.escala_fin = 1.3
		p.color = Color(1, 1, 1, 0.85)
		p.desvanece = 0.4
		_suelo.particulas.append(p)


## Humo oscuro que sube despacio: explosiones y apariciones.
func humo(pos: Vector2, cuantos: int, dispersion := 6.0) -> void:
	if _tex_polvo == null or _aire == null:
		return
	for i in cuantos:
		if _aire.particulas.size() >= TOPE_AIRE:
			return
		var p := _nueva(_tex_polvo, 4, pos + Vector2(randf_range(-1, 1), randf_range(-0.6, 0.6)) * dispersion, randf_range(0.5, 0.8))
		p.vel = Vector2(randf_range(-10, 10), randf_range(-26, -12))
		p.friccion = 1.5
		p.escala = 1.2
		p.escala_fin = 2.4
		p.color = COLOR_HUMO
		p.desvanece = 0.3
		p.espejo = randf() < 0.5
		_aire.particulas.append(p)


## La onda del órdago: un anillo que crece hasta casi llenar la sala.
func onda(pos: Vector2) -> void:
	if _tex_onda == null:
		return
	for i in 2:
		var p := _nueva(_tex_onda, 1, pos, 0.42 + i * 0.12)
		p.escala = 0.2
		p.escala_fin = 6.5 - i * 2.0
		p.desvanece = 0.25
		_brillo.particulas.append(p)
	if _amb != null:
		_amb.luz(pos, 150.0, Color(0.9, 0.95, 1.0, 0.5), 0.35)
		_amb.golpe_zoom(0.03, pos)


## Un aro fino que se abre y se apaga (por encima de todo lo del suelo, sumando luz).
func _anillo(pos: Vector2, radio: float, vida: float, color: Color) -> void:
	if _tex_onda == null or _brillo == null or _brillo.particulas.size() >= TOPE_AIRE:
		return
	var p := _nueva(_tex_onda, 1, pos, vida)
	var lado := float(_tex_onda.get_width()) * 0.5
	p.escala = radio / lado * 0.35
	p.escala_fin = radio / lado
	p.crece = vida * 0.8
	p.desvanece = 0.2
	p.color = color
	p["aplaste"] = 0.6  # un poco tumbado, como si estuviera en el suelo
	_brillo.particulas.append(p)


## Un disco blanco que se encoge enseguida: el destello de un golpe gordo o de una muerte.
func _disco(pos: Vector2, escala: float, vida: float, color: Color) -> void:
	if _amb == null or _brillo == null or _brillo.particulas.size() >= TOPE_AIRE:
		return
	var p := _nueva(_amb.tex_disco, 1, pos, vida)
	p.escala = escala
	p.escala_fin = escala * 0.3
	p.desvanece = 0.3
	p.color = color
	_brillo.particulas.append(p)


## Una copia del jugador que se desvanece: la estela de la voltereta (y del desatado).
func fantasma(sprite: Sprite2D, color := Color(0.75, 0.85, 1.0, 0.45), quien = null) -> void:
	if sprite == null or sprite.texture == null or _suelo == null or _suelo.particulas.size() >= TOPE_SUELO:
		return
	var tex := sprite.texture
	var w := float(tex.get_width()) / sprite.hframes
	var h := float(tex.get_height()) / sprite.vframes
	var p := _nueva(tex, 1, (quien if quien != null else _jugador).position + sprite.position, 0.16 if color.a < 0.5 else 0.22)
	p.region = Rect2(sprite.frame_coords.x * w, sprite.frame_coords.y * h, w, h)
	p.rot = sprite.rotation
	p.escala = sprite.scale.y
	p.escala_fin = sprite.scale.y
	p.espejo = sprite.flip_h
	p.color = color
	p.desvanece = 0.0
	_suelo.particulas.append(p)


## Los números de daño. Los golpes dobles salen grandes, dorados y con un "!".
func numero_dano(pos: Vector2, cantidad: float, color: Color, critico: bool) -> void:
	if not Juego.numeros_dano:
		return
	var cifra := str(maxi(1, roundi(cantidad)))
	if critico:
		_texto(pos + Vector2(randf_range(-4, 4), -8), cifra + "!", COLOR_CRITICO, true, 0.55)
	else:
		_texto(pos + Vector2(randf_range(-5, 3), -6), cifra, color, false, 0.4)


## Un aviso que flota un momento (¡POR LOS PELOS!, FIEBRE 2...). Ya traducido.
func texto(pos: Vector2, contenido: String, color := COLOR_CREMA, grande := false) -> void:
	_texto(pos, contenido, color, grande, 0.9)


func _texto(pos: Vector2, contenido: String, color: Color, grande: bool, vida: float) -> void:
	if _textos == null or _textos.particulas.size() >= TOPE_TEXTOS:
		return
	var fuente: Font = Juego.fuente_grande if grande else Juego.fuente
	var tam := 16 if grande else 8
	var p := _nueva(null, 1, pos, vida)
	p["texto"] = contenido
	p["fuente"] = fuente
	p["tam"] = tam
	p["ancho"] = fuente.get_string_size(contenido, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	p.vel = Vector2(0, -30.0)
	p.color = color
	p.escala = 1.6 if grande else 1.0
	p.crece = 0.12
	p.desvanece = 0.35
	_textos.particulas.append(p)
