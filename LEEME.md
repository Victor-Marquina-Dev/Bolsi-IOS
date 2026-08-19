# Bolsi iOS

App nativa de Bolsi para iPhone, en **SwiftUI**. Habla con el mismo backend que la web y el
Android (`GET /api/...`), así que no duplica ninguna regla de negocio del servidor.

Sigue el mismo diseño que Bolsi Android: el boceto de Claude Design importado en
`AI-Project-Factory/01-projects/bolsi-android/03-diseno/`. **Todas las decisiones difíciles ya
están tomadas y escritas ahí** (`plan-boceto.md`): qué pide el boceto, qué hace Bolsi y por qué.
Este proyecto es la traducción, no un rediseño.

## Por qué el paquete está partido en dos

En la máquina donde se escribe este código no hay macOS, y sin macOS no hay Xcode ni
simulador. La respuesta es separar lo que se puede verificar de lo que no:

| | Qué hay | Dónde se verifica |
|---|---|---|
| **`Sources/BolsiCore`** | Modelos, cliente del API, plata, reglas de negocio, tokens del boceto. **No importa SwiftUI.** | **Acá mismo**, en Windows: `herramientas\swift-win.bat test` |
| **`Sources/BolsiApp`** | Las pantallas SwiftUI | En la Mac de la nube (GitHub Actions), que compila y **devuelve capturas del simulador** |

La regla que sostiene esto: **si algo se puede decidir sin pantalla, va en `BolsiCore` y lleva
test.** Cada regla que quede escondida en una vista es una regla que nadie puede comprobar
hasta que la app esté en un teléfono.

## Compilar y testear en Windows

Necesita el toolchain de swift.org (`winget install Swift.Toolchain`) y Visual Studio con las
herramientas de C++ — Swift en Windows usa el linker y el SDK de MSVC.

```
herramientas\swift-win.bat build
herramientas\swift-win.bat test
```

El script existe porque hay tres cosas que hay que preparar en el orden correcto: entrar al
entorno de Visual Studio, poner el toolchain en el PATH y fijar `SDKROOT`. Detalle en el
propio `.bat`.

## Compilar la app

No hay `.xcodeproj` en el repo a propósito: lo **genera** XcodeGen desde `project.yml`. La CI
corre `xcodegen generate` antes de compilar, y así el proyecto se puede versionar como un YAML
legible en vez de un plist con identificadores generados.

`.github/workflows/ios.yml` hace, en una Mac de la nube: tests del núcleo → generar el
proyecto → compilar para el simulador → **una captura por pantalla**, subidas como artefacto.
Ese artefacto es lo que reemplaza al emulador: la nube verifica la **forma**, el iPhone del
dueño verifica los **datos**.

## Lo que falta para verlo en el iPhone

1. Un repo en GitHub (la CI compila desde ahí).
2. Apple Developer Program (99 USD/año) para TestFlight, con un App Store Connect API key
   como secreto del repo.
