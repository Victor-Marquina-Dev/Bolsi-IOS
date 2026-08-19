import Foundation

/// Convierte lo que alguien **escribe a mano** en la URL base del API.
///
/// **Por qué esto existe y no es una constante.** El backend de Bolsi corre en la PC del dueño,
/// no en un servidor. El Android resuelve esto en tiempo de compilación (`BOLSI_BASE_URL` en
/// `local.properties`, con `10.0.2.2` para el emulador) y le alcanza, porque quien compila y
/// quien usa la app son la misma persona en la misma máquina. Acá no: la app se compila en una
/// Mac de la nube y se usa en un iPhone que tiene que llegar a `192.168.0.101` por WiFi. Esa IP
/// la da el router y cambia; recompilar en la nube y volver a instalar por cada cambio de IP
/// serían veinte minutos para arreglar un número. Así que se escribe en la app.
///
/// Y si se escribe a mano, hay que perdonar cómo se escribe: nadie va a tipear
/// `http://192.168.0.101:4000/api` completo en un teclado de teléfono. `192.168.0.101` alcanza.
public enum DireccionServidor {

    /// El puerto en que corre el backend en desarrollo.
    public static let puertoPorDefecto = 4000

    /// La dirección con la que arranca la app si nunca se configuró otra.
    public static let sugerida = "192.168.0.101"

    /// Normaliza lo escrito, o `nil` si no hay forma de entenderlo.
    ///
    /// - `192.168.0.101` → `http://192.168.0.101:4000/api`
    /// - `192.168.0.101:4000` → `http://192.168.0.101:4000/api`
    /// - `http://192.168.0.101:4000/api/` → sin la barra final
    /// - `bolsi.midominio.com` → `http://bolsi.midominio.com/api` (**sin** puerto)
    public static func normalizar(_ escrito: String) -> URL? {
        var texto = escrito.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty else { return nil }

        // Sin esquema no hay host: `URLComponents` mete "192.168.0.101" entero en `path` y
        // devuelve `host == nil`. Es la trampa clásica de parsear direcciones a mano.
        if !texto.contains("://") { texto = "http://" + texto }

        guard var partes = URLComponents(string: texto),
              let host = partes.host,
              !host.isEmpty,
              !host.contains(" ")
        else { return nil }

        // El puerto se agrega SOLO a una IP o a `localhost`. A un dominio, no: nadie publica un
        // sitio en el 4000, y meterle el puerto a `bolsi.midominio.com` rompería la única forma
        // en que esto podría apuntar a un servidor de verdad algún día.
        if partes.port == nil, esDireccionLocal(host) {
            partes.port = puertoPorDefecto
        }

        // La ruta: `/api` si no escribieron ninguna, y tal cual si escribieron algo. Si alguien
        // puso `/api/v2` sabía lo que hacía; agregarle otro `/api` encima sería corregir a
        // quien tenía razón.
        var ruta = partes.path
        while ruta.hasSuffix("/") { ruta.removeLast() }
        partes.path = ruta.isEmpty ? "/api" : ruta

        // La consulta y el fragmento no tienen sentido en una URL base y solo pueden llegar por
        // un copiado y pegado accidental.
        partes.query = nil
        partes.fragment = nil

        return partes.url
    }

    /// `true` si el host es una IPv4 o `localhost`, o sea algo de la red de casa.
    static func esDireccionLocal(_ host: String) -> Bool {
        if host == "localhost" { return true }
        let trozos = host.split(separator: ".", omittingEmptySubsequences: false)
        guard trozos.count == 4 else { return false }
        return trozos.allSatisfy { trozo in
            guard !trozo.isEmpty, trozo.count <= 3, let n = Int(trozo) else { return false }
            return (0...255).contains(n)
        }
    }

    /// Lo que se le muestra al dueño cuando abre el campo: la URL completa a la que va a pegar.
    public static func descripcion(_ escrito: String) -> String {
        normalizar(escrito)?.absoluteString ?? "Dirección incompleta"
    }
}
