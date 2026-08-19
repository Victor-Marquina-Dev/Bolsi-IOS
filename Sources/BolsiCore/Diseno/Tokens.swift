import Foundation

/// Los tokens del BOCETO, **sin importar SwiftUI**.
///
/// Viven en el núcleo y no en la app por un motivo práctico: acá se pueden compilar y testear
/// en Windows. `BolsiApp` los traduce a `Color`/`Font` en una capa de veinte líneas, así que si
/// un valor está mal se ve en un test y no en una captura que tarda diez minutos en llegar.
///
/// Son los mismos valores que ya se auditaron al construir el Android (`ui/theme/Tokens.kt`):
/// **no se inventa ni un número**, cada uno sale de leer el prototipo.

/// Un color del boceto en `0xAARRGGBB`. Sin dependencia de UI para poder compararlo en un test.
public struct ColorBoceto: Sendable, Equatable, Hashable {
    public let argb: UInt32
    public init(_ argb: UInt32) { self.argb = argb }

    public var alfa: Double { Double((argb >> 24) & 0xFF) / 255 }
    public var rojo: Double { Double((argb >> 16) & 0xFF) / 255 }
    public var verde: Double { Double((argb >> 8) & 0xFF) / 255 }
    public var azul: Double { Double(argb & 0xFF) / 255 }

    /// El mismo color con otro alfa. El boceto lo hace todo el tiempo (`rgba(A, .14)`).
    public func conAlfa(_ nuevo: Double) -> ColorBoceto {
        let a = UInt32((max(0, min(1, nuevo)) * 255).rounded())
        return ColorBoceto((a << 24) | (argb & 0x00FFFFFF))
    }

    /// Espejo de `shade(hex)` del prototipo: cada canal por 0,62. Es la tinta de acento sobre
    /// fondo claro (en oscuro usa el color pleno).
    public func oscurecer(_ factor: Double = 0.62) -> ColorBoceto {
        func canal(_ desplazamiento: UInt32) -> UInt32 {
            let v = Double((argb >> desplazamiento) & 0xFF) * factor
            return UInt32(max(0, min(255, v.rounded())))
        }
        return ColorBoceto((argb & 0xFF000000) | (canal(16) << 16) | (canal(8) << 8) | canal(0))
    }
}

/// Los 17 colores del boceto, en sus dos temas.
public struct PaletaBoceto: Sendable {
    public let fondo, superficie, superficie2: ColorBoceto
    public let tinta, tinta2, tinta3, linea: ColorBoceto
    public let acento, rojo, verde: ColorBoceto
    public let barra, velo, tirador: ColorBoceto
    public let plataEntra, plataSale, pildoraEntra, pildoraSale: ColorBoceto
    public let esOscuro: Bool

    /// El acento del boceto: sus `data-props` ofrecen cuatro y el azul es el default, el que
    /// está aplicado en todas las capturas del prototipo.
    public static let acentoBoceto = ColorBoceto(0xFF3E8BFF)

    /// `vars` de `renderVals()` con `dark === true`. **Es el estado por defecto del boceto.**
    public static let oscura = PaletaBoceto(
        fondo: ColorBoceto(0xFF000000),
        superficie: ColorBoceto(0xFF1C1C1E),
        superficie2: ColorBoceto(0xFF2C2C2E),
        tinta: ColorBoceto(0xFFF5F6F8),
        tinta2: ColorBoceto(0xFF8E939B),
        tinta3: ColorBoceto(0xFF5A6069),
        linea: ColorBoceto(0x17FFFFFF),
        acento: acentoBoceto,
        rojo: ColorBoceto(0xFFFF453A),
        verde: ColorBoceto(0xFF32D74B),
        barra: ColorBoceto(0xD11C1C1E),
        velo: ColorBoceto(0x8C000000),
        tirador: ColorBoceto(0x59FFFFFF),
        plataEntra: ColorBoceto(0xFF32D74B),
        plataSale: ColorBoceto(0xFFFF453A),
        pildoraEntra: ColorBoceto(0x3332D74B),
        pildoraSale: ColorBoceto(0x33FF453A),
        esOscuro: true
    )

    /// `vars` con `dark === false`.
    public static let clara = PaletaBoceto(
        fondo: ColorBoceto(0xFFF3F5F7),
        superficie: ColorBoceto(0xFFFFFFFF),
        superficie2: ColorBoceto(0xFFF3F5F7),
        tinta: ColorBoceto(0xFF2E3947),
        tinta2: ColorBoceto(0xFF8A94A2),
        tinta3: ColorBoceto(0xFFB4BCC7),
        linea: ColorBoceto(0x142E3947),
        acento: acentoBoceto,
        rojo: ColorBoceto(0xFFFF3B30),
        verde: ColorBoceto(0xFF34C759),
        barra: ColorBoceto(0xDBFFFFFF),
        velo: ColorBoceto(0x9EF3F5F7),
        tirador: ColorBoceto(0x592E3947),
        plataEntra: ColorBoceto(0xFF0F6E33),
        plataSale: ColorBoceto(0xFFC0392B),
        pildoraEntra: ColorBoceto(0x210F6E33),
        pildoraSale: ColorBoceto(0x1FC0392B),
        esOscuro: false
    )

    /// El par que el boceto repite en cada chip: relleno translúcido del acento.
    public func acentoSuave(oscuro: Double = 0.20, claro: Double = 0.11) -> ColorBoceto {
        acento.conAlfa(esOscuro ? oscuro : claro)
    }

    /// Tinta de acento: pleno en oscuro, oscurecido en claro (`dark ? A : shade(A)`).
    public var acentoTinta: ColorBoceto { esOscuro ? acento : acento.oscurecer() }
}

/// Radios, contados sobre el template del boceto. Los nombres dicen **dónde** se usa cada uno.
public enum RadioBoceto {
    public static let tarjeta = 22.0
    public static let tarjetaChica = 20.0
    public static let tarjetaGrande = 26.0
    public static let cuenta = 24.0
    public static let chip = 16.0
    public static let chipChico = 13.0
    public static let marca = 11.0
    public static let pildora = 7.0
    public static let nav = 26.0
    public static let pastilla = 18.0
    public static let hoja = 28.0
    public static let barra = 4.0
}

/// Medidas de layout. El teléfono del prototipo mide 393 × 852 con el contenido a
/// `padding: 0 16px 110px`.
public enum EspacioBoceto {
    public static let pantalla = 16.0
    public static let colaNav = 110.0
    public static let entreTarjetas = 10.0
    public static let entreCeldas = 8.0
    public static let tarjeta = 14.0
    public static let navAlto = 62.0
    public static let navLateral = 12.0
    public static let navAbajo = 24.0
    public static let navPadding = 6.0
    public static let pastillaInset = 5.0
}

/// Curvas y duraciones. El boceto **no usa física en ningún lado**: todo es `cubic-bezier` con
/// duración fija, que se traduce sin aproximar.
public enum MovimientoBoceto {
    /// `cubic-bezier(.22,1,.36,1)` — la curva de casi todo: entradas, hojas, barras.
    public static let entrada = (0.22, 1.0, 0.36, 1.0)
    /// `cubic-bezier(.4,0,.2,1)` — la estándar.
    public static let estandar = (0.4, 0.0, 0.2, 1.0)
    /// `cubic-bezier(.34,1.56,.64,1)` — con rebote.
    public static let rebote = (0.34, 1.56, 0.64, 1.0)

    public static let entradaMs = 300.0
    public static let fundidoMs = 280.0
    public static let hojaMs = 300.0
    public static let popMs = 240.0
    public static let acordeonMs = 280.0
    public static let pulsacionMs = 200.0
    public static let tinteMs = 200.0
    public static let progresoMs = 800.0
    public static let navMs = 440.0
    public static let navSquashMs = 120.0
    public static let respirarMs = 4000.0
    public static let pingMs = 3200.0

    /// `stretch = 1 + Math.min(d, 3) * 0.16`, con `d` = distancia en pestañas.
    public static func estiron(distancia: Int) -> Double {
        1 + Double(min(distancia, 3)) * 0.16
    }
}

/// Tamaños de texto. En iOS la familia del boceto (`-apple-system`, SF Pro Display) es la del
/// sistema: no hace falta empaquetar Inter como en Android, sale gratis y exacta.
public enum TextoBoceto {
    public static let saldo = 30.0
    public static let saldoTracking = -1.1
    public static let montoGrande = 27.0
    public static let titulo = 18.0
    public static let header = 17.0
    public static let fila = 14.5
    public static let cuerpo = 14.0
    public static let secundario = 12.5
    public static let chip = 11.5
    public static let eyebrow = 10.5
    public static let eyebrowTracking = 1.2
    public static let nav = 9.5
}
