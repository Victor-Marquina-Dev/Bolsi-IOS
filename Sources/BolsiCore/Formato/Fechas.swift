import Foundation

/// Fechas en el formato que habla el backend: `yyyy-MM-dd`.
///
/// **Sin `DateFormatter`, a propósito**, por la misma razón que `Dinero` formatea a mano: este
/// módulo se testea en Windows y se ejecuta en iOS, y un formateador arrastra locale, calendario
/// y zona horaria del sistema. Un test que pasa en la PC del dueño y falla en el teléfono no
/// sirve para nada, y el modo en que falla es el peor posible: una fecha corrida un día.
///
/// Todo se arma con `DateComponents`, que es aritmética de calendario y da lo mismo en las dos
/// plataformas.
public enum Fechas {

    /// `2026-08-19`. Es lo que esperan `desde` y `hasta` de los endpoints de reportes.
    public static func dia(_ fecha: Date, calendario: Calendar = .current) -> String {
        let c = calendario.dateComponents([.year, .month, .day], from: fecha)
        let a = c.year ?? 2000, m = c.month ?? 1, d = c.day ?? 1
        // El relleno con ceros se hace a mano: `String(format:)` mira el locale en algunas
        // plataformas y esto tiene que dar el mismo texto siempre.
        return "\(a)-\(dosDigitos(m))-\(dosDigitos(d))"
    }

    private static func dosDigitos(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }

    /// Lee la fecha de un texto del backend.
    ///
    /// Tolera que venga como `2026-08-19` o como un ISO completo `2026-08-19T00:00:00.000Z`:
    /// **solo mira los primeros diez caracteres**. El backend manda las dos formas según el
    /// campo, y depender de cuál manda cada uno es la clase de detalle que cambia sin avisar.
    ///
    /// La hora se descarta de propósito: un vencimiento es un día, no un instante. Quedarse con
    /// la hora hace que "vence hoy" dependa de la zona horaria del teléfono.
    public static func fecha(_ texto: String, calendario: Calendar = .current) -> Date? {
        let trozos = texto.prefix(10).split(separator: "-")
        guard trozos.count == 3,
              let a = Int(trozos[0]), let m = Int(trozos[1]), let d = Int(trozos[2]),
              (1...12).contains(m), (1...31).contains(d)
        else { return nil }
        var c = DateComponents()
        c.year = a; c.month = m; c.day = d
        return calendario.date(from: c)
    }

    /// Cuántos días faltan para una fecha. Negativo si ya pasó, `0` si es hoy.
    ///
    /// `nil` si el texto no se entiende. Quien llame **descarta** ese caso en vez de asumir un
    /// número: es la regla que ya aplica el Android para los pendientes, y el motivo es que
    /// asumir `0` convertiría una fecha ilegible en un aviso urgente falso.
    public static func diasHasta(_ texto: String, desde hoy: Date = Date(), calendario: Calendar = .current) -> Int? {
        guard let objetivo = fecha(texto, calendario: calendario) else { return nil }
        let a = calendario.startOfDay(for: hoy)
        let b = calendario.startOfDay(for: objetivo)
        return calendario.dateComponents([.day], from: a, to: b).day
    }

    /// El día 1 del mes de `fecha`. Es el `desde` de todo lo que dice "este mes".
    public static func primerDiaDelMes(_ fecha: Date = Date(), calendario: Calendar = .current) -> Date {
        var c = calendario.dateComponents([.year, .month], from: fecha)
        c.day = 1
        return calendario.date(from: c) ?? fecha
    }
}
