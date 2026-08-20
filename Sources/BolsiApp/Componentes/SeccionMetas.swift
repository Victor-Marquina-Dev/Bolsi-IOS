import SwiftUI
import BolsiCore

/// Encabezado de sección del boceto: título, contador en burbuja y un botón redondo.
///
/// Medidas del prototipo: título 18px/700 con `letter-spacing:-0.3`, burbuja de 22 con el acento
/// al 16%, botón de 26 sobre `superficie`.
struct EncabezadoSeccion: View {
    @Environment(\.paleta) private var paleta
    let titulo: String
    var conteo: Int?
    var icono: String = Iconos.chevron
    var accion: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 9) {
                Text(titulo)
                    .font(.system(size: TextoBoceto.titulo, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(Color(paleta.tinta))
                    .lineLimit(1)

                if let conteo {
                    Text("\(conteo)")
                        .font(.system(size: TextoBoceto.secundario, weight: .heavy))
                        .foregroundStyle(Color(paleta.acentoTinta))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color(paleta.acento.conAlfa(0.16))))
                }
            }

            Spacer(minLength: 4)

            Button(action: accion) {
                TrazoBoceto(d: icono, lienzo: 14, grosor: 1.9)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color(paleta.tinta2))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color(paleta.superficie)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }
}

/// Tarjeta de meta: cuadradito con la inicial, nombre, montos, anillo y barra.
struct TarjetaMeta: View {
    @Environment(\.paleta) private var paleta
    let meta: MetaUi

    /// El avance se anima al aparecer, como en el boceto (800 ms). Arranca en cero para que el
    /// anillo se dibuje llenándose y no aparezca ya lleno.
    @State private var avance: Double = 0

    var body: some View {
        TarjetaBoceto(
            radio: RadioBoceto.tarjetaChica,
            padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        ) {
            HStack(spacing: 12) {
                Text(meta.inicial)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(meta.color))
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(meta.color.conAlfa(0.14)))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(meta.nombre)
                        .font(.system(size: TextoBoceto.fila, weight: .semibold))
                        .foregroundStyle(Color(paleta.tinta))
                        .lineLimit(1)

                    // El ahorrado en tinta fuerte y el objetivo en tinta suave: el boceto
                    // distingue lo que ya se logró de la referencia.
                    (
                        Text(meta.ahorrado)
                            .font(.system(size: TextoBoceto.secundario, weight: .semibold))
                            .foregroundColor(Color(paleta.tinta))
                            + Text(" de \(meta.objetivo)")
                            .font(.system(size: TextoBoceto.secundario))
                            .foregroundColor(Color(paleta.tinta2))
                    )
                    .lineLimit(1)
                }

                Spacer(minLength: 0)

                AnilloMeta(avance: avance, porcentaje: meta.porcentaje, color: meta.color)
            }

            BarraAvance(avance: avance, color: meta.color)
                .padding(.top, 9)

            if let falta = meta.falta {
                Text(falta)
                    .font(.system(size: TextoBoceto.chip))
                    .foregroundStyle(Color(paleta.tinta2))
                    .padding(.top, 6)
            }
        }
        .onAppear {
            withAnimation(.bocetoEstandar(MovimientoBoceto.progresoMs)) {
                avance = meta.fraccion
            }
        }
    }
}

/// El anillo de 44 con el porcentaje al centro.
///
/// El boceto lo hace con `stroke-dasharray` sobre un `<circle r="20">` en lienzo 48, con el
/// `<svg>` rotado −90°: **empieza arriba y avanza en horario**. En SwiftUI eso es un `trim` sobre
/// un círculo rotado −90°, que es exactamente la misma construcción.
private struct AnilloMeta: View {
    @Environment(\.paleta) private var paleta
    let avance: Double
    let porcentaje: Int
    let color: ColorBoceto

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(paleta.superficie2), lineWidth: 5)
            Circle()
                .trim(from: 0, to: avance)
                .stroke(Color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(porcentaje)%")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Color(paleta.tinta))
                // Un 100% no puede empujar el anillo ni cortarse: el texto se encoge antes.
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        // 44 de anillo dentro del lienzo de 48 del boceto: el trazo de 5 se dibuja centrado
        // sobre el borde, así que la caja tiene que dejarle 2,5 de cada lado.
        .frame(width: 39, height: 39)
        .padding(2.5)
    }
}

/// La barra de 5 con radio 3 sobre `superficie2`.
private struct BarraAvance: View {
    @Environment(\.paleta) private var paleta
    let avance: Double
    let color: ColorBoceto

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(paleta.superficie2))
                Capsule()
                    .fill(Color(color))
                    // `max(0, …)` porque un ancho negativo hace que SwiftUI se queje en consola,
                    // y con avance 0 el cálculo puede dar un −0 por el redondeo.
                    .frame(width: max(0, geo.size.width * min(max(avance, 0), 1)))
            }
        }
        .frame(height: 5)
    }
}
