# Paquete de marketing · The Hole Never Ends

Producido el 8-nov-2026 a partir del manual `docs/marketing/` y del juego real (Roblox Studio).
El inventario completo, con las dimensiones reales de cada archivo, está en **[INVENTARIO.md](INVENTARIO.md)**.

> **Nada se ha publicado ni subido.** No he cambiado el juego, su nombre, sus imágenes ni ninguna campaña.

**¿Qué subo a Roblox?** → **[SUBIR_A_ROBLOX.md](SUBIR_A_ROBLOX.md)**. Los archivos exactos, numerados, están en
`12_FINAL_EXPORTS/SUBIR_A_ROBLOX/`.

## Versiones en inglés
Todo tiene copia en inglés, en una subcarpeta **`EN/`** junto a la española (archivos acabados en `_en`):
logo (`*_en`), miniaturas (`03_ROBLOX_THUMBNAILS/EN`), anuncios (`08_ROBLOX_ADS/EN`), Instagram completo
(`05_INSTAGRAM/EN`: post, carrusel, Stories, comunidad, plantillas, portadas), TikTok (`06_TIKTOK/EN`),
YouTube (`07_YOUTUBE/EN`), banners de lanzamiento y actualización (`_en`), tráiler 16:9 y 9:16
(`THNE_trailer_oficial_en_*`) y los 15 vídeos cortos (`12_FINAL_EXPORTS/shorts_9x16/EN`).
Los textos ingleses están en `11_EDITABLE_PROJECTS/scripts/i18n.py`. Para regenerar en inglés: `THNE_LANG=en python make_….py`.
**Ojo:** la interfaz que se ve en las capturas es la del juego, y está en español en ambas versiones.

## 1. Cómo se ha hecho (y qué es real)

| Pieza | Método | ¿Es gameplay real? |
|---|---|---|
| Capturas y vídeos de juego | Sesión de *Play* en Studio. Escenas preparadas por código **solo durante la sesión** (no se guardó nada): pozo abierto hasta 2.195 m, herramientas y equipo dados, cámara colocada por script. Grabado con la API de Windows `PrintWindow` | **Sí**: es el motor de Roblox renderizando el juego. Los planos de cámara y de acción se grabaron **4–5 veces más lentos** (cámara, animación y partículas) y se aceleraron después para que vayan fluidos |
| Logo, símbolo e iconos | Escenas 3D procedurales en **Blender 5.2** (Cycles) + acabado en Python/Pillow | No: son ilustraciones 3D **del juego** (zonas, herramientas, minerales y avatar de bloques reales del juego) |
| Miniaturas, anuncios y redes | Composición en Python/Pillow sobre capturas reales, con retoque ligero (+10 % de color y contraste) | Sí (salvo `02_descubrimientos_B`, que usa el arte 3D) |
| Música y efectos | **Sintetizados desde cero** con `scripts/synth.py` (sin muestras ni música de terceros) | — |

El personaje de las capturas es **tu avatar** (`sadicoymafioso`), el que se usó en las pruebas.

## 2. Qué hay (todo terminado salvo lo marcado)

| Carpeta | Contenido | Formato |
|---|---|---|
| `01_BRANDING/` | Logo principal ES/EN, horizontal ES/EN, compacto, símbolo; versiones para fondo claro y oscuro (PNG transparente); `THNE_logos_presentacion.jpg`; `THNE_paleta.png`; **`GUIA_VISUAL.md`** | PNG hasta 3.800 px |
| `02_ROBLOX_ICONS/` | **5 iconos** (A corte · B pico contra cristal · C mirar el pozo · D profundidades · E hallazgo legendario) a 1024 y 512 px + prueba de tamaños (256/150/50 px) | PNG cuadrado |
| `03_ROBLOX_THUMBNAILS/` | **9 conceptos** de miniatura × ES / EN / sin texto = 25 archivos | JPG 1920×1080, < 0,5 MB |
| `04_BANNERS/` | Banner principal 1920×600, YouTube 2560×1440, cabecera X 1500×500, lanzamiento ES/EN, plantilla «próxima actualización» ES/EN | JPG |
| `05_INSTAGRAM/` | Post de presentación, **carrusel de 6**, **7 Stories**, 3 posts de comunidad, 3 plantillas, **15 portadas de Reels** | 1080×1350 / 1080×1920 / 1080×1080 |
| `06_TIKTOK/portadas/` | Las 15 portadas (mismas que Reels) | 1080×1920 |
| `07_YOUTUBE/` | 4 miniaturas (tráiler, Cavé 1.000 m, Las 7 capas, devlog) | JPG 1280×720 |
| `08_ROBLOX_ADS/` | **10 creatividades** (5 conceptos × 2 variantes) + `HIPOTESIS.md` | JPG 1920×1080 |
| `09_OFFICIAL_TRAILER/` | Tráiler ES 16:9, EN 16:9, ES 9:16 (34 s) + **vídeo de juego para la página de Roblox** (34 s, sin texto) | MP4 H.264 + AAC, 30 fps |
| `10_RAW_GAMEPLAY/` | Capturas en bruto (2512×1326) y 11 clips como secuencias de fotogramas | **Solo en tu PC** (1,3 GB, no va a git) |
| `11_EDITABLE_PROJECTS/` | Scripts de Blender y su `.blend`, scripts de composición y montaje, música y efectos WAV | Ver §6 |
| `12_FINAL_EXPORTS/` | **15 vídeos cortos** 9:16 (8–15 s) y copias de lo recomendado | MP4 1080×1920 |

### Los 15 vídeos cortos (Reels / TikTok / Shorts: el mismo archivo sirve para los tres)
| # | Gancho | Tipo |
|---|---|---|
| 01 | Cavé 1.000 m en mi jardín | Descubrimiento / escala |
| 02 | ¿Qué hay debajo de tu casa? | Curiosidad |
| 03 | Herramienta 1 vs herramienta 10 | Progresión |
| 04 | El mineral más raro del juego | Descubrimiento |
| 05 | Picar cristal a cámara lenta | Satisfactorio |
| 06 | POV: heredas una casa con jardín… | Historia / POV |
| 07 | Las 7 capas del agujero (la 7.ª, «???») | Curiosidad |
| 08 | Todo lo que cavas se vende | Bucle de juego |
| 09 | No mires abajo. | Curiosidad / miedo suave |
| 10 | Alguien cavó aquí antes que yo · ¿Quién era «E.»? | Misterio |
| 11 | Reto: ¿a qué profundidad estoy? | Reto (pide comentarios) |
| 12 | Llevo meses haciendo este juego | Presentación / devlog (tu cuenta) |
| 13 | A 1.000 metros todo brilla | Ambiente |
| 14 | Cuando la mochila se llena a 16 m… | Humor (pasa de verdad en el juego) |
| 15 | Muy pronto en Roblox | Teaser |

## 3. Qué usar primero
1. **Icono: C «mirar el pozo»**. Es el más legible a 50 px y coincide con el símbolo de la marca.
   Alternativas: **A «corte»** y **B «pico contra cristal»**. No he medido el CTR de ninguno; esto es criterio de diseño.
2. **Miniaturas activas en la personalización** (de 2 a 5): `01_hasta_donde`, `04_tu_casa_tu_agujero`, `07_cuevas_de_cristal`,
   `02_hallazgo_legendario`. Las demás, en la galería.
3. **Vídeo de la pestaña Videos de Roblox:** `THNE_video_pagina_roblox_gameplay_1920x1080.mp4` (revisa el §5).
4. **Instagram (semana de lanzamiento):** post de presentación + carrusel, Reels 06, 01 y 12; Stories en el orden del capítulo 12 del manual.
5. **Roblox Ads:** sube las 10 imágenes a una campaña: cada concepto tiene variante A y B.

## 4. Pruebas que recomiendo (sin dar por hecho el resultado)
- **Iconos** (Roblox no hace A/B de iconos): encuesta de Stories A/B (`story 03_icono_a_o_b` usa A frente a C) y anuncios `02_descubrimientos_A` (captura) frente a `B` (arte 3D).
- **Miniaturas:** la personalización de Roblox reparte de 2 a 5. Compara con texto y sin texto (`ES` frente a `SIN_TEXTO`).
- **Anuncios:** A frente a B en cada concepto. Mira las partidas por clic tras 48 h, no solo los clics.
- **Vídeos cortos:** publica los 15 en 4–5 semanas. Compara la retención a 3 s y los guardados. Haz más de los 2 mejores ganchos.

## 5. Revisar antes de publicar (no lo he podido comprobar)
- **Música y efectos:** están sintetizados y comprobados técnicamente (picos −1 dB, sin saturar), pero **no puedo escucharlos**.
  Escúchalos. En TikTok y Reels quizá prefieras un audio en tendencia de la biblioteca de la plataforma.
- **Vídeo de la página de Roblox:** es gameplay real con la interfaz, sin texto ni voz. Pero algunos planos usan cámara
  colocada por script y movimiento ralentizado. Si Roblox los considera «cinemáticas», graba uno jugando normal
  (Play → grabación de pantalla) y sustitúyelo.
- **Fluidez:** los clips con interfaz (venta, herramienta nueva, legendario) se grabaron en tiempo real a unos 9 fps y se suavizaron
  mezclando fotogramas. Se nota algo menos fluido que el resto.
- **Escenas preparadas:** las herramientas, el equipo y los minerales que se venden se dieron por código en la sesión de prueba
  (la venta da 7.190 monedas porque se añadieron minerales). En los textos no prometo cantidades.
- **Legibilidad en móvil:** comprobada en la prueba de tamaños de iconos. Las miniaturas y Stories solo se han revisado reducidas en pantalla.
- **Especificaciones de Roblox Ads:** son las documentadas en el manual (16:9, 10 imágenes) a fecha de nov-2026. Confírmalas al subir.

## 6. Lo que no he podido producir
- **Miniatura y vídeo multijugador:** el MCP de Studio solo arranca sesiones de un jugador.
  Hazlo con amigos en un servidor privado o en *Test → Clients* con 2–3 jugadores.
- **Voz en off:** no tengo generador de voz. Los vídeos funcionan sin voz.
- **Escena del Núcleo (2.200 m):** la grabé, pero no la uso porque desvela el final (el manual recomienda no enseñarlo).
- **Cuevas de las Cavernas Antiguas y Profundidades Volcánicas en primer plano:** solo aparecen de paso en la bajada.
  Si quieres miniaturas propias, hay que buscar una cueva vistosa en esas zonas.
- **Calidad de los iconos:** son buenos renders 3D, limpios y legibles, pero **no alcanzan el nivel de ilustración de los juegos
  top** (Pet Simulator, Grow a Garden), que usan avatares y poses hechos a mano. Si el presupuesto lo permite, un ilustrador
  puede partir del icono C y de los `.blend` como referencia.

## 7. Cómo regenerar o editar
Todo se reconstruye desde `11_EDITABLE_PROJECTS/` (Python 3 con Pillow, numpy e imageio-ffmpeg; Blender 5.2):
- `blender/render_logos.sh` y `blender/render_icons.sh <variantes>`, y luego `scripts/make_logos.py` y `make_icons.py`.
- `scripts/make_thumbnails.py`, `make_ads.py`, `make_social.py` (cambia los textos dentro).
- `scripts/make_trailer.py es|en land|vert`, `make_shorts.py [ids]` y `make_roblox_video.py`.
- `scripts/synth.py audio/` regenera la música. `scripts/make_final.py` rehace la paleta, las copias finales y el inventario.
- Grabar más material: `scripts/rec.py` y `snap.py` capturan el visor de Studio aunque la ventana esté detrás de otras.

## 8. Dónde subir cada cosa
| Recurso | Dónde |
|---|---|
| Icono | Creator Hub → tu experiencia → Configure → **Icon** (sube el de 1024 px y revisa el recorte) |
| Miniaturas | Creator Hub → **Thumbnails** (hasta 10; activa 2–5 en la personalización) |
| Vídeo de juego | Creator Hub → Place settings → **Videos** (3 subidas al mes) |
| Anuncios | **Ads Manager** → campaña → Creatividades (16:9) |
| Reels, Stories, posts | Instagram (portada: `05_INSTAGRAM/portadas_reels`) |
| TikTok y YouTube Shorts | Los mismos MP4 de `12_FINAL_EXPORTS/shorts_9x16` (portadas en `06_TIKTOK/portadas`, miniaturas en `07_YOUTUBE`) |
| Banners | YouTube (2560×1440), X (1500×500), web o prensa (1920×600) |

**Notas de uso de las Stories** (añade los stickers en la app): 01 encuesta «¿Juegas a Roblox?» · 02 deslizador de emoji ·
03 encuesta A/B · 04 enlace `ig_beta` · 05 cuenta atrás · 06 enlace `ig_stories` · 07 caja de preguntas.
Recuerda usar los códigos LaunchData del manual (`ig_reels`, `tiktok`…) en los enlaces para medir de dónde viene cada jugador.

## Reels de pantalla partida (arriba tu clip, abajo gameplay)

- **Clips de gameplay editados** (20–30 s, 1080×960, con música y efectos): `12_FINAL_EXPORTS/gameplay_clips_split/THNE_gp_01…10`.
  Del 07 al 10 salen del gameplay grabado el 10/11/2026: perforadora abisal, cartel de cada zona y hallazgos épicos y legendarios.
  Se grabó en Studio con un perfil desechable (atributo `StudioNoSave` en ServerStorage), sin tocar tu partida guardada.
  El arranque y el resto de los recursos se generan con `make_gameplay_clips.py`.
- **Plantilla:** `11_EDITABLE_PROJECTS/scripts/make_split.py`. Monta arriba el clip que elijas (con su sonido) y abajo el gameplay:
  - `python make_split.py MI_CLIP.mp4 --bottom auto-gp --text "TEXTO DEL GANCHO"`
  - `python make_split.py CARPETA/ --bottom auto-gp` hace un reel por cada vídeo de la carpeta, con un clip de gameplay distinto en cada uno.
  - Sin `--bottom`, abajo hace cortes automáticos. Salida: `12_FINAL_EXPORTS/reels_split/`.
- El clip de arriba lo eliges tú y eres responsable de tener derecho a usarlo (los clips de series o programas de TV pueden recibir reclamaciones).
