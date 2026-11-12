class_name PantallaReto
extends Control
## El reto diario: la misma mazmorra para todos cada día (fecha UTC) y tu marca.
## Si hay online (ver scripts/online.gd), una segunda pestaña con la tabla MUNDIAL.
## Teclado: Enter juega, Esc vuelve, izquierda/derecha cambia de pestaña, arriba/abajo
## mueve la tabla, H cambia hoy/histórico, N cambia el nombre. Táctil: todo se toca y la
## tabla se arrastra.

signal jugar_reto
signal atras

enum Pestana { HOY, MUNDIAL }

const CAJA_JUGAR := Rect2(150, 330, 160, 20)
const CAJA_VOLVER := Rect2(330, 330, 160, 20)
const CAJA_PESTANA_HOY := Rect2(226, 44, 90, 16)
const CAJA_PESTANA_MUNDIAL := Rect2(324, 44, 90, 16)
const CAJA_NOMBRE := Rect2(60, 66, 200, 14)
const CAJA_MODO := Rect2(440, 66, 140, 14)
const CAJA_SUBIR := Rect2(588, 106, 20, 20)
const CAJA_BAJAR := Rect2(588, 252, 20, 20)
const CAJA_ACEPTAR := Rect2(226, 200, 90, 18)
const CAJA_AHORA_NO := Rect2(324, 200, 90, 18)
const FILAS_VISIBLES := 15
const Y_CABECERA := 102.0
const Y_FILAS := 114.0
const ALTO_FILA := 11.0
const COLOR_CREMA := Color8(247, 236, 210)
const COLOR_ORO := Color8(247, 198, 74)
const COLOR_GRIS := Color8(168, 154, 142)
const COLOR_VERDE := Color8(108, 207, 148)
const COLOR_ROJO := Color8(214, 61, 79)
const COLOR_BOTON := Color8(42, 31, 61)
const COLOR_BOTON_FUERTE := Color8(122, 90, 160)

## La pone main.gd. Puede estar apagada (sin online.cfg): entonces no hay pestaña MUNDIAL.
var online: Online

var _pestana := Pestana.HOY
var _historico := false
var _filas: Array = []
var _yo: Dictionary = {}
var _total := 0
var _estado := ""  # "", "cargando", "sin_conexion", "servidor"
var _desplazado := 0
var _arrastre := 0.0
var _fecha := ""
var _reloj := 0.0
var _conectado := false
var _nombre_preguntado := false
var _eligiendo_nombre := false
var _error_nombre := ""
var _esperando_nombre := false
var _campo: LineEdit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false
	_fecha = Juego.fecha_hoy()
	# El campo de texto del nombre: con teclado se escribe sin más; en el móvil saca el teclado.
	_campo = LineEdit.new()
	_campo.position = Vector2(220, 156)
	_campo.size = Vector2(200, 20)
	_campo.max_length = Online.NOMBRE_MAX
	_campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campo.visible = false
	var caja := StyleBoxFlat.new()
	caja.bg_color = COLOR_BOTON
	caja.border_color = COLOR_ORO
	caja.set_border_width_all(1)
	_campo.add_theme_stylebox_override("normal", caja)
	_campo.add_theme_stylebox_override("focus", caja)
	_campo.add_theme_color_override("font_color", COLOR_CREMA)
	_campo.text_submitted.connect(func(_t: String) -> void: _aceptar_nombre())
	add_child(_campo)


func hay_mundial() -> bool:
	return online != null and online.activo


func abrir() -> void:
	visible = true
	_conectar()
	_fecha = Juego.fecha_hoy()
	_pestana = Pestana.HOY
	_cerrar_nombre()
	if hay_mundial():
		_pedir()
		# La primera vez, que elija nombre (puede dejarlo para luego).
		if online.necesita_nombre() and not _nombre_preguntado:
			_abrir_nombre()
	queue_redraw()


func _conectar() -> void:
	if _conectado or online == null:
		return
	_conectado = true
	online.tabla_lista.connect(_al_llegar_tabla)
	online.tabla_fallida.connect(_al_fallar_tabla)
	online.nombre_resultado.connect(_al_resultado_nombre)
	online.envio_terminado.connect(_al_enviar)


## Tu puntuación acaba de llegar al servidor: la tabla ya la trae.
func _al_enviar(_ok: bool, _error: String) -> void:
	if visible and hay_mundial():
		_pedir()


func _pedir() -> void:
	if not hay_mundial():
		return
	_estado = "cargando"
	if _historico:
		online.pedir_historico()
	else:
		online.pedir_tabla(_fecha)
	queue_redraw()


func _al_llegar_tabla(datos: Dictionary) -> void:
	if (datos.get("tipo", "") == "historico") != _historico:
		return
	_filas = datos.get("top") if datos.get("top") is Array else []
	_yo = datos.get("yo") if datos.get("yo") is Dictionary else {}
	_total = int(datos.get("total", _filas.size()))
	_estado = ""
	_desplazado = clampi(_desplazado, 0, _max_desplazado())
	queue_redraw()


func _al_fallar_tabla(tipo: String, motivo: String) -> void:
	if (tipo == "historico") != _historico:
		return
	_estado = motivo
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_reloj -= delta
	if _reloj > 0.0:
		return
	_reloj = 1.0
	# Si cambia el día con la pantalla abierta, se pasa al reto nuevo.
	var hoy := Juego.fecha_hoy()
	if hoy != _fecha:
		_fecha = hoy
		_filas = []
		_yo = {}
		if hay_mundial() and not _historico:
			_pedir()
	queue_redraw()


func _jugar() -> void:
	Sonido.tocar("clic")
	_cerrar_nombre()
	visible = false
	jugar_reto.emit()


func _volver() -> void:
	Sonido.tocar("clic")
	_cerrar_nombre()
	visible = false
	atras.emit()


func _cambiar_pestana(p: Pestana) -> void:
	if (p == Pestana.MUNDIAL and not hay_mundial()) or _pestana == p:
		return
	Sonido.tocar("clic")
	_pestana = p
	if p == Pestana.MUNDIAL:
		if online.necesita_nombre() and not _nombre_preguntado:
			_abrir_nombre()
		if _filas.is_empty() and _estado != "cargando":
			_pedir()
	queue_redraw()


func _cambiar_modo() -> void:
	Sonido.tocar("clic")
	_historico = not _historico
	_filas = []
	_yo = {}
	_desplazado = 0
	_pedir()


func _mover(filas: int) -> void:
	_desplazado = clampi(_desplazado + filas, 0, _max_desplazado())
	queue_redraw()


func _max_desplazado() -> int:
	return maxi(_filas.size() - FILAS_VISIBLES, 0)


# ---------------------------------------------------------------- nombre
func _abrir_nombre() -> void:
	_nombre_preguntado = true
	_eligiendo_nombre = true
	_error_nombre = ""
	_esperando_nombre = false
	_campo.text = online.nombre if online != null else ""
	_campo.visible = true
	_campo.grab_focus()
	queue_redraw()


func _cerrar_nombre() -> void:
	_eligiendo_nombre = false
	_esperando_nombre = false
	if _campo != null:
		_campo.visible = false
		_campo.release_focus()
	queue_redraw()


func _aceptar_nombre() -> void:
	if _esperando_nombre or online == null:
		return
	var error := Online.revisar_nombre(_campo.text)
	if error != "":
		_error_nombre = error
		queue_redraw()
		return
	Sonido.tocar("clic")
	_esperando_nombre = true
	_error_nombre = ""
	online.elegir_nombre(_campo.text)
	queue_redraw()


func _al_resultado_nombre(ok: bool, error: String) -> void:
	_esperando_nombre = false
	if ok:
		_cerrar_nombre()
		_pedir()
	else:
		_error_nombre = error
	queue_redraw()


static func texto_error_nombre(error: String) -> String:
	match error:
		"": return ""
		"nombre_corto": return Idioma.t("DEMASIADO CORTO: MÍNIMO 3.")
		"nombre_largo": return Idioma.t("DEMASIADO LARGO: MÁXIMO 16.")
		"nombre_invalido": return Idioma.t("SOLO LETRAS, NÚMEROS Y GUIONES.")
		"nombre_feo": return Idioma.t("ESE NOMBRE NO ESTÁ PERMITIDO.")
		"nombre_ocupado": return Idioma.t("ESE NOMBRE YA LO TIENE OTRA PERSONA.")
		"sin_conexion": return Idioma.t("SIN CONEXIÓN. INTÉNTALO MÁS TARDE.")
	return Idioma.t("ALGO HA FALLADO. INTÉNTALO MÁS TARDE.")


# ---------------------------------------------------------------- entrada
func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventScreenDrag:
		# Arrastrar la tabla con el dedo.
		if _pestana != Pestana.MUNDIAL or _eligiendo_nombre:
			return
		_arrastre -= evento.relative.y
		while absf(_arrastre) >= ALTO_FILA:
			_mover(1 if _arrastre > 0.0 else -1)
			_arrastre -= signf(_arrastre) * ALTO_FILA
		return
	if not (evento is InputEventMouseButton) or not evento.pressed:
		return
	match evento.button_index:
		MOUSE_BUTTON_WHEEL_UP: _mover(-1)
		MOUSE_BUTTON_WHEEL_DOWN: _mover(1)
		MOUSE_BUTTON_LEFT: tocar(evento.position)


## Un toque o clic en la pantalla (también lo usan las pruebas).
func tocar(p: Vector2) -> void:
	if _eligiendo_nombre:
		if CAJA_ACEPTAR.has_point(p):
			_aceptar_nombre()
		elif CAJA_AHORA_NO.has_point(p):
			Sonido.tocar("clic")
			_cerrar_nombre()
		elif Rect2(_campo.position, _campo.size).has_point(p):
			_campo.grab_focus()
		return
	if CAJA_JUGAR.has_point(p):
		_jugar()
	elif CAJA_VOLVER.has_point(p):
		_volver()
	elif hay_mundial() and CAJA_PESTANA_HOY.has_point(p):
		_cambiar_pestana(Pestana.HOY)
	elif hay_mundial() and CAJA_PESTANA_MUNDIAL.has_point(p):
		_cambiar_pestana(Pestana.MUNDIAL)
	elif _pestana == Pestana.MUNDIAL:
		if CAJA_NOMBRE.has_point(p):
			_abrir_nombre()
		elif CAJA_MODO.has_point(p):
			_cambiar_modo()
		elif CAJA_SUBIR.has_point(p):
			_mover(-5)
		elif CAJA_BAJAR.has_point(p):
			_mover(5)


func _input(evento: InputEvent) -> void:
	# Con el campo de texto abierto, Esc cierra (antes de que se lo quede el campo).
	if visible and _eligiendo_nombre and evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
		_cerrar_nombre()
		get_viewport().set_input_as_handled()


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or _eligiendo_nombre or not (evento is InputEventKey) or not evento.pressed:
		return
	if tecla(evento.keycode, evento.echo):
		get_viewport().set_input_as_handled()


## Lo que hace cada tecla. Devuelve false si no hace nada.
func tecla(codigo: int, repetida := false) -> bool:
	var mundial := _pestana == Pestana.MUNDIAL
	if codigo in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and not repetida:
		_jugar()
	elif codigo == KEY_ESCAPE and not repetida:
		_volver()
	elif codigo in [KEY_LEFT, KEY_RIGHT, KEY_TAB] and hay_mundial():
		_cambiar_pestana(Pestana.HOY if mundial else Pestana.MUNDIAL)
	elif not mundial:
		return false
	elif codigo == KEY_UP:
		_mover(-1)
	elif codigo == KEY_DOWN:
		_mover(1)
	elif codigo == KEY_PAGEUP:
		_mover(-FILAS_VISIBLES)
	elif codigo == KEY_PAGEDOWN:
		_mover(FILAS_VISIBLES)
	elif codigo == KEY_H and not repetida:
		_cambiar_modo()
	elif codigo == KEY_N and not repetida:
		_abrir_nombre()
	elif codigo == KEY_R and not repetida:
		_pedir()
	else:
		return false
	return true


# ---------------------------------------------------------------- dibujo
func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color8(20, 16, 30))
	draw_string(Juego.fuente_grande, Vector2(0, 32), Idioma.t("RETO DIARIO"), HORIZONTAL_ALIGNMENT_CENTER, 640, 16, COLOR_ORO)
	if hay_mundial():
		_boton(CAJA_PESTANA_HOY, Idioma.t("HOY"), _pestana == Pestana.HOY)
		_boton(CAJA_PESTANA_MUNDIAL, Idioma.t("MUNDIAL"), _pestana == Pestana.MUNDIAL)
	if _pestana == Pestana.MUNDIAL and hay_mundial():
		_dibujar_mundial()
	else:
		_dibujar_hoy()
	_boton(CAJA_JUGAR, Idioma.t("JUGAR RETO") if Progreso.reto_puntuable(_fecha) else Idioma.t("PRACTICAR"), true)
	_boton(CAJA_VOLVER, Idioma.t("VOLVER"), false)
	if _eligiendo_nombre:
		_dibujar_nombre()


func _boton(caja: Rect2, texto: String, fuerte: bool) -> void:
	draw_rect(caja, COLOR_BOTON_FUERTE if fuerte else COLOR_BOTON)
	draw_string(Juego.fuente, Vector2(caja.position.x, caja.position.y + caja.size.y * 0.5 + 4.0), texto,
			HORIZONTAL_ALIGNMENT_CENTER, caja.size.x, 8, COLOR_CREMA)


static func tiempo_texto(segundos: int) -> String:
	return "%d:%02d" % [segundos / 60, segundos % 60]


## Lo que falta para el reto de mañana (medianoche UTC).
static func hasta_manana() -> String:
	var queda := 86400 - int(Time.get_unix_time_from_system()) % 86400
	return "%d:%02d:%02d" % [queda / 3600, (queda / 60) % 60, queda % 60]


func _texto(y: float, texto: String, color: Color, grande := false) -> void:
	draw_string(Juego.fuente_grande if grande else Juego.fuente, Vector2(0, y), texto, HORIZONTAL_ALIGNMENT_CENTER, 640,
			16 if grande else 8, color)


func _dibujar_hoy() -> void:
	_texto(90, Idioma.t("MISMA MAZMORRA PARA TODOS HOY (%s). JUEGAS CON EL TAHÚR.") % _fecha, COLOR_GRIS)
	_texto(104, Idioma.t("NUEVO RETO EN %s (UTC)") % hasta_manana(), COLOR_GRIS)
	if not Progreso.reto_puntuable(_fecha):
		_texto(144, Idioma.t("TU MARCA DE HOY: %d") % Progreso.reto_mejor_hoy(_fecha), COLOR_CREMA, true)
		var d: Dictionary = Progreso.reto_detalle
		if Progreso.reto_fecha == _fecha and String(d.get("fecha", "")) == _fecha:
			_texto(162, Idioma.t("PISO %d   TIEMPO %s   BAJAS %d   MONEDAS %d   GOLPES %d") % [int(d.piso),
					tiempo_texto(int(d.tiempo)), int(d.bajas), int(d.monedas), int(d.golpes)], COLOR_GRIS)
		var practica := Progreso.practica_hoy(_fecha)
		if practica > 0:
			_texto(176, Idioma.t("MEJOR PRÁCTICA: %d (NO PUNTÚA)") % practica, COLOR_GRIS)
	else:
		_texto(144, Idioma.t("AÚN NO HAS JUGADO EL RETO DE HOY"), COLOR_CREMA, true)
	_texto(210, Idioma.t("SOLO PUNTÚA EL PRIMER INTENTO DEL DÍA. LOS DEMÁS SON DE PRÁCTICA."), COLOR_ORO)
	_texto(230, Idioma.t("PUNTOS: 1000 POR PISO, 5000 POR GANAR, 2 POR BAJA, 1 POR MONEDA,"), COLOR_GRIS)
	_texto(242, Idioma.t("-100 POR GOLPE RECIBIDO Y, SI GANAS, 3 POR SEGUNDO POR DEBAJO DE 25 MINUTOS."), COLOR_GRIS)
	if hay_mundial() and online.pendientes() > 0:
		_texto(270, Idioma.t("TU PUNTUACIÓN ESTÁ PENDIENTE DE ENVIAR."), COLOR_ORO)


func _dibujar_mundial() -> void:
	var nombre_txt := (Idioma.t("NOMBRE: %s") % online.nombre) if online.nombre != "" else Idioma.t("ELEGIR NOMBRE")
	_boton(CAJA_NOMBRE, nombre_txt, online.nombre == "")
	_boton(CAJA_MODO, Idioma.t("VER HOY") if _historico else Idioma.t("VER HISTÓRICO"), false)
	_texto(92, Idioma.t("MEJORES DE SIEMPRE") if _historico else (Idioma.t("TOP 50 DEL %s") % _fecha), COLOR_ORO)
	var x := 60.0
	draw_string(Juego.fuente, Vector2(x, Y_CABECERA), Idioma.t("POS"), HORIZONTAL_ALIGNMENT_RIGHT, 30, 8, COLOR_GRIS)
	draw_string(Juego.fuente, Vector2(x + 44, Y_CABECERA), Idioma.t("NOMBRE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COLOR_GRIS)
	draw_string(Juego.fuente, Vector2(x + 200, Y_CABECERA), Idioma.t("PUNTOS"), HORIZONTAL_ALIGNMENT_RIGHT, 100, 8, COLOR_GRIS)
	draw_string(Juego.fuente, Vector2(x + 330, Y_CABECERA), Idioma.t("PISO"), HORIZONTAL_ALIGNMENT_RIGHT, 40, 8, COLOR_GRIS)
	draw_string(Juego.fuente, Vector2(x + 390, Y_CABECERA), Idioma.t("TIEMPO"), HORIZONTAL_ALIGNMENT_RIGHT, 60, 8, COLOR_GRIS)
	if _estado != "":
		var aviso := Idioma.t("CARGANDO...")
		match _estado:
			"sin_conexion": aviso = Idioma.t("SIN CONEXIÓN. VUELVE A PROBAR CON R O MÁS TARDE.")
			"servidor": aviso = Idioma.t("EL SERVIDOR NO RESPONDE BIEN. PRUEBA MÁS TARDE.")
		_texto(190, aviso, COLOR_GRIS)
	elif _filas.is_empty():
		_texto(190, Idioma.t("AÚN NO HAY PUNTUACIONES. ¡SÉ EL PRIMERO!"), COLOR_GRIS)
	else:
		var hasta := mini(_desplazado + FILAS_VISIBLES, _filas.size())
		for i in range(_desplazado, hasta):
			_fila(Y_FILAS + (i - _desplazado) * ALTO_FILA, _filas[i])
		if _desplazado > 0:
			_flecha(CAJA_SUBIR, true)
		if hasta < _filas.size():
			_flecha(CAJA_BAJAR, false)
	# Tu fila, aparte, si no se ve en la tabla.
	if not _yo.is_empty() and not fila_propia_visible():
		_fila(Y_FILAS + FILAS_VISIBLES * ALTO_FILA + 2.0, _yo, true)
	_texto(300, Idioma.t("FLECHAS: MOVER   H: HOY/HISTÓRICO   N: NOMBRE   R: RECARGAR"), Color(COLOR_GRIS, 0.7))
	_texto(316, Idioma.t("SOLO SE GUARDAN TU NOMBRE Y TUS PUNTUACIONES."), COLOR_GRIS)


func fila_propia_visible() -> bool:
	var hasta := mini(_desplazado + FILAS_VISIBLES, _filas.size())
	for i in range(_desplazado, hasta):
		if _filas[i].get("yo", false):
			return true
	return false


func _fila(y: float, f: Dictionary, sola := false) -> void:
	var mia: bool = f.get("yo", false) or sola
	if mia:
		draw_rect(Rect2(56, y - 9, 524, ALTO_FILA), Color(COLOR_VERDE, 0.25))
	var color := COLOR_VERDE if mia else COLOR_CREMA
	var x := 60.0
	draw_string(Juego.fuente, Vector2(x, y), str(int(f.get("pos", 0))), HORIZONTAL_ALIGNMENT_RIGHT, 30, 8, color)
	draw_string(Juego.fuente, Vector2(x + 44, y), String(f.get("nombre", "?")), HORIZONTAL_ALIGNMENT_LEFT, 150, 8, color)
	draw_string(Juego.fuente, Vector2(x + 200, y), str(int(f.get("puntos", 0))), HORIZONTAL_ALIGNMENT_RIGHT, 100, 8, color)
	draw_string(Juego.fuente, Vector2(x + 330, y), str(int(f.get("piso", 0))), HORIZONTAL_ALIGNMENT_RIGHT, 40, 8, color)
	draw_string(Juego.fuente, Vector2(x + 390, y), tiempo_texto(int(f.get("tiempo", 0))), HORIZONTAL_ALIGNMENT_RIGHT, 60, 8, color)


func _flecha(caja: Rect2, arriba: bool) -> void:
	draw_rect(caja, COLOR_BOTON)
	var c := caja.get_center()
	var puntos := PackedVector2Array([c + Vector2(-5, 3), c + Vector2(5, 3), c + Vector2(0, -4)]) if arriba \
			else PackedVector2Array([c + Vector2(-5, -3), c + Vector2(5, -3), c + Vector2(0, 4)])
	draw_colored_polygon(puntos, COLOR_CREMA)


func _dibujar_nombre() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.06, 0.05, 0.1, 0.9))
	draw_rect(Rect2(150, 104, 340, 140), Color8(30, 23, 44))
	draw_rect(Rect2(150, 104, 340, 140), COLOR_ORO, false, 1.0)
	_texto(124, Idioma.t("ELIGE TU NOMBRE PÚBLICO"), COLOR_ORO)
	_texto(140, Idioma.t("DE 3 A 16 LETRAS, NÚMEROS O GUIONES. SALE EN LA TABLA MUNDIAL."), COLOR_GRIS)
	var aviso := Idioma.t("ENVIANDO...") if _esperando_nombre else texto_error_nombre(_error_nombre)
	_texto(192, aviso, COLOR_ROJO if _error_nombre != "" else COLOR_GRIS)
	_boton(CAJA_ACEPTAR, Idioma.t("ACEPTAR"), true)
	_boton(CAJA_AHORA_NO, Idioma.t("AHORA NO"), false)
	_texto(236, Idioma.t("SOLO SE GUARDAN TU NOMBRE Y TUS PUNTUACIONES."), COLOR_GRIS)
