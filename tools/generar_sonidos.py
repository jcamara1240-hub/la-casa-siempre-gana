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
    SALIDA.mkdir(parents=True, exist_ok=True)
    x = suave(np.asarray(x, dtype=float))
    x = x - np.mean(x)
    x = x / max(np.max(np.abs(x)), 1e-6) * pico
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
    guardar("golpe", triangular(barrido(420, 180, 0.05), 0.05) * caida(0.05, 30), 0.35)
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


if __name__ == "__main__":
    efectos()
    musica_menu()
    musica_piso()
    musica_jefe()
    musica_victoria()
