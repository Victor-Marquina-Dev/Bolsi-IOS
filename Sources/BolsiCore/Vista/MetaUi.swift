import Foundation

/// Una meta lista para pintarse: los textos ya armados y la fracción del anillo.
///
/// Vive en el núcleo porque **cada campo de acá es una decisión, no un formato**: qué hacer con
/// un porcentaje que pasa de 100, con un objetivo en cero, con una meta en otra moneda. Metidas
/// en la vista serían tres decisiones que nadie puede verificar sin una Mac.
public struct MetaUi: Sendable, Identifiable {
    public let id: String
    public let nombre: String
    /// La letra del cuadradito de color, a la izquierda.
    public let inicial: String
    public let ahorrado: String
    public let objetivo: String
    /// Entero para el texto del centro del anillo.
    public let porcentaje: Int
    /// De 0 a 1, para el anillo y la barra. **Recortado**, aunque el porcentaje pase de 100.
    public let fraccion: Double
    /// "Faltan S/ 400.00", o `nil` si ya se alcanzó.
    public let falta: String?
    public let color: ColorBoceto

    public init(
        id: String,
        nombre: String,
        inicial: String,
        ahorrado: String,
        objetivo: String,
        porcentaje: Int,
        fraccion: Double,
        falta: String?,
        color: ColorBoceto
    ) {
        self.id = id
        self.nombre = nombre
        self.inicial = inicial
        self.ahorrado = ahorrado
        self.objetivo = objetivo
        self.porcentaje = porcentaje
        self.fraccion = fraccion
        self.falta = falta
        self.color = color
    }
}

public extension MetaUi {

    /// Los colores con que el boceto pinta las metas, en orden.
    ///
    /// El prototipo los asigna **por posición**, no por meta: la primera es azul, la segunda
    /// verde. No hay un color guardado en la meta, así que el color no significa nada — es solo
    /// para distinguirlas de un vistazo.
    static let colores: [ColorBoceto] = [
        ColorBoceto(0xFF3E8BFF), ColorBoceto(0xFF34C759), ColorBoceto(0xFFFF8A34),
        ColorBoceto(0xFFAF52DE), ColorBoceto(0xFFFF3B30), ColorBoceto(0xFF32ADE6),
        ColorBoceto(0xFFFFB020), ColorBoceto(0xFF7A5AF8),
    ]

    /// Convierte lo que manda el backend en lo que se pinta.
    ///
    /// - `posicion` decide el color, igual que en el boceto.
    static func de(_ meta: Meta, posicion: Int) -> MetaUi {
        let objetivo = Dinero.decimal(meta.montoObjetivo)
        let actual = Dinero.decimal(meta.montoActual)

        // El porcentaje lo calcula el backend y se respeta. Solo se **recorta** para el dibujo:
        // un anillo no puede dar más de una vuelta, y una barra al 140% se saldría de la
        // tarjeta. El número de al lado sí muestra el 140 — el dueño ahorró de más y merece
        // verlo, es el dibujo el que no da para representarlo.
        let porcentaje = Int(meta.porcentajeAlcanzado.rounded())
        let fraccion = min(max(meta.porcentajeAlcanzado / 100, 0), 1)

        let restante = objetivo - actual
        return MetaUi(
            id: meta.id,
            nombre: meta.nombre,
            inicial: Iniciales.una(meta.nombre),
            ahorrado: Dinero.monto(actual, meta.moneda),
            objetivo: Dinero.monto(objetivo, meta.moneda),
            porcentaje: porcentaje,
            fraccion: fraccion,
            // Alcanzada o pasada: no se dice "Faltan S/ 0.00" ni menos todavía un negativo. Es
            // el mismo criterio de no pintar un número que afirma algo falso.
            falta: restante > 0 ? "Faltan \(Dinero.monto(restante, meta.moneda))" : nil,
            color: colores[posicion % colores.count]
        )
    }

    /// Las metas que se muestran en Inicio.
    ///
    /// Solo las de la moneda principal, y **las tres más avanzadas**. El boceto pinta tres; con
    /// diez, Inicio se convierte en la pantalla de Metas y deja de ser un resumen. Se eligen por
    /// avance y no por fecha de creación porque las que están por cerrarse son las que uno
    /// quiere mirar.
    static func paraInicio(_ metas: [Meta], moneda: Moneda, cuantas: Int = 3) -> [MetaUi] {
        metas
            .filter { $0.moneda == moneda }
            .sorted { $0.porcentajeAlcanzado > $1.porcentajeAlcanzado }
            .prefix(cuantas)
            .enumerated()
            .map { MetaUi.de($0.element, posicion: $0.offset) }
    }
}
