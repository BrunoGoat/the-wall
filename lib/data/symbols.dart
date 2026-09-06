/// The marks a habit can wear.
///
/// Not emoji. An emoji is a font character: it is drawn by whatever the phone
/// happens to have installed, it looks like a different thing on every device,
/// and it never belongs to the same world as the town it is standing over. The
/// landmarks were always given their own drawn mark; the habits get the same
/// treatment. A symbol here is an *id* — the drawing lives in
/// `ui/habit_sigil.dart` and is made of the same straight lines and squared
/// masses everything else in the app is made of.
library;

/// Every mark, in the order the picker shows them.
///
/// Ordered so the first row is what most people are actually here for — read,
/// run, lift, sit still, stop smoking, drink water — and the rest widens out
/// from there.
const List<String> habitSymbols = [
  'libro',
  'carrera',
  'pesa',
  'loto',
  'pipa',
  'gota',
  'hoja',
  'luna',
  'pluma',
  'laud',
  'pincel',
  'escoba',
  'frasco',
  'diente',
  'campana',
  'brote',
  'rueda',
  'ola',
  'huella',
  'olla',
  'diana',
  'sol',
  'estrella',
  'corazon',
  'montana',
  'arbol',
  'espiga',
  'copa',
  'bolsa',
  'llave',
  'yunque',
  'espada',
  'escudo',
  'reloj',
  'farol',
  'torre',
];

/// What each mark is, for anyone who cannot see it.
const Map<String, String> habitSymbolNames = {
  'libro': 'Libro abierto',
  'carrera': 'Corredor',
  'pesa': 'Pesa',
  'loto': 'Figura sentada',
  'pipa': 'Pipa tachada',
  'gota': 'Gota de agua',
  'hoja': 'Hoja',
  'luna': 'Luna',
  'pluma': 'Pluma de escribir',
  'laud': 'Laúd',
  'pincel': 'Pincel',
  'escoba': 'Escoba',
  'frasco': 'Frasco de botica',
  'diente': 'Diente',
  'campana': 'Campana',
  'brote': 'Brote',
  'rueda': 'Rueda',
  'ola': 'Olas',
  'huella': 'Huella',
  'olla': 'Olla',
  'diana': 'Diana',
  'sol': 'Sol',
  'estrella': 'Estrella',
  'corazon': 'Corazón',
  'montana': 'Montaña',
  'arbol': 'Árbol',
  'espiga': 'Espiga',
  'copa': 'Copa',
  'bolsa': 'Bolsa de monedas',
  'llave': 'Llave',
  'yunque': 'Yunque',
  'espada': 'Espada',
  'escudo': 'Escudo',
  'reloj': 'Reloj de arena',
  'farol': 'Farol',
  'torre': 'Torre',
};

/// The mark a habit gets when nobody has chosen one.
const String kDefaultHabitSymbol = 'torre';

/// What the emoji of earlier versions turn into.
///
/// Anybody who has been laying pieces since before the marks were drawn opens
/// the app to the same habits with the same meanings, not to a valley of
/// question marks.
const Map<String, String> _legacy = {
  '🏠': 'torre',
  '📖': 'libro',
  '📚': 'libro',
  '🏃': 'carrera',
  '💪': 'pesa',
  '🏋': 'pesa',
  '🧘': 'loto',
  '🚭': 'pipa',
  '🚬': 'pipa',
  '💧': 'gota',
  '🥗': 'hoja',
  '🍎': 'hoja',
  '😴': 'luna',
  '🛏': 'luna',
  '✍': 'pluma',
  '📝': 'pluma',
  '💻': 'pluma',
  '🎸': 'laud',
  '🎵': 'laud',
  '🎨': 'pincel',
  '🧹': 'escoba',
  '💊': 'frasco',
  '🦷': 'diente',
  '☎': 'campana',
  '📞': 'campana',
  '🌱': 'brote',
  '🧠': 'estrella',
  '🪙': 'bolsa',
  '💰': 'bolsa',
  '🚲': 'rueda',
  '🏊': 'ola',
  '🐕': 'huella',
  '🐶': 'huella',
  '🍳': 'olla',
  '🎯': 'diana',
  '☀': 'sol',
  '⭐': 'estrella',
  '❤': 'corazon',
  '⛰': 'montana',
  '🌳': 'arbol',
  '🔑': 'llave',
  '⚔': 'espada',
  '🛡': 'escudo',
  '⏳': 'reloj',
  '🏮': 'farol',
};

/// The mark to actually draw for whatever is saved against a habit.
///
/// Never fails and never returns nothing: a town always has a mark over it.
String resolveHabitSymbol(String? saved) {
  if (saved == null || saved.isEmpty) return kDefaultHabitSymbol;
  if (habitSymbolNames.containsKey(saved)) return saved;
  // Emoji are routinely stored with a variation selector on the end, which is
  // invisible and would otherwise miss the table by one code unit.
  final bare = saved.replaceAll('️', '').replaceAll('⃣', '');
  final hit = _legacy[bare];
  if (hit != null) return hit;
  // Something nobody planned for — an emoji typed by hand, a mark from a
  // version that came later. Choose one and always choose the same one: a
  // town must not change its sign every time the app opens.
  var h = 0;
  for (final c in bare.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return habitSymbols[h % habitSymbols.length];
}
