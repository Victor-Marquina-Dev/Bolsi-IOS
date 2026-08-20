import SwiftUI
import BolsiCore

/// La carcasa del boceto: el contenido de la pestaña y la barra flotante encima.
///
/// Es el equivalente de `BocetoHost` del Android, y de ahí se trae una lección ya pagada: el
/// boceto distingue **tres** capas y conviene no confundirlas desde el principio.
///
/// | Capa | Qué hace con la barra y los flotantes | Ejemplo |
/// |---|---|---|
/// | Pestaña | Las conserva | Inicio, Cuentas |
/// | Pantalla (`s.tab`) | Las conserva | Historial |
/// | Overlay (`s.overlay`, `z-index:50`) | Las **tapa** | Suscripciones, Deudas |
///
/// En Android eso se descubrió a mitad de camino y hubo que agregar los huecos de a uno. Acá ya
/// están los tres previstos.
struct Raiz: View {
    @Environment(\.paleta) private var paleta
    @EnvironmentObject private var sesion: EstadoSesion
    @StateObject private var modeloInicio = ModeloInicio()
    @State private var pestana: PestanaBoceto = Fuente.pestanaInicial

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(paleta.fondo).ignoresSafeArea()

            contenido
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            BarraBoceto(seleccionada: $pestana)
                .padding(.bottom, EspacioBoceto.navAbajo)

            // Sello de maqueta. Una captura CON este sello son datos de ejemplo; una captura sin
            // él son datos de verdad. Sin esta marca, un saldo inventado en una captura se lee
            // como el saldo del dueño — es el antipatrón #21 de la agencia, y acá aplica de lleno
            // porque estas capturas son justamente lo que él va a mirar para decidir.
            if Fuente.esMaqueta {
                Text("MAQUETA")
                    .font(.system(size: TextoBoceto.nav, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(ColorBoceto(0xFFFF9F0A))))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 2)
            }
        }
        .task {
            guard Fuente.demo else { return }
            await recorrerSolo()
        }
    }

    /// Recorre las cinco pestañas solo, para el video de la CI. Ver `Fuente.demo`.
    private func recorrerSolo() async {
        // Empieza por la que sigue a la actual y da una vuelta completa. Se usa la lista de
        // pestañas y no un índice a mano: si mañana hay una sexta, entra sola.
        let todas = PestanaBoceto.allCases
        guard let desde = todas.firstIndex(of: pestana) else { return }

        for paso in 1...todas.count {
            try? await Task.sleep(for: .seconds(Fuente.segundosPorPestana))
            guard !Task.isCancelled else { return }
            withAnimation(.bocetoEstandar(MovimientoBoceto.navMs)) {
                pestana = todas[(desde + paso) % todas.count]
            }
        }
    }

    @ViewBuilder
    private var contenido: some View {
        switch pestana {
        case .inicio:
            inicio
        case .cuentas, .bolsi, .analisis, .agenda:
            // Andamio: cada pestaña se reemplaza por su pantalla real, una por una, en el mismo
            // orden que el Android (Inicio → Cuentas → Bolsi → Análisis → Agenda). A propósito
            // NO se pinta una pantalla con datos inventados para que "parezca" terminada: dice
            // qué falta y ya.
            Andamio(pestana: pestana)
        }
    }

    /// Inicio con datos de verdad, o con la maqueta cuando corre en la CI.
    @ViewBuilder
    private var inicio: some View {
        if Fuente.esMaqueta {
            Inicio(estado: Fuente.inicioDeMaqueta)
        } else {
            switch modeloInicio.situacion {
            case .cargando:
                Cargando()
                    // `.task` y no `.onAppear`: se cancela solo si la vista se va antes de que
                    // llegue la respuesta, y no vuelve a dispararse al cambiar de pestaña y
                    // regresar. En Android eso hizo falta resolverlo con un bus de refresco
                    // aparte porque los ViewModels sobreviven al cambio de pestaña.
                    .task { modeloInicio.cargar(sesion) }

            case let .listo(estado):
                Inicio(estado: estado)

            case let .falla(mensaje):
                Falla(mensaje: mensaje) { modeloInicio.cargar(sesion) }
            }
        }
    }
}

/// Mientras no llegó la respuesta. **Sin ninguna cifra en pantalla**: un cero dibujado acá se
/// lee como un saldo de cero, que es la mentira que el Historial del Android ya contó una vez.
private struct Cargando: View {
    @Environment(\.paleta) private var paleta

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView()
                .tint(Color(paleta.tinta2))
            Text("Buscando tus datos…")
                .font(.system(size: TextoBoceto.secundario, weight: .medium))
                .foregroundStyle(Color(paleta.tinta2))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, EspacioBoceto.colaNav)
    }
}

/// Cuando no se pudo cargar. El mensaje lo redacta el backend —o `ClienteApi` si fue la red— y
/// se muestra tal cual, con un botón para volver a intentar.
private struct Falla: View {
    @Environment(\.paleta) private var paleta
    let mensaje: String
    let reintentar: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(mensaje)
                .font(.system(size: TextoBoceto.cuerpo, weight: .medium))
                .foregroundStyle(Color(paleta.tinta2))
                .multilineTextAlignment(.center)

            Button(action: reintentar) {
                Text("Volver a intentar")
                    .font(.system(size: TextoBoceto.secundario, weight: .bold))
                    .foregroundStyle(Color(paleta.acentoTinta))
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(
                        Capsule().fill(Color(paleta.superficie))
                    )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, EspacioBoceto.pantalla)
        .padding(.bottom, EspacioBoceto.colaNav)
    }
}

/// Marcador de una pestaña todavía sin construir.
private struct Andamio: View {
    @Environment(\.paleta) private var paleta
    let pestana: PestanaBoceto

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            TrazoBoceto(d: pestana.trazo, lienzo: 22, grosor: 1.6)
                .frame(width: 34, height: 34)
                .foregroundStyle(Color(paleta.tinta3))
            Text(pestana.etiqueta)
                .font(.system(size: TextoBoceto.titulo, weight: .bold))
                .foregroundStyle(Color(paleta.tinta))
            Text("Esta pestaña se construye en el tramo siguiente.")
                .font(.system(size: TextoBoceto.secundario))
                .foregroundStyle(Color(paleta.tinta2))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, EspacioBoceto.pantalla)
        .padding(.bottom, EspacioBoceto.colaNav)
    }
}
