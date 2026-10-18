# Dirección artística

**Idea central:** cuanto más bajas, más extraño. La superficie es un jardín al sol. Cada capa
añade algo que no debería estar ahí: primero el trabajo humano (las Minas), luego la roca que
brilla, la arquitectura imposible, el calor, la oscuridad que respira y, por último, algo que no es
natural.

## Reglas
1. **Una paleta por capa, nunca un corte brusco.** El color del ambiente, la niebla, la gradación
   de color, el bloom, la atmósfera y las partículas cambian con la profundidad y se mezclan
   6 m a cada lado de un límite (`Util/ZoneLook`). Dentro de una capa, la parte de abajo es un 22 %
   más oscura y tiene la niebla un 30 % más cerca: bajar siempre se nota.
2. **El neón es información.** Solo brilla lo que importa: cristales, faroles, brasas, organismos
   y anomalías. El bloom tiene un umbral alto (0,95), así que solo afecta a esos materiales.
3. **El aire tiene textura.** Cada capa tiene sus partículas: polvo marrón que cae en las Minas,
   chispas frías que suben en el Cristal, arena que va de lado en las Cavernas, brasas que suben
   en las Volcánicas, esporas lentas en el Abismo y motas blancas rápidas en el Núcleo. Todo sale
   de un único emisor alrededor de la cámara, con un máximo de 20 partículas por segundo.
4. **La decoración cuenta algo** (bloque 4): cada elemento responde a quién estuvo ahí o a qué es
   ese lugar. No se colocan objetos al azar.
5. **Rendimiento antes que efecto.** Los efectos se escalan con la calidad gráfica de Roblox
   (`Visuals.qualityScale`): 30 % en calidad baja y 100 % en alta. El bloom nunca baja del 40 %
   para que los cristales sigan leyéndose.

| Capa | Paleta | Aire | Sensación |
|---|---|---|---|
| Jardín | tierra cálida | polvo fino | todavía cerca del sol |
| Minas Olvidadas | sepia y naranja de farol | polvo marrón que cae | alguien trabajó aquí |
| Cuevas de Cristal | violeta y azul frío, bloom alto | chispas que suben | la roca está viva |
| Cavernas Antiguas | oro y arena, bruma | motas de lado | muy antiguo, muy grande |
| Profundidades Volcánicas | rojo y naranja, contraste duro | brasas que suben | calor hostil |
| El Abismo | verde azulado casi negro | esporas luminosas lentas | respira |
| Núcleo Desconocido | pálido y desaturado | motas blancas rápidas | no es natural |

Valores en `src/shared/Config/Visuals.lua`. Se aplican en `AmbienceController`.

**Sin verificar en Studio:** cómo se ve. Hay que recorrer las capas, ajustar los valores a ojo y
comprobar el coste de las partículas en calidad baja.

## Escenas de cueva (bloque 4)

`Logic/ScenePlan` decide, de forma determinista por semilla y sector, qué hay en cada galería y en
cada cámara. `Services/CaveScenes` lo construye con piezas. El plan es puro y tiene test: cada
objeto está sobre suelo real o cuelga de un techo real, nunca dentro de la sala del Contador ni
fuera de su estilo, y el sector no pasa de 60 objetos.

| Estilo | Qué cuenta | Escenas |
|---|---|---|
| Minas | Alguien trabajó aquí y se fue con prisa | Raíles en las galerías llanas; una vagoneta en un fondo de saco, a veces volcada con el mineral por el suelo; el **campamento de E.** (saco de dormir, caja con farol que parpadea, pico apoyado, hoguera fría y una tabla con «E.»); **flechas de tiza** de E. en las galerías que llevan al Contador |
| Cristal | La roca está viva | Racimos de cristal colgando del techo; un **corazón de cristal** que late en las cámaras grandes |
| Ruinas | Lo construyó alguien | Arcos con un glifo; a veces uno derrumbado; columnas caídas |
| Lava | Calor hostil | Columnas de basalto con una grieta encendida; una fumarola que suelta brasas |
| Abismo | Respira | Lianas luminosas que cuelgan y laten; una nube de esporas |
| Núcleo | No es natural | Fragmentos que flotan y giran |
| Todas | Escala | Estalactitas y estalagmitas en las cámaras |

**Medido en la VM** (30 semillas × 47 sectores): 7,1 objetos por sector de media y 18 como máximo,
es decir, unas 30 piezas por sector de media y unas 180 en el peor caso. Solo el corazón de
cristal, la fumarola y el farol del campamento llevan luz.

**Vida ambiental** (`AmbientLifeController`, en el cliente): el farol y la fumarola parpadean, los
cristales y los bulbos laten, los fragmentos del Núcleo giran y, cada 4–10 s (según la calidad
gráfica), cae un poco de polvo del techo cerca del jugador si hay techo a más de 6 studs. Solo se
anima lo que está a menos de 140 studs: una lista de, como máximo, los 80 objetos cercanos, recalculada
cada 0,5 s y animada en cada fotograma.

**Sin verificar en Studio:** aspecto, escala y piezas reales por sector (contarlas con
`#workspace.World:GetDescendants()` tras bajar 300 m), y el coste por fotograma de la animación
ambiental.
