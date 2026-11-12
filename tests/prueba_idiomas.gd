extends SceneTree
## Los idiomas de scripts/idiomas/: mismos textos que el inglés, mismos %d/%s, glifos en la fuente,
## nombres de élites con su género, y el selector de Opciones recorre los seis y se guarda.
##   godot --headless --fixed-fps 60 --path . -s res://tests/prueba_idiomas.gd

var _fallos := 0
var I = load("res://scripts/idioma.gd")


func _initialize() -> void:
	_correr.call_deferred()


func _ok(condicion: bool, que: String) -> void:
	print("bien: " if condicion else "MAL: ", que)
	if not condicion:
		_fallos += 1


func _huecos(texto: String) -> Array:
	var regex := RegEx.create_from_string("%[-+0-9.]*[a-zA-Z%]")
	return regex.search_all(texto).map(func(r): return r.get_string())


## Los caracteres que tiene la fuente, leídos del .fnt.
func _glifos(ruta: String) -> Dictionary:
	var hay := {}
	var regex := RegEx.create_from_string("char id=(\\d+)")
	for r in regex.search_all(FileAccess.get_file_as_string(ruta)):
		hay[int(r.get_string(1))] = true
	return hay


func _tecla(codigo: Key) -> void:
	for pulsada in [true, false]:
		var e := InputEventKey.new()
		e.keycode = codigo
		e.physical_keycode = codigo
		e.pressed = pulsada
		root.push_input(e)
	await process_frame


func _correr() -> void:
	_ok(I.IDIOMAS == ["es", "en", "pt", "fr", "de", "it"], "seis idiomas")
	_ok(I.NOMBRES.values() == ["ESPAÑOL", "ENGLISH", "PORTUGUÊS", "FRANÇAIS", "DEUTSCH", "ITALIANO"], "cada uno con su nombre en su idioma")
	var fuentes := [_glifos("res://assets/fuente/pixel.fnt"), _glifos("res://assets/fuente/pixel2.fnt")]
	for codigo in I.OTROS:
		var textos: Dictionary = I.OTROS[codigo].TEXTOS
		var faltan: Array = I.EN.keys().filter(func(k): return not textos.has(k))
		var sobran: Array = textos.keys().filter(func(k): return not I.EN.has(k))
		_ok(faltan.is_empty(), "%s: tiene todos los textos del inglés (%d)%s" % [codigo, textos.size(), "" if faltan.is_empty() else ". Faltan: " + str(faltan)])
		_ok(sobran.is_empty(), "%s: no sobra ninguno %s" % [codigo, "" if sobran.is_empty() else str(sobran)])
		var malos: Array = []
		var sin_glifo := {}
		for clave in textos:
			var valor: String = textos[clave]
			if _huecos(clave) != _huecos(valor):
				malos.append(clave)
			if valor.strip_edges() == "":
				malos.append(clave)
			for texto in [valor, valor.to_upper()]:
				for ch in texto:
					if ch != " " and not (fuentes[0].has(ch.unicode_at(0)) and fuentes[1].has(ch.unicode_at(0))):
						sin_glifo[ch] = true
		_ok(malos.is_empty(), "%s: mismos %%d/%%s y en el mismo orden %s" % [codigo, "" if malos.is_empty() else str(malos)])
		_ok(sin_glifo.is_empty(), "%s: todas sus letras están en la fuente %s" % [codigo, "" if sin_glifo.is_empty() else str(sin_glifo.keys())])
	var nombres_sin_glifo: Array = []
	for nombre in I.NOMBRES.values():
		for ch in nombre:
			if not fuentes[0].has(ch.unicode_at(0)):
				nombres_sin_glifo.append(ch)
	_ok(nombres_sin_glifo.is_empty(), "los nombres de los idiomas tienen glifos " + str(nombres_sin_glifo))

	# Las frases del Dueño caben en una línea (como comprueba prueba_enganche_a en español e inglés)
	# y el resultado para compartir del reto existe en cada idioma y se puede pintar.
	var fuente: Font = load("res://assets/fuente/pixel.fnt")
	var F = load("res://scripts/frases_db.gd")
	var R = load("res://scripts/pantalla_reto.gd")
	var detalle := {"fecha": "2026-11-12", "gano": false, "piso": 3, "puntos": 23410}
	for codigo in I.OTROS:
		I.actual = codigo
		var largas: Array = []
		for id in F.FRASES:
			if fuente.get_string_size(I.t(F.FRASES[id].texto), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > 560.0:
				largas.append(id)
		_ok(largas.is_empty(), "%s: las frases del Dueño caben en una línea %s" % [codigo, largas])
		_ok(R.COMPARTIR.has(codigo), "%s: tiene su texto para compartir" % codigo)
		var compartir: String = R.texto_compartir(detalle, 3).replace("·", "-").to_upper()
		var raros: Array = []
		for ch in compartir:
			if ch != "\n" and ch != " " and not fuente.has_char(ch.unicode_at(0)):
				raros.append(ch)
		_ok(raros.is_empty(), "%s: el resultado para compartir se puede pintar: %s %s" % [codigo, compartir.get_slice("\n", 0), raros])
	I.actual = "es"
	# Cae al inglés y luego al español.
	I.actual = "de"
	_ok(I.t("JUGAR") == "SPIELEN", "en alemán se traduce")
	_ok(I.t("TEXTO QUE NO EXISTE") == "TEXTO QUE NO EXISTE", "lo desconocido se queda en español")
	_ok(I.buscar("JUGAR", {"OPCIONES": "OPTIONEN"}) == "PLAY", "si falta en el idioma, sale el inglés")
	_ok(I.buscar("NO EXISTE", {}) == "NO EXISTE", "y si tampoco, el español")

	# Nombres de élites: orden, género y conjunción de cada idioma.
	var E = load("res://scripts/enemigo.gd")
	var esperados := {
		"es": ["Ficha Blindada y Veloz", "Matón Escudado y Ardiente"],
		"en": ["Armored Swift Chip", "Shielded Blazing Thug"],
		"pt": ["Ficha Blindada e Veloz", "Capanga Escudado e Ardente"],
		"fr": ["Jeton Blindé et Rapide", "Gros Bras Protégé et Incendiaire"],
		"de": ["Gepanzerter Schneller Chip", "Beschildeter Brennender Schläger"],
		"it": ["Fiche Corazzata e Veloce", "Scagnozzo Scudato e Ardente"],
	}
	for codigo in esperados:
		I.actual = codigo
		var a: String = E.nombre_de("ficha", ["blindado", "veloz"])
		var b: String = E.nombre_de("maton", ["escudo", "rastro"])
		_ok([a, b] == esperados[codigo], "%s: %s / %s" % [codigo, a, b])
	I.actual = "de"
	_ok(E.nombre_de("reina", ["veloz", "rastro"]) == "Schnelle Brennende Dame", "alemán femenino: " + E.nombre_de("reina", ["veloz", "rastro"]))
	I.actual = "fr"
	_ok(E.nombre_de("camara", ["salto"]) == "Caméra Fuyante", "francés femenino: " + E.nombre_de("camara", ["salto"]))
	I.actual = "es"

	# El selector de Opciones recorre los seis y se guarda en ajustes.cfg.
	DirAccess.remove_absolute("user://partida.sav")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	var juego: Node = root.get_node("Juego")
	juego.cambiar_idioma("es")
	var menu = m._menu
	menu._ir_a(1)
	await process_frame
	_ok(menu._items[0] == "idioma", "Opciones empieza por el idioma")
	var vistos: Array = [I.actual]
	for i in 6:
		await _tecla(KEY_ENTER)
		vistos.append(I.actual)
		var cfg := ConfigFile.new()
		_ok(cfg.load("user://ajustes.cfg") == OK and cfg.get_value("ajustes", "idioma") == I.actual, "guardado en ajustes.cfg: " + I.actual)
		_ok(menu._texto("idioma").ends_with(I.NOMBRES[I.actual]), "el botón dice " + menu._texto("idioma"))
	_ok(vistos == ["es", "en", "pt", "fr", "de", "it", "es"], "Enter recorre los seis y vuelve: " + str(vistos))
	await _tecla(KEY_LEFT)
	_ok(I.actual == "it", "la flecha izquierda va hacia atrás")
	# Con ajuste guardado se respeta; sin él, el idioma del sistema si es uno de los seis.
	juego.cambiar_idioma("fr")
	I.actual = "es"
	juego.cargar_ajustes()
	_ok(I.actual == "fr", "se respeta el idioma guardado")
	DirAccess.remove_absolute("user://ajustes.cfg")
	juego.cargar_ajustes()
	var sistema := OS.get_locale_language()
	_ok(I.actual == (sistema if I.IDIOMAS.has(sistema) else "en"), "sin ajustes, el del sistema (%s) o inglés: %s" % [sistema, I.actual])
	juego.cambiar_idioma("es")
	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)
