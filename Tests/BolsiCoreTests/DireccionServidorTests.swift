import Testing
import Foundation
@testable import BolsiCore

/// Tests de la dirección del servidor.
///
/// Parece trivial y no lo es: es lo que el dueño va a escribir con el pulgar en un teclado de
/// teléfono, y cada forma que no se perdone acá termina en "no se pudo conectar" sin ninguna
/// pista de que el problema era una barra al final.
@Suite("Dirección del servidor")
struct DireccionServidorTests {

    @Test("Solo la IP alcanza: se completan esquema, puerto y ruta")
    func soloLaIp() {
        #expect(
            DireccionServidor.normalizar("192.168.0.101")?.absoluteString
                == "http://192.168.0.101:4000/api"
        )
    }

    @Test("Con puerto escrito, se respeta el que puso el dueño")
    func conPuerto() {
        #expect(
            DireccionServidor.normalizar("192.168.0.101:3000")?.absoluteString
                == "http://192.168.0.101:3000/api"
        )
    }

    @Test("La URL completa vuelve igual, sin la barra final")
    func urlCompleta() {
        // La barra final la agrega el teclado de iOS al pegar y rompe `appendingPathComponent`
        // en la ruta siguiente: quedaría `//cuentas`.
        #expect(
            DireccionServidor.normalizar("http://192.168.0.101:4000/api/")?.absoluteString
                == "http://192.168.0.101:4000/api"
        )
    }

    @Test("Se perdonan los espacios de los dedos gordos")
    func conEspacios() {
        #expect(
            DireccionServidor.normalizar("  192.168.0.101  ")?.absoluteString
                == "http://192.168.0.101:4000/api"
        )
    }

    @Test("A un dominio NO se le mete el puerto 4000")
    func dominioSinPuerto() {
        // Nadie publica un sitio en el 4000. Meterle el puerto rompería la única forma en que
        // esto podría apuntar a un servidor de verdad algún día.
        #expect(
            DireccionServidor.normalizar("bolsi.midominio.com")?.absoluteString
                == "http://bolsi.midominio.com/api"
        )
        #expect(
            DireccionServidor.normalizar("https://bolsi.midominio.com")?.absoluteString
                == "https://bolsi.midominio.com/api"
        )
    }

    @Test("localhost sí lleva el puerto: es la PC de casa")
    func localhostLlevaPuerto() {
        #expect(
            DireccionServidor.normalizar("localhost")?.absoluteString
                == "http://localhost:4000/api"
        )
    }

    @Test("Una ruta escrita a mano se respeta tal cual")
    func rutaPropia() {
        // Quien escribió `/api/v2` sabía lo que hacía: agregarle otro `/api` sería corregir a
        // quien tenía razón.
        #expect(
            DireccionServidor.normalizar("192.168.0.101:4000/api/v2")?.absoluteString
                == "http://192.168.0.101:4000/api/v2"
        )
    }

    @Test("Lo que no se entiende devuelve nil, no una URL inventada")
    func loIlegible() {
        #expect(DireccionServidor.normalizar("") == nil)
        #expect(DireccionServidor.normalizar("   ") == nil)
        // Sin host no hay a dónde ir. Devolver algo acá haría que la app intente conectarse a
        // una dirección que el dueño nunca escribió y el error diría cualquier cosa.
        #expect(DireccionServidor.normalizar("http://") == nil)
    }

    @Test("La consulta y el fragmento se descartan")
    func sinConsulta() {
        // Solo pueden llegar por un copiado y pegado accidental, y arrastrarlos ensuciaría cada
        // petición de la app con parámetros que nadie pidió.
        #expect(
            DireccionServidor.normalizar("http://192.168.0.101:4000/api?token=abc#x")?.absoluteString
                == "http://192.168.0.101:4000/api"
        )
    }

    @Test("Distingue una IP de un nombre")
    func reconoceIps() {
        #expect(DireccionServidor.esDireccionLocal("192.168.0.101"))
        #expect(DireccionServidor.esDireccionLocal("10.0.0.1"))
        #expect(DireccionServidor.esDireccionLocal("localhost"))
        #expect(!DireccionServidor.esDireccionLocal("bolsi.midominio.com"))
        // 300 no es un octeto válido: es un nombre raro, no una IP.
        #expect(!DireccionServidor.esDireccionLocal("300.1.2.3"))
        #expect(!DireccionServidor.esDireccionLocal("192.168.0"))
    }

    @Test("La descripción muestra la URL final, para que no haya que adivinarla")
    func descripcionLegible() {
        #expect(DireccionServidor.descripcion("192.168.0.101") == "http://192.168.0.101:4000/api")
        #expect(DireccionServidor.descripcion("") == "Dirección incompleta")
    }
}
