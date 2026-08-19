import Testing
import Foundation
@testable import BolsiCore

/// Tests de fechas e iniciales.
///
/// Las fechas se testean porque **un día de diferencia cambia el significado**: "vence hoy"
/// enciende el punto rojo de la campana y "vence mañana" no. Y porque este módulo corre en dos
/// plataformas: un formateador que mira el locale daría resultados distintos en la PC del dueño
/// y en su teléfono, y el modo de fallar sería el peor posible — una fecha corrida un día,
/// silenciosa.
@Suite("Fechas e iniciales")
struct FechasTests {

    private var calendario: Calendar {
        // Fijo y sin zona horaria de por medio: el test tiene que dar lo mismo en la PC y en el
        // runner de la nube, que está en otra zona.
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func dia(_ a: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = a; c.month = m; c.day = d
        return calendario.date(from: c)!
    }

    @Test("El día se escribe como lo espera el backend, con ceros")
    func formatoDelDia() {
        #expect(Fechas.dia(dia(2026, 8, 19), calendario: calendario) == "2026-08-19")
        // El relleno con ceros es lo que se rompe primero: "2026-8-9" no lo entiende el backend.
        #expect(Fechas.dia(dia(2026, 1, 5), calendario: calendario) == "2026-01-05")
        #expect(Fechas.dia(dia(2026, 12, 31), calendario: calendario) == "2026-12-31")
    }

    @Test("Lee tanto la fecha sola como el ISO completo")
    func leeLasDosFormas() {
        let corta = Fechas.fecha("2026-08-19", calendario: calendario)
        let larga = Fechas.fecha("2026-08-19T14:32:07.000Z", calendario: calendario)
        // El backend manda las dos formas según el campo. Depender de cuál manda cada uno es
        // exactamente el detalle que cambia sin avisar.
        #expect(corta == larga)
        #expect(corta == dia(2026, 8, 19))
    }

    @Test("Una fecha ilegible devuelve nil y no una fecha cualquiera")
    func fechaIlegible() {
        #expect(Fechas.fecha("", calendario: calendario) == nil)
        #expect(Fechas.fecha("ayer", calendario: calendario) == nil)
        #expect(Fechas.fecha("2026-13-01", calendario: calendario) == nil)
        #expect(Fechas.fecha("2026/08/19", calendario: calendario) == nil)
    }

    @Test("Los días que faltan: hoy es cero, ayer es negativo")
    func diasQueFaltan() {
        let hoy = dia(2026, 8, 19)
        // Este es el número del que depende el punto rojo: `<= 0` es "requiere acción".
        #expect(Fechas.diasHasta("2026-08-19", desde: hoy, calendario: calendario) == 0)
        #expect(Fechas.diasHasta("2026-08-18", desde: hoy, calendario: calendario) == -1)
        #expect(Fechas.diasHasta("2026-08-24", desde: hoy, calendario: calendario) == 5)
        // Cruzando el mes, que es donde una resta ingenua de días se equivoca.
        #expect(Fechas.diasHasta("2026-09-01", desde: hoy, calendario: calendario) == 13)
    }

    @Test("La hora no cambia el conteo de días")
    func laHoraNoCuenta() {
        // Un vencimiento es un día, no un instante. Si la hora contara, "vence hoy" dependería
        // de qué hora es en el teléfono.
        let hoyTarde = calendario.date(byAdding: .hour, value: 23, to: dia(2026, 8, 19))!
        #expect(Fechas.diasHasta("2026-08-19T00:00:00.000Z", desde: hoyTarde, calendario: calendario) == 0)
    }

    @Test("El primer día del mes")
    func primerDia() {
        #expect(Fechas.primerDiaDelMes(dia(2026, 8, 19), calendario: calendario) == dia(2026, 8, 1))
        #expect(Fechas.primerDiaDelMes(dia(2026, 1, 1), calendario: calendario) == dia(2026, 1, 1))
    }

    // MARK: - Iniciales

    @Test("Dos iniciales para el avatar")
    func dosIniciales() {
        #expect(Iniciales.dos("Víctor Marquina") == "VM")
        #expect(Iniciales.dos("Massimo Osti") == "MO")
        // Una sola palabra usa dos letras: con una sola el círculo queda desbalanceado.
        #expect(Iniciales.dos("Víctor") == "VÍ")
        #expect(Iniciales.dos("  Víctor   Jesús  Marquina ") == "VJ")
        #expect(Iniciales.dos("") == "?")
    }

    @Test("Una inicial para las suscripciones, y los emojis no cuentan")
    func unaInicial() {
        #expect(Iniciales.una("Netflix") == "N")
        #expect(Iniciales.una("Apple TV") == "A")
        // Varios nombres del mundo real arrancan con un emoji. Una inicial que sale "🎬" no es
        // una inicial: es un dibujo donde debía haber una letra.
        #expect(Iniciales.una("🎬 Netflix") == "N")
        #expect(Iniciales.dos("🎬 Netflix Premium") == "NP")
        #expect(Iniciales.una("") == "?")
    }

    // MARK: - Color desde el texto del backend

    @Test("Los colores del backend se leen en sus tres formas")
    func coloresCss() {
        #expect(ColorBoceto(css: "#3E8BFF") == ColorBoceto(0xFF3E8BFF))
        #expect(ColorBoceto(css: "3e8bff") == ColorBoceto(0xFF3E8BFF))
        // `#abc` es `#aabbcc`: cada dígito se duplica. Rellenar con ceros daría otro color.
        #expect(ColorBoceto(css: "#abc") == ColorBoceto(0xFFAABBCC))
        #expect(ColorBoceto(css: "#80FF0000") == ColorBoceto(0x80FF0000))
    }

    @Test("Un color ilegible devuelve nil, no un color por defecto")
    func colorIlegible() {
        // Devolver un color inventado en silencio pintaría un tramo de la barra de gastos con
        // el color de otra categoría. El dueño lee esa barra por color.
        #expect(ColorBoceto(css: "no-es-un-color") == nil)
        #expect(ColorBoceto(css: "") == nil)
        #expect(ColorBoceto(css: "#12345") == nil)
    }
}
