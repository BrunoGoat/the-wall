import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/rng.dart';
import '../data/pacing.dart';
import '../data/symbols.dart';
import '../data/character.dart';
import '../data/landmarks.dart';
import '../engine/town.dart';
import 'census.dart';
import 'habit.dart';
import 'piece.dart';

/// What happened when a piece was laid. Drives the celebration.
class PlaceResult {
  PlaceResult({
    required this.piece,
    required this.relit,
    required this.relitFrom,
    this.startedNewDay = false,
  });

  final Piece piece;

  /// True when this piece brought a town's lights back on.
  final bool relit;
  final double relitFrom;

  final bool startedNewDay;
}

/// Everything the app remembers: the habits, and the towns they have built.
class Store extends ChangeNotifier {
  Store();

  static const _key = 'pueblo_state_v1';

  /// What the app was called when it was a wall. Read once, then left alone.
  static const _wallKey = 'la_muralla_state_v2';
  static const _wallLegacyKey = 'la_muralla_state_v1';

  final List<Habit> habits = [];
  int active = 0;

  bool loaded = false;
  bool _dirty = false;
  SharedPreferences? _prefs;

  /// Set at launch so the first piece back can play the relighting against the
  /// state the person actually walked in on.
  double integrityAtLaunch = 1.0;

  Habit get habit => habits[active.clamp(0, habits.length - 1)];

  /// What kind of place the town in front of you is.
  TownCharacter get character => habit.place;

  /// Its plan: which landmark comes next, and what everything costs.
  TownPlan get plan => TownPlan.of(character);

  int get total => habit.total;

  /// A pretend count, for looking at what the town becomes without waiting
  /// years for it. The real pieces are untouched.
  int? preview;
  bool get isPreviewing => preview != null;
  int get shownTotal => preview ?? habit.total;

  void setPreview(int? count) {
    preview = count;
    notifyListeners();
  }

  DateTime? get lastPlacedAt => habit.lastPlacedAt;

  // ------------------------------------------------------------- la crónica

  /// Escribe en la crónica de un pueblo todo lo que ya se empezó y todavía no
  /// estaba escrito.
  ///
  /// Se llama al cargar, al importar y cada vez que cae una pieza. Ni antes ni
  /// después: escribir de más le cerraría la puerta a lo que se añada mañana
  /// —el edificio siguiente ya estaría decidido— y escribir de menos dejaría
  /// que un cambio del catálogo le cambie las casas a alguien que ya las tiene
  /// levantadas.
  ///
  /// Sólo crece. Una crónica no se acorta ni se corrige: lo que dice es lo que
  /// pasó.
  bool _writeUpWorks(Habit h) {
    final want = TownPlan.of(h.place).chronicleFor(h.total, h.chronicle);
    if (want.length <= h.chronicle.length) return false;
    h.chronicle
      ..clear()
      ..addAll(want);
    return true;
  }

  /// Lo que el pueblo está esperando que le contesten, si es que espera algo.
  ///
  /// Todo lo demás de esta app ocurre solo: las casas se eligen con el hash del
  /// pueblo y los hitos por el orden que le tocó al fundarlo, y está bien que
  /// sea así — hay un solo botón y ninguna decisión que tomar, y ésa es la
  /// mitad de lo que la hace descansada.
  ///
  /// Pero una vez cada varias semanas, cuando toca empezar una obra grande, el
  /// pueblo pregunta. Dos obras que le tocaban igual de pronto, y la que no
  /// salga sigue la primera de la lista para la próxima vez, así que elegir no
  /// es renunciar a nada: es decidir el orden de tu propio valle. Es la única
  /// decisión que hay en toda la app, y por eso tiene que ser rara.
  ///
  /// Nulo casi siempre. Deja de serlo justo en la pieza en la que la obra
  /// empezaría, y vuelve a serlo en cuanto se contesta.
  List<Landmark>? get pendingChoice {
    final c = plan.choiceFor(habit.total, habit.chronicle);
    if (c == null) return null;
    final marks = [
      for (final id in c.$2)
        if (TownPlan.landmarkOf(id) != null) TownPlan.landmarkOf(id)!,
    ];
    return marks.length < 2 ? null : marks;
  }

  /// Contestar: se escribe en la crónica y de ahí no se mueve nunca más.
  ///
  /// Si lo que llega no es una de las dos que se preguntaron, no pasa nada —
  /// se escribe la primera, que es la que habría salido sola. Un pueblo no se
  /// queda esperando por una respuesta que no llega.
  void chooseWork(String id) {
    final c = plan.choiceFor(habit.total, habit.chronicle);
    if (c == null) return;
    final want = c.$2.contains(id) ? id : c.$2.first;
    while (habit.chronicle.length < c.$1) {
      // No puede pasar —la crónica llega justo hasta aquí— pero si pasara,
      // escribir en el hueco equivocado le cambiaría los edificios a un pueblo
      // que ya está en pie. Mejor rellenar con lo que decía el plan.
      habit.chronicle.add(plan.chronicleFor(total, habit.chronicle).last);
    }
    habit.chronicle.add(want);
    _writeUpWorks(habit);
    _save();
    notifyListeners();
  }

  /// Cerrar sin contestar: que decidan ellos, y que lo decidan ahora.
  ///
  /// Escribe la primera, que es la que habría salido sola. Se podría no hacer
  /// nada —la pregunta caduca con la pieza siguiente y entonces se escribe lo
  /// mismo— pero eso deja la crónica un hueco corta mientras tanto, y si ese
  /// mientras tanto dura un mes y en el medio cae una actualización con hitos
  /// nuevos, la obra que estaba a punto de empezar podría cambiar. Es una
  /// ventana chica, pero cerrarla cuesta una línea.
  void letThemDecide() {
    final c = plan.choiceFor(habit.total, habit.chronicle);
    if (c == null) return;
    chooseWork(c.$2.first);
  }

  /// Y de todos, que es lo que hace falta al abrir la app y al importar.
  /// Apunta en el padrón a los vecinos que hayan nacido en [layout].
  ///
  /// Lo llama la vista con el plano que ya tiene construido, que es lo que
  /// evita levantar un pueblo entero otra vez sólo para contar casas. Se llama
  /// una vez por cada cuenta de piezas, que es exactamente cuando puede haber
  /// nacido alguien.
  ///
  /// Nunca sobre un plano a medio enseñar: mientras cae una pieza la vista
  /// dibuja el pueblo de antes, y apuntar a alguien contra ese plano le daría
  /// la fecha de la pieza que todavía no ha caído.
  void enrol(Habit h, TownLayout layout) {
    if (layout.placed != h.total) return;
    if (enrolFolk(h, layout).isEmpty) return;
    _save();
  }

  bool _writeUpAll() {
    var moved = false;
    for (final h in habits) {
      if (_writeUpWorks(h)) moved = true;
    }
    return moved;
  }

  // -------------------------------------------------------------------- cielo

  /// Las constelaciones que alguien se quedó mirando y anotó.
  ///
  /// Del valle y no de un hábito: lo que se ve desde el observatorio de un
  /// pueblo se ve desde el de cualquier otro, porque es el mismo cielo. Un
  /// cuaderno de estrellas por hábito sería tener que redescubrir Orión cada
  /// vez que fundás un pueblo, y eso no es cómo funciona el cielo.
  final Set<String> sky = <String>{};

  bool sawIt(String id) => sky.contains(id);

  /// Anota una. Devuelve si era nueva, que es lo que decide si hay algo que
  /// celebrar.
  bool logConstellation(String id) {
    if (!sky.add(id)) return false;
    _save();
    notifyListeners();
    return true;
  }

  /// Si en el valle hay un observatorio en pie, en cualquier pueblo.
  ///
  /// Basta con uno: el primero que levanta la cúpula se la levanta al valle
  /// entero. Cinco pueblos y cinco observatorios antes de ver una estrella
  /// sería castigar al que tiene varios hábitos.
  bool get hasObservatory {
    for (final h in habits) {
      if (TownPlan.of(h.place).built('observatorio', h.total, h.chronicle)) {
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------------ habits

  bool get canAddHabit => habits.length < Habit.maxSlots;

  /// The next free plot in the valley. Slots are never reused while their
  /// habit exists, so nobody's town ever moves.
  int _freeSlot() {
    final taken = habits.map((h) => h.slot).toSet();
    for (var i = 0; i < Habit.maxSlots; i++) {
      if (!taken.contains(i)) return i;
    }
    return habits.length;
  }

  Habit addHabit(String name, String symbol, {int? character}) {
    final slot = _freeSlot();
    final h = Habit(
      id: 'h${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Sin nombre' : name.trim(),
      symbol: resolveHabitSymbol(symbol),
      slot: slot,
      character: character ?? TownCharacter.forSlot(slot).order,
      createdAt: DateTime.now(),
    );
    habits.add(h);
    active = habits.length - 1;
    _save();
    notifyListeners();
    return h;
  }

  void renameHabit(int index, {String? name, String? symbol}) {
    if (index < 0 || index >= habits.length) return;
    final h = habits[index];
    if (name != null && name.trim().isNotEmpty) h.name = name.trim();
    if (symbol != null && symbol.isNotEmpty) {
      h.symbol = resolveHabitSymbol(symbol);
    }
    _save();
    notifyListeners();
  }

  /// Removing a habit removes its town. There is no way back, which is why the
  /// only caller asks twice.
  ///
  /// The last one can go too. A valley with nothing in it is not a state this
  /// app has — the town view would have nothing to draw — so removing the only
  /// habit leaves the same blank one you would have got on a phone that had
  /// never opened the app. That is what deleting it means: the name, the mark
  /// and every piece are gone, and the ground is empty again.
  void removeHabit(int index) {
    if (index < 0 || index >= habits.length) return;
    habits.removeAt(index);
    if (habits.isEmpty) habits.add(_blankHabit());
    if (active >= habits.length) active = habits.length - 1;
    integrityAtLaunch = integrity;
    _save();
    notifyListeners();
  }

  /// The habit a valley starts with: no name worth keeping, no pieces, the
  /// first plot.
  static Habit _blankHabit() => Habit(
    id: 'h${DateTime.now().microsecondsSinceEpoch}',
    name: 'Mi hábito',
    symbol: kDefaultHabitSymbol,
    slot: 0,
    createdAt: DateTime.now(),
  );

  /// Quita la última pieza puesta.
  ///
  /// Es lo único en toda la app que le quita algo a un pueblo, y existe por un
  /// motivo concreto y aburrido: un dedo que se apoya solo, un bolsillo, un
  /// toque de más. Un logro que no pasó no tiene por qué quedar en piedra.
  ///
  /// La crónica de obra no se toca. Si esa pieza era la primera de un edificio,
  /// ese edificio sigue escrito y sigue siendo el que se va a construir — que
  /// es lo correcto: lo que se decidió, se decidió, y deshacer un dedo no es
  /// motivo para volver a sortear qué se está levantando.
  Piece? removeLastPiece() {
    if (habit.pieces.isEmpty) return null;
    final gone = habit.pieces.removeLast();
    integrityAtLaunch = integrity;
    preview = null;
    _save();
    notifyListeners();
    return gone;
  }

  void select(int index) {
    if (index < 0 || index >= habits.length || index == active) return;
    active = index;
    preview = null;
    integrityAtLaunch = integrity;
    _save();
    notifyListeners();
  }

  /// Which habit has laid the most pieces, or null while there is nothing to
  /// compare — one habit is not a valley, and a valley where nobody has begun
  /// has no leader either.
  ///
  /// Ties go to whoever got there first, so the crown never flickers between
  /// two towns on the same count.
  int? get leader {
    if (habits.length < 2) return null;
    var best = -1;
    for (var i = 0; i < habits.length; i++) {
      if (habits[i].total <= 0) continue;
      if (best < 0 ||
          habits[i].total > habits[best].total ||
          (habits[i].total == habits[best].total &&
              habits[i].createdAt.isBefore(habits[best].createdAt))) {
        best = i;
      }
    }
    return best < 0 ? null : best;
  }

  // ------------------------------------------------------------------- state

  Future<void> load() async {
    // Storage must never be able to hold the app hostage: if the platform
    // channel is slow or unavailable we carry on in memory.
    try {
      _prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      _prefs = null;
    }
    final raw = _prefs?.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        _decode(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        habits.clear();
      }
    } else {
      _adoptTheWall();
    }
    if (habits.isEmpty) habits.add(_blankHabit());
    active = active.clamp(0, habits.length - 1);
    // Una copia guardada por una versión anterior no trae crónica. Se escribe
    // aquí, con el catálogo de hoy, y de ahí en adelante ya no se recalcula.
    if (_writeUpWorks(habit) || _writeUpAll()) _save();
    integrityAtLaunch = integrity;
    loaded = true;
    notifyListeners();
  }

  /// Everything laid back when this was one wall becomes the first habit's
  /// town. Nobody loses a year of work to a change of mind about the app.
  void _adoptTheWall() {
    final raw =
        _prefs?.getString(_wallKey) ?? _prefs?.getString(_wallLegacyKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final list =
          ((j['bricks'] as List?) ?? [])
              .map((e) => Piece.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.index.compareTo(b.index));
      for (var i = 0; i < list.length; i++) {
        list[i] = Piece(
          index: i,
          placedAt: list[i].placedAt,
          label: list[i].label,
        );
      }
      if (list.isEmpty) return;
      habits.add(
        Habit(
          id: 'h0',
          name: 'Mi hábito',
          symbol: kDefaultHabitSymbol,
          slot: 0,
          createdAt: list.first.placedAt,
          pieces: list,
        ),
      );
    } catch (_) {
      // A save from a version that no longer exists is not worth crashing for.
    }
  }

  void _decode(Map<String, dynamic> j) {
    habits
      ..clear()
      ..addAll(
        ((j['h'] as List?) ?? []).map(
          (e) => Habit.fromJson(e as Map<String, dynamic>),
        ),
      );
    active = (j['a'] as num?)?.toInt() ?? 0;
    sky
      ..clear()
      ..addAll(((j['sky'] as List?) ?? []).map((e) => e.toString()));
  }

  Map<String, dynamic> _encode() => {
    'v': 1,
    'a': active,
    'h': habits.map((h) => h.toJson()).toList(),
    'sky': sky.toList()..sort(),
  };

  // ------------------------------------------------------- taking it with you

  /// Everything this app knows about you, as one line of text.
  ///
  /// Because a town should not be able to disappear for a reason that has
  /// nothing to do with you. A phone gets lost, a signing key changes and
  /// Android refuses the update, somebody clears an app's storage by mistake —
  /// none of those are your fault and none of them should cost you a year of
  /// mornings. This is the same thing the app writes to storage, handed over
  /// so you can keep it somewhere it is yours.
  ///
  /// It is plain JSON on purpose. Not compressed, not encoded: it is your
  /// history and you should be able to open it and see it — the dates you laid
  /// each piece and what you wrote on them, in the order they happened.
  String exportSave() => jsonEncode(_encode());

  /// What [exportSave] wrote, read back. Returns null when it worked, and the
  /// reason in Spanish when it did not.
  ///
  /// All or nothing: everything is parsed into a new list first, and the
  /// habits this store is holding are not touched until the whole thing has
  /// come back clean. A restore that half-worked would be worse than one that
  /// refused, because it would look like it had worked.
  String? importSave(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return 'No hay nada pegado.';
    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      return 'Eso no es una copia de La Muralla.';
    }
    if (parsed is! Map<String, dynamic>) {
      return 'Eso no es una copia de La Muralla.';
    }
    final list = parsed['h'];
    if (list is! List) return 'A esa copia le falta la lista de pueblos.';
    final read = <Habit>[];
    try {
      for (final e in list) {
        read.add(Habit.fromJson(e as Map<String, dynamic>));
      }
    } catch (_) {
      return 'Esa copia está rota: no pude leer uno de los pueblos.';
    }
    if (read.isEmpty) return 'Esa copia no tiene ningún pueblo dentro.';
    if (read.length > Habit.maxSlots) {
      return 'Esa copia trae ${read.length} pueblos y el valle tiene sitio '
          'para ${Habit.maxSlots}.';
    }
    habits
      ..clear()
      ..addAll(read);
    active = ((parsed['a'] as num?)?.toInt() ?? 0).clamp(0, habits.length - 1);
    // Y el cuaderno del cielo, que viaja con el valle: es del valle.
    sky
      ..clear()
      ..addAll(((parsed['sky'] as List?) ?? []).map((e) => e.toString()));
    preview = null;
    _writeUpAll();
    integrityAtLaunch = integrity;
    _save();
    notifyListeners();
    return null;
  }

  /// How much is in a copy, for saying so out loud before and after.
  String describe() {
    final towns = habits.length;
    final pieces = habits.fold<int>(0, (n, h) => n + h.total);
    return '$pieces ${pieces == 1 ? 'pieza' : 'piezas'} en '
        '$towns ${towns == 1 ? 'pueblo' : 'pueblos'}';
  }

  void _save() {
    _dirty = true;
    // Writes are cheap but not free; coalesce bursts into one write.
    Future.microtask(() {
      if (!_dirty) return;
      _dirty = false;
      _prefs?.setString(_key, jsonEncode(_encode()));
    });
  }

  // ----------------------------------------------------------------- placing

  /// The one and only way a town grows. One call, one piece.
  PlaceResult placePiece() {
    final now = DateTime.now();
    final before = integrity;
    final hadToday = _countOn(now) > 0;

    final piece = Piece(index: habit.total, placedAt: now);
    habit.pieces.add(piece);
    // Y si esta pieza empieza un edificio nuevo, queda escrito qué edificio es.
    _writeUpWorks(habit);

    _save();
    notifyListeners();

    return PlaceResult(
      piece: piece,
      relit: before < 0.999,
      relitFrom: before,
      startedNewDay: !hadToday,
    );
  }

  /// Writes (or clears) the note on a piece. Always optional.
  void setLabel(int index, String? text) {
    final list = habit.pieces;
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].withLabel(text);
    _save();
    notifyListeners();
  }

  Piece? pieceAt(int index) {
    final list = habit.pieces;
    return index >= 0 && index < list.length ? list[index] : null;
  }

  List<Piece> get pieces => habit.pieces;

  List<Piece> get labelled =>
      habit.pieces.where((p) => p.hasLabel).toList().reversed.toList();

  /// Undo for the fat-finger case: only the most recent piece, only for a
  /// couple of minutes.
  bool canUndoLast() {
    if (habit.pieces.isEmpty) return false;
    return DateTime.now().difference(habit.pieces.last.placedAt).inMinutes < 2;
  }

  void undoLast() {
    if (!canUndoLast()) return;
    habit.pieces.removeLast();
    _save();
    notifyListeners();
  }

  // ------------------------------------------------------------------- decay

  static double daysIdleOf(Habit h) {
    final last = h.lastPlacedAt;
    if (last == null) return 0;
    final d = DateTime.now().difference(last).inMinutes / 1440.0;
    return d < 0 ? 0 : d;
  }

  static double integrityOf(Habit h) =>
      h.pieces.isEmpty ? 1.0 : Pacing.integrityFor(daysIdleOf(h));

  double get daysIdle => daysIdleOf(habit);
  double get integrity => integrityOf(habit);
  bool get isDecaying => integrity < 0.995;

  // ----------------------------------------------------------------- streaks

  int get streak => streakOf(habit);
  int get bestStreak => _bestStreakOf(habit);

  static int streakOf(Habit h) {
    if (h.pieces.isEmpty) return 0;
    final days = <DateTime>{for (final p in h.pieces) dayStart(p.placedAt)};
    var cursor = dayStart(DateTime.now());
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static int _bestStreakOf(Habit h) {
    if (h.pieces.isEmpty) return 0;
    final days = <DateTime>{
      for (final p in h.pieces) dayStart(p.placedAt),
    }.toList()..sort();
    var best = 1, run = 1;
    for (var i = 1; i < days.length; i++) {
      final gap = days[i].difference(days[i - 1]).inDays;
      run = gap == 1 ? run + 1 : 1;
      if (run > best) best = run;
    }
    return best;
  }

  int _countOn(DateTime when) {
    final k = dayKey(when);
    var n = 0;
    for (final p in habit.pieces) {
      if (dayKey(p.placedAt) == k) n++;
    }
    return n;
  }

  List<DayTally> lastDays(int days) {
    final counts = <int, int>{};
    for (final p in habit.pieces) {
      counts.update(dayKey(p.placedAt), (v) => v + 1, ifAbsent: () => 1);
    }
    final today = dayStart(DateTime.now());
    return List.generate(days, (i) {
      final d = today.subtract(Duration(days: days - 1 - i));
      return DayTally(d, counts[dayKey(d)] ?? 0);
    });
  }

  /// What the town is putting up right now.
  String get nextEventLabel {
    final work = plan.underway(shownTotal, habit.chronicle);
    if (work == null) return 'El pueblo sigue creciendo';
    final left = work.$2;
    return left == 1
        ? 'Una pieza más y ${work.$1} queda en pie'
        : '${work.$1} · faltan $left';
  }

  Future<void> wipe() async {
    habits.clear();
    habits.add(
      Habit(
        id: 'h${DateTime.now().microsecondsSinceEpoch}',
        name: 'Mi hábito',
        symbol: kDefaultHabitSymbol,
        slot: 0,
        createdAt: DateTime.now(),
      ),
    );
    active = 0;
    await _prefs?.remove(_key);
    integrityAtLaunch = 1.0;
    notifyListeners();
  }

  /// Fast-forwards a town for development, so a year of use can be looked at
  /// without waiting a year. Driven by a compile-time define, off by default.
  static const List<String> _debugLabels = [
    'Leí',
    'Corrí',
    'Estudié',
    'Escribí',
    'No fumé',
    'Salí a caminar',
    'Llamé a mamá',
    'Ordené el taller',
    'Toqué la guitarra',
    'Nadé',
  ];

  /// Fast-forwards a town for development, so a year of use can be looked at
  /// without waiting a year.
  ///
  /// It lays them the way a person would: one on most days at an hour this
  /// habit favours, a weekday it tends to skip, the odd double day, and misses
  /// that come in runs rather than scattered evenly — because a blank day
  /// really does drag the next one. Pieces every 137 minutes round the clock
  /// would fill the town just as fast and be no use at all for looking at
  /// anything that reads the shape of a history rather than its length.
  void debugFill(int count, {int endedDaysAgo = 0, int? into}) {
    if (count <= 0) return;
    final h = habits[(into ?? active).clamp(0, habits.length - 1)];
    final s = hash32(h.slot + 1, 0x0FEED, 3);
    final hour = 6 + hash32(s, 1, 1) % 15;
    final weak = 1 + hash32(s, 2, 1) % 7;
    final end = dayStart(DateTime.now().subtract(Duration(days: endedDaysAgo)));
    final when = <DateTime>[];
    var day = 0;
    var missed = false;
    while (when.length < count && day < count * 6 + 60) {
      final d = end.subtract(Duration(days: day));
      final r = hash01(s, 7, day);
      var miss = r < 0.16;
      if (d.weekday == weak) miss = r < 0.66;
      if (missed && r < 0.45) miss = true;
      missed = miss;
      if (!miss) {
        final m = hashRange(-40, 55, s, 8, day).round();
        when.add(d.add(Duration(hours: hour, minutes: m)));
        if (hash01(s, 9, day) < 0.12 && when.length < count) {
          when.add(d.add(Duration(hours: hour + 4, minutes: m ~/ 2)));
        }
      }
      day++;
    }
    when.sort();
    for (var i = 0; i < when.length; i++) {
      h.pieces.add(
        Piece(
          index: h.total,
          placedAt: when[i],
          label: i % 9 == 3
              ? _debugLabels[(i ~/ 9) % _debugLabels.length]
              : null,
        ),
      );
    }
    _writeUpWorks(h);
    integrityAtLaunch = integrity;
    notifyListeners();
  }
}
