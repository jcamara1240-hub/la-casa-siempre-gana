class_name Hud
extends Control
## Vidas, oro, mapa y barra del jefe, pintados sobre el muro de arriba.

var salas: Dictionary = {}
var posicion_actual := Vector2i.ZERO
var horda: Horda
var barra: BarraCartas

var _texturas_objetos := {}
var _cola_logros: Array = []
var _logro_t := 0.0
@onready var _trofeo: Texture2D = load("res://assets/objetos/trofeo.png")

var _corazon: Texture2D = load("res://assets/objetos/corazon.png")
var _moneda: Texture2D = load("res://assets/objetos/moneda.png")
var _ordago: Texture2D = Jugo.textura("res://assets/objetos/ordago.png")
var _fiebre_vista := 0.0  # el medidor sube y baja suave, no a saltos
var _pulso := 0.0
var _vida_antes := -1
var _golpe_t := 0.0  # el corazón que acabas de perder tiembla y parpadea
var _golpe_i := -1
var _nivel_antes := 0
var _subida_t := 0.0  # la casilla de Fiebre que se acaba de llenar destella
var _chispas: Array = []  # [posición, velocidad, t, vida, color]: pocas y por lotes
var _chispa_espera := 0.0
var _jefe_ref: Object = null
var _jefe_antes := 1.0
var _jefe_rastro := 1.0  # lo que ha perdido el jefe se queda un momento en crema
var _jefe_golpe_t := 0.0

const Ambiente := preload("res://scripts/ambiente.gd")
const COLORES_FIEBRE := [Color8(247, 198, 74), Color8(240, 129, 60), Color8(214, 61, 79)]
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ROJO := Color8(214, 61, 79)
const COLOR_FONDO := Color8(20, 16, 30)
const COLOR_MARCO := Color8(74, 52, 102)
const TOPE_CHISPAS := 28
const X_FIEBRE := 38.0
const CASILLA := 17.0  # ancho de cada casilla de Fiebre con su hueco

const COLOR_MAPA := {
	GeneradorMazmorra.Tipo.INICIO: Color8(168, 154, 142),
	GeneradorMazmorra.Tipo.NORMAL: Color8(122, 90, 160),
	GeneradorMazmorra.Tipo.TESORO: Color8(247, 198, 74),
	GeneradorMazmorra.Tipo.TIENDA: Color8(108, 207, 148),
	GeneradorMazmorra.Tipo.JEFE: Color8(214, 61, 79),
	GeneradorMazmorra.Tipo.EVENTO: Color8(111, 195, 232),
	GeneradorMazmorra.Tipo.APUESTAS: Color8(232, 110, 200),
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 304)
	Juego.estado_cambiado.connect(queue_redraw)


func avisar_logro(id: String) -> void:
	_cola_logros.append(id)
	if _cola_logros.size() == 1:
		_logro_t = 2.6


func _process(delta: float) -> void:
	queue_redraw()
	_mirar_raton()
	_fiebre_vista = move_toward(_fiebre_vista, Juego.fiebre, delta * 6.0)
	_pulso += delta
	_mirar_vida(delta)
	_mirar_fiebre(delta)
	_mirar_jefe(delta)
	_mover_chispas(delta)
	if not _cola_logros.is_empty():
		_logro_t -= delta
		if _logro_t <= 0.0:
			_cola_logros.pop_front()
			_logro_t = 2.6


func _dibujar_logro() -> void:
	if _cola_logros.is_empty():
		return
	var caja := Rect2(404, 36, 232, 22)
	draw_rect(caja, Color8(20, 16, 30))
	_marco(caja, Color8(247, 198, 74))
	draw_texture(_trofeo, caja.position + Vector2(5, 5))
	draw_string(Juego.fuente, caja.position + Vector2(22, 9), Idioma.t("LOGRO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(168, 154, 142))
	draw_string(Juego.fuente, caja.position + Vector2(22, 18), LogrosDB.nombre(_cola_logros[0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(247, 198, 74))


func _caja_transformacion(i: int) -> Rect2:
	return Rect2(566.0 - i * 13.0, 4.0, 11.0, 11.0)


func _caja_objeto(i: int) -> Rect2:
	return Rect2(98 + (i % 10) * 13, 3 + (i / 10) * 13, 12, 12)


## El ratón sobre un objeto de arriba: su descripción sale en la barra de cartas.
func _mirar_raton() -> void:
	if barra == null or barra.info_externa.get("origen") == "tienda":
		return
	var raton := get_local_mouse_position()
	for i in Juego.transformaciones.size():
		if _caja_transformacion(i).has_point(raton):
			var t: String = Juego.transformaciones[i]
			barra.info_externa = {"nombre": Idioma.t(ObjetosDB.TRANSFORMACIONES[t].nombre), "desc": Idioma.t(ObjetosDB.TRANSFORMACIONES[t].desc), "origen": "hud"}
			return
	for i in Juego.objetos.size():
		if _caja_objeto(i).has_point(raton):
			var id: String = Juego.objetos[i]
			barra.info_externa = {"nombre": ObjetosDB.nombre(id), "desc": ObjetosDB.descripcion(id), "origen": "hud"}
			return
	if barra.info_externa.get("origen") == "hud":
		barra.info_externa = {}


func _draw() -> void:
	var placa := Color(0.08, 0.06, 0.12, 0.8)
	draw_rect(Rect2(2, 2, 92, 25), placa)
	draw_rect(Rect2(640 - 58, 1, 56, 28), placa)
	_dibujar_corazones()
	draw_texture_rect_region(_moneda, Rect2(6, 15, 8, 8), Rect2(0, 0, 8, 8))
	draw_string(Juego.fuente, Vector2(17, 23), str(Juego.oro), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(247, 236, 210))
	draw_string(Juego.fuente, Vector2(50, 23), (Idioma.t("PISO %d INF") % Juego.piso) if Juego.infinito else (Idioma.t("PISO %d/%d") % [Juego.piso, Juego.PISOS_TOTALES]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(168, 154, 142))
	_dibujar_objetos()
	_dibujar_logro()
	_dibujar_transformaciones()
	if Juego.diario:
		draw_rect(Rect2(2, 28, 76, 11), Color(0.08, 0.06, 0.12, 0.8))
		draw_string(Juego.fuente, Vector2(6, 37), Idioma.t("RETO DIARIO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(108, 207, 148))
	if Juego.extremo:
		draw_rect(Rect2(2, 28, 72 if Juego.imposible else 58, 11), Color(0.08, 0.06, 0.12, 0.8))
		draw_string(Juego.fuente, Vector2(6, 37), Idioma.t("IMPOSIBLE") if Juego.imposible else Idioma.t("EXTREMO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(214, 61, 79))
	if Juego.deuda > 0:
		draw_rect(Rect2(2, 28, 70, 11), Color(0.08, 0.06, 0.12, 0.8))
		draw_string(Juego.fuente, Vector2(6, 37), Idioma.t("DEUDA %d") % Juego.deuda, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(214, 61, 79))
	_dibujar_mapa()
	_dibujar_reservas()
	if horda != null and is_instance_valid(horda.jefe):
		_dibujar_jefe()
	elif Juego.progreso_sala >= 0.0:
		_dibujar_sala()
	_dibujar_chispas()


## Lo que llevas de la sala, en porcentaje: las oleadas entran según lo que vas matando.
func _dibujar_sala() -> void:
	var parte := clampf(Juego.progreso_sala, 0.0, 1.0)
	var color := Color8(247, 198, 74) if parte < 0.999 else Color8(108, 207, 148)
	draw_rect(Rect2(269, 3, 102, 6), Color(0.08, 0.06, 0.12, 0.8))
	draw_rect(Rect2(270, 4, roundf(100.0 * parte), 4), color)
	# La presión de la casa: una muesca por cada décima por encima de lo normal.
	for i in clampi(roundi((Juego.presion - 1.0) * 10.0), 0, 7):
		draw_rect(Rect2(270 + i * 4, 10, 3, 2), Color8(214, 61, 79))
	draw_string(Juego.fuente, Vector2(376, 10), Idioma.t("SALA %d%%") % roundi(parte * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(247, 236, 210))


# ------------------------------------------------------------ lo que se mira cada fotograma
## Estado que publica Juego (lo pone otro archivo): se lee con cuidado y con valor por defecto.
static func _al_limite() -> bool:
	return Juego.has_method("al_limite") and bool(Juego.call("al_limite"))


static func _desatado() -> bool:
	return Juego.get("desatado") == true


static func _desatado_resto() -> float:
	return float(Juego.call("desatado_resto")) if Juego.has_method("desatado_resto") else 0.0


func _mirar_vida(delta: float) -> void:
	_golpe_t = maxf(_golpe_t - delta, 0.0)
	if _vida_antes > Juego.vida and Juego.vida >= 0:
		# El corazón que ha perdido algo: tiembla y suelta trozos.
		_golpe_i = clampi((Juego.vida) / 2, 0, maxi(Juego.vida_max / 2 - 1, 0))
		_golpe_t = 0.45
		var centro := Vector2(10.5 + _golpe_i * 11, 7.5)
		for k in 6:
			_chispa(centro, Vector2.RIGHT.rotated(TAU * k / 6.0 + randf() * 0.5) * randf_range(25.0, 50.0), 0.35, COLOR_ROJO if k % 2 == 0 else COLOR_CREMA)
	_vida_antes = Juego.vida


func _mirar_fiebre(delta: float) -> void:
	_subida_t = maxf(_subida_t - delta, 0.0)
	var nivel := Juego.nivel_fiebre()
	if nivel > _nivel_antes:
		_subida_t = 0.3
	_nivel_antes = nivel
	# Con la Fiebre al máximo (o desatado) el medidor echa chispas hacia arriba.
	var ardiendo := _desatado() or nivel >= 3
	if not ardiendo:
		return
	_chispa_espera -= delta
	if _chispa_espera > 0.0:
		return
	_chispa_espera = 0.04 if _desatado() else 0.09
	var x0 := _x_casillas()
	var p := Vector2(x0 + randf() * (3.0 * CASILLA - 2.0), 291.0)
	var color: Color = COLORES_FIEBRE[randi() % 3]
	_chispa(p, Vector2(randf_range(-6.0, 6.0), randf_range(-38.0, -18.0)), randf_range(0.3, 0.55), color)


func _mirar_jefe(delta: float) -> void:
	_jefe_golpe_t = maxf(_jefe_golpe_t - delta, 0.0)
	if horda == null or not is_instance_valid(horda.jefe):
		_jefe_ref = null
		return
	var j := horda.jefe
	var k := clampf(j.vida / j.vida_max, 0.0, 1.0)
	if j != _jefe_ref:
		_jefe_ref = j
		_jefe_antes = k
		_jefe_rastro = k
	if k < _jefe_antes - 0.004:  # los golpes pequeños no lo encienden: siempre se lee rojo
		_jefe_golpe_t = 0.07
	_jefe_antes = k
	if _jefe_rastro > k:
		# Primero se queda quieto un instante y luego baja, cada vez más deprisa.
		_jefe_rastro = move_toward(_jefe_rastro, k, delta * (0.08 + (_jefe_rastro - k) * 2.5))
	else:
		_jefe_rastro = k


func _chispa(p: Vector2, v: Vector2, vida: float, color: Color) -> void:
	if _chispas.size() >= TOPE_CHISPAS:
		return
	_chispas.append([p, v, 0.0, vida, color])


func _mover_chispas(delta: float) -> void:
	var i := _chispas.size() - 1
	while i >= 0:
		var c: Array = _chispas[i]
		c[2] += delta
		if c[2] >= c[3]:
			_chispas[i] = _chispas[_chispas.size() - 1]
			_chispas.pop_back()
		else:
			c[0] += c[1] * delta
			c[1] *= 1.0 - minf(delta * 3.0, 1.0)
		i -= 1


## Un marco de un píxel justo por dentro del rectángulo (draw_rect sin relleno lo
## centra en el borde y deja huecos de medio píxel).
func _marco(caja: Rect2, color: Color) -> void:
	draw_rect(Rect2(caja.position, Vector2(caja.size.x, 1)), color)
	draw_rect(Rect2(caja.position.x, caja.end.y - 1.0, caja.size.x, 1), color)
	draw_rect(Rect2(caja.position.x, caja.position.y + 1.0, 1, caja.size.y - 2.0), color)
	draw_rect(Rect2(caja.end.x - 1.0, caja.position.y + 1.0, 1, caja.size.y - 2.0), color)


func _dibujar_chispas() -> void:
	for c in _chispas:
		var color: Color = c[4]
		color.a = 1.0 - c[2] / c[3]
		draw_rect(Rect2(c[0].floor(), Vector2.ONE), color)


# ------------------------------------------------------------ vidas
## Cada corazón son dos puntos de vida. Al límite, el último late con la viñeta roja.
func _dibujar_corazones() -> void:
	var limite := _al_limite()
	var golpe := Ambiente.latido() if limite else 0.0
	if limite:
		_marco(Rect2(2, 2, 92, 25), Color(COLOR_ROJO, 0.35 + 0.65 * golpe))
	for i in Juego.vida_max / 2:
		var puntos := Juego.vida - i * 2
		var columna := 0 if puntos >= 2 else (1 if puntos == 1 else 2)
		var p := Vector2(6 + i * 11, 4)
		if limite and puntos > 0 and puntos <= 2:
			draw_circle(p + Vector2(4.5, 3.5), 5.0 + 2.0 * golpe, Color(COLOR_ROJO, 0.2 + 0.4 * golpe))
			p.y -= roundf(golpe * 2.0)
		var tinte := Color.WHITE
		if _golpe_t > 0.0 and i == _golpe_i:
			# El que acabas de perder tiembla y parpadea.
			p.x += 1.0 if int(_golpe_t * 40.0) % 2 == 0 else -1.0
			if int(_golpe_t * 20.0) % 2 == 0:
				tinte.a = 0.25
		draw_texture_rect_region(_corazon, Rect2(p, Vector2(9, 7)), Rect2(columna * 9, 0, 9, 7), tinte)


## Abajo a la izquierda, sobre el muro: los órdagos que te quedan y el medidor de Fiebre.
## El medidor tiene vida propia: las casillas llenas laten, la que se acaba de llenar
## destella, desde el nivel 2 le salen llamas y desatado se vuelve una mecha que se gasta.
func _x_casillas() -> float:
	var ancho := maxf(_ancho_texto(Idioma.t("FIEBRE")), _ancho_texto(Idioma.t("DESATADO")))
	return X_FIEBRE + ancho + 4.0


static func _ancho_texto(texto: String) -> float:
	return Juego.fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x


func _dibujar_reservas() -> void:
	var desatado := _desatado()
	var x_casillas := _x_casillas()
	var panel := Rect2(2, 289, x_casillas + 3.0 * CASILLA + 2.0, 14)
	draw_rect(panel, Color(0.08, 0.06, 0.12, 0.8))
	if _ordago != null:
		draw_texture(_ordago, Vector2(5, 290))
	var color_ordagos := COLOR_CREMA if Juego.ordagos > 0 else Color8(168, 154, 142)
	draw_string(Juego.fuente, Vector2(19, 300), "x%d" % Juego.ordagos, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color_ordagos)
	var nivel := Juego.nivel_fiebre()
	if desatado:
		var parpadeo := int(_pulso * 12.0) % 2 == 0
		draw_string(Juego.fuente, Vector2(X_FIEBRE, 300), Idioma.t("DESATADO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
				COLORES_FIEBRE[0] if parpadeo else COLORES_FIEBRE[1])
		_dibujar_mecha(Rect2(x_casillas, 292, 3.0 * CASILLA - 2.0, 8))
		_marco(panel, Color(COLORES_FIEBRE[1], 0.5 + 0.3 * sin(_pulso * 18.0)))
		return
	draw_string(Juego.fuente, Vector2(X_FIEBRE, 300), Idioma.t("FIEBRE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			COLORES_FIEBRE[nivel - 1] if nivel > 0 else Color8(168, 154, 142))
	for i in 3:
		var caja := Rect2(x_casillas + i * CASILLA, 292, 15, 8)
		draw_rect(caja, COLOR_FONDO)
		var lleno := clampf(_fiebre_vista - i, 0.0, 1.0)
		if lleno > 0.0:
			var color: Color = COLORES_FIEBRE[i]
			# Las casillas llenas laten: se ve de reojo que estás en racha.
			if lleno >= 1.0:
				color = color.lightened(0.25 * (0.5 + 0.5 * sin(_pulso * (6.0 + nivel * 3.0))))
			var relleno := Rect2(caja.position + Vector2(1, 1), Vector2((caja.size.x - 2.0) * lleno, caja.size.y - 2.0))
			draw_rect(relleno, color)
			draw_rect(Rect2(relleno.position, Vector2(relleno.size.x, 1)), color.lightened(0.35))
			if nivel >= 2 and lleno >= 1.0:
				_llamas(caja.position.x + 1.0, caja.size.x - 2.0, caja.position.y, 1.0 + nivel * 0.8, i)
		# La que se acaba de llenar destella en crema.
		if _subida_t > 0.0 and i == nivel - 1:
			_marco(caja.grow(1.0), Color(COLOR_CREMA, _subida_t / 0.3))
			draw_rect(caja.grow(-1.0), Color(COLOR_CREMA, 0.6 * _subida_t / 0.3))
		_marco(caja, COLOR_MARCO if i >= nivel else COLORES_FIEBRE[i])


## Desatado: una sola barra que se consume, con fuego que corre por encima.
func _dibujar_mecha(caja: Rect2) -> void:
	var resto := _desatado_resto()
	draw_rect(caja, COLOR_FONDO)
	var ancho := roundf((caja.size.x - 2.0) * resto)
	for x in int(ancho):
		# Franjas de colores de fuego que corren hacia la izquierda.
		var franja := int(floorf((x + _pulso * 40.0) / 3.0)) % 3
		draw_rect(Rect2(caja.position.x + 1.0 + x, caja.position.y + 1.0, 1, caja.size.y - 2.0), COLORES_FIEBRE[franja])
	draw_rect(Rect2(caja.position + Vector2(1, 1), Vector2(ancho, 1)), Color(COLOR_CREMA, 0.6))
	_llamas(caja.position.x + 1.0, ancho, caja.position.y, 4.0, 7)
	# La punta de la mecha: una chispa blanca que se va comiendo la barra.
	if ancho > 0.0:
		draw_rect(Rect2(caja.position.x + ancho, caja.position.y, 2, caja.size.y), COLOR_CREMA)
	_marco(caja, COLORES_FIEBRE[0])


## Llamitas de pixel art sobre el borde de arriba de una casilla.
func _llamas(x0: float, ancho: float, arriba: float, alto: float, semilla: int) -> void:
	var paso := floorf(_pulso * 14.0)
	var x := 0.0
	while x < ancho:
		var n := fposmod(sin((x0 + x) * 12.9898 + paso * 78.233 + semilla * 3.1) * 43758.5453, 1.0)
		var h := roundf(n * alto)
		if h >= 1.0:
			draw_rect(Rect2(x0 + x, arriba - h, 1, h), COLORES_FIEBRE[1] if n > 0.6 else COLORES_FIEBRE[0])
			draw_rect(Rect2(x0 + x, arriba - h, 1, 1), COLORES_FIEBRE[2] if n > 0.8 else COLORES_FIEBRE[1])
		x += 1.0


func _dibujar_objetos() -> void:
	for i in Juego.objetos.size():
		var id: String = Juego.objetos[i]
		if not _texturas_objetos.has(id):
			_texturas_objetos[id] = ObjetosDB.textura(id)
		draw_texture(_texturas_objetos[id], _caja_objeto(i).position)


func _dibujar_transformaciones() -> void:
	for i in Juego.transformaciones.size():
		var datos: Dictionary = ObjetosDB.TRANSFORMACIONES[Juego.transformaciones[i]]
		var caja := _caja_transformacion(i)
		draw_rect(caja, Color8(20, 16, 30))
		draw_rect(caja.grow(-1.0), Color.html(datos.color))


func _dibujar_mapa() -> void:
	var origen := Vector2(640 - 6 - 49, 3)
	for c in salas:
		var s: Dictionary = salas[c]
		var visible_sala: bool = s.visitada
		if not visible_sala:
			for d in GeneradorMazmorra.DIRECCIONES:
				if salas.has(c + d) and salas[c + d].visitada:
					visible_sala = true
		if not visible_sala:
			continue
		var caja := Rect2(origen + Vector2(c.x * 7, c.y * 5), Vector2(6, 4))
		var color: Color = COLOR_MAPA[s.tipo]
		if not s.visitada:
			color = color.darkened(0.55)
		draw_rect(caja, color)
		if s.tipo == GeneradorMazmorra.Tipo.APUESTAS:
			draw_rect(Rect2(caja.position + Vector2(2, 1), Vector2(2, 2)), Color8(247, 198, 74))  # la ficha: se distingue del evento
		if c == posicion_actual:
			_marco(caja.grow(1.0), Color8(247, 236, 210))


## La barra del jefe: marco, rastro crema de lo que acaba de perder, destello al golpearlo
## y marcas cada cuarto. Por debajo de un tercio, el marco late en rojo.
func _dibujar_jefe() -> void:
	var j := horda.jefe
	var ancho := 180.0
	var x := 320.0 - ancho * 0.5
	var k := clampf(j.vida / j.vida_max, 0.0, 1.0)
	var nombre: String = Idioma.t(j.nombre)
	var x_nombre := roundf(320.0 - _ancho_texto(nombre) * 0.5)
	draw_string(Juego.fuente, Vector2(x_nombre + 1, 10), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_FONDO)
	draw_string(Juego.fuente, Vector2(x_nombre, 9), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color8(247, 198, 74))
	var marco := Rect2(x - 1, 11, ancho + 2, 8)
	draw_rect(marco, COLOR_FONDO)
	var interior := Rect2(x + 1, 13, ancho - 2, 4)
	draw_rect(Rect2(interior.position, Vector2(interior.size.x * _jefe_rastro, 4)), COLOR_CREMA)
	var color := COLOR_ROJO.lightened(0.3) if _jefe_golpe_t > 0.0 else COLOR_ROJO
	draw_rect(Rect2(interior.position, Vector2(interior.size.x * k, 4)), color)
	draw_rect(Rect2(interior.position, Vector2(interior.size.x * k, 1)), color.lightened(0.3))
	for cuarto in [0.25, 0.5, 0.75]:
		draw_rect(Rect2(interior.position.x + roundf(interior.size.x * cuarto), 13, 1, 4), Color(COLOR_FONDO, 0.7))
	var borde := COLOR_MARCO
	if k < 0.34:
		borde = COLOR_MARCO.lerp(COLOR_ROJO, 0.5 + 0.5 * sin(_pulso * 10.0))
	_marco(marco, borde)
