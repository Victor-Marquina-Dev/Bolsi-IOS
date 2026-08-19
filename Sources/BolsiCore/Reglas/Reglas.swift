import Foundation

/// Las reglas de negocio que el rediseño ya decidió, sacadas de la vista para que se puedan
/// **probar**.
///
/// Todas salieron de construir el Android contra el boceto y están anotadas en
/// `plan-boceto.md`. Ahí vivían dentro de composables, donde en este entorno nadie las puede
/// verificar; acá cada una lleva su test. Es la mitad del valor de haber partido el paquete.
public enum Reglas {

    /// La moneda principal del usuario: la de la mayoría de sus cuentas, con PEN de desempate.
    ///
    /// Existe porque **nunca se suman monedas distintas** (`dinero-y-decimales`, multi-moneda
    /// sin conversión). Todo total de la app se calcula en esta moneda y las filas de otra
    /// quedan fuera, con aviso — no se inventa una tasa de cambio.
    public static func monedaDominante(_ cuentas: [Cuenta]) -> Moneda {
        guard !cuentas.isEmpty else { return "PEN" }
        var conteo: [Moneda: Int] = [:]
        for cuenta in cuentas { conteo[cuenta.moneda, default: 0] += 1 }
        let maximo = conteo.values.max() ?? 0
        // Empate: gana PEN. Sin esto el orden del diccionario decide la moneda de la app,
        // que es distinto en cada arranque.
        if conteo["PEN"] == maximo { return "PEN" }
        return conteo.first { $0.value == maximo }?.key ?? "PEN"
    }

    /// Total mensual de suscripciones.
    ///
    /// Dos reglas propias, ninguna del boceto: **una suscripción pausada no entra** (no cobra)
    /// y **solo suma la moneda principal**. El prototipo suma sus seis sin distinguir porque
    /// todas son de la misma moneda y ninguna está pausada.
    public static func cargoMensual(_ suscripciones: [Suscripcion], moneda: Moneda) -> Decimal {
        Dinero.sumar(
            suscripciones
                .filter { $0.activa && $0.moneda == moneda }
                .map(\.monto)
        )
    }

    /// El día del mes en que cobra una suscripción, ajustado al mes real.
    ///
    /// Una que cobra el 31 en un mes de 30 cae el último día: no existe el 31 y perder el
    /// cobro sería peor que adelantarlo un día.
    public static func diaDeCobro(diaPago: Int, diasDelMes: Int) -> Int {
        min(max(diaPago, 1), diasDelMes)
    }

    /// Cuántos días faltan para el próximo cobro. Si el día ya pasó este mes, cuenta para el
    /// siguiente.
    public static func diasHastaCobro(diaPago: Int, desde hoy: Date, calendario: Calendar = .current) -> Int {
        let inicioHoy = calendario.startOfDay(for: hoy)
        let diaActual = calendario.component(.day, from: inicioHoy)
        let diasEsteMes = calendario.range(of: .day, in: .month, for: inicioHoy)?.count ?? 30
        let objetivo = diaDeCobro(diaPago: diaPago, diasDelMes: diasEsteMes)

        if objetivo >= diaActual {
            return objetivo - diaActual
        }
        guard let mesSiguiente = calendario.date(byAdding: .month, value: 1, to: inicioHoy) else { return 0 }
        let diasMesSiguiente = calendario.range(of: .day, in: .month, for: mesSiguiente)?.count ?? 30
        let objetivoSiguiente = diaDeCobro(diaPago: diaPago, diasDelMes: diasMesSiguiente)
        var componentes = calendario.dateComponents([.year, .month], from: mesSiguiente)
        componentes.day = objetivoSiguiente
        guard let fecha = calendario.date(from: componentes) else { return 0 }
        return calendario.dateComponents([.day], from: inicioHoy, to: fecha).day ?? 0
    }

    /// Neto de un día: **solo movimientos reales** y solo de la moneda principal.
    ///
    /// Las suscripciones que cobran ese día y los pendientes que vencen son **previsiones**:
    /// todavía no movieron plata. Mezclarlas en el total es inventarle plata al dueño — es la
    /// regla que decidió la Agenda del Android.
    public static func netoDelDia(
        movimientos: [Transaccion],
        monedaPorCuenta: [String: Moneda],
        moneda: Moneda
    ) -> Decimal {
        movimientos
            .filter { (monedaPorCuenta[$0.cuentaId] ?? moneda) == moneda }
            .reduce(Decimal(0)) { total, movimiento in
                let valor = Dinero.decimal(movimiento.monto)
                return movimiento.esIngreso ? total + valor : total - valor
            }
    }

    /// El rótulo del conteo de una lista paginada.
    ///
    /// Con páginas pendientes escribe `"20+ movimientos"`. Es la regla del Historial: **un
    /// número incompleto se rotula como incompleto**, nunca se presenta como el total del
    /// período.
    public static func conteoDeLista(cargados: Int, hayMas: Bool) -> String {
        let palabra = cargados == 1 ? "movimiento" : "movimientos"
        return hayMas ? "\(cargados)+ \(palabra)" : "\(cargados) \(palabra)"
    }
}
