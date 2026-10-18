# Audio propio que necesita el juego

Hoy todos los sonidos son archivos internos de Roblox (`rbxasset://sounds/...`) reutilizados con
otro tono: cargan, pero son genéricos. Esta es la lista de lo que hace falta, por prioridad.

**Cómo integrarlos:** súbelos a Roblox (Creator Hub → Audio) y pásame los `rbxassetid://...`. Cambio
el `id` de cada clave en `src/shared/Config/Sounds.lua` sin tocar el resto del código, y la marco
`verified = true` solo después de oírla en Studio (F7 recorre todos los sonidos).

Formato: OGG o MP3, mono, sin silencio al principio (el golpe se dispara en el fotograma del
impacto). Volumen normalizado; el juego ajusta volumen y tono por clave.

## Prioridad 1: lo que se oye cientos de veces

| Clave | Cuándo suena | Duración | Carácter |
|---|---|---|---|
| `hit_soil` | Cada golpe en tierra o césped | 0,15–0,25 s | Golpe sordo de pala en tierra húmeda; poco agudo, para que no canse |
| `hit_rock` | Cada golpe en roca, pizarra, arenisca... | 0,15–0,3 s | Choque seco de metal contra piedra, con un poco de grava |
| `hit_ore` | Cada golpe en una veta (cobre, hierro, oro...) | 0,2–0,35 s | Como `hit_rock`, con un timbre metálico corto encima |
| `hit_crystal` | Cada golpe en cristal | 0,2–0,4 s | Tintineo de vidrio grueso, sin estridencia |
| `hit_lava` | Golpe en basalto u obsidiana | 0,2–0,3 s | Piedra vítrea y dura, más grave que `hit_rock` |
| `hit_dense` | Golpe en roca abisal o del núcleo | 0,25–0,4 s | Muy grave, casi un «tum» con cola corta |
| `break_soil` | La celda de tierra cede | 0,3–0,5 s | Derrumbe pequeño de tierra suelta |
| `break_rock` | La celda de roca cede | 0,4–0,6 s | Roca que se parte y cae en trozos |
| `break_ore` | Se rompe una veta | 0,4–0,6 s | Rotura de roca con un destello metálico |
| `break_crystal` | Se rompe un cristal | 0,4–0,7 s | Cristal que se quiebra, con un brillo final |
| `swing_light` | Gesto de pala (antes del impacto) | 0,15–0,25 s | Silbido corto de aire; hoy es un clic provisional porque `swoosh.wav` no carga |
| `swing_heavy` | Gesto de pico | 0,2–0,3 s | Silbido más grave y con peso |
| `too_hard` | Rebote: material demasiado duro | 0,2–0,3 s | «Clang» seco con vibración del mango |

## Prioridad 2: identidad de El Contador

| Clave | Cuándo suena | Duración | Carácter |
|---|---|---|---|
| `counter_knock` | Ritmo de tres golpes y pausa (cada 2,6 s), audible a 55 m | 0,4–0,7 s por golpe | Golpe grave de madera y metal contra piedra, como desde dentro de la roca. Debe funcionar apagado (el juego le quita agudos) y nítido de cerca |
| `counter_hum` | Dentro de la sala, en bucle | Bucle de 4–8 s sin corte | Zumbido bajo y estable, eléctrico pero no industrial; inquietante, muy por debajo del resto |
| `counter_lock` | Un anillo encaja | 0,4–0,8 s | Encaje mecánico preciso, con una resonancia breve |
| `counter_found` | Al abrir la sala | 1,5–3 s | Aire que entra en un espacio cerrado; reverberación larga |

## Prioridad 3: equipo y descubrimientos

| Clave (nueva salvo indicación) | Cuándo suena | Duración | Carácter |
|---|---|---|---|
| `lamp_on` / `lamp_off` | Encender o apagar la linterna (L) | 0,1–0,2 s | Clic de interruptor robusto |
| `detector_pulse` | Pulso del detector (G) | 0,6–1 s | Ping de sónar grave que se apaga; distinto de los descubrimientos |
| `hook_throw` | Lanzar el gancho (T) | 0,3–0,5 s | Cable que sale silbando |
| `hook_attach` | El gancho engancha | 0,2–0,3 s | Golpe metálico seco contra roca |
| `discover_rare` (existe) | Hallazgo raro | 0,6–1 s | Campanilla breve y cálida |
| `discover_epic` (existe) | Hallazgo épico | 1–1,5 s | Acorde corto que asciende |
| `discover_legendary` (existe) | Hallazgo legendario | 1,5–2,5 s | Acorde amplio con brillo; el momento más especial |
| `geode_open` (existe) | Abrir una geoda | 0,8–1,2 s | Cáscara que se abre y cristales que tintinean |
| `fossil_extract` (existe) | Extraer un fósil | 0,8–1,2 s | Piedra que se separa con cuidado y polvo |
| `cave_open` (existe) | Abrir una cueva | 1–2 s | Corriente de aire que entra; eco |
| `zone` (existe) | Entrar en una capa nueva | 1–2 s | Nota grave ambiental, distinta por capa si es posible |

Las claves nuevas (`lamp_on`, `lamp_off`, `detector_pulse`, `hook_throw`, `hook_attach`) se
añadirán a `Config/Sounds` cuando haya audio para ellas; hoy el equipo usa `ui_click` y `too_hard`.

## Interfaz (prioridad baja)

`ui_click`, `error`, `pickup`, `sell` y `purchase`: clics y campanillas cortas (0,1–0,4 s) con la
misma familia de timbre.
