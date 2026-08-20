import Foundation

/// Arma el `EstadoInicio` con datos de verdad, pidiéndolos al backend.
///
/// Es el hermano del `Maqueta.inicio`: la pantalla recibe el mismo tipo y no se entera de dónde
/// salió. Vive en `BolsiCore` y no en la app por una razón concreta — **acá hay aritmética sobre
/// plata**, y esa aritmética se testea en Windows con el transporte de mentira. Metida en una
/// vista de SwiftUI no habría forma de verificarla sin una Mac.
///
/// ## Las reglas no son mías
///
/// Las cuatro reglas de abajo salieron de construir el Android y las aprobó el dueño ahí. Se
/// replican **tal cual** porque las dos apps miran la misma plata: si el iPhone y el Android
/// muestran saldos distintos para la misma cuenta, uno de los dos está mintiendo y no hay forma
/// de saber cuál.
///
/// 1. **Las tarjetas de crédito no entran en el saldo total.** Ese número responde "cuánto
///    tengo disponible" y nunca debe descontar lo que se debe en una tarjeta; la deuda se
///    muestra aparte. Y se excluyen **antes** de calcular la moneda dominante: si no, alguien
///    cuya única cuenta en dólares fuera una tarjeta vería "S/ 0.00" en lugar del saldo de sus
///    cuentas reales.
/// 2. **Nunca se suman dos monedas** y no hay tipo de cambio en el sistema. Las otras monedas se
///    avisan en una línea aparte, sin sumarse.
/// 3. **El pill de ingresos/gastos usa la misma moneda que el saldo.** Si el resumen del mes no
///    trae esa moneda, el pill queda vacío: no se inventa un cero.
/// 4. **El punto de la campana** se enciende con pendientes vencidos o que vencen hoy.
public struct CargadorInicio: Sendable {

    private let api: ApiBolsi

    public init(api: ApiBolsi) {
        self.api = api
    }

    /// Pide todo y compone la pantalla.
    ///
    /// **Solo las cuentas pueden tumbar la carga.** Sin cuentas no hay saldo ni moneda, así que
    /// no hay pantalla. Todo lo demás —resumen, categorías, suscripciones, pendientes— falla por
    /// separado y se degrada solo en su pedazo: es el mismo reparto que el Android
    /// (`SaldoHeroViewModel`: "dos fuentes de datos, dos fallas posibles por separado"). Sin
    /// esto, un endpoint de reportes caído dejaría al dueño sin ver su saldo, que es el dato que
    /// vino a ver.
    public func cargar(
        nombre: String,
        hoy: Date = Date(),
        calendario: Calendar = .current
    ) async -> ResultadoApi<EstadoInicio> {

        let desde = Fechas.dia(Fechas.primerDiaDelMes(hoy, calendario: calendario), calendario: calendario)
        let hasta = Fechas.dia(hoy, calendario: calendario)

        // En paralelo: son cinco viajes independientes por WiFi de casa y en serie se notan.
        async let cuentasPedido = api.cuentas()
        async let resumenPedido = api.resumen(desde: desde, hasta: hasta)
        async let categoriasPedido = api.gastosPorCategoria(desde: desde, hasta: hasta)
        async let suscripcionesPedido = api.suscripciones()
        async let pendientesPedido = api.pendientes()
        async let metasPedido = api.metas()

        let cuentas: [Cuenta]
        switch await cuentasPedido {
        case let .exito(lista): cuentas = lista
        case let .falla(mensaje): return .falla(mensaje)
        case .sinSesion: return .sinSesion
        }

        // Regla 1: fuera las tarjetas, y antes de mirar la moneda.
        let cuentasSaldo = cuentas.filter { !$0.esCredito }
        let moneda = Reglas.monedaDominante(cuentasSaldo)
        let saldo = Dinero.sumar(cuentasSaldo.filter { $0.moneda == moneda }.map(\.saldoActual))

        // Regla 3: el pill solo si el resumen trae la moneda del saldo.
        var ingresos: Decimal?
        var gastos: Decimal?
        var avisoOtraMoneda: String?
        if case let .exito(filas) = await resumenPedido {
            if let fila = filas.first(where: { $0.moneda == moneda }) {
                ingresos = Dinero.decimal(fila.ingresos)
                gastos = Dinero.decimal(fila.gastos)
            } else if let otra = filas.first(where: { $0.moneda != moneda }) {
                // Hubo movimientos, pero en otra moneda. Dejarlo en blanco sin explicar por qué
                // fue justo el problema que el Android tuvo que arreglar después.
                avisoOtraMoneda = "Hubo movimientos en \(otra.moneda) este mes, no incluidos aquí"
            }
        }

        var porciones: [PorcionCategoria] = []
        if case let .exito(filas) = await categoriasPedido {
            porciones = filas
                .filter { $0.moneda == moneda }
                .map { fila in
                    PorcionCategoria(
                        id: fila.categoriaId,
                        nombre: fila.categoriaNombre,
                        // Un color ilegible no puede tirar la categoría afuera: el monto sigue
                        // siendo parte del gasto del mes, y desaparecerlo de la barra dejaría un
                        // total que no cierra. Se pinta gris y se ve que le falta color.
                        color: ColorBoceto(css: fila.categoriaColor) ?? ColorBoceto(0xFF8A8A8E),
                        monto: Dinero.decimal(fila.total)
                    )
                }
        }

        var inicialesSuscripciones: [String] = []
        var restantes = 0
        if case let .exito(lista) = await suscripcionesPedido {
            // Solo las activas: una pausada no cobra, así que tampoco tiene por qué aparecer en
            // el carrusel de "lo que se te viene".
            let activas = lista.filter(\.activa)
            inicialesSuscripciones = activas.prefix(4).map { Iniciales.una($0.nombre) }
            restantes = max(0, activas.count - 4)
        }

        // Regla 4. Falta la otra mitad de lo que el Android considera "atención": los
        // presupuestos excedidos. El endpoint de presupuestos todavía no está en `ApiBolsi`, y
        // se anota acá en vez de dejar el punto rojo pareciendo completo.
        var hayAvisos = false
        if case let .exito(lista) = await pendientesPedido {
            hayAvisos = lista.contains { pendiente in
                guard pendiente.estado != "resuelto" else { return false }
                // Fecha ilegible se descarta, no se asume urgente.
                guard let dias = Fechas.diasHasta(pendiente.vencimiento, desde: hoy, calendario: calendario)
                else { return false }
                return dias <= 0
            }
        }

        var metas: [MetaUi] = []
        if case let .exito(lista) = await metasPedido {
            metas = MetaUi.paraInicio(lista, moneda: moneda)
        }

        return .exito(EstadoInicio(
            nombre: nombre,
            iniciales: Iniciales.dos(nombre),
            hayAvisos: hayAvisos,
            saldo: saldo,
            moneda: moneda,
            ingresosMes: ingresos,
            gastosMes: gastos,
            etiquetaMes: EstadoInicio.etiquetaDelMes(hoy, calendario: calendario),
            otrasMonedas: CargadorInicio.lineaOtrasMonedas(cuentasSaldo, principal: moneda),
            avisoOtraMoneda: avisoOtraMoneda,
            gastoPorCategoria: porciones,
            inicialesSuscripciones: inicialesSuscripciones,
            suscripcionesRestantes: restantes,
            metas: metas
        ))
    }

    /// Regla 2: "+ US$ 200.00 en otras cuentas".
    ///
    /// Cada moneda se suma **por separado** y nunca entre sí. `nil` con una sola moneda, que es
    /// el caso normal: no debe aparecer nada nuevo en pantalla para quien no tiene el problema.
    static func lineaOtrasMonedas(_ cuentas: [Cuenta], principal: Moneda) -> String? {
        let porMoneda = Dictionary(grouping: cuentas.filter { $0.moneda != principal }, by: \.moneda)
        guard !porMoneda.isEmpty else { return nil }

        // Ordenado por código de moneda: sin esto el texto cambia de orden entre arranques,
        // porque el orden de un diccionario de Swift no está definido.
        let montos = porMoneda.keys.sorted().map { moneda in
            Dinero.monto(Dinero.sumar(porMoneda[moneda]!.map(\.saldoActual)), moneda)
        }
        let unido: String
        if montos.count == 1 {
            unido = montos[0]
        } else {
            unido = montos.dropLast().joined(separator: ", ") + " y " + montos[montos.count - 1]
        }
        return "+ \(unido) en otras cuentas"
    }
}
