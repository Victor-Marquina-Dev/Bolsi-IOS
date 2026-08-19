import Foundation
#if canImport(FoundationNetworking)
// En Windows y Linux, `URLSession` vive en un módulo aparte. Sin esto el núcleo no compila
// fuera de Apple, y perder eso significa perder los tests que corren en la máquina del dueño.
import FoundationNetworking
#endif

/// Dónde guardar el token de sesión.
///
/// Es un protocolo y no una implementación porque el núcleo no puede depender del Keychain
/// (existe solo en Apple). La app lo implementa con Keychain; los tests, con memoria.
public protocol AlmacenSesion: Sendable {
    func leerToken() -> String?
    func guardarToken(_ token: String?)
}

/// Almacén en memoria: para tests y para el modo maqueta.
public final class SesionEnMemoria: AlmacenSesion, @unchecked Sendable {
    private let candado = NSLock()
    private var token: String?

    public init(token: String? = nil) { self.token = token }

    public func leerToken() -> String? {
        candado.lock(); defer { candado.unlock() }
        return token
    }

    public func guardarToken(_ nuevo: String?) {
        candado.lock(); defer { candado.unlock() }
        token = nuevo
    }
}

/// Lo que el cliente necesita para hablar con el mundo: una función que manda una petición y
/// devuelve la respuesta.
///
/// **Está inyectable a propósito.** Así los tests del cliente —armado de la URL, cabecera de
/// sesión, lectura del sobre, mapeo de errores— corren **sin red y en Windows**. Testear eso
/// contra un servidor de verdad haría que los tests dependieran de que el backend esté
/// prendido, y hoy está apagado la mitad del tiempo.
public typealias Transporte = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

/// Cliente del API de Bolsi.
///
/// Habla con el mismo backend que la web y el Android. Ninguna regla de negocio vive acá: el
/// servidor decide, este cliente traduce.
public struct ClienteApi: Sendable {

    public let base: URL
    private let sesion: AlmacenSesion
    private let transporte: Transporte

    /// El decodificador se arma una vez: el backend manda fechas ISO y claves en camelCase, que
    /// es el default, así que no hace falta configurar nada más.
    private static let decodificador = JSONDecoder()

    public init(base: URL, sesion: AlmacenSesion, transporte: Transporte? = nil) {
        self.base = base
        self.sesion = sesion
        self.transporte = transporte ?? ClienteApi.transporteReal
    }

    private static let transporteReal: Transporte = { peticion in
        let (datos, respuesta) = try await URLSession.shared.data(for: peticion)
        guard let http = respuesta as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (datos, http)
    }

    // MARK: - Peticiones

    public func obtener<T: Decodable & Sendable>(
        _ ruta: String,
        consulta: [String: String] = [:]
    ) async -> ResultadoApi<T> {
        guard let peticion = armar(ruta: ruta, consulta: consulta, metodo: "GET", cuerpo: nil) else {
            return .falla("La dirección del servidor no es válida.")
        }
        return await ejecutar(peticion)
    }

    public func enviar<T: Decodable & Sendable, C: Encodable>(
        _ ruta: String,
        cuerpo: C,
        metodo: String = "POST"
    ) async -> ResultadoApi<T> {
        guard let json = try? JSONEncoder().encode(cuerpo),
              let peticion = armar(ruta: ruta, consulta: [:], metodo: metodo, cuerpo: json)
        else {
            return .falla("No se pudo preparar el envío.")
        }
        return await ejecutar(peticion)
    }

    // MARK: - Armado

    /// `internal` para que los tests puedan mirar la petición sin mandarla.
    func armar(ruta: String, consulta: [String: String], metodo: String, cuerpo: Data?) -> URLRequest? {
        // La ruta llega como "/cuentas" y la base termina en "/api": pegarlas con
        // `appendingPathComponent` es lo único que respeta una base con subcarpeta.
        let limpia = ruta.hasPrefix("/") ? String(ruta.dropFirst()) : ruta
        guard var componentes = URLComponents(
            url: base.appendingPathComponent(limpia),
            resolvingAgainstBaseURL: false
        ) else { return nil }

        if !consulta.isEmpty {
            // Ordenado por clave: una URL estable es una URL testeable, y además los diccionarios
            // de Swift no garantizan orden entre corridas.
            componentes.queryItems = consulta
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = componentes.url else { return nil }

        var peticion = URLRequest(url: url)
        peticion.httpMethod = metodo
        peticion.setValue("application/json", forHTTPHeaderField: "Accept")
        if cuerpo != nil {
            peticion.setValue("application/json", forHTTPHeaderField: "Content-Type")
            peticion.httpBody = cuerpo
        }
        if let token = sesion.leerToken() {
            peticion.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return peticion
    }

    // MARK: - Ejecución

    private func ejecutar<T: Decodable & Sendable>(_ peticion: URLRequest) async -> ResultadoApi<T> {
        do {
            let (datos, http) = try await transporte(peticion)

            // 401 primero y aparte: no es un error que haya que mostrar. Significa que la sesión
            // se cayó y la app tiene que volver al login. Un cartel rojo encima de una pantalla
            // que está por desaparecer es ruido.
            if http.statusCode == 401 {
                sesion.guardarToken(nil)
                return .sinSesion
            }

            if !(200...299).contains(http.statusCode) {
                // El mensaje lo redacta el backend y se muestra tal cual: si él explica por qué
                // rechazó algo, traducirlo de nuevo acá solo agrega una versión que se
                // desincroniza.
                if let sobre = try? ClienteApi.decodificador.decode(SobreError.self, from: datos) {
                    return .falla(sobre.error.mensaje)
                }
                return .falla("El servidor respondió \(http.statusCode).")
            }

            let sobre = try ClienteApi.decodificador.decode(Sobre<T>.self, from: datos)
            return .exito(sobre.data)

        } catch is DecodingError {
            // Se separa del error de red a propósito: un JSON que no encaja es un contrato roto
            // entre app y backend, no un problema de conexión, y confundirlos manda a buscar el
            // problema al lugar equivocado.
            return .falla("La respuesta del servidor no tiene el formato esperado.")
        } catch {
            return .falla(mensajeDeRed(error))
        }
    }

    /// Traduce un fallo de red a algo que se pueda leer.
    ///
    /// Importa más de lo que parece en este proyecto: el backend corre en la PC del dueño, así
    /// que "no se pudo conectar" va a pasar seguido —PC apagada, fuera de la red de casa— y
    /// decir "error -1004" no ayuda a nadie a entender qué hacer.
    private func mensajeDeRed(_ error: Error) -> String {
        guard let url = error as? URLError else { return error.localizedDescription }
        switch url.code {
        case .notConnectedToInternet:
            return "Sin conexión."
        case .timedOut:
            return "El servidor no respondió a tiempo."
        case .cannotConnectToHost, .cannotFindHost:
            return "No se pudo conectar con el servidor de Bolsi. ¿Está encendido y en la misma red?"
        default:
            return url.localizedDescription
        }
    }
}
