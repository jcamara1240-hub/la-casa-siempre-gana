class_name Guardado
extends RefCounted
## La partida en curso, guardada al entrar en cada sala. Si cierras a mitad de combate,
## vuelves al principio de esa sala.

const RUTA := "user://partida.sav"


static func hay_partida() -> bool:
	return FileAccess.file_exists(RUTA)


static func guardar(datos: Dictionary) -> void:
	var f := FileAccess.open(RUTA, FileAccess.WRITE)
	if f != null:
		f.store_var(datos)
		f.close()


static func cargar() -> Dictionary:
	var f := FileAccess.open(RUTA, FileAccess.READ)
	if f == null:
		return {}
	var datos = f.get_var()
	f.close()
	return datos if datos is Dictionary else {}


static func borrar() -> void:
	if hay_partida():
		DirAccess.remove_absolute(RUTA)
