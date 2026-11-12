class_name Recogible
extends Sprite2D
## Cualquier cosa que el jugador toca en el suelo: monedas, cofres, artículos...

enum Clase { MONEDA, CORAZON, CARTA, COFRE, TRAMPILLA, ARTICULO, OBJETO, EVENTO, MAQUINA }

const RADIO := {
	Clase.MONEDA: 9.0, Clase.CORAZON: 10.0, Clase.CARTA: 13.0,
	Clase.COFRE: 14.0, Clase.TRAMPILLA: 15.0, Clase.ARTICULO: 18.0, Clase.OBJETO: 13.0, Clase.EVENTO: 15.0,
	Clase.MAQUINA: 46.0,  # tragaperras y ruleta: se juega con E (o el botón) estando al lado
}

var clase := Clase.MONEDA
var datos: Dictionary = {}  # artículos de tienda: id, precio, tipo; máquinas: maquina
var iman := false

var _armada := false  # la trampilla no se traga a quien ya estaba encima

var _t := 0.0
var _vel := Vector2.ZERO
var _principal: Node


func iniciar(nueva_clase: int, principal: Node) -> void:
	clase = nueva_clase
	_principal = principal
	if clase == Clase.MONEDA:
		_vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30, 90)


func tocando() -> bool:
	return quien_toca() != null


## El jugador que lo está tocando (en cooperativo, el primero de los dos que esté en pie), o null.
func quien_toca() -> Node2D:
	var lista: Array = _principal.jugadores if _principal.jugadores.size() > 1 else [_principal.jugador]
	for j in lista:
		if not j.caido and position.distance_to(j.position) <= RADIO[clase]:
			return j
	return null


func _physics_process(delta: float) -> void:
	_t += delta
	if clase == Clase.MONEDA:
		_mover_moneda(delta)
	if clase == Clase.TRAMPILLA and not _armada:
		_armada = not tocando()
		return
	if clase != Clase.ARTICULO and clase != Clase.MAQUINA:
		var quien := quien_toca()
		if quien != null:
			_principal.recogido(self, quien)


func _mover_moneda(delta: float) -> void:
	frame = int(_t * 10.0) % 4
	var hacia: Vector2 = _principal.objetivo_moneda(position).position - position
	var alcance := 150.0 if Juego.stat("iman") > 0.0 else 42.0
	if iman or hacia.length() < alcance:
		position += hacia.normalized() * (260.0 if iman else 170.0) * delta
	else:
		position += _vel * delta
		_vel = _vel.lerp(Vector2.ZERO, clampf(delta * 5.0, 0.0, 1.0))
		position = position.clamp(Sala.INTERIOR.position + Vector2(4, 4), Sala.INTERIOR.end - Vector2(4, 4))
