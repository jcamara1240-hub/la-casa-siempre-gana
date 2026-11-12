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


def mismos_pixeles(img, destino):
    """True si el archivo ya tiene esos píxeles: otra versión de Pillow comprime distinto
    y reescribirlo ensuciaría git sin cambiar nada."""
    if not destino.exists():
        return False
    with Image.open(destino) as viejo:
        return viejo.size == img.size and viejo.convert("RGBA").tobytes() == img.convert("RGBA").tobytes()


def guardar(img, ruta):
    destino = SALIDA / ruta
    destino.parent.mkdir(parents=True, exist_ok=True)
    if not mismos_pixeles(img, destino):
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


def linea(img, x0, y0, x1, y1, letra):
    """Línea de un píxel de grosor (Bresenham)."""
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pon(img, x0, y0, letra)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


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


def enemigo_crupier():
    """Visera verde, chaleco y un abanico de naipes. En el fotograma 3 avisa: los naipes brillan."""
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        b = 1 if f in (1, 3) else 0
        aviso = f == 3
        rect(img, 4, 1 + b, 8, 1, "k")  # pelo engominado
        rect(img, 3, 2 + b, 10, 2, "m" if aviso else "G"); rect(img, 3, 3 + b, 10, 1, "g")  # la visera
        rect(img, 4, 4 + b, 8, 4, "c" if aviso else "o")
        pon(img, 6, 5 + b, "k"); pon(img, 9, 5 + b, "k")
        rect(img, 6, 7 + b, 4, 1, "k")  # bigote
        rect(img, 4, 8 + b, 8, 5, "c")  # camisa
        rect(img, 4, 8 + b, 2, 5, "k"); rect(img, 10, 8 + b, 2, 5, "k")  # chaleco
        rect(img, 6, 8 + b, 4, 1, "R"); pon(img, 7, 8 + b, "r"); pon(img, 8, 8 + b, "r")  # pajarita
        rect(img, 2, 9 + b, 2, 3, "c"); rect(img, 2, 10 + b, 2, 1, "R")  # brazo con liga
        naipe = "y" if aviso else "c"
        rect(img, 12, 6 + b, 2, 4, naipe); rect(img, 13, 5 + b, 2, 4, naipe)  # los naipes en abanico
        pon(img, 13, 7 + b, "R"); pon(img, 14, 6 + b, "k")
        pie = f % 2 == 0
        rect(img, 5, 13 + b, 2, 3 - b if pie else 2 - b, "k"); rect(img, 9, 13 + b, 2, 2 - b if pie else 3 - b, "k")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/crupier.png")


def maton():
    """Sombrero de ala, traje de raya diplomática y una metralleta. En el 3 la boca del cañón se enciende."""
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        b = 1 if f in (1, 3) else 0
        aviso = f == 3
        rect(img, 4, 0 + b, 8, 3, "p"); rect(img, 4, 2 + b, 8, 1, "R"); rect(img, 6, 0 + b, 4, 1, "v")  # el sombrero
        rect(img, 2, 3 + b, 12, 1, "p")
        rect(img, 4, 4 + b, 8, 4, "o"); rect(img, 4, 7 + b, 8, 1, "r")  # cara y barba de tres días
        rect(img, 5, 5 + b, 2, 1, "k"); rect(img, 9, 5 + b, 2, 1, "k")
        traje = "c" if aviso else "s"
        rect(img, 2, 8 + b, 12, 5, traje)
        for x in (3, 5, 10, 12):
            rect(img, x, 8 + b, 1, 5, "y" if aviso else "v")  # la raya diplomática
        rect(img, 7, 8 + b, 2, 3, "c"); rect(img, 7, 8 + b, 2, 2, "R")  # corbata
        rect(img, 1, 11 + b, 12, 2, "k"); rect(img, 4, 13 + b, 3, 2, "s"); pon(img, 5, 13 + b, "c")  # metralleta y su tambor
        rect(img, 13, 11 + b, 2, 1, "y" if aviso else "k")
        pie = f % 2 == 0
        rect(img, 4, 14, 3, 2 if pie else 1, "k"); rect(img, 9, 14, 3, 1 if pie else 2, "k")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/maton.png")


def botones():
    """El botones del hotel: gorrito, chaqueta roja y una bomba con la mecha encendida."""
    frames = []
    for f in range(4):
        img = lienzo(16, 16)
        b = 1 if f in (1, 3) else 0
        aviso = f == 3
        rect(img, 5, 1 + b, 5, 2, "R"); rect(img, 5, 3 + b, 5, 1, "y")  # el gorrito
        elipse(img, 7.5, 6.0 + b, 3.6, 2.8, "o")
        pon(img, 6, 6 + b, "k"); pon(img, 9, 6 + b, "k"); rect(img, 7, 8 + b, 2, 1, "r")
        rect(img, 4, 9 + b, 7, 4, "R"); rect(img, 4, 9 + b, 7, 1, "y")  # la chaqueta y sus botones
        for y in (10, 12):
            pon(img, 6, y + b, "y"); pon(img, 8, y + b, "y")
        rect(img, 2, 10 + b, 2, 2, "R")
        elipse(img, 13.0, 9.0 + b, 2.2, 2.2, "R" if aviso else "d")  # la bomba en alto
        pon(img, 12, 8 + b, "c" if aviso else "v")
        pon(img, 13, 6 + b, "o"); pon(img, 14, 5 + b, "y" if aviso else "o")
        pie = f % 2 == 0
        rect(img, 5, 13 + b, 2, 3 - b if pie else 2 - b, "r"); rect(img, 8, 13 + b, 2, 2 - b if pie else 3 - b, "r")
        frames.append(contorno(img))
    guardar(hoja(frames), "personajes/botones.png")


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
def con_halo(img, cerca="R", lejos="o"):
    """Rodea lo opaco de un halo cálido semitransparente (dos anillos): las balas enemigas
    se leen sobre cualquier fondo. Agranda el lienzo dos píxeles por cada lado."""
    base = lienzo(img.width + 4, img.height + 4)
    base.alpha_composite(img, (2, 2))
    salida = base.copy()
    for letra, alfa in ((cerca, 190), (lejos, 80)):
        siguiente = salida.copy()
        for y in range(base.height):
            for x in range(base.width):
                if salida.getpixel((x, y))[3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
                    i, j = x + dx, y + dy
                    if 0 <= i < base.width and 0 <= j < base.height and salida.getpixel((i, j))[3]:
                        # en diagonal, más flojo: el halo sale redondeado
                        a = alfa if dx == 0 or dy == 0 else alfa // 2
                        siguiente.putpixel((x, y), rgba(letra)[:3] + (a,))
                        break
        salida = siguiente
    return salida


def proyectiles():
    guardar(sprite([
        "..kkk...", ".kyyyk..", "kyccyok.", "kyccyok.", "kyyyook.", ".kyook..", "..kkk...",
    ], 8), "efectos/bala.png")
    # Las enemigas llevan halo rojo y naranja: siempre se distinguen de las tuyas y del suelo.
    guardar(con_halo(sprite([
        "..kkkk..", ".kRRRRk.", "kRRoyRRk", "kRoyyoRk", "kRoyyoRk", "kRRoyRRk", ".kRRRRk.", "..kkkk..",
    ], 8)), "efectos/bala_enemiga.png")
    guardar(con_halo(sprite([
        "..kkkk..", ".kBBBBk.", "kBcBBBBk", "kBBBBBBk", "kBBBBBBk", "kBBBBcBk", ".kBBBBk.", "..kkkk..",
    ], 8)), "efectos/burbuja.png")
    guardar(con_halo(sprite([
        "kkkkkk", "kcccck", "kcRRck", "kRRRRk", "kcRRck", "kcRRck", "kcccck", "kkkkkk",
    ], 6)), "efectos/naipe_bala.png")
    guardar(con_halo(sprite([
        "kkkkkk", "kcccck", "kckkck", "kkkkkk", "kckkck", "kckkck", "kcccck", "kkkkkk",
    ], 6)), "efectos/naipe_negro.png")
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


def efectos_punchy():
    """Balas de las armas nuevas y el jugo: fogonazos, chispas, casquillos, polvo y la onda del órdago."""
    guardar(sprite([".kk.", "kcyk", "kyok", ".kk."], 4), "efectos/perdigon.png")
    guardar(sprite([".kkkk.", "kcyyok", "kyoyok", "kyooRk", "kooork", ".kkkk."], 6), "efectos/corcho.png")
    guardar(sprite(["kk..", "kcsk", ".ksk", "..kk"], 4), "efectos/esquirla.png")
    guardar(sprite(["....", "cyyo", "yoor", "...."], 4), "efectos/casquillo.png")

    frames = []
    for f in range(2):
        img = lienzo(8, 8)
        rect(img, 0, 3, 6, 4, "k"); rect(img, 1, 4, 4, 2, "R"); rect(img, 1, 5, 4, 1, "r"); rect(img, 3, 4, 1, 2, "c")
        pon(img, 5, 2, "o"); pon(img, 6, 1, "o")  # la mecha
        if f == 0:
            pon(img, 7, 0, "y"); pon(img, 6, 0, "c")
        else:
            pon(img, 7, 0, "c"); pon(img, 7, 1, "y"); pon(img, 5, 0, "y")
        frames.append(img)
    guardar(hoja(frames), "efectos/dinamita.png")

    frames = []
    for f in range(2):
        img = lienzo(8, 8)
        for y in range(8):
            for x in range(8):
                r = math.hypot(x - 3.5, y - 3.5)
                if r > 3.9:
                    continue
                if r > 3.1:
                    pon(img, x, y, "k")
                elif r > 1.7:
                    a = math.atan2(y - 3.5, x - 3.5) % (math.pi / 2)
                    pon(img, x, y, "c" if a < math.pi / 4 else ("R" if f else "r"))
                else:
                    pon(img, x, y, ("y" if f else "k"))
        if f:
            pon(img, 3, 3, "c")
        frames.append(img)
    guardar(hoja(frames), "efectos/mina.png")

    # El tajo de la botella: apunta a +X y barre de arriba abajo.
    frames = []
    for f in range(4):
        img = lienzo(32, 32)
        desde, hasta, grueso = [(-75, -10, 3.5), (-75, 75, 5.5), (-20, 75, 4.0), (35, 75, 2.0)][f]
        for y in range(32):
            for x in range(32):
                dx, dy = x - 15.5, y - 15.5
                r = math.hypot(dx, dy)
                a = math.degrees(math.atan2(dy, dx))
                if desde <= a <= hasta and 14.5 - grueso <= r <= 14.5:
                    borde = r < 14.5 - grueso + 1.0 or a > hasta - 12
                    pon(img, x, y, "s" if borde and f else "c")
        frames.append(img)
    guardar(hoja(frames), "efectos/barrido.png")

    # Fogonazo: centrado en la celda y con el lóbulo largo hacia +X (se gira con el disparo).
    frames = []
    for f in range(3):
        img = lienzo(16, 16)
        escala = [1.0, 0.78, 0.5][f]
        for y in range(16):
            for x in range(16):
                dx, dy = x - 6.5, y - 7.5
                r = math.hypot(dx, dy)
                a = math.atan2(dy, dx)
                # una estrella de cinco puntas estirada hacia delante
                limite = escala * (2.6 + 6.0 * max(0.0, math.cos(a)) ** 4 + 1.6 * max(0.0, math.cos(a * 5)) ** 2)
                if r > limite:
                    continue
                t = r / max(limite, 0.01)
                if f < 2:
                    pon(img, x, y, "c" if t < 0.4 else ("y" if t < 0.75 else "o"))
                else:
                    pon(img, x, y, "y" if t < 0.5 else "s")
        frames.append(img)
    guardar(hoja(frames), "efectos/fogonazo.png")

    frames = []
    for f in range(4):
        img = lienzo(8, 8)
        if f == 0:
            rect(img, 3, 2, 2, 4, "c"); rect(img, 2, 3, 4, 2, "c"); rect(img, 3, 3, 2, 2, "y")
        else:
            d = [0, 1.6, 2.6, 3.4][f]
            for i in range(8):
                a = math.tau * i / 8 + (0.39 if i % 2 else 0)
                largo = 1 if i % 2 else (2 if f < 3 else 1)
                for k in range(largo):
                    x = round(3.5 + math.cos(a) * (d + k * 0.9))
                    y = round(3.5 + math.sin(a) * (d + k * 0.9))
                    pon(img, x, y, ["c", "y", "y", "o"][min(3, f + k)])
        frames.append(img)
    guardar(hoja(frames), "efectos/chispa.png")

    # El polvo de la voltereta: una nube que crece y se deshace.
    frames = []
    nubes = [(3.5, 4.5, 1.0), (2.5, 4.0, 0.8), (5.0, 4.2, 0.8)]
    for f in range(4):
        img = lienzo(8, 8)
        crece = [1.2, 2.0, 2.6, 2.9][f]
        for y in range(8):
            for x in range(8):
                dentro = any(math.hypot(x - cx, y - (cy - f * 0.3)) <= crece * k for cx, cy, k in nubes)
                if not dentro:
                    continue
                if f == 3 and (x + y) % 2:
                    continue
                if f == 2 and (x + y * 3) % 5 == 0:
                    continue
                arriba = y < 4 - f * 0.3
                pon(img, x, y, "c" if arriba and f < 2 else "s")
        frames.append(img)
    guardar(hoja(frames), "efectos/polvo.png")

    frames = []
    for claro, oscuro in (("R", "r"), ("G", "g"), ("B", "b"), ("y", "o")):
        frames.append(sprite([".kkk", "k" + "c" + claro + "k", "k" + claro + oscuro + "k", "kkk."], 4))
    guardar(hoja(frames), "efectos/ficha_rota.png")

    onda = lienzo(64, 64)
    for y in range(64):
        for x in range(64):
            r = math.hypot(x - 31.5, y - 31.5)
            if 28.6 <= r <= 31.6:
                pon(onda, x, y, "c")
            elif 25.8 <= r < 27.2:
                onda.putpixel((x, y), rgba("c")[:3] + (110,))
    guardar(onda, "efectos/onda.png")


def efectos_ronda2():
    """Quemaduras que se quedan en el suelo y los adornos de las paredes de cada piso."""
    # Tres manchas de hollín distintas; el centro más oscuro, el borde roto y con rayas.
    azar = random.Random(11)
    frames = []
    for v in range(3):
        img = lienzo(24, 24)
        rayos = [azar.uniform(0, math.tau) for _ in range(5 + v)]
        for y in range(24):
            for x in range(24):
                dx, dy = x - 11.5, y - 11.5
                r = math.hypot(dx, dy)
                a = math.atan2(dy, dx)
                borde = 7.5 + 2.2 * math.sin(a * (3 + v) + v) + 1.3 * math.sin(a * 7 + 2 * v)
                raya = any(abs((a - b + math.pi) % math.tau - math.pi) < 0.12 for b in rayos)
                if raya:
                    borde += 3.5
                if r > borde:
                    continue
                t = r / borde
                if t > 0.75 and azar.random() < 0.35:
                    continue  # el borde se deshace en motas
                alfa = int(200 * (1.0 - t * 0.6))
                letra = "k" if t < 0.55 else "d"
                img.putpixel((x, y), rgba(letra)[:3] + (alfa,))
        frames.append(img)
    guardar(hoja(frames), "efectos/quemado.png")

    # Adornos de pared y de esquina: celdas de 16x16, se pintan tal cual (o teñidas los neones).
    c = []
    def cuadro(fondo, motivo):
        img = lienzo(16, 16)
        rect(img, 2, 3, 12, 10, "o"); rect(img, 2, 3, 12, 1, "y"); rect(img, 3, 4, 10, 8, fondo)
        for x, y, l in motivo:
            pon(img, x, y, l)
        return contorno(img)
    ficha_m = [(x, y, "R") for x in range(6, 10) for y in range(6, 10)] + [(7, 5, "R"), (8, 5, "R"), (7, 10, "R"), (8, 10, "R"), (5, 7, "R"), (5, 8, "R"), (10, 7, "R"), (10, 8, "R"), (7, 7, "c"), (8, 8, "c"), (6, 6, "c"), (9, 9, "c")]
    c.append(cuadro("d", ficha_m))
    pica = [(7, 5, "c"), (8, 5, "c"), (6, 6, "c"), (7, 6, "c"), (8, 6, "c"), (9, 6, "c"), (5, 7, "c"), (6, 7, "c"), (7, 7, "c"), (8, 7, "c"), (9, 7, "c"), (10, 7, "c"), (5, 8, "c"), (6, 8, "c"), (7, 8, "c"), (8, 8, "c"), (9, 8, "c"), (10, 8, "c"), (7, 9, "c"), (8, 9, "c"), (6, 10, "c"), (7, 10, "c"), (8, 10, "c"), (9, 10, "c")]
    c.append(cuadro("k", pica))
    siete = [(x, 5, "R") for x in range(5, 11)] + [(10, 6, "R"), (9, 7, "R"), (9, 8, "R"), (8, 9, "R"), (8, 10, "R")] + [(4, 11, "o"), (11, 11, "o")]
    c.append(cuadro("y", siete))
    dados = [(x, y, "c") for x in range(5, 9) for y in range(6, 10)] + [(6, 7, "k"), (7, 8, "k")] + [(x, y, "R") for x in range(9, 12) for y in range(8, 11)] + [(10, 9, "c")]
    c.append(cuadro("G", dados))
    # 4: aplique de latón con su tulipa
    c.append(contorno(sprite(["", "", "......cc......", ".....cyyc.....", ".....yyyy.....", ".....oyyo.....", "......oo......", "......o.......", ".....ooo......", "....o.o.......", "....oo........"], 16)))
    # 5: neón en forma de rombo (blanco: se tiñe al pintarlo)
    c.append(sprite(["", "", ".......c........", "......c.c.......", ".....c...c......", "....c..c..c.....", "...c..c.c..c....", "....c..c..c.....", ".....c...c......", "......c.c.......", ".......c........"], 16))
    # 6: candelabro de tres velas
    c.append(contorno(sprite(["", "", "...y...y...y....", "...c...c...c....", "...c...c...c....", "...c...c...c....", "..ooo.ooo.ooo...", "...o...o...o....", "...ooooooooo....", ".......o........", "......ooo......."], 16)))
    # 7: bombilla desnuda colgando del cable
    c.append(contorno(sprite([".......k........", ".......k........", ".......k........", ".......k........", "......sss.......", "......cyy.......", ".....cyyyy......", ".....yyyyo......", "......yoo.......", ".......o........"], 16)))
    # 8: rejilla de ventilación
    rej = lienzo(16, 16); rect(rej, 3, 4, 10, 8, "s")
    for y in (5, 7, 9):
        rect(rej, 4, y, 8, 1, "k")
    c.append(contorno(rej))
    # 9: maceta con palmera, para las esquinas
    c.append(contorno(sprite(["..G.....G.......", "...G...G....G...", "G...G.GmG..G....", ".GG..GmG..GG....", "...GGmGGGG......", ".GmG.GG..GmG....", "G....G.G....G...", "....g...g.......", "......g.........", "....rrrrr.......", "....ooooo.......", ".....rrr........", ".....rrr........", "......r........."], 16)))
    # 10: poste de cordón de terciopelo
    c.append(contorno(sprite(["", "", "", "......yy........", "......oo........", "......oo........", "......oo...RR...", "......oo.RR.....", "......ooR.......", "......oo........", "......oo........", ".....oooo.......", "....oooooo......"], 16)))
    # 11: cenicero de pie
    c.append(contorno(sprite(["", "", "", "", ".....sssss......", "....s.k.k.s.....", ".....sssss......", ".......s........", ".......s........", ".......s........", ".......s........", ".....sssss......", "....sssssss....."], 16)))
    # 12-15: rótulos de neón (blancos: se tiñen): moneda, cofre, interrogación y corona.
    c.append(sprite(["", "", ".....cccccc.....", "....c......c....", "...c...cc...c...", "...c..c.....c...", "...c...cc...c...", "...c.....c..c...", "...c...cc...c...", "....c......c....", ".....cccccc....."], 16))
    c.append(sprite(["", "", "...cccccccccc...", "..c..........c..", "..c..........c..", "..cccccccccccc..", "..c....cc....c..", "..c....cc....c..", "..c..........c..", "..cccccccccccc.."], 16))
    c.append(sprite(["", "", "......cccc......", ".....c....c.....", "..........c.....", ".........c......", "........c.......", ".......c........", ".......c........", "", ".......c........"], 16))
    c.append(sprite(["", "", "", "..c...cc...c....", "..cc.c..c.cc....", "..c.c....c.c....", "..c........c....", "..c........c....", "..cccccccccc....", "", "..cccccccccc...."], 16))
    # 16: rótulo de la sala de apuestas, un siete de neón (también blanco: se tiñe).
    c.append(sprite(["", "", "...cccccccccc...", "...c........c...", "...cccccc...c...", "........c..c....", ".......c..c.....", "......c..c......", ".....c..c.......", ".....c..c.......", ".....cccc......."], 16))
    guardar(hoja(c), "baldosas/adornos.png")


def objetos_punchy():
    """La mesa de póker que se vuelca y el icono del órdago."""
    frames = []
    # De pie: el tapete visto desde arriba, con unas fichas y un naipe.
    img = lienzo(32, 24)
    rect(img, 2, 3, 28, 13, "o"); rect(img, 1, 4, 30, 11, "o")
    rect(img, 3, 4, 26, 11, "G"); rect(img, 2, 5, 28, 9, "G")
    rect(img, 3, 13, 26, 1, "g")
    for x, y in ((7, 6), (9, 7), (22, 10)):
        rect(img, x, y, 2, 2, "R" if x != 9 else "B")
    rect(img, 14, 6, 3, 4, "c"); pon(img, 15, 7, "R")
    rect(img, 1, 15, 30, 3, "r"); rect(img, 2, 15, 28, 1, "o")  # el canto
    rect(img, 4, 18, 2, 4, "r"); rect(img, 26, 18, 2, 4, "r")  # las patas
    frames.append(contorno(img))
    # Volcada: de canto, como un parapeto; se ve la madera de abajo y las patas hacia ti.
    img = lienzo(32, 24)
    rect(img, 1, 6, 30, 2, "G"); rect(img, 2, 5, 28, 1, "G")
    rect(img, 1, 8, 30, 10, "o")
    for x in range(5, 30, 6):
        rect(img, x, 8, 1, 10, "r")  # las tablas
    rect(img, 1, 17, 30, 1, "r")
    rect(img, 5, 14, 3, 7, "r"); rect(img, 5, 14, 1, 7, "o"); rect(img, 24, 14, 3, 7, "r"); rect(img, 24, 14, 1, 7, "o")
    rect(img, 5, 21, 3, 1, "y"); rect(img, 24, 21, 3, 1, "y")  # contera de latón
    frames.append(contorno(img))
    # Rota: dos trozos, astillas y fichas por el suelo.
    img = lienzo(32, 24)
    for x0, y0, ancho, alto in ((2, 11, 11, 7), (17, 12, 12, 6)):
        rect(img, x0, y0, ancho, alto, "o"); rect(img, x0, y0, ancho, 1, "G")
        rect(img, x0 + 3, y0 + 1, 1, alto - 1, "r")
    for x, y in ((13, 12), (14, 14), (16, 11), (12, 9), (29, 10)):
        pon(img, x, y, "o")
    rect(img, 6, 18, 2, 3, "r"); rect(img, 22, 18, 2, 2, "r")
    frames.append(contorno(img))
    for x, y, c in ((10, 21, "R"), (19, 21, "B"), (27, 20, "y")):
        rect(frames[2], x, y, 2, 1, c)
    guardar(hoja(frames), "objetos/mesa.png")
    guardar(icono_ordago(), "objetos/ordago.png")


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
ESTILOS = {"normal": ("d", "k", "p"), "tienda": ("g", "k", "G"), "jefe": ("d", "k", "r"), "tesoro": ("p", "d", "v"),
           "apuestas": ("r", "k", "y")}


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


# ---------------------------------------------------------------- cartas del arsenal de los años 20
# Se dibujan sin borde y contorno() les pone el negro: así se leen sobre el fondo morado.
def icono_recortada():
    img = lienzo(12, 12)
    rect(img, 4, 4, 6, 1, "c"); rect(img, 4, 5, 6, 1, "s")  # los dos cañones, serrados
    rect(img, 3, 4, 1, 3, "s"); rect(img, 5, 6, 3, 1, "o")  # báscula y guardamanos
    rect(img, 1, 4, 2, 2, "o"); rect(img, 1, 6, 2, 1, "r"); rect(img, 1, 7, 1, 2, "r")  # culata cortada en pistola
    pon(img, 4, 7, "s")
    img = contorno(img)
    for x, y in ((11, 2), (11, 4), (11, 6), (11, 8)):
        pon(img, x, y, "y")
    return img


def icono_tommy():
    img = lienzo(12, 12)
    rect(img, 1, 3, 2, 2, "o"); pon(img, 1, 5, "r")  # culata
    rect(img, 3, 3, 5, 2, "s"); rect(img, 3, 3, 5, 1, "c")  # cajón
    rect(img, 8, 3, 3, 1, "s"); pon(img, 8, 2, "s"); pon(img, 10, 2, "s")  # cañón con aletas
    rect(img, 3, 5, 1, 3, "o")  # empuñadura
    elipse(img, 6.0, 6.6, 1.7, 1.9, "s"); pon(img, 6, 6, "k"); pon(img, 5, 6, "c")  # el tambor
    rect(img, 9, 4, 1, 3, "o")  # empuñadura delantera
    img = contorno(img)
    pon(img, 11, 2, "y"); pon(img, 11, 4, "y")
    return img


def icono_ruleta_rusa():
    img = lienzo(12, 12)
    for y in range(12):
        for x in range(12):
            r = math.hypot(x - 5.5, y - 5.5)
            if r <= 5.8:
                pon(img, x, y, "k" if r > 5.0 else "s")
    for i in range(6):
        a = -math.pi / 2 + math.tau * i / 6
        cx, cy = round(5.5 + math.cos(a) * 3.0 - 0.5), round(5.5 + math.sin(a) * 3.0 - 0.5)
        rect(img, cx, cy, 2, 2, "y" if i == 0 else "k")
        if i == 0:
            pon(img, cx, cy, "c"); pon(img, cx + 1, cy + 1, "o")
    rect(img, 5, 5, 2, 2, "d")
    pon(img, 3, 2, "c")
    return img


def icono_dinamita():
    img = lienzo(12, 12)
    rect(img, 3, 4, 4, 7, "R"); rect(img, 6, 4, 1, 7, "r"); rect(img, 3, 4, 1, 7, "o")
    rect(img, 3, 7, 4, 1, "c")  # la faja de papel
    pon(img, 5, 3, "c"); pon(img, 6, 2, "c"); pon(img, 7, 1, "c")  # mecha
    img = contorno(img)
    for x, y, c in ((8, 0, "y"), (9, 1, "o"), (8, 1, "c"), (10, 0, "y"), (9, 2, "y")):
        pon(img, x, y, c)
    return img


def icono_laser():
    img = lienzo(12, 12)
    rect(img, 1, 7, 3, 3, "s"); pon(img, 1, 7, "c"); rect(img, 2, 10, 2, 1, "p")  # el emisor de la cámara acorazada
    img = contorno(img)
    pon(img, 3, 7, "R")
    for i in range(7):
        x, y = 4 + i, 6 - i
        pon(img, x, y, "c")  # el rayo
        pon(img, x, y + 1, "R")
        pon(img, x - 1, y, "R")
    for x, y, c in ((10, 0, "y"), (11, 1, "y"), (11, 0, "c"), (9, 0, "o"), (11, 2, "o")):
        pon(img, x, y, c)
    return img


def icono_corcho():
    img = lienzo(12, 12)
    rect(img, 1, 6, 4, 5, "g"); rect(img, 2, 6, 1, 5, "G")  # la botella
    rect(img, 2, 4, 2, 2, "y"); rect(img, 1, 6, 4, 1, "y")  # papel dorado
    rect(img, 1, 8, 4, 2, "c")  # etiqueta
    pon(img, 2, 8, "R"); pon(img, 3, 9, "R")
    rect(img, 7, 1, 3, 2, "o"); pon(img, 7, 1, "y"); rect(img, 8, 3, 1, 1, "o")  # el corcho volando
    img = contorno(img)
    for x, y in ((3, 2), (4, 3), (5, 2), (4, 1), (6, 4)):
        pon(img, x, y, "c")  # la espuma
    return img


def icono_mina():
    img = lienzo(12, 12)
    elipse(img, 5.5, 8.3, 5.2, 2.6, "r")  # el canto
    for y in range(12):
        for x in range(12):
            dx, dy = (x - 5.5) / 5.2, (y - 7.0) / 2.6
            if dx * dx + dy * dy <= 1.0:
                a = math.atan2(dy, dx) % (math.pi / 3)
                pon(img, x, y, ("c" if a < math.pi / 6 else "R") if dx * dx + dy * dy > 0.4 else "r")
    rect(img, 4, 5, 4, 2, "k")  # el detonador
    rect(img, 5, 3, 2, 2, "R"); pon(img, 5, 3, "c")  # y su luz
    img = contorno(img)
    for x, y in ((5, 0), (6, 0), (2, 2), (9, 2), (3, 1), (8, 1)):
        pon(img, x, y, "y")
    return img


def icono_botella():
    """Una botella rota cogida por el cuello: el cristal roto arriba y unas esquirlas."""
    img = sprite([
        "............",
        "............",
        "............",
        "............",
        "...GGGGGG...",
        "...mGGGGG...",
        "...mGGGGG...",
        "....mGGG....",
        ".....GG.....",
        ".....GG.....",
        ".....gg.....",
        "............",
    ], 12)
    img = contorno(img)
    for x, y0 in ((3, 0), (4, 2), (5, 1), (6, 3), (7, 2), (8, 1)):
        for y in range(y0, 4):
            pon(img, x, y, "B" if y > y0 else "c")
    for x, y in ((10, 2), (11, 4), (10, 6)):
        pon(img, x, y, "c")
    return img


def icono_trucada():
    img = lienzo(12, 12)
    for x, y in ((0, 10), (1, 9), (1, 8), (2, 7), (3, 6), (4, 6)):
        pon(img, x, y, "B")  # la estela curva
    rect(img, 5, 4, 3, 3, "y"); pon(img, 5, 4, "c"); rect(img, 8, 5, 1, 1, "o"); pon(img, 7, 6, "o")
    img = contorno(img)
    for x, y in ((10, 9), (11, 10), (9, 10), (10, 11), (10, 10)):
        pon(img, x, y, "R")  # la diana
    pon(img, 10, 10, "c")
    return img


def icono_empujon():
    img = lienzo(12, 12)
    elipse(img, 7.0, 6.0, 3.6, 3.4, "R")  # el guante de boxeo
    rect(img, 5, 3, 3, 2, "R"); pon(img, 8, 4, "c"); pon(img, 9, 4, "c")
    rect(img, 3, 7, 2, 2, "r")
    rect(img, 2, 4, 2, 5, "c")  # el puño de la manga
    img = contorno(img)
    for y in (3, 6, 9):
        rect(img, 0, y, 1 if y != 6 else 1, 1, "c")
    return img


def icono_metralla():
    img = lienzo(12, 12)
    elipse(img, 2.5, 5.5, 2.0, 2.4, "o"); rect(img, 2, 5, 1, 2, "y")  # el estallido
    for pts in (((7, 1), (8, 1), (8, 2), (9, 2)), ((8, 5), (9, 5), (10, 5), (9, 6), (8, 6)), ((7, 10), (8, 10), (8, 9), (9, 9))):
        for i, (x, y) in enumerate(pts):
            pon(img, x, y, "c" if i == 0 else "s")  # las esquirlas
    img = contorno(img)
    for x, y in ((5, 3), (6, 2), (6, 5), (5, 8), (6, 9)):
        pon(img, x, y, "y")
    return img


def icono_calibre():
    img = sprite([
        "............",
        ".....o......",
        "....coo.....",
        "....cor.....",
        "...cooor....",
        "...rrrrr....",
        "...cyyyo....",
        "...cyyyo....",
        "...cyyyo....",
        "...cyyyo....",
        "..ooooooo...",
        "............",
    ], 12)
    return contorno(img)


def icono_fiebre():
    img = lienzo(12, 12)
    rect(img, 4, 1, 3, 8, "c"); rect(img, 5, 3, 1, 6, "R")  # el termómetro
    elipse(img, 5.0, 9.0, 2.0, 2.0, "R"); pon(img, 4, 8, "c")
    for y in (2, 4, 6):
        pon(img, 6, y, "s")
    img = contorno(img)
    for x, y, c in ((9, 4, "o"), (10, 3, "y"), (9, 6, "y"), (10, 7, "o"), (10, 5, "R"), (1, 3, "o"), (1, 5, "y")):
        pon(img, x, y, c)  # está que arde
    return img


def icono_pelos():
    img = sprite([
        "............",
        "............",
        "...ss.ss....",
        "..scssss....",
        "..scssss....",
        "..kkkkkk....",
        "s.ssssss.s..",
        "sscccccccs..",
        ".ssssssss...",
        "............",
    ], 12)
    img = contorno(img)
    pon(img, 6, 3, "d"); pon(img, 6, 4, "k")  # el agujero de la bala
    rect(img, 8, 3, 2, 1, "c")
    rect(img, 10, 2, 2, 3, "y"); pon(img, 11, 3, "o")
    return img


def icono_ordago():
    """El órdago: una ficha a punto de reventar. Sirve también de icono en la tienda y el marcador."""
    img = lienzo(12, 12)
    for y in range(12):
        for x in range(12):
            r = math.hypot(x - 5.5, y - 5.5)
            if r > 4.6:
                continue
            if r > 3.9:
                pon(img, x, y, "k")
            elif r > 2.9:
                a = math.atan2(y - 5.5, x - 5.5) % (math.pi / 2)
                pon(img, x, y, "y" if a < math.pi / 4 else "o")
            else:
                pon(img, x, y, "R")
    rect(img, 5, 3, 2, 4, "c"); rect(img, 5, 8, 2, 1, "c")  # ¡!
    for x, y in ((0, 0), (1, 1), (11, 0), (10, 1), (0, 11), (1, 10), (11, 11), (10, 10)):
        pon(img, x, y, "y")
    for x, y in ((5, 0), (6, 0), (0, 5), (0, 6), (11, 5), (11, 6), (5, 11), (6, 11)):
        pon(img, x, y, "o")
    return img


ICONOS.update({
    "recortada": icono_recortada(), "tommy": icono_tommy(), "ruleta_rusa": icono_ruleta_rusa(),
    "dinamita": icono_dinamita(), "laser": icono_laser(), "corcho": icono_corcho(), "mina": icono_mina(),
    "botella": icono_botella(), "trucada": icono_trucada(), "empujon": icono_empujon(),
    "metralla": icono_metralla(), "calibre": icono_calibre(), "fiebre": icono_fiebre(),
    "pelos": icono_pelos(), "ordago": icono_ordago(),
})
CARTAS_VISUAL.update({
    "recortada": ("ataque", 0, "2"), "tommy": ("ataque", 1, "1.5"), "ruleta_rusa": ("ataque", 1, "6"),
    "dinamita": ("ataque", 1, "14"), "laser": ("ataque", 2, "9"), "corcho": ("ataque", 0, "5"),
    "mina": ("ataque", 0, "9"), "botella": ("ataque", 0, "7"),
    "trucada": ("mod", 1, ""), "empujon": ("mod", 0, ""), "metralla": ("mod", 1, "+3"), "calibre": ("mod", 1, "+4"),
    "fiebre": ("mult", 1, "X+"), "pelos": ("mult", 1, "X3"), "ordago": ("mult", 2, "X+"),
})


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
def pasivos_punchy():
    """Los objetos de la voltereta, el órdago y las mesas. 12 de ancho, como los demás."""
    tirantes = sprite([
        "............", ".....RR.....", ".....RR.....", "....oyyo....", "...RRooRR...", "...RR..RR...",
        "..RR....RR..", "..RR....RR..", ".RR......RR.", ".ss......ss.", ".yy......yy.", "............",
    ], 12)
    petaca = sprite([
        "............", "......yy....", "......oo....", "...ssssss...", "..sccsssss..", "..scssssss..",
        "..scsyysss..", "..scsyysss..", "..sssssss...", "..ssssssss..", "...ssssss...", "............",
    ], 12)  # plana, con tapón de rosca y un sello dorado
    pitillera = lienzo(12, 10)
    rect(pitillera, 1, 1, 10, 8, "s"); rect(pitillera, 5, 1, 2, 8, "p")  # las dos tapas y la bisagra
    for x in (2, 3, 4):
        rect(pitillera, x, 2, 1, 5, "c"); pon(pitillera, x, 6, "o")  # los cigarrillos
    rect(pitillera, 2, 4, 3, 1, "R")  # la goma
    rect(pitillera, 7, 2, 3, 6, "c"); rect(pitillera, 8, 3, 1, 4, "s"); pon(pitillera, 8, 4, "y")  # el grabado
    claque = sprite([
        "............", "............", "..ooo.......", "..ocy.......", ".occcc......", ".occcccc....",
        ".occcccooo..", ".ooccccoooo.", ".kkkkkkkkkk.", ".sss....sss.", "............",
    ], 12)
    casquillo = sprite([
        "............", ".R........R.", "..R......R..", "...R....R...", "....RkkR....", "....cyyo....",
        "....cyyo....", "....cGyo....", "....cyyo....", "...oooooo...", "............",
    ], 12)  # colgado al cuello con un cordón
    manga = lienzo(12, 12)
    rect(manga, 1, 6, 3, 5, "p"); rect(manga, 1, 6, 1, 5, "v")  # la manga del traje
    rect(manga, 4, 6, 1, 5, "c"); pon(manga, 4, 8, "y")  # el puño y su gemelo
    rect(manga, 6, 2, 4, 6, "c")  # el as
    for x, y in ((8, 3), (7, 4), (8, 4), (9, 4), (8, 5)):
        pon(manga, x, y, "k")
    rect(manga, 9, 9, 2, 2, "c"); rect(manga, 2, 1, 2, 2, "c")  # naipes saliendo
    tapete = lienzo(12, 11)
    rect(tapete, 1, 1, 10, 9, "s"); rect(tapete, 2, 2, 8, 7, "G")
    palo(tapete, 4, 3, "diamante", "m")
    for x, y in ((1, 1), (9, 1), (1, 8), (9, 8)):
        rect(tapete, x, y, 2, 2, "c"); pon(tapete, x + (1 if x == 1 else 0), y + (1 if y == 1 else 0), "k")  # esquinas remachadas
    gatillo = lienzo(12, 11)
    rect(gatillo, 3, 2, 8, 2, "s"); rect(gatillo, 3, 2, 8, 1, "c")  # el cañón
    rect(gatillo, 2, 4, 5, 1, "s")
    rect(gatillo, 2, 5, 2, 3, "o"); rect(gatillo, 1, 7, 2, 2, "o"); pon(gatillo, 3, 5, "r")  # la culata
    rect(gatillo, 5, 5, 1, 2, "y")  # el gatillo, bien a la vista
    rect(gatillo, 4, 7, 3, 1, "s"); pon(gatillo, 6, 6, "s")  # el guardamonte
    return {
        "tirantes": contorno(tirantes), "petaca": contorno(petaca), "pitillera": contorno(pitillera),
        "zapatos_claque": contorno(claque), "casquillo": contorno(casquillo), "naipe_manga": contorno(manga),
        "tapete_reforzado": contorno(tapete), "gatillo": contorno(gatillo),
    }


# Los objetos de la ronda hardcore: contra élites, golpes de un corazón y oleadas.
PASIVOS_HARDCORE = {
    "chaleco": ["..bb....bb..", ".bbbb..bbbb.", ".bbbbbbbbbb.", ".bBbbbbbbBb.", ".bbbssssbbb.", ".bbbsccsbbb.",
                ".bbbssssbbb.", ".bBbbbbbbBb.", ".bbbbbbbbbb.", "..bbbbbbbb.."],
    "espuelas": ["............", "..ooo.......", "..ooo.......", "..oooo......", "..ooooss.y..", "..oooo.syyy.",
                 "..ooooss.y..", ".rrrrrr.....", "............"],
    "cronometro": [".....ss.....", "....ssss....", "...scccs....", "..sccRccs...", "..sccRccs...", "..sccRRcs...",
                   "..scccccs...", "...scccs....", "....sss....."],
    "trofeo_caza": [".c........c.", ".cc.c..c.cc.", "..cccccccc..", "...cccccc...", "..oooooooo..", "..ooccccoo..",
                    "..ookcckoo..", "...occcco...", "....oooo...."],
    "bala_plata": ["............", ".....cc.....", "....cssc....", "....cssc....", "....csss....", "....csss....",
                   "....yyyy....", "....yooy....", "....yyyy...."],
    "navaja": ["............", ".........cc.", ".......cccs.", ".....cccss..", "...cccss....", "..ccss......",
               ".rRRr.......", ".rRRRr......", "..rrr......."],
    "campana": [".....yy.....", "....yyyy....", "...yyyyyy...", "...ycyyyy...", "..yycyyyyy..", "..yyyyyyyy..",
                ".oooooooooo.", ".....rr.....", "....ssss...."],
    "espejo": ["...yyyyyy...", "..yBBBBBBy..", "..yBcBBBBy..", "..yBBcBBBy..", "..yBBBBBBy..", "...yyyyyy...",
               ".....yy.....", ".....oo.....", ".....oo.....", ".....yy....."],
}


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
    dibujos.update(pasivos_punchy())
    dibujos.update({nombre: contorno(sprite(filas, 12)) for nombre, filas in PASIVOS_HARDCORE.items()})
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
    if not mismos_pixeles(lienzo_icono, RAIZ / "icon.png"):
        lienzo_icono.save(RAIZ / "icon.png")


# ---------------------------------------------------------------- sala de apuestas
def simbolo_siete():
    img = lienzo(16, 16)
    rect(img, 3, 2, 10, 3, "R"); rect(img, 10, 5, 3, 2, "R"); rect(img, 9, 7, 3, 2, "R")
    rect(img, 8, 9, 3, 2, "R"); rect(img, 7, 11, 3, 3, "R")
    rect(img, 3, 2, 10, 1, "o"); pon(img, 3, 3, "o")
    return contorno(img)


def simbolos_tragaperras():
    """Los rodillos: siete, moneda, corazón, carta, diamante, órdago y los cuatro malos."""
    f = [simbolo_siete()]
    moneda = lienzo(16, 16)
    elipse(moneda, 7.5, 7.5, 6.2, 6.2, "o"); elipse(moneda, 7.5, 7.5, 5.2, 5.2, "y")
    rect(moneda, 7, 4, 2, 8, "o"); rect(moneda, 5, 5, 6, 1, "o"); rect(moneda, 5, 10, 6, 1, "o")
    pon(moneda, 5, 4, "c"); pon(moneda, 4, 5, "c")
    f.append(contorno(moneda))
    corazon = lienzo(16, 16)
    for y, fila in enumerate([".RRR..RRR.", "RRcRRRRRRR", "RcRRRRRRRR", "RRRRRRRRRR", ".RRRRRRRr.", "..RRRRRr..", "...RRRr...", "....Rr...."]):
        for x, ch in enumerate(fila):
            if ch != ".":
                pon(corazon, x + 3, y + 4, ch)
    f.append(contorno(corazon))
    carta = lienzo(16, 16)
    rect(carta, 4, 2, 8, 12, "c"); texto(carta, 5, 3, "A", "k"); palo(carta, 6, 8, "picas", "k")
    f.append(contorno(carta))
    diamante = lienzo(16, 16)
    for y in range(12):
        ancho = 7 - abs(y - 4) if y <= 4 else 7 - (y - 4)
        ancho = max(ancho, 0)
        for x in range(8 - ancho, 8 + ancho):
            pon(diamante, x, y + 2, "B" if (x + y) % 4 else "c")
    rect(diamante, 2, 5, 12, 1, "b")
    f.append(contorno(diamante))
    ordago = lienzo(16, 16)
    ordago.alpha_composite(icono_ordago(), (2, 2))
    f.append(ordago)
    calavera = lienzo(16, 16)
    elipse(calavera, 7.5, 6.5, 5.5, 5.0, "c"); rect(calavera, 5, 10, 6, 3, "c")
    rect(calavera, 4, 6, 3, 3, "k"); rect(calavera, 9, 6, 3, 3, "k"); pon(calavera, 7, 9, "k"); pon(calavera, 8, 9, "k")
    for x in (6, 8, 10):
        pon(calavera, x, 12, "s")
    f.append(contorno(calavera))
    gato = sprite(["", "", "...k.......k....", "...kk.....kk....", "...kkkkkkkkk....", "..kkykkkkkykk...", "..kkkkkkkkkkk...",
                   "..kkkkkpkkkkk...", "...kkkkkkkkk....", "....kkkkkkk.....", "...kkkkkkkkk....", "...kkkkkkkkkk...", "...kkkkkkkkk.k..", "....kk...kk..k..", "............k..."], 16)
    f.append(contorno(gato, "v"))
    pistola = lienzo(16, 16)
    rect(pistola, 2, 5, 12, 3, "s"); rect(pistola, 2, 5, 12, 1, "c"); rect(pistola, 11, 8, 3, 6, "o"); rect(pistola, 12, 8, 1, 6, "r")
    rect(pistola, 9, 8, 2, 2, "s"); pon(pistola, 9, 10, "s"); rect(pistola, 1, 4, 2, 1, "s")
    f.append(contorno(pistola))
    antifaz = lienzo(16, 16)
    rect(antifaz, 1, 5, 14, 5, "k"); rect(antifaz, 2, 4, 5, 1, "k"); rect(antifaz, 9, 4, 5, 1, "k")
    rect(antifaz, 3, 6, 3, 2, "c"); rect(antifaz, 10, 6, 3, 2, "c"); rect(antifaz, 7, 9, 2, 2, "d")
    rect(antifaz, 0, 6, 1, 1, "R"); rect(antifaz, 15, 6, 1, 1, "R")
    f.append(contorno(antifaz, "s"))
    guardar(hoja(f), "objetos/simbolos_tragaperras.png")


def tragaperras_sala():
    """La tragaperras de la sala: un mueble rojo y oro con tres rodillos, la palanca y la bandeja."""
    img = lienzo(32, 46)
    rect(img, 3, 6, 24, 38, "r"); rect(img, 4, 6, 22, 37, "R")
    rect(img, 3, 1, 24, 7, "y"); rect(img, 4, 2, 22, 5, "o")
    for x in range(5, 26, 3):
        pon(img, x, 4, "c" if x % 2 else "y")  # las bombillas del marquesina
    rect(img, 5, 11, 20, 12, "k")
    for i in range(3):
        rect(img, 6 + i * 6, 12, 5, 10, "c")
        texto(img, 7 + i * 6, 14, "7", "R")
    rect(img, 5, 16, 20, 1, "y")  # la línea de premio
    rect(img, 6, 27, 18, 4, "d"); rect(img, 13, 28, 4, 2, "y")  # ranura de monedas
    rect(img, 5, 36, 20, 5, "k"); rect(img, 6, 37, 18, 3, "s"); rect(img, 9, 38, 3, 1, "y"); rect(img, 16, 38, 2, 1, "y")
    rect(img, 3, 43, 24, 2, "r")
    rect(img, 27, 12, 2, 2, "s"); rect(img, 28, 5, 1, 9, "s"); rect(img, 27, 3, 3, 3, "R"); pon(img, 27, 3, "c")
    guardar(contorno(img), "objetos/tragaperras.png")


def mesa_ruleta_sala():
    """La mesa de ruleta vista desde arriba: el plato a la izquierda y el tapete de apuestas."""
    img = lienzo(68, 42)
    rect(img, 1, 3, 66, 36, "o"); rect(img, 0, 5, 68, 32, "o")
    rect(img, 2, 5, 64, 32, "G"); rect(img, 3, 4, 62, 34, "G")
    rect(img, 2, 36, 64, 2, "g")
    cx, cy = 17.5, 20.5
    for y in range(img.height):
        for x in range(img.width):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if r > 14.5:
                continue
            if r > 13.0:
                pon(img, x, y, "o")
            elif r > 8.0:
                sector = int((math.atan2(dy, dx) + math.pi) / (2 * math.pi) * 18)
                pon(img, x, y, "R" if sector % 2 else "k")
            elif r > 6.5:
                pon(img, x, y, "y")
            else:
                pon(img, x, y, "r" if r > 2 else "y")
    pon(img, 17, 9, "G"); pon(img, 18, 9, "G")
    pon(img, 24, 12, "c")  # la bola
    # Tapete de apuestas: casillas rojas y negras y el cero en verde.
    rect(img, 36, 8, 28, 26, "c")
    rect(img, 37, 9, 4, 24, "m")
    for j in range(3):
        for i in range(5):
            rect(img, 42 + i * 4 + 1 - 1, 9 + j * 8, 3, 7, "R" if (i + j) % 2 == 0 else "k")
    rect(img, 50, 26, 4, 3, "y")  # una ficha apostada
    rect(img, 4, 37, 4, 4, "r"); rect(img, 60, 37, 4, 4, "r")
    guardar(contorno(img), "objetos/mesa_ruleta.png")


def sala_apuestas():
    simbolos_tragaperras(); tragaperras_sala(); mesa_ruleta_sala()


def main():
    (SALIDA / "fuente").mkdir(parents=True, exist_ok=True)
    crear_fuente("pixel", 1)
    crear_fuente("pixel2", 2)
    protagonista(); ficha(); dado(); sota(); naipe(); joker(); cubilete(); portero()
    ficha_oro_sprite(); camara(); ratero(); dado_bomba(); reina(); dado_jefe(); revolver(); bingo()
    cajero(); coctelero(); poker(); dueno()
    jefe(); pez_rojo(); ruleta(); mosca(); rey_blackjack()
    enemigo_crupier(); maton(); botones()
    proyectiles(); objetos(); baldosas(); cartas(); pasivos(); eventos(); icono_app()
    efectos_punchy(); objetos_punchy(); efectos_ronda2()
    sala_apuestas()


if __name__ == "__main__":
    main()
