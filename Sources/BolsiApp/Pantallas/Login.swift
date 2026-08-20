import SwiftUI
import BolsiCore

/// Entrar a Bolsi.
///
/// **El boceto no trae esta pantalla**: el prototipo empieza con la sesión ya abierta. Así que
/// no hay diseño aprobado que copiar, y por eso esta pantalla no invita nada nuevo — se arma
/// entera con los tokens que el dueño ya aprobó (`PaletaBoceto`, `RadioBoceto`, `TextoBoceto`) y
/// con los mismos gestos que el resto de la app. Es deliberadamente sobria: el Android tomó la
/// misma decisión ("mínima y funcional a propósito... que FUNCIONE por sobre el diseño") y no
/// pasó por el Designer.
///
/// ## El campo de servidor
///
/// Está acá y no escondido en Ajustes porque **sin él la app no sirve para nada**. El backend
/// corre en la PC de casa, con una IP que reparte el router y que cambia; si esa dirección
/// estuviera compilada adentro, cada cambio de IP costaría una vuelta entera por la Mac de la
/// nube. Va plegado para no ser lo primero que se ve, y se abre de un toque.
struct Login: View {
    @Environment(\.paleta) private var paleta
    @EnvironmentObject private var sesion: EstadoSesion

    @State private var email = ""
    @State private var password = ""
    @State private var verServidor = false
    @FocusState private var foco: CampoLogin?

    /// Ocho caracteres es el mínimo del backend. Se comprueba acá para no gastar un viaje de red
    /// en algo que va a rebotar seguro — pero el mensaje de un rechazo real lo sigue redactando
    /// el servidor.
    private var puedeEntrar: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 8
            && !sesion.entrando
    }

    var body: some View {
        // `GeometryReader` para saber el alto visible y centrar el bloque.
        //
        // Sin esto queda pegado arriba con media pantalla vacía abajo, que es como salió en la
        // primera captura. Y no se puede resolver con `maxHeight: .infinity` adentro del
        // `ScrollView`: **un ScrollView mide su contenido con alto no acotado**, así que
        // `.infinity` no tiene contra qué expandirse. Es el mismo mecanismo que costó dos horas
        // en el `Popup` de Android — antipatrón #22 de la agencia, otro contenedor, misma
        // trampa.
        GeometryReader { geo in
            ScrollView {
                contenido(altoVisible: geo.size.height)
            }
            .background(Color(paleta.fondo).ignoresSafeArea())
        }
        .animation(.bocetoEntrada(), value: sesion.error)
        .animation(.bocetoEstandar(), value: verServidor)
    }

    private func contenido(altoVisible: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)

            marca

            Text("Entrá a tu Bolsi")
                .font(.system(size: TextoBoceto.saldo, weight: .heavy))
                .tracking(TextoBoceto.saldoTracking)
                .foregroundStyle(Color(paleta.tinta))
                .padding(.top, 22)

            Text("Tus cuentas, tus bolsis y lo que se viene este mes.")
                .font(.system(size: TextoBoceto.secundario, weight: .medium))
                .foregroundStyle(Color(paleta.tinta2))
                .padding(.top, 6)

            CampoTexto(
                etiqueta: "CORREO",
                texto: $email,
                marcador: "vos@correo.com",
                foco: $foco,
                propio: .email,
                esCorreo: true
            )
            .padding(.top, 28)

            CampoTexto(
                etiqueta: "CONTRASEÑA",
                texto: $password,
                // NO puntos como marcador. En la primera captura el campo se leia como
                // si ya tuviera una contrasena escrita. Y este texto hace doble trabajo:
                // explica por que el boton sigue apagado.
                marcador: "Mínimo 8 caracteres",
                foco: $foco,
                propio: .password,
                esSecreto: true
            )
            .padding(.top, 10)
            .onSubmit(entrar)

            if let error = sesion.error {
                // El texto lo escribe el backend y se muestra tal cual: si él explica por
                // qué rechazó algo, traducirlo de nuevo acá solo agrega una versión que se
                // desincroniza.
                Text(error)
                    .font(.system(size: TextoBoceto.secundario, weight: .semibold))
                    .foregroundStyle(Color(paleta.rojo))
                    .padding(.top, 12)
                    .transition(.opacity)
            }

            botonEntrar
                .padding(.top, 20)

            servidorPlegado
                .padding(.top, 24)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // `minHeight` y no `height`: con el teclado abierto el contenido tiene que poder
        // crecer y desplazarse, no quedar recortado a la altura de la pantalla.
        .frame(minHeight: altoVisible)
        .padding(.horizontal, EspacioBoceto.pantalla + 6)
    }

    // MARK: - Piezas

    /// Los tres chevrones y la palabra, igual que el hero de Inicio. Es lo único de marca que el
    /// boceto define, así que es lo que corresponde usar acá.
    private var marca: some View {
        HStack(spacing: 9) {
            TrazoBoceto(d: Iconos.chevrones, lienzo: 22, grosor: 2.2, lienzoAlto: 11)
                .frame(width: 28, height: 14)
                .foregroundStyle(Color(paleta.acentoTinta))
            Text("BOLSI")
                .font(.system(size: TextoBoceto.header, weight: .bold))
                .tracking(TextoBoceto.eyebrowTracking + 1)
                .foregroundStyle(Color(paleta.tinta))
        }
    }

    private var botonEntrar: some View {
        Button(action: entrar) {
            HStack(spacing: 8) {
                if sesion.entrando {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
                Text(sesion.entrando ? "Entrando…" : "Entrar")
                    .font(.system(size: TextoBoceto.fila, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            // Alto fijo y fuera de cualquier contenedor que pueda apretarlo. En Android el botón
            // de guardar quedó en 17 dp por estar dentro de un `Popup`, que mide con alto
            // infinito, y costó dos horas: el antipatrón #22 de la agencia.
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: RadioBoceto.pastilla, style: .continuous)
                    .fill(Color(paleta.acento).opacity(puedeEntrar ? 1 : 0.4))
            )
        }
        .buttonStyle(.plain)
        .disabled(!puedeEntrar)
    }

    private var servidorPlegado: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                verServidor.toggle()
                if verServidor { foco = .servidor }
            } label: {
                HStack(spacing: 7) {
                    Text("SERVIDOR")
                        .font(.system(size: TextoBoceto.eyebrow, weight: .bold))
                        .tracking(TextoBoceto.eyebrowTracking)
                        .foregroundStyle(Color(paleta.tinta2))
                    Text(sesion.direccion)
                        .font(.system(size: TextoBoceto.chip, weight: .medium))
                        .foregroundStyle(Color(paleta.tinta3))
                        .lineLimit(1)
                    TrazoBoceto(d: Iconos.chevron, lienzo: 16, grosor: 1.7)
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Color(paleta.tinta3))
                        .rotationEffect(.degrees(verServidor ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if verServidor {
                CampoTexto(
                    etiqueta: nil,
                    texto: $sesion.direccion,
                    marcador: DireccionServidor.sugerida,
                    foco: $foco,
                    propio: .servidor,
                    esUrl: true
                )
                .padding(.top, 10)

                // Se muestra la URL completa a la que va a pegar. Escribir "192.168.0.101" y no
                // saber si eso significa `http` o `https`, con qué puerto o con qué ruta, es
                // exactamente donde se pierde media hora buscando un problema que no existe.
                Text(DireccionServidor.descripcion(sesion.direccion))
                    .font(.system(size: TextoBoceto.chip, weight: .medium))
                    .foregroundStyle(Color(paleta.tinta3))
                    .padding(.top, 6)

                Text("La PC con Bolsi tiene que estar encendida y en la misma red WiFi.")
                    .font(.system(size: TextoBoceto.chip))
                    .foregroundStyle(Color(paleta.tinta3))
                    .padding(.top, 4)
            }
        }
    }

    private func entrar() {
        guard puedeEntrar else { return }
        foco = nil
        Task { await sesion.iniciarSesion(email: email, password: password) }
    }
}

// MARK: - Campo

/// Cuál de los tres campos tiene el teclado.
enum CampoLogin { case email, password, servidor }

/// Un campo de texto con la piel del boceto: superficie, radio de chip y rótulo arriba.
///
/// **El foco entra como parámetro y se aplica adentro, sobre el `TextField`.** Puesto por fuera
/// —`CampoTexto(...).focused(...)`— no funciona: `.focused` marca la vista a la que se aplica
/// como destino del foco, y una `VStack` no puede recibirlo. El teclado nunca se movería al
/// campo pedido, y el síntoma sería un campo de servidor que se abre pero no se puede escribir
/// sin tocarlo a mano.
private struct CampoTexto: View {
    @Environment(\.paleta) private var paleta
    let etiqueta: String?
    @Binding var texto: String
    let marcador: String
    var foco: FocusState<CampoLogin?>.Binding
    let propio: CampoLogin
    var esCorreo = false
    var esSecreto = false
    var esUrl = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let etiqueta {
                Text(etiqueta)
                    .font(.system(size: TextoBoceto.eyebrow, weight: .bold))
                    .tracking(TextoBoceto.eyebrowTracking)
                    .foregroundStyle(Color(paleta.tinta2))
            }

            campo
                .font(.system(size: TextoBoceto.fila, weight: .medium))
                .foregroundStyle(Color(paleta.tinta))
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: RadioBoceto.chip, style: .continuous)
                        .fill(Color(paleta.superficie))
                )
                // Autocorrección apagada en los tres: un correo con la primera en mayúscula o
                // una IP "corregida" a una palabra es la clase de fallo que se lee como
                // "contraseña incorrecta" y manda a buscar el problema donde no está.
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private var campo: some View {
        if esSecreto {
            SecureField(marcador, text: $texto)
                .focused(foco, equals: propio)
        } else {
            TextField(marcador, text: $texto)
                .focused(foco, equals: propio)
                .keyboardType(esCorreo ? .emailAddress : (esUrl ? .URL : .default))
                .textContentType(esCorreo ? .emailAddress : nil)
        }
    }
}
