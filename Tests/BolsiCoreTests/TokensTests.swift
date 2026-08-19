import Testing
@testable import BolsiCore

/// Los tokens llevan test porque en este entorno son lo único del diseño que se puede
/// verificar sin una Mac. Un hex mal tipeado acá se paga en una captura que tarda diez
/// minutos en volver de la nube.
@Suite("Tokens del boceto")
struct TokensTests {

    @Test("El acento es el azul por defecto del prototipo")
    func acento() {
        #expect(PaletaBoceto.acentoBoceto.argb == 0xFF3E8BFF)
        #expect(PaletaBoceto.oscura.acento == PaletaBoceto.clara.acento)
    }

    @Test("Descompone el color en sus canales")
    func canales() {
        let azul = ColorBoceto(0xFF3E8BFF)
        #expect(azul.alfa == 1.0)
        #expect(abs(azul.rojo - 62.0 / 255) < 0.0001)
        #expect(abs(azul.verde - 139.0 / 255) < 0.0001)
        #expect(azul.azul == 1.0)
    }

    @Test("conAlfa cambia solo la opacidad")
    func alfa() {
        let tenue = ColorBoceto(0xFF3E8BFF).conAlfa(0.14)
        #expect(tenue.argb & 0x00FFFFFF == 0x3E8BFF)
        // 0,14 × 255 = 35,7 → 36 = 0x24
        #expect((tenue.argb >> 24) & 0xFF == 0x24)
    }

    @Test("oscurecer es el shade() del boceto: cada canal por 0,62")
    func shade() {
        let oscurecido = ColorBoceto(0xFF3E8BFF).oscurecer()
        // 62×0,62 = 38,44 → 38 ; 139×0,62 = 86,18 → 86 ; 255×0,62 = 158,1 → 158
        #expect(oscurecido.argb == 0xFF26569E)
    }

    @Test("La tinta de acento es plena en oscuro y oscurecida en claro")
    func acentoTinta() {
        #expect(PaletaBoceto.oscura.acentoTinta == PaletaBoceto.acentoBoceto)
        #expect(PaletaBoceto.clara.acentoTinta == PaletaBoceto.acentoBoceto.oscurecer())
    }

    @Test("El tema oscuro tiene fondo negro puro y el claro el gris del prototipo")
    func fondos() {
        #expect(PaletaBoceto.oscura.fondo.argb == 0xFF000000)
        #expect(PaletaBoceto.clara.fondo.argb == 0xFFF3F5F7)
        #expect(PaletaBoceto.oscura.esOscuro)
        #expect(!PaletaBoceto.clara.esOscuro)
    }

    @Test("El verde de ingreso del tema claro es el oscuro, para que se lea sobre blanco")
    func plata() {
        // El boceto no usa `--green` para los montos en claro: usa un verde más oscuro.
        #expect(PaletaBoceto.clara.plataEntra.argb == 0xFF0F6E33)
        #expect(PaletaBoceto.clara.verde.argb == 0xFF34C759)
        #expect(PaletaBoceto.clara.plataEntra != PaletaBoceto.clara.verde)
    }

    @Test("El estirón de la pastilla del nav topa a los 3 saltos")
    func estiron() {
        #expect(MovimientoBoceto.estiron(distancia: 0) == 1.0)
        #expect(abs(MovimientoBoceto.estiron(distancia: 1) - 1.16) < 0.0001)
        #expect(abs(MovimientoBoceto.estiron(distancia: 3) - 1.48) < 0.0001)
        #expect(MovimientoBoceto.estiron(distancia: 4) == MovimientoBoceto.estiron(distancia: 3))
    }
}
