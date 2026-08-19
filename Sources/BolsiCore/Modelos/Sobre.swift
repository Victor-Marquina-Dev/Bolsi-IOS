import Foundation

/// El sobre `{ data, meta }` con el que responde **todo** el backend de Bolsi.
///
/// No es un detalle de transporte que se pueda ignorar: la respuesta útil viene siempre
/// dentro de `data`, y `meta` trae la paginación cuando la hay. Se modela una sola vez acá
/// para que ninguna pantalla vuelva a desenvolverlo a mano.
public struct Sobre<T: Decodable>: Decodable {
    public let data: T
    public let meta: MetaPaginado?
}

/// `meta` de los listados paginados (`page`, `limit`, `total`).
public struct MetaPaginado: Decodable, Sendable {
    public let page: Int
    public let limit: Int
    public let total: Int
}

/// El sobre de error: `{ error: { codigo, mensaje } }`.
///
/// El `mensaje` viene redactado por el backend y **se muestra tal cual**. La app no
/// reinterpreta el motivo de un fallo: si el backend dice por qué rechazó algo, decirlo con
/// otras palabras solo agrega una traducción que se puede desincronizar.
public struct SobreError: Decodable, Sendable {
    public struct Detalle: Decodable, Sendable {
        public let codigo: String
        public let mensaje: String
    }
    public let error: Detalle
}

/// El resultado de cualquier llamada al API.
///
/// Tres casos y no dos, igual que en el Android (`ApiResult`): `sinSesion` es distinto de
/// `falla` porque un 401 no es un error que haya que mostrarle a nadie — significa que la
/// sesión se cayó y la app ya está volviendo al login. Pintar un cartel rojo encima de eso
/// es ruido sobre una pantalla que está por desaparecer.
public enum ResultadoApi<T: Sendable>: Sendable {
    case exito(T)
    case falla(String)
    case sinSesion
}
