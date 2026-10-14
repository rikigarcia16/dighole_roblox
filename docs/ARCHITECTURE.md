# Arquitectura técnica

## 1. Motor de excavación: decisión

**Elegido: Roblox Terrain (vóxeles de 4 studs) + estado lógico propio por celdas.**

| Opción | Ventajas | Inconvenientes |
|---|---|---|
| **Terrain + celdas lógicas (elegida)** | Deformación real con colisión, render y replicación gestionados por el motor (C++). Coste de red mínimo: los cambios de vóxeles se replican solos. Sin límite práctico de profundidad. Se ve bien (terreno suave) y escala a móvil. | Solo ~22 materiales de terreno y los colores son globales (1 material = 1 recurso). Resolución mínima de 4 studs. El aspecto es "suave", no bloques cúbicos. |
| Parts por bloque | Control total del aspecto (cubos, texturas). | Miles de Parts por parcela: memoria, física y replicación caras; inviable a 1500 m con varios jugadores. |
| Chunks de MeshParts / EditableMesh | Aspecto libre y menos instancias. | Generar colisiones de mallas dinámicas es caro y EditableMesh tiene límites de memoria y de publicación; mucho más código. |

### Cómo funciona

- El mundo de cada parcela es una **función pura** de `(semilla, celdas excavadas, daño parcial)`.
  `Logic/OreGeneration.resourceAt(seed, x, d, z)` decide qué recurso hay en cada celda.
  No hace falta guardar vóxeles: cualquier región se puede regenerar idéntica.
- **Celda = 1 vóxel de 4×4×4 studs = 1 metro de profundidad** (`GameConfig.CellSize`, `StudsPerMeter`).
- La zona excavable es de 16×16 celdas (64×64 studs) rodeada por un **anillo protegido** de una
  celda: el jugador nunca puede abrir el agujero hacia el vacío ni hacia las construcciones.
- **Generación por chunks bajo demanda**: capas horizontales de 16 celdas
  (`TerrainChunkService.ensureDepth`). Siempre hay `GenerateAheadCells` (32 m) generados por debajo
  de la excavación más profunda. Una parcela nueva solo genera 48 m.
- Cada golpe hace **una sola** escritura `Terrain:WriteVoxels` sobre la caja mínima que contiene las
  celdas afectadas (como mucho 7×7×7 con el radio máximo).
- **Daño parcial visible**: una celda dañada reduce su ocupación (`1 - daño/dureza`, mínimo 0.25),
  así cada golpe cambia el terreno aunque no rompa la celda.
- **Recompensas sin lecturas de vóxeles**: como el contenido es determinista, el servidor sabe qué
  material tenía cada celda rota sin `ReadVoxels`. Una celda solo se puede romper una vez
  (`plot.dug`), así que no hay duplicación.

### Flujo de un golpe

```
Cliente                              Servidor (DiggingService)
mantener clic / E / R2 / CAVAR
raycast al terreno (alcance)
cooldown local, swing + sonido  ──Dig(pos, normal)──▶  tipos y valores finitos
                                                       rate limit (token bucket)
                                                       herramienta equipada == perfil
                                                       cooldown de la herramienta (tolerancia 0.8)
                                                       alcance desde HumanoidRootPart
                                                       parcela + permiso (dueño/colaborador)
                                                       celda dentro de la zona excavable
                                                       línea de visión (raycast servidor)
                                                       potencia >= potencia mínima del material
                                                       energía suficiente
                                                       aplicar daño → WriteVoxels
                                                       recompensas → mochila / descubrimientos
                                                       generar chunks por delante
              ◀──DigFx (a jugadores cercanos)──        progreso, zona nueva, estado
partículas, fragmentos, sonido
```

## 2. Persistencia

`PlayerDataService` usa DataStoreService con:

- **Bloqueo de sesión** (`{ data, lock = { jobId, time } }`) mediante `UpdateAsync`. Un servidor
  solo escribe si tiene el bloqueo; si otro lo tiene, espera y reintenta; si sigue bloqueado,
  expulsa con un mensaje en vez de arriesgar una sobrescritura. Los bloqueos se renuevan en cada
  autoguardado y caducan a los 6 min (servidor caído).
- **Reintentos con espera exponencial** en cada llamada.
- **Perfil temporal** si el DataStore no está disponible (Studio sin acceso a API, caída de
  Roblox): se juega, se avisa al jugador y **nunca** se escribe, para no pisar datos reales.
- **Versionado** (`ProfileSchema.CURRENT_VERSION`) con migraciones y saneado completo al cargar
  (ids desconocidos, NaN, negativos, niveles fuera de rango...).
- Autoguardado cada 120 s, al salir y en `BindToClose`.

### Qué se guarda del terreno

| Dato | Se guarda | Cómo se reconstruye |
|---|---|---|
| Semilla de la parcela | Sí | — |
| Celdas excavadas | Sí, codificadas por tramos (`CellSet`, RLE con deltas) | Se regenera el terreno desde la semilla y se vacían esas celdas |
| Daño parcial de celdas | No (cosmético, como mucho un golpe de progreso) | La celda vuelve a estar entera |
| Mayor profundidad, zonas alcanzadas | Sí | — |

Tamaño estimado: una capa 16×16 completamente excavada son ~16 tramos; un pozo de 1500 m
entero cabe en unas decenas de KB, muy por debajo del límite de 4 MB por clave.

## 3. Multijugador

- Hasta 8 parcelas por servidor (`GameConfig.MaxPlots`), una por jugador, separadas 288 studs.
- Cada parcela tiene su propia semilla y estado; el progreso es individual.
- El permiso de excavación se comprueba en el servidor (`PlotService.canDig`: dueño o
  `collaborators`). Las invitaciones con interfaz llegan en la Fase 4; la estructura ya existe.
- Las recompensas van siempre al jugador que golpea.
- El terreno se replica de forma nativa, así que todos ven el mismo agujero sin código de red.
- Los efectos (`DigFx`) solo se envían a jugadores en un radio de 220 studs.

## 4. Seguridad

El servidor es la autoridad de monedas, inventario, compras, minería, recompensas, rarezas y
desbloqueos. El cliente solo envía: punto de golpe, "vender", "volver a la superficie" y
acciones de tienda con un id. Cada remote tiene limitador de frecuencia y validación de tipos.
Compras y ventas exigen estar cerca del garaje o del carro (distancia medida en el servidor).

## 5. Rendimiento

- Sin bucles por frame en el servidor salvo la recarga de energía (cada 0,25 s, O(jugadores)).
- Generación incremental de chunks (≈5 000 vóxeles por chunk) y una escritura por golpe.
- Cliente: partículas, fragmentos y sonidos en pools fijos (48 fragmentos, 8 emisores, 12 sonidos).
- `StreamingEnabled` activo.
- **Pendiente de medir en Studio con MicroProfiler** (no se ha podido ejecutar el motor aquí).

## 6. Organización del código

```
Shared/Config      datos de balance (sin lógica)
Shared/Util        utilidades puras compartidas
Server/Logic       lógica pura testeable fuera de Roblox
Server/Services    servicios con estado; init.server.lua los arranca en orden
Client/Controllers input, efectos, ambiente, HUD
Client/UI          componentes y pantallas
```

Los nombres del encargo se corresponden así: `GameConfig` → `Config/*`; `PlayerDataService`;
`DiggingService`; `TerrainChunkService`; `OreGenerationService` → `Logic/OreGeneration`;
`InventoryService` (inventario + descubrimientos + venta); `EconomyService` → monedas dentro de
`InventoryService`/`ShopService`; `ShopService` (herramientas y mejoras); `EquipmentService`;
`EnergyService`; `PlotService`; `StateService` (sincronización); `EffectsController`;
`UIController`. `QuestService`, `MultiplayerService` (invitaciones) y `CheckpointService` llegan en
fases posteriores.
