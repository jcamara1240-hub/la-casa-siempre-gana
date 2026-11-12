extends SceneTree
## Comprueba las reglas sin abrir el juego:
##   godot --headless --path . -s res://tests/prueba_combo.gd

var _fallos := 0


func _initialize() -> void:
	_cartas_validas()
	_datos_coherentes()
	_reglas_del_combo()
	_cartas_nuevas()
	_desglose()
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
	for db in [CartasDB.CARTAS, ObjetosDB.OBJETOS, PersonajesDB.PERSONAJES, ObjetosDB.TRANSFORMACIONES, LogrosDB.LOGROS]:
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
	for clave in ["JUGAR RETO", "PUNTOS", "FILA LLENA. TOCA LA CARTA QUE QUIERAS CAMBIAR O TOCA AQUÍ PARA CANCELAR.", "DESLIZA EL DEDO POR LA SALA PARA ANDAR. TU PERSONAJE ATACA SOLO."]:
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
	_igual(Combo.resolver(["cortar", "bala"]).total, 10.5, "cortar: 3 balas al 70%")
	_igual(Combo.resolver(["bala", "sobre", "bala"]).total, 11, "sobre bajo cuerda cuenta lo de su izquierda")
	_igual(Combo.resolver(["bala", "bala", "abanico", "abanico", "doble_pareja"]).total, 112, "doble pareja")
	_igual(Combo.resolver(["bala", "carta_alta"]).total, 15, "carta alta con un ataque")
	_igual(Combo.resolver(["bala", "bala", "carta_alta"]).total, 10, "carta alta con dos ataques")
	_igual(Combo.resolver(["bala", "bala", "bala", "bala", "bala", "bala", "bala", "siete"]).total, 245, "siete de la suerte")
	_igual(Combo.resolver(["bala", "bancarrota"], {"monedas": 0}).total, 15, "bancarrota")
	_igual(Combo.resolver(["bala", "mesa_llena"]).total, 7.5, "mesa llena")
	_igual(Combo.resolver(["bala", "", "rojo_negro"]).total, 10, "rojo o negro en ranura impar")
	_igual(Combo.resolver(["bala", "rojo_negro"]).total, 5, "rojo o negro en ranura par")


## Los nombres que se cruzan entre bases de datos tienen que existir.
func _datos_coherentes() -> void:
	var listas := {"cartas iniciales": [Progreso.RARAS_INICIALES, CartasDB.CARTAS],
		"objetos iniciales": [Progreso.OBJETOS_INICIALES, ObjetosDB.OBJETOS]}
	for que in listas:
		for id in listas[que][0]:
			if not listas[que][1].has(id):
				_fallos += 1
				print("MAL  %s: no existe %s" % [que, id])
	for id in Progreso.RARAS_INICIALES:
		if CartasDB.CARTAS.has(id) and CartasDB.CARTAS[id].rareza == 0:
			_fallos += 1
			print("MAL  %s es común: no hace falta en las iniciales" % id)
	for t in ObjetosDB.TRANSFORMACIONES:
		for pieza in ObjetosDB.TRANSFORMACIONES[t].piezas:
			if not ObjetosDB.OBJETOS.has(pieza):
				_fallos += 1
				print("MAL  la transformación %s pide %s, que no existe" % [t, pieza])
	for p in PersonajesDB.PERSONAJES:
		for id in PersonajesDB.PERSONAJES[p].cartas:
			if not CartasDB.CARTAS.has(id):
				_fallos += 1
				print("MAL  %s empieza con %s, que no existe" % [p, id])
	var campos := {CartasDB.Tipo.ATAQUE: ["dano", "n"], CartasDB.Tipo.MODIFICADOR: ["mod", "valor"], CartasDB.Tipo.MULTIPLICADOR: ["mult"]}
	for id in CartasDB.CARTAS:
		var carta: Dictionary = CartasDB.CARTAS[id]
		for campo in campos[carta.tipo]:
			if not carta.has(campo):
				_fallos += 1
				print("MAL  a la carta %s le falta %s" % [id, campo])


func _cartas_nuevas() -> void:
	# Ataques nuevos, solos.
	_igual(Combo.resolver(["recortada"]).total, 12, "recortada: 6 perdigones de 2")
	_igual(Combo.resolver(["tommy"]).total, 12, "metralleta: 8 balas de 1.5")
	_igual(Combo.resolver(["ruleta_rusa"]).total, 11, "ruleta rusa: previsión media (6 x 11/6)")
	_igual(Combo.resolver(["dinamita"]).total, 14, "dinamita")
	_igual(Combo.resolver(["laser"]).total, 9, "láser")
	_igual(Combo.resolver(["corcho"]).total, 5, "corcho")
	_igual(Combo.resolver(["corcho"]).ataques[0].paredes, 3, "el corcho rebota 3 veces")
	_igual(Combo.resolver(["mina"]).total, 18, "dos fichas trampa de 9")
	_igual(Combo.resolver(["botella"]).total, 7, "botella")
	# Modificadores nuevos: los gasta solo el siguiente ataque.
	var r := Combo.resolver(["trucada", "bala"])
	_igual(r.total, 5, "bala trucada no cambia el daño")
	_igual(r.ataques[0].busca, 1, "bala trucada: el ataque persigue")
	_igual(Combo.resolver(["empujon", "bala"]).ataques[0].empuje, 1, "empujón")
	r = Combo.resolver(["metralla", "bala", "bala"])
	_igual(r.ataques[0].metralla, 1, "metralla en el primer ataque")
	_igual(r.ataques[1].metralla, 0, "metralla no pasa al segundo ataque")
	r = Combo.resolver(["calibre", "bala"])
	_igual(r.total, 9, "gran calibre: +4")
	_igual(r.ataques[0].calibre, 1, "gran calibre: bala gorda")
	_igual(Combo.resolver(["calibre", "subir", "bala"]).total, 13.5, "gran calibre suma antes del porcentaje")
	_igual(int(Combo.resolver(["metralla"]).pasos[0].sin_efecto), 1, "metralla sin ataque detrás")
	_igual(Combo.resolver(["trucada", "bala", "eco"]).ataques[1].busca, 1, "la reapuesta copia los modificadores")
	# Atravesar y rebotar en los ataques sin proyectil.
	_igual(Combo.resolver(["rebote", "laser"]).ataques[0].paredes, 2, "carambola: el láser rebota en las paredes")
	_igual(Combo.resolver(["perforar", "laser"]).ataques[0].radio, 10, "farol: el láser es más ancho")
	_igual(Combo.resolver(["perforar", "dinamita"]).ataques[0].radio, 58, "farol: más área a la dinamita")
	_igual(Combo.resolver(["rebote", "mina"]).ataques[0].radio, 38, "carambola: más área a las fichas trampa")
	_igual(Combo.resolver(["perforar", "botella"]).ataques[0].radio, 48, "farol: la botella llega más lejos")
	# Multiplicadores nuevos: sin contexto (previsión) valen x1.
	r = Combo.resolver(["bala", "fiebre"])
	_igual(r.total, 5, "fiebre sin fiebre")
	_igual(int(r.pasos[1].sin_efecto), 1, "fiebre sin fiebre no hace nada")
	_igual(Combo.resolver(["bala", "fiebre"], {"fiebre": 2}).total, 10, "fiebre nivel 2: x2")
	_igual(Combo.resolver(["bala", "fiebre"], {"fiebre": 3}).total, 12.5, "fiebre nivel 3: x2.5")
	_igual(Combo.resolver(["bala", "pelos"]).total, 5, "por los pelos sin voltereta")
	_igual(Combo.resolver(["bala", "pelos"], {"voltereta": true}).total, 15, "por los pelos tras rodar")
	_igual(Combo.resolver(["bala", "ordago"]).total, 5, "órdago sin órdagos")
	_igual(Combo.resolver(["bala", "ordago"], {"ordagos": 2}).total, 15, "órdago con dos guardados")
	_igual(Combo.resolver(["pelos", "bala"], {"voltereta": true}).total, 5, "por los pelos solo mira a su izquierda")
	_igual(Combo.resolver(["bala", "fiebre", "pelos"], {"fiebre": 1, "voltereta": true}).total, 22.5, "fiebre y pelos se acumulan")
	# La Ruleta Rusa de verdad: o 6 o 36, una de cada seis más o menos.
	var azar := RandomNumberGenerator.new()
	azar.seed = 7
	var premios := 0
	for _i in 600:
		var tiro := Combo.resolver(["ruleta_rusa"], {"azar": azar})
		if tiro.ataques[0].premio:
			premios += 1
			_igual(tiro.total, 36, "ruleta rusa: el premio hace x6")
		else:
			_igual(tiro.total, 6, "ruleta rusa: sin premio, daño normal")
	if premios < 60 or premios > 150:
		_fallos += 1
		print("MAL  ruleta rusa: %d premios en 600 tiros" % premios)
	# Los ataques sueltos (los usan los objetos) llevan todos sus campos.
	var suelto := Combo.ataque_suelto("nova", 3.0, 8)
	_igual(suelto.dano, 3, "ataque suelto: daño")
	_igual(suelto.n, 8, "ataque suelto: cantidad")
	_igual(int(suelto.has("busca") and suelto.has("paredes") and suelto.has("premio")), 1, "ataque suelto: campos nuevos")
	_igual(int(Combo.ataque_suelto("trucada", 2.0, 1).id == "bala"), 1, "ataque suelto con algo que no es un ataque")


## El desglose (lo que suma o multiplica cada carta) rehace exactamente el total.
func _cuadra(fila: Array, ctx := {}) -> bool:
	var r := Combo.resolver(fila, ctx)
	var cuenta := 0.0
	for paso in r.pasos:
		match String(paso.aporte):
			"suma": cuenta += float(paso.valor)
			"mult": cuenta *= float(paso.valor)
			"": pass
			_: return false
		if not is_equal_approx(cuenta, float(paso.total)):
			return false
	return is_equal_approx(cuenta, float(r.total))


func _desglose() -> void:
	var r := Combo.resolver(["afilar", "bala", "doble_nada", "eco"])
	var aportes: Array = r.pasos.map(func(p): return "%s:%s" % [p.aporte, Combo._numero(p.valor)])
	if aportes != [":0", "suma:8", "mult:2", "suma:8"]:
		_fallos += 1
		print("MAL  desglose: ", aportes)
	# El orden cambia la cuenta, y el desglose la sigue: 5 x2 + 5 = 15, (5 + 5) x2 = 20.
	_igual(Combo.resolver(["bala", "doble_nada", "bala"]).pasos[-1].total, 15, "desglose: x2 en medio")
	_igual(Combo.resolver(["bala", "bala", "doble_nada"]).pasos[-1].total, 20, "desglose: x2 al final")
	_igual(int(Combo.resolver(["doble_nada", "bala"]).pasos[0].aporte == ""), 1, "un x2 sin nada a la izquierda no aporta")
	var fijas := [["bala"], ["afilar", "bala", "bala"], ["bala", "eco"], ["bala", "bala", "escalera"],
		["bala", "comodin", "pareja"], ["bala", "bala", "bala", "abanico", "abanico", "full"],
		["calibre", "subir", "bala"], ["tapete", "bala", "bala"], ["bala", "fiebre", "pelos"], ["", "bala", "", "doble_nada"]]
	for fila in fijas:
		if not _cuadra(fila, {"fiebre": 1, "voltereta": true}):
			_fallos += 1
			print("MAL  el desglose no cuadra con el total: ", fila)
	# Y con filas al azar, con el contexto y la Ruleta Rusa de verdad.
	var azar := RandomNumberGenerator.new()
	azar.seed = 31
	var ids: Array = CartasDB.CARTAS.keys()
	var malas := 0
	for _i in 800:
		var fila: Array = []
		for _j in azar.randi_range(1, 8):
			fila.append("" if azar.randf() < 0.1 else ids[azar.randi() % ids.size()])
		var ctx := {"monedas": azar.randi_range(0, 60), "racha": azar.randi_range(0, 6), "vida": azar.randi_range(1, 8),
			"fiebre": azar.randi_range(0, 3), "voltereta": azar.randf() < 0.5, "ordagos": azar.randi_range(0, 3),
			"dano_global": float(azar.randi_range(0, 2)), "azar": azar}
		if not _cuadra(fila, ctx):
			malas += 1
			if malas < 5:
				print("MAL  el desglose no cuadra: ", fila)
	if malas > 0:
		_fallos += 1
	print("desgloses comprobados: 800 al azar")


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
