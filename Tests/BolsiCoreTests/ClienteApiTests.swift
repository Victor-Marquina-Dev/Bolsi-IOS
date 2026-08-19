import Testing
import Foundation
@testable import BolsiCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Tests del cliente del API **sin red**, gracias al transporte inyectable.
///
/// Cubren lo que de verdad se rompe en un cliente HTTP y que no se ve mirando el código: cómo
/// queda la URL, si viaja la cabecera de sesión, si el sobre `{data}` se desenvuelve, y si cada
/// clase de fallo cae en el caso correcto. Que corran en Windows y sin backend prendido es el
/// punto: el servidor de este proyecto vive en la PC del dueño y está apagado la mitad del tiempo.
@Suite("Cliente del API")
struct ClienteApiTests {

    private let base = URL(string: "http://192.168.0.101:4000/api")!

    /// Un transporte de mentira que devuelve lo que se le diga y guarda la petición que recibió.
    private final class Espia: @unchecked Sendable {
        var recibida: URLRequest?
        var codigo = 200
        var cuerpo = Data()

        func transporte() -> Transporte {
            { [self] peticion in
                recibida = peticion
                let http = HTTPURLResponse(
                    url: peticion.url!,
                    statusCode: codigo,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (cuerpo, http)
            }
        }
    }

    @Test("La URL respeta la base con subcarpeta /api")
    func urlConSubcarpeta() {
        let cliente = ClienteApi(base: base, sesion: SesionEnMemoria())
        let peticion = cliente.armar(ruta: "/cuentas", consulta: [:], metodo: "GET", cuerpo: nil)
        #expect(peticion?.url?.absoluteString == "http://192.168.0.101:4000/api/cuentas")
    }

    @Test("Los parámetros salen ordenados, para que la URL sea estable")
    func consultaOrdenada() {
        let cliente = ClienteApi(base: base, sesion: SesionEnMemoria())
        let peticion = cliente.armar(
            ruta: "/transacciones",
            consulta: ["limit": "100", "desde": "2026-08-01", "page": "1"],
            metodo: "GET",
            cuerpo: nil
        )
        // Sin ordenar, el diccionario de Swift cambia el orden entre corridas y este test
        // pasaria a veces. Un test intermitente es peor que ninguno.
        #expect(
            peticion?.url?.absoluteString
                == "http://192.168.0.101:4000/api/transacciones?desde=2026-08-01&limit=100&page=1"
        )
    }

    @Test("Con sesión viaja el Bearer; sin sesión no viaja nada")
    func cabeceraDeSesion() {
        let conToken = ClienteApi(base: base, sesion: SesionEnMemoria(token: "abc123"))
        let p1 = conToken.armar(ruta: "/cuentas", consulta: [:], metodo: "GET", cuerpo: nil)
        #expect(p1?.value(forHTTPHeaderField: "Authorization") == "Bearer abc123")

        let sinToken = ClienteApi(base: base, sesion: SesionEnMemoria())
        let p2 = sinToken.armar(ruta: "/cuentas", consulta: [:], metodo: "GET", cuerpo: nil)
        #expect(p2?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Desenvuelve el sobre {data} del backend")
    func desenvuelveElSobre() async {
        let espia = Espia()
        espia.cuerpo = Data("""
        {"data":[{"id":"c1","nombre":"BCP Cuenta Corriente","tipo":"corriente","banco":"BCP",
        "moneda":"PEN","saldoInicial":"0.00","saldoActual":"1500.50","bolsillitoId":null,
        "lineaCredito":null,"diaCierre":null,"diaPago":null,"deudaActual":null,"disponible":null}],
        "meta":null}
        """.utf8)

        let cliente = ClienteApi(base: base, sesion: SesionEnMemoria(), transporte: espia.transporte())
        let resultado: ResultadoApi<[Cuenta]> = await cliente.obtener("/cuentas")

        guard case let .exito(cuentas) = resultado else {
            Issue.record("se esperaba exito, llego \(resultado)")
            return
        }
        #expect(cuentas.count == 1)
        #expect(cuentas[0].nombre == "BCP Cuenta Corriente")
        // El monto llega como texto y se convierte exacto: es la regla de `dinero-y-decimales`.
        #expect(Dinero.decimal(cuentas[0].saldoActual) == Decimal(string: "1500.50"))
        #expect(!cuentas[0].esCredito)
    }

    @Test("Un 401 es sinSesion, no un error para mostrar — y borra el token")
    func sinSesion() async {
        let espia = Espia()
        espia.codigo = 401
        espia.cuerpo = Data(#"{"error":{"codigo":"SIN_SESION","mensaje":"Falta el token."}}"#.utf8)

        let almacen = SesionEnMemoria(token: "viejo")
        let cliente = ClienteApi(base: base, sesion: almacen, transporte: espia.transporte())
        let resultado: ResultadoApi<[Cuenta]> = await cliente.obtener("/cuentas")

        guard case .sinSesion = resultado else {
            Issue.record("un 401 tiene que ser sinSesion, llego \(resultado)")
            return
        }
        // Y el token invalido no puede quedar guardado: si queda, la proxima pantalla vuelve a
        // pedir con una sesion muerta y el usuario ve el error dos veces.
        #expect(almacen.leerToken() == nil)
    }

    @Test("El mensaje de error lo escribe el backend y se muestra tal cual")
    func mensajeDelBackend() async {
        let espia = Espia()
        espia.codigo = 400
        espia.cuerpo = Data(#"{"error":{"codigo":"VALIDACION","mensaje":"descripcion es requerida"}}"#.utf8)

        let cliente = ClienteApi(base: base, sesion: SesionEnMemoria(), transporte: espia.transporte())
        let resultado: ResultadoApi<[Cuenta]> = await cliente.obtener("/cuentas")

        guard case let .falla(mensaje) = resultado else {
            Issue.record("se esperaba falla")
            return
        }
        #expect(mensaje == "descripcion es requerida")
    }

    @Test("Un JSON que no encaja se distingue de un problema de red")
    func contratoRoto() async {
        let espia = Espia()
        espia.cuerpo = Data(#"{"data":{"no":"es una lista"}}"#.utf8)

        let cliente = ClienteApi(base: base, sesion: SesionEnMemoria(), transporte: espia.transporte())
        let resultado: ResultadoApi<[Cuenta]> = await cliente.obtener("/cuentas")

        guard case let .falla(mensaje) = resultado else {
            Issue.record("se esperaba falla")
            return
        }
        // Un contrato roto y una conexion caida se arreglan en lugares distintos: el mensaje
        // tiene que mandar a buscar al lugar correcto.
        #expect(mensaje.contains("formato"))
    }

    @Test("Servidor apagado: el mensaje dice qué revisar, no un número de error")
    func servidorApagado() async {
        let transporte: Transporte = { _ in throw URLError(.cannotConnectToHost) }
        let cliente = ClienteApi(base: base, sesion: SesionEnMemoria(), transporte: transporte)
        let resultado: ResultadoApi<[Cuenta]> = await cliente.obtener("/cuentas")

        guard case let .falla(mensaje) = resultado else {
            Issue.record("se esperaba falla")
            return
        }
        // Va a pasar seguido: el backend corre en la PC del dueño. "Error -1004" no le dice a
        // nadie que tiene que prender la PC.
        #expect(mensaje.contains("misma red"))
    }

    @Test("Un POST manda cuerpo JSON y su Content-Type")
    func envioConCuerpo() {
        struct Cuerpo: Encodable { let email: String }
        let cliente = ClienteApi(base: base, sesion: SesionEnMemoria())
        let json = try? JSONEncoder().encode(Cuerpo(email: "a@b.c"))
        let peticion = cliente.armar(ruta: "/auth/login", consulta: [:], metodo: "POST", cuerpo: json)

        #expect(peticion?.httpMethod == "POST")
        #expect(peticion?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(peticion?.httpBody != nil)
    }
}
