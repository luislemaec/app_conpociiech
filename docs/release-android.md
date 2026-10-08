# Release de Android

Guía para firmar y generar la App CONPOCIIECH (`ec.org.conpociiech.app`). La llave de firma
y sus claves **nunca** entran al repositorio: `android/key.properties`, `*.jks` y
`*.keystore` están en `.gitignore`, y un build de release sin `key.properties` falla a
propósito (no se firma con la llave de depuración).

## 1. Crear la llave de subida (una sola vez)

Guárdala **fuera** del repositorio, por ejemplo en `C:\llaves\conpociiech\`, con respaldo
cifrado en otro lugar. Si se pierde, no se pueden publicar actualizaciones.

```bat
mkdir C:\llaves\conpociiech
keytool -genkeypair -v -keystore C:\llaves\conpociiech\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 4096 -validity 10000 -alias upload
```

`keytool` viene con el JDK. Pide una clave para el almacén y otra para la llave, y los datos
del certificado (nombre de la organización: CONPOCIIECH, país: EC).

## 2. Crear `android/key.properties` (no se versiona)

```properties
storePassword=<clave del almacén>
keyPassword=<clave de la llave>
keyAlias=upload
storeFile=C:/llaves/conpociiech/upload-keystore.jks
```

Use `/` en la ruta. Una ruta relativa se resuelve desde `android/`.

## 3. Versión

En `pubspec.yaml`, `version: 1.0.0+1` es `versionName+versionCode`. Cada envío a Google Play
necesita un `versionCode` mayor (`1.0.1+2`, `1.0.2+3`, …).

## 4. Generar

URL de producción (valor por defecto):

```bat
flutter build appbundle --release
```

Resultado: `build/app/outputs/bundle/release/app-release.aab` (lo que se sube a Google Play).

Para instalar directamente en un teléfono (distribución interna o pruebas):

```bat
flutter build apk --release
```

Resultado: `build/app/outputs/flutter-apk/app-release.apk`.

Para el entorno local, agregar `--dart-define=API_BASE_URL=https://tribunal.local/api/v1`
(el dispositivo debe resolver `tribunal.local` y confiar en su certificado).

## 5. Google Play

- Activar **Play App Signing**: Google guarda la llave de la App y la llave del paso 1 queda
  solo como llave de subida (se puede reemplazar si se pierde).
- Publicar primero en **Prueba interna** o **Prueba cerrada**.
- La ficha exige: política de privacidad (URL pública), formulario de **Seguridad de los
  datos** (la App maneja nombres de personas y datos electorales; no los comparte con
  terceros; viajan cifrados por HTTPS), clasificación de contenido, capturas e icono 512 px.

## Verificación antes de publicar

```bat
flutter analyze
flutter test
```

Y probar en un dispositivo real: inicio de sesión, cambio de clave obligatorio, cierre por
15 minutos de inactividad y cada sección según el rol.
