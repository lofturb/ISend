# -*- coding: utf-8 -*-
"""
Genera los iconos e imagenes de arranque de ISend sin dependencias externas.

Escribe PNGs a mano con zlib + struct (biblioteca estandar), asi que funciona
en Windows con Python 3.8 sin Pillow ni nada parecido.

Produce:
  app/Resources/              -> iconos del sistema e imagenes de arranque
  app/recursos-generados.txt  -> resumen de lo creado

Uso (desde la raiz del proyecto):
    python tools/generar_recursos.py

Uso desde cualquier sitio:
    python tools/generar_recursos.py --raiz C:\\ruta\\al\\proyecto

El dibujo es una pareja de flechas (una a la derecha, otra a la izquierda)
sobre un fondo azul noche con degradado: el simbolo de "intercambiar".
"""

import io
import os
import struct
import sys
import zlib


def raiz_proyecto():
    """Acepta --raiz; si no, usa el directorio actual (si tiene app/) o el
    abuelo de este script (cuando vive en tools/)."""
    if "--raiz" in sys.argv:
        i = sys.argv.index("--raiz")
        if i + 1 < len(sys.argv):
            return os.path.abspath(sys.argv[i + 1])
    actual = os.getcwd()
    if os.path.isdir(os.path.join(actual, "app")):
        return actual
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


RAIZ = raiz_proyecto()
DESTINO = os.path.join(RAIZ, "app", "Resources")

# Paleta de ISend: azul noche con acento menta.
FONDO_ARRIBA = (0x1B, 0x2C, 0x46, 255)
FONDO_ABAJO = (0x0A, 0x13, 0x20, 255)
ACENTO = (0x3D, 0xDC, 0x97, 255)
ARRANQUE_FONDO = (0x0B, 0x12, 0x20, 255)


def escribir_png(ruta, ancho, alto, pixeles):
    """pixeles: bytearray RGBA de ancho*alto*4."""
    filas = []
    for y in range(alto):
        inicio = y * ancho * 4
        filas.append(b"\x00" + bytes(pixeles[inicio:inicio + ancho * 4]))
    crudo = b"".join(filas)

    def bloque(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos
                + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))

    cabecera = struct.pack(">IIBBBBB", ancho, alto, 8, 6, 0, 0, 0)
    contenido = (b"\x89PNG\r\n\x1a\n"
                 + bloque(b"IHDR", cabecera)
                 + bloque(b"IDAT", zlib.compress(crudo, 9))
                 + bloque(b"IEND", b""))
    with io.open(ruta, "wb") as f:
        f.write(contenido)


def en_rectangulo_redondeado(x, y, x0, y0, x1, y1, radio):
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    cx = min(max(x, x0 + radio), x1 - radio)
    cy = min(max(y, y0 + radio), y1 - radio)
    dx, dy = x - cx, y - cy
    return dx * dx + dy * dy <= radio * radio


def en_triangulo(px, py, a, b, c):
    def signo(p1, p2, p3):
        return ((p1[0] - p3[0]) * (p2[1] - p3[1])
                - (p2[0] - p3[0]) * (p1[1] - p3[1]))

    d1 = signo((px, py), a, b)
    d2 = signo((px, py), b, c)
    d3 = signo((px, py), c, a)
    hay_negativos = d1 < 0 or d2 < 0 or d3 < 0
    hay_positivos = d1 > 0 or d2 > 0 or d3 > 0
    return not (hay_negativos and hay_positivos)


def dentro_de_flechas(x, y, ancho, alto):
    """Dos flechas horizontales: derecha arriba, izquierda abajo."""
    w, h = float(ancho), float(alto)

    # Flecha superior (apunta a la derecha).
    if (0.20 * w <= x <= 0.67 * w) and (0.355 * h <= y <= 0.420 * h):
        return True
    if en_triangulo(x, y,
                    (0.62 * w, 0.270 * h),
                    (0.83 * w, 0.3875 * h),
                    (0.62 * w, 0.505 * h)):
        return True

    # Flecha inferior (apunta a la izquierda).
    if (0.33 * w <= x <= 0.80 * w) and (0.580 * h <= y <= 0.645 * h):
        return True
    if en_triangulo(x, y,
                    (0.38 * w, 0.495 * h),
                    (0.17 * w, 0.6125 * h),
                    (0.38 * w, 0.730 * h)):
        return True

    return False


def color_de_fondo(y, alto):
    t = 0.0 if alto <= 1 else float(y) / float(alto - 1)
    return tuple(int(round(FONDO_ARRIBA[i] * (1 - t) + FONDO_ABAJO[i] * t))
                 for i in range(4))


def icono(ancho, alto, con_fondo=True):
    """Icono con degradado, esquinas redondeadas y las flechas en menta.
    Se dibuja con supermuestreo 3x para que los bordes queden suaves."""
    sup = 3
    radio = 0.2237 * ancho
    pixeles = bytearray(ancho * alto * 4)
    total_muestras = sup * sup

    for y in range(alto):
        fondo = color_de_fondo(y, alto)
        for x in range(ancho):
            muestras_flecha = 0
            muestras_fondo = 0

            for sy in range(sup):
                for sx in range(sup):
                    px = x + (sx + 0.5) / sup
                    py = y + (sy + 0.5) / sup
                    if con_fondo and not en_rectangulo_redondeado(
                            px, py, 0, 0, ancho, alto, radio):
                        continue
                    muestras_fondo += 1
                    if dentro_de_flechas(px, py, ancho, alto):
                        muestras_flecha += 1

            base = (y * ancho + x) * 4
            if muestras_fondo == 0:
                pixeles[base:base + 4] = b"\x00\x00\x00\x00"
                continue

            cobertura = float(muestras_flecha) / total_muestras
            color = [int(round(fondo[i] * (1 - cobertura) + ACENTO[i] * cobertura))
                     for i in range(3)]
            alfa = 255 if not con_fondo else int(
                round(255.0 * muestras_fondo / total_muestras))
            pixeles[base] = color[0]
            pixeles[base + 1] = color[1]
            pixeles[base + 2] = color[2]
            pixeles[base + 3] = alfa

    return pixeles


def arranque(ancho, alto):
    """Imagen de arranque: fondo azul noche con las flechas centradas."""
    pixeles = bytearray(ancho * alto * 4)
    lado = int(min(ancho, alto) * 0.30)
    ox = (ancho - lado) // 2
    oy = (alto - lado) // 2

    for y in range(alto):
        base_fila = y * ancho * 4
        for x in range(ancho):
            base = base_fila + x * 4
            if ox <= x < ox + lado and oy <= y < oy + lado:
                lx, ly = x - ox, y - oy
                # 2x2 de supermuestreo solo dentro del recuadro del simbolo.
                dentro = 0
                for dy in (0.25, 0.75):
                    for dx in (0.25, 0.75):
                        if dentro_de_flechas(lx + dx, ly + dy, lado, lado):
                            dentro += 1
                if dentro:
                    cobertura = dentro / 4.0
                    pixeles[base] = int(round(
                        ARRANQUE_FONDO[0] * (1 - cobertura) + ACENTO[0] * cobertura))
                    pixeles[base + 1] = int(round(
                        ARRANQUE_FONDO[1] * (1 - cobertura) + ACENTO[1] * cobertura))
                    pixeles[base + 2] = int(round(
                        ARRANQUE_FONDO[2] * (1 - cobertura) + ACENTO[2] * cobertura))
                    pixeles[base + 3] = 255
                    continue
            pixeles[base:base + 4] = bytes(ARRANQUE_FONDO)

    return pixeles


ICONOS = [
    ("Icon-29.png", 29),
    ("Icon-29@2x.png", 58),
    ("Icon-40.png", 40),
    ("Icon-40@2x.png", 80),
    ("Icon-60.png", 60),
    ("Icon-60@2x.png", 120),
    ("Icon-60@3x.png", 180),
    ("Icon-76.png", 76),
    ("Icon-76@2x.png", 152),
    ("Icon-83.5@2x.png", 167),
    ("iTunesArtwork", 512),
]

ARRANQUES = [
    ("LaunchImage-700-Portrait.png", 768, 1024),
    ("LaunchImage-700-Portrait@2x.png", 1536, 2048),
    ("LaunchImage-700-Landscape.png", 1024, 768),
    ("LaunchImage-700-Landscape@2x.png", 2048, 1536),
]


def main():
    if not os.path.isdir(DESTINO):
        os.makedirs(DESTINO)
    hechos = []

    print("  Raiz:    %s" % RAIZ)
    print("  Destino: %s" % DESTINO)
    print("")

    for nombre, lado in ICONOS:
        escribir_png(os.path.join(DESTINO, nombre), lado, lado,
                     icono(lado, lado, con_fondo=(nombre != "iTunesArtwork")))
        hechos.append("%s  %dx%d" % (nombre, lado, lado))

    for nombre, ancho, alto in ARRANQUES:
        escribir_png(os.path.join(DESTINO, nombre), ancho, alto,
                     arranque(ancho, alto))
        hechos.append("%s  %dx%d" % (nombre, ancho, alto))

    resumen = os.path.join(RAIZ, "app", "recursos-generados.txt")
    with io.open(resumen, "w", encoding="utf-8") as f:
        f.write("Recursos generados por tools/generar_recursos.py\n\n")
        f.write("\n".join(hechos) + "\n")

    print("Generados %d archivos en app/Resources" % len(hechos))
    for h in hechos:
        print("   ", h)


if __name__ == "__main__":
    main()
