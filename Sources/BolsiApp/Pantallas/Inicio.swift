import SwiftUI
import BolsiCore

/// Pestaña **Inicio** del boceto.
///
/// Cuatro bloques en el orden del prototipo: cabecera, hero de saldo, cuatro accesos rápidos y
/// el par de tarjetas (Movimientos y Suscripciones).
///
/// El estado entra por parámetro y no lo busca ella: así la misma vista sirve con datos del API
/// en el teléfono y con datos de maqueta en las capturas de la CI. Es lo que permite verificar la
/// forma sin backend.
struct Inicio: View {
    @Environment(\.paleta) private var paleta
    let estado: EstadoInicio
    var onNotificaciones: () -> Void = {}
    var onSuscripciones: () -> Void = {}

    @State private var oculto = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Cabecera(estado: estado, onNotificaciones: onNotificaciones)
                    .padding(.top, EspacioBoceto.entreTarjetas)

                HeroSaldo(estado: estado, oculto: $oculto)
                    .padding(.top, 14)

                Accesos()
                    .padding(.top, EspacioBoceto.entreTarjetas)

                // Las dos tarjetas, **de la misma altura**. El boceto es un grid de CSS, donde
                // las celdas de una fila se estiran a la más alta por defecto; el Android lo
                // resuelve con `height(IntrinsicSize.Min)` en la Row. Con `.top` y sin estirar,
                // la de Movimientos quedaba más baja que la de Suscripciones y la fila se veía
                // descalzada — así salió en la primera captura.
                HStack(alignment: .top, spacing: EspacioBoceto.entreCeldas) {
                    TarjetaMovimientos(estado: estado)
                        .frame(maxHeight: .infinity)
                    TarjetaSuscripciones(estado: estado, onTap: onSuscripciones)
                        .frame(maxHeight: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, EspacioBoceto.entreCeldas)

                // Metas. Faltaba entera: el boceto la trae y el Android la construyó, así que su
                // ausencia era un hueco, no una decisión. Vacía no se pinta ni el encabezado —
                // un título "Metas" sobre nada dice que algo se rompió.
                if !estado.metas.isEmpty {
                    EncabezadoSeccion(titulo: "Metas", conteo: estado.metas.count)
                        .padding(.top, 20)

                    VStack(spacing: EspacioBoceto.entreCeldas) {
                        ForEach(estado.metas) { meta in
                            TarjetaMeta(meta: meta)
                        }
                    }
                    .padding(.top, EspacioBoceto.entreCeldas)
                }
            }
            .padding(.horizontal, EspacioBoceto.pantalla)
            .padding(.bottom, EspacioBoceto.colaNav)
        }
    }
}

// MARK: - Cabecera

private struct Cabecera: View {
    @Environment(\.paleta) private var paleta
    let estado: EstadoInicio
    let onNotificaciones: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            // Avatar con iniciales: el boceto usa un degradado suave, no un color plano.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(ColorBoceto(0xFF5A6B85)), Color(ColorBoceto(0xFF3C4759))],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 46, height: 46)
                .overlay(
                    Text(estado.iniciales)
                        .font(.system(size: TextoBoceto.cuerpo, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("¡Hola!")
                    .font(.system(size: TextoBoceto.secundario))
                    .foregroundStyle(Color(paleta.tinta2))
                Text(estado.nombre)
                    .font(.system(size: TextoBoceto.titulo, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(Color(paleta.tinta))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Campana y ajustes comparten una sola píldora, separados por una línea fina.
            HStack(spacing: 0) {
                Button(action: onNotificaciones) {
                    ZStack(alignment: .topTrailing) {
                        TrazoBoceto(d: Iconos.campana, lienzo: 20, grosor: 1.7)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(Color(paleta.tinta))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                        // El punto rojo se enciende SOLO con lo que hay que atender, no con
                        // "lo no leído": Bolsi calcula sus avisos, no los guarda.
                        if estado.hayAvisos {
                            Circle()
                                .fill(Color(paleta.rojo))
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle().strokeBorder(Color(paleta.superficie), lineWidth: 2)
                                )
                                .offset(x: -8, y: 6)
                        }
                    }
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color(paleta.linea))
                    .frame(width: 1, height: 18)

                TrazoBoceto(d: Iconos.ajustes, lienzo: 20, grosor: 1.7)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color(paleta.tinta))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
            }
            .background(
                Capsule().fill(Color(paleta.superficie))
            )
            .modifier(SombraTarjetaBoceto())
        }
    }
}

// MARK: - Hero de saldo

private struct HeroSaldo: View {
    @Environment(\.paleta) private var paleta
    let estado: EstadoInicio
    @Binding var oculto: Bool

    var body: some View {
        TarjetaBoceto(
            padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text("SALDO TOTAL")
                        .font(.system(size: TextoBoceto.eyebrow, weight: .bold))
                        .tracking(TextoBoceto.eyebrowTracking)
                        .foregroundStyle(Color(paleta.tinta2))

                    Text(estado.etiquetaMes)
                        .font(.system(size: TextoBoceto.chip, weight: .medium))
                        .foregroundStyle(Color(paleta.tinta2))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(paleta.superficie2)))

                    Spacer(minLength: 4)

                    // Los tres chevrones y la marca. Su lienzo es 22 × 11, NO cuadrado: en
                    // Android dibujarlo en una caja cuadrada lo dejó desalineado del texto.
                    HStack(spacing: 7) {
                        TrazoBoceto(d: Iconos.chevrones, lienzo: 22, grosor: 2.2, lienzoAlto: 11)
                            .frame(width: 22, height: 11)
                            .foregroundStyle(Color(paleta.tinta3))
                        Text("BOLSI")
                            .font(.system(size: TextoBoceto.eyebrow, weight: .bold))
                            .tracking(TextoBoceto.eyebrowTracking)
                            .foregroundStyle(Color(paleta.tinta2))
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    Text(oculto ? "••••••" : Dinero.monto(estado.saldo, estado.moneda))
                        .font(.system(size: TextoBoceto.saldo, weight: .heavy))
                        .tracking(TextoBoceto.saldoTracking)
                        .foregroundStyle(Color(paleta.tinta))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Button { oculto.toggle() } label: {
                        // Dos trazos: parpado + iris. Con uno solo el ojo sale como un rombo
                        // vacio — mismo bug que en Android, y volvio a aparecer en la primera
                        // captura de la CI.
                        TrazoBoceto(
                            trazos: oculto ? Iconos.ojoCerrado : Iconos.ojo,
                            lienzo: 19,
                            grosor: 1.7
                        )
                        .frame(width: 19, height: 19)
                        .foregroundStyle(Color(paleta.tinta2))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .padding(.top, 10)

                // Las cuentas en otras monedas: nunca se suman al saldo de arriba, pero
                // tampoco pueden quedar sin rastro. Ver `EstadoInicio.otrasMonedas`.
                if let otras = estado.otrasMonedas {
                    Text(otras)
                        .font(.system(size: TextoBoceto.chip, weight: .medium))
                        .foregroundStyle(Color(paleta.tinta3))
                        .padding(.top, 4)
                }

                // Ingresos y gastos del mes, **si se conocen**. Sin datos no se pinta un cero:
                // diría que este mes no entró ni salió nada, que es una afirmación y no un
                // hueco. Cuando el motivo es que los movimientos fueron en otra moneda, se
                // explica; cuando es que todavía no hubo ninguno, no hay nada que decir.
                if let neto = estado.netoMes, let ingresos = estado.ingresosMes, let gastos = estado.gastosMes {
                    HStack(spacing: 10) {
                        // El neto, sin píldora y con su signo.
                        Text((neto >= 0 ? "+ " : "− ") + Dinero.monto(abs(neto), estado.moneda))
                            .font(.system(size: TextoBoceto.secundario, weight: .bold))
                            .foregroundStyle(Color(neto >= 0 ? paleta.plataEntra : paleta.plataSale))

                        Pildora(monto: ingresos, moneda: estado.moneda, entra: true)
                        Pildora(monto: gastos, moneda: estado.moneda, entra: false)

                        Spacer(minLength: 0)
                    }
                    .padding(.top, 12)
                } else if let aviso = estado.avisoOtraMoneda {
                    Text(aviso)
                        .font(.system(size: TextoBoceto.chip, weight: .medium))
                        .foregroundStyle(Color(paleta.tinta3))
                        .padding(.top, 12)
                }
            }
        }
    }

    /// Las dos píldoras del hero: flecha, monto y su fondo tintado.
    private struct Pildora: View {
        @Environment(\.paleta) private var paleta
        let monto: Decimal
        let moneda: Moneda
        let entra: Bool

        var body: some View {
            HStack(spacing: 5) {
                TrazoBoceto(
                    d: entra ? Iconos.flechaArriba : Iconos.flechaAbajo,
                    lienzo: 10,
                    grosor: 1.9
                )
                .frame(width: 10, height: 10)
                Text(Dinero.monto(monto, moneda))
                    .font(.system(size: TextoBoceto.secundario, weight: .bold))
                    // Sin esto el monto se parte en dos lineas y la pildora crece al doble:
                    // paso en la primera captura, con "S/" arriba y "500.00" abajo.
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(Color(entra ? paleta.plataEntra : paleta.plataSale))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: RadioBoceto.pildora, style: .continuous)
                    .fill(Color(entra ? paleta.pildoraEntra : paleta.pildoraSale))
            )
        }
    }
}

// MARK: - Accesos rápidos

private struct Accesos: View {
    @Environment(\.paleta) private var paleta

    private let accesos: [(String, String)] = [
        ("Tarjetas", Iconos.tarjetas),
        ("Deudas", Iconos.deudas),
        ("Escanear", Iconos.escanear),
        ("Presupuestos", Iconos.presupuestos),
    ]

    var body: some View {
        HStack(spacing: EspacioBoceto.entreCeldas) {
            ForEach(accesos, id: \.0) { acceso in
                TarjetaBoceto(
                    radio: RadioBoceto.tarjetaChica,
                    padding: EdgeInsets(top: 13, leading: 6, bottom: 12, trailing: 6)
                ) {
                    VStack(spacing: 7) {
                        TrazoBoceto(d: acceso.1, lienzo: 20, grosor: 1.7)
                            .frame(width: 21, height: 21)
                            .foregroundStyle(Color(paleta.acento))
                        Text(acceso.0)
                            .font(.system(size: TextoBoceto.chip, weight: .medium))
                            .foregroundStyle(Color(paleta.tinta))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - El par de tarjetas

private struct TarjetaMovimientos: View {
    @Environment(\.paleta) private var paleta
    let estado: EstadoInicio

    var body: some View {
        TarjetaBoceto(radio: RadioBoceto.tarjetaChica) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Movimientos")
                        .font(.system(size: TextoBoceto.fila, weight: .bold))
                        .tracking(-0.2)
                        .foregroundStyle(Color(paleta.tinta))
                    Spacer(minLength: 4)
                    TrazoBoceto(d: Iconos.chevron, lienzo: 16, grosor: 1.9)
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color(paleta.tinta3))
                }

                // La barra apilada: cada tramo pesa lo que gastó su categoría.
                let porciones = EstadoInicio.porcionesVisibles(estado.gastoPorCategoria)
                let total = porciones.reduce(Decimal(0)) { $0 + $1.monto }
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(porciones) { porcion in
                            let fraccion = total > 0
                                ? (porcion.monto / total as NSDecimalNumber).doubleValue
                                : 1.0 / Double(max(1, porciones.count))
                            RoundedRectangle(cornerRadius: RadioBoceto.barra, style: .continuous)
                                .fill(Color(porcion.color))
                                .frame(width: max(3, (geo.size.width - 2 * Double(porciones.count - 1)) * fraccion))
                        }
                    }
                }
                .frame(height: 7)
                .padding(.top, 12)

                // El total del mes solo si se conoce. Con `nil` se muestra el reparto por
                // categoría sin ponerle un total abajo: la barra sigue diciendo algo cierto.
                Text(estado.etiquetaMes + ": ")
                    .font(.system(size: TextoBoceto.secundario))
                    .foregroundStyle(Color(paleta.tinta2))
                    + Text(
                        estado.gastosMes.map { Dinero.monto($0, estado.moneda) } ?? "sin datos"
                    )
                    .font(.system(size: TextoBoceto.secundario, weight: .bold))
                    .foregroundStyle(Color(estado.gastosMes == nil ? paleta.tinta3 : paleta.tinta))
            }
        }
    }
}

private struct TarjetaSuscripciones: View {
    @Environment(\.paleta) private var paleta
    let estado: EstadoInicio
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TarjetaBoceto(radio: RadioBoceto.tarjetaChica) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Suscripciones")
                            .font(.system(size: TextoBoceto.fila, weight: .bold))
                            .tracking(-0.2)
                            .foregroundStyle(Color(paleta.tinta))
                        Spacer(minLength: 4)
                        TrazoBoceto(d: Iconos.chevron, lienzo: 16, grosor: 1.9)
                            .frame(width: 14, height: 14)
                            .foregroundStyle(Color(paleta.tinta3))
                    }

                    if estado.inicialesSuscripciones.isEmpty {
                        Text("Ninguna activa")
                            .font(.system(size: TextoBoceto.secundario))
                            .foregroundStyle(Color(paleta.tinta2))
                            .padding(.top, 14)
                    } else {
                        // Avatares solapados y el contador "+N", como el boceto.
                        HStack(spacing: -8) {
                            ForEach(Array(estado.inicialesSuscripciones.enumerated()), id: \.offset) { par in
                                Circle()
                                    .fill(Color(paleta.superficie2))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle().strokeBorder(Color(paleta.superficie), lineWidth: 2)
                                    )
                                    .overlay(
                                        Text(par.element)
                                            .font(.system(size: TextoBoceto.chip, weight: .semibold))
                                            .foregroundStyle(Color(paleta.tinta2))
                                    )
                            }
                            if estado.suscripcionesRestantes > 0 {
                                Text("+\(estado.suscripcionesRestantes)")
                                    .font(.system(size: TextoBoceto.chip, weight: .bold))
                                    .foregroundStyle(Color(paleta.tinta2))
                                    .padding(.leading, 12)
                            }
                        }
                        .padding(.top, 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Íconos

/// Los `path` del boceto que usa Inicio. Los de una sola pantalla viven con su pantalla; los que
/// se repiten en muchas subirán a un archivo común cuando aparezca el segundo uso.
enum Iconos {
    static let campana =
        "M10 3.4a4.6 4.6 0 0 0-4.6 4.6c0 3.4-1.4 4.4-1.4 4.4h12s-1.4-1-1.4-4.4A4.6 4.6 0 0 0 10 3.4z"
    static let ajustes = "M4 6.2h8.2M15.2 6.2h.8M4 13.8h4.2M11.2 13.8h4.8"
    /// 22 × 11, no cuadrado.
    static let chevrones = "M2 2l3.4 3.4L2 8.8M9 2l3.4 3.4L9 8.8M16 2l3.4 3.4L16 8.8"
    /// Parpado + iris. El boceto lo escribe como dos `<path>` en el mismo `<svg>`.
    static let ojo = [
        "M2.5 9.5S5.4 5 9.5 5s7 4.5 7 4.5-2.9 4.5-7 4.5-7-4.5-7-4.5z",
        "M7.4 9.5a2.1 2.1 0 1 0 4.2 0a2.1 2.1 0 1 0-4.2 0",
    ]
    /// Oculto: el parpado y la raya que lo cruza, sin iris.
    static let ojoCerrado = [
        "M2.5 9.5S5.4 5 9.5 5s7 4.5 7 4.5-2.9 4.5-7 4.5-7-4.5-7-4.5z",
        "M3 3l13 13",
    ]
    static let flechaArriba = "M5 8.6V1.8M2.3 4.4 5 1.7l2.7 2.7"
    static let flechaAbajo = "M5 1.8v6.8M2.3 5.9 5 8.6l2.7-2.7"
    static let tarjetas =
        "M2.8 5.8h14.4a1.2 1.2 0 0 1 1.2 1.2v6a1.2 1.2 0 0 1-1.2 1.2H2.8a1.2 1.2 0 0 1-1.2-1.2V7a1.2 1.2 0 0 1 1.2-1.2zM1.6 8.8h16.8"
    static let deudas = "M5.6 3.6h10.8v14.8l-2.7-1.8-2.7 1.8-2.7-1.8-2.7 1.8V3.6zM8.6 8h4.8M8.6 11.6h3"
    static let escanear =
        "M3 7V4.6A1.6 1.6 0 0 1 4.6 3H7M13 3h2.4A1.6 1.6 0 0 1 17 4.6V7M17 13v2.4a1.6 1.6 0 0 1-1.6 1.6H13M7 17H4.6A1.6 1.6 0 0 1 3 15.4V13"
    static let presupuestos = "M4.2 15.6V9.4M8.7 15.6V5.4M13.2 15.6v-4.4M17 15.6v-7"
    static let chevron = "M6 3.5 10.5 8 6 12.5"
}
