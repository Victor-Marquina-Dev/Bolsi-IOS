import SwiftUI
import BolsiCore

/// Punto de entrada de Bolsi iOS.
@main
struct BolsiApp: App {
    @StateObject private var sesion = EstadoSesion()

    var body: some Scene {
        WindowGroup {
            TemaBoceto {
                contenido
            }
            .environmentObject(sesion)
            // El boceto es oscuro por defecto (sus `data-props` declaran `"theme": "dark"`) y
            // trae claro alternativo. Se respeta el sistema, que es la convención de iOS.
            .preferredColorScheme(nil)
        }
    }

    @ViewBuilder
    private var contenido: some View {
        // En modo maqueta se salta el login. No es una comodidad: el simulador de la nube no
        // llega al backend de la LAN, así que sin esto **la CI solo podría fotografiar la
        // pantalla de login** y no habría nada que comparar contra el boceto.
        if Fuente.esMaqueta {
            // `-BolsiPantalla login` fuerza el login incluso en maqueta. Sin esto la CI no
            // podría fotografiarlo nunca: el modo maqueta existe justamente para saltearlo, y
            // una pantalla que no se puede mirar es una pantalla que se escribió a ciegas.
            if Fuente.mostrarLogin { Login() } else { Raiz() }
        } else {
            switch sesion.fase {
            case .fuera: Login()
            case .dentro: Raiz()
            }
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

    /// Lo que pidió la CI con `-BolsiPantalla`.
    private static var pantallaPedida: String {
        UserDefaults.standard.string(forKey: "BolsiPantalla") ?? ""
    }

    /// La pestaña con la que abrir. La CI la pasa como `-BolsiPantalla cuentas` para dejar una
    /// captura por pantalla en una sola corrida.
    static var pestanaInicial: PestanaBoceto {
        PestanaBoceto(rawValue: pantallaPedida) ?? .inicio
    }

    /// `true` con `-BolsiPantalla login`: es la única forma de sacarle una captura.
    static var mostrarLogin: Bool { pantallaPedida == "login" }

    /// El estado de Inicio **de maqueta**, para las capturas de la CI.
    ///
    /// Los datos de verdad no pasan por acá: los pide `ModeloInicio` con `CargadorInicio`. Este
    /// quedó como lo que siempre fue, una fuente para el simulador sin red, y por eso ya no se
    /// llama como si fuera la única.
    static var inicioDeMaqueta: EstadoInicio { Maqueta.inicio }
}
