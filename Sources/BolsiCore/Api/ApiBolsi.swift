import Foundation

/// Las llamadas concretas al backend de Bolsi.
///
/// Una capa fina sobre `ClienteApi`: cada método es una ruta y su tipo de respuesta. Existe para
/// que ninguna pantalla escriba una ruta a mano — si el backend renombra un endpoint, se cambia
/// acá y no en cinco vistas.
///
/// Las rutas salen de los repositorios del Android, que a su vez se escribieron leyendo las
/// rutas del backend. No se inventa ninguna.
public struct ApiBolsi: Sendable {

    private let cliente: ClienteApi

    public init(cliente: ClienteApi) {
        self.cliente = cliente
    }

    // MARK: - Sesión

    /// `POST /api/auth/login`.
    ///
    /// Devuelve `token` (no `accessToken`) — confirmado llamando al backend de verdad antes de
    /// escribir esto, no leyendo documentación.
    public func iniciarSesion(email: String, password: String) async -> ResultadoApi<Sesion> {
        await cliente.enviar("/auth/login", cuerpo: CredencialesLogin(email: email, password: password))
    }

    // MARK: - Catálogos

    public func cuentas() async -> ResultadoApi<[Cuenta]> {
        await cliente.obtener("/cuentas")
    }

    public func categorias() async -> ResultadoApi<[Categoria]> {
        await cliente.obtener("/categorias")
    }

    public func bolsillitos() async -> ResultadoApi<[Bolsillito]> {
        await cliente.obtener("/bolsillitos")
    }

    public func suscripciones() async -> ResultadoApi<[Suscripcion]> {
        await cliente.obtener("/suscripciones")
    }

    public func pendientes() async -> ResultadoApi<[Pendiente]> {
        await cliente.obtener("/pendientes")
    }

    // MARK: - Movimientos

    public func transacciones(
        page: Int = 1,
        limit: Int = 20,
        desde: String? = nil,
        hasta: String? = nil,
        tipo: String? = nil,
        categoriaId: String? = nil,
        busqueda: String? = nil
    ) async -> ResultadoApi<[Transaccion]> {
        var consulta = ["page": String(page), "limit": String(limit)]
        // Los filtros ausentes NO viajan como cadena vacía: el backend los combina con AND y un
        // `tipo=` vacío no es lo mismo que no filtrar por tipo.
        if let desde { consulta["desde"] = desde }
        if let hasta { consulta["hasta"] = hasta }
        if let tipo { consulta["tipo"] = tipo }
        if let categoriaId { consulta["categoriaId"] = categoriaId }
        if let busqueda, !busqueda.isEmpty { consulta["busqueda"] = busqueda }
        return await cliente.obtener("/transacciones", consulta: consulta)
    }

    /// Movimientos de UN día: mismo `desde == hasta` que ya resuelve el backend.
    public func transaccionesDelDia(_ fecha: String) async -> ResultadoApi<[Transaccion]> {
        await transacciones(page: 1, limit: 100, desde: fecha, hasta: fecha)
    }

    // MARK: - Reportes

    /// `GET /api/reportes/resumen` — ingresos/gastos/neto **por moneda**.
    public func resumen(desde: String, hasta: String) async -> ResultadoApi<[ResumenPeriodo]> {
        await cliente.obtener("/reportes/resumen", consulta: ["desde": desde, "hasta": hasta])
    }

    public func gastosPorCategoria(
        desde: String,
        hasta: String,
        tipo: String = "gasto"
    ) async -> ResultadoApi<[GastoPorCategoria]> {
        await cliente.obtener(
            "/reportes/gastos-por-categoria",
            consulta: ["desde": desde, "hasta": hasta, "tipo": tipo]
        )
    }
}

/// Cuerpo de `POST /api/auth/login`.
public struct CredencialesLogin: Encodable, Sendable {
    public let email: String
    public let password: String
}

/// Lo que devuelve el login.
public struct Sesion: Decodable, Sendable {
    public let token: String
    public let expiraAt: String
    public let usuario: Usuario
}

public struct Usuario: Decodable, Sendable {
    public let id: String
    public let nombre: String
    public let email: String
    public let telefono: String?

    /// Las iniciales del avatar del boceto: dos letras si el nombre tiene dos palabras.
    ///
    /// El prototipo trae "MO" a mano para su "Massimo Osti"; acá se derivan del nombre real.
    /// La regla vive en `Iniciales` porque las suscripciones necesitan la misma, con una letra.
    public var iniciales: String { Iniciales.dos(nombre) }
}

/// Fila de `GET /api/reportes/gastos-por-categoria`.
public struct GastoPorCategoria: Decodable, Sendable {
    public let categoriaId: String
    public let categoriaNombre: String
    public let categoriaColor: String
    public let categoriaEmoji: String
    public let moneda: Moneda
    public let total: String
}
