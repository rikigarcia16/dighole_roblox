# THE HOLE NEVER ENDS

Juego de excavación para Roblox: cava, descubre, vende, mejora y sigue bajando.

> **Estado: Fases 1, 2 y 3 implementadas en código** (excavación real, parcelas, tienda, guardado,
> cuevas, cofres, hallazgos, historia, misiones y economía reequilibrada). **Todavía no se ha
> ejecutado dentro de Roblox Studio**: la lógica tiene tests automáticos y el código está comprobado
> contra los tipos de la API de Roblox, pero hay que probarlo en Studio. Ver
> [`docs/PHASE1_REPORT.md`](docs/PHASE1_REPORT.md) y [`docs/PHASE2_3_REPORT.md`](docs/PHASE2_3_REPORT.md).

## Cómo abrirlo en Roblox Studio (Rojo)

El proyecto es código Luau en archivos `.lua`, sincronizado con Studio mediante
[Rojo](https://rojo.space). Así el código vive en Git y Studio recibe los cambios en directo.

1. **Instala Rojo** en tu PC (una de estas opciones):
   - Con [Aftman](https://github.com/LPGhatguy/aftman): `aftman install` en la carpeta del repo
     (usa `aftman.toml`).
   - O descarga `rojo` desde https://github.com/rojo-rbx/rojo/releases y ponlo en tu PATH.
   - Extensión de VS Code "Rojo" (instala el binario por ti).
2. **Instala el plugin de Rojo en Studio** (si tu plugin actual es Rojo o Argon, ya está). Desde
   la terminal: `rojo plugin install`, o desde la Creator Store.
3. **Clona el repo** y entra en la carpeta:
   ```bash
   git clone https://github.com/rikigarcia16/dighole_roblox.git
   cd dighole_roblox
   ```
4. **Sirve el proyecto**: `rojo serve`
5. En Studio abre un **Baseplate vacío**, **borra la pieza `Baseplate`** (el mundo se genera por
   código), pulsa **Rojo → Connect** en la barra de plugins.
6. Activa el guardado en Studio: *Game Settings → Security → Enable Studio Access to API
   Services*. Sin esto el juego funciona igual pero avisa de que no se guarda el progreso.
7. Pulsa **Play**. Para probar multijugador: *Test → Clients and Servers → 2 Players → Start*.

Alternativa sin plugin: `rojo build -o TheHoleNeverEnds.rbxlx` y abre el archivo en Studio.

## Controles

| Acción | PC | Móvil | Mando |
|---|---|---|---|
| Cavar | Mantener clic izquierdo (apunta con el ratón) o `E` | Mantener botón **CAVAR** | Mantener `R2` |
| Mochila / descubrimientos | `B` o botón | Botón | `Y` |
| Volver a la superficie | `R` o botón (bajo 8 m) | Botón | Cruceta ↑ |
| Interactuar (vender, tienda, nota) | `F` | Tocar el aviso | `X` |
| Primera persona | Rueda del ratón | Pellizcar | — |

Si el cursor no apunta a tierra al alcance, se cava delante/debajo de los pies, así que cavar
hacia abajo es cómodo en cualquier dispositivo.

## Estructura

```
default.project.json        Mapa de Rojo (dónde va cada carpeta dentro de Roblox)
src/shared/                 ReplicatedStorage.Shared — usado por servidor y cliente
  Config/                   ← TODO el balance: recursos, zonas, herramientas, mejoras, sonidos
  Util/                     Grid (celdas↔mundo), Hash, CellSet, ToolModels, RateLimiter...
  Remotes.lua               Lista única de RemoteEvents/RemoteFunctions
src/server/                 ServerScriptService.Server
  Logic/                    Lógica pura y testeable (generación, inventario, perfil)
  Services/                 Servicios con estado (datos, parcelas, terreno, excavación, tienda...)
src/client/                 StarterPlayerScripts.Client
  Controllers/              Input de excavación, efectos, ambiente por profundidad, HUD
  UI/                       Tienda, mochila, componentes de interfaz, textos de historia
tests/                      Tests de lógica + simulación de economía
docs/                       Arquitectura, balance e informe de fase
```

## Cambiar el balance

Todo se ajusta en `src/shared/Config/` sin tocar scripts:

- `Resources.lua` — valor, dureza, potencia mínima, color, rareza, profundidad y probabilidad.
- `Zones.lua` — capas, mezcla de roca, densidad de vetas, iluminación.
- `Tools.lua` — precio, potencia, radio, cadencia, consumo, alcance, modelo.
- `Upgrades.lua` — niveles y precios de mochila y batería.
- `GameConfig.lua` — tamaño de parcela, chunks, límites de red, guardado.

Después ejecuta los tests y la simulación de economía (abajo) para comprobar el efecto.

## Tests

La lógica que no necesita el motor (configuración, generación, inventario, perfiles, guardado del
agujero y escritura de vóxeles) se prueba fuera de Studio con un pequeño runner de Luau incluido en
`tools/luaucheck` (necesita Rust). Instrucciones en [`tests/README.md`](tests/README.md):

```bash
cargo build --release --manifest-path tools/luaucheck/Cargo.toml
tools/luaucheck/target/release/luaucheck run tests/run.lua          # tests
tools/luaucheck/target/release/luaucheck run tests/balance_sim.lua  # simulación de economía
```

## Documentación

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — decisiones técnicas, excavación, persistencia, seguridad.
- [`docs/BALANCE.md`](docs/BALANCE.md) — economía y tiempos objetivo.
- [`docs/PHASE1_REPORT.md`](docs/PHASE1_REPORT.md) — Fase 1: qué está hecho, qué está probado, qué falta.
- [`docs/PHASE2_3_REPORT.md`](docs/PHASE2_3_REPORT.md) — Fases 2–3 y revisión general con los fallos corregidos.
- [`docs/AUDIT.md`](docs/AUDIT.md) — auditoría priorizada: estado real de cada sistema, límites del motor, decisiones pendientes.

Herramientas: `tools/render` dibuja cortes del subsuelo generado (útil para revisar cambios en la
generación de cuevas) y `tests/bench_generation.lua` mide el coste de generación en la VM de Luau.
