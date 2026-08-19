import Testing
import Foundation
@testable import BolsiCore

/// Tests de la capa de plata. Corren en Windows con el toolchain de swift.org, que es lo que
/// hace que este trabajo no sea a ciegas mientras no haya Mac.
@Suite("Dinero")
struct DineroTests {

    @Test("El símbolo sale de la moneda")
    func simbolo() {
        #expect(Dinero.simbolo("PEN") == "S/")
        #expect(Dinero.simbolo("USD") == "US$")
        // Una moneda que el backend todavía no manda no debe romper la pantalla.
        #expect(Dinero.simbolo("EUR") == "S/")
    }

    @Test("Lee el punto decimal del backend sin importar la región del teléfono")
    func decimalConPunto() {
        #expect(Dinero.decimal("1234.56") == Decimal(string: "1234.56"))
        #expect(Dinero.decimal("0.05") == Decimal(string: "0.05"))
        // Un monto ilegible es cero, no un crash.
        #expect(Dinero.decimal("") == 0)
        #expect(Dinero.decimal("no-es-plata") == 0)
    }

    @Test("Formatea con coma de miles y dos decimales")
    func formato() {
        #expect(Dinero.numero(Decimal(string: "1234.5")!) == "1,234.50")
        #expect(Dinero.numero(Decimal(string: "42.9")!) == "42.90")
        #expect(Dinero.numero(Decimal(0)) == "0.00")
        #expect(Dinero.numero(Decimal(string: "15842.13")!) == "15,842.13")
        #expect(Dinero.numero(Decimal(string: "1000000")!) == "1,000,000.00")
    }

    @Test("Redondea a dos decimales, no trunca")
    func redondeo() {
        #expect(Dinero.numero(Decimal(string: "0.005")!) == "0.01")
        #expect(Dinero.numero(Decimal(string: "1.994")!) == "1.99")
        #expect(Dinero.numero(Decimal(string: "1.995")!) == "2.00")
    }

    @Test("Suma exacta: es la razón de usar Decimal y no Double")
    func sumaExacta() {
        // Con Double, 0.1 + 0.2 no da 0.3. Con Decimal sí, y por eso los montos
        // se suman acá y no en la vista.
        #expect(Dinero.sumar(["0.10", "0.20"]) == Decimal(string: "0.30"))
        // Diez centavos sumados cien veces tienen que dar diez soles clavados.
        let cien = Array(repeating: "0.10", count: 100)
        #expect(Dinero.sumar(cien) == Decimal(10))
        #expect(Dinero.numero(Dinero.sumar(cien)) == "10.00")
    }

    @Test("El monto con signo usa el menos tipográfico del boceto")
    func signo() {
        #expect(Dinero.montoConSigno("39.90", esIngreso: false, moneda: "PEN") == "− S/ 39.90")
        #expect(Dinero.montoConSigno("750.00", esIngreso: true, moneda: "PEN") == "+ S/ 750.00")
        // Una cuenta en dólares se rotula en dólares: fue un bug real del Historial.
        #expect(Dinero.montoConSigno("100.00", esIngreso: false, moneda: "USD") == "− US$ 100.00")
    }
}
