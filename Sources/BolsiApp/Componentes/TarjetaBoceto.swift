import SwiftUI
import BolsiCore

/// El molde de tarjeta del BOCETO.
///
/// En el prototipo es literalmente esto, repetido **36 veces**:
/// `background:var(--surface); border-radius:22px; padding:13px 14px;
/// box-shadow:0 1px 3px rgba(46,57,71,.06)`. Y esa sombra sola aparece **91 veces**. Es la pieza
/// que sostiene casi todas las pantallas, así que se escribe una vez.
///
/// **La sombra sale exacta acá y en Android costó trabajo.** `Modifier.shadow` de Compose no
/// acepta desplazamiento ni color propio, así que hubo que dibujarla a mano con un
/// `BlurMaskFilter`. En SwiftUI `.shadow(color:radius:x:y:)` los toma directo. El radio va a la
/// mitad del `blur-radius` del CSS porque son escalas distintas: 3 px de CSS son ~1,5 de radio.
struct TarjetaBoceto<Contenido: View>: View {
    @Environment(\.paleta) private var paleta

    var radio: Double = RadioBoceto.tarjeta
    var padding: EdgeInsets = EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14)
    var conBorde: Bool = false
    @ViewBuilder var contenido: Contenido

    var body: some View {
        contenido
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radio, style: .continuous)
                    .fill(Color(paleta.superficie))
            )
            .overlay(
                conBorde
                    ? RoundedRectangle(cornerRadius: radio, style: .continuous)
                        .strokeBorder(Color(paleta.linea), lineWidth: 1)
                    : nil
            )
            .modifier(SombraTarjetaBoceto())
    }
}

/// `box-shadow: 0 1px 3px rgba(46,57,71,.06)`.
///
/// **Es el mismo color en los dos temas**, porque el prototipo no lo cambia: su variable de
/// sombra no depende de `dark`. Sobre el fondo negro del tema oscuro queda casi invisible, y así
/// debe ser — ahí las tarjetas se separan del fondo porque su superficie es más clara, no por la
/// sombra.
struct SombraTarjetaBoceto: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(
            color: Color(ColorBoceto(0xFF2E3947).conAlfa(0.06)),
            radius: 1.5,
            x: 0,
            y: 1
        )
    }
}
