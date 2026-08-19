import Foundation

/// Las iniciales que el boceto pinta en los círculos: el avatar de la cabecera y las
/// suscripciones del carrusel.
///
/// El prototipo las trae escritas a mano ("MO" para su "Massimo Osti", "N" para Netflix) porque
/// es un HTML estático. En la app salen del nombre de verdad, y por eso hay reglas que el
/// prototipo nunca tuvo que pensar: nombres de una sola palabra, espacios de más, emojis.
public enum Iniciales {

    /// Dos letras para el avatar: la inicial del nombre y la del apellido.
    ///
    /// Con una sola palabra usa sus dos primeras letras ("Víctor" → "VÍ"), que es lo que hace
    /// que un avatar de una palabra no quede con una letra sola y desbalanceado.
    public static func dos(_ nombre: String) -> String {
        let palabras = palabrasUtiles(nombre)
        switch palabras.count {
        case 0: return "?"
        case 1: return String(palabras[0].prefix(2)).uppercased()
        default: return (String(palabras[0].prefix(1)) + String(palabras[1].prefix(1))).uppercased()
        }
    }

    /// Una letra, para los círculos chicos de suscripciones.
    public static func una(_ nombre: String) -> String {
        guard let primera = palabrasUtiles(nombre).first else { return "?" }
        return String(primera.prefix(1)).uppercased()
    }

    /// Las palabras que aportan una letra.
    ///
    /// Descarta las que empiezan con algo que no es letra ni número, porque varios nombres de
    /// suscripción del mundo real arrancan con un emoji ("🎬 Netflix") y una inicial que sale
    /// "🎬" no es una inicial: es un círculo con un dibujo adentro donde debía haber una letra.
    private static func palabrasUtiles(_ nombre: String) -> [Substring] {
        nombre
            .split(whereSeparator: { $0.isWhitespace })
            .filter { palabra in
                guard let primera = palabra.first else { return false }
                return primera.isLetter || primera.isNumber
            }
    }
}
