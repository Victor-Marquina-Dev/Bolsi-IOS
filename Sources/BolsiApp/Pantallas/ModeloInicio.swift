import Foundation
import SwiftUI
import BolsiCore

/// Trae el estado de Inicio y avisa qué está pasando mientras tanto.
///
/// La composición y toda la aritmética viven en `BolsiCore.CargadorInicio`, donde se testean en
/// Windows. Acá solo queda lo que necesita SwiftUI: tres estados y un `Task`.
///
/// **Tres estados y no dos.** "Cargando" y "vacío" tienen que verse distinto. El Historial del
/// Android mostró `+ S/ 0.00` y `0+ movimientos` mientras cargaba, y eso no es un hueco: es un
/// número falso que se lee como un dato. Mientras no llegó la respuesta, la pantalla no dice
/// ninguna cifra.
@MainActor
final class ModeloInicio: ObservableObject {

    enum Situacion {
        case cargando
        case listo(EstadoInicio)
        case falla(String)
    }

    @Published private(set) var situacion: Situacion = .cargando

    private var enVuelo: Task<Void, Never>?

    /// Pide los datos. Si ya había un pedido en vuelo, lo cancela: al tirar para refrescar dos
    /// veces seguidas, la respuesta vieja podría llegar después de la nueva y pisarla.
    func cargar(_ sesion: EstadoSesion) {
        enVuelo?.cancel()
        enVuelo = Task { [weak self] in
            guard let self else { return }
            guard let api = sesion.api else {
                self.situacion = .falla("Revisá la dirección del servidor.")
                return
            }
            let resultado = await CargadorInicio(api: api).cargar(nombre: sesion.nombre)
            guard !Task.isCancelled else { return }

            switch resultado {
            case let .exito(estado):
                self.situacion = .listo(estado)
            case let .falla(mensaje):
                self.situacion = .falla(mensaje)
            case .sinSesion:
                // El token se cayó. `ClienteApi` ya lo borró; acá solo hay que volver al login.
                // No se pinta ningún cartel: sería un error rojo encima de una pantalla que está
                // desapareciendo.
                sesion.salir()
            }
        }
    }
}
