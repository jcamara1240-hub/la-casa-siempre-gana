class_name LogrosDB
extends RefCounted
## Los logros y cuándo se consiguen. Se comprueban en los momentos clave de la partida.

const LOGROS := {
	"primera_sangre": {"nombre": "Primera Sangre", "desc": "Elimina a tu primer enemigo."},
	"cien": {"nombre": "Limpieza de Sala", "desc": "Elimina a 100 enemigos en total."},
	"mil": {"nombre": "Exterminador", "desc": "Elimina a 1.000 enemigos en total."},
	"cinco_mil": {"nombre": "Plaga", "desc": "Elimina a 5.000 enemigos en total."},
	"pez": {"nombre": "Pescado Frito", "desc": "Vence al Pez Rojo."},
	"tres_jefes": {"nombre": "Cazador de Jefes", "desc": "Vence a 3 jefes distintos."},
	"todos_jefes": {"nombre": "Dueño del Casino", "desc": "Vence a todos los jefes."},
	"sin_tocar": {"nombre": "Intocable", "desc": "Vence a un jefe sin recibir daño."},
	"ganar": {"nombre": "Desbancado", "desc": "Gana una partida."},
	"tres_victorias": {"nombre": "Cliente Vetado", "desc": "Gana 3 partidas."},
	"todos_ganan": {"nombre": "Equipo Completo", "desc": "Gana con 4 personajes distintos."},
	"mesa_oro": {"nombre": "Mesa de Oro", "desc": "Gana en la Mesa de Oro."},
	"extremo": {"nombre": "Un Solo Corazón", "desc": "Gana en modo extremo."},
	"combo_100": {"nombre": "Buena Mano", "desc": "Consigue un combo de 100."},
	"combo_1000": {"nombre": "Escalera Real", "desc": "Consigue un combo de 1.000."},
	"combo_5000": {"nombre": "Rompebancos", "desc": "Consigue un combo de 5.000."},
	"rico": {"nombre": "Bolsillos Llenos", "desc": "Gana 500 monedas en una partida."},
	"objetos": {"nombre": "Coleccionista", "desc": "Lleva 10 objetos en una partida."},
	"transformacion": {"nombre": "Otra Persona", "desc": "Consigue una transformación."},
	"todas_transf": {"nombre": "Mil Caras", "desc": "Descubre todas las transformaciones."},
	"fila_llena": {"nombre": "Mesa Completa", "desc": "Llena las 8 ranuras de cartas."},
	"trilero": {"nombre": "Ojo de Halcón", "desc": "Gana a los trileros."},
	"doble_cinco": {"nombre": "Nervios de Acero", "desc": "Dobla 5 veces seguidas en el doble o nada."},
	"deudor": {"nombre": "Moroso", "desc": "Deja que el prestamista te cobre un corazón."},
	"mendigo": {"nombre": "Buen Corazón", "desc": "Dale monedas al mendigo."},
	"reto": {"nombre": "Cita Diaria", "desc": "Juega un reto diario."},
	"cartas": {"nombre": "La Baraja Entera", "desc": "Desbloquea todas las cartas."},
	# Voltereta, Fiebre, mesas y órdago: los dos contadores van en Progreso.contadores ("por_los_pelos",
	# "mesas") y los otros dos se marcan con Juego.marcar_logro() en el momento en que pasan.
	"afeitado": {"nombre": "Afeitado Apurado", "desc": "Haz 50 volteretas por los pelos en total."},
	"rojo_vivo": {"nombre": "Al Rojo Vivo", "desc": "Limpia una sala con la Fiebre al máximo."},
	"mal_perdedor": {"nombre": "Mal Perdedor", "desc": "Vuelca 20 mesas en total."},
	"sin_despeinarse": {"nombre": "Sin Despeinarse", "desc": "Vence a un jefe sin gastar ningún órdago."},
	# Roce, Desatado y propina: contadores "roces", "desatados" y "propinas" de Progreso.contadores.
	"roces": {"nombre": "A Flor de Piel", "desc": "Deja que 100 balas te pasen rozando sin rodar."},
	"desatado": {"nombre": "Sin Freno", "desc": "Desátate 25 veces en total."},
	"servicio": {"nombre": "Servicio Rápido", "desc": "Cobra 25 propinas por rapidez."},
}


static func nombre(id: String) -> String:
	return Idioma.t(LOGROS[id].nombre)


static func descripcion(id: String) -> String:
	return Idioma.t(LOGROS[id].desc)
