"""Sintetiza todos los efectos y la música del juego. Nada de muestras externas.

Uso:  python tools/generar_sonidos.py
Necesita numpy. Escribe archivos .wav en assets/sonido/.
"""
import wave
from pathlib import Path
import numpy as np

SALIDA = Path(__file__).resolve().parent.parent / "assets" / "sonido"
FS = 22050
azar = np.random.default_rng(1240)


def t(dur):
    return np.arange(int(FS * dur)) / FS


def cuadrada(f, dur, ancho=0.5):
    fase = np.cumsum(np.full(int(FS * dur), f)) / FS if np.isscalar(f) else np.cumsum(f) / FS
    return np.where((fase % 1.0) < ancho, 1.0, -1.0)


def triangular(f, dur):
    fase = np.cumsum(np.full(int(FS * dur), f)) / FS if np.isscalar(f) else np.cumsum(f) / FS
    return 4.0 * np.abs((fase % 1.0) - 0.5) - 1.0


def ruido(dur):
    return azar.uniform(-1.0, 1.0, int(FS * dur))


def caida(dur, velocidad=8.0):
    return np.exp(-t(dur) * velocidad)


def barrido(f0, f1, dur):
    return np.linspace(f0, f1, int(FS * dur))


def suave(x, ms=3):
    """Quita el clic del principio y del final."""
    n = min(int(FS * ms / 1000), len(x) // 2)
    if n > 0:
        rampa = np.linspace(0.0, 1.0, n)
        x = x.copy()
        x[:n] *= rampa
        x[-n:] *= rampa[::-1]
    return x


def guardar(nombre, x, pico=0.8):
    x = suave(np.asarray(x, dtype=float))
    x = x - np.mean(x)
    escribir(nombre, x / max(np.max(np.abs(x)), 1e-6) * pico)


def escribir(nombre, x):
    SALIDA.mkdir(parents=True, exist_ok=True)
    datos = (x * 32767).astype(np.int16)
    with wave.open(str(SALIDA / f"{nombre}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(FS)
        w.writeframes(datos.tobytes())


def serie(notas, onda=cuadrada, velocidad=10.0):
    """Une notas (frecuencia, duración) una detrás de otra."""
    partes = [onda(f, d) * caida(d, velocidad) for f, d in notas]
    return np.concatenate(partes)


def efectos():
    guardar("disparo", cuadrada(barrido(900, 300, 0.07), 0.07, 0.3) * caida(0.07, 25), 0.45)
    guardar("carta", (ruido(0.06) * 0.6 + cuadrada(barrido(1400, 700, 0.06), 0.06)) * caida(0.06, 40), 0.4)
    guardar("rayo", (cuadrada(azar.uniform(200, 2200, int(FS * 0.14)), 0.14, 0.5)) * caida(0.14, 16), 0.45)
    guardar("explosion", (ruido(0.4) + triangular(barrido(130, 40, 0.4), 0.4)) * caida(0.4, 9), 0.8)
    # "golpe" está en efectos_ronda2(): lleva ruido y tiene que ir al final para no mover el azar.
    guardar("muerte", (cuadrada(barrido(500, 90, 0.13), 0.13) * 0.7 + ruido(0.13) * 0.3) * caida(0.13, 14), 0.5)
    guardar("dano", cuadrada(barrido(320, 90, 0.26), 0.26, 0.4) * caida(0.26, 7), 0.8)
    guardar("moneda", serie([(988, 0.05), (1319, 0.14)], cuadrada, 14), 0.4)
    guardar("puerta_cierra", (triangular(70, 0.2) + ruido(0.2) * 0.5) * caida(0.2, 16), 0.8)
    guardar("puerta_abre", serie([(392, 0.06), (523, 0.06), (784, 0.16)], triangular, 12), 0.6)
    guardar("comprar", serie([(784, 0.05), (1047, 0.05), (1319, 0.16)], cuadrada, 11), 0.5)
    guardar("carta_coger", serie([(523, 0.05), (659, 0.05), (784, 0.05), (1047, 0.14)], triangular, 10), 0.7)
    guardar("objeto", serie([(392, 0.09), (523, 0.09), (659, 0.09), (784, 0.09), (1047, 0.4)], cuadrada, 6), 0.55)
    guardar("transformacion", serie([(262, 0.1), (330, 0.1), (392, 0.1), (523, 0.1), (659, 0.1), (784, 0.1), (1047, 0.6)], cuadrada, 4), 0.6)
    guardar("tick", cuadrada(660, 0.05, 0.25) * caida(0.05, 34), 0.35)
    guardar("mult", serie([(880, 0.04), (1175, 0.04), (1760, 0.13)], cuadrada, 13), 0.5)
    guardar("clic", cuadrada(1046, 0.04, 0.25) * caida(0.04, 40), 0.35)
    guardar("mover", triangular(740, 0.03) * caida(0.03, 45), 0.3)
    guardar("jefe_aparece", (cuadrada(barrido(70, 140, 0.8), 0.8, 0.4) + ruido(0.8) * 0.2) * caida(0.8, 2.5), 0.8)
    guardar("jefe_muere", (ruido(1.1) * 0.6 + cuadrada(barrido(420, 30, 1.1), 1.1)) * caida(1.1, 3), 0.85)
    guardar("bajar", serie([(659, 0.1), (523, 0.1), (392, 0.1), (262, 0.3)], triangular, 7), 0.7)
    guardar("victoria", serie([(523, 0.12), (523, 0.12), (523, 0.12), (659, 0.3), (784, 0.15), (1047, 0.7)], cuadrada, 4), 0.6)
    guardar("derrota", serie([(392, 0.22), (370, 0.22), (349, 0.22), (262, 0.8)], triangular, 3), 0.75)
    guardar("ganar", serie([(659, 0.06), (880, 0.06), (1319, 0.2)], cuadrada, 9), 0.5)
    guardar("perder", serie([(330, 0.12), (233, 0.28)], cuadrada, 7), 0.55)
    guardar("mezclar", (ruido(0.11) * cuadrada(45, 0.11)) * caida(0.11, 18), 0.3)


# ------------------------------------------------------------------ música
LA3 = 220.0


def hz(semitonos):
    return LA3 * 2.0 ** (semitonos / 12.0)


class Pista:
    def __init__(self, bpm, compases):
        self.pulso = 60.0 / bpm
        self.total = int(FS * self.pulso * 4 * compases)
        self.mezcla = np.zeros(self.total)

    def poner(self, inicio, sonido, volumen):
        i = int(inicio * FS) % self.total
        fin = i + len(sonido)
        if fin <= self.total:
            self.mezcla[i:fin] += sonido * volumen
        else:
            corte = self.total - i
            self.mezcla[i:] += sonido[:corte] * volumen
            self.mezcla[:fin - self.total] += sonido[corte:] * volumen  # cierra el bucle sin clics

    def nota(self, pulso_inicio, semitono, pulsos, onda, volumen, decaimiento=4.0, ancho=None):
        dur = pulsos * self.pulso
        s = onda(hz(semitono), dur) if ancho is None else onda(hz(semitono), dur, ancho)
        self.poner(pulso_inicio * self.pulso, suave(s * caida(dur, decaimiento)), volumen)

    def bombo(self, pulso, volumen=0.8):
        d = 0.14
        self.poner(pulso * self.pulso, suave(triangular(barrido(150, 45, d), d) * caida(d, 14)), volumen)

    def caja(self, pulso, volumen=0.3):
        d = 0.12
        self.poner(pulso * self.pulso, suave(ruido(d) * caida(d, 20)), volumen)

    def charles(self, pulso, volumen=0.1):
        d = 0.04
        self.poner(pulso * self.pulso, suave(ruido(d) * caida(d, 80)), volumen)


# Acordes como semitonos respecto a La3: Am7, Dm7, G7, Cmaj7, Fmaj7, Bm7b5, E7
ACORDES = {
    "Am": [0, 3, 7, 10], "Dm": [-7, -4, 0, 3], "G7": [-2, 2, 5, 8], "C": [3, 7, 10, 14],
    "F": [-4, 0, 3, 7], "Bdim": [2, 5, 8, 12], "E7": [-5, -1, 2, 5],
}


def musica_menu():
    """Un lounge de sala de juego: bajo andante y acordes a contratiempo."""
    p = Pista(92, 16)
    prog = ["Am", "Dm", "G7", "C", "F", "Bdim", "E7", "Am"] * 2
    melodia = [(0, 12), (1.5, 15), (3, 14), (8, 10), (9.5, 12), (11, 8), (16, 7), (17.5, 10), (19, 12),
               (24, 7), (26, 3), (32, 12), (33.5, 15), (35, 19), (40, 17), (42, 15), (48, 14), (49.5, 12),
               (51, 11), (56, 12)]
    for c, nombre in enumerate(prog):
        ac = ACORDES[nombre]
        base = c * 4
        for pulso, grado in enumerate([0, 2, 1, 3]):
            p.nota(base + pulso, ac[grado] - 24, 0.95, triangular, 0.5, 2.5)
        for golpe in (1.66, 3.66):
            for nota in ac[1:]:
                p.nota(base + golpe, nota, 0.5, cuadrada, 0.05, 7, 0.25)
        for golpe in (0, 1.66, 2, 3.66):
            p.charles(base + golpe, 0.07)
    for pulso, nota in melodia:
        p.nota(pulso, nota, 1.5, triangular, 0.28, 2.0)
    guardar("musica_menu", p.mezcla, 0.55)


def musica_piso():
    """Arpegios nerviosos: en la mazmorra no se descansa."""
    p = Pista(128, 16)
    prog = ["Am", "Am", "F", "G7", "Am", "Dm", "E7", "E7"] * 2
    for c, nombre in enumerate(prog):
        ac = ACORDES[nombre]
        base = c * 4
        for i in range(8):
            p.nota(base + i * 0.5, ac[0] - 24 + (12 if i % 2 else 0), 0.45, triangular, 0.5, 5)
        figura = [0, 1, 2, 3, 2, 1, 2, 3] * 2
        for i, g in enumerate(figura):
            p.nota(base + i * 0.25, ac[g] + 12, 0.24, cuadrada, 0.09, 11, 0.25)
        for b in (0, 2):
            p.bombo(base + b, 0.6)
        for b in (1, 3):
            p.caja(base + b, 0.22)
        for i in range(8):
            p.charles(base + i * 0.5, 0.06)
    tema = [(0, 12), (2, 15), (3, 14), (4, 12), (6, 10), (8, 8), (10, 12), (12, 10), (14, 7), (16, 12), (18, 15),
            (20, 19), (22, 17), (24, 15), (26, 14), (28, 11), (30, 8)]
    for vuelta in (0, 32):
        for pulso, nota in tema:
            p.nota(vuelta + pulso, nota, 1.8, cuadrada, 0.1, 2.6, 0.5)
    guardar("musica_piso", p.mezcla, 0.55)


def musica_jefe():
    """Rápida y en frigio: la banca no perdona."""
    p = Pista(152, 16)
    raices = [-5, -5, -4, -5, -5, -5, -2, -4] * 2
    for c, r in enumerate(raices):
        base = c * 4
        for i in range(8):
            p.nota(base + i * 0.5, r - 12 + (0 if i % 4 else -12), 0.4, cuadrada, 0.22, 6, 0.4)
            p.charles(base + i * 0.5, 0.07)
        for b in (0, 1, 2, 2.5, 3):
            p.bombo(base + b, 0.55)
        for b in (1, 3):
            p.caja(base + b, 0.3)
        for b, n in ((0, 12), (0.75, 15), (1.5, 16), (2.25, 19), (3, 22)):
            p.nota(base + b, r + n, 0.5, cuadrada, 0.1, 6, 0.25)
    gancho = [(0, 19), (1, 20), (2, 19), (3, 17), (4, 16), (6, 19), (8, 19), (9, 20), (10, 24), (12, 23), (14, 20)]
    for vuelta in (16, 48):
        for pulso, nota in gancho:
            p.nota(vuelta + pulso, nota, 1.0, triangular, 0.3, 3)
    guardar("musica_jefe", p.mezcla, 0.55)


def musica_victoria():
    """Fanfarria en mayor con aire de orquesta de casino."""
    p = Pista(136, 8)
    prog = ["C", "F", "G7", "C", "F", "G7", "C", "C"]
    for c, nombre in enumerate(prog):
        ac = ACORDES[nombre]
        base = c * 4
        for i in range(8):
            p.nota(base + i * 0.5, ac[0] - 24 + (7 if i % 2 else 0), 0.45, triangular, 0.5, 5)
        for golpe in (0.5, 1.5, 2.5, 3.5):
            for nota in ac[:3]:
                p.nota(base + golpe, nota + 12, 0.4, cuadrada, 0.06, 8, 0.25)
        for b in (0, 2):
            p.bombo(base + b, 0.55)
        for b in (1, 3):
            p.caja(base + b, 0.25)
        for i in range(8):
            p.charles(base + i * 0.5, 0.06)
    tema = [(0, 15), (1, 19), (2, 22), (3, 27), (4, 24), (6, 27), (8, 26), (10, 22), (12, 19), (14, 22),
            (16, 24), (17, 27), (18, 29), (20, 26), (22, 22), (24, 27), (26, 31), (28, 27)]
    for pulso, nota in tema:
        p.nota(pulso, nota, 1.8, cuadrada, 0.14, 2.4, 0.5)
    guardar("musica_victoria", p.mezcla, 0.6)


# ------------------------------------------------------------------ armas nuevas, voltereta, órdago y mesas
def paso_bajo(x, n):
    """Media móvil: le quita el siseo al ruido y lo deja en golpe sordo."""
    return np.convolve(x, np.ones(n) / n, mode="same")


def silencio(dur):
    return np.zeros(int(FS * dur))


def efectos_punchy():
    """Va al final a propósito: usa el mismo generador de azar y así no cambia ningún sonido anterior."""
    d = 0.22
    sube_baja = np.sin(np.linspace(0, np.pi, int(FS * d))) ** 2
    guardar("voltereta", paso_bajo(ruido(d), 6) * sube_baja + triangular(barrido(260, 140, d), d) * sube_baja * 0.25, 0.35)

    d = 0.9
    golpe = triangular(barrido(110, 38, d), d) * caida(d, 3.5) + cuadrada(55, d, 0.5) * caida(d, 8) * 0.2
    golpe[:int(FS * 0.25)] += paso_bajo(ruido(0.25), 10) * caida(0.25, 14) * 1.3
    golpe[:int(FS * 0.05)] += cuadrada(barrido(900, 220, 0.05), 0.05) * caida(0.05, 40) * 0.6
    guardar("ordago", golpe, 0.85)

    d = 0.16
    mesa = triangular(barrido(190, 80, d), d) * caida(d, 16)
    mesa[:int(FS * 0.05)] += paso_bajo(ruido(0.05), 5) * caida(0.05, 50) * 0.8
    guardar("mesa", mesa, 0.65)

    d = 0.3
    astillas = paso_bajo(ruido(d), 2) * caida(d, 9)
    for inicio in (0.0, 0.05, 0.11, 0.17):
        i = int(FS * inicio)
        astillas[i:i + int(FS * 0.02)] += ruido(0.02) * 1.6 * (1.0 - inicio * 2.5)
    guardar("mesa_rota", astillas + triangular(barrido(150, 55, d), d) * caida(d, 12) * 0.7, 0.65)

    d = 0.2
    escopeta = paso_bajo(ruido(d), 9) * caida(d, 22) * 1.4 + triangular(barrido(150, 40, d), d) * caida(d, 11) * 1.2
    escopeta[:int(FS * 0.008)] += ruido(0.008) * 0.8  # el chasquido del principio, corto
    guardar("escopeta", escopeta, 0.8)

    d = 0.045
    guardar("metralleta", (ruido(d) * 0.7 + cuadrada(barrido(560, 240, d), d, 0.4)) * caida(d, 70), 0.4)

    d = 0.2
    vibrato = barrido(1900, 280, d) * (1.0 + 0.04 * np.sin(np.arange(int(FS * d)) * 0.03))
    guardar("laser", cuadrada(vibrato, d, 0.25) * caida(d, 9), 0.4)

    pitido = lambda f, dur: cuadrada(f, dur, 0.5) * caida(dur, 18)
    guardar("mina", np.concatenate([pitido(1320, 0.045), silencio(0.035), pitido(1760, 0.07)]), 0.35)

    d = 0.15
    tajo = np.sin(np.linspace(0, np.pi, int(FS * d))) ** 3
    guardar("barrido", paso_bajo(ruido(d), 2) * tajo + triangular(barrido(1100, 380, d), d) * tajo * 0.3, 0.42)

    guardar("fiebre", serie([(659, 0.045), (831, 0.045), (988, 0.045), (1319, 0.12)], cuadrada, 12), 0.45)

    roce = paso_bajo(ruido(0.07), 3) * np.sin(np.linspace(0, np.pi, int(FS * 0.07))) ** 2
    campana = (triangular(1760, 0.22) + triangular(2637, 0.22) * 0.4) * caida(0.22, 12)
    guardar("por_los_pelos", np.concatenate([roce * 0.6, campana]), 0.45)

    d = 0.14
    fuerte = triangular(barrido(240, 55, d), d) * caida(d, 14)
    fuerte[:int(FS * 0.06)] += paso_bajo(ruido(0.06), 3) * caida(0.06, 40)
    guardar("impacto_fuerte", fuerte, 0.7)

    d = 0.07
    tintineo = (triangular(2600, d) + triangular(3950, d) * 0.6) * caida(d, 45)
    rebote = triangular(3100, 0.03) * caida(0.03, 70) * 0.5  # el segundo toque contra el suelo
    i = int(FS * 0.035)
    tintineo[i:i + len(rebote)] += rebote[:len(tintineo) - i]
    guardar("casquillo", tintineo, 0.25)


# ------------------------------------------------------------------ ronda 2: al límite, roce, desatado
def sin_continua(x, r=0.995):
    """Filtro de un polo (corta por debajo de ~18 Hz): quita la continua que dejan las ondas
    cuadradas estrechas y que, al apagarse la nota, acabaría en un chasquido."""
    y = np.empty(len(x))
    previo_x = previo_y = 0.0
    for i, v in enumerate(np.asarray(x, dtype=float).tolist()):
        previo_y = v - previo_x + r * previo_y
        previo_x = v
        y[i] = previo_y
    return y


def guardar_limpio(nombre, x, pico=0.8, ms=4):
    """Como guardar(), pero sin continua antes del fundido: empieza y acaba de verdad en cero."""
    x = sin_continua(x)
    x = suave(x - np.mean(x), ms)
    escribir(nombre, x / max(np.max(np.abs(x)), 1e-6) * pico)


def guardar_bucle(nombre, x, pico):
    """Para bucles: sin fundidos, porque el final empalma con el principio.
    El filtro se pasa sobre dos vueltas y se queda la segunda, que ya empalma sola."""
    x = np.asarray(x, dtype=float)
    x = sin_continua(np.concatenate([x, x]))[len(x):]
    x = x - np.mean(x)
    escribir(nombre, x / max(np.max(np.abs(x)), 1e-6) * pico)


def seno(f, dur):
    fase = np.cumsum(np.full(int(FS * dur), f)) / FS if np.isscalar(f) else np.cumsum(f) / FS
    return np.sin(2.0 * np.pi * fase)


def agudo(x, n):
    """Lo contrario de paso_bajo: se queda con el siseo."""
    return x - paso_bajo(x, n)


def bombo_gordo(f0, f1, dur, velocidad, saturar=2.5):
    """Seno que cae de tono y satura: los armónicos hacen que se oiga también en altavoces pequeños."""
    return suave(np.tanh(seno(barrido(f0, f1, dur), dur) * caida(dur, velocidad) * saturar), 5)


def efectos_ronda2():
    """Va detrás de efectos_punchy() por lo mismo: así no cambia ningún sonido anterior."""
    # Roce: un silbido que sube y se queda brillando. Es un premio, así que suave y agudo.
    d = 0.16
    f = (1700 + 1100 * (1 - np.exp(-t(d) * 40))) * (1 + 0.012 * np.sin(2 * np.pi * 28 * t(d)))
    silbido = (seno(f, d) + seno(f * 2, d) * 0.22) * (1 - np.exp(-t(d) * 350)) * caida(d, 15)
    aire = agudo(ruido(d), 4) * caida(d, 45) * 0.3
    guardar_limpio("roce", silbido + aire, 0.32)

    # Latido: "pum-pum", grave pero con armónicos. Lo repite sonido.gd a tempo de la música.
    d = 0.42
    latido = silencio(d)
    lub = bombo_gordo(66, 44, 0.16, 17)
    dub = bombo_gordo(76, 50, 0.13, 21, 2.0) * 0.7
    latido[:len(lub)] += lub
    i = int(FS * 0.18)
    latido[i:i + len(dub)] += dub
    latido[:int(FS * 0.03)] += paso_bajo(ruido(0.03), 12) * caida(0.03, 90) * 0.5
    guardar_limpio("latido", latido, 0.7, 6)

    # Desatado: subida de tono y ruido que revienta en un acorde de quinta (vale en mayor y en menor).
    d = 0.3
    n = int(FS * d)
    subida = cuadrada(np.geomspace(220, 880, n), d, 0.3) * np.linspace(0.45, 1.0, n) ** 2 * 0.5
    subida += agudo(ruido(d), 3) * np.linspace(0.1, 1.0, n) ** 3 * 0.5
    d = 0.62
    acorde = silencio(d)
    for k, (semitono, abre) in enumerate(((-12, 0.5), (0, 0.4), (7, 0.4), (12, 0.3), (19, 0.3))):
        for j, desafino in enumerate((-0.004, 0.004)):  # dos voces casi iguales: suena más ancho
            fase = (k * 0.37 + j * 0.5) + np.cumsum(np.full(int(FS * d), hz(semitono) * (1 + desafino))) / FS
            acorde += np.where((fase % 1.0) < abre, 1.0, -1.0) * 0.16
    acorde *= (1 - np.exp(-t(d) * 300)) * caida(d, 3.2)
    acorde[:int(FS * 0.12)] += paso_bajo(ruido(0.12), 2) * caida(0.12, 25) * 0.45
    acorde += bombo_gordo(120, 45, d, 9) * 0.35
    acorde *= np.minimum(1.0, (d - t(d)) / 0.18)  # se apaga del todo, sin cortarse
    guardar_limpio("desatado", np.tanh(np.concatenate([subida, acorde]) * 1.6), 0.75)

    # Oleada: tambor grave y un "ta-tán" de segunda menor, que da mala espina.
    d = 0.34
    oleada = bombo_gordo(150, 60, d, 10) * 0.9
    oleada[:int(FS * 0.04)] += paso_bajo(ruido(0.04), 3) * caida(0.04, 70) * 0.6
    for inicio, semitono in ((0.0, 12), (0.09, 13)):
        nota = (cuadrada(hz(semitono), 0.12, 0.25) + cuadrada(hz(semitono + 12), 0.12, 0.5) * 0.4) * caida(0.12, 22)
        i = int(FS * inicio)
        oleada[i:i + len(nota)] += suave(nota) * 0.35
    guardar_limpio("oleada", oleada, 0.7)

    # Remate: impacto gordo y una campanilla de premio por encima.
    d = 0.55
    remate = bombo_gordo(135, 38, d, 7) * 1.1
    remate[:int(FS * 0.09)] += paso_bajo(ruido(0.09), 2) * caida(0.09, 38) * 0.9
    remate[:int(FS * 0.03)] += cuadrada(barrido(1400, 300, 0.03), 0.03) * caida(0.03, 60) * 0.4
    brillo = (triangular(2637, 0.4) + triangular(3951, 0.4) * 0.5 + triangular(5274, 0.4) * 0.2) * caida(0.4, 9)
    i = int(FS * 0.03)
    remate[i:i + len(brillo)] += suave(brillo) * 0.32
    guardar_limpio("remate", remate, 0.85)

    # Aviso: un tic de ficha, cortísimo. Suena cada vez que va a salir un enemigo.
    d = 0.035
    tic = (triangular(2100, d) * 0.6 + agudo(ruido(d), 2) * 0.5) * caida(d, 110)
    guardar_limpio("aviso", tic, 0.22, 2)

    # Golpe con más pegada (sustituye al de efectos()): el "bip" de siempre más un chasquido
    # y un golpe sordo debajo. Ahora hay más golpes por segundo y tienen que notarse sin cansar.
    d = 0.06
    golpe = triangular(barrido(420, 180, d), d) * caida(d, 30) * 0.8
    golpe += bombo_gordo(240, 110, d, 40, 1.8) * 0.7
    golpe[:int(FS * 0.006)] += paso_bajo(ruido(0.006), 2) * 0.9
    guardar_limpio("golpe", golpe, 0.48, 2)


def platillo(p, pulso, volumen):
    d = 0.9
    p.poner(pulso * p.pulso, suave(agudo(ruido(d), 2) * caida(d, 4.5)), volumen)


def charles_abierto(p, pulso, volumen):
    d = 0.11
    p.poner(pulso * p.pulso, suave(agudo(ruido(d), 2) * caida(d, 28)), volumen)


def palmada(p, pulso, volumen):
    d = 0.14
    x = paso_bajo(ruido(d), 2) * caida(d, 24)
    for retraso in (0.008, 0.016):  # tres manos casi a la vez
        i = int(FS * retraso)
        x[i:] += paso_bajo(ruido(d), 2)[:len(x) - i] * caida(d, 60)[:len(x) - i] * 0.6
    p.poner(pulso * p.pulso, suave(x), volumen)


def tom(p, pulso, f0, volumen):
    d = 0.2
    p.poner(pulso * p.pulso, bombo_gordo(f0, f0 * 0.55, d, 14, 1.6), volumen)


def capa_piso():
    """La capa que entra con la intensidad: mismo tempo y mismo largo que musica_piso."""
    p = Pista(128, 16)
    bajo = Pista(128, 16)
    prog = ["Am", "Am", "F", "G7", "Am", "Dm", "E7", "E7"] * 2
    for c, nombre in enumerate(prog):
        base = c * 4
        raiz = ACORDES[nombre][0]
        for b in (1, 3):  # con el bombo de la base queda a negras
            p.bombo(base + b, 0.5)
        for i in range(16):
            p.charles(base + i * 0.25, 0.07 if i % 2 else 0.04)
        for b in (0.5, 1.5, 2.5, 3.5):
            charles_abierto(p, base + b, 0.05)
        for i in range(16):  # bajo a semicorcheas que empuja
            bajo.nota(base + i * 0.25, raiz - 12 + (12 if i % 4 == 3 else 0), 0.2, cuadrada, 0.16, 14, 0.5)
        if c % 4 == 3:  # redoble al final de cada frase
            for k in range(8):
                p.caja(base + 2 + k * 0.25, 0.08 + 0.03 * k)
        if c % 4 == 0:
            platillo(p, base, 0.06)
    p.mezcla += paso_bajo(bajo.mezcla, 6)
    guardar_bucle("musica_piso_capa", p.mezcla, 0.45)


def capa_jefe():
    """Lo mismo para musica_jefe: semicorcheas, palmas y redobles de timbal."""
    p = Pista(152, 16)
    bajo = Pista(152, 16)
    raices = [-5, -5, -4, -5, -5, -5, -2, -4] * 2
    figura = [1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1]
    for c, r in enumerate(raices):
        base = c * 4
        for i in range(16):
            if i % 2:
                p.charles(base + i * 0.25, 0.06)
            if figura[i]:
                bajo.nota(base + i * 0.25, r - 12, 0.2, cuadrada, 0.2, 18, 0.4)
        for b in (1, 3):
            palmada(p, base + b, 0.16)
        if c % 4 == 3:
            for k, (pulso, f) in enumerate(((2, 210), (2.5, 180), (3, 150), (3.25, 130), (3.5, 115), (3.75, 100))):
                tom(p, base + pulso, f, 0.35 + 0.04 * k)
        if c % 4 == 0:
            platillo(p, base, 0.07)
    p.mezcla += paso_bajo(bajo.mezcla, 5)
    guardar_bucle("musica_jefe_capa", p.mezcla, 0.45)


if __name__ == "__main__":
    efectos()
    musica_menu()
    musica_piso()
    musica_jefe()
    musica_victoria()
    efectos_punchy()
    efectos_ronda2()
    capa_piso()
    capa_jefe()
