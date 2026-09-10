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
import '../model/piece.dart';

/// Los papeles del pueblo del día [at].
///
/// Dos, o [count] si se piden otros tantos. Nunca repetidos entre sí, y
/// siempre los mismos para un mismo día.
List<Notice> villageNotices(DateTime at, {int count = 2}) {
  if (_bandos.isEmpty || count <= 0) return const [];
  final dia = dayKey(dayStart(at));
  final out = <Notice>[];
  final usados = <int>{};
  // Se elige saltando por la lista con un paso primo respecto de su largo, así
  // que dos papeles del mismo día nunca caen en el mismo sitio por mucho que
  // el día empuje.
  var at0 = hashInt(_bandos.length, dia, 91);
  final paso = 1 + hashInt(_bandos.length - 1, dia, 92);
  for (var k = 0; k < count && usados.length < _bandos.length; k++) {
    while (!usados.add(at0)) {
      at0 = (at0 + 1) % _bandos.length;
    }
    final (dice, y) = _bandos[at0];
    out.add(Notice(NoticeKind.pueblo, dice, y));
    at0 = (at0 + paso) % _bandos.length;
  }
  return out;
}

/// Cuántos hay. Para que el catálogo se pueda contar sin abrirlo.
int get villageNoticeCount => _bandos.length;

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
