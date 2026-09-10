/// Los papeles que el pueblo clava en su tablón, uno por línea.
///
/// Aquí sólo hay texto. Quién se lleva cuál y en qué día está en
/// `gossip.dart`, y la única razón de que sean dos archivos es que esto no
/// para de crecer: mezclar cuatrocientas frases con el reparto convertía un
/// archivo de treinta líneas de lógica en uno de novecientas, y a partir de
/// ahí nadie vuelve a leer la lógica.
///
/// **Para añadir uno**: una pareja más al final, el titular y el renglón de
/// debajo. No hay número que cuadrar en ningún otro sitio — el reparto se hace
/// sobre lo que haya, y el orden de la lista tampoco importa, porque se baraja
/// entera cada día.
///
/// La única regla: que no hablen de quien usa la app. Eso es lo que dice el
/// tablón por su cuenta, con las cuentas delante, y un bando que lo imitara
/// sería el pueblo inventándose algo sobre alguien.
library;

/// El catálogo entero. El titular, y el renglón que va debajo.
const List<(String, String)> bandos = [
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
  (
    'Se busca una oveja gris.',
    'Responde por Blanca, lo cual no ayuda demasiado.',
  ),
  (
    'El campanero pide que no tiren piedras a la campana.',
    'La campana ya tiene bastante con lo suyo.',
  ),
  (
    'Hay miel nueva en la tienda.',
    'No pregunten de qué flores. El apicultor se puso nervioso.',
  ),
  (
    'Se encontró un sombrero en la plaza.',
    'Es grande, elegante y huele a establo.',
  ),
  ('El río ha bajado mucho.', 'Los pescadores dicen que no es buena señal.'),
  (
    'La posada busca mozo.',
    'Se requiere paciencia, fuerza y saber contar hasta tres.',
  ),
  (
    'No dejar herramientas junto al pozo.',
    'La última acabó abajo y ahora tenemos dos problemas.',
  ),
  (
    'El alcalde convoca reunión al anochecer.',
    'Dice que es importante. No quiso decir por qué.',
  ),
  ('Se venden huevos frescos.', 'Si alguno rompe un huevo, se lo queda.'),
  ('El tejedor terminó una manta enorme.', 'Nadie sabe para quién era.'),
  (
    'La cabra del herrero volvió.',
    'Nadie sabe dónde estuvo. Ella tampoco parece dispuesta a explicarlo.',
  ),
  (
    'Se busca aprendiz de carpintero.',
    'Saber distinguir un martillo de un hacha sería un buen comienzo.',
  ),
  (
    'No cruzar el bosque después de la puesta del sol.',
    'No por las criaturas. Por el barro.',
  ),
  (
    'La cosecha de cebollas ha sido excelente.',
    'Demasiado excelente, según el cocinero.',
  ),
  (
    'Alguien dejó flores en la puerta de la iglesia.',
    'Nadie admite haberlas puesto.',
  ),
  (
    'La panadera vuelve a vender bollos de miel.',
    'Esta vez ha prometido no quemarlos.',
  ),
  (
    'Se necesita un burro para transportar leña.',
    'El burro también puede opinar, pero no suele hacerlo.',
  ),
  ('El cazador perdió su arco.', 'Lo dejó en algún sitio entre aquí y allí.'),
  ('La fuente vuelve a funcionar.', 'No preguntéis qué había atascándola.'),
  (
    'Se encontró una moneda en el camino.',
    'Es demasiado vieja para saber de quién era.',
  ),
  (
    'El carnicero cierra temprano hoy.',
    'Tiene una cita. No quiso especificar con quién.',
  ),
  (
    'Se ruega cerrar las gallinas por la noche.',
    'Las últimas tres noches alguien las dejó salir.',
  ),
  (
    'Hay trabajo descargando sacos en el molino.',
    'Se paga al terminar, si todavía podéis mover los brazos.',
  ),
  ('El médico pide que no le lleven más gallinas.', 'Ya tiene suficientes.'),
  ('El pozo está limpio.', 'Por fin podemos decirlo sin mentir.'),
  (
    'Se perdió una cuchara de plata.',
    'No es exactamente de plata, pero el dueño insiste.',
  ),
  (
    'La señora del molino busca a su gato.',
    'Es negro, gordo y probablemente no quiera volver.',
  ),
  ('El herrero arregla herraduras hoy.', 'Las espadas tendrán que esperar.'),
  (
    'Se encontraron huellas grandes junto al río.',
    'Probablemente de un ciervo. Probablemente.',
  ),
  (
    'El molino estará cerrado mañana.',
    'La rueda necesita descanso. El molinero también.',
  ),
  ('Se venden zanahorias.', 'Son pequeñas, pero tienen carácter.'),
  (
    'La plaza necesita barrer.',
    'Si alguien encuentra una moneda mientras lo hace, que recuerde quién puso el aviso.',
  ),
  ('El pastor vuelve del monte al mediodía.', 'Dice que trae noticias.'),
  ('Hay una nueva posadera.', 'Su sopa es excelente. Su humor, menos.'),
  (
    'No tocar la campana fuera de horario.',
    'Ya tuvimos suficiente alarma por un gato.',
  ),
  (
    'Se busca dueño de un caballo marrón.',
    'El caballo parece bastante seguro de que tiene dueño.',
  ),
  (
    'El río trae ramas de lugares desconocidos.',
    'El agua sigue bajando desde las montañas.',
  ),
  (
    'Se necesita quien repare tres carretas.',
    'Dos tienen ruedas y una tiene esperanza.',
  ),
  (
    'El alcalde perdió las llaves.',
    'Dice que fue un accidente. Las perdió por tercera vez.',
  ),
  (
    'El mercado será más pequeño este domingo.',
    'Los comerciantes también necesitan dormir alguna vez.',
  ),
  ('Se encontró un anillo junto al puente.', 'No parece barato.'),
  (
    'El viejo Olegario vuelve a contar su historia.',
    'Dice que esta vez nadie le creerá. Tiene razón.',
  ),
  (
    'El carpintero vende mesas.',
    'Son sólidas, pesadas y prácticamente imposibles de mover.',
  ),
  (
    'El granero necesita techo nuevo.',
    'El actual tiene una relación complicada con la lluvia.',
  ),
  ('La campana sonó sola anoche.', 'El campanero asegura que no fue él.'),
  ('Se buscan manos para recoger manzanas.', 'Traed las vuestras.'),
  (
    'El río tiene peces otra vez.',
    'Los pescadores ya están discutiendo quién los vio primero.',
  ),
  (
    'Hay una carta para alguien del pueblo.',
    'Lleva aquí tanto tiempo que ya parece parte del mobiliario.',
  ),
  (
    'Se perdió un pañuelo rojo.',
    'Tiene bordadas las iniciales de alguien que no quiere decir cuáles.',
  ),
  (
    'La herrería permanecerá cerrada hasta el lunes.',
    'El herrero se tomó el fin de semana muy en serio.',
  ),
  ('Se encontró un perro en la plaza.', 'Él parece creer que vive aquí.'),
  (
    'El panadero pide que no golpeen la puerta antes del amanecer.',
    'Sobre todo si no van a comprar pan.',
  ),
  (
    'Hay una vaca en el huerto.',
    'El dueño tiene hasta el mediodía para reconocerla.',
  ),
  (
    'La cosecha de trigo empieza mañana.',
    'Quien falte tendrá que escuchar al capataz durante horas.',
  ),
  ('La fuente sabe mejor después de hervirla.', 'Nadie sabe por qué.'),
  (
    'El alcalde compró una nueva capa.',
    'La anterior no era tan vieja como él decía.',
  ),
  (
    'Se necesitan velas para la iglesia.',
    'También sirven para quienes tienen cosas que hacer después de oscurecer.',
  ),
  (
    'Un cuervo lleva días siguiendo al cartero.',
    'El cartero dice que no le debe nada.',
  ),
  (
    'Se alquila una habitación.',
    'Da al patio y escucha perfectamente los gallos.',
  ),
  (
    'El granjero busca un espantapájaros.',
    'Los cuervos ya se acostumbraron al anterior.',
  ),
  (
    'Se encontró una pala en el cementerio.',
    'Nadie recuerda haberla dejado allí.',
  ),
  (
    'El río amaneció cubierto de niebla.',
    'Los pescadores esperarán un poco antes de salir.',
  ),
  ('La taberna sirve estofado.', 'Hoy sí contiene carne.'),
  ('El herrero busca carbón.', 'Paga bien y pregunta poco.'),
  ('Se perdió una cesta de huevos.', 'El ladrón tuvo que ser muy cuidadoso.'),
  (
    'El puente necesita reparaciones.',
    'Aguanta, pero cada vez suena más convencido de lo contrario.',
  ),
  (
    'Se venden botas usadas.',
    'Sólo tienen dos dueños anteriores. Que sepamos.',
  ),
  ('El boticario prepara un remedio nuevo.', 'Dice que esta vez no explota.'),
  (
    'La iglesia necesita limpiar las ventanas.',
    'Desde dentro se ve menos de lo que debería.',
  ),
  (
    'Alguien ha dejado un saco de harina en la plaza.',
    'Nadie quiere admitir que lo olvidó.',
  ),
  (
    'El pastor cuenta una oveja menos.',
    'La oveja, por su parte, parece contar al pastor menos.',
  ),
  (
    'Se buscan voluntarios para reparar la muralla.',
    'No hace falta experiencia. La muralla tampoco tiene mucha.',
  ),
  (
    'La posada perdió una llave.',
    'Si aparece en vuestra habitación, no preguntéis cómo llegó.',
  ),
  ('Se encontró una caja cerrada junto al río.', 'Está vacía. Creemos.'),
  (
    'El mercado tendrá manzanas del sur.',
    'Son caras, pero vienen de muy lejos y eso parece importante.',
  ),
  (
    'El granjero ofrece leche fresca.',
    'Fresca de verdad. La vaca sigue enfadada.',
  ),
  ('No dejar comida en la plaza.', 'El cuervo ya tiene suficiente poder.'),
  (
    'Se buscan músicos para el sábado.',
    'Si sabéis tocar algo, ya sois mejores que los últimos.',
  ),
  ('El tejador arreglará los tejados mañana.', 'Entrad las gallinas antes.'),
  (
    'Se encontró una hebilla de hierro.',
    'No parece pertenecer a ninguna ropa del pueblo.',
  ),
  (
    'El molino hace un ruido nuevo.',
    'El molinero dice que es normal. No parece convencido.',
  ),
  (
    'La señora Marta vende mermelada.',
    'La de ciruela está especialmente buena.',
  ),
  ('Se necesita alguien que sepa nadar.', 'No preguntéis todavía para qué.'),
  ('La campana tiene una grieta.', 'Aun así, suena mejor que el campanero.'),
  (
    'El cazador vuelve mañana.',
    'Espera traer carne, si los ciervos colaboran.',
  ),
  (
    'Se busca una mula para el camino del norte.',
    'Que sea obediente sería un cambio agradable.',
  ),
  ('El pozo vuelve a tener cuerda.', 'Esta vez está atada a algo.'),
  (
    'Se encontró una carta en la posada.',
    'Está escrita en un idioma que nadie reconoce.',
  ),
  (
    'La panadería cierra los martes.',
    'El martes pasado alguien compró todo el pan y el pueblo todavía habla de ello.',
  ),
  (
    'El herrador tiene turno libre el jueves.',
    'Reservad antes de que el caballo se canse de esperar.',
  ),
  (
    'Se vende madera seca.',
    'La mojada también estaba a la venta, pero no funcionó.',
  ),
  (
    'El río trae peces pequeños.',
    'El pescador dice que pronto vendrán los grandes.',
  ),
  (
    'El alcalde pide silencio mañana al amanecer.',
    'Tiene previsto anunciar algo.',
  ),
  ('Se busca quien haya visto una carreta azul.', 'No era azul ayer.'),
  ('El granero estará cerrado esta noche.', 'Hay que contar el trigo.'),
  (
    'El pastor encontró una moneda antigua.',
    'Ahora todos quieren encontrar otra.',
  ),
  (
    'Se necesita un nuevo cubo para el pozo.',
    'El anterior decidió descansar en el fondo.',
  ),
  (
    'La posada tiene sopa caliente.',
    'No preguntéis qué hora es; siempre está caliente.',
  ),
  ('Se encontró una espada rota cerca del camino.', 'No hay sangre alrededor.'),
  (
    'El carpintero terminó el ataúd.',
    'Esperemos que tarde mucho en necesitarse.',
  ),
  (
    'El pueblo tendrá visita mañana.',
    'El alcalde ha pedido que nadie haga preguntas raras.',
  ),
  (
    'Se buscan voluntarios para apagar el horno de la panadería.',
    'El panadero dice que es urgente.',
  ),
  ('El río está creciendo.', 'Los pescadores han recogido sus cosas.'),
  ('Se vende lana recién esquilada.', 'La oveja ya se ha olvidado del asunto.'),
  ('Alguien ha estado dejando piedras en el camino.', 'Nadie sabe por qué.'),
  (
    'El molinero necesita ayuda con la rueda.',
    'Dice que pesa poco. No le creáis.',
  ),
  (
    'La taberna tiene música esta noche.',
    'El músico sólo conoce tres canciones.',
  ),
  (
    'Se perdió un candil.',
    'Si lo encontráis de noche, probablemente lo veáis.',
  ),
  (
    'La fuente está fría incluso al mediodía.',
    'Siempre lo estuvo, pero hoy alguien se dio cuenta.',
  ),
  ('El boticario compra hierbas raras.', 'Mejor no preguntarle para qué.'),
  ('Se encontró un guante en la plaza.', 'El otro apareció en el molino.'),
  (
    'La cosecha de cebada empieza el viernes.',
    'El que no quiera trabajar puede empezar a buscar excusas hoy.',
  ),
  (
    'El alcalde ha prohibido correr por la plaza.',
    'Preguntad al niño que rompió la fuente.',
  ),
  (
    'Se busca una gallina especialmente grande.',
    'No está perdida. Sólo necesitamos saber de quién es.',
  ),
  ('El puente ha sido reforzado.', 'Esta vez el carpintero vino con planos.'),
  ('El herrero tiene una espada abandonada.', 'Nadie ha venido a reclamarla.'),
  ('El pastor oyó campanas en el bosque.', 'No hay campanas en el bosque.'),
  (
    'Se necesitan sacos para la cosecha.',
    'Los viejos tienen agujeros y los nuevos cuestan demasiado.',
  ),
  (
    'La posada acepta reservas para el sábado.',
    'El perro ocupa una cama, como siempre.',
  ),
  ('Se encontró un reloj que no funciona.', 'Marca siempre la misma hora.'),
  (
    'El río vuelve a sonar fuerte por la noche.',
    'Los que viven cerca dicen que es normal.',
  ),
  ('El panadero necesita harina.', 'Mucha. Demasiada, según el almacén.'),
  (
    'Se vende una carreta.',
    'Tiene una rueda nueva y tres que todavía aguantan.',
  ),
  (
    'El alcalde pide que nadie toque la estatua.',
    'Especialmente nadie que diga "sólo estaba mirando".',
  ),
  (
    'Se perdió un libro.',
    'Tiene más páginas de las que alguien del pueblo ha leído en su vida.',
  ),
  ('El cementerio necesita flores.', 'Alguien se llevó las últimas.'),
  (
    'El cazador encontró huellas enormes.',
    'Dice que eran de oso. El resto dice que eran de oso porque no quiere discutir.',
  ),
  (
    'Se buscan recolectores de setas.',
    'El boticario paga mejor por las que no mata a nadie.',
  ),
  (
    'La taberna necesita barriles vacíos.',
    'No tardarán mucho en volver a estar llenos.',
  ),
  (
    'El herrador se ausentará dos días.',
    'Su aprendiz dice que sabe hacerlo. Su caballo no está tan seguro.',
  ),
  (
    'La campana volvió a sonar a medianoche.',
    'El campanero insiste en que esta vez tampoco fue él.',
  ),
  (
    'Se encontró una bolsa de monedas.',
    'Hay menos cada vez que alguien la cuenta.',
  ),
  ('El granjero busca ayuda con el establo.', 'Lleva semanas posponiéndolo.'),
  (
    'La plaza tendrá mercado mañana.',
    'Traed lo que tengáis y fingid que vale mucho.',
  ),
  (
    'Se venden conejos.',
    'Vivos, por supuesto. Los otros no tuvieron tanta suerte.',
  ),
  (
    'El río se ha llevado parte de la orilla.',
    'La orilla nueva queda bastante fea.',
  ),
  (
    'La iglesia busca un nuevo campanero.',
    'Se valorará no tener miedo a las alturas.',
  ),
  (
    'El carpintero encontró termitas.',
    'Ahora todos miran sus casas con preocupación.',
  ),
  (
    'Se perdió una llave grande.',
    'El dueño sabe qué abre. Dice que no importa.',
  ),
  (
    'La panadera pide que devuelvan sus bandejas.',
    'Algunas llevan meses viajando por el pueblo.',
  ),
  ('Hay una nueva señal en el camino.', 'Nadie recuerda haberla puesto.'),
  ('Se necesitan leñadores.', 'El invierno no espera a nadie.'),
  ('El pastor ofrece lana.', 'No acepta ovejas a cambio.'),
  (
    'La posada tiene habitación libre.',
    'Sólo una. Y está al lado de la cocina.',
  ),
  ('El molino comprará trigo mañana.', 'Siempre que no venga mojado.'),
  ('Se encontró una bota junto al río.', 'De nuevo, sólo una.'),
  ('El herrero ha terminado una armadura.', 'No sabemos para quién.'),
  (
    'Se busca quien haya visto al alcalde ayer.',
    'Él dice que estaba aquí. Nadie lo vio.',
  ),
  ('El boticario pide frascos vacíos.', 'No pregunta de dónde vienen.'),
  ('La fuente está rodeada de flores nuevas.', 'Alguien las planta de noche.'),
  ('Se venden manzanas rojas.', 'Algunas tienen marcas de dientes.'),
  (
    'El granjero ha perdido tres gallinas.',
    'Sospecha del zorro. El zorro no ha sido interrogado.',
  ),
  ('La muralla necesita piedras.', 'Las que faltan siguen sin aparecer.'),
  (
    'Se encontró una flauta en el bosque.',
    'Suena mal incluso cuando nadie la toca.',
  ),
  (
    'El alcalde anuncia una nueva norma.',
    'No dejar carros en medio de la plaza.',
  ),
  (
    'La posada ofrece cama y desayuno.',
    'El desayuno depende de si queda comida.',
  ),
  ('El cazador vende pieles.', 'Dice que no preguntéis de qué animal son.'),
  (
    'Se busca aprendiz de herrero.',
    'Las primeras semanas consisten principalmente en no quemarse.',
  ),
  (
    'El río está demasiado silencioso.',
    'Los pescadores prefieren cuando hace ruido.',
  ),
  ('La panadería tendrá pan negro mañana.', 'No está quemado. Esta vez.'),
  (
    'Se encontró un collar en el camino.',
    'Parece caro y nadie del pueblo reconoce el símbolo.',
  ),
  (
    'El molinero ha cerrado una puerta.',
    'Dice que siempre estuvo ahí. No es verdad.',
  ),
  ('Se necesitan manos para reparar el granero.', 'Traed guantes si tenéis.'),
  ('El cementerio tiene una tumba nueva.', 'Nadie parece saber para quién es.'),
  (
    'El herrero busca una pieza de hierro muy concreta.',
    'Dice que sabrá reconocerla cuando la vea.',
  ),
  ('La campana no sonará esta tarde.', 'El campanero tiene fiebre.'),
  ('Se vende queso fresco.', 'Muy fresco. Demasiado, según algunos.'),
  ('El pastor perdió un perro.', 'El perro volvió solo. El pastor todavía no.'),
  (
    'La plaza tendrá música el domingo.',
    'Esta vez han contratado a dos músicos.',
  ),
  (
    'Se encontraron huellas alrededor del granero.',
    'Ninguna entra. Todas salen.',
  ),
  ('La posada necesita leña.', 'Mucha. El invierno ha decidido quedarse.'),
  (
    'El alcalde busca a alguien que sepa leer mapas.',
    'Preferiblemente antes de partir.',
  ),
  ('Se perdió una cesta de manzanas.', 'La cesta apareció vacía.'),
  ('El carpintero vende una puerta.', 'Tiene bisagras nuevas y no tiene casa.'),
  ('La fuente amaneció llena de hojas.', 'No hay árboles cerca.'),
  ('El boticario compra veneno de serpiente.', 'Dice que es para medicina.'),
  (
    'Se necesita quien limpie la torre.',
    'El último voluntario no volvió a ofrecerse.',
  ),
  (
    'El herrador encontró una herradura extraña.',
    'No corresponde a ningún caballo conocido.',
  ),
  (
    'El río ha traído un tronco marcado.',
    'Tiene símbolos tallados en la corteza.',
  ),
  (
    'La iglesia perdió una vela grande.',
    'No sabemos cómo alguien puede perder una vela tan grande.',
  ),
  (
    'Se busca dueño para una cabra muy enfadada.',
    'Ella también busca dueño, aparentemente.',
  ),
  (
    'La taberna sirve cerveza nueva.',
    'El tabernero dice que es mejor. Nadie se atreve a contradecirlo.',
  ),
  ('El granjero encontró monedas en su campo.', 'Lleva tres días cavando.'),
  (
    'Se reparará el camino del norte.',
    'Primero habrá que encontrar dónde empieza.',
  ),
  (
    'El alcalde pide que no se alimenten los cuervos.',
    'Ya son demasiados y lo saben.',
  ),
  ('Se encontró una campana pequeña en el bosque.', 'No tiene badajo.'),
  (
    'La panadera busca a quien dejó una nota en su horno.',
    'No era una receta.',
  ),
  (
    'El molino necesita una nueva cuerda.',
    'La anterior desapareció durante la noche.',
  ),
  ('Se venden flores del valle.', 'Algunas sólo abren después del anochecer.'),
  ('El cazador recomienda no acercarse al pantano.', 'No explica por qué.'),
  (
    'El pastor dice haber visto luces en la colina.',
    'Esta vez no estaba borracho.',
  ),
  (
    'La posada tiene un huésped que nadie conoce.',
    'Paga por adelantado y no habla mucho.',
  ),
  (
    'Se encontró una bolsa de semillas junto a la muralla.',
    'Nadie sabe qué crecen.',
  ),
  (
    'El herrero escuchó golpes bajo su taller.',
    'Ha decidido no investigar hasta mañana.',
  ),
  (
    'El río trae agua turbia desde el norte.',
    'Conviene esperar antes de beber.',
  ),
  (
    'El alcalde ordena cerrar las puertas al anochecer.',
    'Dice que es por seguridad.',
  ),
  (
    'Se encontró una carta sin remitente.',
    'Sólo tiene escrito el nombre del pueblo.',
  ),
  ('El cuervo volvió a robar una cuchara.', 'Ya tiene cinco.'),
  (
    'Alguien dejó una vela encendida junto al cementerio.',
    'Se apagó sola antes del amanecer.',
  ),
  (
    'Aviso: si encontráis algo extraño en el camino, no lo llevéis a la plaza.',
    'Ya no tenemos sitio.',
  ),
  (
    'Hoy se casa la hija del panadero.',
    'La boda será en la plaza. El pan, en cambio, se sirve donde siempre.',
  ),
  (
    'El alcalde ha pedido prestado un caballo.',
    'Todavía no ha encontrado al caballo ni al que se lo prestó.',
  ),
  (
    'Hay luna llena esta noche.',
    'Las ventanas de la posada ya están cerradas por si acaso.',
  ),
  (
    'El pequeño Emil encontró una rana dorada.',
    'Ahora lleva dos días intentando encontrar otra.',
  ),
  (
    'La señora Greta cumple ochenta años.',
    'Ha pedido que nadie mencione el número.',
  ),
  (
    'El músico de la plaza toca gratis hoy.',
    'Dice que tiene una deuda con alguien.',
  ),
  (
    'El perro del cartero aprendió a abrir puertas.',
    'El cartero considera que esto es una habilidad peligrosa.',
  ),
  (
    'Llegó un mercader de tierras lejanas.',
    'Vende especias que hacen estornudar hasta a los caballos.',
  ),
  (
    'Se ha visto un arcoíris sobre el bosque.',
    'Los niños dicen que termina detrás de la colina.',
  ),
  (
    'La posada está preparando una fiesta.',
    'El posadero lleva tres días diciendo que "todavía falta algo".',
  ),
  (
    'El viejo Tomás cuenta que de joven cruzó las montañas.',
    'Su nieta dice que nunca salió del pueblo.',
  ),
  (
    'Una gallina puso un huevo azul.',
    'El sacerdote ha sido consultado. No supo qué responder.',
  ),
  (
    'Mañana llega el recaudador de impuestos.',
    'La plaza amaneció misteriosamente vacía esta mañana.',
  ),
  ('Hay un barco detenido río abajo.', 'No parece tener tripulación.'),
  (
    'El herrero se dejó crecer la barba.',
    'Nadie recuerda haberlo visto sin ella.',
  ),
  (
    'Una niña perdió su muñeca en el bosque.',
    'La encontraron sentada junto a un árbol.',
  ),
  (
    'Se venden ciruelas negras.',
    'La cesta está bajo techo. Nadie explicó por qué.',
  ),
  (
    'Esta noche habrá cuentos en la taberna.',
    'El viejo narrador exige una jarra antes de empezar.',
  ),
  (
    'La cosecha será buena este año.',
    'Los granjeros llevan semanas diciendo lo mismo, así que debe ser verdad.',
  ),
  (
    'Un desconocido preguntó por el camino viejo.',
    'Nadie usa ese camino desde hace años.',
  ),
  (
    'El gato de la posada duerme siempre sobre la misma mesa.',
    'Los clientes han aprendido a comer alrededor suyo.',
  ),
  (
    'Se encontró una estatua pequeña en el campo.',
    'El dueño de la tierra dice que ayer no estaba allí.',
  ),
  (
    'La hija del herrero quiere aprender a tocar el laúd.',
    'El laúd todavía no está de acuerdo.',
  ),
  (
    'El mercado comienza al amanecer.',
    'Los primeros en llegar se quedan con los mejores nabos.',
  ),
  (
    'El alcalde ha comprado un mapa nuevo.',
    'Lo tiene colgado al revés desde el martes.',
  ),
  (
    'Se necesitan voluntarios para el festival de primavera.',
    'Principalmente alguien que sepa dónde guardamos las cosas.',
  ),
  ('El río huele a lluvia.', 'Los pescadores juran que eso existe.'),
  (
    'Se ha perdido una carreta roja.',
    'Si la veis, avisad. Es bastante difícil de esconder.',
  ),
  (
    'La campana de la iglesia necesita una cuerda nueva.',
    'El campanero propone usar la vieja hasta que se rompa.',
  ),
  (
    'El panadero ha empezado a vender tortas con miel.',
    'Las primeras doce desaparecieron antes de llegar al mostrador.',
  ),
  (
    'Esta mañana nació un ternero blanco.',
    'Todo el mundo fue a verlo. El ternero parecía decepcionado.',
  ),
  (
    'El carpintero está fabricando una mesa enorme.',
    'No acepta preguntas sobre cuántas personas piensa sentar.',
  ),
  (
    'Un viajero dejó una carta en la posada.',
    'Volverá por ella dentro de un mes.',
  ),
  ('Hay niebla sobre las colinas.', 'Los pastores regresaron antes de tiempo.'),
  (
    'La plaza tendrá flores nuevas.',
    'Las plantaron los niños y luego discutieron sobre dónde.',
  ),
  (
    'Se busca una persona que sepa contar historias.',
    'El pueblo está cansado de la misma historia del lobo.',
  ),
  ('El río se congeló esta mañana.', 'Nadie recuerda un invierno tan frío.'),
  ('La taberna ha comprado una mesa nueva.', 'Ya tiene nombre: Gertrudis.'),
  (
    'Un cuervo ha aprendido a imitar al campanero.',
    'El campanero no está contento.',
  ),
  (
    'La hija del molinero se marcha a la ciudad.',
    'Su madre ha preparado comida para el viaje. Para tres semanas.',
  ),
  ('Hay un nuevo banco en la plaza.', 'Nadie sabe quién lo hizo.'),
  (
    'Se encontró una cesta llena de peras junto al camino.',
    'El pueblo entero espera a que alguien venga a reclamarlas.',
  ),
  (
    'El herrero busca un ayudante.',
    'El puesto incluye fuego, humo y una cantidad razonable de golpes.',
  ),
  ('Hoy se reparte sopa gratis.', 'Traed vuestro propio cuenco.'),
  (
    'Un hombre asegura haber visto un lobo blanco.',
    'El pueblo le cree porque esta vez estaba acompañado.',
  ),
  (
    'La fuente está decorada con cintas.',
    'Alguien se casa. O alguien quiere que pensemos eso.',
  ),
  ('La cosecha de uvas comienza mañana.', 'Los niños ya han empezado antes.'),
  (
    'Se encontró un zapato en la chimenea de la posada.',
    'Nadie sabe cómo llegó hasta allí.',
  ),
  (
    'El médico recomienda descansar.',
    'Él mismo lleva tres noches sin hacerlo.',
  ),
  (
    'El cartero perdió una carta.',
    'La carta llegó igual. El cartero no sabe cómo.',
  ),
  (
    'Hoy toca limpiar la plaza.',
    'Quien encuentre algo interesante puede quedárselo. Quien encuentre una rata, que avise.',
  ),
  (
    'El mercado trae telas del este.',
    'Son tan finas que algunos miran a través de ellas para comprobarlo.',
  ),
  (
    'El granjero Jacobo compró una vaca nueva.',
    'Es enorme y tiene muy malas opiniones sobre todo el mundo.',
  ),
  (
    'La campana de la iglesia está desafinada.',
    'Nadie sabía que una campana podía estarlo.',
  ),
  (
    'Se busca alguien para cuidar el huerto durante el viaje.',
    'El espantapájaros no cuenta como persona.',
  ),
  (
    'El río ha dejado piedras lisas en la orilla.',
    'Los niños se las están llevando todas.',
  ),
  (
    'Hay una nueva receta en la taberna.',
    'El cocinero la llama "estofado sorpresa". La sorpresa cambia cada día.',
  ),
  (
    'Una mujer preguntó por el camino hacia el norte.',
    'Luego siguió hacia el sur.',
  ),
  (
    'La torre estará cerrada durante la tarde.',
    'Se han encontrado abejas dentro.',
  ),
  ('El viejo molino tiene una ventana rota.', 'Nadie oyó el golpe.'),
  (
    'Se celebra el día del pueblo el próximo domingo.',
    'Habrá música, comida y un discurso demasiado largo.',
  ),
  (
    'El pastor perdió una oveja durante la tormenta.',
    'La oveja volvió antes que él.',
  ),
  (
    'El herrero fabricó un cuchillo magnífico.',
    'Ahora intenta recordar quién se lo encargó.',
  ),
  (
    'Se busca dueño para una capa verde.',
    'Está colgada en la posada desde el invierno.',
  ),
  (
    'Hay manzanas suficientes para todos.',
    'Eso dicen hasta que llega el primero con una carretilla.',
  ),
  (
    'El alcalde ha prohibido las carreras de gallinas.',
    'La última terminó en la casa del sacerdote.',
  ),
  (
    'Una niña ofrece dibujos a cambio de pan.',
    'Algunos son sorprendentemente buenos.',
  ),
  (
    'La nieve llegó temprano este año.',
    'Los niños están encantados. Los adultos ya están haciendo cuentas.',
  ),
  (
    'Se arreglará el tejado de la iglesia.',
    'Los trabajos empiezan cuando deje de llover.',
  ),
  (
    'Una familia nueva se instalará junto al río.',
    'Traen dos caballos, cinco cajas y un piano.',
  ),
  (
    'El mercado busca un nuevo pregonero.',
    'Hace falta alguien capaz de gritar sin quedarse afónico.',
  ),
  (
    'La posada ha recibido un barril de vino extranjero.',
    'El posadero lo guarda bajo llave.',
  ),
  (
    'Hay huellas de botas junto al cementerio.',
    'Son demasiado pequeñas para pertenecer al sepulturero.',
  ),
  ('El río trae hojas amarillas.', 'El otoño está llegando.'),
  (
    'La panadera regalará un bollo a cada niño.',
    'El primero que llegue tendrá dos.',
  ),
  (
    'El caballo de la alcaldesa aprendió a abrir el establo.',
    'Ahora duerme donde quiere.',
  ),
  (
    'Se busca quien pueda reparar un reloj.',
    'Marca las doce desde hace tres días.',
  ),
  (
    'El bosque está lleno de setas.',
    'El boticario pide que nadie las toque hasta que él llegue.',
  ),
  ('Hoy habrá música junto al pozo.', 'No preguntéis por qué junto al pozo.'),
  (
    'El carpintero terminó una silla para el alcalde.',
    'El alcalde todavía prefiere la vieja.',
  ),
  (
    'Un mercader ofrece brújulas.',
    'La mitad apunta al norte. La otra mitad apunta con entusiasmo.',
  ),
  ('Se encontró una pluma enorme.', 'El cazador no reconoce el ave.'),
  (
    'El sacerdote busca ayuda para ordenar los libros.',
    'Hay algunos que llevan décadas sin abrirse.',
  ),
  ('El herrero cerrará temprano.', 'Tiene una cita con el barbero.'),
  (
    'Una vaca se ha acostumbrado a la campana.',
    'Ahora se acerca cada vez que la oye.',
  ),
  (
    'La taberna necesita músicos para el viernes.',
    'Se aceptan músicos y gente que sepa fingir.',
  ),
  ('Se venden calabazas.', 'Algunas pesan más que un niño.'),
  (
    'Un viajero dejó una moneda extranjera.',
    'El mercader dice que vale poco. El viajero dijo que vale muchísimo.',
  ),
  (
    'El granero está lleno.',
    'Por primera vez en años, el granjero sonríe al decirlo.',
  ),
  (
    'La fuente se congeló por completo.',
    'Los niños ya han empezado a caminar encima.',
  ),
  (
    'Se busca un nombre para el nuevo caballo del alcalde.',
    'El alcalde ha rechazado diecisiete sugerencias.',
  ),
  (
    'El viejo puente tiene musgo nuevo.',
    'Los ancianos aseguran que siempre estuvo ahí.',
  ),
  (
    'Una mujer vende perfumes hechos con flores.',
    'El de lavanda ya tiene media plaza oliendo a primavera.',
  ),
  ('Hoy no habrá pescado.', 'Los peces parecen haberse puesto de acuerdo.'),
  (
    'El herrero tiene una quemadura nueva.',
    'Dice que no es grave. Su aprendiz opina distinto.',
  ),
  (
    'Un niño asegura que hay una puerta bajo el río.',
    'Ha hecho un dibujo para demostrarlo.',
  ),
  (
    'Se necesitan voluntarios para plantar árboles.',
    'Los que los planten podrán presumir de ellos dentro de veinte años.',
  ),
  ('El molino funcionará toda la noche.', 'Hay un pedido urgente.'),
  (
    'El alcalde ha perdido su sombrero favorito.',
    'Ofrece una recompensa. Bastante generosa para ser un sombrero.',
  ),
  (
    'Se encontró un pequeño nido en la torre.',
    'Nadie quiere ser quien lo retire.',
  ),
  (
    'La feria llega dentro de una semana.',
    'Ya se escucha a los comerciantes discutir por los puestos.',
  ),
  (
    'El pueblo tiene un nuevo reloj de sol.',
    'Funciona perfectamente cuando hay sol.',
  ),
  (
    'La posadera aprendió una canción nueva.',
    'Ahora la canta mientras trabaja.',
  ),
  (
    'Se busca una persona para acompañar al mercader hasta el siguiente pueblo.',
    'Viaje tranquilo, salvo por el camino.',
  ),
  (
    'La cosecha de calabazas fue extraordinaria.',
    'El problema es encontrar dónde ponerlas.',
  ),
  (
    'Una tormenta rompió tres árboles.',
    'El carpintero ya está tomando medidas.',
  ),
  (
    'El panadero necesita ayuda esta madrugada.',
    'El que quiera dormir puede volver mañana.',
  ),
  (
    'Hay una carta sellada para el alcalde.',
    'Lleva el escudo de un lugar que nadie reconoce.',
  ),
  (
    'Se ha visto humo detrás de la colina.',
    'Los pastores dicen que viene de una fogata.',
  ),
  (
    'El perro del herrero tiene un nuevo collar.',
    'Se lo ganó por perseguir ladrones. O gallinas. Nadie está seguro.',
  ),
  ('El cementerio necesita una nueva verja.', 'La anterior decidió tumbarse.'),
  (
    'Se venden velas aromáticas.',
    'La de canela hace que la taberna huela a Navidad.',
  ),
  (
    'El río trajo un tronco enorme.',
    'El carpintero lleva toda la mañana mirándolo.',
  ),
  ('La niña de la casa azul toca el violín.', 'Ya no tan mal como antes.'),
  (
    'El alcalde invita a cenar a los ancianos del pueblo.',
    'Nadie sabe qué está tramando.',
  ),
  (
    'Se encontró un saco de harina en medio del camino.',
    'La carreta que lo llevaba sigue sin aparecer.',
  ),
  (
    'El molino tiene un visitante nuevo.',
    'Lleva sombrero rojo y no habla con nadie.',
  ),
  (
    'Se buscan voluntarios para apagar las luces de la plaza.',
    'Una tarea sencilla, dicen.',
  ),
  (
    'La taberna ofrece alojamiento gratis al viajero número cien.',
    'Van por noventa y ocho.',
  ),
  ('Un niño dejó un dibujo de un dragón en el tablón.', 'Tiene seis patas.'),
  (
    'Se acerca una tormenta desde el oeste.',
    'Los granjeros ya están guardando las herramientas.',
  ),
  ('La posada recibió una caja de limones.', 'Nadie sabe quién la envió.'),
  (
    'El herrero ha pedido silencio durante una hora.',
    'Está intentando recordar algo.',
  ),
  (
    'Se encontró una llave oxidada en el bosque.',
    'Parece demasiado grande para una casa.',
  ),
  (
    'El pastor asegura que una oveja sabe su nombre.',
    'La oveja no ha confirmado nada.',
  ),
  (
    'Hay una nueva estatua en la plaza.',
    'Representa a alguien que nadie recuerda.',
  ),
  (
    'El alcalde dará un discurso mañana.',
    'Se recomienda llevar algo para sentarse.',
  ),
  (
    'El panadero ha empezado a levantarse todavía más temprano.',
    'El pueblo se niega a competir.',
  ),
  (
    'Se necesita un aprendiz de boticario.',
    'Curiosidad obligatoria. Nariz sensible, recomendable.',
  ),
  (
    'El gato negro de la plaza tiene tres casas.',
    'Él parece considerar que todas son suyas.',
  ),
  (
    'Se venden semillas de flores del sur.',
    'Dicen que florecen incluso con poca luz.',
  ),
  ('Un hombre dejó su caballo en la posada.', 'Lleva cuatro días sin volver.'),
  ('La campana volvió a sonar de madrugada.', 'Esta vez hubo testigos.'),
  ('El puente estará cerrado mañana.', 'Pasará una caravana.'),
  (
    'El río se llevó un barril vacío.',
    'El dueño dice que lo necesita de vuelta.',
  ),
  ('La plaza está llena de huellas de barro.', 'Anoche no llovió.'),
  (
    'Se busca una flauta perdida.',
    'El dueño dice que suena mejor cuando la toca él. Nadie lo ha comprobado.',
  ),
  ('El granjero ofrece trabajo por una semana.', 'El pago incluye comida.'),
  (
    'Una familia ha dejado el pueblo.',
    'Dejaron flores en la puerta de su casa.',
  ),
  (
    'El boticario necesita frascos pequeños.',
    'También acepta grandes, pero no sabe dónde guardarlos.',
  ),
  (
    'La taberna estrenará menú el viernes.',
    'El cocinero promete tres platos que no llevan nabo.',
  ),
  ('Se ha encontrado una corona de flores en el río.', 'Todavía está fresca.'),
  (
    'El herrero fabricó una campana pequeña.',
    'La está probando con bastante entusiasmo.',
  ),
  (
    'La hija del alcalde aprendió a montar.',
    'Ahora insiste en cruzar el puente todos los días.',
  ),
  (
    'Hay una reunión de agricultores esta tarde.',
    'Tema principal: quién tiene el mejor caballo.',
  ),
  ('El carpintero necesita madera de roble.', 'La de pino se está acabando.'),
  (
    'Una anciana ofrece té a los viajeros.',
    'Dice que es bueno para recordar sueños.',
  ),
  ('El pueblo recibió sal nueva.', 'Ya no tendremos que racionarla.'),
  ('Se busca un perro pequeño y blanco.', 'Es más rápido de lo que parece.'),
  ('Una tormenta rompió la veleta.', 'Ahora apunta siempre hacia la taberna.'),
  (
    'El mercado tiene queso de cabra.',
    'El queso es bueno. La cabra, según dicen, también.',
  ),
  ('El río amaneció cubierto de flores.', 'Nadie sabe de dónde vienen.'),
  ('Se encontró una moneda enterrada bajo un banco.', 'El banco es nuevo.'),
  (
    'La posada tiene un huésped que duerme de día.',
    'Paga puntualmente y nadie quiere molestarlo.',
  ),
  (
    'El sacerdote ha pedido que alguien cuide las velas.',
    'Últimamente desaparecen demasiadas.',
  ),
  ('El alcalde compró un espejo nuevo.', 'Lleva media hora frente a él.'),
  (
    'Se necesita alguien que sepa herrar mulas.',
    'Las mulas del pueblo tienen opiniones fuertes.',
  ),
  ('La cosecha de trigo terminó.', 'Esta noche se cena en la plaza.'),
  (
    'Una carreta desconocida pasó por el pueblo al amanecer.',
    'No llevaba mercancía.',
  ),
  (
    'El perro de la posada ha aprendido una palabra.',
    'Dice "fuera". Sólo cuando llueve.',
  ),
  (
    'Se busca a quien haya dejado una vela en el bosque.',
    'Sigue apareciendo encendida.',
  ),
  (
    'La fuente está decorada con monedas.',
    'Los niños han empezado a pedir deseos.',
  ),
  ('El viejo puente sobrevivió otra primavera.', 'El carpintero también.'),
  (
    'El alcalde ha invitado a un noble.',
    'La posadera lleva dos días limpiando.',
  ),
  (
    'Una mujer vende pequeños amuletos.',
    'No promete que funcionen. Eso parece tranquilizar a algunos.',
  ),
  ('El molinero compró un perro.', 'Lo llamó Molino.'),
  ('Se encontró un libro junto al río.', 'Varias páginas hablan del pueblo.'),
  ('Hay una luz encendida en la torre.', 'Nadie recuerda haber subido.'),
  (
    'El herrero busca una piedra negra.',
    'Dice que la necesita para un trabajo importante.',
  ),
  (
    'El pastor volvió del bosque antes del amanecer.',
    'No quiso hablar durante el desayuno.',
  ),
  (
    'La panadería regalará pan duro para los animales.',
    'Se aceptan animales grandes, pequeños y hambrientos.',
  ),
  (
    'El pueblo tendrá una nueva fuente.',
    'La antigua seguirá allí por si la nueva resulta peor.',
  ),
  ('Se encontró una capa en el camino.', 'Está empapada y llena de hojas.'),
  (
    'Un comerciante ofrece mapas del valle.',
    'Algunos tienen lugares que no existen.',
  ),
  ('La iglesia celebrará una misa al amanecer.', 'Después habrá desayuno.'),
  (
    'El granjero encontró una huella de bota dentro del granero.',
    'Él no usa botas.',
  ),
  (
    'La taberna busca un nuevo cocinero.',
    'El anterior se fue después de inventar la sopa de cebolla.',
  ),
  (
    'Se venden velas para el invierno.',
    'Comprar antes de la primera nevada es una idea bastante buena.',
  ),
  (
    'Una bandada de pájaros llegó al pueblo.',
    'Se fueron al cabo de una hora, todos juntos.',
  ),
  (
    'El río está más claro que de costumbre.',
    'Los pescadores pueden ver el fondo. Eso no los tranquiliza.',
  ),
  (
    'El alcalde ha declarado día festivo.',
    'Nadie sabe qué estamos celebrando, pero nadie piensa protestar.',
  ),
  (
    'Se encontró una pequeña campana en el camino.',
    'Suena cuando no hay viento.',
  ),
  (
    'El carpintero ha construido una cama enorme.',
    'Dice que es para alguien importante.',
  ),
  (
    'Una niña ofrece flores junto a la fuente.',
    'No acepta monedas, sólo historias.',
  ),
  (
    'El mercader de especias volverá el próximo mes.',
    'Esta vez traerá canela.',
  ),
  ('Se busca al dueño de una carta sin abrir.', 'Lleva un sello de cera azul.'),
  ('La posada ha comprado un piano.', 'Nadie del pueblo sabe tocarlo.'),
  (
    'El boticario cultiva una planta nueva.',
    'La mantiene lejos de las gallinas.',
  ),
  (
    'Se oyó música en el bosque anoche.',
    'Los cazadores regresaron antes de descubrir de dónde venía.',
  ),
  (
    'El herrero ha cerrado su taller.',
    'En la puerta hay una nota que dice: "Mañana".',
  ),
  (
    'La plaza amaneció cubierta de nieve.',
    'Alguien dibujó una cara enorme antes de que saliera el sol.',
  ),
  (
    'Un viajero dejó una historia escrita en la posada.',
    'Nadie sabe si ocurrió aquí.',
  ),
  (
    'El pastor encontró una campana pequeña entre las piedras.',
    'Ninguna oveja reconoce su sonido.',
  ),
  (
    'El pueblo tiene nuevo reloj.',
    'Va cinco minutos adelantado. El alcalde dice que es para que lleguemos temprano.',
  ),
  (
    'Se busca a alguien que haya visto al zorro rojo.',
    'Lleva semanas rondando los corrales.',
  ),
  ('El río trajo una botella cerrada.', 'Dentro hay un papel.'),
  (
    'La panadera está haciendo una tarta enorme.',
    'No ha querido decir para quién.',
  ),
  (
    'Alguien ha plantado un árbol en mitad de la plaza.',
    'El alcalde todavía está decidiendo si enfadarse.',
  ),
  (
    'Esta noche habrá hoguera en la colina.',
    'Los mayores dicen que es una vieja tradición.',
  ),
  (
    'El tablón amaneció lleno de notas.',
    'Por una vez, ninguna es del alcalde.',
  ),
];
