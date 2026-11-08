"""Genera todos los gráficos del juego a partir de texto y unas pocas reglas.

Uso:  python tools/generar_sprites.py
Necesita Pillow. Escribe en assets/ y se puede relanzar siempre que cambie algo.
"""
import math
import random
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "assets"

# La paleta "Tapete": morados de sótano, verde de mesa de juego y oro de casino.
PALETA = {
    "k": "#14101e", "d": "#2a1f3d", "p": "#4a3466", "v": "#7a5aa0",
    "g": "#1f5c50", "G": "#2f8a6b", "m": "#6ccf94",
    "r": "#8f2340", "R": "#d63d4f", "o": "#f0813c", "y": "#f7c64a",
    "c": "#f7ecd2", "s": "#a89a8e", "b": "#2e6fb0", "B": "#6fc3e8",
}


def rgba(letra):
    h = PALETA[letra].lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def sprite(filas, ancho=None):
    ancho = ancho or max(len(f) for f in filas)
    img = Image.new("RGBA", (ancho, len(filas)), (0, 0, 0, 0))
    for y, fila in enumerate(filas):
        for x, ch in enumerate(fila):
            if ch not in ". ":
                img.putpixel((x, y), rgba(ch))
    return img


def lienzo(an, al):
    return Image.new("RGBA", (an, al), (0, 0, 0, 0))


def rect(img, x, y, an, al, letra):
    for j in range(y, y + al):
        for i in range(x, x + an):
            if 0 <= i < img.width and 0 <= j < img.height:
                img.putpixel((i, j), rgba(letra))


def pon(img, x, y, letra):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), rgba(letra))


def guardar(img, ruta):
    destino = SALIDA / ruta
    destino.parent.mkdir(parents=True, exist_ok=True)
    img.save(destino)


def hoja(frames, columnas=None):
    columnas = columnas or len(frames)
    an, al = frames[0].size
    filas = math.ceil(len(frames) / columnas)
    img = lienzo(an * columnas, al * filas)
    for i, f in enumerate(frames):
        img.alpha_composite(f, ((i % columnas) * an, (i // columnas) * al))
    return img


# ---------------------------------------------------------------- fuente
GLIFOS = {
    "A": ".#./#.#/###/#.#/#.#", "B": "##./#.#/##./#.#/##.", "C": ".##/#../#../#../.##",
    "D": "##./#.#/#.#/#.#/##.", "E": "###/#../##./#../###", "F": "###/#../##./#../#..",
    "G": ".##/#../#.#/#.#/.##", "H": "#.#/#.#/###/#.#/#.#", "I": "###/.#./.#./.#./###",
    "J": "..#/..#/..#/#.#/.#.", "K": "#.#/#.#/##./#.#/#.#", "L": "#../#../#../#../###",
    "M": "#...#/##.##/#.#.#/#...#/#...#", "N": "#..#/##.#/#.##/#..#/#..#",
    "O": ".#./#.#/#.#/#.#/.#.", "P": "##./#.#/##./#../#..", "Q": ".#./#.#/#.#/##./.##",
    "R": "##./#.#/##./#.#/#.#", "S": ".##/#../.#./..#/##.", "T": "###/.#./.#./.#./.#.",
    "U": "#.#/#.#/#.#/#.#/###", "V": "#.#/#.#/#.#/#.#/.#.",
    "W": "#...#/#...#/#.#.#/##.##/#...#", "X": "#.#/#.#/.#./#.#/#.#",
    "Y": "#.#/#.#/.#./.#./.#.", "Z": "###/..#/.#./#../###",
    "0": "###/#.#/#.#/#.#/###", "1": ".#./##./.#./.#./###", "2": "##./..#/.#./#../###",
    "3": "##./..#/.#./..#/##.", "4": "#.#/#.#/###/..#/..#", "5": "###/#../##./..#/##.",
    "6": ".##/#../###/#.#/###", "7": "###/..#/.#./.#./.#.", "8": "###/#.#/###/#.#/###",
    "9": "###/#.#/###/..#/##.",
    ".": "./././.#".replace("#", "#")[:7] + "", ",": "../../../.#/#.",
    ":": "./#/./#/.", ";": "../.#/../.#/#.", "!": "#/#/#/./#", "¡": "#/./#/#/#",
    "?": "##./..#/.#./.../.#.", "¿": ".#./.../.#./#../.##", "+": ".../.#./###/.#./...",
    "-": ".../.../###/.../...", "=": ".../###/.../###/...", "/": "..#/..#/.#./#../#..",
    "%": "#.#/..#/.#./#../#.#", "(": ".#/#./#./#./.#", ")": "#./.#/.#/.#/#.",
    "'": "#/#/././/".rstrip("/"), "*": ".../#.#/.#./#.#/...",
}
GLIFOS["<"] = "..#/.#./#../.#./..#"
GLIFOS[">"] = "#../.#./..#/.#./#.."
GLIFOS["."] = "./././#"
GLIFOS["'"] = "#/#/./././"[:9]
ACENTOS = {"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ñ": "N"}


def glifo_a_filas(texto):
    filas = [f for f in texto.split("/")]
    while len(filas) < 5:
        filas.append("." * len(filas[0]))
    return filas[:5]


def crear_fuente(nombre, escala):
    alto_celda = 8
    chars = list(GLIFOS.keys()) + list(ACENTOS.keys())
    ancho_hoja = 256
    x = y = 0
    img = Image.new("RGBA", (ancho_hoja * escala, 64 * escala), (0, 0, 0, 0))
    entradas = []
    for ch in chars:
        base = ACENTOS.get(ch, ch)
        filas = glifo_a_filas(GLIFOS[base])
        an = max(len(f) for f in filas)
        if x + an + 1 > ancho_hoja:
            x, y = 0, y + alto_celda
        for j, f in enumerate(filas):
            for i, c in enumerate(f):
                if c == "#":
                    rect_b(img, (x + i) * escala, (y + j + 2) * escala, escala)
        if ch in ACENTOS:
            if ch == "Ñ":
                for i in range(an):
                    rect_b(img, (x + i) * escala, y * escala, escala)
            else:
                rect_b(img, (x + an // 2 + (1 if an % 2 == 0 else 0)) * escala, y * escala, escala)
        entradas.append((ch, x, y, an))
        x += an + 1
    guardar(img, f"fuente/{nombre}.png")
    lineas = [
        f'info face="{nombre}" size={8 * escala} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0',
        f"common lineHeight={9 * escala} base={7 * escala} scaleW={img.width} scaleH={img.height} pages=1 packed=0",
        f'page id=0 file="{nombre}.png"',
    ]
    registros = []
    for ch, cx, cy, an in entradas:
        ids = {ord(ch)}
        if ch.lower() != ch:
            ids.add(ord(ch.lower()))
        for cid in ids:
            registros.append(
                f"char id={cid} x={cx * escala} y={cy * escala} width={an * escala} height={alto_celda * escala} "
                f"xoffset=0 yoffset=0 xadvance={(an + 1) * escala} page=0 chnl=15"
            )
    registros.append(f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={3 * escala} page=0 chnl=15")
    lineas.append(f"chars count={len(registros)}")
    lineas += registros
    (SALIDA / f"fuente/{nombre}.fnt").write_text("\n".join(lineas) + "\n", encoding="utf-8")


def rect_b(img, x, y, escala):
    for j in range(escala):
        for i in range(escala):
            img.putpixel((x + i, y + j), (255, 255, 255, 255))


def texto(img, x, y, cad, letra):
    """Escribe con la propia fuente dentro de un sprite (5 px de alto)."""
    for ch in cad.upper():
        if ch == " ":
            x += 3
            continue
        filas = glifo_a_filas(GLIFOS[ACENTOS.get(ch, ch)])
        for j, f in enumerate(filas):
            for i, c in enumerate(f):
                if c == "#":
                    pon(img, x + i, y + j, letra)
        x += max(len(f) for f in filas) + 1


def ancho_texto(cad):
    t = 0
    for ch in cad.upper():
        t += 3 if ch == " " else max(len(f) for f in glifo_a_filas(GLIFOS[ACENTOS.get(ch, ch)])) + 1
    return t - 1



# ---------------------------------------------------------------- ayudas de dibujo
PALOS = {
    "picas": ["..#..", ".###.", "#####", "#.#.#", "..#.."],
    "corazon": [".#.#.", "#####", "#####", ".###.", "..#.."],
    "diamante": ["..#..", ".###.", "#####", ".###.", "..#.."],
    "trebol": [".###.", ".###.", "#####", "#.#.#", "..#.."],
}


def contorno(img, letra="k"):
    """Añade un borde de un píxel alrededor de todo lo opaco."""
    salida = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                i, j = x + dx, y + dy
                if 0 <= i < img.width and 0 <= j < img.height and img.getpixel((i, j))[3]:
                    pon(salida, x, y, letra)
                    break
    return salida


def elipse(img, cx, cy, rx, ry, letra):
    for y in range(img.height):
        for x in range(img.width):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                pon(img, x, y, letra)


def palo(img, x, y, nombre, letra):
    for j, f in enumerate(PALOS[nombre]):
        for i, c in enumerate(f):
            if c == "#":
                pon(img, x + i, y + j, letra)


def icono_naipe(nombre_palo, letra_carta):
    color = "R" if nombre_palo in ("corazon", "diamante") else "k"
    img = lienzo(12, 12)
    rect(img, 1, 0, 10, 12, "k")
    rect(img, 2, 1, 8, 10, "c")
    texto(img, 3, 1, letra_carta, color)
    palo(img, 4, 6, nombre_palo, color)
    return img


def mini_naipe(letra_carta, color="k"):
    img = lienzo(7, 11)
    rect(img, 0, 0, 7, 11, "k")
    rect(img, 1, 1, 5, 9, "c")
    texto(img, 2, 3, letra_carta, color)
    return img


def varios_naipes(letras, colores=None):
    img = lienzo(12, 12)
    paso = 0 if len(letras) == 1 else (12 - 7) / (len(letras) - 1)
    for i, l in enumerate(letras):
        c = colores[i] if colores else "k"
        img.alpha_composite(mini_naipe(l, c), (round(i * paso), 1 if i % 2 else 0))
    return img


def icono_ficha(claro, oscuro):
    img = lienzo(12, 12)
    for y in range(12):
        for x in range(12):
            dx, dy = x - 5.5, y - 5.5
            r = math.hypot(dx, dy)
            if r > 6:
                continue
            if r > 5.2:
                pon(img, x, y, "k")
            elif r > 3.4:
                a = math.atan2(dy, dx) % (math.pi / 2)
                pon(img, x, y, "c" if a < math.pi / 4 else claro)
            elif r > 2.6:
                pon(img, x, y, oscuro)
            else:
                pon(img, x, y, claro)
    return img


def con_flecha(base):
    img = base.copy()
    for j, f in enumerate(["..c..", ".ccc.", "ccccc", "..c..", "..c.."]):
        for i, c in enumerate(f):
            if c == "c":
                pon(img, 7 + i - 1, j, "m")
    return img


def icono_dado(n, fondo="c", punto="k"):
    img = lienzo(12, 12)
    rect(img, 1, 1, 10, 10, "k")
    rect(img, 2, 2, 8, 8, fondo)
    posiciones = {
        1: [(5, 5)], 2: [(3, 3), (7, 7)], 3: [(3, 3), (5, 5), (7, 7)],
        4: [(3, 3), (7, 3), (3, 7), (7, 7)], 5: [(3, 3), (7, 3), (5, 5), (3, 7), (7, 7)],
        6: [(3, 3), (7, 3), (3, 5), (7, 5), (3, 7), (7, 7)],
    }
    for x, y in posiciones[n]:
        rect(img, x, y, 2, 2, punto)
    return img


def rejilla_palos(colocacion):
    """Varios palos en un icono: se leen mejor que varios naipes solapados."""
    img = lienzo(12, 12)
    for x, y, nombre, letra in colocacion:
        palo(img, x, y, nombre, letra)
    return img


def dos_dados():
    img = lienzo(12, 12)
    a = icono_dado(5).resize((8, 8), Image.NEAREST)
    b = icono_dado(3).resize((8, 8), Image.NEAREST)
    img.alpha_composite(a, (0, 0))
    img.alpha_composite(b, (4, 4))
    return img


def tres_fichas():
    img = lienzo(12, 12)
    for i, (x, y, c, o) in enumerate(((0, 0, "R", "r"), (5, 2, "G", "g"), (2, 6, "B", "b"))):
        img.alpha_composite(icono_ficha(c, o).resize((7, 7), Image.NEAREST), (x, y))
    return img


def tres_sietes():
    img = lienzo(12, 12)
    rect(img, 0, 2, 12, 8, "k")
    for x in (1, 5, 9):
        texto(img, x, 3, "7", "R")
    return img

# ---------------------------------------------------------------- protagonista
CUERPO = {
    "frente": [
        "......kkkk......",
        ".....kvvvvk.....",
        "....kvvvvvpk....",
        "....kvpppppk....",
        "....kpddddpk....",
        "....kpyddypk....",
        "....kpddddpk....",
        ".....kppppk.....",
        "....krRyyRrk....",
        "...kcrRRRRrck...",
        "....krRRRRrk....",
        "....krrrrrrk....",
    ],
    "espalda": [
        "......kkkk......",
        ".....kvvvvk.....",
        "....kvvvvvpk....",
        "....kvvvvvpk....",
        "....kvvvvppk....",
        "....kvvvpppk....",
        "....kvvppppk....",
        ".....kppppk.....",
        "....krRRRRrk....",
        "...kcrRRRRrck...",
        "....krRRRrrk....",
        "....krrrrrrk....",
    ],
    "lado": [
        "......kkkk......",
        ".....kvvvvk.....",
        "....kvvvvvvk....",
        "....kvvvppppk...",
        "....kvvpddddk...",
        "....kvvpddydk...",
        "....kvvpddddk...",
        ".....kpppppk....",
        "....krRRyRrk....",
        "....krRRRcck....",
        "....krRRRRrk....",
        "....krrrrrrk....",
    ],
}
PIERNAS = {
    "quieto": ["....", ".....kdkkdk.....", ".....kdkkdk.....", ".....kkkkkk....."],
    "a": ["", ".....kdkkdk.....", ".....kkkkdk.....", "........kkk....."],
    "b": ["", ".....kdkkdk.....", ".....kdkkdk.....", ".....kkkkkk....."],
    "c": ["", ".....kdkkdk.....", ".....kdkkkk.....", ".....kkk........"],
}


MAPAS_PERSONAJE = {
    "tahur": {},
    "borracho": {"v": "s", "p": "p", "R": "o", "r": "r", "y": "R"},
    "crupier": {"v": "G", "p": "g", "R": "c", "r": "s", "y": "R"},
    "heredera": {"v": "y", "p": "o", "R": "B", "r": "b", "y": "c"},
    "mago": {"v": "b", "p": "k", "R": "v", "r": "p", "y": "B"},
    "guarda": {"v": "k", "p": "d", "R": "d", "r": "k", "y": "R"},
}


def fotograma(direccion, piernas, bote, mapa):
    tabla = str.maketrans(mapa)
    img = lienzo(16, 16)
    arriba = sprite([f.translate(tabla) for f in CUERPO[direccion]], 16)
    img.alpha_composite(sprite(PIERNAS[piernas][1:], 16), (0, 13))
    img.alpha_composite(arriba, (0, 1 + bote))
    return img


def protagonista():
    for nombre, mapa in MAPAS_PERSONAJE.items():
        frames = []
        for d in ("frente", "espalda", "lado"):
            frames += [
                fotograma(d, "quieto", 0, mapa), fotograma(d, "quieto", 1, mapa),
                fotograma(d, "a", 0, mapa), fotograma(d, "b", 1, mapa), fotograma(d, "c", 0, mapa), fotograma(d, "b", 1, mapa),
            ]
        guardar(hoja(frames, 6), f"personajes/pj_{nombre}.png")
        if nombre == "tahur":
            guardar(hoja(frames, 6), "personajes/protagonista.png")


# ---------------------------------------------------------------- enemigos
def ficha_de(tam, base, oscuro, nombre):
    frames = []
    for f in range(4):
        img = lienzo(tam, tam)
        c = (tam - 1) / 2
        escala = tam / 16
        for y in range(tam):
            for x in range(tam):
                dx, dy = x - c, y - c
                r = math.hypot(dx, dy)
                if r > 7.5 * escala:
                    continue
                if r > 7.5 * escala - 0.9:
                    pon(img, x, y, "k")
                elif r > 4.6 * escala:
                    a = (math.atan2(dy, dx) + f * math.pi / 8) % (math.pi / 2)
                    pon(img, x, y, "c" if a < math.pi / 4 else base)
                elif r > 3.8 * escala:
                    pon(img, x, y, oscuro)
                else:
                    pon(img, x, y, base)
        m = tam // 2
        d = max(2, round(2.5 * escala))
        for k in range(max(2, round(2 * escala))):
            pon(img, m - d - 1 + k, m - 2 + k, "k")
            pon(img, m + d - k, m - 2 + k, "k")
        pon(img, m - d, m + 1, "c"); pon(img, m + d - 1, m + 1, "c")
        for x in range(m - d + 1, m + d - 1):
            pon(img, x, m + 3, "k")
        frames.append(img)
    guardar(hoja(frames), f"personajes/{nombre}.png")


def ficha():
    ficha_de(16, "R", "r", "ficha")
    ficha_de(26, "G", "g", "ficha_grande")


def naipe():
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        y = 2 + (1 if f == 1 else 0)
        rect(img, 3, y, 10, 13, "k")
        rect(img, 4, y + 1, 8, 11, "y" if f == 3 else "b")
        for j in range(y + 2, y + 11, 3):
            for i in range(5, 11, 3):
                pon(img, i, j, "B" if f != 3 else "o")
        rect(img, 5, y + 4, 2, 2, "c"); rect(img, 9, y + 4, 2, 2, "c")
        pon(img, 6, y + 5, "k"); pon(img, 9, y + 5, "k")
        rect(img, 6, y + 8, 4, 1, "k")
        frames.append(img)
    guardar(hoja(frames), "personajes/naipe.png")


def joker():
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        bote = 1 if f in (1, 2) else 0
        elipse(img, 7.5, 10 + bote, 5, 4.5, "c")
        for x, y, color in ((3, 3, "R"), (7, 1, "y"), (12, 3, "b")):
            elipse(img, x + .5, y + 1 + bote, 2, 2, color)
        rect(img, 3, 5 + bote, 10, 2, "R"); rect(img, 7, 3 + bote, 3, 4, "y"); rect(img, 11, 5 + bote, 2, 2, "b")
        rect(img, 5, 9 + bote, 2, 2, "k"); rect(img, 9, 9 + bote, 2, 2, "k")
        for x in range(5, 11):
            pon(img, x, 13 + bote - (1 if x in (5, 10) else 0), "R")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/joker.png")


def cubilete():
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        dx = (1 if f == 1 else (-1 if f == 3 else 0))
        for y in range(3, 15):
            ancho = 4 + (y - 3) // 3
            rect(img, 8 - ancho + dx, y, ancho * 2, 1, "r" if y % 4 else "o")
        rect(img, 8 - 4 + dx, 3, 8, 2, "o")
        rect(img, 5 + dx, 8, 2, 2, "y"); rect(img, 9 + dx, 8, 2, 2, "y")
        rect(img, 6 + dx, 12, 4, 1, "k")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/cubilete.png")


def ficha_oro_sprite():
    ficha_de(16, "y", "o", "ficha_oro")


def camara():
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        rect(img, 2, 5, 12, 8, "k"); rect(img, 3, 6, 10, 6, "s")
        rect(img, 6, 7, 4, 4, "k"); rect(img, 7, 8, 2, 2, "R" if f < 2 else "o")
        rect(img, 7, 2, 2, 3, "k"); rect(img, 4, 1, 8, 2, "p")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/camara.png")


def ratero():
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        b = 1 if f % 2 else 0
        elipse(img, 7.5, 5 + b, 4.5, 4.5, "o"); rect(img, 3, 3 + b, 10, 3, "k"); rect(img, 5, 4 + b, 2, 1, "c"); rect(img, 9, 4 + b, 2, 1, "c")
        rect(img, 4, 9 + b, 8, 5, "p"); rect(img, 12, 8 + b, 3, 4, "y")
        rect(img, 5, 14, 2, 2 if f % 2 else 1, "k"); rect(img, 9, 14, 2, 1 if f % 2 else 2, "k")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/ratero.png")


def dado_bomba():
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        y = 3 + (1 if f in (1, 3) else 0)
        rect(img, 3, y, 10, 10, "k"); rect(img, 4, y + 1, 8, 8, "R" if f % 2 else "r")
        for px, py in ((5, 2), (9, 2), (7, 4), (5, 6), (9, 6)):
            rect(img, px, y + py, 2, 2, "c")
        pon(img, 8, y - 1, "y"); pon(img, 9, y - 2, "o")
        frames.append(img)
    guardar(hoja(frames), "personajes/dado_bomba.png")


def reina():
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        b = 1 if f in (1, 3) else 0
        rect(img, 3, b + 2, 10, 13, "k"); rect(img, 4, b + 3, 8, 11, "c")
        palo(img, 6, b + 5, "corazon", "R")
        for x in (4, 7, 10):
            rect(img, x, b, 2, 3, "y")
        rect(img, 4, b + 12, 8, 1, "R")
        frames.append(img)
    guardar(hoja(frames), "personajes/reina.png")


def portero():
    frames = []
    for f in range(4):
        img = lienzo(20, 20)
        rect(img, 4, 8, 12, 9, "d")
        rect(img, 8, 8, 4, 5, "c"); rect(img, 9, 8, 2, 5, "R")
        rect(img, 2, 8, 3, 7, "d"); rect(img, 15, 8, 3, 7, "d")
        rect(img, 2, 15, 3, 2, "c"); rect(img, 15, 15, 3, 2, "c")
        elipse(img, 9.5, 5, 4.6, 4.6, "o")
        rect(img, 5, 0, 10, 3, "k")
        rect(img, 5, 4, 10, 2, "k")
        pie = f % 2 == 0
        rect(img, 5, 17, 4, 3 if pie else 2, "k"); rect(img, 11, 17, 4, 2 if pie else 3, "k")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/portero.png")


def dado():
    alas = [
        ["kk....", "kcck..", ".kcck.", "..kkk."],
        ["......", "kkkk..", "kccck.", ".kkkk."],
        ["......", "......", "kkckk.", "kcck.."],
        ["......", "kkkk..", "kccck.", ".kkkk."],
    ]
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        y0 = 3 + (1 if f in (1, 2) else 0)
        izq = sprite(alas[f], 6)
        img.alpha_composite(izq, (0, y0 + 1))
        img.alpha_composite(izq.transpose(Image.FLIP_LEFT_RIGHT), (10, y0 + 1))
        rect(img, 4, y0, 8, 9, "k")
        rect(img, 5, y0 + 1, 6, 7, "c")
        rect(img, 5, y0 + 7, 6, 1, "s")
        pon(img, 6, y0 + 3, "r"); pon(img, 9, y0 + 3, "r")
        pon(img, 7, y0 + 5, "k"); pon(img, 8, y0 + 5, "k")
        frames.append(img)
    guardar(hoja(frames), "personajes/dado.png")


def sota():
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        bote = 1 if f in (1, 3) else 0
        rect(img, 3, 0 + bote, 10, 14, "k")
        rect(img, 4, 1 + bote, 8, 12, "c")
        rect(img, 4, 1 + bote, 2, 1, "R")
        rect(img, 10, 12 + bote, 2, 1, "R")
        # el ojo que apunta
        rect(img, 6, 4 + bote, 4, 6, "k")
        rect(img, 7, 5 + bote, 2, 4, "R" if f != 3 else "y")
        pon(img, 7, 6 + bote, "k")
        pon(img, 8, 7 + bote, "c")
        pie = (f % 2) == 0
        rect(img, 5, 14, 2, 2 if pie else 1, "k")
        rect(img, 9, 14, 2, 1 if pie else 2, "k")
        frames.append(img)
    guardar(hoja(frames), "personajes/sota.png")


def jefe():
    """La Banca: una tragaperras enfadada de 48x48."""
    frames = []
    for f in range(3):
        img = lienzo(48, 48)
        rect(img, 6, 10, 34, 34, "k")
        rect(img, 7, 11, 32, 32, "r")
        rect(img, 7, 11, 32, 2, "R")
        rect(img, 7, 41, 32, 2, "d")
        rect(img, 10, 4, 26, 7, "k")
        rect(img, 11, 5, 24, 5, "y")
        for i in range(12, 34, 3):
            pon(img, i, 7, "o" if (i + f) % 2 else "c")
        # ventana de rodillos (los símbolos van en sprites aparte)
        rect(img, 10, 15, 26, 14, "k")
        rect(img, 11, 16, 24, 12, "d")
        # boca-ranura
        rect(img, 14, 32, 18, 8, "k")
        rect(img, 15, 33, 16, 6, "d" if f != 2 else "R")
        for i in range(15, 31, 3):
            rect(img, i, 33, 2, 2, "c")
            rect(img, i + 1, 37, 2, 2, "c")
        # brazo
        rect(img, 40, 24, 3, 8, "k")
        rect(img, 41, 24, 1, 8, "s")
        y_palanca = 12 + f * 3
        rect(img, 42, y_palanca, 2, 24 - y_palanca, "k")
        rect(img, 43, y_palanca, 1, 24 - y_palanca, "s")
        rect(img, 41, y_palanca - 4, 6, 5, "k")
        rect(img, 42, y_palanca - 3, 4, 3, "R")
        pon(img, 43, y_palanca - 3, "c")
        # patas
        rect(img, 9, 44, 8, 4, "k"); rect(img, 29, 44, 8, 4, "k")
        rect(img, 10, 44, 6, 2, "p"); rect(img, 30, 44, 6, 2, "p")
        frames.append(img)
    guardar(hoja(frames), "personajes/jefe.png")

    simbolos = {
        "siete": [
            "..........", ".kkkkkkkk.", ".kRRRRRRk.", ".kkkkkRRk.", "....kRRk..",
            "...kRRk...", "...kRRk...", "..kRRk....", "..kRRk....", "..kkkk....",
        ],
        "campana": [
            "....kk....", "...kyyk...", "..kyycyk..", "..kyycyk..", "..kyyyyk..",
            ".kyyyyyyk.", ".kooooook.", ".kkkkkkkk.", "....kk....", "..........",
        ],
        "cereza": [
            "......kk..", ".....kGGk.", "....k.kk..", "...k...k..", "..kk...kk.",
            ".kRRk.kRRk", "kRcRRkRcRk", "kRRRRkRRRk", ".kRRk.kkk.", "..kk......",
        ],
    }
    guardar(hoja([sprite(simbolos[s], 10) for s in ("siete", "campana", "cereza")]), "personajes/rodillos.png")


def pez_rojo():
    frames = []
    for f in range(3):
        img = lienzo(48, 48)
        cola = [12, 6, 10][f]
        for x in range(2, 15):
            alto = int((14 - x) * cola / 13) + 2
            rect(img, x, 24 - alto, 1, alto * 2, "o" if x < 8 else "R")
        elipse(img, 27, 24, 17, 13, "R")
        elipse(img, 29, 30, 12, 6, "o")
        for x, y in ((16, 20), (21, 16), (21, 24), (26, 19), (15, 27), (26, 14)):
            pon(img, x, y, "r"); pon(img, x + 1, y + 1, "r")
        for i in range(10):
            rect(img, 18 + i, 7 + abs(i - 4), 1, 6 - abs(i - 4) + 3, "o")
        elipse(img, 23, 34, 5, 3 + (f == 1), "o")
        elipse(img, 35, 18, 5, 5, "c")
        elipse(img, 36, 19, 2.6, 2.6, "k")
        pon(img, 35, 18, "c")
        if f == 2:
            elipse(img, 44, 25, 3, 4, "k")
        else:
            rect(img, 41, 26, 3, 1, "k")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/pez_rojo.png")


def ruleta():
    frames = []
    for f in range(4):
        img = lienzo(48, 48)
        for y in range(48):
            for x in range(48):
                dx, dy = x - 23.5, y - 23.5
                r = math.hypot(dx, dy)
                if r > 23:
                    continue
                if r > 21.8:
                    pon(img, x, y, "k")
                elif r > 19:
                    pon(img, x, y, "o" if (x + y) % 5 else "y")
                elif r > 9:
                    seg = int(((math.atan2(dy, dx) + f * math.pi / 16) % math.tau) / (math.tau / 12))
                    pon(img, x, y, "G" if seg == 0 else ("R" if seg % 2 else "k"))
                elif r > 8:
                    pon(img, x, y, "k")
                else:
                    pon(img, x, y, "y")
        for i in range(3):
            pon(img, 18 + i, 21 + i, "k"); pon(img, 29 - i, 21 + i, "k")
        pon(img, 20, 25, "r"); pon(img, 27, 25, "r")
        for x in range(21, 27):
            pon(img, x, 28, "k")
        frames.append(img)
    guardar(hoja(frames), "personajes/ruleta.png")


def dado_jefe():
    frames = []
    for f in range(4):
        img = lienzo(48, 48)
        d = (0, 2, 0, -2)[f]
        rect(img, 7, 7 + d, 34, 34, "k"); rect(img, 9, 9 + d, 30, 30, "c"); rect(img, 9, 35 + d, 30, 4, "s")
        for x, y in ((13, 13), (29, 13), (13, 29), (29, 29)):
            rect(img, x, y + d, 6, 6, "R")
        rect(img, 18, 22 + d, 4, 4, "k"); rect(img, 26, 22 + d, 4, 4, "k")
        frames.append(img)
    guardar(hoja(frames), "personajes/dados.png")


def revolver():
    frames = []
    for f in range(6):
        img = lienzo(48, 48)
        elipse(img, 23.5, 23.5, 22, 22, "k"); elipse(img, 23.5, 23.5, 20, 20, "s"); elipse(img, 23.5, 23.5, 16, 16, "p")
        for i in range(6):
            a = math.tau * i / 6 + f * math.tau / 36
            elipse(img, 23.5 + math.cos(a) * 12, 23.5 + math.sin(a) * 12, 4, 4, "k")
        elipse(img, 23.5, 23.5, 5, 5, "y"); rect(img, 21, 22, 2, 2, "k"); rect(img, 25, 22, 2, 2, "k")
        frames.append(img)
    guardar(hoja(frames), "personajes/revolver.png")


def bingo():
    frames = []
    for f in range(4):
        img = lienzo(48, 48)
        elipse(img, 23.5, 21, 19, 19, "k"); elipse(img, 23.5, 21, 17, 17, "B")
        for i, c in enumerate("RyGo"):
            a = f * 1.2 + i * 1.7
            elipse(img, 23.5 + math.cos(a) * 9, 21 + math.sin(a) * 9, 4, 4, c)
        for x in range(9, 40, 6):
            rect(img, x, 6, 1, 30, "s")
        rect(img, 12, 39, 24, 8, "k"); rect(img, 13, 40, 22, 5, "r")
        frames.append(img)
    guardar(hoja(frames), "personajes/bingo.png")


def cajero():
    frames = []
    for f in range(3):
        img = lienzo(48, 48)
        rect(img, 6, 16, 36, 24, "s"); rect(img, 8, 18, 32, 20, "p"); rect(img, 12, 6, 24, 12, "s"); rect(img, 14, 8, 20, 8, "k")
        texto(img, 16, 10, "777", "m")
        for j in range(3):
            for i in range(5):
                rect(img, 11 + i * 6, 21 + j * 5, 4, 3, "c" if (i + j + f) % 3 else "y")
        cajon = 40 if f < 2 else 42
        rect(img, 4, cajon, 40, 6, "k"); rect(img, 6, cajon + 1, 36, 3, "y" if f == 2 else "r")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/cajero.png")


def coctelero():
    frames = []
    for f in range(4):
        img = lienzo(48, 48)
        d = (0, 0, 2, -2)[f]
        for y in range(12, 44):
            ancho = 10 + (y - 12) // 4
            rect(img, 24 - ancho + d, y, ancho * 2, 1, "s" if y % 7 else "c")
        rect(img, 18 + d, 3, 12, 9, "s"); rect(img, 21 + d, 0, 6, 4, "o")
        rect(img, 16 + d, 22, 5, 5, "k"); rect(img, 28 + d, 22, 5, 5, "k"); pon(img, 18 + d, 24, "R"); pon(img, 30 + d, 24, "R")
        rect(img, 18 + d, 33, 12, 3, "k")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/coctelero.png")


def poker():
    frames = []
    for f in range(2):
        img = lienzo(48, 48)
        elipse(img, 23.5, 26, 16, 18, "o"); rect(img, 12, 8, 24, 7, "k"); rect(img, 7, 14, 34, 4, "G"); rect(img, 4, 17, 40, 3, "g")
        rect(img, 15, 24, 7, 3, "k"); rect(img, 27, 24, 7, 3, "k")
        if f:
            pon(img, 18, 25, "R"); pon(img, 30, 25, "R")
        rect(img, 18, 35, 12, 2, "k")
        rect(img, 8, 41, 32, 7, "p"); rect(img, 20, 41, 8, 4, "c")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/poker.png")


def dueno():
    frames = []
    for f in range(3):
        img = lienzo(48, 48)
        elipse(img, 23.5, 34, 20, 13, "p"); rect(img, 18, 24, 12, 16, "v"); rect(img, 20, 24, 8, 12, "c"); rect(img, 22, 26, 4, 12, "R")
        elipse(img, 23.5, 17, 12, 11, "o"); rect(img, 16, 0, 16, 7, "k"); rect(img, 12, 6, 24, 3, "k"); rect(img, 16, 4, 16, 2, "R")
        rect(img, 16, 14, 6, 3, "k"); rect(img, 26, 14, 6, 3, "k"); pon(img, 18, 15, "y"); pon(img, 28, 15, "y")
        rect(img, 28, 22, 12, 3, "c"); rect(img, 40, 22, 2, 3, "R")
        rect(img, 18, 22, 8, 3 if f == 2 else 1, "k")
        rect(img, 8, 40 + (f % 2), 10, 8 - (f % 2), "k"); rect(img, 30, 40 + ((f + 1) % 2), 10, 8 - ((f + 1) % 2), "k")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/dueno.png")


def mosca():
    frames = []
    for f in range(3):
        img = lienzo(48, 48)
        ala = [lambda: (8, 12, 14), lambda: (9, 20, 12), lambda: (6, 16, 15)][f]()
        for lado in (-1, 1):
            elipse(img, 24 + lado * (ala[2] + 2), ala[1], ala[2], ala[0], "B")
            elipse(img, 24 + lado * (ala[2] + 4), ala[1] - 1, ala[2] - 5, ala[0] - 4, "c")
            for i in range(3):
                rect(img, 24 + lado * (8 + i * 3) - 1, 34 + i * 3, 3, 1, "k")
        img = contorno(img)
        elipse(img, 24, 33, 8, 10, "d")
        for y in (32, 36, 40):
            rect(img, 18, y, 13, 1, "p")
        elipse(img, 24, 17, 8, 7, "d")
        elipse(img, 16, 16, 6, 7, "R")
        elipse(img, 32, 16, 6, 7, "R")
        pon(img, 14, 13, "c"); pon(img, 15, 13, "c"); pon(img, 30, 13, "c"); pon(img, 31, 13, "c")
        rect(img, 21, 21, 7, 2, "s")
        rect(img, 17, 24, 6, 5, "R"); rect(img, 26, 24, 6, 5, "R"); rect(img, 23, 25, 3, 3, "y")
        if f == 2:
            rect(img, 38, 26, 8, 11, "c"); palo(img, 40, 29, "picas", "k")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/mosca.png")


def rey_blackjack():
    frames = []
    for f in range(3):
        img = lienzo(48, 48)
        rect(img, 8, 6, 32, 42, "k")
        rect(img, 9, 7, 30, 40, "c")
        rect(img, 10, 8, 28, 38, "R" if f != 2 else "s")
        rect(img, 12, 10, 24, 34, "c")
        texto(img, 13, 11, "K", "R")
        palo(img, 30, 37, "corazon", "R")
        for x, alto in ((15, 6), (20, 9), (24, 11), (28, 9), (33, 6)):
            rect(img, x - 1, 13 - alto + 8, 3, alto, "y")
        rect(img, 14, 18, 21, 4, "o")
        elipse(img, 24, 28, 9, 7, "o")
        if f == 2:
            for i in range(4):
                pon(img, 18 + i, 25 + i, "k"); pon(img, 21 - i, 25 + i, "k")
                pon(img, 27 + i, 25 + i, "k"); pon(img, 30 - i, 25 + i, "k")
        else:
            rect(img, 19, 26, 3, 3, "k"); rect(img, 27, 26, 3, 3, "k")
            if f == 1:
                pon(img, 20, 27, "y"); pon(img, 28, 27, "y")
        rect(img, 17, 33, 15, 9, "s")
        for x in range(18, 31, 3):
            rect(img, x, 37, 1, 5, "c")
        rect(img, 22, 34, 5, 2, "k")
        frames.append(img)
    guardar(hoja(frames), "personajes/rey_blackjack.png")


# ---------------------------------------------------------------- proyectiles y efectos
def proyectiles():
    guardar(sprite([
        "..kkk...", ".kyyyk..", "kyccyok.", "kyccyok.", "kyyyook.", ".kyook..", "..kkk...",
    ], 8), "efectos/bala.png")
    guardar(sprite([
        "..kkkk..", ".kRRRRk.", "kRRoyRRk", "kRoyyoRk", "kRoyyoRk", "kRRoyRRk", ".kRRRRk.", "..kkkk..",
    ], 8), "efectos/bala_enemiga.png")
    guardar(sprite([
        "..kkkk..", ".kBBBBk.", "kBcBBBBk", "kBBBBBBk", "kBBBBBBk", "kBBBBcBk", ".kBBBBk.", "..kkkk..",
    ], 8), "efectos/burbuja.png")
    guardar(sprite([
        "kkkkkk", "kcccck", "kcRRck", "kRRRRk", "kcRRck", "kcRRck", "kcccck", "kkkkkk",
    ], 6), "efectos/naipe_bala.png")
    guardar(sprite([
        "kkkkkk", "kcccck", "kckkck", "kkkkkk", "kckkck", "kckkck", "kcccck", "kkkkkk",
    ], 6), "efectos/naipe_negro.png")
    guardar(sprite([
        "......kk......", ".....kcck.....", ".....kcsk.....", "....kccsk.....", "....kccsk.....",
        "...kkccskk....", "kkkcccyysccckk", "kkkcccyysccckk", "...kkccskk....", ".....kcsk.....",
        ".....kcsk.....", ".....kcsk.....", "......kk......", "..............",
    ], 14), "efectos/cuchilla.png")

    frames = []
    for f in range(6):
        img = lienzo(48, 48)
        r_ext = 6 + f * 3.6
        r_int = max(0, r_ext - (9 - f))
        for y in range(48):
            for x in range(48):
                d = math.hypot(x - 23.5, y - 23.5)
                d2 = d + 1.4 * math.sin(math.atan2(y - 23.5, x - 23.5) * 7 + f)
                if r_int <= d2 <= r_ext:
                    t = (d2 - r_int) / max(1, r_ext - r_int)
                    pon(img, x, y, "c" if f < 2 and t < .5 else ("y" if t < .55 else ("o" if t < .8 else "R")))
        frames.append(img)
    guardar(hoja(frames), "efectos/explosion.png")

    frames = []
    for f in range(4):
        img = lienzo(8, 8)
        ancho = [6, 4, 2, 4][f]
        x = 4 - ancho // 2
        rect(img, x, 0, ancho, 8, "k")
        if ancho > 2:
            rect(img, x + 1, 1, ancho - 2, 6, "y")
            pon(img, x + 1, 1, "c")
        else:
            rect(img, x, 1, ancho, 6, "o")
        frames.append(img)
    guardar(hoja(frames), "objetos/moneda.png")

    llena = [
        ".kk..kk..", "kRRkkRRk.", "kRcRRRRk.", "kRRRRRRk.", ".kRRRRk..", "..kRRk...", "...kk....",
    ]
    vacia = [f.replace("R", "d").replace("c", "d") for f in llena]
    media = [f[:4].replace("R", "R") + f[4:].replace("R", "d") for f in llena]
    guardar(hoja([sprite(s, 9) for s in (llena, media, vacia)]), "objetos/corazon.png")


def objetos():
    cerrado = [
        "................", "................", "..kkkkkkkkkkkk..", ".kooooooooooook.", ".koyyyyyyyyyyok.",
        ".kooooooooooook.", ".kkkkkkyykkkkkk.", ".kdddddkykdddddk", ".krrrrrkkkrrrrk.", ".krrrrrrrrrrrrk.",
        ".krrrrrrrrrrrrk.", ".kkkkkkkkkkkkkk.", "................",
    ]
    abierto = [
        "..kkkkkkkkkkkk..", ".kooooooooooook.", ".koyyyyyyyyyyok.", ".kkkkkkkkkkkkkk.", ".kdyydyycdydyyk.",
        ".kdddddddddddkk.", ".kkkkkkyykkkkkk.", ".kdddddkykdddddk", ".krrrrrkkkrrrrk.", ".krrrrrrrrrrrrk.",
        ".krrrrrrrrrrrrk.", ".kkkkkkkkkkkkkk.", "................",
    ]
    guardar(hoja([sprite(cerrado, 16), sprite(abierto, 16)]), "objetos/cofre.png")

    pedestal = lienzo(16, 16)
    rect(pedestal, 2, 11, 12, 5, "k"); rect(pedestal, 3, 11, 10, 3, "v"); rect(pedestal, 3, 14, 10, 1, "p")
    rect(pedestal, 4, 9, 8, 2, "k"); rect(pedestal, 5, 9, 6, 1, "s")
    guardar(pedestal, "objetos/pedestal.png")

    trampilla = lienzo(32, 32)
    rect(trampilla, 0, 0, 32, 32, "k")
    rect(trampilla, 2, 2, 28, 28, "y")
    rect(trampilla, 4, 4, 24, 24, "k")
    for i in range(5):
        rect(trampilla, 6 + i * 2, 6 + i * 3, 20 - i * 4, 3, "d" if i % 2 else "p")
    guardar(trampilla, "objetos/trampilla.png")

    dorso = lienzo(16, 22)
    rect(dorso, 0, 0, 16, 22, "k"); rect(dorso, 1, 1, 14, 20, "y"); rect(dorso, 2, 2, 12, 18, "r")
    for j in range(3, 19, 4):
        for i in range(3, 13, 4):
            pon(dorso, i + 1, j + 1, "y"); pon(dorso, i, j + 2, "o"); pon(dorso, i + 2, j + 2, "o")
    guardar(dorso, "objetos/carta_suelo.png")

    columna = lienzo(16, 24)
    for n, y in enumerate(range(16, -1, -4)):
        rect(columna, 1, y + 2, 14, 6, "k")
        rect(columna, 2, y + 3, 12, 3, "R" if n % 2 else "G")
        rect(columna, 2, y + 6, 12, 1, "r" if n % 2 else "g")
        for i in range(3, 14, 4):
            rect(columna, i, y + 3, 2, 3, "c")
    guardar(columna, "baldosas/columna.png")


# ---------------------------------------------------------------- baldosas
ESTILOS = {"normal": ("d", "k", "p"), "tienda": ("g", "k", "G"), "jefe": ("d", "k", "r"), "tesoro": ("p", "d", "v")}


def baldosas():
    azar = random.Random(7)
    columnas = []
    for nombre, (base, sombra, luz) in ESTILOS.items():
        fila = []
        for variante in range(4):
            t = lienzo(16, 16)
            rect(t, 0, 0, 16, 16, base)
            # Solo una marca en las esquinas: una rejilla entera taparía a los enemigos.
            for x, y in ((0, 0), (1, 0), (15, 0), (0, 1), (0, 15)):
                pon(t, x, y, sombra)
            for _ in range(2 + variante * 2):
                pon(t, azar.randrange(1, 14), azar.randrange(1, 14), luz if azar.random() < .45 else sombra)
            if variante == 3:
                x, y = 4, 3
                for _ in range(8):
                    pon(t, x, y, sombra)
                    x += azar.choice((0, 1)); y += 1
            fila.append(t)
        columnas.append(hoja(fila))
    img = lienzo(64, 16 * len(columnas))
    for j, c in enumerate(columnas):
        img.alpha_composite(c, (0, j * 16))
    guardar(img, "baldosas/suelos.png")

    tapa = lienzo(16, 16)
    rect(tapa, 0, 0, 16, 16, "p")
    rect(tapa, 0, 15, 16, 1, "d")
    for x, y in ((3, 4), (11, 9), (7, 12)):
        pon(tapa, x, y, "v")
    guardar(tapa, "baldosas/muro_tapa.png")

    cara = lienzo(16, 16)
    rect(cara, 0, 0, 16, 16, "v")
    rect(cara, 0, 7, 16, 1, "p"); rect(cara, 0, 15, 16, 1, "k")
    rect(cara, 5, 0, 1, 7, "p"); rect(cara, 13, 8, 1, 7, "p")
    for x in range(0, 16):
        pon(cara, x, 0, "s" if x % 5 == 0 else "v")
    guardar(cara, "baldosas/muro_cara.png")

    colores = {"normal": ("s", "v"), "tesoro": ("y", "o"), "tienda": ("m", "G"), "jefe": ("R", "r")}
    filas = []
    for tipo in ("normal", "tesoro", "tienda", "jefe"):
        claro, oscuro = colores[tipo]
        fr = []
        for cerrada in (False, True):
            arriba = lienzo(32, 32)
            rect(arriba, 0, 0, 32, 32, "k")
            rect(arriba, 0, 0, 3, 32, claro); rect(arriba, 29, 0, 3, 32, claro)
            rect(arriba, 3, 0, 26, 3, claro)
            rect(arriba, 3, 3, 1, 29, oscuro); rect(arriba, 28, 3, 1, 29, oscuro)
            if cerrada:
                rect(arriba, 4, 3, 24, 29, "r" if tipo != "jefe" else "d")
                for x in (8, 15, 22):
                    rect(arriba, x, 3, 2, 29, "y")
                rect(arriba, 4, 15, 24, 3, "y")
            fr.append(arriba)
        filas.append(hoja(fr))
    img = lienzo(64, 32 * 4)
    for j, f in enumerate(filas):
        img.alpha_composite(f, (0, j * 32))
    guardar(img, "baldosas/puertas.png")


# ---------------------------------------------------------------- cartas
ICONOS = {
    "bala": ["............", "............", "......kkkk..", ".yy..kyyyyk.", "...ookyccyyk", "yyyyokyccyyk",
             "...ookyyyyok", ".yy..kyyook.", "......kkkk..", "............"],
    "rayo": ["......kkkkk.", ".....kyycyk.", "....kyyyk...", "...kyyyk....", "..kyyyykkk..", ".kkkkyyyyk..",
             "....kyyyk...", "...kyyk.....", "...kyk......", "..kyk.......", "..kk........"],
    "cuchilla": ["..........kk", ".........kck", "........kcsk", ".......kcsk.", "......kcsk..", ".....kcsk...",
                 ".kk.kcsk....", ".kykksk.....", "..kyyk......", ".kkrkyk.....", "krrk.kk.....", "kkk........."],
    "explosion": ["....k...k...", ".k.kyk.kyk.k", "kyk.kyykyk.k", ".kyyyooyyyk.", "..kyoRRoyk..", "kkyoRccRoyk.",
                  "kyyoRccRoyyk", ".kkyoRRoykk.", "..kyyooyyk..", ".kyk.kyk.kyk", ".k...k...k.."],
    "abanico": ["...........k", "..........ky", "........kky.", ".....kkyy...", "..kkyy......", "kkyyyyyyyyyy",
                "..kkyy......", ".....kkyy...", "........kky.", "..........ky", "...........k"],
    "nova": [".....kk.....", ".....yy.....", ".y...kk...y.", "..y......y..", "....kkkk....", "yy.kyccyk.yy",
             "yy.kyccyk.yy", "....kkkk....", "..y......y..", ".y...kk...y.", ".....yy.....", ".....kk....."],
    "afilar": ["....kk......", "...kcck.....", "...kcsk.....", "...kcsk..kk.", "...kcsk.kyyk", "...kcsk.kyyk",
               "...kcsk..kk.", "...kcsk.....", ".kkkyykkk...", "...krrk.....", "...krrk.....", "...kkkk....."],
    "doble": ["...kkk.kkk..", "..kyycyyyck.", "..kyyyykyyk.", "...kkk.kkk..", "............", "....cc......",
              "....cc......", "..cccccc....", "..cccccc....", "....cc......", "....cc......"],
    "perforar": ["............", "...k....k...", "...kk...kk..", "kkkkckkkkck.", "ccccsyyyccsk", "ccccsyyyccsk",
                 "kkkkckkkkck.", "...kk...kk..", "...k....k...", "............"],
    "quemar": [".....k......", "....kRk.....", "....kRRk....", "..k.kRoRk...", ".kRkRooRk.k.", ".kRRoooRRkRk",
               "kRRoyyoooRRk", "kRooycyyooRk", "kRoyycyyyoRk", ".kRoyyyyoRk.", "..kkkkkkkk.."],
    "rebote": ["............", ".kk.......kk", "kyyk.....k..", "kyyk....k...", ".kk.k..k....", "....k.k.....",
               ".....k......", "kkkkkkkkkkkk", "ssssssssssss", "dddddddddddd"],
    "hielo": [".....kk.....", "..k..kBk..k.", ".kBk.kBk.kBk", "..kBkkBkkBk.", "...kBcBBBk..", "kkkkBBcBkkkk",
              "kBBBBcBBBBBk", "kkkkBBBBkkkk", "...kBkkBk...", "..kBk..kBk..", ".kBk....kBk.", "..k......k.."],
    "tapete": ["kkkkkkkkkkkk", "kGGGGGGGGGGk", "kGmGGGGGGmGk", "kGGGGkkGGGGk", "kGGGkyykGGGk", "kGGGkyykGGGk",
               "kGGGGkkGGGGk", "kGmGGGGGGmGk", "kGGGGGGGGGGk", "kkkkkkkkkkkk"],
    "eco": ["............", "...kk..y...o", "..kyk.yy.o.o", "kkyyk..y.o.o", "kyyyk..y.o.o", "kyyyk..y.o.o",
            "kkyyk..y.o.o", "..kyk.yy.o.o", "...kk..y...o", "............"],
    "doble_nada": [".kkkkkkkkkk.", "kyyyyyyyyyyk", "kyk.yyyy.kyk", "kyyk.yy.kyyk", "kyyyk..kyyyk", "kyyyy..yyyyk",
                   "kyyyk..kyyyk", "kyyk.yy.kyyk", "kyk.yyyy.kyk", "kyyyyyyyyyyk", ".kkkkkkkkkk."],
    "propina": ["...kkkkkk...", "..kyyyyyyk..", ".kyokkkkoyk.", ".kyokyyyyyk.", ".kyyokkyyyk.", ".kyyyyyokyk.",
                ".kyokkkkoyk.", "..kyyyyyyk..", "...kkkkkk...", "............"],
    "escalera": ["............", ".........kkk", ".........kyk", ".......kkkyk", ".......kyyyk", ".....kkkyyyk",
                 ".....kyyyyyk", "...kkkyyyyyk", "...kyyyyyyyk", ".kkkyyyyyyyk", ".kkkkkkkkkkk"],
}
ICONOS.update({
    "abanico": ["....kkk.....", "..kkccck....", ".kccckcck...", "kcckcckcck..", "kckcckcckk..", "kkcckcckcck.",
                ".kcckcck.ck.", "..kckck..k..", "...kkk......"],
    "bola": icono_ficha("c", "s"),
    "dados": dos_dados(),
    "boomerang": ["............", "...kkkkkk...", "..kBBBBBBk..", ".kBBkkkkBBk.", ".kBk....kBk.", ".kBk....kBk.",
                  ".kk......kk.", "............", "kyk......kyk", ".k........k."],
    "lluvia": tres_fichas(),
    "molotov": ["...kk.oy....", "...kk..o....", "...kk.......", "..kBBk......", ".kBBBBk.....", ".kBcBBk.....",
                ".kBcBBk.....", ".kBRRRk.....", ".kRRRRk.....", ".kkkkkk....."],
    "jackpot": tres_sietes(),
    "as_picas": icono_naipe("picas", "A"),
    "reparto": rejilla_palos([(0, 0, "diamante", "c"), (7, 3, "diamante", "c"), (0, 7, "diamante", "c")]),
    "ciega_peq": icono_ficha("B", "b"),
    "ciega_grande": icono_ficha("R", "r"),
    "marcada": ["..kkkkkkkk..", "..kccccRck..", "..kccRRcck..", "..kcRRccck..", "..kRRcccck..", "..kcRccRck..",
                "..kccccRck..", "..kcccccck..", "..kkkkkkkk.."],
    "ficha_oro": icono_ficha("y", "o"),
    "subir": con_flecha(icono_ficha("G", "g")),
    "resto": tres_fichas(),
    "comodin": ["R....y....b.", "RR..yyy..bb.", ".RRyyyyybb..", ".RRRyyybbb..", "..kccccck...", "..ckckcck...",
                "..ccccccc...", "..cRcccRc...", "...cRRRc....", "....ccc....."],
    "alfombra": ["kkkkkkkkkkkk", "RRyRRRRRRyRR", "RRRRRRRRRRRR", "RRyRRRRRRyRR", "rrrrrrrrrrrr", "RRyRRRRRRyRR",
                 "RRRRRRRRRRRR", "RRyRRRRRRyRR", "kkkkkkkkkkkk"],
    "pareja": varios_naipes(["K", "K"], ["R", "R"]),
    "trio": rejilla_palos([(3, 0, "picas", "y"), (0, 6, "picas", "y"), (6, 6, "picas", "y")]),
    "poker": rejilla_palos([(0, 0, "picas", "c"), (6, 0, "corazon", "R"), (0, 6, "trebol", "c"), (6, 6, "diamante", "R")]),
    "full": rejilla_palos([(0, 0, "corazon", "R"), (6, 0, "corazon", "R"), (0, 6, "picas", "c"), (6, 6, "picas", "c")]),
    "color": icono_naipe("diamante", "C"),
    "cara_cruz": ["...kkkkkk...", "..kyyyyyyk..", ".kyokkkkoyk.", ".kyokooooyk.", ".kyokooooyk.", ".kyokooooyk.",
                  ".kyokkkkoyk.", "..kyyyyyyk..", "...kkkkkk..."],
    "all_in": ["..kkkkkkkk..", ".kRcRcRcRk..", ".kkkkkkkkk..", ".kGcGcGcGk..", ".kkkkkkkkk..", ".kBcBcBcBk..",
               ".kkkkkkkkk..", ".kycycycyk..", ".kkkkkkkkk.."],
    "racha": ICONOS["quemar"],
    "hucha": ["..........k.", "..kkkkkkk.k.", ".kRRRRRRRk..", "kcRkRRRRRRkk", "kRRRRRRRRRkk", "kRRRRRRRRRk.",
              ".kRRRRRRRk..", "..kRk.kRk...", "..kkk.kkk..."],
    "mano_muerta": ["...kkkkkk...", "..kccccccK..", ".kccccccccK.", ".kckkcckkcK.", ".kckkcckkcK.", ".kcccckccck.",
                    "..kcccccck..", "...kckckk...", "...kkkkk...."],
    "solitario": icono_naipe("trebol", "1"),
    "casa": [".....kk.....", "....kyyk....", "...kyyyyk...", "..kyyyyyyk..", ".kkkkkkkkkk.", "..kRRRRRRk..",
             "..kRRkkRRk..", "..kRRkkRRk..", "..kkkkkkkk.."],
})
ICONOS["mano_muerta"] = [f.replace("K", "k") for f in ICONOS["mano_muerta"]]

def letra_icono(cad, color):
    img = lienzo(12, 12)
    rect(img, 0, 2, 12, 8, "k")
    texto(img, 6 - ancho_texto(cad) // 2, 4, cad, color)
    return img


ICONOS.update({
    "billete": ["............", "kkkkkkkkkkkk", "kGGGGGGGGGGk", "kGmGGkkGGmGk", "kGGGkyykGGGk", "kGGGkyykGGGk", "kGmGGkkGGmGk",
                "kGGGGGGGGGGk", "kkkkkkkkkkkk"],
    "taco": ["..........kk", ".........kok", "........koyk", ".......koyk.", "......koyk..", ".....koyk...", "....koyk....",
             "...koyk.....", "..krrk......", ".krrk.......", "krrk........", "kkk........."],
    "bola8": [".." + "kkkkkkkk" + "..", ".kkkkkkkkkk.", "kkkkccckkkkk", "kkkckkkckkkk", "kkkkccckkkkk", "kkkckkkckkkk", "kkkkccckkkkk",
              "kkkkkkkkkkkk", ".kkkkkkkkkk.", "..kkkkkkkk.."],
    "dardo": ["...........k", "..........kR", ".........kRk", "....k...kRk.", "....kk.kRk..", ".kkkkkkRk...", ".kyyyyyk....", ".kkkkkk.....",
              "....kk......", "....k......."],
    "ruleta_gira": icono_ficha("R", "k"),
    "cortar": varios_naipes(["A", "2"], ["R", "k"]),
    "sobre": ["............", "kkkkkkkkkkkk", "kckkccckkckk", "kcckcckkcckk", "kccckkkccckk", "kcccccccccck", "kcccccccccck", "kkkkkkkkkkkk"],
    "mano": ICONOS["quemar"],
    "doble_pareja": rejilla_palos([(0, 0, "corazon", "R"), (6, 0, "corazon", "R"), (0, 6, "diamante", "y"), (6, 6, "diamante", "y")]),
    "carta_alta": icono_naipe("picas", "K"),
    "siete": letra_icono("7", "y"),
    "tres_ataques": letra_icono("3", "R"),
    "bancarrota": letra_icono("0", "s"),
    "mesa_llena": ["kkkkkkkkkkkk", "kGcGcGcGcGck", "kGGGGGGGGGGk", "kGcGcGcGcGck", "kGGGGGGGGGGk", "kGcGcGcGcGck", "kkkkkkkkkkkk"],
    "rojo_negro": ["kkkkkkrRRRRR", "kkkkkkrRRRRR", "kkkkkkrRRRRR", "kkkkkkrRRRRR", "kkkkkkrRRRRR", "kkkkkkrRRRRR", "kkkkkkrRRRRR", "kkkkkkrRRRRR", "kkkkkkrRRRRR"],
})

CARTAS_VISUAL = {
    "bala": ("ataque", 0, "5"), "rayo": ("ataque", 0, "3"), "cuchilla": ("ataque", 1, "4"),
    "explosion": ("ataque", 1, "8"), "abanico": ("ataque", 0, "3"), "nova": ("ataque", 1, "2"),
    "afilar": ("mod", 0, "+3"), "doble": ("mod", 1, "+1"), "perforar": ("mod", 0, "+2"),
    "quemar": ("mod", 0, ""), "rebote": ("mod", 1, "+2"), "hielo": ("mod", 0, ""),
    "tapete": ("mod", 2, "+2"), "eco": ("mult", 1, ""), "doble_nada": ("mult", 2, "X2"),
    "propina": ("mult", 0, "X1.5"), "escalera": ("mult", 1, "X+"),
    "bola": ("ataque", 0, "4"), "dados": ("ataque", 0, "?"), "boomerang": ("ataque", 1, "4"),
    "lluvia": ("ataque", 1, "4"), "molotov": ("ataque", 0, "5"), "jackpot": ("ataque", 2, "20"),
    "as_picas": ("ataque", 2, "16"), "reparto": ("ataque", 0, "3"),
    "ciega_peq": ("mod", 0, "+2"), "ciega_grande": ("mod", 1, "+5"), "marcada": ("mod", 1, "25%"),
    "ficha_oro": ("mod", 1, ""), "subir": ("mod", 1, "+50%"), "resto": ("mod", 2, "+?"),
    "comodin": ("mod", 2, "?"), "alfombra": ("mod", 2, "+1"),
    "pareja": ("mult", 0, "X2"), "trio": ("mult", 1, "X3"), "poker": ("mult", 2, "X6"),
    "full": ("mult", 2, "X5"), "color": ("mult", 1, "X3"), "cara_cruz": ("mult", 1, "X1/3"),
    "all_in": ("mult", 1, "X3"), "racha": ("mult", 1, "X+"), "hucha": ("mult", 2, "X+"),
    "mano_muerta": ("mult", 1, "X3"), "solitario": ("mult", 1, "X3"), "casa": ("mult", 2, "X2.5"),
    "billete": ("ataque", 0, "2"), "taco": ("ataque", 0, "6"), "bola8": ("ataque", 1, "6"), "dardo": ("ataque", 1, "9"),
    "ruleta_gira": ("ataque", 1, "3"), "cortar": ("mod", 1, "+2"), "sobre": ("mod", 1, "+?"), "mano": ("mod", 0, "+2"),
    "doble_pareja": ("mult", 1, "X4"), "carta_alta": ("mult", 0, "X3"), "siete": ("mult", 2, "X7"), "tres_ataques": ("mult", 1, "X3"),
    "bancarrota": ("mult", 1, "X3"), "mesa_llena": ("mult", 1, "X+"), "rojo_negro": ("mult", 0, "X2"),
}
ESTILO_CARTA = {"ataque": ("R", "r"), "mod": ("B", "b"), "mult": ("y", "o")}


def cartas():
    for id_carta, (tipo, rareza, etiqueta) in CARTAS_VISUAL.items():
        claro, oscuro = ESTILO_CARTA[tipo]
        img = lienzo(32, 44)
        rect(img, 1, 0, 30, 44, "k"); rect(img, 0, 1, 32, 42, "k")
        rect(img, 1, 1, 30, 42, claro)
        rect(img, 2, 2, 28, 40, oscuro)
        rect(img, 3, 3, 26, 26, "k")
        rect(img, 4, 4, 24, 24, "d")
        for r in range(rareza + 1):
            rect(img, 5 + r * 4, 5, 2, 2, "y" if rareza else "s")
        icono = ICONOS[id_carta] if isinstance(ICONOS[id_carta], Image.Image) else sprite(ICONOS[id_carta], 12)
        grande = icono.resize((24, icono.height * 2), Image.NEAREST)
        img.alpha_composite(grande, (4, 4 + (24 - grande.height) // 2))
        if etiqueta:
            texto(img, 16 - ancho_texto(etiqueta) // 2, 33, etiqueta, "c")
        else:
            rect(img, 13, 35, 6, 2, claro)
        guardar(img, f"cartas/{id_carta}.png")
    hueco = lienzo(32, 44)
    rect(hueco, 1, 0, 30, 44, "d"); rect(hueco, 0, 1, 32, 42, "d"); rect(hueco, 2, 2, 28, 40, "k")
    guardar(hueco, "cartas/_hueco.png")
    cerrada = hueco.copy()
    rect(cerrada, 12, 20, 8, 7, "p"); rect(cerrada, 13, 16, 6, 4, "p"); rect(cerrada, 15, 18, 2, 2, "k")
    guardar(cerrada, "cartas/_cerrada.png")


# ---------------------------------------------------------------- objetos pasivos
def pasivos():
    dibujos = {
        "trebol": ["...GG..GG...", "..GmGGGGmG..", "..GGGGGGGG..", "...GGGGGG...", "..GGGGGGGG..", "..GmGGGGmG..",
                   "...GG.gGG...", ".....gg.....", "......gg....", ".......g...."],
        "herradura": ["..yyyyyyyy..", ".yyoooooooy.", ".yo......oy.", ".yk......ky.", ".yo......oy.", ".yk......ky.",
                      ".yo......oy.", ".yy......yy.", ".ooo....ooo."],
        "dado_cargado": icono_dado(6, "R", "c"),
        "zapatos": ["............", "............", ".kkkk.......", ".kddk.......", ".kdddkk.....", ".kdddddkkk..",
                    ".kdpddddddk.", ".kkkkkkkkkk.", "..c.....cc.."],
        "traje": ["..kk....kk..", ".kddkkkkddk.", ".kdddcRcddk.", "kddddcRcdddk", "kdkddcRcddkd", "kdkddcRcddkd",
                  "ckkddcRcddkc", "..kddddddk..", "..kkkkkkkk.."],
        "gafas": ["............", "............", "kkkkkkkkkkkk", "kdddkkkkdddk", "kdBdk..kdBdk", "kdddk..kdddk",
                  ".kkk....kkk.", "............"],
        "puro": ["............", "........s...", ".......s....", "........s...", "............", "orrrrrrrrRRk",
                 "ororrrrrrRok", "orrrrrrrrRRk", "............"],
        "whisky": ["............", ".kkkkkkkkk..", ".k.......k..", ".k.cc....k..", ".kyycyyyyk..", ".koooyooyk..",
                   ".kyoyoyoyk..", ".kyooooyyk..", ".kkkkkkkkk.."],
        "reloj": ["...kyyyyk...", "..kyccccyk..", ".kyccRcccyk.", ".kyccRcccyk.", ".kyccRRRcyk.", ".kycccccyyk.",
                  "..kyccccyk..", "...kyyyyk...", ".....yy....."],
        "tarjeta": ["kkkkkkkkkkkk", "kyyyyyyyyyyk", "kkkkkkkkkkkk", "kyyyyyyyyyyk", "kyRRyyyyyyyk", "kyRRyyycycyk",
                    "kyyyyyyyyyyk", "kkkkkkkkkkkk"],
        "saco": ["....k..k....", ".....kk.....", "....kyyk....", "...koooyk...", "..koyyyoyk..", ".koyykyyoyk.",
                 ".koyykyyoyk.", ".kooyyyooyk.", "..kkkkkkkk.."],
        "iman": ["..RRk..kss..", "..RRk..kss..", "..RRk..kss..", "..RRk..kss..", "..RRk..kss..", "..RRRkkssk..",
                 "...RRRsss...", "....RRss...."],
        "cartera": ["............", ".kkkkkkkkk..", ".krrrrrrrrk.", ".krrrrkkkkk.", ".krrrrkyyyk.", ".krrrrkkkkk.",
                    ".krrrrrrrrk.", ".kkkkkkkkkk."],
        "ficha_vip": icono_ficha("v", "p"),
        "baraja_doble": varios_naipes(["J", "J"], ["R", "k"]),
        "anillo_sello": ["....yyyy....", "...yRRRRy...", "...yRRRRy...", "....yyyy....", "...y....y...", "..y......y..", "..y......y..", "...y....y...", "....yyyy...."],
        "baston": ["...kkkkk....", "..kyyyyyk...", "...kkkyyk...", ".....kdk....", ".....kdk....", ".....kdk....", ".....kdk....", ".....kdk....", ".....kdk....", ".....kyk...."],
        "pajarita": ["............", "kk........kk", "kRRk....kRRk", "kRRRkkkkRRRk", "kRRRkyykRRRk", "kRRRkkkkRRRk", "kRRk....kRRk", "kk........kk"],
        "cerveza": ["...cccccc...", "..cccccccc..", ".kyyyyyyyk..", ".kyoyyoyyk.k", ".kyyyoyyykkk", ".kyoyyyoyk.k", ".kyyyoyyykk.", ".kkkkkkkkk.."],
        "pata_conejo": ["....cc......", "...cccc.....", "...cccc.....", "..ccccc.....", "..cccc......", "..ccc.......", "..yy........", ".kyyk.......", ".kkkk......."],
        "fajo": ["kkkkkkkkkkkk", "kGGGGGGGGGGk", "kkkkkkkkkkkk", "kGGGGyGGGGGk", "kkkkkyykkkkk", "kGGGGyGGGGGk", "kkkkkkkkkkkk"],
        "manga": ["kkkk........", "kddk.ccc....", "kddkkcRc....", "kdddkcRc....", "kdddkccc....", ".kddk.......", ".kkkk......."],
        "corbata": ["....kkkk....", "....kRRk....", ".....kk.....", "....kRRk....", "...kRRRRk...", "...kRRRRk...", "...kRRRRk...", "....kRRk....", ".....kk....."],
        "antifaz": ["............", "kkkkkkkkkkkk", "kpppkppkpppk", "kpkkpkkpkkpk", "kpppkkkkpppk", ".kkkk..kkkk."],
        "guantes": ["..c.c.c.....", "..c.c.c.c...", "..c.c.c.c...", "..ccccccc...", "..ccccccc.c.", "..cccccccc..", "..ccccccc...", "...ccccc....", "...sssss...."],
        "chapa": ["...yyyyyy...", "..yoooooyy..", ".yoyyyyyoyy.", ".yoyRRyyoyy.", ".yoyRRyyoyy.", ".yoyyyyyoyy.", "..yoooooyy..", "...yyyyyy..."],
        "mechero": ["...o........", "..oyo.......", "..oyo.......", "...o........", ".kkkkkkk....", ".kyyyyyk....", ".kyoyoyk....", ".kyyyyyk....", ".kkkkkkk...."],
        "seguro": ["kkkkkkkkkkkk", "kGGGGGGGGGGk", "kGGGGcGGGGGk", "kGGGccGGGGGk", "kGGcGcGGcGGk", "kGGGGcGcGGGk",
                   "kGGGGccGGGGk", ".kGGGcGGGGk.", "..kkGGGGkk..", "....kkkk...."],
    }
    for nombre, dibujo in dibujos.items():
        icono = dibujo if isinstance(dibujo, Image.Image) else sprite(dibujo, 12)
        guardar(icono, f"pasivos/{nombre}.png")

    reparto = lienzo(16, 16)
    rect(reparto, 3, 2, 10, 13, "k"); rect(reparto, 4, 3, 8, 11, "b")
    rect(reparto, 6, 1, 8, 13, "k"); rect(reparto, 7, 2, 6, 11, "c")
    texto(reparto, 8, 5, "?", "R")
    guardar(reparto, "objetos/rebarajar.png")


def eventos():
    frames = []
    # El trilero, con su camiseta de rayas.
    a = lienzo(16, 24)
    elipse(a, 7.5, 5, 4.5, 4.5, "o"); rect(a, 3, 0, 10, 3, "k"); rect(a, 5, 4, 2, 2, "k"); rect(a, 9, 4, 2, 2, "k")
    rect(a, 3, 10, 10, 10, "c")
    for y in range(10, 20, 3):
        rect(a, 3, y, 10, 1, "R")
    rect(a, 4, 20, 3, 4, "b"); rect(a, 9, 20, 3, 4, "b")
    frames.append(contorno(a))
    # La máquina de doble o nada.
    b = lienzo(16, 24)
    rect(b, 2, 4, 12, 20, "r"); rect(b, 2, 4, 12, 2, "y"); rect(b, 4, 8, 8, 7, "k")
    palo(b, 6, 9, "diamante", "y"); rect(b, 5, 18, 6, 2, "k")
    frames.append(contorno(b))
    # El prestamista, con sombrero y bigote.
    c = lienzo(16, 24)
    elipse(c, 7.5, 7, 4.5, 4.5, "o"); rect(c, 1, 3, 14, 2, "k"); rect(c, 4, 0, 8, 3, "k"); rect(c, 5, 6, 2, 2, "k"); rect(c, 9, 6, 2, 2, "k")
    rect(c, 4, 9, 8, 2, "k"); rect(c, 3, 12, 10, 9, "d"); rect(c, 7, 12, 2, 6, "y"); rect(c, 4, 21, 3, 3, "k"); rect(c, 9, 21, 3, 3, "k")
    frames.append(contorno(c))
    # La camarera con su bandeja.
    d = lienzo(16, 24)
    elipse(d, 6.5, 6, 4.5, 4.5, "o"); rect(d, 2, 1, 9, 4, "R"); rect(d, 4, 5, 2, 2, "k"); rect(d, 8, 5, 2, 2, "k")
    rect(d, 2, 11, 9, 10, "k"); rect(d, 4, 12, 5, 7, "c"); rect(d, 3, 21, 3, 3, "o"); rect(d, 7, 21, 3, 3, "o")
    rect(d, 10, 11, 6, 1, "s"); rect(d, 12, 7, 2, 4, "B")
    frames.append(contorno(d))
    # El mendigo y la caja fuerte.
    e = lienzo(16, 24)
    elipse(e, 7.5, 7, 4.5, 4.5, "o"); rect(e, 3, 2, 10, 3, "s"); rect(e, 5, 6, 2, 2, "k"); rect(e, 9, 6, 2, 2, "k")
    rect(e, 3, 12, 10, 10, "p"); rect(e, 5, 22, 7, 2, "y"); rect(e, 6, 16, 4, 3, "s")
    frames.append(contorno(e))
    f6 = lienzo(16, 24)
    rect(f6, 2, 6, 12, 16, "s"); rect(f6, 3, 7, 10, 14, "p"); elipse(f6, 7.5, 14, 3.5, 3.5, "y"); rect(f6, 7, 11, 2, 7, "k")
    frames.append(contorno(f6))
    guardar(hoja(frames), "personajes/npc.png")

    trofeo = lienzo(12, 12)
    rect(trofeo, 3, 0, 6, 6, "y"); rect(trofeo, 1, 1, 2, 3, "o"); rect(trofeo, 9, 1, 2, 3, "o"); rect(trofeo, 5, 6, 2, 3, "y"); rect(trofeo, 3, 9, 6, 2, "o")
    guardar(contorno(trofeo), "objetos/trofeo.png")

    copa = lienzo(32, 28)
    for y in range(2, 26):
        ancho = 8 + (y * 6) // 24
        rect(copa, 16 - ancho, y, ancho * 2, 1, "r" if y % 6 else "R")
    rect(copa, 7, 24, 18, 2, "o")
    guardar(contorno(copa), "objetos/copa_trile.png")


def icono_app():
    icono = icono_ficha("R", "r").resize((120, 120), Image.NEAREST)
    lienzo_icono = lienzo(128, 128)
    lienzo_icono.alpha_composite(icono, (4, 4))
    lienzo_icono.save(RAIZ / "icon.png")


def main():
    (SALIDA / "fuente").mkdir(parents=True, exist_ok=True)
    crear_fuente("pixel", 1)
    crear_fuente("pixel2", 2)
    protagonista(); ficha(); dado(); sota(); naipe(); joker(); cubilete(); portero()
    ficha_oro_sprite(); camara(); ratero(); dado_bomba(); reina(); dado_jefe(); revolver(); bingo()
    cajero(); coctelero(); poker(); dueno()
    jefe(); pez_rojo(); ruleta(); mosca(); rey_blackjack()
    proyectiles(); objetos(); baldosas(); cartas(); pasivos(); eventos(); icono_app()


if __name__ == "__main__":
    main()
