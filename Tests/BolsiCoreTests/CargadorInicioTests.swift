import Testing
import Foundation
@testable import BolsiCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Tests de la composición de Inicio: **la aritmética sobre la plata del dueño**.
///
/// Es la parte del proyecto donde un error no se ve. Un color mal puesto salta en la primera
/// captura; un saldo que suma una tarjeta de crédito se ve perfectamente bien y está mal. Estos
/// tests existen para eso, y corren en Windows sin backend ni red.
///
/// Las cuatro reglas que se verifican salieron de construir el Android y las aprobó el dueño
/// ahí. Si el iPhone y el Android muestran distinto para la misma cuenta, uno miente.
@Suite("Inicio con datos del backend")
struct CargadorInicioTests {

    /// Un backend de mentira que responde por ruta.
    private final class Servidor: @unchecked Sendable {
        /// Ruta (sufijo) → JSON. Lo que no esté acá responde una lista vacía.
        var cuerpos: [String: String] = [:]
        /// Ruta (sufijo) → código HTTP, para simular endpoints caídos.
        var codigos: [String: Int] = [:]

        func transporte() -> Transporte {
            { [self] peticion in
                let ruta = peticion.url?.path ?? ""
                let cuerpo = cuerpos.first { ruta.hasSuffix($0.key) }?.value ?? #"{"data":[]}"#
                let codigo = codigos.first { ruta.hasSuffix($0.key) }?.value ?? 200
                let http = HTTPURLResponse(
                    url: peticion.url!,
                    statusCode: codigo,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (Data(cuerpo.utf8), http)
            }
        }
    }

    private func cargador(_ servidor: Servidor) -> CargadorInicio {
        let cliente = ClienteApi(
            base: URL(string: "http://192.168.0.101:4000/api")!,
            sesion: SesionEnMemoria(token: "t"),
            transporte: servidor.transporte()
        )
        return CargadorInicio(api: ApiBolsi(cliente: cliente))
    }

    /// Una cuenta con los campos mínimos, para no repetir veinte claves en cada test.
    private func cuentaJson(
        id: String,
        tipo: String,
        moneda: String,
        saldo: String
    ) -> String {
        """
        {"id":"\(id)","nombre":"Cuenta \(id)","tipo":"\(tipo)","banco":null,"moneda":"\(moneda)",
        "saldoInicial":"0.00","saldoActual":"\(saldo)","bolsillitoId":null,"lineaCredito":null,
        "diaCierre":null,"diaPago":null,"deudaActual":null,"disponible":null}
        """
    }

    private func esperarExito(
        _ resultado: ResultadoApi<EstadoInicio>,
        _ donde: String = #function
    ) -> EstadoInicio? {
        guard case let .exito(estado) = resultado else {
            Issue.record("se esperaba exito en \(donde), llego \(resultado)")
            return nil
        }
        return estado
    }

    // MARK: - Regla 1: las tarjetas de crédito no entran

    @Test("El saldo total no descuenta la deuda de una tarjeta")
    func tarjetaFueraDelSaldo() async {
        let s = Servidor()
        s.cuerpos["/cuentas"] = """
        {"data":[
          \(cuentaJson(id: "a", tipo: "corriente", moneda: "PEN", saldo: "1000.00")),
          \(cuentaJson(id: "b", tipo: "credito", moneda: "PEN", saldo: "-500.00"))
        ]}
        """

        let estado = esperarExito(await cargador(s).cargar(nombre: "Víctor Marquina"))
        // El saldo responde "cuánto tengo disponible". La deuda de la tarjeta se muestra aparte,
        // en Cuentas: descontarla acá contestaría otra pregunta.
        #expect(estado?.saldo == Decimal(string: "1000.00"))
    }

    @Test("Las tarjetas se excluyen ANTES de elegir la moneda, no solo al sumar")
    func tarjetaFueraAntesDeLaMoneda() async {
        let s = Servidor()
        // Dos tarjetas en dólares y una cuenta de verdad en soles. Si las tarjetas contaran para
        // elegir la moneda, ganaría USD (2 contra 1) y el dueño vería el saldo de sus tarjetas
        // en vez del de su plata.
        s.cuerpos["/cuentas"] = """
        {"data":[
          \(cuentaJson(id: "t1", tipo: "credito", moneda: "USD", saldo: "-300.00")),
          \(cuentaJson(id: "t2", tipo: "credito", moneda: "USD", saldo: "-700.00")),
          \(cuentaJson(id: "e", tipo: "efectivo", moneda: "PEN", saldo: "300.00"))
        ]}
        """

        let estado = esperarExito(await cargador(s).cargar(nombre: "Víctor"))
        #expect(estado?.moneda == "PEN")
        #expect(estado?.saldo == Decimal(string: "300.00"))
        // Y las tarjetas tampoco aparecen en la línea de otras monedas: no son plata que esté
        // en otro lado, son deuda.
        #expect(estado?.otrasMonedas == nil)
    }

    // MARK: - Regla 2: nunca se suman dos monedas

    @Test("Las cuentas en otra moneda se avisan, no se suman")
    func otrasMonedasSeAvisan() async {
        let s = Servidor()
        s.cuerpos["/cuentas"] = """
        {"data":[
          \(cuentaJson(id: "a", tipo: "ahorros", moneda: "PEN", saldo: "1000.00")),
          \(cuentaJson(id: "b", tipo: "ahorros", moneda: "PEN", saldo: "500.00")),
          \(cuentaJson(id: "c", tipo: "ahorros", moneda: "USD", saldo: "200.00"))
        ]}
        """

        let estado = esperarExito(await cargador(s).cargar(nombre: "Víctor"))
        // 1500, no 1700: no hay tipo de cambio en el sistema y sumarlas inventaría uno.
        #expect(estado?.saldo == Decimal(string: "1500.00"))
        #expect(estado?.otrasMonedas == "+ US$ 200.00 en otras cuentas")
    }

    @Test("Con una sola moneda no aparece ninguna línea extra")
    func unaSolaMonedaNoDiceNada() async {
        let s = Servidor()
        s.cuerpos["/cuentas"] = """
        {"data":[\(cuentaJson(id: "a", tipo: "ahorros", moneda: "PEN", saldo: "1000.00"))]}
        """
        let estado = esperarExito(await cargador(s).cargar(nombre: "Víctor"))
        // Quien no tiene el problema no debe ver texto nuevo en su pantalla.
        #expect(estado?.otrasMonedas == nil)
    }

    // MARK: - Regla 3: no se inventa un cero

    @Test("Sin resumen del mes, ingresos y gastos quedan en nil — no en cero")
    func sinResumenNoHayCero() async {
        let s = Servidor()
        s.cuerpos["/cuentas"] = """
        {"data":[\(cuentaJson(id: "a", tipo: "ahorros", moneda: "PEN", saldo: "1000.00"))]}
        """
        s.cuerpos["/reportes/resumen"] = #"{"data":[]}"#

        let estado = esperarExito(await cargador(s).cargar(nombre: "Víctor"))
        // Un cero acá dice "este mes no gastaste nada", que es una afirmación falsa. `nil` dice
        // "no lo sé", que es la verdad.
        #expect(estado?.ingresosMes == nil)
        #expect(estado?.gastosMes == nil)
        #expect(estado?.netoMes == nil)
        #expect(estado?.avisoOtraMoneda == nil)
    }

    @Test("Si los movimientos del mes fueron en otra moneda, se explica por qué falta el pill")
    func movimientosEnOtraMoneda() async {
        let s = Servidor()
        s.cuerpos["/cuentas"] = """
        {"data":[\(cuentaJson(id: "a", tipo: "ahorros", moneda: "PEN", saldo: "1000.00"))]}
        """
        s.cuerpos["/reportes/resumen"] = """
        {"data":[{"moneda":"USD","ingresos":"100.00","gastos":"40.00","neto":"60.00"}]}
        """

        let estado = esperarExito(await cargador(s).cargar(nombre: "Víctor"))
        #expect(estado?.ingresosMes == nil)
        // Dejarlo en blanco sin explicación fue justo lo que el Android tuvo que arreglar
        // después: se veía un hueco y no había forma de saber que era por la moneda.
        #expect(estado?.avisoOtraMoneda?.contains("USD") == true)
    }

    @Test("Con resumen en la moneda del saldo, el neto sale de la resta")
    func netoDelMes() async {
        let s = Servidor()
        s.cuerpos["/cuentas"] = """
        {"data":[\(cuentaJson(id: "a", tipo: "ahorros", moneda: "PEN", saldo: "1000.00"))]}
        """
        s.cuerpos["/reportes/resumen"] = """
        {"data":[{"moneda":"PEN","ingresos":"2500.50","gastos":"1200.25","neto":"1300.25"}]}
        """

        let estado = esperarExito(await cargador(s).cargar(nombre: "Víctor"))
        #expect(estado?.ingresosMes == Decimal(string: "2500.50"))
        #expect(estado?.gastosMes == Decimal(string: "1200.25"))
        // Exacto, no aproximado: con `Double` esta resta da 1300.2500000000002.
        #expect(estado?.netoMes == Decimal(string: "1300.25"))
    }

    // MARK: - Regla 4: el punto de la campana

    @Test("Un pendiente vencido enciende la campana; uno futuro no")
    func campanaSoloConLoVencido() async {
        let hoy = Date(timeIntervalSince1970: 1_786_000_000) // un día cualquiera, fijo
        let calendario = Calendar.current
        let ayer = Fechas.dia(calendario.date(byAdding: .day, value: -1, to: hoy)!)
        let enCincoDias = Fechas.dia(calendario.date(byAdding: .day, value: 5, to: hoy)!)

        func conPendiente(_ vencimiento: String, estado: String) -> Servidor {
            let s = Servidor()
            s.cuerpos["/cuentas"] = """
            {"data":[\(cuentaJson(id: "a", tipo: "ahorros", moneda: "PEN", saldo: "10.00"))]}
            """
            s.cuerpos["/pendientes"] = """
            {"data":[{"id":"p","tipo":"pago","descripcion":"Alquiler","monto":"800.00",
            "moneda":"PEN","vencimiento":"\(vencimiento)","estado":"\(estado)"}]}
            """
            return s
        }

        let vencido = esperarExito(await cargador(conPendiente(ayer, estado: "pendiente")).cargar(nombre: "V", hoy: hoy))
        #expect(vencido?.hayAvisos == true)

        let futuro = esperarExito(await cargador(conPendiente(enCincoDias, estado: "pendiente")).cargar(nombre: "V", hoy: hoy))
        // "Falta poco" no es "requiere acción": eso vive en la lista de próximos, no en el punto.
        #expect(futuro?.hayAvisos == false)

        let resuelto = esperarExito(await cargador(conPendiente(ayer, estado: "resuelto")).cargar(nombre: "V", hoy: hoy))
        #expect(resuelto?.hayAvisos == false)
    }

    // MARK: - Degradación por partes

    @Test("Un endpoint de reportes caído no tapa el saldo")
    func reportesCaidoNoTumbaElSaldo() async {
        let s = Servidor()
        s.cuerpos["/cuentas"] = """
        {"data":[\(cuentaJson(id: "a", tipo: "ahorros", moneda: "PEN", saldo: "1234.56"))]}
        """
        s.codigos["/reportes/resumen"] = 500
        s.codigos["/reportes/gastos-por-categoria"] = 500
        s.codigos["/suscripciones"] = 500

        let estado = esperarExito(await cargador(s).cargar(nombre: "Víctor"))
        // El saldo es el dato que el dueño vino a ver. Un reporte caído no puede costárselo.
        #expect(estado?.saldo == Decimal(string: "1234.56"))
        #expect(estado?.ingresosMes == nil)
        #expect(estado?.gastoPorCategoria.isEmpty == true)
    }

    @Test("Sin cuentas no hay pantalla: la falla se propaga")
    func cuentasCaidoEsFalla() async {
        let s = Servidor()
        s.codigos["/cuentas"] = 500
        s.cuerpos["/cuentas"] = #"{"error":{"codigo":"INTERNO","mensaje":"Base de datos caída"}}"#

        guard case let .falla(mensaje) = await cargador(s).cargar(nombre: "Víctor") else {
            Issue.record("sin cuentas no hay saldo ni moneda: tiene que ser falla")
            return
        }
        #expect(mensaje == "Base de datos caída")
    }

    @Test("Un 401 se propaga como sinSesion, no como error")
    func sesionCaida() async {
        let s = Servidor()
        s.codigos["/cuentas"] = 401
        guard case .sinSesion = await cargador(s).cargar(nombre: "Víctor") else {
            Issue.record("un 401 tiene que llegar como sinSesion para volver al login")
            return
        }
    }

    // MARK: - Categorías y suscripciones

    @Test("El color de la categoría se lee del backend; uno ilegible no borra el gasto")
    func coloresDeCategorias() async {
        let s = Servidor()
        s.cuerpos["/cuentas"] = """
        {"data":[\(cuentaJson(id: "a", tipo: "ahorros", moneda: "PEN", saldo: "10.00"))]}
        """
        s.cuerpos["/reportes/gastos-por-categoria"] = """
        {"data":[
          {"categoriaId":"c1","categoriaNombre":"Comida","categoriaColor":"#3E8BFF",
           "categoriaEmoji":"🍔","moneda":"PEN","total":"120.00"},
          {"categoriaId":"c2","categoriaNombre":"Roto","categoriaColor":"no-es-un-color",
           "categoriaEmoji":"❓","moneda":"PEN","total":"80.00"},
          {"categoriaId":"c3","categoriaNombre":"En dólares","categoriaColor":"#FF3B30",
           "categoriaEmoji":"💵","moneda":"USD","total":"50.00"}
        ]}
        """

        let estado = esperarExito(await cargador(s).cargar(nombre: "Víctor"))
        // La de otra moneda queda fuera: la barra es del gasto en la moneda del saldo.
        #expect(estado?.gastoPorCategoria.count == 2)
        #expect(estado?.gastoPorCategoria.first?.color == ColorBoceto(0xFF3E8BFF))
        // El color ilegible no puede desaparecer el monto: 80 soles gastados siguen siendo parte
        // del mes, y sacarlos dejaría una barra cuyo total no cierra.
        #expect(estado?.gastoPorCategoria.last?.monto == Decimal(string: "80.00"))
    }

    @Test("El carrusel muestra cuatro suscripciones activas y cuenta el resto")
    func suscripcionesDelCarrusel() async {
        let s = Servidor()
        s.cuerpos["/cuentas"] = """
        {"data":[\(cuentaJson(id: "a", tipo: "ahorros", moneda: "PEN", saldo: "10.00"))]}
        """
        func sus(_ id: String, _ nombre: String, activa: Bool) -> String {
            """
            {"id":"\(id)","nombre":"\(nombre)","monto":"30.00","moneda":"PEN","diaPago":5,
            "cuentaId":"a","categoriaId":"c","color":"#3E8BFF","emoji":"📺","activa":\(activa)}
            """
        }
        s.cuerpos["/suscripciones"] = """
        {"data":[
          \(sus("1", "Netflix", activa: true)),
          \(sus("2", "Spotify", activa: true)),
          \(sus("3", "Disney+", activa: true)),
          \(sus("4", "Max", activa: true)),
          \(sus("5", "YouTube", activa: true)),
          \(sus("6", "Apple TV", activa: true)),
          \(sus("7", "Pausada", activa: false))
        ]}
        """

        let estado = esperarExito(await cargador(s).cargar(nombre: "Víctor"))
        #expect(estado?.inicialesSuscripciones == ["N", "S", "D", "M"])
        // Seis activas menos las cuatro que se ven. La pausada no cuenta: no cobra.
        #expect(estado?.suscripcionesRestantes == 2)
    }

    @Test("Las iniciales del avatar salen del nombre de verdad")
    func inicialesDelAvatar() async {
        let s = Servidor()
        s.cuerpos["/cuentas"] = #"{"data":[]}"#
        let estado = esperarExito(await cargador(s).cargar(nombre: "Víctor Marquina"))
        #expect(estado?.iniciales == "VM")
        // Sin cuentas la moneda cae a PEN y el saldo a cero. Acá el cero SÍ es cierto: no hay
        // ninguna cuenta, no es un dato que falte.
        #expect(estado?.moneda == "PEN")
        #expect(estado?.saldo == 0)
    }
}
