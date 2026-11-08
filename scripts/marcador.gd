class_name Marcador
extends Node
## Habla con Firestore por su API REST: una colección de puntuaciones por cada día.

signal top_recibido(filas: Array, correcto: bool)
signal puntuacion_enviada(correcto: bool)

var base := "https://firestore.googleapis.com/v1"
var proyecto := MarcadorConfig.PROYECTO
var clave := MarcadorConfig.CLAVE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func configurado() -> bool:
	return proyecto != "" and clave != ""


func _ruta(fecha: String) -> String:
	return "%s/projects/%s/databases/(default)/documents/dias/%s" % [base, proyecto, fecha]


func pedir_top(fecha: String) -> void:
	if not configurado():
		top_recibido.emit([], false)
		return
	var cuerpo := {"structuredQuery": {
		"from": [{"collectionId": "puntos"}],
		"orderBy": [{"field": {"fieldPath": "puntos"}, "direction": "DESCENDING"}],
		"limit": 10,
	}}
	_peticion("%s:runQuery?key=%s" % [_ruta(fecha), clave], cuerpo, _al_recibir_top)


func enviar(fecha: String, nombre: String, puntos: int) -> void:
	if not configurado():
		puntuacion_enviada.emit(false)
		return
	var cuerpo := {"fields": {"nombre": {"stringValue": nombre}, "puntos": {"integerValue": str(puntos)}}}
	_peticion("%s/puntos?key=%s" % [_ruta(fecha), clave], cuerpo, _al_enviar)


func _peticion(url: String, cuerpo: Dictionary, al_terminar: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	http.request_completed.connect(func(resultado, codigo, _cabeceras, datos):
		http.queue_free()
		al_terminar.call(resultado == HTTPRequest.RESULT_SUCCESS and codigo >= 200 and codigo < 300, datos.get_string_from_utf8()))
	if http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(cuerpo)) != OK:
		http.queue_free()
		al_terminar.call(false, "")


func _al_enviar(correcto: bool, _texto: String) -> void:
	puntuacion_enviada.emit(correcto)


func _al_recibir_top(correcto: bool, texto: String) -> void:
	var filas: Array = []
	if correcto:
		var datos = JSON.parse_string(texto)
		if datos is Array:
			for d in datos:
				if d is Dictionary and d.has("document"):
					var campos: Dictionary = d.document.fields
					filas.append({"nombre": str(campos.nombre.stringValue), "puntos": int(campos.puntos.integerValue)})
	top_recibido.emit(filas, correcto)
