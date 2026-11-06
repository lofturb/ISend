# ---------------------------------------------------------------------------
#  ISend -- envio de archivos por Wi-Fi entre el iPad y cualquier navegador.
#
#  App nativa para iOS 9 / armv7 (iPad mini 1, iPad 2, ...).
#  La app levanta un servidor HTTP en la red local y sirve una interfaz web:
#  desde el PC se arrastran archivos para enviarlos y se descargan los del iPad.
#
#  Compilar:  make clean && make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
# ---------------------------------------------------------------------------

TARGET = iphone:clang:9.3:9.0
ARCHS = armv7
PACKAGE_FORMAT = ipa

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = ISend

# Todos los .m del proyecto. Si anades un archivo, anadelo aqui o no enlaza.
ISend_FILES = \
	main.m \
	ISAppDelegate.m \
	ISTheme.m \
	ISPaths.m \
	ISService.m \
	ISHTTPServer.m \
	ISQRCode.m \
	ISFileCell.m \
	ISHomeViewController.m \
	ISFilesViewController.m \
	ISSettingsViewController.m

# CoreImage genera el codigo QR; QuickLook previsualiza los archivos.
ISend_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore CoreImage QuickLook

# Los iconos, las imagenes de arranque y la carpeta web/ viajan en el .app.
ISend_RESOURCE_DIRS = Resources

# -Werror convierte cualquier aviso en error: silenciamos solo lo justo.
ISend_CFLAGS = -fobjc-arc \
	-Wno-deprecated-declarations \
	-Wno-unused-parameter \
	-Wno-unused-variable \
	-Wno-unused-function \
	-Wno-objc-method-access

ISend_LDFLAGS = -Wl,-dead_strip

# Permisos de jailbreak: red local + acceso a carpetas fuera del contenedor.
ISend_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
