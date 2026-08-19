import Foundation
import Security
import BolsiCore

/// Guarda el token de sesión en el Keychain del sistema.
///
/// **Por qué acá y no en `BolsiCore`.** El núcleo define `AlmacenSesion` como protocolo y no
/// sabe nada de esto: el Keychain existe solo en las plataformas de Apple, y si el núcleo lo
/// importara dejaría de compilar en Windows y con él se irían los 34 tests que hoy corren en la
/// máquina del dueño. La regla del proyecto es que el núcleo no importa nada específico de una
/// plataforma; los tests son el motivo.
///
/// **Por qué Keychain y no `UserDefaults`.** El token da acceso a todos los movimientos del
/// dueño. `UserDefaults` es un plist en claro dentro del contenedor de la app: cualquier backup
/// sin cifrar de iTunes se lo lleva legible. El Android hace lo mismo con `EncryptedSharedPreferences`
/// (`PrefsSeguras`), y las dos apps guardan la misma credencial: no tiene sentido que una la
/// proteja y la otra no.
final class SesionKeychain: AlmacenSesion, @unchecked Sendable {

    private let servicio: String
    private let cuenta = "token"

    /// Se lee una vez y queda en memoria. Sin esto, cada petición HTTP haría una consulta al
    /// Keychain: en la carga de Inicio son cinco llamadas en paralelo y cinco consultas para
    /// leer el mismo texto.
    private let candado = NSLock()
    private var cache: String??

    init(servicio: String = "com.bolsi.ios") {
        self.servicio = servicio
    }

    func leerToken() -> String? {
        candado.lock()
        defer { candado.unlock() }
        if let cache { return cache }

        var consulta = baseDeConsulta
        consulta[kSecReturnData as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne

        var resultado: CFTypeRef?
        let estado = SecItemCopyMatching(consulta as CFDictionary, &resultado)
        let token: String?
        if estado == errSecSuccess, let datos = resultado as? Data {
            token = String(data: datos, encoding: .utf8)
        } else {
            token = nil
        }
        cache = .some(token)
        return token
    }

    func guardarToken(_ nuevo: String?) {
        candado.lock()
        defer { candado.unlock() }
        cache = .some(nuevo)

        // Borrar y volver a escribir, en vez de `SecItemUpdate`. Es una sola credencial y así no
        // hay que distinguir "existe" de "no existe": las dos ramas de `SecItemUpdate` fallan de
        // formas distintas y no hay nada que ganar.
        SecItemDelete(baseDeConsulta as CFDictionary)

        guard let nuevo, let datos = nuevo.data(using: .utf8) else { return }
        var item = baseDeConsulta
        item[kSecValueData as String] = datos
        // `AfterFirstUnlock` y no `WhenUnlocked`: la app puede querer refrescar datos con el
        // teléfono bloqueado, y con `WhenUnlocked` el token sería ilegible ahí.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    private var baseDeConsulta: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
    }
}
