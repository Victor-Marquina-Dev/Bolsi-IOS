import Testing
import Foundation
@testable import BolsiCore

/// Tests de las metas de Inicio.
///
/// Lo que se prueba acá no es formato: son las tres decisiones que la tarjeta esconde —qué pasa
/// con una meta pasada de largo, con una alcanzada justo, y cuáles de diez metas se muestran.
@Suite("Metas de Inicio")
struct MetaUiTests {

    private func meta(
        _ id: String,
        nombre: String = "Viaje",
        objetivo: String = "1000.00",
        actual: String = "600.00",
        moneda: Moneda = "PEN",
        porcentaje: Double = 60
    ) -> Meta {
        Meta(
            id: id,
            nombre: nombre,
            montoObjetivo: objetivo,
            montoActual: actual,
            moneda: moneda,
            fechaLimite: "2026-12-31",
            porcentajeAlcanzado: porcentaje
        )
    }

    @Test("Una meta a medias: montos, porcentaje y lo que falta")
    func metaAMedias() {
        let ui = MetaUi.de(meta("m1"), posicion: 0)
        #expect(ui.inicial == "V")
        #expect(ui.ahorrado == "S/ 600.00")
        #expect(ui.objetivo == "S/ 1,000.00")
        #expect(ui.porcentaje == 60)
        #expect(ui.fraccion == 0.6)
        #expect(ui.falta == "Faltan S/ 400.00")
        #expect(ui.color == MetaUi.colores[0])
    }

    @Test("Pasada de largo: el número muestra el 140, el dibujo se recorta al 100")
    func metaPasada() {
        let ui = MetaUi.de(
            meta("m2", objetivo: "1000.00", actual: "1400.00", porcentaje: 140),
            posicion: 0
        )
        // El dueño ahorró de más y merece verlo.
        #expect(ui.porcentaje == 140)
        // Pero un anillo no puede dar más de una vuelta y una barra al 140% se sale de la
        // tarjeta: el dibujo se recorta, el número no.
        #expect(ui.fraccion == 1.0)
        // Y no se dice "Faltan −S/ 400.00", que es lo que saldría de restar sin mirar.
        #expect(ui.falta == nil)
    }

    @Test("Alcanzada justo: no dice 'Faltan S/ 0.00'")
    func metaAlcanzada() {
        let ui = MetaUi.de(
            meta("m3", objetivo: "1000.00", actual: "1000.00", porcentaje: 100),
            posicion: 0
        )
        #expect(ui.porcentaje == 100)
        #expect(ui.fraccion == 1.0)
        #expect(ui.falta == nil)
    }

    @Test("Inicio muestra las tres más avanzadas, de la moneda principal")
    func lasTresMasAvanzadas() {
        let metas = [
            meta("a", nombre: "Auto", porcentaje: 10),
            meta("b", nombre: "Bici", porcentaje: 90),
            meta("c", nombre: "Casa", porcentaje: 50),
            meta("d", nombre: "Dolares", moneda: "USD", porcentaje: 99),
            meta("e", nombre: "Escuela", porcentaje: 70),
        ]
        let visibles = MetaUi.paraInicio(metas, moneda: "PEN")

        // Por avance y no por orden de creación: las que están por cerrarse son las que uno
        // quiere mirar. Y la de dólares queda fuera aunque sea la más avanzada — Inicio muestra
        // la moneda principal.
        #expect(visibles.map(\.id) == ["b", "e", "c"])
        // El color va por posición en la lista visible, como en el boceto: el primero azul.
        #expect(visibles[0].color == MetaUi.colores[0])
        #expect(visibles[1].color == MetaUi.colores[1])
    }

    @Test("Sin metas en la moneda principal, la sección queda vacía")
    func sinMetas() {
        let soloDolares = [meta("d", moneda: "USD")]
        #expect(MetaUi.paraInicio(soloDolares, moneda: "PEN").isEmpty)
        #expect(MetaUi.paraInicio([], moneda: "PEN").isEmpty)
    }

    @Test("Un objetivo en cero no rompe nada")
    func objetivoEnCero() {
        // Pasa con una meta recién creada mal cargada. El backend manda el porcentaje, así que
        // acá no hay división: la protección es no inventar una.
        let ui = MetaUi.de(
            meta("z", objetivo: "0.00", actual: "0.00", porcentaje: 0),
            posicion: 0
        )
        #expect(ui.fraccion == 0)
        #expect(ui.porcentaje == 0)
        #expect(ui.falta == nil)
    }

    @Test("Los colores se reparten en ciclo y no se salen de la lista")
    func coloresEnCiclo() {
        let novena = MetaUi.de(meta("n"), posicion: 8)
        #expect(novena.color == MetaUi.colores[0])
        let vigesima = MetaUi.de(meta("v"), posicion: 19)
        #expect(vigesima.color == MetaUi.colores[19 % MetaUi.colores.count])
    }
}
