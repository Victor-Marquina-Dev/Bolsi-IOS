import Foundation

/// Las entidades del API de Bolsi, traducidas de los DTOs ya verificados del Android
/// (`data/remote/dto/`), que a su vez se escribieron leyendo los schemas de Zod del backend.
///
/// **Los montos son `String` y no números, a propósito.** Prisma serializa `Decimal` a
/// string en JSON, y el backend manda dos decimales fijos (`Decimal.toFixed(2)`). Meterlos
/// en un `Double` al deserializar es justo el paso donde se pierde plata; acá se conservan
/// como texto y se convierten a `Decimal` **solo para sumar** (ver `Dinero.swift`).
public typealias Moneda = String // "PEN" | "USD"

public struct Cuenta: Decodable, Sendable, Identifiable {
    public let id: String
    public let nombre: String
    public let tipo: String // efectivo | ahorros | corriente | credito | debito | digital | otra
    public let banco: String?
    public let moneda: Moneda
    public let saldoInicial: String
    public let saldoActual: String
    public let bolsillitoId: String?
    public let lineaCredito: String?
    public let diaCierre: Int?
    public let diaPago: Int?
    public let deudaActual: String?
    public let disponible: String?

    /// `true` si es una tarjeta de crédito: el boceto las pinta aparte de las demás.
    public var esCredito: Bool { tipo == "credito" }
}

public struct Transaccion: Decodable, Sendable, Identifiable {
    public let id: String
    public let tipo: String // "ingreso" | "gasto"
    public let monto: String
    public let descripcion: String
    public let fecha: String
    public let categoriaId: String
    public let cuentaId: String
    public let bolsillitoId: String?
    public let origen: String?
    /// No nulo = esta fila es UNA de las dos mitades de una transferencia entre cuentas
    /// propias. El backend rechaza editarla o borrarla por separado.
    public let transferenciaId: String?

    public var esIngreso: Bool { tipo == "ingreso" }
    public var esTransferencia: Bool { transferenciaId != nil }
}

public struct Categoria: Decodable, Sendable, Identifiable {
    public let id: String
    public let nombre: String
    public let color: String
    public let emoji: String
    public let tipoMovimiento: String // "ingreso" | "gasto" | "ambos"
    public let esPredefinida: Bool

    /// Las de "ambos" sirven para gasto y para ingreso — el selector de Nuevo movimiento
    /// depende de esto.
    public func sirvePara(tipo: String) -> Bool {
        tipoMovimiento == tipo || tipoMovimiento == "ambos"
    }
}

public struct Bolsillito: Decodable, Sendable, Identifiable {
    public let id: String
    public let tipo: String
    public let nombre: String
    public let moneda: Moneda
    public let color: String
    public let emoji: String
    public let favorito: Bool
    public let usuarioId: String
}

public struct Suscripcion: Decodable, Sendable, Identifiable {
    public let id: String
    public let nombre: String
    public let monto: String
    public let moneda: Moneda
    /// Día del mes en que cobra. Es `Int` de verdad: el backend lo valida como número.
    public let diaPago: Int
    public let cuentaId: String
    public let categoriaId: String
    public let color: String
    public let emoji: String
    public let activa: Bool
}

public struct Pendiente: Decodable, Sendable, Identifiable {
    public let id: String
    public let tipo: String // "cobro" | "pago"
    public let descripcion: String
    public let monto: String
    public let moneda: Moneda
    public let vencimiento: String
    /// Estado **efectivo**: el backend calcula "vencido" al leer comparando contra hoy.
    /// Nunca se persiste; este cliente solo pinta lo que llega y jamás lo recalcula.
    public let estado: String // "pendiente" | "resuelto" | "vencido"
}

/// Fila de `GET /api/reportes/resumen`: ingresos/gastos/neto **agrupados por moneda**.
///
/// El backend ya las separa y nunca mezcla PEN con USD. Que venga una fila por moneda es
/// la señal de que sumarlas del lado del cliente sería inventar una conversión.
public struct ResumenPeriodo: Decodable, Sendable {
    public let moneda: Moneda
    public let ingresos: String
    public let gastos: String
    public let neto: String
}
