// swift-tools-version: 6.0
import PackageDescription

/// Paquete de **Bolsi iOS**, partido en dos a propósito.
///
/// `BolsiCore` no importa SwiftUI ni UIKit: son modelos, cliente del API, formato de
/// plata y las reglas de negocio. Eso hace que **compile y se testee en Windows** con el
/// toolchain oficial de swift.org, que es la única forma de verificar algo de verdad sin
/// una Mac a mano. `BolsiApp` (las pantallas) vive fuera del paquete, en el target de
/// Xcode que genera XcodeGen — ahí sí hace falta macOS.
///
/// La regla que sostiene todo esto: **si algo se puede decidir sin pantalla, va en
/// `BolsiCore` y lleva test.** Cada regla que quede en la vista es una regla que en este
/// entorno nadie puede comprobar.
let package = Package(
    name: "BolsiCore",
    // macOS entra en la lista aunque la app sea solo de iPhone: `swift test` en la Mac de
    // la CI compila para el **host**, y sin un mínimo declarado SwiftPM apunta a macOS 10.13,
    // donde el framework de testing de Swift 6 no existe. Fue lo que tiró la primera corrida.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BolsiCore", targets: ["BolsiCore"]),
    ],
    targets: [
        .target(name: "BolsiCore", path: "Sources/BolsiCore"),
        .testTarget(name: "BolsiCoreTests", dependencies: ["BolsiCore"], path: "Tests/BolsiCoreTests"),
    ]
)
