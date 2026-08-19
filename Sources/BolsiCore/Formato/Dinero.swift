import Foundation

/// Plata: convertir, sumar y escribir montos.
///
/// Sigue el patrón `dinero-y-decimales` de la agencia: **exacto en la base, exacto en la
/// aritmética, `string` en el JSON, y número solo en el instante de mostrarlo**. Acá eso se
/// puede cumplir de verdad porque Swift trae `Decimal`: el Android quedó con `Double` en las
/// sumas, que es un compromiso que funciona con montos chicos y va acumulando error.
///
/// El formato **no usa `NumberFormatter`** a propósito. Se arma a mano para que dé exactamente
/// el mismo resultado en iOS y en Windows, que es donde corren los tests de este paquete; el
/// formateador del sistema depende de ICU y de la configuración regional del equipo, y un test
/// que pasa en una máquina y falla en otra no sirve para nada.
public enum Dinero {

    /// `"S/"` o `"US$"`, igual que el Android (`simboloMoneda`).
    public static func simbolo(_ moneda: Moneda) -> String {
        switch moneda {
        case "USD": return "US$"
        default: return "S/"
        }
    }

    /// Texto del backend (`"1234.56"`) a `Decimal` exacto.
    ///
    /// Fuerza la interpretación con punto decimal (`en_US_POSIX`) en vez de la configuración
    /// del equipo: el backend siempre manda punto, y en un teléfono configurado con coma
    /// decimal la lectura ingenua devuelve `nil` y el monto se convierte en cero sin avisar.
    public static func decimal(_ texto: String) -> Decimal {
        Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    /// Suma una lista de montos en texto. Sin pasar por punto flotante en ningún paso.
    public static func sumar(_ montos: [String]) -> Decimal {
        montos.reduce(Decimal(0)) { $0 + decimal($1) }
    }

    /// `1234.5` → `"1,234.50"`. Coma para los miles y punto para los centavos, que es lo que
    /// ya muestra el resto de Bolsi (`String.format(Locale.US, "%,.2f")` en Android).
    public static func numero(_ monto: Decimal) -> String {
        var redondeado = Decimal()
        var origen = monto
        NSDecimalRound(&redondeado, &origen, 2, .plain)

        // A centavos enteros: desde acá la aritmética es entera y no hay nada que perder.
        let centavosTotales = NSDecimalNumber(decimal: redondeado * 100).int64Value
        let negativo = centavosTotales < 0
        let absoluto = negativo ? -centavosTotales : centavosTotales
        let entero = absoluto / 100
        let centavos = absoluto % 100

        var digitos = String(entero)
        var conMiles = ""
        while digitos.count > 3 {
            let corte = digitos.index(digitos.endIndex, offsetBy: -3)
            conMiles = "," + digitos[corte...] + conMiles
            digitos = String(digitos[digitos.startIndex..<corte])
        }
        conMiles = digitos + conMiles

        let centavosTexto = centavos < 10 ? "0\(centavos)" : String(centavos)
        return "\(negativo ? "-" : "")\(conMiles).\(centavosTexto)"
    }

    /// `"S/ 1,234.50"`.
    public static func monto(_ monto: Decimal, _ moneda: Moneda) -> String {
        "\(simbolo(moneda)) \(numero(monto))"
    }

    /// Igual, desde el texto que viene del API.
    public static func monto(_ texto: String, _ moneda: Moneda) -> String {
        monto(decimal(texto), moneda)
    }

    /// `"+ S/ 20.00"` / `"− S/ 20.00"`.
    ///
    /// El signo va **separado del símbolo** y usa el menos tipográfico `−` (U+2212), no el
    /// guion del teclado: es lo que usa el boceto en cada monto, y en una columna de números
    /// alineados la diferencia de ancho entre `-` y `−` se ve.
    public static func montoConSigno(_ texto: String, esIngreso: Bool, moneda: Moneda) -> String {
        let valor = decimal(texto)
        let absoluto = valor < 0 ? -valor : valor
        return "\(esIngreso ? "+" : "−") \(monto(absoluto, moneda))"
    }
}
