class_name Mesa
extends Sprite2D
## Una mesa de póker. De pie estorba; volcada hace de parapeto contra las balas enemigas
## hasta que se rompe. Se vuelca rodando contra ella o con E al lado.
## No nombra a Juego ni a Sonido a propósito: Sala la usa, y las pruebas cargan Sala
## antes que los autoloads. Lo que depende de la partida llega por parámetro.

signal volcada(mesa: Mesa)
signal rota(mesa: Mesa)

enum Estado { DE_PIE, VOLCADA, ROTA }

const RUTA := "res://assets/objetos/mesa.png"
const TAM_DE_PIE := Vector2(28, 14)
const AGUANTE := 6  # balas que para antes de romperse
const EMPUJE := 300.0
const ATURDIR := 0.7
const ALCANCE_BARRIDO := 24.0

var estado := Estado.DE_PIE
var centro := Vector2.ZERO
var caja := Rect2()  # lo que choca: cambia al volcarse
var direccion := Vector2.ZERO

var _aguante := AGUANTE
var _temblor := 0.0


func iniciar(en: Vector2) -> void:
	centro = en
	position = en
	if ResourceLoader.exists(RUTA):
		texture = load(RUTA)
	hframes = 3
	frame = 0
	caja = Rect2(en - TAM_DE_PIE * 0.5 + Vector2(0, 2), TAM_DE_PIE)


func solida() -> bool:
	return estado != Estado.ROTA


func para_balas() -> bool:
	return estado == Estado.VOLCADA


## refuerzo: el del Tapete Reforzado (aguanta el triple con 1.0).
func volcar(dir: Vector2, horda, dano: float, refuerzo: float) -> void:
	if estado != Estado.DE_PIE:
		return
	_poner_volcada(dir, refuerzo)
	# Cae de golpe: un poco aplastada y enseguida en su sitio.
	scale = Vector2(1.25, 0.7)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if horda != null:
		_barrer(horda, dano * (1.0 + refuerzo))
	volcada.emit(self)


func _poner_volcada(dir: Vector2, refuerzo: float) -> void:
	estado = Estado.VOLCADA
	direccion = dir
	frame = 1
	_aguante = roundi(AGUANTE * (1.0 + 2.0 * refuerzo))
	# El dibujo volcado mira hacia arriba: se gira hacia donde cae.
	rotation = dir.angle() + PI / 2.0
	position = centro + dir * 5.0
	if dir.x != 0.0:
		caja = Rect2(centro + dir * 8.0 - Vector2(4, 15), Vector2(8, 30))
	else:
		caja = Rect2(centro + dir * 6.0 - Vector2(15, 4), Vector2(30, 8))


## Al caer arrolla a los que tiene delante.
func _barrer(horda, dano: float) -> void:
	for e in horda.en_radio(centro + direccion * 14.0, ALCANCE_BARRIDO):
		horda.danar(e, dano, direccion * EMPUJE)
		e.aturdir(ATURDIR)


## Una bala enemiga se ha estrellado contra ella.
func recibir_bala() -> void:
	if estado != Estado.VOLCADA:
		return
	_aguante -= 1
	_temblor = 1.0
	if _aguante <= 0:
		_romper()


func _romper() -> void:
	estado = Estado.ROTA
	frame = 2
	offset = Vector2.ZERO
	self_modulate = Color(0.8, 0.8, 0.8)
	rota.emit(self)


## Para las salas ya visitadas: [estado, dirección].
func restaurar(guardado: Array, refuerzo: float) -> void:
	if guardado.size() < 2 or int(guardado[0]) == Estado.DE_PIE:
		return
	_poner_volcada(guardado[1], refuerzo)
	if int(guardado[0]) == Estado.ROTA:
		estado = Estado.ROTA
		frame = 2
		self_modulate = Color(0.8, 0.8, 0.8)


func volcar_datos() -> Array:
	return [estado, direccion]


func _process(delta: float) -> void:
	if _temblor <= 0.0:
		return
	_temblor = maxf(_temblor - delta * 7.0, 0.0)
	offset = Vector2(randf_range(-1.0, 1.0), 0.0).round() * ceilf(_temblor * 1.5)
	modulate = Color(1.5, 1.5, 1.5) if _temblor > 0.7 else Color.WHITE
