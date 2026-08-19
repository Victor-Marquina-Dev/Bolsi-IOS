import SwiftUI
import BolsiCore

/// Dibuja un `path` del boceto como trazo, escalado desde su lienzo original.
///
/// Toda la lectura del SVG está en `BolsiCore.TrazoSvg`, con tests. Acá solo queda convertir
/// comandos en un `Path` de SwiftUI, que son doce líneas y nada que pueda salir mal en silencio.
///
/// **El escalado va por el ANCHO, no por el lado corto.** En Android usar `minDimension` dejó
/// los chevrones de "BOLSI" —cuyo lienzo es 22 × 11— desalineados respecto del texto de al lado.
/// Para un lienzo cuadrado da lo mismo; para uno que no lo es, no.
struct TrazoBoceto: View {
    let d: String
    /// El lado del `viewBox` del prototipo: 20 en casi todos, 22 en la barra inferior.
    let lienzo: Double
    let grosor: Double
    /// Alto del lienzo cuando **no** es cuadrado (`width="22" height="11"`).
    var lienzoAlto: Double?

    init(d: String, lienzo: Double = 20, grosor: Double = 1.7, lienzoAlto: Double? = nil) {
        self.d = d
        self.lienzo = lienzo
        self.grosor = grosor
        self.lienzoAlto = lienzoAlto
    }

    var body: some View {
        // El trazo se lee una vez por `d`: son constantes y volver a parsearlas en cada
        // recomposición es trabajo tirado.
        let trazo = TrazoSvg(d)

        Canvas { contexto, tamano in
            let escala = tamano.width / lienzo
            var camino = Path()

            for comando in trazo.comandos {
                switch comando {
                case let .mover(x, y):
                    camino.move(to: CGPoint(x: x * escala, y: y * escala))
                case let .linea(x, y):
                    camino.addLine(to: CGPoint(x: x * escala, y: y * escala))
                case let .curva(x1, y1, x2, y2, x, y):
                    camino.addCurve(
                        to: CGPoint(x: x * escala, y: y * escala),
                        control1: CGPoint(x: x1 * escala, y: y1 * escala),
                        control2: CGPoint(x: x2 * escala, y: y2 * escala)
                    )
                case .cerrar:
                    camino.closeSubpath()
                }
            }

            contexto.stroke(
                camino,
                with: .color(.primary),
                style: StrokeStyle(
                    lineWidth: grosor * escala,
                    // El boceto pone `stroke-linecap="round"` y `stroke-linejoin="round"` en
                    // cada `<svg>`: sin esto los íconos salen con puntas cortadas.
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .aspectRatio(lienzo / (lienzoAlto ?? lienzo), contentMode: .fit)
    }
}
