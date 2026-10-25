# Prueba: guardado real y dos jugadores

Lo único del juego que todavía no se ha visto funcionar de verdad. Necesita un sitio **publicado**
(los DataStores no existen en un archivo local) y dos clientes a la vez.

## 0. Preparar (una vez, lo haces tú)

1. En Studio, con `digthehole.rbxl` abierto: **Archivo → Publicar en Roblox como…** Crea una
   experiencia nueva y privada; no hace falta que sea pública.
2. **Inicio → Configuración del juego → Seguridad → «Habilitar el acceso de Studio a los servicios
   de API»** → Guardar. Sin esto, Studio sigue sin DataStore.
3. Borra la pieza `Baseplate` de la plantilla (el servidor ya la quita al arrancar, pero estorba al
   editar).
4. Vuelve a conectar Rojo para que el sitio publicado tenga el código actual.

Al pulsar Play no debe aparecer «El guardado no está disponible en esta sesión».

## 1. Guardado real (un jugador, Play normal)

| # | Paso | Qué debe pasar |
|---|---|---|
| G1 | Cava unos 30 bloques, vende y compra la pala reforzada. Para Play. | — |
| G2 | Play otra vez. | Mismas monedas, misma pala equipada, el agujero tal y como lo dejaste, el récord en el cartel. |
| G3 | Abre el diario y la casa. | Las entradas y el mapa de capas siguen igual. |
| G4 | Ajustes (⚙): efectos bajos y sin sacudida. Para y vuelve. | Se conservan. |
| G5 | Consigue una hazaña (por ejemplo, tres geodas) y vuelve a entrar. | Sigue concedida y su ventaja funciona. |

Para lo profundo (taller, fondo) no hace falta bajar de verdad: en la barra de comandos de Studio,
durante Play, puedo dejar el perfil en el estado que haga falta. Avísame y lo preparo.

## 2. Dos jugadores (Probar → Clientes y servidores → 2 jugadores → Iniciar)

| # | Paso | Qué debe pasar |
|---|---|---|
| D1 | Arrancan los dos. | Cada uno en su parcela, con su casa, su cartel y su agujero; ninguno ve la cámara al revés. |
| D2 | El jugador 1 cava. El 2 mira desde el borde. | El 2 ve caer los bloques, el polvo y oye los golpes. |
| D3 | El 2 intenta cavar en la parcela del 1. | «Esta parcela no es tuya…» y no pasa nada. |
| D4 | El 1 se va (cierra su ventana). | Su parcela se libera y el 2 no nota tirones. |
| D5 | El 1 vuelve a entrar. | Recupera su progreso y su agujero (puede caer en otra parcela). |
| D6 | Los dos cavan a la vez durante 1 minuto. | Sin tirones; anota los ms del MicroProfiler (Ctrl+F6) si los hay. |

## 3. Qué me pasas

- Las filas que fallen, con lo que viste.
- Las líneas rojas o amarillas de la Salida (Output).
- Si quieres, déjame hacerlo a mí: con el sitio publicado y Rojo conectado puedo correr la parte 1
  y preparar estados; la parte 2 necesita que pulses tú «Iniciar» con 2 jugadores.
