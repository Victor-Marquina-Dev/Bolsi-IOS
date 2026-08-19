import Foundation

/// Lo que la pestaña Inicio necesita para pintarse, ya resuelto.
///
/// **Por qué el estado vive en el núcleo y no en la vista.** Así la pantalla no sabe de dónde
/// salieron los datos: los pone el API cuando la app corre en un teléfono, o los pone la maqueta
/// cuando corre en el simulador de la nube (que no llega al backend de la LAN). Sin esta
/// separación no habría forma de sacar una captura con contenido, y sin captura no habría forma
/// de comparar contra el boceto.
///
/// Es el mismo reparto que en Android, donde cada pantalla lee un `UiState` de su ViewModel. La
/// diferencia es que acá el tipo está en un módulo que **se testea en Windows**.
public struct EstadoInicio: Sendable {
    public let nombre: String
    public let iniciales: String
    /// `true` si hay algo que atender: es lo que enciende el punto rojo de la campana.
    public let hayAvisos: Bool

    public let saldo: Decimal
    public let moneda: Moneda
    public let ingresosMes: Decimal
    public let gastosMes: Decimal
    /// "En agosto" — el mes que se está mirando, con su nombre de verdad.
    public let etiquetaMes: String

    public let gastoPorCategoria: [PorcionCategoria]
    public let inicialesSuscripciones: [String]
    public let suscripcionesRestantes: Int

    public var netoMes: Decimal { ingresosMes - gastosMes }

    public init(
        nombre: String,
        iniciales: String,
        hayAvisos: Bool,
        saldo: Decimal,
        moneda: Moneda,
        ingresosMes: Decimal,
        gastosMes: Decimal,
        etiquetaMes: String,
        gastoPorCategoria: [PorcionCategoria],
        inicialesSuscripciones: [String],
        suscripcionesRestantes: Int
    ) {
        self.nombre = nombre
        self.iniciales = iniciales
        self.hayAvisos = hayAvisos
        self.saldo = saldo
        self.moneda = moneda
        self.ingresosMes = ingresosMes
        self.gastosMes = gastosMes
        self.etiquetaMes = etiquetaMes
        self.gastoPorCategoria = gastoPorCategoria
        self.inicialesSuscripciones = inicialesSuscripciones
        self.suscripcionesRestantes = suscripcionesRestantes
    }
}

/// Un tramo de la barra apilada de la tarjeta Movimientos: su color y cuánto pesa.
public struct PorcionCategoria: Sendable, Identifiable {
    public let id: String
    public let nombre: String
    public let color: ColorBoceto
    public let monto: Decimal

    public init(id: String, nombre: String, color: ColorBoceto, monto: Decimal) {
        self.id = id
        self.nombre = nombre
        self.color = color
        self.monto = monto
    }
}

public extension EstadoInicio {
    /// El mes en curso escrito como lo escribe el boceto (`tInMay` → "En mayo").
    ///
    /// El prototipo está congelado en mayo de 2026; la app tiene que decir el mes que de verdad
    /// se está mirando.
    static func etiquetaDelMes(_ fecha: Date = Date(), calendario: Calendar = .current) -> String {
        let meses = [
            "enero", "febrero", "marzo", "abril", "mayo", "junio",
            "julio", "agosto", "setiembre", "octubre", "noviembre", "diciembre",
        ]
        let mes = calendario.component(.month, from: fecha)
        return "En " + meses[max(0, min(11, mes - 1))]
    }

    /// Las seis categorías con más gasto, que son las que el boceto pinta en la barra.
    ///
    /// Más de seis deja tramos de menos de un píxel: no informan y ensucian.
    static func porcionesVisibles(_ todas: [PorcionCategoria]) -> [PorcionCategoria] {
        todas
            .filter { $0.monto > 0 }
            .sorted { $0.monto > $1.monto }
            .prefix(6)
            .map { $0 }
    }
}
