# Economía y progresión

Todo el balance está en `src/shared/Config/`. Este documento explica los valores de partida y
cómo se comprueban.

## Bucle de dinero

- Un golpe de la pala oxidada rompe 1 celda de tierra cada 2 golpes (dureza 2, potencia 1, 0,4 s).
- En el Jardín, una celda vale de media **~1,7 monedas** (mezcla de tierra, piedra, carbón y cobre;
  medido por los tests de generación).
- Mochila inicial: 20 unidades → **~35 monedas por viaje**. Batería inicial: 60 golpes.
- Cada recurso nuevo descubierto da un bonus de 5× su valor (una vez).
- La venta y las compras solo funcionan en la superficie (carro de venta y garaje), lo que crea el
  bucle "bajar → llenar → subir → vender → mejorar".

## Bloqueos de progreso

Cada material tiene una **potencia mínima** (`requiredPower`). La roca base de cada zona exige
una herramienta mejor:

| Zona | Roca base | Potencia mínima | Herramienta |
|---|---|---:|---|
| 1 Jardín | Tierra / Piedra | 1 | Pala oxidada |
| 2 Minas Olvidadas | Pizarra | 2 | Pala reforzada |
| 3 Cuevas de Cristal | Roca cristalina | 4 | Pala de acero |
| 4 Cavernas Antiguas | Arenisca antigua | 7 | Pico minero |
| 5 Volcánicas | Basalto | 12 | Pico industrial |
| 6 Abismo | Roca abisal | 20 | Taladro portátil |
| 7 Núcleo | Materia del núcleo | 35 | Taladro avanzado |

Así las mejoras cambian lo que el jugador **puede** hacer, no solo lo rápido que lo hace.

## Simulación

`tests/balance_sim.lua` hace que un bot cave un pozo de 4×4 a través del terreno real generado,
venda al llenar la mochila o vaciar la batería, y compre siempre la mejora más barata. La columna
"jugador" multiplica por 1,7 (los jugadores no son óptimos). Mediana de 3 semillas:

```
milestone                             bot (min) est. player (min)
first sale                                  0.5              0.9
Mochila nivel 2                             1.1              1.9
first purchase                              1.1              1.9
tool: Pala reforzada                        2.2              3.7
Batería nivel 2                            2.8              4.8
first find: Fragmento antiguo               3.1              5.2
Mochila nivel 3                             4.2              7.1
25 m                                        4.3              7.4
tool: Pala de acero                         5.6              9.5
ZONA 2 (50 m)                               6.4             10.9
Batería nivel 3                            6.7             11.4
first find: Geoda                           7.8             13.2
tool: Pico minero                          10.0             17.0
Mochila nivel 4                            12.3             20.9
ZONA 3 (150 m)                             13.6             23.1
Batería nivel 4                           14.1             24.0
first find: Fósil raro                    15.0             25.6
tool: Pico industrial                      18.6             31.6
Mochila nivel 5                            22.2             37.7
ZONA 4 (350 m)                             24.7             41.9
first find: Reliquia                       25.1             42.7
Batería nivel 5                           26.4             45.0
tool: Taladro portátil                    35.3             60.0
Mochila nivel 6                            39.5             67.1
ZONA 5 (650 m)                             39.7             67.6
Batería nivel 6                           46.2             78.6
ZONA 6 (1000 m)                            55.8             94.9
tool: Taladro avanzado                     56.3             95.7
first find: Artefacto antiguo              56.3             95.8
Mochila nivel 7                            66.2            112.5
tool: Excavador de plasma                  77.3            131.4
ZONA 7 (1500 m)                            78.3            133.1
tool: Perforadora abisal                  110.0            187.1
```

### Comparación con los objetivos del encargo

| Objetivo | Meta | Estimación |
|---|---|---|
| Primera venta | primer minuto | ~0,9 min ✅ |
| Primera mejora | minutos 2–4 | ~1,9 min ✅ (Mochila nv. 2) |
| Primera herramienta importante | minutos 5–10 | ~3,7 min (Pala reforzada); Pala de acero ~9,5 min ✅ |
| Primera zona nueva | minutos 10–20 | ~11 min ✅ |

**Reequilibrio de la Fase 3:** se subieron los precios desde la Pala de acero (×2–3), los niveles
altos de mochila y batería, y la dureza de las rocas base profundas (cristalina 28, arenisca 55,
basalto 110, abisal 180, núcleo 300). Resultado estimado: núcleo en ~2 h 15 min y todas las
herramientas en ~3 h. El juego temprano no cambia.

| Hito | Estimación jugador |
|---|---|
| Zona 3 (150 m) | ~23 min |
| Zona 4 (350 m) | ~42 min |
| Zona 5 (650 m) | ~68 min |
| Zona 6 (1000 m) | ~95 min |
| Zona 7 (1500 m) | ~133 min |

Para la primera versión probablemente convenga alargar algo el tramo 650–1500 m (objetivo
orientativo 3–5 h hasta el núcleo) cuando esas zonas tengan contenido (Fase 5). Estas cifras son
una simulación de un bot que cava en línea recta, no datos de jugadores: hay que validarlas con
pruebas reales.

## Otras fuentes de monedas

- **Cofres** en cuevas (45 % de las cuevas): 40–14 000 monedas según la zona (±20 %) más 2–4
  unidades de un mineral valioso de esa profundidad. Cada cofre se abre una sola vez (guardado).
- **Hallazgos ocultos** dentro de la roca: Fragmento antiguo (2–160 m), Geoda (50–400 m),
  Fósil raro (150–700 m), Reliquia (350–1200 m), Artefacto antiguo (1000 m+). No ocupan mochila.
- **Misiones**: 12 en cadena, unas 1 500 monedas en total.
- **Pistas**: la caja del minero (150) y la placa de piedra (1 000).

La simulación cuenta los hallazgos pero no los cofres ni las misiones, así que el ritmo real será
algo más rápido de lo que indica la tabla.

## Iteración 5: misiones hasta el Núcleo y colecciones (simulación en la VM)

El simulador ya no compra la batería oculta, cavar no gasta energía y cobra las recompensas de
misión que el bot puede conseguir solo (profundidad, herramientas y hallazgos). Tiempos estimados
para un jugador real (×1,7):

| Hito | Antes | Ahora |
|---|---|---|
| Zona 2 (50 m) | 11,0 min | 10,3 min |
| Zona 3 (150 m) | 22,7 min | 20,5 min |
| Zona 4 (350 m) | 39,4 min | 35,9 min |
| Zona 5 (650 m) | 61,7 min | 52,4 min |
| Zona 6 (1000 m) | 86,1 min | 72,1 min |
| Zona 7 (1500 m) | 122,2 min | 102,8 min |

Las misiones aceleran un 10–16 % sin saltarse ninguna herramienta. Cada recompensa ronda el 10 %
del precio de la siguiente herramienta. Las colecciones (300–40 000) no entran en la simulación:
dependen de explorar, no de cavar en línea recta.
