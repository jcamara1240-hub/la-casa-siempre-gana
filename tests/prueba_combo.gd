extends SceneTree
## Comprueba las reglas sin abrir el juego:
##   godot --headless --path . -s res://tests/prueba_combo.gd

var _fallos := 0


func _initialize() -> void:
	_cartas_validas()
	_reglas_del_combo()
	_mazmorras()
	_traducciones()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _igual(obtenido, esperado, que: String) -> void:
	if not is_equal_approx(float(obtenido), float(esperado)):
		_fallos += 1
		print("MAL  %s: salió %s y debía ser %s" % [que, obtenido, esperado])


func _cartas_validas() -> void:
	for id in CartasDB.CARTAS:
		if CartasDB.textura(id) == null:
			_fallos += 1
			print("MAL  falta el dibujo de ", id)
	for id in ObjetosDB.OBJETOS:
		if ObjetosDB.textura(id) == null:
			_fallos += 1
			print("MAL  falta el dibujo del objeto ", id)
	print("cartas: ", CartasDB.CARTAS.size(), "  objetos: ", ObjetosDB.OBJETOS.size())


func _traducciones() -> void:
	var fuente: Font = load("res://assets/fuente/pixel.fnt")
	var textos: Array = []
	for db in [CartasDB.CARTAS, ObjetosDB.OBJETOS, PersonajesDB.PERSONAJES, ObjetosDB.TRANSFORMACIONES]:
		for id in db:
			textos.append(db[id].nombre)
			textos.append(db[id].desc)
	for id in PersonajesDB.PERSONAJES:
		if PersonajesDB.PERSONAJES[id].requisito != "":
			textos.append(PersonajesDB.PERSONAJES[id].requisito)
	for mesa in PersonajesDB.MESAS:
		textos.append(mesa.nombre)
		textos.append(mesa.desc)
	for jefe in PersonajesDB.JEFES.values():
		textos.append(jefe)
	for texto in textos:
		if not Idioma.EN.has(texto):
			_fallos += 1
			print("MAL  sin traducir: ", texto)
	# Cualquier t("...") del código tiene que existir en el diccionario.
	for ruta in _scripts("res://scripts"):
		var codigo := FileAccess.get_file_as_string(ruta)
		var regex := RegEx.create_from_string("Idioma\\.t\\(\"([^\"]+)\"\\)")
		for r in regex.search_all(codigo):
			if not Idioma.EN.has(r.get_string(1)):
				_fallos += 1
				print("MAL  %s sin traducir: %s" % [ruta, r.get_string(1)])
	for clave in ["FILA LLENA. TOCA LA CARTA QUE QUIERAS CAMBIAR O TOCA AQUÍ PARA CANCELAR.", "DESLIZA EL DEDO POR LA SALA PARA ANDAR. TU PERSONAJE ATACA SOLO."]:
		if not Idioma.EN.has(clave):
			_fallos += 1
			print("MAL  sin traducir: ", clave)
	var todos: Array = Idioma.EN.keys() + Idioma.EN.values()
	for texto in todos:
		for i in texto.length():
			var codigo_letra: int = texto.unicode_at(i)
			if not fuente.has_char(codigo_letra):
				_fallos += 1
				print("MAL  la fuente no tiene '%s' en: %s" % [String.chr(codigo_letra), texto])
	print("traducciones comprobadas: ", Idioma.EN.size())


func _scripts(carpeta: String) -> Array:
	var lista: Array = []
	for f in DirAccess.get_files_at(carpeta):
		if f.ends_with(".gd"):
			lista.append(carpeta + "/" + f)
	for d in DirAccess.get_directories_at(carpeta):
		lista += _scripts(carpeta + "/" + d)
	return lista


func _reglas_del_combo() -> void:
	_igual(Combo.resolver(["bala"]).total, 5, "bala sola")
	_igual(Combo.resolver(["afilar", "bala"]).total, 8, "modificador a la izquierda")
	_igual(Combo.resolver(["bala", "afilar"]).total, 5, "modificador sin ataque detrás")
	_igual(Combo.resolver(["afilar", "bala", "bala"]).total, 13, "el modificador lo gasta un solo ataque")
	_igual(Combo.resolver(["bala", "doble_nada"]).total, 10, "x2 al final")
	_igual(Combo.resolver(["doble_nada", "bala"]).total, 5, "x2 al principio no hace nada")
	_igual(Combo.resolver(["bala", "doble_nada", "bala"]).total, 15, "x2 solo mira a su izquierda")
	_igual(Combo.resolver(["bala", "doble_nada", "doble_nada"]).total, 20, "los multiplicadores se acumulan")
	_igual(Combo.resolver(["bala", "bala", "escalera"]).total, 20, "escalera con dos ataques")
	_igual(Combo.resolver(["bala", "eco"]).total, 7.5, "eco")
	_igual(Combo.resolver(["tapete", "bala", "bala"]).total, 14, "tapete afecta a toda su derecha")
	_igual(Combo.resolver(["doble", "bala"]).total, 10, "un proyectil más")
	var r := Combo.resolver(["bala", "doble_nada"])
	_igual(r.ataques[0].dano, 10, "el x2 llega al daño real de la bala")
	_igual(int(Combo.resolver(["afilar"]).pasos[0].sin_efecto), 1, "avisa de la carta sin efecto")
	_igual(Combo.resolver(["", "bala", ""]).total, 5, "huecos vacíos")
	_igual(Combo.resolver(["bala", "bala", "pareja"]).total, 20, "pareja")
	_igual(Combo.resolver(["bala", "abanico", "pareja"]).total, 14, "pareja sin pareja")
	_igual(Combo.resolver(["bala", "comodin", "pareja"]).total, 20, "el comodín copia y cuenta para la pareja")
	_igual(Combo.resolver(["comodin", "bala"]).total, 5, "comodín sin carta a su izquierda")
	_igual(Combo.resolver(["bala", "all_in"]).total, 15, "all in en la última ranura con la fila llena")
	_igual(Combo.resolver(["bala", "all_in", ""]).total, 5, "all in con un hueco")
	_igual(Combo.resolver(["bala", "bala", "bala", "color"]).total, 45, "color")
	_igual(Combo.resolver(["bala", "bala", "bala", "abanico", "abanico", "full"]).total, 165, "full")
	_igual(Combo.resolver(["bala", "racha"], {"racha": 4}).total, 10, "racha")
	_igual(Combo.resolver(["bala", "hucha"], {"monedas": 40}).total, 10, "hucha")
	_igual(Combo.resolver(["bala", "mano_muerta"], {"vida": 2}).total, 15, "mano del muerto")
	_igual(Combo.resolver(["bala", "mano_muerta"], {"vida": 8}).total, 5, "mano del muerto con vida")
	_igual(Combo.resolver(["bala", "solitario", "propina"]).total, 7.5, "solitario acompañado")
	_igual(Combo.resolver(["bala", "casa"], {"monedas": 3}).coste, 1, "la casa cobra")
	_igual(Combo.resolver(["bala", "casa"], {"monedas": 0}).total, 5, "la casa sin monedas")
	_igual(Combo.resolver(["subir", "bala"]).total, 7.5, "subir la apuesta")
	_igual(Combo.resolver(["resto", "bala"], {"monedas": 16}).total, 7, "todo al resto")
	_igual(Combo.resolver(["bala", "cara_cruz"]).total, 10, "cara o cruz: previsión media")
	_igual(Combo.resolver(["bala"], {"dano_global": 2.0}).total, 7, "el Mafioso suma daño a todo")


func _mazmorras() -> void:
	var azar := RandomNumberGenerator.new()
	for semilla in 1000:
		azar.seed = semilla + 1
		var cuantas := 13 + semilla % 3
		var salas := GeneradorMazmorra.generar(azar, cuantas)
		if salas.size() != cuantas:
			_fallos += 1
			print("MAL  semilla %d: %d salas" % [semilla, salas.size()])
			continue
		var cuenta := {}
		for c in salas:
			cuenta[salas[c].tipo] = cuenta.get(salas[c].tipo, 0) + 1
		for t in [GeneradorMazmorra.Tipo.INICIO, GeneradorMazmorra.Tipo.JEFE, GeneradorMazmorra.Tipo.TESORO, GeneradorMazmorra.Tipo.TIENDA]:
			if cuenta.get(t, 0) != 1:
				_fallos += 1
				print("MAL  semilla %d: tipo %d x%d" % [semilla, t, cuenta.get(t, 0)])
	print("mazmorras comprobadas: 1000")
