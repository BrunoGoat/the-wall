import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/math3.dart';
import '../core/rng.dart';
import '../engine/solids.dart';
import '../model/board_slots.dart';
import '../model/findings.dart';

/// El tablón de la plaza, medido.
///
/// Esto no dibuja nada: dice dónde está cada cosa en el mundo. Sale de las
/// medidas del modelo de la plaza (`NoticeBoard` en `engine/solids.dart`) —
/// dos postes, una plancha, un tejadito a dos aguas y hojas claras clavadas—
/// con una sola diferencia, y a propósito: la plancha se ensancha hasta que
/// caben todas las notas. El de la plaza tiene tres hojas de adorno; éste
/// tiene las que el pueblo tenga que decir, y hay que poder recorrerlo.
///
/// Se mide una vez y no cambia: la cámara se mueve, el tablón no.
class BoardPlan {
  BoardPlan._({
    required this.papers,
    required this.halfWidth,
    required this.low,
    required this.high,
  });

  /// Las medidas del modelo, tal cual, para lo que no depende del ancho.
  static const double postThick = 0.075;
  static const double plankDepth = 0.05;

  /// Cuánto vuela el tejado por los lados y cuánto de fondo.
  /// Cuánto vuela el tejado por los lados, cuánto de fondo y cuánto sube.
  ///
  /// El fondo es poco a propósito: desde la altura a la que se mira el tablón
  /// se le ve la panza al alero, y con el fondo del modelo esa panza era una
  /// franja oscura tan ancha como una nota.
  static const double eave = 0.1, roofDepth = 0.11, roofRise = 0.17;

  /// Media hoja, y cuánto hay de una a la siguiente. Fijas: una hoja mide lo
  /// que mide, haya una clavada o haya diez.
  static const double paperW = 0.3, paperH = 0.23;

  /// El hueco de cada papel. Sobra sitio alrededor de la hoja porque es ahí
  /// donde se desordena: sin holgura, diez papeles centrados en sus diez
  /// celdas vuelven a ser una rejilla por mucho que se sorteen los huecos.
  static const double colPitch = 0.82, rowPitch = 0.68;

  /// El aire que queda entre la última hoja y el poste.
  static const double margin = 0.16;

  /// El tablón es siempre igual de grande: dos filas de cinco.
  ///
  /// Antes crecía con lo que hubiera que clavar, y eso estaba mal por dos
  /// motivos. Uno, que un pueblo con una sola nota tenía un tablón diminuto
  /// con esa nota llenándolo, cuando lo que cuenta la verdad es un tablón
  /// entero con un papel solo en una punta y el resto de la madera vacía. Y
  /// dos, que al crecer a lo alto la cámara tenía que echarse atrás para que
  /// cupiera, así que las hojas se veían más chicas cuantas más había: cuanto
  /// más tenía que decir el pueblo, menos se leía.
  ///
  /// Diez es lo que cabe llenarlo: ocho es todo lo que [noticesFor] llega a
  /// saber de alguien, y dos son los bandos del pueblo.
  ///
  /// La rejilla es la del modelo de la plaza y no una suya: si fueran dos
  /// números, el tablón de lejos tendría huecos donde el de cerca no, y la
  /// silueta mentiría en cuanto uno de los dos cambiara.
  static const int rows = NoticeBoard.rows, cols = NoticeBoard.cols;
  static const int capacity = NoticeBoard.capacity;

  final List<BoardPaper> papers;

  /// Media anchura de la plancha.
  final double halfWidth;

  /// Dónde empieza y dónde acaba la plancha, medido desde el suelo.
  final double low, high;

  double get top => high + roofRise;

  /// El medio del tablón de arriba abajo, tejado incluido. Es el punto al que
  /// mira la cámara cuando se pone de frente, y el mismo del que sale
  /// [fitDistance]: si fueran dos, la distancia calculada para que quepa
  /// entero dejaría el tejado fuera.
  double get midY => (low + top) / 2;
  double get postTop => high + 0.07;

  /// Dónde se clava el nombre del hábito: en el filo de arriba de la plancha.
  double get headY => high - 0.11;
  static const double headHeight = 0.115;

  /// El rectángulo plano en el que se maqueta ese nombre.
  ///
  /// Tiene que llevar la proporción del hueco al que va, porque la homografía
  /// estira lo que le den hasta las cuatro esquinas: con una caja de medidas
  /// fijas, cuanto más ancho el tablón más se estiraban las letras a lo largo.
  /// Era eso lo que hacía que el nombre saliera deformado, y se notaba más
  /// cuantas más notas tenía el pueblo, porque el tablón crecía a lo ancho.
  Size get headBox {
    const alto = 44.0;
    return Size(alto * (2 * (halfWidth - 0.1)) / headHeight, alto);
  }

  /// Las notas, repartidas por el tablón.
  ///
  /// En dos filas mientras haya de qué, porque un tablón de una sola fila con
  /// ocho hojas es una tira y no un tablón. El desorden —el tamaño de cada
  /// hoja, lo que se corre de su sitio y cuánto se tuerce— sale de la nota y
  /// no del azar, así que el tablón está siempre igual: uno vuelve a mirar una
  /// nota y sigue donde estaba.
  /// [slots] dice en qué hueco va cada una de [said], en el mismo orden, y es
  /// lo que se acuerda de dónde quedó clavado cada papel — lo reparte
  /// [BoardSlots].
  ///
  /// Va sin valor por defecto a propósito. Lo tuvo, y era «clavarlas en
  /// fila»: una versión salió con el tablón de la plaza usando los huecos
  /// sorteados y el de cerca poniéndolas en fila, o sea que desde el valle los
  /// papeles estaban a la derecha y al entrar aparecían a la izquierda.
  /// Olvidarse de pasarlos ahora no compila.
  factory BoardPlan.of(List<Notice> said, {required List<int> slots}) {
    const halfWidth = cols * colPitch / 2 + margin;
    const low = 0.42;
    const high = low + rows * rowPitch + 0.3;
    const band = (high - low - 0.3) / rows;
    const usable = 2 * halfWidth - 2 * margin;
    const medio = (low + high) / 2;
    const w = paperW, h = paperH;
    // El aire que se le deja al filo. Una hoja pegada al canto de la madera se
    // lee como un fallo de recorte aunque esté dentro.
    const aire = 0.025;
    // Descolgada crece, y hay que decidir cuánto: una hoja crecida que se sale
    // de la madera queda colgando del cielo. Crece lo que quepa —nunca más de
    // [BoardPaper.grown]— y además se corre hacia dentro, que es lo que uno
    // hace al mover a mano un papel más grande. Con las dos cosas, la hoja
    // abierta cabe siempre, por construcción y no por suerte.
    final grow = math.min(
      BoardPaper.grown,
      math.min(((high - low) / 2 - aire) / h, (halfWidth - aire) / w),
    );
    final margenX = halfWidth - w * grow - aire;
    final margenY = (high - low) / 2 - h * grow - aire;

    final papers = <BoardPaper>[];
    for (var i = 0; i < math.min(said.length, capacity); i++) {
      final hueco = slots[i];
      if (hueco < 0 || hueco >= capacity) continue;
      final row = hueco % rows, col = hueco ~/ rows;
      // Todo lo que hace que un papel sea ese papel —cuánto se sale de su
      // hueco, cuánto se tuerce, de qué resma es— sale de su propio nombre y
      // no de su sitio en la lista. Si saliera de la lista, el día que una
      // nota deja de estar, todas las de detrás cambiarían de inclinación y de
      // color a la vez y el tablón parecería otro.
      final semilla = stableHash(noticeId(said[i]));
      final cx =
          -halfWidth +
          margin +
          (col + 0.5) * (usable / cols) +
          hashJitter((colPitch - paperW * 2) * 0.44, semilla, 22);
      final cy =
          low +
          0.15 +
          (rows - 1 - row + 0.5) * band +
          hashJitter((rowPitch - paperH * 2) * 0.44, semilla, 23);
      papers.add(
        BoardPaper(
          notice: said[i],
          index: i,
          cx: cx,
          cy: cy,
          grow: grow,
          openCx: cx.clamp(-margenX, margenX),
          openCy: cy.clamp(medio - margenY, medio + margenY),
          w: w,
          h: h,
          // Torcida siempre, y de cuánto y hacia dónde por separado. Con un
          // solo sorteo simétrico salían papeles a medio grado —que se leen
          // como rectos— y vecinos con la misma inclinación, que es lo que
          // convierte el desorden en un patrón.
          lean:
              (hash01(semilla, 26) < 0.5 ? -1 : 1) *
              (0.03 + hash01(semilla, 24) * 0.085),
          paper: said[i].kind == NoticeKind.pueblo
              ? villagePaper
              : _papers[hashInt(_papers.length, semilla, 25)],
        ),
      );
    }
    return BoardPlan._(
      papers: papers,
      halfWidth: halfWidth,
      low: low,
      high: high,
    );
  }

  /// Los tonos de papel.
  ///
  /// Tres pergaminos de la misma familia, no tres colores. Lo que hacía que
  /// las notas parecieran un taco de pósits no era que fueran claras sino que
  /// eran de tres tonos distintos —crema, verde, amarillo—: tres colores es un
  /// código, y un código pide que signifiquen algo. Aquí no significan nada:
  /// son tres papeles de la misma resma envejecidos de manera distinta, que es
  /// lo que hay clavado en un tablón de verdad.
  static const List<Color> _papers = [
    Color(0xFFE9DCBC),
    Color(0xFFDFD1AE),
    Color(0xFFF0E5C9),
  ];

  /// El de los papeles del pueblo: el más viejo de los tres, para que un bando
  /// sobre una cabra no se confunda con lo que el tablón sabe de vos.
  static const Color villagePaper = Color(0xFFD8C8A2);

  /// Los colores del modelo de la plaza, sin tocar.
  static const Color wood = Color(0xFFC9B896);
  static const Color post = Color(0xFF6B573F);
  static const Color shingle = Color(0xFF8A7355);

  /// La tinta: parda y oscura, de las que se hacían con agallas de roble.
  static const Color ink = Color(0xFF33291B);

  /// La tangente de medio campo vertical, que es la lente de [OrbitCamera]:
  /// `fovY` es 0,86 radianes allí. Aquí escrita una vez, porque de esto salen
  /// todas las distancias.
  static const double tanHalfFovY = 0.4586;

  /// La distancia a la que se lee: la que deja el tablón llenando la mayor
  /// parte del alto de la pantalla.
  ///
  /// Es la distancia de trabajo, y de ella salen las dos únicas a las que se
  /// puede llegar con los dedos. En un teléfono de pie un tablón que es dos
  /// veces más ancho que alto no cabe entero y a la vez se lee: o se ve entero
  /// y las letras son puntos, o se leen las letras y se ve un trozo. Se elige
  /// lo segundo, y por eso el tablón se recorre.
  double readDistance(Size size) => (top - low) / (2 * 0.62 * tanHalfFovY);

  /// Lo cerca y lo lejos que dejan llegar los dedos. Es una franja estrecha a
  /// propósito: el zoom aquí no es para explorar, es para ajustar.
  double nearLimit(Size size) => readDistance(size) * 0.72;

  double farLimit(Size size) => math.max(
    nearLimit(size) * 1.05,
    math.min(readDistance(size) * 1.5, fitDistance(size) * 1.15),
  );

  /// Hasta dónde se puede correr el tablón a los lados sin que se vea el vacío
  /// de al lado.
  ///
  /// Sale de lo que la lente abarca a esa distancia, no de un número: el
  /// borde del tablón puede llegar al borde de la pantalla y ni un dedo más.
  /// Cuando el tablón entero cabe en el cuadro no hay nada que correr y esto
  /// vale cero, que es lo que hace que un tablón de dos notas no se pueda
  /// arrastrar a ninguna parte.
  double panLimit(Size size, double distance) {
    final medioAncho =
        distance * tanHalfFovY * (size.width / math.max(size.height, 1));
    return math.max(0, halfWidth + eave - medioAncho);
  }

  /// Lo lejos que hay que estar para que quepa entero de frente.
  ///
  /// Sale de la lente, no de un número a ojo: media pantalla de ancho son
  /// `focal` píxeles por la tangente de medio campo, así que la distancia a la
  /// que un tablón de este ancho llena el cuadro es exactamente ésta. Un
  /// número puesto a mano quedaría corto en cuanto el tablón creciera una
  /// columna, que es justo lo que hace al llegar otra nota.
  double fitDistance(Size size) {
    final tanX = tanHalfFovY * (size.width / math.max(size.height, 1));
    final ancho = (halfWidth + eave) / math.max(tanX, 0.06);
    final alto = (top - low) / 2 / tanHalfFovY;
    return math.max(math.max(ancho, alto), 1.2) * 1.06;
  }
}

/// Una hoja clavada en el tablón.
class BoardPaper {
  const BoardPaper({
    required this.notice,
    required this.index,
    required this.cx,
    required this.cy,
    required this.openCx,
    required this.openCy,
    required this.grow,
    required this.w,
    required this.h,
    required this.lean,
    required this.paper,
  });

  final Notice notice;
  final int index;

  /// El centro, en el plano de la plancha.
  final double cx, cy;

  /// Y a dónde se corre al descolgarse, para que crecida siga cabiendo en la
  /// madera. En las de en medio es el mismo sitio.
  final double openCx, openCy;

  /// Cuánto crece de verdad esta hoja: [grown] o lo que quepa en la madera.
  final double grow;

  /// Media hoja.
  final double w, h;

  /// Lo torcida que está, en radianes.
  final double lean;
  final Color paper;

  /// Justo delante de la plancha.
  static const double rest = plankFront + 0.004;
  static const double plankFront = BoardPlan.plankDepth;

  /// Cuánto se despega del tablón al descolgarla.
  ///
  /// Mucho, y ahí está la gracia: crecer en el sitio no era descolgar nada,
  /// era la misma nota un poco más grande entre las demás. Medio metro hacia
  /// el que mira es la mitad del camino hasta el ojo, así que la nota se sale
  /// del tablón de verdad, tapa lo que haya detrás y el acercamiento se nota.
  static const double lift = 0.5;

  /// Cuánto crece al abrirse. Una nota que se descuelga para leerla es más
  /// grande que la misma nota clavada entre las otras siete.
  ///
  /// Crece igual de ancho que de alto, y eso no es pereza: la hoja lleva el
  /// texto pintado encima con una homografía que estira un rectángulo plano
  /// hasta las cuatro esquinas, así que si la hoja cambiara de proporción al
  /// abrirse, las letras se estirarían con ella.
  static const double grown = 1.85;

  /// A qué distancia hay que ponerse para leerla descolgada.
  ///
  /// Cuenta con las tres cosas que deciden esto y no con una sola:
  ///
  /// - que la nota crece,
  /// - que se viene [lift] hacia el ojo —sin eso la cámara se paraba donde
  ///   estaría la nota clavada y la nota, ya adelantada, se salía de cuadro—,
  /// - y **que la hoja es apaisada y el teléfono está de pie**. Esto último
  ///   faltaba, y era el bulto: puesta a llenar el alto de la pantalla, una
  ///   hoja de tres unidades de ancho por dos y pico de alto se salía dos
  ///   veces y media por los costados. Lo que manda es el lado que peor entra.
  double closeUpDistance(Size size) {
    final tanX =
        BoardPlan.tanHalfFovY * (size.width / math.max(size.height, 1));
    final porAlto = h * grow / BoardPlan.tanHalfFovY;
    final porAncho = w * grow / math.max(tanX, 0.06);
    // Pegada al borde, con un pelo de aire. Una nota descolgada es lo único
    // que se está mirando: dejarle un margen del catorce por ciento la hacía
    // parecer una nota un poco más grande y no una nota en la mano.
    // Y la distancia se mide desde el ojo hasta la hoja, no hasta la plancha:
    // la hoja está [rest] por delante de la madera y se adelanta otro [lift]
    // al descolgarse. Sumar sólo el segundo dejaba la nota cinco centímetros
    // más cerca de lo calculado, que es poco, pero lo justo para que asomara
    // por los costados.
    return math.max(porAlto, porAncho) * 1.02 + rest + lift;
  }

  /// Las cuatro esquinas, en el mundo, con [open] entre 0 y 1.
  List<V3> cornersAt(double open) {
    final k = Curves.easeOutCubic.transform(open.clamp(0.0, 1.0));
    final crece = 1 + (grow - 1) * k;
    final hw = w * crece;
    final hh = h * crece;
    final a = lean * (1 - k);
    final z = rest + lift * k;
    final mx = cx + (openCx - cx) * k;
    final my = cy + (openCy - cy) * k;
    final ca = math.cos(a), sa = math.sin(a);
    V3 at(double dx, double dy) =>
        V3(mx + dx * ca - dy * sa, my + dx * sa + dy * ca, z);
    // En el orden que espera la homografía: arriba-izquierda, arriba-derecha,
    // abajo-derecha, abajo-izquierda.
    return [at(-hw, hh), at(hw, hh), at(hw, -hh), at(-hw, -hh)];
  }
}

// ------------------------------------------------------------- la homografía

/// La matriz que planta un rectángulo de [src] píxeles sobre un cuadrilátero
/// cualquiera de la pantalla.
///
/// Es lo que deja escribir en las hojas con texto de verdad —el mismo
/// `TextPainter` de siempre— en vez de con letras dibujadas a mano: se
/// maqueta la nota en un rectángulo plano y esto la tuerce en perspectiva
/// junto con el papel. Sin esto, una hoja mirada de lado tendría el papel en
/// perspectiva y las letras de frente, que es el truco más viejo y más feo de
/// los que hay.
///
/// [dst] va en el orden de [BoardPaper.cornersAt]. Devuelve null cuando el
/// cuadrilátero está degenerado, que es lo que pasa cuando se mira la hoja
/// exactamente de canto.
Float64List? paperTransform(Size src, List<Offset> dst) {
  final x0 = dst[0].dx, y0 = dst[0].dy;
  final x1 = dst[1].dx, y1 = dst[1].dy;
  final x2 = dst[2].dx, y2 = dst[2].dy;
  final x3 = dst[3].dx, y3 = dst[3].dy;

  final sx = x0 - x1 + x2 - x3;
  final sy = y0 - y1 + y2 - y3;
  double g = 0, h = 0;
  if (sx.abs() > 1e-9 || sy.abs() > 1e-9) {
    final dx1 = x1 - x2, dy1 = y1 - y2;
    final dx2 = x3 - x2, dy2 = y3 - y2;
    final den = dx1 * dy2 - dx2 * dy1;
    if (den.abs() < 1e-9) return null;
    g = (sx * dy2 - dx2 * sy) / den;
    h = (dx1 * sy - sx * dy1) / den;
  }
  final a = x1 - x0 + g * x1;
  final b = x3 - x0 + h * x3;
  final d = y1 - y0 + g * y1;
  final e = y3 - y0 + h * y3;
  if (!a.isFinite || !b.isFinite || !d.isFinite || !e.isFinite) return null;

  final w = src.width <= 0 ? 1.0 : src.width;
  final t = src.height <= 0 ? 1.0 : src.height;
  final m = Float64List(16);
  m[0] = a / w;
  m[1] = d / w;
  m[3] = g / w;
  m[4] = b / t;
  m[5] = e / t;
  m[7] = h / t;
  m[10] = 1;
  m[12] = x0;
  m[13] = y0;
  m[15] = 1;
  return m;
}

/// Si un punto de la pantalla cae dentro del cuadrilátero.
///
/// Con esto se toca una hoja: no hace falta lanzar un rayo por el mundo,
/// porque la hoja ya está proyectada y lo que el dedo toca es la pantalla.
bool insideQuad(List<Offset> q, Offset at) =>
    _inTriangle(q[0], q[1], q[2], at) || _inTriangle(q[0], q[2], q[3], at);

bool _inTriangle(Offset a, Offset b, Offset c, Offset p) {
  double side(Offset u, Offset v) =>
      (v.dx - u.dx) * (p.dy - u.dy) - (v.dy - u.dy) * (p.dx - u.dx);
  final s1 = side(a, b), s2 = side(b, c), s3 = side(c, a);
  final neg = s1 < 0 || s2 < 0 || s3 < 0;
  final pos = s1 > 0 || s2 > 0 || s3 > 0;
  return !(neg && pos);
}
