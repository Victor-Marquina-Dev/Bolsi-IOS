import Foundation
import SwiftUI
import BolsiCore

/// Quién está usando la app, y a qué servidor le habla.
///
/// Es la única pieza que decide si se ve el login o se ve la app. Todo lo demás recibe un
/// `ApiBolsi` ya armado y no se pregunta de dónde salió.
///
/// **La dirección del servidor se guarda acá y no se compila adentro.** El Android la fija en
/// tiempo de compilación y le alcanza; en iOS no, porque compilar es un viaje de veinte minutos
/// a una Mac de la nube. Ver `DireccionServidor` para el porqué completo.
@MainActor
final class EstadoSesion: ObservableObject {

    enum Fase {
        /// Hay token guardado: se entra directo y se verá si sirve en el primer pedido.
        case dentro
        case fuera
    }

    @Published private(set) var fase: Fase
    @Published private(set) var entrando = false
    @Published private(set) var error: String?

    /// La dirección tal como la escribió el dueño, sin normalizar. Se guarda cruda para que al
    /// volver a abrir el campo vea lo que él puso y no una URL que no reconoce.
    @Published var direccion: String {
        didSet { defaults.set(direccion, forKey: Llaves.direccion) }
    }

    @Published private(set) var nombre: String

    private let almacen: AlmacenSesion
    private let defaults: UserDefaults

    private enum Llaves {
        static let direccion = "BolsiDireccionServidor"
        static let nombre = "BolsiNombreUsuario"
    }

    init(almacen: AlmacenSesion = SesionKeychain(), defaults: UserDefaults = .standard) {
        self.almacen = almacen
        self.defaults = defaults
        self.direccion = defaults.string(forKey: Llaves.direccion) ?? DireccionServidor.sugerida
        self.nombre = defaults.string(forKey: Llaves.nombre) ?? ""

        // Con token guardado se entra directo, sin pantalla de "verificando". Si el token está
        // vencido, el primer pedido devuelve 401 y la app vuelve al login sola — un segundo de
        // app de más es mejor que una pantalla de espera en cada arranque.
        self.fase = almacen.leerToken() == nil ? .fuera : .dentro
    }

    /// El cliente apuntado al servidor configurado. `nil` si la dirección no se entiende.
    var api: ApiBolsi? {
        guard let base = DireccionServidor.normalizar(direccion) else { return nil }
        return ApiBolsi(cliente: ClienteApi(base: base, sesion: almacen))
    }

    func iniciarSesion(email: String, password: String) async {
        guard let api else {
            error = "Revisá la dirección del servidor."
            return
        }
        entrando = true
        error = nil

        switch await api.iniciarSesion(email: email, password: password) {
        case let .exito(sesion):
            almacen.guardarToken(sesion.token)
            nombre = sesion.usuario.nombre
            defaults.set(nombre, forKey: Llaves.nombre)
            entrando = false
            fase = .dentro

        case let .falla(mensaje):
            entrando = false
            error = mensaje

        case .sinSesion:
            // Un 401 en el propio login son credenciales mal puestas, no una sesión vencida. Es
            // el único lugar de la app donde `sinSesion` hay que mostrarlo: en cualquier otra
            // pantalla significaría "volvé al login", y acá ya estamos en el login.
            entrando = false
            error = "Correo o contraseña incorrectos."
        }
    }

    /// Cierra la sesión. Se llama al tocar Salir y también cuando un pedido devuelve 401.
    func salir() {
        almacen.guardarToken(nil)
        error = nil
        fase = .fuera
    }

    func limpiarError() {
        error = nil
    }
}
