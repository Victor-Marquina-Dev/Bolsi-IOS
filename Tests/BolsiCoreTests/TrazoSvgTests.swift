import Testing
import Foundation
@testable import BolsiCore

/// Tests del lector de trazos. Cada uno cubre un caso que **en Android se descubrió mirando la
/// pantalla**, que es justo lo que acá no se puede hacer sin una Mac.
@Suite("Trazos SVG")
struct TrazoSvgTests {

    @Test("Un movimiento y una línea, absolutos")
    func basico() {
        let t = TrazoSvg("M5 16V9.4")
        #expect(t.comandos == [
            .mover(x: 5, y: 16),
            .linea(x: 5, y: 9.4),
        ])
    }

    @Test("El ícono de Análisis: tres barras sueltas")
    func analisis() {
        // Es el `tabDefs` real del boceto. Tres subtrazos, no uno.
        let t = TrazoSvg("M5 16V9.4M11 16V5.4M17 16v-4")
        #expect(t.comandos == [
            .mover(x: 5, y: 16), .linea(x: 5, y: 9.4),
            .mover(x: 11, y: 16), .linea(x: 11, y: 5.4),
            .mover(x: 17, y: 16), .linea(x: 17, y: 12), // `v-4` es relativo: 16 − 4
        ])
    }

    @Test("Tras un M, los pares siguientes son líneas y no movimientos")
    func paresImplicitos() {
        // Es el bug que convierte un ícono en un borrón: `M 4 9.6 11 4` son DOS segmentos.
        let t = TrazoSvg("M4 9.6 11 4")
        #expect(t.comandos == [
            .mover(x: 4, y: 9.6),
            .linea(x: 11, y: 4),
        ])
    }

    @Test("Horizontales y verticales, relativas y absolutas")
    func hv() {
        let t = TrazoSvg("M2 2h10v5H4V3")
        #expect(t.comandos == [
            .mover(x: 2, y: 2),
            .linea(x: 12, y: 2),
            .linea(x: 12, y: 7),
            .linea(x: 4, y: 7),
            .linea(x: 4, y: 3),
        ])
    }

    @Test("Cierra el subtrazo y vuelve al inicio")
    func cierre() {
        let t = TrazoSvg("M4.6 5.8h12.8v11.4H4.6z")
        #expect(t.comandos.first == .mover(x: 4.6, y: 5.8))
        #expect(t.comandos.last == .cerrar)
    }

    @Test("Los números negativos pegados se leen como dos valores")
    func negativosPegados() {
        // `l-2.8-2.8` no tiene separadores: el signo hace de corte.
        let t = TrazoSvg("M4.5 8.6l-2.8-2.8")
        #expect(t.comandos.count == 2)
        #expect(t.comandos[0] == .mover(x: 4.5, y: 8.6))
        // Con tolerancia y no con `==`: 4,5 − 2,8 da 1,7000000000000002 en punto flotante.
        // Las coordenadas son geometría y pueden ser `Double`; la plata no, y por eso va en
        // `Decimal` (ver `Dinero.swift`). Compararlas exacto es un test que miente.
        guard case let .linea(x, y) = t.comandos[1] else {
            Issue.record("se esperaba una línea")
            return
        }
        #expect(abs(x - 1.7) < 0.0001)
        #expect(abs(y - 5.8) < 0.0001)
    }

    @Test("Un círculo escrito como dos arcos sale redondo")
    func circulo() {
        // Es la traducción de `<circle cx=6.6 cy=6.6 r=4.4>` que usa la lupa del Historial.
        let t = TrazoSvg("M2.2 6.6a4.4 4.4 0 1 0 8.8 0a4.4 4.4 0 1 0-8.8 0")
        // Arranca en el borde izquierdo del círculo.
        #expect(t.comandos.first == .mover(x: 2.2, y: 6.6))
        // Solo curvas después del movimiento: ninguna línea recta que delate un arco mal leído.
        let soloCurvas = t.comandos.dropFirst().allSatisfy {
            if case .curva = $0 { return true } else { return false }
        }
        #expect(soloCurvas)

        // Y el recorrido pasa de verdad por el borde: el punto extremo derecho es cx + r = 11.
        let llegaAlOtroExtremo = t.comandos.contains {
            if case let .curva(_, _, _, _, x, y) = $0 {
                return abs(x - 11.0) < 0.001 && abs(y - 6.6) < 0.001
            }
            return false
        }
        #expect(llegaAlOtroExtremo)
    }

    @Test("Todos los puntos del arco caen sobre la circunferencia")
    func arcoExacto() {
        // Verifica la matemática, no la forma: cada extremo de tramo tiene que estar a
        // distancia r del centro. Un error de signo en la parametrización se ve acá.
        let t = TrazoSvg("M2.2 6.6a4.4 4.4 0 1 0 8.8 0")
        let centro = (x: 6.6, y: 6.6)
        for comando in t.comandos {
            if case let .curva(_, _, _, _, x, y) = comando {
                let radio = ((x - centro.x) * (x - centro.x) + (y - centro.y) * (y - centro.y)).squareRoot()
                #expect(abs(radio - 4.4) < 0.001)
            }
        }
    }

    @Test("Una cuadrática se convierte en cúbica sin mover el punto final")
    func cuadratica() {
        let t = TrazoSvg("M0 0Q5 10 10 0")
        guard case let .curva(x1, y1, x2, y2, x, y) = t.comandos[1] else {
            Issue.record("se esperaba una curva")
            return
        }
        #expect(x == 10 && y == 0)
        // Controles a dos tercios del control único (5,10).
        #expect(abs(x1 - 10.0 / 3) < 0.0001)
        #expect(abs(y1 - 20.0 / 3) < 0.0001)
        #expect(abs(x2 - (10 - 10.0 / 3)) < 0.0001)
        #expect(abs(y2 - 20.0 / 3) < 0.0001)
    }

    @Test("Un trazo roto no revienta: devuelve lo que pudo leer")
    func trazoRoto() {
        #expect(TrazoSvg("").comandos.isEmpty)
        // Faltan coordenadas: se corta donde deja de entender.
        #expect(TrazoSvg("M4 9.6 L").comandos == [.mover(x: 4, y: 9.6)])
        // Una letra que no existe se ignora en vez de tirar la pantalla.
        #expect(TrazoSvg("M1 1 X9 9 L2 2").comandos.contains(.linea(x: 2, y: 2)))
    }

    @Test("Los cinco íconos de la barra se leen completos")
    func iconosDeLaBarra() {
        for pestana in ["M4 9.6 11 4l7 5.6v7.4a1.4 1.4 0 0 1-1.4 1.4H5.4A1.4 1.4 0 0 1 4 17V9.6z",
                        "M3 8.4 10 4.4l7 4M4.8 8.8v6.4M8.2 8.8v6.4M11.8 8.8v6.4M15.2 8.8v6.4M3.2 16.4h13.6",
                        "M3.6 7.4h11.8a1.6 1.6 0 0 1 1.6 1.6v6.2a1.6 1.6 0 0 1-1.6 1.6H5.2a1.6 1.6 0 0 1-1.6-1.6V7.4zM3.6 7.4 13.4 4.4v3M13.4 11.8h2.6",
                        "M5 16V9.4M11 16V5.4M17 16v-4",
                        "M4.6 5.8h12.8v11.4H4.6zM4.6 9.4h12.8M8 3.6v2.6M14 3.6v2.6"] {
            let t = TrazoSvg(pestana)
            #expect(!t.comandos.isEmpty)
            // Ningún ícono del boceto cabe en un solo comando: si sale uno, se leyó a medias.
            #expect(t.comandos.count > 1)
            // Y todas las coordenadas tienen que ser números reales, no NaN de una división mal.
            let sanas = t.comandos.allSatisfy { comando in
                switch comando {
                case let .mover(x, y), let .linea(x, y):
                    return x.isFinite && y.isFinite
                case let .curva(x1, y1, x2, y2, x, y):
                    return [x1, y1, x2, y2, x, y].allSatisfy(\.isFinite)
                case .cerrar:
                    return true
                }
            }
            #expect(sanas)
        }
    }
}
