import SwiftUI
import BolsiCore

/// Traduce los tokens del boceto a SwiftUI. Es la única capa que conoce las dos cosas.
///
/// A propósito es delgada: los **valores** viven en `BolsiCore` (donde se testean en Windows) y
/// acá solo se convierten. Si un color se ve mal, el test dice si el número está mal o si es la
/// traducción — sin eso, cada duda de color termina en una captura de diez minutos.
extension Color {
    init(_ boceto: ColorBoceto) {
        self.init(
            .sRGB,
            red: boceto.rojo,
            green: boceto.verde,
            blue: boceto.azul,
            opacity: boceto.alfa
        )
    }
}

/// La paleta activa, según el tema del sistema.
///
/// El boceto define los dos juegos completos y sus `data-props` declaran `"theme": "dark"`, así
/// que **oscuro es el estado en que el dueño lo aprobó**. Acá se respeta el sistema, que es la
/// convención de iOS, y oscuro es lo que se ve en la mayoría de los teléfonos.
struct PaletaKey: EnvironmentKey {
    static let defaultValue = PaletaBoceto.oscura
}

extension EnvironmentValues {
    var paleta: PaletaBoceto {
        get { self[PaletaKey.self] }
        set { self[PaletaKey.self] = newValue }
    }
}

/// Envuelve la app y elige la paleta según el modo del sistema.
struct TemaBoceto<Contenido: View>: View {
    @Environment(\.colorScheme) private var esquema
    @ViewBuilder var contenido: Contenido

    var body: some View {
        let paleta = esquema == .dark ? PaletaBoceto.oscura : PaletaBoceto.clara
        contenido
            .environment(\.paleta, paleta)
            .background(Color(paleta.fondo).ignoresSafeArea())
            // El boceto usa `-apple-system` / SF Pro Display: en iOS es la fuente del sistema,
            // así que sale exacta y gratis. En Android hubo que empaquetar Inter como
            // equivalente libre.
            .tint(Color(paleta.acento))
    }
}

/// Las curvas del boceto como `Animation` de SwiftUI. Se traducen sin aproximar porque el
/// prototipo no usa física en ningún lado: son `cubic-bezier` con duración fija, que es
/// exactamente lo que hace `.timingCurve`.
extension Animation {
    static func bocetoEntrada(_ ms: Double = MovimientoBoceto.entradaMs) -> Animation {
        let c = MovimientoBoceto.entrada
        return .timingCurve(c.0, c.1, c.2, c.3, duration: ms / 1000)
    }

    static func bocetoEstandar(_ ms: Double = MovimientoBoceto.pulsacionMs) -> Animation {
        let c = MovimientoBoceto.estandar
        return .timingCurve(c.0, c.1, c.2, c.3, duration: ms / 1000)
    }

    static func bocetoRebote(_ ms: Double = MovimientoBoceto.pulsacionMs) -> Animation {
        let c = MovimientoBoceto.rebote
        return .timingCurve(c.0, c.1, c.2, c.3, duration: ms / 1000)
    }
}
