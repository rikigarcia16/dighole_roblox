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
Mochila nivel 3                             4.2              7.1
25 m                                        4.3              7.4
tool: Pala de acero                         5.6              9.5
ZONA 2 (50 m)                               6.4             10.9
Batería nivel 3                            6.7             11.4
tool: Pico minero                           8.0             13.5
Mochila nivel 4                            10.0             17.0
Batería nivel 4                           11.6             19.8
ZONA 3 (150 m)                             12.2             20.7
tool: Pico industrial                      14.6             24.7
Mochila nivel 5                            15.8             26.9
Batería nivel 5                           18.4             31.3
ZONA 4 (350 m)                             20.3             34.4
tool: Taladro portátil                    21.0             35.7
Mochila nivel 6                            23.8             40.4
Batería nivel 6                           25.9             44.1
tool: Taladro avanzado                     28.4             48.3
Mochila nivel 7                            31.9             54.2
tool: Excavador de plasma                  36.5             62.1
tool: Perforadora abisal                   43.1             73.2
```

### Comparación con los objetivos del encargo

| Objetivo | Meta | Estimación |
|---|---|---|
| Primera venta | primer minuto | ~0,9 min ✅ |
| Primera mejora | minutos 2–4 | ~1,9 min ✅ (Mochila nv. 2) |
| Primera herramienta importante | minutos 5–10 | ~3,7 min (Pala reforzada); Pala de acero ~9,5 min ✅ |
| Primera zona nueva | minutos 10–20 | ~11 min ✅ |

**Problema conocido:** el juego medio y avanzado va demasiado rápido (todas las herramientas en
~75 min estimados). Se subieron los precios altos y se bajó la densidad de vetas profundas, pero el
reequilibrio de verdad toca en la **Fase 3**, cuando las zonas profundas tengan contenido y se
pueda probar con jugadores reales. Estas cifras son una simulación, no datos de jugadores.
