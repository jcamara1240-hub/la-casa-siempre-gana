extends Node
## El ambiente de cada sala: sombras, luces, lo que se queda en el suelo, los avisos de
## ataque y el posproceso (viñeta, Fiebre, desatado y al límite). Solo es aspecto.
## Cada capa pinta todo lo suyo en un único _draw y con topes: nada de un nodo por cosa.
## Lo crea el jugo, que es quien le pasa los golpes, las explosiones y las bajas.

const SHADER_POST := preload("res://shaders/posproceso.gdshader")
const TOPE_PIEZAS := 260  # casquillos y trozos de ficha que se quedan en el suelo
const TOPE_QUEMADOS := 28
const TOPE_LUCES := 56
const TOPE_MARCAS := 40
const MARGEN_POST := 48.0
const CENTRO_PANTALLA := Vector2(320, 152)
const ZOOM_MAX := 1.1  # antes 1,06: los momentos de cine se acercan más
const TOPE_LUCES_BALA := 110  # balas enemigas que iluminan el suelo
const CINE_ALTO := 20.0  # píxeles de cada franja negra en los momentos de cine
# Los focos del casino que barren la sala en plena pelea, un color por piso.
const COLOR_FOCOS := [Color(1.0, 0.85, 0.55), Color(0.55, 0.8, 1.0), Color(0.55, 1.0, 0.7), Color(1.0, 0.65, 0.35), Color(1.0, 0.4, 0.5)]
const OLEADA_DURA := 1.5  # lo que dura el rótulo de una oleada
# Los que avisan antes de atacar con su fotograma 3.
const AVISAN := {"crupier": true, "maton": true, "botones": true, "naipe": true, "sota": true}
# Los que van por el aire: su sombra se separa del dibujo.
const VUELAN := {"dado": true, "dado_bomba": true}
const COLOR_SOMBRA := Color(0.03, 0.02, 0.07, 0.45)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_AVISO := Color8(214, 61, 79)
const COLOR_FIEBRE := Color8(240, 129, 60)


## Una capa que se pinta llamando a una función del ambiente.
class Lienzo extends Node2D:
	var pintar: Callable

	func _draw() -> void:
		pintar.call(self)


var _mundo: Node2D
var _jugador  # el de player.gd
var _jugo  # Jugo: para el humo y los trozos al aparecer
var _restos: Lienzo
var _luz: Lienzo
var _penumbra: Lienzo
var _sombras: Lienzo
var _avisos: Lienzo
var _post_raiz: Node2D
var _post: ColorRect
var _mat: ShaderMaterial
var _rotulos: Lienzo

var tex_luz: Texture2D
var tex_sombra: Texture2D
var tex_disco: Texture2D
var _tex_quemado: Texture2D
var _tex_adornos: Texture2D

var _piezas: Array = []  # [textura, región, posición, giro, escala, color, espejo]
var _piezas_i := 0  # la siguiente que se pisa cuando ya no caben más
var _quemados: Array = []  # [posición, escala, giro, variante]
var _restos_sucio := false
var _restos_espera := 0.0
var _luces: Array = []  # las de un momento: explosiones, fogonazos, apariciones
var _marcas: Array = []  # avisos de nacimiento: [posición, t, seg]
var _columnas: Array = []  # columnas de luz al aparecer un enemigo: [posición, t, radio]
var _vistos := {}
var _t := 0.0
var _version_sala := -1
var _encendido := 1.0  # 0 al entrar: los neones se encienden a trompicones
var _tipo_sala := 1
var _piso := 1

# Lo que se le pasa al posproceso, suavizado para que nada pegue saltos.
var _fiebre_v := 0.0
var _lineas_v := 0.0
var _desatado_v := 0.0
var _limite_v := 0.0
var _vineta_v := 0.38
var _zoom := 1.0
var _combate_v := 0.0  # 0..1: lo metida que está la sala en la pelea (penumbra y focos)
var _penumbra_v := 0.0
var _golpe_v := 0.0  # el fogonazo de cuando te dan
var _cine_t := 0.0
var _cine_v := 0.0
var _pulso := 0.0  # un latigazo de luz: oleada nueva, jefe que entra
var _zoom_centro := CENTRO_PANTALLA

# El rótulo de la oleada.
var _oleada_t := 0.0
var _oleada_texto := ""
var _oleada_ultima := false
var _oleada_grande := false


func preparar(mundo: Node2D, _ui: Node, jugador, jugo) -> void:
	_mundo = mundo
	_jugador = jugador
	_jugo = jugo
	tex_luz = _textura_luz()
	tex_sombra = _textura_elipse(24, 10)
	tex_disco = _textura_elipse(16, 16)
	_tex_quemado = _cargar("res://assets/efectos/quemado.png")
	_tex_adornos = _cargar("res://assets/baldosas/adornos.png")
	# Justo encima del suelo de la sala, en este orden: restos, luz, sombras.
	_restos = _lienzo(_pintar_restos)
	mundo.add_child(_restos)
	mundo.move_child(_restos, 1)
	# La penumbra: en plena pelea la sala se apaga un poco y todo lo que brilla, brilla más.
	_penumbra = _lienzo(_pintar_penumbra)
	mundo.add_child(_penumbra)
	mundo.move_child(_penumbra, 2)
	_luz = _lienzo(_pintar_luz)
	var suma := CanvasItemMaterial.new()
	suma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_luz.material = suma
	_luz.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mundo.add_child(_luz)
	mundo.move_child(_luz, 3)
	_sombras = _lienzo(_pintar_sombras)
	mundo.add_child(_sombras)
	mundo.move_child(_sombras, 4)
	# Los avisos de ataque van por encima del posproceso, como el jugador y las balas.
	_avisos = _lienzo(_pintar_avisos)
	_avisos.z_index = 2
	mundo.add_child(_avisos)
	_crear_post()
	# El rótulo de la oleada va justo encima del posproceso y por debajo de las balas.
	_rotulos = _lienzo(_pintar_rotulos.unbind(1))
	_post_raiz.add_child(_rotulos)


## El latido de "al límite" (0..1, dos golpes por compás), con reloj real: así la viñeta
## del posproceso y los corazones del marcador laten a la vez.
static func latido() -> float:
	var fase := fmod(Time.get_ticks_msec() / 1000.0 * 1.25, 1.0)
	return minf(pow(maxf(0.0, cos(fase * TAU)), 16.0) + 0.6 * pow(maxf(0.0, cos((fase - 0.18) * TAU)), 16.0), 1.0)


static func _cargar(ruta: String) -> Texture2D:
	return load(ruta) if ResourceLoader.exists(ruta) else null


func _lienzo(funcion: Callable) -> Lienzo:
	var l := Lienzo.new()
	l.pintar = funcion
	return l


## La capa que queda encima del posproceso (sin temblor) pero debajo del jugador, las
## balas enemigas y los avisos (z 2): ahí van el destello, los rótulos y los números.
func capa_alta() -> Node2D:
	return _post_raiz


## Un rectángulo a pantalla completa (con margen para el temblor y el zoom) entre el mundo
## y lo que tiene que verse siempre: jugador, balas enemigas, avisos e interfaz.
func _crear_post() -> void:
	_post_raiz = Node2D.new()
	_post_raiz.z_index = 1
	_mundo.add_child(_post_raiz)
	_post = ColorRect.new()
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.position = -Vector2.ONE * MARGEN_POST
	_post.size = Vector2(640, 360) + Vector2.ONE * MARGEN_POST * 2.0
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER_POST
	_post.material = _mat
	_post_raiz.add_child(_post)


static func _textura_luz() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## Una elipse blanca y dura (pixel art): sombras, discos de destello.
static func _textura_elipse(an: int, al: int) -> Texture2D:
	var img := Image.create(an, al, false, Image.FORMAT_RGBA8)
	for y in al:
		for x in an:
			var dx := (x + 0.5 - an * 0.5) / (an * 0.5)
			var dy := (y + 0.5 - al * 0.5) / (al * 0.5)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


func limpiar() -> void:
	_piezas.clear()
	_piezas_i = 0
	_quemados.clear()
	_luces.clear()
	_marcas.clear()
	_columnas.clear()
	_vistos.clear()
	_restos_sucio = true
	_zoom = 1.0
	_aplicar_zoom()
	if _restos != null:
		_restos.queue_redraw()


# ------------------------------------------------------------ cada fotograma
func _process(delta: float) -> void:
	if _mundo == null:
		return
	if get_tree().paused:
		if _zoom != 1.0:
			_zoom = 1.0
			_aplicar_zoom()
		return
	var real := delta / maxf(Engine.time_scale, 0.001)
	_t += delta
	_encendido = minf(_encendido + real * 1.4, 1.0)
	_mirar_sala()
	_envejecer(delta)
	_mirar_apariciones()
	_post_raiz.position = -_mundo.position
	_actualizar_post(real)
	if _zoom != 1.0:
		_zoom = move_toward(_zoom, 1.0, real * 0.35)
		_aplicar_zoom()
	_restos_espera -= real
	if _restos_sucio and _restos_espera <= 0.0:
		_restos_sucio = false
		_restos_espera = 0.05
		_restos.queue_redraw()
	_pulso = maxf(_pulso - real * 2.2, 0.0)
	_golpe_v = maxf(_golpe_v - real * 3.5, 0.0)
	_cine_t = maxf(_cine_t - real, 0.0)
	_cine_v = move_toward(_cine_v, 1.0 if _cine_t > 0.0 else 0.0, real * 4.0)
	_penumbra.queue_redraw()
	_luz.queue_redraw()
	_sombras.queue_redraw()
	_avisos.queue_redraw()
	if _oleada_t > 0.0:
		_oleada_t = maxf(_oleada_t - real, 0.0)
		_rotulos.queue_redraw()  # también el último fotograma, para que se borre


## Si la sala ha cambiado y nadie nos lo ha dicho, se ambienta sola con el piso actual.
func _mirar_sala() -> void:
	var sala = _sala()
	if sala == null or sala.version == _version_sala:
		return
	entrar_sala(sala.tipo_sala(), Juego.piso)


## Lo de la sala anterior se va; las marcas de nacimiento de esta, si ya las hay, se quedan.
func entrar_sala(tipo: int, piso: int) -> void:
	_tipo_sala = tipo
	_piso = piso
	_piezas.clear()
	_piezas_i = 0
	_quemados.clear()
	_restos_sucio = true
	_encendido = 0.0
	_oleada_t = 0.0
	if _rotulos != null:
		_rotulos.queue_redraw()
	var sala = _sala()
	if sala != null:
		_version_sala = sala.version
		if sala.piso != piso:
			sala.ambientar(piso)


func _sala():
	if _jugador == null or _jugador.sala == null:
		return null
	return _jugador.sala


func _horda():
	if _jugador == null:
		return null
	return _jugador.horda


func _envejecer(delta: float) -> void:
	for lista in [_luces, _marcas, _columnas]:
		var i: int = lista.size() - 1
		while i >= 0:
			var cosa: Array = lista[i]
			cosa[1] += delta
			if cosa[1] >= cosa[2]:
				lista[i] = lista[lista.size() - 1]
				lista.pop_back()
			i -= 1


## Cada enemigo nuevo sale de una columna de luz con un poco de humo.
func _mirar_apariciones() -> void:
	var horda = _horda()
	if horda == null:
		return
	if _vistos.size() > horda.enemigos.size() * 3 + 64:
		_vistos.clear()
		for e in horda.enemigos:
			_vistos[e.get_instance_id()] = true
	for e in horda.enemigos:
		var id: int = e.get_instance_id()
		if _vistos.has(id):
			continue
		_vistos[id] = true
		if e.activo() or _columnas.size() >= TOPE_MARCAS:
			continue
		var r: float = e.radio
		_columnas.append([e.position, 0.0, 0.5 if r < 15.0 else 0.9, r])
		if _jugo != null:
			_jugo.humo(e.position + Vector2(0, r * 0.6), 2 if r < 15.0 else 6)


# ------------------------------------------------------------ lo que piden los demás
## Franjas negras arriba y abajo durante seg segundos: entra un jefe, cae un jefe, caes tú.
func cine(seg: float) -> void:
	_cine_t = maxf(_cine_t, seg)


## Te han dado: la imagen se rompe un instante en colores.
func golpe() -> void:
	_golpe_v = 1.0


## Un latigazo de luz en toda la sala.
func pulso(fuerza := 1.0) -> void:
	_pulso = maxf(_pulso, fuerza)


## Una luz de un momento sobre el suelo (explosiones, fogonazos, muertes).
func luz(pos: Vector2, radio: float, color: Color, vida := 0.2) -> void:
	if _luces.size() >= TOPE_LUCES:
		return
	_luces.append([pos, 0.0, vida, radio, color])


func marca_nacimiento(pos: Vector2, seg: float) -> void:
	if _marcas.size() >= TOPE_MARCAS:
		return
	_marcas.append([pos, 0.0, maxf(seg, 0.1)])


func quemadura(pos: Vector2, radio: float) -> void:
	if _tex_quemado == null:
		return
	if _quemados.size() >= TOPE_QUEMADOS:
		_quemados.pop_front()
	_quemados.append([pos.round(), clampf(radio / 18.0, 0.5, 2.2), randf() * TAU, randi() % 3])
	_restos_sucio = true


## Una partícula que se queda en el suelo hasta que cambies de sala.
func pieza(p: Dictionary) -> void:
	var datos := [p.tex, p.region, p.pos.round(), p.rot, p.escala_fin, p.color, p.espejo]
	if _piezas.size() < TOPE_PIEZAS:
		_piezas.append(datos)
	else:
		_piezas[_piezas_i] = datos
		_piezas_i = (_piezas_i + 1) % TOPE_PIEZAS
	_restos_sucio = true


## Un golpe de zoom (solo con la sacudida activada): se acerca un poco hacia pos.
func golpe_zoom(cantidad: float, pos := CENTRO_PANTALLA) -> void:
	if not Juego.sacudida:
		return
	var nuevo := minf(1.0 + cantidad, ZOOM_MAX)
	if nuevo <= _zoom:
		return
	_zoom = nuevo
	_zoom_centro = CENTRO_PANTALLA.lerp(pos, 0.3)
	_aplicar_zoom()


func _aplicar_zoom() -> void:
	if not is_inside_tree():
		return
	var vista := get_viewport()
	if vista == null:
		return
	if _zoom == 1.0:
		vista.canvas_transform = Transform2D.IDENTITY
		return
	vista.canvas_transform = Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, _zoom_centro * (1.0 - _zoom))


## La primera sale pequeña (la sala acaba de empezar y quizá esté el cartel del piso);
## las siguientes, grandes; la última, en oro y con su nombre.
func oleada(numero: int, total: int) -> void:
	_oleada_ultima = total > 1 and numero >= total
	_oleada_grande = numero > 1
	if _oleada_ultima:
		_oleada_texto = Idioma.t("ÚLTIMA OLEADA")
	elif total <= 0:
		_oleada_texto = Idioma.t("OLEADA %d") % maxi(numero, 1)
	else:
		_oleada_texto = Idioma.t("OLEADA %d/%d") % [clampi(numero, 1, total), total]
	_oleada_t = OLEADA_DURA
	if numero > 1:
		pulso(1.0 if _oleada_ultima else 0.6)
	if _rotulos != null:
		_rotulos.queue_redraw()


# ------------------------------------------------------------ posproceso
func _actualizar_post(real: float) -> void:
	var k := clampf(real * 6.0, 0.0, 1.0)
	var combate: bool = Juego.get("en_combate") == true
	var horda = _horda()
	if Juego.get("en_combate") == null and horda != null:
		combate = not horda.enemigos.is_empty()
	var desatado: bool = Juego.get("desatado") == true
	var limite: bool = Juego.has_method("al_limite") and bool(Juego.call("al_limite")) and Juego.vida > 0
	var fiebre := clampf((Juego.fiebre - 1.8) / 1.2, 0.0, 1.0) if combate else 0.0  # arde desde el nivel 2
	var lineas := 0.0
	if desatado:
		lineas = 0.85
	elif Juego.fiebre >= 2.9 and combate:
		lineas = 0.3
	if _jugador != null and _jugador.rodando():
		lineas = maxf(lineas, 0.25)
	var suave := 1.0 if Juego.sacudida else 0.45  # sin sacudida, todo más tranquilo
	_fiebre_v = lerpf(_fiebre_v, maxf(fiebre, 1.0 if desatado else 0.0), k)
	_lineas_v = lerpf(_lineas_v, lineas * suave, clampf(real * 10.0, 0.0, 1.0))
	_desatado_v = lerpf(_desatado_v, 1.0 if desatado else 0.0, k)
	var golpe := 0.0
	if limite:
		golpe = 0.35 + 0.65 * latido()
	_limite_v = lerpf(_limite_v, golpe, clampf(real * 20.0, 0.0, 1.0))
	var vineta := 0.38
	if _tipo_sala == GeneradorMazmorra.Tipo.JEFE:
		vineta = 0.5
	elif _tipo_sala != GeneradorMazmorra.Tipo.NORMAL:
		vineta = 0.3
	_vineta_v = lerpf(_vineta_v, vineta, k)
	_combate_v = lerpf(_combate_v, 1.0 if combate else 0.0, clampf(real * 3.0, 0.0, 1.0))
	var penumbra := 0.05 + 0.13 * _combate_v
	if _tipo_sala == GeneradorMazmorra.Tipo.JEFE:
		penumbra += 0.1 * _combate_v
	_penumbra_v = penumbra
	_mat.set_shader_parameter("golpe", _golpe_v * suave)
	_mat.set_shader_parameter("cine", _cine_v * CINE_ALTO)
	_mat.set_shader_parameter("brillo", 0.55 + 0.3 * _combate_v + 0.6 * _pulso)
	_mat.set_shader_parameter("tiempo", _t)
	_mat.set_shader_parameter("fiebre", _fiebre_v)
	_mat.set_shader_parameter("lineas", _lineas_v)
	_mat.set_shader_parameter("desatado", _desatado_v * suave)
	_mat.set_shader_parameter("limite", _limite_v)
	_mat.set_shader_parameter("vineta", _vineta_v)


# ------------------------------------------------------------ capas
func _pintar_restos(l: Node2D) -> void:
	if _tex_quemado != null:
		var lado := float(_tex_quemado.get_height())
		for q in _quemados:
			l.draw_set_transform(q[0], q[2], Vector2(q[1], q[1]))
			# Hollín más oscuro que cualquier suelo: vale igual en los pisos teñidos.
			l.draw_texture_rect_region(_tex_quemado, Rect2(-lado * 0.5, -lado * 0.5, lado, lado), Rect2(q[3] * lado, 0, lado, lado), Color(0.45, 0.4, 0.5, 0.75))
	for p in _piezas:
		var region: Rect2 = p[1]
		var escala: float = p[4]
		l.draw_set_transform(p[2], p[3], Vector2(-escala if p[6] else escala, escala))
		var color: Color = p[5]
		# Apagados y medio transparentes: cuentan lo que pasó sin parecerse a una bala.
		l.draw_texture_rect_region(p[0], Rect2(-region.size * 0.5, region.size), region, Color(color.darkened(0.55), 0.7))
	l.draw_set_transform(Vector2.ZERO)


func _pintar_penumbra(l: Node2D) -> void:
	if _penumbra_v > 0.005:
		l.draw_rect(Rect2(-MARGEN_POST, -MARGEN_POST, 640 + MARGEN_POST * 2.0, 360 + MARGEN_POST * 2.0), Color(0.02, 0.01, 0.07, _penumbra_v))


## Los focos del casino: barren la sala mientras dura la pelea y dan un latigazo con cada
## oleada. Con un jefe, uno de ellos no le quita ojo.
func _pintar_focos(l: Node2D, horda) -> void:
	var fuerza := _combate_v * 0.15 + _pulso * 0.18
	if fuerza < 0.004:
		return
	var color: Color = COLOR_FOCOS[clampi(_piso - 1, 0, COLOR_FOCOS.size() - 1)]
	for i in 3:
		var fase := i * 2.1
		var p := Vector2(320.0 + cos(_t * (0.5 + i * 0.13) + fase) * 250.0, 160.0 + sin(_t * (0.8 + i * 0.17) + fase * 1.7) * 85.0)
		var tam := Vector2(170, 118)
		if i == 0 and horda != null and is_instance_valid(horda.jefe):
			p = horda.jefe.position + Vector2(0, 8)
			tam = Vector2(210, 150)
		l.draw_texture_rect(tex_luz, Rect2(p - tam * 0.5, tam), false, Color(color if i != 1 else Color.WHITE, fuerza))


## Lo que brilla en la horda: las balas iluminan el suelo, el jefe late (en rojo cuando se
## enfada), los desesperados arden y quien está a punto de atacar se enciende.
func _pintar_luces_horda(l: Node2D, horda) -> void:
	var balas: Array = horda.ataques._balas_enemigas if horda.ataques != null else []
	var cuantas := mini(balas.size(), TOPE_LUCES_BALA)
	var color_bala := Color(1.0, 0.35, 0.3, 0.3)
	for i in cuantas:
		var b = balas[i]
		if is_instance_valid(b):
			l.draw_texture_rect(tex_luz, Rect2(b.position - Vector2(13, 13), Vector2(26, 26)), false, color_bala)
	for e in horda.enemigos:
		if e.muerto:
			continue
		if e is Jefe:
			var enfado: bool = e.enfadado()
			var late := 0.5 + 0.5 * sin(_t * (9.0 if enfado else 4.0))
			var r := 86.0 + 14.0 * late
			var c := Color(1.0, 0.3, 0.3, 0.3) if enfado else Color(1.0, 0.8, 0.55, 0.2)
			c.a += 0.08 * late
			l.draw_texture_rect(tex_luz, Rect2(e.position - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, c)
		elif e.elite:
			var r: float = e.radio * 3.2
			var a := 0.22 + 0.08 * sin(_t * 6.0 + e.position.x)
			l.draw_texture_rect(tex_luz, Rect2(e.position - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, Color(COLOR_ORO, a))
		elif e.desesperado:
			var r: float = e.radio * 2.6
			l.draw_texture_rect(tex_luz, Rect2(e.position - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, Color(1.0, 0.25, 0.25, 0.26 + 0.1 * sin(_t * 14.0 + e.position.y)))
		elif AVISAN.has(e.tipo) and e.frame == 3:
			var r: float = e.radio * 3.0
			l.draw_texture_rect(tex_luz, Rect2(e.position - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.85, 0.4, 0.4))


func _pintar_luz(l: Node2D) -> void:
	var sala = _sala()
	if sala != null:
		for luz_sala in sala.luces:
			var color: Color = luz_sala[2]
			var parpadeo: float = luz_sala[3]
			if parpadeo > 0.0:
				var n := sin(_t * 7.0 + luz_sala[4]) * sin(_t * 23.0 + luz_sala[4] * 2.0)
				color.a *= 1.0 - parpadeo * clampf(n * 2.5 - 1.2, 0.0, 1.0)
			color.a *= _encendido_k(luz_sala[4])
			var tam: Vector2 = luz_sala[1]
			l.draw_texture_rect(tex_luz, Rect2(luz_sala[0] - tam * 0.5, tam), false, color)
		if not sala.rotulo.is_empty() and _tex_adornos != null:
			var p: Vector2 = sala.rotulo[1]
			var c: Color = sala.rotulo[2]
			var k := _encendido_k(1.3) * (0.85 + 0.15 * sin(_t * 9.0))
			l.draw_texture_rect(tex_luz, Rect2(p - Vector2(44, 34), Vector2(88, 68)), false, Color(c, 0.4 * k))
			l.draw_texture_rect_region(_tex_adornos, Rect2(p - Vector2(8, 8), Vector2(16, 16)), Rect2(sala.rotulo[0] * 16, 0, 16, 16), Color(c, k))
	if _jugador != null:
		_luz_jugador(l)
	for luz_m in _luces:
		var avance: float = luz_m[1] / luz_m[2]
		var color: Color = luz_m[4]
		color.a *= (1.0 - avance) * (1.0 - avance)
		var r: float = luz_m[3] * (0.8 + 0.2 * avance)
		l.draw_texture_rect(tex_luz, Rect2(luz_m[0] - Vector2(r, r), Vector2(r, r) * 2.0), false, color)
	for col in _columnas:
		var avance: float = col[1] / col[2]
		var ancho: float = col[3] * 3.0
		var alto: float = 90.0 + col[3] * 3.0
		var a := sin(avance * PI) * 0.55
		l.draw_texture_rect(tex_luz, Rect2(col[0].x - ancho * 0.5, col[0].y - alto + col[3], ancho, alto), false, Color(0.75, 0.6, 1.0, a))
		l.draw_texture_rect(tex_luz, Rect2(col[0] - Vector2(ancho, ancho * 0.5), Vector2(ancho * 2.0, ancho)), false, Color(0.8, 0.6, 1.0, a * 0.6))
	var horda = _horda()
	_pintar_focos(l, horda)
	if horda != null:
		_pintar_luces_horda(l, horda)


## Los neones y bombillas tardan un poco en encenderse al entrar, cada uno a su ritmo.
func _encendido_k(fase: float) -> float:
	if _encendido >= 1.0:
		return 1.0
	var umbral := 0.25 + fmod(fase * 0.37, 0.5)
	if _encendido < umbral:
		return 0.12 if fmod(_t * 17.0 + fase, 1.0) < 0.25 else 0.0
	return 1.0


func _luz_jugador(l: Node2D) -> void:
	var p: Vector2 = _jugador.position + Vector2(0, 4)
	var color := Color(1.0, 0.86, 0.62, 0.12 + 0.07 * _combate_v)  # en la penumbra, tu luz manda
	var r := 62.0 + 10.0 * _combate_v
	var fiebre := clampf(Juego.fiebre / 3.0, 0.0, 1.0)
	color = color.lerp(Color(COLOR_FIEBRE, 0.17), fiebre)
	r += fiebre * 14.0
	if _desatado_v > 0.01:
		color = color.lerp(Color(1.0, 0.75, 0.35, 0.26), _desatado_v)
		r += 20.0 * _desatado_v * (0.9 + 0.1 * sin(_t * 20.0))
	if _limite_v > 0.01:
		color = color.lerp(Color(1.0, 0.25, 0.3, 0.2), _limite_v * 0.6)
	l.draw_texture_rect(tex_luz, Rect2(p - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, color)


func _pintar_sombras(l: Node2D) -> void:
	if _jugador != null and _jugador.visible:
		var rueda: bool = _jugador.rodando()
		var ancho := 9.0 if rueda else 11.0
		_sombra(l, _jugador.position + Vector2(0, 8), ancho, 4.0, COLOR_SOMBRA)
	var horda = _horda()
	if horda != null:
		for e in horda.enemigos:
			var tex: Texture2D = e.texture
			if tex == null:
				continue
			var alto: float = float(tex.get_height()) / e.vframes * absf(e.scale.y)
			var r: float = e.radio
			var ancho: float = maxf(r * 2.2, 8.0)
			var pie: float = alto * 0.5 - 2.0
			var color := COLOR_SOMBRA
			color.a *= e.modulate.a
			if VUELAN.has(e.tipo):
				pie += 5.0
				ancho *= 0.75
				color.a *= 0.7
			_sombra(l, e.position + Vector2(0, pie), ancho, maxf(3.0, ancho * 0.32), color)
			if e.elite and not e.muerto:
				var pulso := 0.5 + 0.5 * sin(_t * 6.0 + e.position.y)
				l.draw_set_transform(e.position + Vector2(0, pie), 0.0, Vector2(1.0, 0.36))
				l.draw_arc(Vector2.ZERO, ancho * 0.65 + 2.0 + pulso, 0.0, TAU, 24, Color(COLOR_ORO, 0.5 + 0.3 * pulso), 1.0)
				l.draw_set_transform(Vector2.ZERO)
	# Donde va a aparecer alguien: un aro que se cierra y una cruz en el centro.
	for m in _marcas:
		var avance: float = clampf(m[1] / m[2], 0.0, 1.0)
		var p: Vector2 = m[0]
		var r := lerpf(16.0, 4.0, avance)
		var a := 0.45 + 0.4 * avance
		if avance > 0.7 and int(_t * 20.0) % 2 == 0:
			a = 1.0
		l.draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
		l.draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(COLOR_AVISO, a), 1.0)
		l.draw_arc(Vector2.ZERO, 16.0, avance * TAU, avance * TAU + 1.2, 8, Color(COLOR_FIEBRE, 0.5), 1.0)
		l.draw_set_transform(Vector2.ZERO)
		l.draw_rect(Rect2(p.x - 2, p.y, 5, 1), Color(COLOR_AVISO, a))
		l.draw_rect(Rect2(p.x, p.y - 1, 1, 3), Color(COLOR_AVISO, a))
	for col in _columnas:
		var avance: float = col[1] / col[2]
		l.draw_set_transform(col[0] + Vector2(0, col[3] * 0.6), 0.0, Vector2(1.0, 0.4))
		l.draw_arc(Vector2.ZERO, col[3] + 4.0 + avance * 10.0, 0.0, TAU, 20, Color(0.8, 0.65, 1.0, 0.6 * (1.0 - avance)), 1.0)
		l.draw_set_transform(Vector2.ZERO)


func _sombra(l: Node2D, pie: Vector2, ancho: float, alto: float, color: Color) -> void:
	l.draw_texture_rect(tex_sombra, Rect2((pie - Vector2(ancho, alto) * 0.5).round(), Vector2(ancho, alto).round()), false, color)


## El "!" sobre los enemigos que están a punto de atacar: se ve aunque haya mucho lío.
func _pintar_avisos(l: Node2D) -> void:
	var horda = _horda()
	if horda == null:
		return
	var parpadeo := int(_t * 14.0) % 2 == 0
	for e in horda.enemigos:
		if not e.activo() or e is Jefe:
			continue
		# Los ataques en línea recta enseñan por dónde van a pasar antes de salir.
		var linea: Vector2 = e.aviso_linea()
		if linea != Vector2.ZERO:
			l.draw_dashed_line(e.position, e.position + linea, Color(COLOR_AVISO, 0.75 if parpadeo else 0.45), 2.0, 5.0)
		elif not AVISAN.has(e.tipo) or e.frame != 3:
			continue
		var tex: Texture2D = e.texture
		var alto: float = 16.0 if tex == null else float(tex.get_height()) / e.vframes * absf(e.scale.y)
		var p: Vector2 = (e.position - Vector2(0, alto * 0.5 + 9.0)).round()
		var color := COLOR_AVISO if parpadeo else COLOR_ORO
		l.draw_rect(Rect2(p.x - 2, p.y - 1, 4, 10), Color8(20, 16, 30))
		l.draw_rect(Rect2(p.x - 1, p.y, 2, 5), color)
		l.draw_rect(Rect2(p.x - 1, p.y + 6, 2, 2), color)
	# Con balas cerca se ve tu caja de choque: lo único que de verdad tienes que salvar.
	if _jugador != null and _jugador.visible and horda.ataques != null and horda.ataques.balas_enemigas_cerca(_jugador.position, 64.0) > 0:
		var centro: Vector2 = (_jugador.position + Vector2(0, 2)).round()
		l.draw_rect(Rect2(centro - Vector2(2, 2), Vector2(4, 4)), Color8(20, 16, 30))
		l.draw_rect(Rect2(centro - Vector2(1, 1), Vector2(2, 2)), Color8(247, 236, 210) if parpadeo else COLOR_ORO)


## El rótulo de la oleada, pegado al muro de arriba: dos rayas entran desde los lados, el
## texto aparece entre ellas, se queda un momento y se va. No tapa el centro de la sala.
func _pintar_rotulos() -> void:
	if _oleada_t <= 0.0 or _oleada_texto == "":
		return
	var vida := OLEADA_DURA - _oleada_t
	var entra := clampf(vida / 0.16, 0.0, 1.0)
	entra = 1.0 - (1.0 - entra) * (1.0 - entra)  # frena al llegar
	var a := clampf(vida / 0.08, 0.0, 1.0) * clampf(_oleada_t / 0.3, 0.0, 1.0)
	var fuente: Font = Juego.fuente_grande if _oleada_grande else Juego.fuente
	var tam := 16 if _oleada_grande else 8
	var y := 52.0 if _oleada_grande else 46.0
	var ancho := fuente.get_string_size(_oleada_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var x := roundf(320.0 - ancho * 0.5)
	var acento := COLOR_AVISO if _oleada_ultima else COLOR_ORO
	var color := COLOR_ORO if _oleada_ultima else Color8(247, 236, 210)
	# La última parpadea un poco al entrar: aprieta.
	if _oleada_ultima and vida < 0.5 and int(vida * 16.0) % 2 == 0:
		color = Color8(247, 236, 210)
	color.a = a
	var placa := Rect2(x - 8.0, y - tam - 1.0, ancho + 16.0, tam + 5.0)
	_rotulos.draw_rect(placa, Color(0.08, 0.06, 0.12, 0.55 * a))
	# Las rayas: salen del texto hacia fuera.
	var raya := 56.0 * entra
	var medio := roundf(y - tam * 0.5 + 1.0)
	for lado: float in [-1.0, 1.0]:
		var desde: float = 320.0 + lado * (ancho * 0.5 + 12.0)
		var hasta: float = desde + lado * raya
		_rotulos.draw_rect(Rect2(minf(desde, hasta), medio, absf(hasta - desde), 1.0), Color(acento, a * 0.8))
		var c := Vector2(desde - lado * 2.0, medio).round()
		var rombo := PackedVector2Array([c + Vector2(0, -3), c + Vector2(2, 0), c + Vector2(0, 3), c + Vector2(-2, 0)])
		_rotulos.draw_colored_polygon(rombo, Color(acento, a))
	var sombra := Color(0.08, 0.06, 0.12, a * 0.9)
	var desliza := roundf((1.0 - entra) * 10.0)
	_rotulos.draw_string(fuente, Vector2(x + 1, y + 1 - desliza), _oleada_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, sombra)
	_rotulos.draw_string(fuente, Vector2(x, y - desliza), _oleada_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)
