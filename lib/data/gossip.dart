/// Lo que el pueblo clava en el tablón cuando no está hablando de vos.
///
/// El tablón de la plaza no puede estar vacío. Un pueblo de verdad tiene
/// siempre un par de papeles clavados —una cabra perdida, un baile el sábado,
/// alguien que busca aprendiz—, y son justamente esos papeles los que hacen
/// que el sitio parezca habitado en vez de un panel de estadísticas al que le
/// faltan datos.
///
/// Ninguno habla de vos ni finge saber nada: son cosas del pueblo, y por eso
/// no se pueden confundir con lo que el tablón sí sabe. Cambian cada día y
/// salen de la fecha, así que el pueblo tiene su propia vida siguiendo su
/// propio calendario y uno vuelve al día siguiente a ver qué hay de nuevo.
library;

import '../core/rng.dart';
import '../model/findings.dart';
import '../model/habit.dart';
import '../model/piece.dart';

/// Los papeles que le tocan hoy al pueblo [town] del valle.
///
/// Dos, o [count] si se piden otros tantos, y **nunca los mismos que a otro
/// pueblo el mismo día**: seis pueblos enseñando la misma cabra perdida no son
/// seis pueblos, son seis copias de una pantalla. Lo que sí se repite es de un
/// día para otro, que es lo que hace un tablón de verdad.
///
/// Se hace barajando el catálogo entero con la fecha y dándole a cada pueblo
/// su tramo: el pueblo cero se lleva los tres primeros de la baraja del día,
/// el uno los tres siguientes, y así. Repartir así y no sortear por separado
/// es lo que hace que no puedan chocar — con seis pueblos y treinta y seis
/// bandos sobra baraja de sobra.
List<Notice> villageNotices(DateTime at, {required int town, int count = 2}) {
  if (_bandos.isEmpty || count <= 0) return const [];
  final baraja = _shuffled(dayKey(dayStart(at)));
  // Tres por pueblo, que es lo más que se le piden. De ancho fijo para que
  // pedir dos o pedir tres no le corra el tramo al pueblo de al lado.
  const window = 3;
  final from = (town.clamp(0, Habit.maxSlots - 1)) * window;
  final out = <Notice>[];
  for (var k = 0; k < count; k++) {
    final (dice, y) = _bandos[baraja[(from + k) % baraja.length]];
    out.add(Notice(NoticeKind.pueblo, dice, y));
  }
  return out;
}

/// El catálogo barajado con la fecha: la baraja del día.
///
/// Barajado de verdad y no recorrido a saltos, para que valga sea cual sea el
/// número de bandos. Con saltos habría que elegir un paso primo con ese
/// número, y añadir un bando podría romperlo en silencio.
List<int> _shuffled(int day) {
  final out = [for (var i = 0; i < _bandos.length; i++) i];
  for (var i = out.length - 1; i > 0; i--) {
    final j = hashInt(i + 1, day, i, 77);
    final t = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}

/// Cuántos hay. Para que el catálogo se pueda contar sin abrirlo.
int get villageNoticeCount => _bandos.length;

/// Los papeles del pueblo, uno por línea.
///
/// Para añadir uno: una pareja más, el titular y el renglón de debajo. Ni
/// número que cuadrar ni sitio donde apuntarlo — el reparto se hace sobre lo
/// que haya. Y que no hable de quien usa la app: eso es lo que dice el tablón
/// por su cuenta, y un bando que lo imitara sería el pueblo inventándose algo.
const List<(String, String)> _bandos = [
  ('Se perdió una cabra.', 'Atiende por Nube. Recompensa: media hogaza.'),
  (
    'El herrero busca aprendiz.',
    'No hace falta saber nada. Sí hace falta madrugar.',
  ),
  ('Baile en la plaza el sábado.', 'Traé tu jarra. El laúd lo pone el pueblo.'),
  (
    'Alguien se llevó la escalera del pozo.',
    'No preguntamos para qué. Devolvela y ya está.',
  ),
  (
    'El molinero jura que la piedra canta de noche.',
    'Nadie más la oyó. El molinero insiste.',
  ),
  ('Se venden nabos.', 'Muchos nabos. Demasiados nabos.'),
  (
    'Se busca quien sepa leer.',
    'Hay una carta desde hace tres semanas y nadie se anima.',
  ),
  (
    'El puente aguanta.',
    'Lo dice el que lo construyó, que es el mismo que cobra por cruzarlo.',
  ),
  (
    'Perdida: una bota. Sólo una.',
    'La izquierda. Quien la encuentre que no pregunte nada.',
  ),
  (
    'El panadero se levanta antes que vos.',
    'Lo dice él. Nadie ha ido a comprobarlo.',
  ),
  (
    'Cuidado con el ganso del corral tercero.',
    'Ya van cuatro. El ganso sigue suelto.',
  ),
  (
    'Se alquila el granero para lo que sea.',
    'Preguntá por Tomás. Tomás no pregunta.',
  ),
  ('Hoy no hay pescado.', 'Ni mañana, probablemente. El río anda raro.'),
  (
    'Aviso: la campana se toca a las seis.',
    'Si suena a otra hora, no es la campana.',
  ),
  (
    'El boticario tiene un remedio nuevo.',
    'Para qué, no lo dice. Que sea sorpresa.',
  ),
  (
    'Se cambian huevos por clavos.',
    'Cinco por uno. No es negociable y ya lo hemos discutido.',
  ),
  (
    'Alguien está moviendo los mojones del camino.',
    'Sabemos quién es. Que pare.',
  ),
  (
    'El pozo está más hondo que el año pasado.',
    'O la cuerda es más corta. Se acepta cualquier explicación.',
  ),
  (
    'Clases de tiro con arco los martes.',
    'Traé tu arco. Y tu propio blanco, después de lo del martes pasado.',
  ),
  (
    'La posada tiene camas libres.',
    'Tres. Bueno, dos: en una duerme el perro y no hay quien lo saque.',
  ),
  ('Se busca al que afinó el laúd.', 'No para agradecérselo.'),
  (
    'El cantero terminó la escalera.',
    'Sube a ninguna parte, pero es una escalera preciosa.',
  ),
  (
    'Aviso del tejador: no subas al tejado.',
    'Da igual el motivo. No subas al tejado.',
  ),
  (
    'Se perdió un gato negro.',
    'O se fue. Con los gatos nunca se sabe cuál de las dos.',
  ),
  (
    'Mercado el primer domingo.',
    'Como todos los meses desde que hay pueblo. Nadie sabe por qué se avisa.',
  ),
  (
    'El pastor dice que vio algo en el monte.',
    'El pastor dice muchas cosas. Ésta la dijo dos veces.',
  ),
  (
    'Se necesitan manos para la siega.',
    'Se paga en trigo, en cerveza, o en no deberle nada a nadie.',
  ),
  (
    'Encontrada: una llave.',
    'Pequeña, de bronce. No abre nada de por acá, que ya lo probamos todo.',
  ),
  (
    'El carpintero no acepta más encargos hasta la primavera.',
    'Ni aunque insistas. Ni aunque seas de la familia.',
  ),
  (
    'Hoy hace un día bueno.',
    'No es un aviso. Es que hacía falta clavar algo alegre.',
  ),
  (
    'Se ruega no dar de comer al cuervo.',
    'Está gordo, está insoportable, y ahora se cree el dueño de la plaza.',
  ),
  (
    'El herrador tiene la fragua fría hasta el jueves.',
    'Se fue a una boda. Volverá peor.',
  ),
  (
    'Aviso: la fuente sabe raro.',
    'Hervila. O no la bebas. O bebela y ya nos contás.',
  ),
  (
    'Se busca dueño para un burro.',
    'Muy bueno. Muy terco. Las dos cosas al mismo tiempo.',
  ),
  (
    'Quien dejó una nota aquí anoche, que vuelva.',
    'No se entiende la letra y parece importante.',
  ),
  (
    'Recordatorio: la muralla no se apoya sola.',
    'Bueno, ésta sí. Pero no os acostumbréis.',
  ),
];
