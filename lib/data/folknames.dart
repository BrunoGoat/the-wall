library;

import '../core/rng.dart';

/// Cómo se llama la gente del valle.
///
/// Un vecino sin nombre es un muñeco; un vecino que se llama Ximena la
/// Tejedora y nació el catorce de marzo es alguien. No cuesta nada y cambia
/// entero lo que se siente al mirar el pueblo de cerca, que es el único sitio
/// donde se les ve la cara.
///
/// Nombres de por aquí y de cuando esto se construía con piedra: los de pila
/// salen de la documentación castellana de los siglos XI al XIV, y el segundo
/// elemento es lo que de verdad se usaba entonces —el oficio, el sitio de
/// donde se venía, o de quién se era hijo—, que es de donde salieron después
/// los apellidos.
///
/// **Se escribe una vez y no se vuelve a tocar.** El nombre de alguien que
/// lleva dos años en tu pueblo no puede cambiar porque yo añada una línea a
/// esta lista, así que en cuanto un vecino nace su nombre queda guardado en el
/// hábito. Esto es de dónde sale el primer día, y nada más.

/// Los de pila, cada uno con su género, porque el otro elemento concuerda.
///
/// Iba suelto y salían cosas como «Constanza el Cantero», que en una app
/// escrita en castellano se lee mal de inmediato. Es de esas cosas que no
/// cuestan nada y que, si no se hacen, delatan que detrás hay una lista y un
/// dado.
const List<(String, bool)> _given = [
  ('Aldonza', true),
  ('Alvar', false),
  ('Andrés', false),
  ('Beatriz', true),
  ('Belasco', false),
  ('Berenguela', true),
  ('Bermudo', false),
  ('Blasco', false),
  ('Catalina', true),
  ('Constanza', true),
  ('Diego', false),
  ('Domingo', false),
  ('Elvira', true),
  ('Enneco', false),
  ('Estefanía', true),
  ('Fadrique', false),
  ('Fernán', false),
  ('Fortún', false),
  ('Froila', false),
  ('García', false),
  ('Gonzalo', false),
  ('Guiomar', true),
  ('Íñigo', false),
  ('Isabel', true),
  ('Jimena', true),
  ('Juan', false),
  ('Leonor', true),
  ('Lope', false),
  ('Lucía', true),
  ('Marina', true),
  ('Martín', false),
  ('Mayor', true),
  ('Mencía', true),
  ('Muño', false),
  ('Nuño', false),
  ('Ordoño', false),
  ('Oria', true),
  ('Pelayo', false),
  ('Pero', false),
  ('Ramiro', false),
  ('Rodrigo', false),
  ('Sancha', true),
  ('Sancho', false),
  ('Suero', false),
  ('Teresa', true),
  ('Toda', true),
  ('Urraca', true),
  ('Velasco', false),
  ('Ximena', true),
];

/// Y de qué se le conocía: el oficio o el mote, en sus dos formas.
const List<(String, String)> _trade = [
  ('el Herrero', 'la Herrera'),
  ('el Tejedor', 'la Tejedora'),
  ('el Molinero', 'la Molinera'),
  ('el Pastor', 'la Pastora'),
  ('el Cantero', 'la Cantera'),
  ('el Hortelano', 'la Hortelana'),
  ('el Zapatero', 'la Zapatera'),
  ('el Carpintero', 'la Carpintera'),
  ('el Alfarero', 'la Alfarera'),
  ('el Curtidor', 'la Curtidora'),
  ('el Barquero', 'la Barquera'),
  ('el Colmenero', 'la Colmenera'),
  ('el Carbonero', 'la Carbonera'),
  ('el Vaquero', 'la Vaquera'),
  ('el Tendero', 'la Tendera'),
  ('el Panadero', 'la Panadera'),
  ('el Ballestero', 'la Ballestera'),
  ('el Viejo', 'la Vieja'),
  ('el Mozo', 'la Moza'),
  ('el Rubio', 'la Rubia'),
  ('el Zurdo', 'la Zurda'),
  ('el Callado', 'la Callada'),
  ('el Tuerto', 'la Tuerta'),
  ('el Romero', 'la Romera'),
];

/// Y de dónde venía, que no distingue.
const List<String> _from = [
  'de la Fuente',
  'del Puente',
  'del Olmo',
  'de la Era',
  'del Cerro',
  'de la Vega',
  'del Soto',
  'de la Torre',
  'del Valle',
  'de la Peña',
  'del Robledal',
  'de la Ribera',
  'del Molino',
  'de la Sierra',
];

/// Un nombre para el vecino de semilla [seed].
///
/// Mil ochocientas combinaciones, que para un pueblo de cuarenta casas es de
/// sobra para que no se repita ninguno — y si en un pueblo de trescientas
/// coinciden dos Marinas la Tejedora, tampoco pasa nada: eso también pasaba.
String folkName(int seed) {
  final (pila, ella) = _given[hashInt(_given.length, seed, 101)];
  // Dos de cada tres por el oficio y uno por la procedencia, que es más o
  // menos como salía: primero eras el herrero y sólo si no eras nada en
  // particular eras el de la otra orilla.
  if (hash01(seed, 103) < 0.68) {
    final (el, la) = _trade[hashInt(_trade.length, seed, 102)];
    return '$pila ${ella ? la : el}';
  }
  return '$pila ${_from[hashInt(_from.length, seed, 102)]}';
}
