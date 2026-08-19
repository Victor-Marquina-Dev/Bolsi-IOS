import SwiftUI
import BolsiCore

/// Dibuja uno o **varios** `path` del boceto como trazo, escalados desde su lienzo original.
///
/// Toda la lectura del SVG está en `BolsiCore.TrazoSvg`, con tests. Acá solo queda convertir
/// comandos en un `Path` de SwiftUI.
///
/// **Varios trazos, no uno.** Varios íconos del prototipo son un `<svg>` con más de un `<path>`:
/// la campana es cuerpo más badajo, el ojo es párpado más iris, los deslizadores de Ajustes son
/// dos líneas más dos perillas. Dibujar solo el primero deja el ícono a medias — en Android el
/// ojo salió como un rombo sin pupila, y **acá volvió a pasar** en la primera captura por haber
/// escrito este componente con un solo `d`. Es la segunda vez que el mismo detalle cuesta una
/// vuelta: por eso ahora la firma pide una lista y el caso de un solo trazo es la conveniencia,
/// no al revés.
///
/// **El escalado va por el ANCHO, no por el lado corto.** En Android usar `minDimension` dejó los
/// chevrones de "BOLSI" —lienzo 22 × 11— desalineados respecto del texto de al lado.
struct TrazoBoceto: View {
    let trazos: [String]
    /// El lado del `viewBox` del prototipo: 20 en casi todos, 22 en la barra inferior.
    let lienzo: Double
    let grosor: Double
    /// Alto del lienzo cuando **no** es cuadrado (`width="22" height="11"`).
    var lienzoAlto: Double?

    init(d: String, lienzo: Double = 20, grosor: Double = 1.7, lienzoAlto: Double? = nil) {
        self.trazos = [d]
        self.lienzo = lienzo
        self.grosor = grosor
        self.lienzoAlto = lienzoAlto
    }

    init(trazos: [String], lienzo: Double = 20, grosor: Double = 1.7, lienzoAlto: Double? = nil) {
        self.trazos = trazos
        self.lienzo = lienzo
        self.grosor = grosor
        self.lienzoAlto = lienzoAlto
    }

    var body: some View {
        Canvas { contexto, tamano in
            let escala = tamano.width / lienzo

            for d in trazos {
                var camino = Path()
                for comando in TrazoSvg(d).comandos {
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
        }
        .aspectRatio(lienzo / (lienzoAlto ?? lienzo), contentMode: .fit)
    }
}
