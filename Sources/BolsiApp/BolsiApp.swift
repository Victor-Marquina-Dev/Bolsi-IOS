import SwiftUI
import BolsiCore

/// Punto de entrada de Bolsi iOS.
@main
struct BolsiApp: App {
    var body: some Scene {
        WindowGroup {
            TemaBoceto {
                Raiz()
            }
            // El boceto es oscuro por defecto (sus `data-props` declaran `"theme": "dark"`) y
            // trae claro alternativo. Se respeta el sistema, que es la convención de iOS.
            .preferredColorScheme(nil)
        }
    }
}

/// De dónde saca la app lo que muestra.
///
/// El simulador de la nube **no llega** al backend de la LAN, así que las capturas de la CI se
/// sacan en modo maqueta. Es una decisión de verificación, no una comodidad: sin esto las
/// capturas mostrarían la pantalla de login y no habría nada que comparar contra el boceto.
///
/// La app compilada para el teléfono nunca entra en este modo — el flag solo lo pone la CI.
enum Fuente {
    #if MAQUETA
    static let esMaqueta = true
    #else
    static let esMaqueta = false
    #endif

    /// La pestaña con la que abrir. La CI la pasa como `-BolsiPantalla cuentas` para dejar una
    /// captura por pantalla en una sola corrida.
    static var pestanaInicial: PestanaBoceto {
        let pedida = UserDefaults.standard.string(forKey: "BolsiPantalla") ?? ""
        return PestanaBoceto(rawValue: pedida) ?? .inicio
    }
}
