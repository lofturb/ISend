# -*- coding: utf-8 -*-
"""
Comprueba que las fuentes, los metadatos y la interfaz web son coherentes.

Uso:
    python tools/comprobar_fuentes.py

No compila nada: evita despistes como olvidar un .m en el Makefile, cambiar el
bundle ID en un sitio y no en otro, o romper la compatibilidad de la web con
Safari 9. Se ejecuta en local y en el CI antes de `make package`.
"""

import os
import plistlib
import re
import sys

_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAIZ = _BASE
if "--raiz" in sys.argv:
    _i = sys.argv.index("--raiz")
    if _i + 1 < len(sys.argv):
        RAIZ = os.path.abspath(sys.argv[_i + 1])
elif not os.path.isdir(os.path.join(_BASE, "app")):
    if os.path.isdir(os.path.join(os.getcwd(), "app")):
        RAIZ = os.getcwd()

APP = os.path.join(RAIZ, "app")
MAKEFILE = os.path.join(APP, "Makefile")
CONTROL = os.path.join(APP, "control")
INFO = os.path.join(APP, "Resources", "Info.plist")
ENTITLEMENTS = os.path.join(APP, "entitlements.plist")
WEB = os.path.join(APP, "Resources", "web")
WEB_FILES = ("index.html", "style.css", "app.js")


def error(texto):
    print("  ERROR: %s" % texto)
    return 1


def aviso(texto):
    print("  AVISO: %s" % texto)


def fuentes_declaradas(makefile, app):
    patron = re.compile(r"^\s*%s_FILES\s*=\s*((?:.*\\\n)*.*)$" % re.escape(app),
                        re.M)
    m = patron.search(makefile)
    if not m:
        raise RuntimeError("no se encontro %s_FILES en app/Makefile" % app)
    texto = m.group(1).replace("\\\n", " ")
    return [x for x in texto.split() if x.endswith(".m")]


def main():
    problemas = 0

    print("=== Fuentes ===")
    if not os.path.isfile(MAKEFILE):
        return error("no existe app/Makefile")

    with open(MAKEFILE, encoding="utf-8") as f:
        makefile = f.read()

    m = re.search(r"^\s*APPLICATION_NAME\s*=\s*(\S+)\s*$", makefile, re.M)
    if not m:
        return error("no se encontro APPLICATION_NAME en app/Makefile")
    app = m.group(1)

    try:
        declaradas = fuentes_declaradas(makefile, app)
    except RuntimeError as e:
        return error(str(e))

    print("  Aplicacion: %s" % app)
    print("  Fuentes en el Makefile: %d" % len(declaradas))

    en_disco = sorted(n for n in os.listdir(APP)
                      if n.endswith(".m") and os.path.isfile(os.path.join(APP, n)))
    for nombre in en_disco:
        if nombre not in declaradas:
            problemas += error("%s esta en app/ pero no en %s_FILES" % (nombre, app))
    for nombre in declaradas:
        ruta = os.path.join(APP, nombre)
        if not os.path.isfile(ruta):
            problemas += error("%s esta en %s_FILES pero no existe" % (nombre, app))
        elif os.path.getsize(ruta) == 0:
            problemas += error("%s esta vacio" % nombre)

    for nombre in en_disco:
        ruta = os.path.join(APP, nombre)
        if os.path.getsize(ruta) == 0:
            continue
        with open(ruta, encoding="utf-8", errors="replace") as f:
            texto = f.read()
        if "#import" not in texto:
            problemas += error("%s no importa ninguna cabecera" % nombre)

    print("")
    print("=== Metadatos ===")
    try:
        with open(INFO, "rb") as f:
            info = plistlib.load(f)
    except Exception as e:  # noqa: BLE001
        return error("no se pudo leer app/Resources/Info.plist: %s" % e)

    try:
        with open(CONTROL, encoding="utf-8") as f:
            control = f.read()
    except Exception as e:  # noqa: BLE001
        return error("no se pudo leer app/control: %s" % e)

    paquete = re.search(r"^Package:\s*(\S+)", control, re.M)
    version = re.search(r"^Version:\s*(\S+)", control, re.M)
    paquete = paquete.group(1) if paquete else None
    version = version.group(1) if version else None

    bundle = info.get("CFBundleIdentifier")
    ejecutable = info.get("CFBundleExecutable")
    version_info = info.get("CFBundleShortVersionString")
    minimo = info.get("MinimumOSVersion")

    print("  Bundle ID (Info.plist): %s" % bundle)
    print("  Paquete (control):      %s" % paquete)
    print("  Ejecutable:             %s" % ejecutable)
    print("  Version (Info.plist):   %s" % version_info)
    print("  Version (control):      %s" % version)
    print("  iOS minimo:             %s" % minimo)

    if bundle != paquete:
        problemas += error("CFBundleIdentifier y Package no coinciden")
    if ejecutable != app:
        problemas += error("CFBundleExecutable (%s) no coincide con "
                           "APPLICATION_NAME (%s)" % (ejecutable, app))
    if version_info != version:
        problemas += error("CFBundleShortVersionString y Version no coinciden")
    if not minimo:
        problemas += error("falta MinimumOSVersion en Info.plist")
    elif str(minimo) not in ("9.0", "9.0.0"):
        aviso("MinimumOSVersion es %s (el objetivo es 9.0)" % minimo)
    if "UILaunchImages" not in info:
        aviso("falta UILaunchImages: iOS 9 puede mostrar barras negras")

    recursos = os.path.join(APP, "Resources")
    for icono in ("Icon-76.png", "Icon-76@2x.png", "Icon-83.5@2x.png",
                  "iTunesArtwork"):
        if not os.path.isfile(os.path.join(recursos, icono)):
            problemas += error("falta el icono %s" % icono)

    print("")
    print("=== Entitlements ===")
    if os.path.isfile(ENTITLEMENTS):
        try:
            with open(ENTITLEMENTS, "rb") as f:
                ent = plistlib.load(f)
        except Exception as e:  # noqa: BLE001
            return error("no se pudo leer app/entitlements.plist: %s" % e)
        ident = ent.get("application-identifier")
        grupos = ent.get("keychain-access-groups") or []
        print("  application-identifier: %s" % ident)
        if ident and bundle and ident != bundle:
            problemas += error("application-identifier no coincide con "
                               "CFBundleIdentifier")
        if grupos and bundle and bundle not in grupos:
            aviso("el bundle ID no esta en keychain-access-groups")
        if not ent.get("com.apple.private.security.no-sandbox"):
            aviso("falta com.apple.private.security.no-sandbox")
    else:
        aviso("no existe app/entitlements.plist")

    print("")
    print("=== Interfaz web ===")
    if not os.path.isdir(WEB):
        problemas += error("no existe app/Resources/web")
    else:
        for nombre in WEB_FILES:
            ruta = os.path.join(WEB, nombre)
            if not os.path.isfile(ruta) or os.path.getsize(ruta) == 0:
                problemas += error("falta o esta vacio web/%s" % nombre)
        if os.path.isfile(os.path.join(WEB, "index.html")):
            with open(os.path.join(WEB, "index.html"), encoding="utf-8") as f:
                html = f.read()
            for nombre in WEB_FILES[1:]:
                if nombre not in html:
                    problemas += error("index.html no referencia %s" % nombre)

        js_path = os.path.join(WEB, "app.js")
        if os.path.isfile(js_path):
            with open(js_path, encoding="utf-8") as f:
                js = f.read()
            # Safari 9 no entiende ES6 ni fetch.
            prohibidos = [
                ("=>", "funciones flecha"),
                ("`", "plantillas de cadena"),
                (r"\bconst\b", "const"),
                (r"\blet\b", "let"),
                (r"\bfetch\s*\(", "fetch"),
                (r"\bclass\s+\w+", "clases ES6"),
                (r"Object\.assign", "Object.assign"),
                (r"\.includes\s*\(", "String.includes"),
            ]
            for patron, nombre in prohibidos:
                if re.search(patron, js):
                    problemas += error("app.js usa %s (no vale para Safari 9)"
                                       % nombre)

        css_path = os.path.join(WEB, "style.css")
        if os.path.isfile(css_path):
            with open(css_path, encoding="utf-8") as f:
                css = f.read()
            for patron, nombre in ((r"display\s*:\s*grid", "CSS Grid"),
                                   (r"grid-template", "CSS Grid"),
                                   (r"var\s*\(\s*--", "variables CSS"),
                                   (r"\bgap\s*:", "gap de flexbox")):
                if re.search(patron, css):
                    problemas += error("style.css usa %s (no vale para Safari 9)"
                                       % nombre)

    print("")
    if problemas:
        print("=== Resultado: %d problema(s) ===" % problemas)
        return 1
    print("=== Resultado: correcto ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
