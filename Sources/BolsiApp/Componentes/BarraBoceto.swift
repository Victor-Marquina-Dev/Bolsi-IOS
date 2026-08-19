import SwiftUI
import BolsiCore

/// Las cinco pestañas del boceto (`tabDefs`), con el nombre de Bolsi para la tercera.
///
/// El boceto la llama "Conjunta"; por decisión del dueño (13/08/2026) en la interfaz se llama
/// **Bolsi**, y la palabra "bolsillito" no aparece más — el código y la API siguen diciéndolo.
enum PestanaBoceto: String, CaseIterable, Identifiable {
    case inicio, cuentas, bolsi, analisis, agenda

    var id: String { rawValue }

    var etiqueta: String {
        switch self {
        case .inicio: return "Inicio"
        case .cuentas: return "Cuentas"
        case .bolsi: return "Bolsi"
        case .analisis: return "Análisis"
        case .agenda: return "Agenda"
        }
    }

    /// El `path` SVG de cada `tabDefs` del prototipo, en lienzo 22 y trazo 1,7.
    var trazo: String {
        switch self {
        case .inicio:
            return "M4 9.6 11 4l7 5.6v7.4a1.4 1.4 0 0 1-1.4 1.4H5.4A1.4 1.4 0 0 1 4 17V9.6z"
        case .cuentas:
            return "M3 8.4 10 4.4l7 4M4.8 8.8v6.4M8.2 8.8v6.4M11.8 8.8v6.4M15.2 8.8v6.4M3.2 16.4h13.6"
        case .bolsi:
            return "M3.6 7.4h11.8a1.6 1.6 0 0 1 1.6 1.6v6.2a1.6 1.6 0 0 1-1.6 1.6H5.2a1.6 1.6 0 0 1-1.6-1.6V7.4zM3.6 7.4 13.4 4.4v3M13.4 11.8h2.6"
        case .analisis:
            return "M5 16V9.4M11 16V5.4M17 16v-4"
        case .agenda:
            return "M4.6 5.8h12.8v11.4H4.6zM4.6 9.4h12.8M8 3.6v2.6M14 3.6v2.6"
        }
    }
}

/// La barra inferior del BOCETO, con sus valores exactos:
///
/// ```
/// left:12px; right:12px; bottom:24px; height:62px; border-radius:26px;
/// background:rgba(12,14,19,.72);
/// backdrop-filter:blur(14px) saturate(140%);
/// box-shadow:0 14px 34px -10px rgba(0,0,0,.55),
///            inset 0 1px 0 rgba(255,255,255,.14),
///            inset 0 0 0 1px rgba(255,255,255,.07);
/// padding:0 6px
/// ```
///
/// **Acá el vidrio es de verdad.** En Android el `backdrop-filter` necesita API 31 y encima
/// hay que capturar a mano lo que queda detrás, así que la barra terminó con un fondo más
/// opaco para compensar. En iOS `.ultraThinMaterial` hace exactamente eso, nativo y desde
/// siempre: es una de las cosas que sale **más fiel** en esta plataforma que en la otra.
struct BarraBoceto: View {
    @Environment(\.paleta) private var paleta
    @Binding var seleccionada: PestanaBoceto

    var body: some View {
        GeometryReader { geo in
            let anchoPestana = (geo.size.width - EspacioBoceto.navPadding * 2) / 5

            ZStack(alignment: .leading) {
                // La pastilla del ítem activo (`pillStyle`): blanco al 15 %, con su borde
                // interior, y se desliza con la curva estándar en 440 ms.
                RoundedRectangle(cornerRadius: RadioBoceto.pastilla, style: .continuous)
                    .fill(.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: RadioBoceto.pastilla, style: .continuous)
                            .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                    )
                    .frame(width: anchoPestana)
                    .padding(.vertical, EspacioBoceto.pastillaInset)
                    .offset(x: EspacioBoceto.navPadding + anchoPestana * Double(indice))
                    .animation(.bocetoEstandar(MovimientoBoceto.navMs), value: seleccionada)

                HStack(spacing: 0) {
                    ForEach(PestanaBoceto.allCases) { pestana in
                        Boton(pestana: pestana, activa: pestana == seleccionada) {
                            seleccionada = pestana
                        }
                        .frame(width: anchoPestana)
                    }
                }
                .padding(.horizontal, EspacioBoceto.navPadding)
            }
        }
        .frame(height: EspacioBoceto.navAlto)
        .background(
            ZStack {
                // `backdrop-filter: blur(14px) saturate(140%)` — nativo.
                RoundedRectangle(cornerRadius: RadioBoceto.nav, style: .continuous)
                    .fill(.ultraThinMaterial)
                // El color propio de la barra encima del material: el boceto define `--tab`
                // aparte de `--surface`, no es la misma superficie que las tarjetas.
                RoundedRectangle(cornerRadius: RadioBoceto.nav, style: .continuous)
                    .fill(Color(ColorBoceto(0xB80C0E13)))
            }
        )
        // Las dos sombras interiores del boceto: la línea de luz de arriba y el borde de 1 px.
        .overlay(
            RoundedRectangle(cornerRadius: RadioBoceto.nav, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.14), .white.opacity(0.07)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: RadioBoceto.nav, style: .continuous))
        // `0 14px 34px -10px rgba(0,0,0,.55)`
        .shadow(color: .black.opacity(0.55), radius: 17, x: 0, y: 14)
        .padding(.horizontal, EspacioBoceto.navLateral)
    }

    private var indice: Int {
        PestanaBoceto.allCases.firstIndex(of: seleccionada) ?? 0
    }

    /// Un ítem: ícono de 21 px y su etiqueta de 9,5 px, que engorda cuando está activo.
    private struct Boton: View {
        let pestana: PestanaBoceto
        let activa: Bool
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(spacing: 3) {
                    TrazoBoceto(d: pestana.trazo, lienzo: 22, grosor: 1.7)
                        .frame(width: 21, height: 21)
                    Text(pestana.etiqueta)
                        .font(.system(size: TextoBoceto.nav, weight: activa ? .bold : .medium))
                        .tracking(-0.15)
                        .lineLimit(1)
                }
                .foregroundStyle(activa ? .white : .white.opacity(0.55))
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.bocetoEstandar(MovimientoBoceto.tinteMs), value: activa)
        }
    }
}
