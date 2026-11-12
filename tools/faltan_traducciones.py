"""Lista, para cada idioma de scripts/idiomas/, los textos del diccionario EN (scripts/idioma.gd)
que le faltan, los que sobran y los que no llevan los mismos %d/%s.

Uso:  python tools/faltan_traducciones.py [código ...]
Sale con código 1 si falta algo, para poder usarlo en pruebas.
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PAR = re.compile(r'"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"')
HUECO = re.compile(r"%[-+0-9.]*[a-zA-Z%]")


def diccionario(ruta, const):
    texto = ruta.read_text(encoding="utf-8")
    inicio = texto.index(f"const {const} := {{")
    fin = texto.index("\n}", inicio)
    return dict(PAR.findall(texto[inicio:fin]))


def main(codigos):
    en = diccionario(RAIZ / "scripts/idioma.gd", "EN")
    archivos = sorted((RAIZ / "scripts/idiomas").glob("*.gd"))
    if codigos:
        archivos = [a for a in archivos if a.stem in codigos]
    hay_fallos = False
    for archivo in archivos:
        otro = diccionario(archivo, "TEXTOS")
        faltan = [k for k in en if k not in otro]
        sobran = [k for k in otro if k not in en]
        huecos = [k for k in otro if k in en and HUECO.findall(k) != HUECO.findall(otro[k])]
        print(f"== {archivo.stem}: {len(otro)} textos, faltan {len(faltan)}, sobran {len(sobran)}, huecos distintos {len(huecos)}")
        for k in faltan:
            print(f'  FALTA  "{k}": "{en[k]}",')
        for k in sobran:
            print(f'  SOBRA  "{k}"')
        for k in huecos:
            print(f'  HUECOS "{k}" -> "{otro[k]}"')
        hay_fallos = hay_fallos or bool(faltan or huecos)
    return 1 if hay_fallos else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
