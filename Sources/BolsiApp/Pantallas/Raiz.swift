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
    }

    @ViewBuilder
    private var contenido: some View {
        switch pestana {
        case .inicio:
            Inicio(estado: Fuente.inicio)
        case .cuentas, .bolsi, .analisis, .agenda:
            // Andamio: cada pestaña se reemplaza por su pantalla real, una por una, en el mismo
            // orden que el Android (Inicio → Cuentas → Bolsi → Análisis → Agenda). A propósito
            // NO se pinta una pantalla con datos inventados para que "parezca" terminada: dice
            // qué falta y ya.
            Andamio(pestana: pestana)
        }
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
