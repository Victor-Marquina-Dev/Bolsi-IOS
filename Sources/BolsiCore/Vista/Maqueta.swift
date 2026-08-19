import Foundation

/// Datos de maqueta, **solo** para las capturas de la CI.
///
/// > [!] Nada de acá es real, y la app lo dice en pantalla.
///
/// El simulador de la nube no llega al backend de la LAN del dueño, así que sin estos datos las
/// capturas mostrarían la pantalla de login y no habría nada que comparar contra el boceto. Pero
/// hay una regla de la agencia que aplica justo acá: **los textos inventados se leen como
/// reales** (antipatrón #21), y una captura con un saldo verosímil es exactamente el tipo de cosa
/// sobre la que alguien decide creyendo que son sus números.
///
/// Por eso dos precauciones que no se negocian:
///
/// 1. Los valores son **redondos y obviamente de ejemplo**, no verosímiles. Un `S/ 1,234.56` se
///    confunde con un saldo; un `S/ 1,000.00` no.
/// 2. La app pinta un sello **MAQUETA** encima cuando usa esto (ver `Raiz`). Una captura sin ese
///    sello es una captura con datos de verdad, y se distinguen de un vistazo.
public enum Maqueta {

    /// Colores de la paleta del boceto (`CATCOLORS`), que es de donde el prototipo saca los
    /// suyos: así la barra apilada se ve como en el diseño aunque los montos sean de ejemplo.
    private static let colores: [ColorBoceto] = [
        ColorBoceto(0xFF3E8BFF), ColorBoceto(0xFF34C759), ColorBoceto(0xFFFF8A34),
        ColorBoceto(0xFFAF52DE), ColorBoceto(0xFFFF3B30), ColorBoceto(0xFF32ADE6),
    ]

    public static let inicio = EstadoInicio(
        nombre: "Nombre de ejemplo",
        iniciales: "NE",
        hayAvisos: true,
        saldo: Decimal(string: "1000.00")!,
        moneda: "PEN",
        ingresosMes: Decimal(string: "500.00")!,
        gastosMes: Decimal(string: "300.00")!,
        etiquetaMes: EstadoInicio.etiquetaDelMes(),
        gastoPorCategoria: [
            PorcionCategoria(id: "1", nombre: "Categoría 1", color: colores[0], monto: 100),
            PorcionCategoria(id: "2", nombre: "Categoría 2", color: colores[1], monto: 80),
            PorcionCategoria(id: "3", nombre: "Categoría 3", color: colores[2], monto: 60),
            PorcionCategoria(id: "4", nombre: "Categoría 4", color: colores[3], monto: 30),
            PorcionCategoria(id: "5", nombre: "Categoría 5", color: colores[4], monto: 20),
            PorcionCategoria(id: "6", nombre: "Categoría 6", color: colores[5], monto: 10),
        ],
        inicialesSuscripciones: ["A", "B", "C", "D"],
        suscripcionesRestantes: 2
    )
}
