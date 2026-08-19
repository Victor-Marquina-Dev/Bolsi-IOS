import Foundation

/// Un comando de trazo, ya resuelto a coordenadas **absolutas** y sin arcos.
///
/// El renderizador solo tiene que dibujar líneas y bézieres cúbicas: toda la traducción
/// —comandos relativos, atajos, arcos elípticos— se hace acá, donde se puede testear.
public enum ComandoTrazo: Sendable, Equatable {
    case mover(x: Double, y: Double)
    case linea(x: Double, y: Double)
    case curva(x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double)
    case cerrar
}

/// Lee el atributo `d` de un `<path>` de SVG.
///
/// **Por qué esto vive en el núcleo y no en la vista.** En el Android este parser vino de
/// `androidx` y aun así dio dos bugs que solo se vieron mirando la pantalla: se dibujaba
/// **un solo** `path` de los varios que tiene un ícono (el ojo salía como un rombo sin pupila)
/// y se escalaba por el lado corto en lienzos no cuadrados (los chevrones de "BOLSI" quedaban
/// desalineados). Acá cada caso lleva test y se descubre en un segundo, no en una captura que
/// tarda diez minutos en volver de la nube.
///
/// Soporta lo que el boceto usa: `M m L l H h V v C c S s Q q A a Z z`. Los arcos se convierten
/// a bézieres con la parametrización por centro de la especificación de SVG, así que un
/// `<circle>` escrito como dos arcos —que es cómo se traducen los círculos del prototipo— sale
/// redondo de verdad.
public struct TrazoSvg: Sendable {

    public let comandos: [ComandoTrazo]

    public init(_ d: String) {
        self.comandos = TrazoSvg.parsear(d)
    }

    // MARK: - Lectura

    private static func parsear(_ d: String) -> [ComandoTrazo] {
        var salida: [ComandoTrazo] = []
        var actual = (x: 0.0, y: 0.0)
        var inicio = (x: 0.0, y: 0.0)
        var ultimoControl: (x: Double, y: Double)?
        var letraPrevia: Character = " "

        var indice = d.startIndex
        var letra: Character = " "

        func numeros(_ cantidad: Int) -> [Double]? {
            var valores: [Double] = []
            while valores.count < cantidad {
                guard let n = leerNumero(d, &indice) else { return nil }
                valores.append(n)
            }
            return valores
        }

        while indice < d.endIndex {
            saltarSeparadores(d, &indice)
            guard indice < d.endIndex else { break }

            let caracter = d[indice]
            if caracter.isLetter {
                letra = caracter
                indice = d.index(after: indice)
            } else {
                // Un comando repetido sin volver a escribir la letra: en `M 4 9 11 4` el
                // segundo par es una LÍNEA, no otro movimiento. Saltarse esta regla es lo que
                // convierte un ícono en un borrón.
                letra = (letraPrevia == "M") ? "L" : (letraPrevia == "m" ? "l" : letraPrevia)
            }

            switch letra {
            case "M", "m":
                guard let v = numeros(2) else { return salida }
                actual = letra == "M" ? (v[0], v[1]) : (actual.x + v[0], actual.y + v[1])
                inicio = actual
                salida.append(.mover(x: actual.x, y: actual.y))
                ultimoControl = nil

            case "L", "l":
                guard let v = numeros(2) else { return salida }
                actual = letra == "L" ? (v[0], v[1]) : (actual.x + v[0], actual.y + v[1])
                salida.append(.linea(x: actual.x, y: actual.y))
                ultimoControl = nil

            case "H", "h":
                guard let v = numeros(1) else { return salida }
                actual.x = letra == "H" ? v[0] : actual.x + v[0]
                salida.append(.linea(x: actual.x, y: actual.y))
                ultimoControl = nil

            case "V", "v":
                guard let v = numeros(1) else { return salida }
                actual.y = letra == "V" ? v[0] : actual.y + v[0]
                salida.append(.linea(x: actual.x, y: actual.y))
                ultimoControl = nil

            case "C", "c":
                guard let v = numeros(6) else { return salida }
                let base = letra == "C" ? (0.0, 0.0) : (actual.x, actual.y)
                let c1 = (base.0 + v[0], base.1 + v[1])
                let c2 = (base.0 + v[2], base.1 + v[3])
                let fin = (base.0 + v[4], base.1 + v[5])
                salida.append(.curva(x1: c1.0, y1: c1.1, x2: c2.0, y2: c2.1, x: fin.0, y: fin.1))
                ultimoControl = c2
                actual = fin

            case "S", "s":
                guard let v = numeros(4) else { return salida }
                let base = letra == "S" ? (0.0, 0.0) : (actual.x, actual.y)
                // El primer control es el reflejo del anterior; si no hubo, es el punto actual.
                let reflejo = ultimoControl.map { (2 * actual.x - $0.x, 2 * actual.y - $0.y) }
                    ?? (actual.x, actual.y)
                let c2 = (base.0 + v[0], base.1 + v[1])
                let fin = (base.0 + v[2], base.1 + v[3])
                salida.append(.curva(x1: reflejo.0, y1: reflejo.1, x2: c2.0, y2: c2.1, x: fin.0, y: fin.1))
                ultimoControl = c2
                actual = fin

            case "Q", "q":
                guard let v = numeros(4) else { return salida }
                let base = letra == "Q" ? (0.0, 0.0) : (actual.x, actual.y)
                let c = (base.0 + v[0], base.1 + v[1])
                let fin = (base.0 + v[2], base.1 + v[3])
                // Cuadrática a cúbica: los controles van a dos tercios del control único.
                let c1 = (actual.x + 2.0 / 3 * (c.0 - actual.x), actual.y + 2.0 / 3 * (c.1 - actual.y))
                let c2 = (fin.0 + 2.0 / 3 * (c.0 - fin.0), fin.1 + 2.0 / 3 * (c.1 - fin.1))
                salida.append(.curva(x1: c1.0, y1: c1.1, x2: c2.0, y2: c2.1, x: fin.0, y: fin.1))
                ultimoControl = c
                actual = fin

            case "A", "a":
                guard let v = numeros(7) else { return salida }
                let fin = letra == "A" ? (v[5], v[6]) : (actual.x + v[5], actual.y + v[6])
                salida.append(contentsOf: arcoACurvas(
                    desde: actual,
                    hasta: fin,
                    rx: v[0], ry: v[1],
                    rotacionGrados: v[2],
                    arcoGrande: v[3] != 0,
                    barrido: v[4] != 0
                ))
                actual = fin
                ultimoControl = nil

            case "Z", "z":
                salida.append(.cerrar)
                actual = inicio
                ultimoControl = nil

            default:
                // Letra desconocida: se ignora en vez de romper la pantalla.
                indice = d.index(after: indice)
            }

            letraPrevia = letra
        }

        return salida
    }

    // MARK: - Números

    private static func saltarSeparadores(_ d: String, _ i: inout String.Index) {
        while i < d.endIndex, d[i] == " " || d[i] == "," || d[i] == "\n" || d[i] == "\t" || d[i] == "\r" {
            i = d.index(after: i)
        }
    }

    private static func leerNumero(_ d: String, _ i: inout String.Index) -> Double? {
        saltarSeparadores(d, &i)
        guard i < d.endIndex else { return nil }

        var texto = ""
        if d[i] == "-" || d[i] == "+" {
            texto.append(d[i])
            i = d.index(after: i)
        }
        var vioPunto = false
        while i < d.endIndex {
            let c = d[i]
            if c.isNumber {
                texto.append(c)
            } else if c == "." && !vioPunto {
                vioPunto = true
                texto.append(c)
            } else {
                // Un segundo punto arranca otro número: en SVG `1.5.5` son dos valores pegados.
                break
            }
            i = d.index(after: i)
        }
        return Double(texto)
    }

    // MARK: - Arcos

    /// Convierte un arco elíptico de SVG en bézieres cúbicas.
    ///
    /// Es la parametrización por centro del apéndice de la especificación. Se implementa
    /// completa —con radios distintos y rotación— y no solo el caso circular, porque el código
    /// es el mismo y así una elipse futura no obliga a volver acá.
    private static func arcoACurvas(
        desde: (x: Double, y: Double),
        hasta: (x: Double, y: Double),
        rx rxEntrada: Double,
        ry ryEntrada: Double,
        rotacionGrados: Double,
        arcoGrande: Bool,
        barrido: Bool
    ) -> [ComandoTrazo] {
        // Radio cero: la especificación manda tratarlo como línea recta.
        if rxEntrada == 0 || ryEntrada == 0 {
            return [.linea(x: hasta.x, y: hasta.y)]
        }
        // Mismo punto de salida y llegada: no hay arco que dibujar.
        if desde.x == hasta.x && desde.y == hasta.y {
            return []
        }

        var rx = abs(rxEntrada)
        var ry = abs(ryEntrada)
        let phi = rotacionGrados * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)

        let dx2 = (desde.x - hasta.x) / 2
        let dy2 = (desde.y - hasta.y) / 2
        let x1p = cosPhi * dx2 + sinPhi * dy2
        let y1p = -sinPhi * dx2 + cosPhi * dy2

        // Si los radios no alcanzan para unir los dos puntos, se agrandan (lo pide la spec).
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let escala = lambda.squareRoot()
            rx *= escala
            ry *= escala
        }

        let numerador = max(0, rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p)
        let denominador = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var factor = denominador == 0 ? 0 : (numerador / denominador).squareRoot()
        if arcoGrande == barrido { factor = -factor }

        let cxp = factor * rx * y1p / ry
        let cyp = -factor * ry * x1p / rx
        let cx = cosPhi * cxp - sinPhi * cyp + (desde.x + hasta.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (desde.y + hasta.y) / 2

        func angulo(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let punto = ux * vx + uy * vy
            let normas = (ux * ux + uy * uy).squareRoot() * (vx * vx + vy * vy).squareRoot()
            var a = acos(max(-1, min(1, normas == 0 ? 1 : punto / normas)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }

        let inicioAngulo = angulo(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var barridoAngulo = angulo(
            (x1p - cxp) / rx, (y1p - cyp) / ry,
            (-x1p - cxp) / rx, (-y1p - cyp) / ry
        )
        if !barrido && barridoAngulo > 0 { barridoAngulo -= 2 * .pi }
        if barrido && barridoAngulo < 0 { barridoAngulo += 2 * .pi }

        // Una bézier no aproxima bien más de un cuarto de vuelta: se parte en tramos.
        let tramos = max(1, Int(ceil(abs(barridoAngulo) / (.pi / 2))))
        let deltaTramo = barridoAngulo / Double(tramos)
        let alfa = 4.0 / 3 * tan(deltaTramo / 4)

        var salida: [ComandoTrazo] = []
        var theta = inicioAngulo

        func punto(_ t: Double) -> (Double, Double) {
            (
                cx + rx * cos(t) * cosPhi - ry * sin(t) * sinPhi,
                cy + rx * cos(t) * sinPhi + ry * sin(t) * cosPhi
            )
        }
        func derivada(_ t: Double) -> (Double, Double) {
            (
                -rx * sin(t) * cosPhi - ry * cos(t) * sinPhi,
                -rx * sin(t) * sinPhi + ry * cos(t) * cosPhi
            )
        }

        for _ in 0..<tramos {
            let theta2 = theta + deltaTramo
            let p1 = punto(theta), d1 = derivada(theta)
            let p2 = punto(theta2), d2 = derivada(theta2)

            salida.append(.curva(
                x1: p1.0 + alfa * d1.0, y1: p1.1 + alfa * d1.1,
                x2: p2.0 - alfa * d2.0, y2: p2.1 - alfa * d2.1,
                x: p2.0, y: p2.1
            ))
            theta = theta2
        }

        return salida
    }
}
