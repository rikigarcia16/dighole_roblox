# Informe de lanzamiento — THE HOLE NEVER ENDS

**Clasificación: NEEDS FINAL TESTING.** Las fases están implementadas y lo comprobable desde aquí se
ha comprobado en Roblox Studio con un jugador. Faltan tres verificaciones que necesitan acción
externa: guardado real (sitio publicado), varios jugadores a la vez y dispositivos táctiles.

## 1. Cambios implementados (bloques recientes)

- **Exterior (fase 1):** casa de cuento (entramado, tejado de tejas, buhardilla, chimenea con humo,
  veleta, ventanas iluminadas con contraventanas y jardineras, porche), jardín con valla, buzón y
  parterres; árboles redondos, cerezos, pinos, arbustos, rocas con musgo, mariposas; caminos de
  grava con bordillos sobre tierra, plaza de aparición, arco «EL AGUJERO», tienda de excavación con
  toldo, engranaje y herramientas expuestas, mercado de minerales, castillete del montacargas,
  colinas y nubes. El suelo queda a ras de lo construido (antes enterraba 2 studs de todo).
- **Subsuelo (fase 2):** estaciones del montacargas industriales; elementos propios en cada capa
  (bombillas y cajas en las Minas, racimos de cristal, braseros e ídolos, pozas de lava, setas
  luminosas, pilares de luz), de 7 a 10 elementos por sector.
- **Interacciones (fase 3):** minerales que saltan de la roca y vuelan al jugador; hallazgos raros
  que suben en un haz de luz con su nombre; la venta lanza la carga al carro y hace saltar monedas;
  presentación 3D de cada herramienta nueva; contador de monedas animado; momento de zona nueva;
  sonidos con licencia por material; música por zona con botón para silenciarla.
- **Jugabilidad:** cavar hacia abajo con E ya no se atasca (cornisas, vetas demasiado duras, paredes
  redondeadas de los pozos); cámara detrás del personaje al aparecer y cenital en pozos estrechos;
  la batería no se vende hasta tener equipo que la use; final del juego («El fondo», herramienta
  ancestral y roca madre que devuelve al jardín); hazañas opcionales; pizarras de E.
- **Pulido (fase 4):** calidad «Bajo» apaga las luces decorativas; Baseplate de plantilla quitada
  del sitio (**guarda el sitio en Studio** para conservarlo); textos y escalas revisados en las
  capturas.

## 2. Mejoras visuales

Capturas de antes y después tomadas en Studio durante el trabajo (vista general, casa de frente y de
lado, tienda por fuera y por dentro, mercado, montacargas, Minas, Cristal, Abismo, estación). Están en
la carpeta local de la sesión de Claude Code, no en el repositorio.

## 3. Pruebas realizadas

| Qué | Cómo | Resultado |
|---|---|---|
| Tests automáticos | Lune: 76 tests, 62 usos de remotos, compilación de todos los scripts | Todo en verde |
| Guardado (lógica) | Tests con DataStore simulado y varios servidores: bloqueo de sesión, reintentos, caída del DataStore, servidor caído | Pasan |
| Primeros minutos | Studio, jugando con ratón y E | Cavar, primera venta (+misión), compra de pala reforzada con presentación 3D, bajada a las Minas |
| Botín y venta | Studio, jugando | 5 piezas volando por 5 minerales (0 por tierra); monedas saltando del carro |
| Bajada continua | Studio, E mantenida | 135 m en 100 s sin atascos (antes se paraba a 2, 71 y 89 m) |
| Estaciones y montacargas | Studio | Instalar con H a 72 m; el panel abre el menú de viaje |
| Contenido avanzado | Studio con atajos (generar terreno, mover al personaje) | Zonas profundas con sus elementos; final completo (grabado, herramienta, roca madre → jardín) |
| Rendimiento | Studio | Cliente a 60 fps con ~5 800 piezas en streaming; servidor ~10 400 piezas y 203 luces, latido a 60/s |
| Multijugador (lógica) | Revisión del código nuevo | Efectos, botín, venta, hazañas, fondo y trofeos van por jugador o por parcela propia; nada compartido sin dueño |
| Seguridad | Revisión de código | Todos los remotos con límite de frecuencia y validación de tipos; el servidor decide monedas, compras, excavación y recompensas |
| Depuración | Búsqueda en el código | Solo un probador de sonido limitado a Studio (F7); ningún atajo en el repositorio |

Los atajos de prueba (dar monedas, mochila grande, teletransportes) se usaron solo dentro de sesiones
de Play y nunca se guardaron en el proyecto.

## 4. Estado de las fases

| Fase | Estado | Evidencia |
|---|---|---|
| 1 Exterior | Completada | Capturas de antes y después; interacciones probadas |
| 2 Subsuelo | Completada | Capturas de Minas, Cristal y Abismo; estación instalada jugando |
| 3 Interacciones | Completada | Botín, venta y presentación de herramienta vistos jugando |
| 4 Pulido | Parcial | Rendimiento medido en PC; faltan móvil, multijugador y guardado real |

## 5. Problemas restantes

| Gravedad | Problema |
|---|---|
| Alta (bloquea lanzamiento) | Guardado real sin probar: necesita el sitio publicado con acceso a API |
| Alta (bloquea lanzamiento) | Multijugador sin probar con clientes reales (la lógica está pensada y probada por separado) |
| Media | Controles táctiles y escala en móvil/tableta sin probar en dispositivo ni emulador. Revisado en el código: la interfaz escala con la pantalla (mínimo 0,62), cada tecla tiene botón táctil y los textos ya no piden teclas en pantallas táctiles |
| Media | Sonidos y música de biblioteca: escúchalos; cámbialos en `Config/Sounds` y `Config/Music` |
| Baja | Hierba del terreno alta; solo se ajusta en Studio (Terrain → `Decoration`) |
| Baja | La etiqueta del nombre de un hallazgo raro no se ve en las capturas de la herramienta (sí existe); confírmala jugando |
| Baja | Aviso de Studio «rbxassetid://203785492 … Asset type does not match»: no está en el proyecto ni en el sitio (interno de Studio) |

## 6. Pasos exactos para publicar

1. En Studio: **Archivo → Guardar** (conserva la eliminación de la Baseplate).
2. **Archivo → Publicar en Roblox como…**, experiencia **privada**.
3. **Configuración del juego → Seguridad → Habilitar el acceso de Studio a los servicios de API.**
4. Seguir `docs/TEST_SAVES_TWO_PLAYERS.md`: guardado (salir y volver) y dos jugadores
   (Probar → Clientes y servidores → 2).
5. Probar en el emulador de dispositivos de Studio (teléfono y tableta) y, si puedes, en un móvil real.
6. Rellenar el cuestionario de madurez de contenido en el panel de creador.
7. Con todo lo anterior bien, pasar la experiencia a pública. No hay monetización activada.
