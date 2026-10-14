# Informe de la Fase 1: prototipo real

## Resumen honesto

- **Implementado:** todo el alcance de la Fase 1 y bastante de la Fase 2 (superficie decorada,
  garaje con tienda, tres o más herramientas, interfaz, efectos, primera nota del misterio).
- **Comprobado automáticamente (fuera de Roblox):** compilación de todos los scripts, análisis de
  tipos contra las definiciones de la API de Roblox, 18 tests de lógica e integración y la
  simulación de economía.
- **NO comprobado:** nada se ha ejecutado dentro de Roblox Studio. En el entorno de desarrollo no
  había Studio. Física, colisiones, replicación, aspecto visual, DataStores e input están
  **sin probar** hasta que alguien siga la lista de abajo en Studio.

## Implementado

| Requisito de la Fase 1 | Dónde |
|---|---|
| Una parcela (hasta 8 por servidor) | `PlotService`, `WorldBuilder` |
| Terreno excavable real (vóxeles, daño parcial visible, colisiones del motor) | `DiggingService`, `TerrainChunkService` |
| Pala funcional (+9 herramientas configuradas, modelos 3D procedurales distintos) | `Config/Tools`, `Util/ToolModels`, `EquipmentService` |
| Materiales (20 definidos: 9 rocas base y 11 minerales; el Jardín usa césped, tierra, piedra, carbón y cobre) | `Config/Resources`, `Logic/OreGeneration` |
| Inventario (mochila con capacidad) | `InventoryService`, `UI/InventoryUI` |
| Venta de recursos (carro de venta con ProximityPrompt) | `InventoryService.sellAll` |
| Dos mejoras (Mochila de 7 niveles, Batería de 6 niveles) | `Config/Upgrades`, `ShopService` |
| Profundidad visible (HUD + cartel de récord en la parcela) | `UIController`, `PlotService.updateBoard` |
| Guardado (monedas, herramientas, mejoras, inventario, descubrimientos, zonas, estadísticas, agujero) | `PlayerDataService`, `Logic/ProfileSchema` |

Extras ya incluidos: energía con recarga en superficie, registro de descubrimientos con bonus,
siete zonas con iluminación y niebla propias, banner de zona, linterna de cabeza, botón de volver a
la superficie, objetivo guía en el HUD, nota misteriosa en la casa, confirmación de compras grandes,
comparación de estadísticas en la tienda, controles de PC, móvil y mando.

## Comprobado

| Comprobación | Resultado |
|---|---|
| Compilación Luau de los 41 scripts | ✅ sin errores |
| Análisis de tipos con definiciones de Roblox (luau-analyze + tipos de luau-lsp) | ✅ sin errores reales; solo avisos del analizador por las rutas de `require` (necesitan el sourcemap de Rojo) |
| Configuración coherente (zonas contiguas, precios crecientes, todo material excavable) | ✅ tests |
| Generación determinista y minerales en su rango de profundidad | ✅ tests |
| Mezcla del Jardín (tierra mayoritaria, carbón y cobre presentes) | ✅ tests |
| Capacidad de la mochila, valor de venta | ✅ tests |
| Saneado de perfiles corruptos o manipulados | ✅ tests |
| Codificación del agujero (ida y vuelta, datos corruptos) | ✅ tests |
| Escritura de vóxeles: tamaño de región, alineación a la rejilla, orientación de los arrays, celdas excavadas como aire, daño parcial | ✅ test de integración con un Terrain falso |
| Limitador de frecuencia | ✅ tests |
| Tiempos de progresión iniciales | ✅ simulación (ver `BALANCE.md`) |

## Lista de prueba en Studio (los 15 criterios de aceptación)

Haz esto en Studio y marca cada punto. Prueba multijugador con *Test → Clients and Servers*.

| # | Criterio | Cómo probarlo | Estado |
|---|---|---|---|
| 1 | Entrar sin errores | Play; la Output no debe mostrar errores rojos | ⬜ sin probar |
| 2 | Tener una parcela | Apareces delante de tu agujero y el cartel dice "Parcela de <nombre>" | ⬜ |
| 3 | Equipar una pala | La pala oxidada aparece en la mano y el HUD dice "Pala oxidada · P1" | ⬜ |
| 4 | Excavar terreno real | Mantén clic; el terreno se hunde con cada golpe, puedes caer en el hueco | ⬜ |
| 5 | Descubrir un mineral | Las vetas de carbón (negro) y cobre (naranja) se ven en las paredes | ⬜ |
| 6 | Recogerlo | Aparece "+1 Cobre" a la derecha y sube la barra de la mochila | ⬜ |
| 7 | Consultar inventario | Botón Mochila o `B` | ⬜ |
| 8 | Venderlo | `↑ Superficie`, ve al carro verde, `F` | ⬜ |
| 9 | Comprar herramienta | Garaje → `F` → Pala reforzada (100) | ⬜ |
| 10 | Notar la mejora | La reforzada rompe 7 celdas por golpe y atraviesa la pizarra | ⬜ |
| 11 | Zona nueva | Baja a 50 m → banner "ZONA 2 · MINAS OLVIDADAS" | ⬜ |
| 12 | Volver a la superficie | Botón `↑ Superficie` o `R` | ⬜ |
| 13 | Salir y entrar sin perder mejoras | Con API Services activado: sal, entra; monedas, herramientas y **el agujero** siguen igual | ⬜ |
| 14 | Móvil sin errores graves | Emulador de dispositivos (teléfono): botón CAVAR, HUD legible | ⬜ |
| 15 | Jugar con otra persona | 2 jugadores: cada uno su parcela, ven los agujeros del otro, no pueden cavar la parcela ajena | ⬜ |

Rendimiento: abre el MicroProfiler (Ctrl+F6) y cava sin parar 1 minuto; anota el tiempo de
`DiggingService`/`WriteVoxels` por golpe y la memoria de terreno con 2–4 jugadores.

## Riesgos y cosas a revisar primero en Studio

1. **Orientación de la herramienta en la mano** (`ToolModels.buildTool`, `Tool.Grip`): calculada
   sobre el papel; puede necesitar girarse unos grados.
2. **Dirección del golpe del brazo** (`EffectsController.swingOffset`): si el brazo baja en vez de
   subir al prepararse, cambia el signo del ángulo.
3. **Sonidos**: se usan sonidos integrados `rbxasset://sounds/...` para no depender de audio
   ajeno. Si alguno no existe en tu versión de Studio no rompe nada (solo no suena). Para
   publicar hay que sustituirlos por audio propio.
4. **Terrain.Decoration** se desactiva desde el proyecto de Rojo; si Rojo no puede asignarlo,
   desactívalo a mano (solo afecta al césped decorativo).
5. **Teletransporte con StreamingEnabled**: se pide streaming alrededor del destino antes de
   mover al personaje; si apareces cayendo, aumenta la espera.

## Limitaciones conocidas

- La interfaz de invitar amigos a tu parcela no existe todavía (el permiso de colaborador ya está
  en el servidor). Llega en la Fase 4.
- Misiones, explosivos, movilidad (cuerda, gancho, jetpack), cofres, cuevas, ruinas y el resto de
  la historia: fases 3 a 5.
- El balance del juego medio y avanzado va demasiado rápido según la simulación (ver `BALANCE.md`).
- Los modelos son piezas low-poly hechas con Parts; en la Fase 2 conviene sustituir la casa, el
  garaje y las herramientas por MeshParts propias con más detalle.

## Siguiente paso

Seguir la lista en Studio y corregir lo que falle. Después, Fase 2: pulido visual y de sensación
(MeshParts propias, animaciones con Animator en vez de la rotación del hombro, audio propio,
primera misión y la primera sorpresa subterránea en las Minas Olvidadas).
