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
