# Ultimate Custom Night — documentación técnica de IA, estados, interacciones y secretos

> **Objetivo:** servir como guía de reverse engineering para entender el `Frame 2` del MFA original de *Ultimate Custom Night* y facilitar una futura reimplementación en Haxe/OpenFL/HaxeFlixel.
>
> **Importante:** gran parte de las fórmulas de esta guía provienen de ingeniería inversa comunitaria del juego de Clickteam Fusion. Cuando hay discrepancias entre fuentes, se indica. Para un port 1:1, el MFA que estás inspeccionando debe considerarse la referencia final.

---

## 0. Resumen rápido del diseño de UCN

UCN no parece usar un único “AI Director” al estilo *Left 4 Dead*. La noche principal es más bien una colección de **muchas máquinas de estados pequeñas** que comparten sistemas globales:

- monitor/cámaras;
- puertas y ventilaciones;
- máscara;
- linterna;
- temperatura;
- ruido;
- energía;
- ventilation meter;
- Faz-Coins;
- Global Music Box;
- Audio Lure;
- Heater / Power A/C / Silent Ventilation / Power Generator;
- timers globales y reloj de la noche.

Cada animatrónico suele tener:

```text
AI level
+ timer / interval
+ RNG check
+ progress/state
+ attack-ready flag
+ countermeasure
+ kill/distraction resolution
```

Eso explica por qué el `Frame 2` puede tener más de **1300 eventos**: Clickteam representa explícitamente combinaciones que en Haxe serían funciones, arrays y enums.

---

# 1. Convenciones técnicas

## 1.1. Reloj

La noche dura aproximadamente:

```text
12 AM -> 6 AM = 4 min 30 s
1 hora ingame = 45 s reales
```

Momentos principales:

| Hora | Tiempo real |
|---|---:|
| 1 AM | 0:45 |
| 2 AM | 1:30 |
| 3 AM | 2:15 |
| 4 AM | 3:00 |
| 5 AM | 3:45 |
| 6 AM | 4:30 |

Muchas fórmulas comunitarias están expresadas en **frames a 60 FPS**:

```text
60 frames ~= 1 segundo
300 frames ~= 5 segundos
600 frames ~= 10 segundos
```

Para recrearlo fielmente en Haxe conviene tener un **fixed gameplay tick de 1/60 s**.

---

## 1.2. AI level

Normalmente:

```text
0 = desactivado
1..20 = dificultad seleccionable
```

Hay personajes donde la IA sí altera probabilidad/velocidad y otros donde funciona casi como un simple `enabled`.

La documentación de reverse engineering suele usar expresiones como:

```text
Random(0..29) < AI
```

A AI 20 equivale aproximadamente a `20/30`.

> En Clickteam `Random(n)` suele devolver `0...(n-1)`. Algunos documentos comunitarios escriben rangos inclusivos por comodidad, por lo que al portar hay que mirar el evento real antes de copiar literalmente la sintaxis.

---

## 1.3. Modelo recomendado para Haxe

No traduzcas:

```text
Alterable Value A
Alterable Value B
Alterable Value C
```

a:

```haxe
valueA;
valueB;
valueC;
```

si ya sabes su función.

Mejor:

```haxe
class AnimatronicRuntime {
    public var ai:Int = 0;
    public var state:AnimState = Idle;
    public var progress:Int = 0;
    public var timerFrames:Int = 0;
    public var enabled:Bool = false;
    public var attackReady:Bool = false;
}
```

Para mantener la precisión de Clickteam:

```haxe
var tickAccumulator:Float = 0;

function update(elapsed:Float) {
    tickAccumulator += elapsed;

    while (tickAccumulator >= 1 / 60) {
        fixedTick();
        tickAccumulator -= 1 / 60;
    }
}
```

---

# 2. Sistemas globales que afectan a varios animatrónicos

## 2.1. Temperatura

Rango habitual:

```text
inicio = 60°F
máximo = 120°F
```

Comportamiento aproximado documentado:

| Sistema | Efecto |
|---|---|
| Nada enfriando | +1°F/s |
| Silent Ventilation | temperatura sube más lento |
| Heater | aumenta rápidamente |
| Fan | enfría |
| Power A/C | enfría mucho más rápido |

Valores de reverse engineering reportados:

```text
natural: +1 cada 1.0 s
Silent Ventilation: +1 cada 2.0 s
Heater: +1 extra cada 0.25 s
Fan: -1 cada 0.5 s
Fan + Silent Ventilation: -1 cada 0.4 s
Power A/C: -1 cada 0.25 s
```

### Animatrónicos relacionados

- **Freddy**: el calor aumenta su progreso.
- **Jack-O-Chica**: solo se vuelve realmente peligrosa con temperatura alta.
- **Phantom Freddy**: a 120°F su actualización acelera brutalmente.
- **Lefty**: el calor aumenta su irritación.
- **Rockstar Freddy**: el Heater puede hacerle creer que recibió el pago.
- **Nightmare Chica**: Power A/C es su counter directo.
- **Mr. Hippo / Pigpatch / Nedd Bear / Orville**: Heater puede empujarlos en ductos.
- **Happy Frog**: inmune al Heater.

---

## 2.2. Ruido

El medidor llega aproximadamente hasta 6 barras.

Fuentes documentadas de ruido:

```text
Fan                  +1
Power Generator      +2
Heater               +1
Power A/C             +1
Silent Ventilation    0
Global Music Box      0

Phantom Mangle        +1 mientras molesta
Mangle                +1 al estar dentro
Phone Guy             +1 durante llamada
Lolbit                +3
```

### Helpy es especial

La investigación de código comunitaria indica que su airhorn:

```text
NO necesita modificar el medidor global
-> suma directamente +2500 a la irritación de Music Man
```

Por eso su descripción de “hacer reaccionar a animatrónicos sensibles al ruido” es más amplia de lo que realmente parece hacer el código.

### A quién importa el ruido

Principalmente:

- **Music Man**
- **Lefty**

Además el ruido puede tapar señales de audio importantes aunque no cambie variables de otros enemigos.

---

## 2.3. Ventilation meter

Modelo documentado:

```text
ventilation = 500
```

Pierde aproximadamente:

```text
<120°F:  -1 cada 100 ms
120°F:   -2 cada 100 ms
Puppet fuera de la caja: -1 por frame
power outage:            -1 por frame
```

Al agotarse puede forzar el monitor y crear ventanas peligrosas para enemigos que dependen de cámara/monitor.

---

## 2.4. Energía

La comunidad encontró un contador interno cercano a:

```text
powerInternal = 10100
display = powerInternal / 100
```

y un drenaje periódico relacionado con:

```text
[(usage + 1) - generator]^2
```

Cada puerta, utilidad y dispositivo aumenta `usage`.

Esto no debe copiarse a ciegas hasta comprobar el MFA, pero explica por qué el **Power Generator** reduce consumo a cambio de mucho ruido.

---

## 2.5. Global Music Box

Interacciones importantes:

- **Marionette**: rellena lentamente la Music Box.
- **Chica**: fuerza a fallar su check de enfado.
- **Lefty**: detiene y reduce su irritación.
- No genera ruido.

Es uno de los sistemas con mayor cantidad de interacciones cruzadas.

---

## 2.6. Camera stalling

Animatrónicos documentados como “stallables”:

| Personaje | Cámara/condición |
|---|---|
| Nightmare Bonnie | mantener CAM 02 seleccionada |
| Nightmare Mangle | CAM 02 |
| Circus Baby | CAM 02 |
| Rockstar Chica | CAM 01 o CAM 02 según el wet-floor sign |
| Lefty | CAM 03 |
| Toy Freddy | monitor arriba en cada múltiplo de 10 s |
| Funtime Foxy | CAM 06 tiene una interacción especial con Showtime |
| Plushtrap | CAM 06 puede retrasar/neutralizar su ventana |

Esto importa muchísimo al portar: no son simples “bugs”; varios forman parte de estrategias avanzadas de 50/20.

---

# 3. Los 50 personajes seleccionables

---

## 3.1. Freddy Fazbear

**Tipo:** lethal / pasillo izquierdo.

### Estado útil

```text
ai
progress
stage
temperature
readyToAttack
```

### Lógica documentada

Cada segundo añade a su progreso aproximadamente:

```text
Random(AI) + floor((temperature - 60) / 5)
```

Cada ~100 puntos avanza una fase.

Valores relevantes:

```text
400 -> preparado para atacar
500+ -> puede matar si monitor está arriba y puerta izquierda abierta
```

### Interacciones

- El calor acelera a Freddy.
- La puerta izquierda es el counter.
- JJ puede ser especialmente peligrosa si está anulando controles de puerta.
- El consumo de puerta conecta su defensa con el sistema de energía.

---

## 3.2. Bonnie

**Tipo:** Pirate Cove / camera disruptor, no lethal directo.

Comparte Pirate Cove con Foxy.

### Estado útil

```text
activeInCove
figurine
cameraJamFrames
```

Cada ~2 segundos existe una posibilidad de cambiar quién está activo entre Bonnie/Foxy. El cambio visual se refleja mediante la figurita del escritorio.

Si Bonnie está activo y miras CAM 05:

```text
-> jumpscare visual/audio
-> cámaras inutilizadas temporalmente
```

La duración reportada por fuentes técnicas difiere:

```text
~250 + AI*20 frames
o
~300 + AI*20 frames
```

**Verificar este valor directamente en el MFA.**

### Interacciones

El bloqueo de cámaras puede impedir:

- vigilar a Foxy;
- comprar plushies;
- atender Toy Freddy;
- encontrar guitarra de Rockstar Bonnie;
- controlar Funtime Foxy;
- acceder cómodamente a otros sistemas.

---

## 3.3. Chica

**Tipo:** Kitchen / music state.

### Estado útil

```text
ai
unhappyCheck
consecutiveFailures
angry
musicState
```

Cada 15 s hace aproximadamente:

```text
Random(0..39) < AI
```

Si Global Music Box está activa, el check falla automáticamente.

Dos checks exitosos consecutivos pueden llevarla al estado de ataque.

Una vez enfadada, con el monitor arriba existe una probabilidad repetida de muerte.

### Counter

Cambiar la música de cocina cuando corresponde o usar **Global Music Box** estratégicamente.

### Interacciones

- Global Music Box la neutraliza en sus checks.
- Comparte el sistema musical con Marionette y Lefty, por lo que una misma decisión puede solucionar tres amenazas.

---

## 3.4. Foxy

**Tipo:** Pirate Cove / progression.

### Estado útil

```text
stage
progress
speedBonus   // equivalente al Value H documentado
figurineIsFoxy
hasLeftCove
```

Mientras la figurita indica Foxy, progresa continuamente.

Umbral aproximado para intentar subir de fase:

```text
progress > 1000 - AI*10
```

Entonces tiene alrededor de `2/3` de probabilidad de avanzar.

`speedBonus` aumenta con cada etapa, hasta aproximadamente 3.

Mirar Pirate Cove mientras Foxy todavía está allí:

```text
progress = 0
speedBonus = 0
```

En su fase final, estar en cámaras puede lanzar checks de muerte.

### Interacciones

- Comparte el Cove con Bonnie.
- El scramble de cámaras de Bonnie puede impedir resetear a Foxy.
- Death Coin aplicada a Bonnie/Foxy elimina a ambos.

---

## 3.5. Toy Freddy

**Tipo:** juego interno “Five Nights with Mr. Hugs”.

### Estado útil

```text
ai
mrHugsCamera
doorState[3]
mrHugsProgress
gameOverFlag
```

Cada 10 s, Mr. Hugs puede moverse:

```text
Random(0..29) < AI
```

Si estás observando la habitación de Toy Freddy exactamente durante esos intervalos, Mr. Hugs puede quedar “stall”.

Si Mr. Hugs permanece frente a una puerta incorrectamente abierta durante:

```text
1000 - AI*5 frames
```

Toy Freddy queda marcado como derrotado.

Después del `gameOverFlag`, al abrir cámaras se realizan checks periódicos para el jumpscare.

### Interacciones

OMC, Bonnie, Ballora y otras cosas que bloquean el uso normal del monitor hacen más difícil atender su minijuego.

---

## 3.6. Toy Bonnie

**Tipo:** office intruder / Freddy Mask.

Spawn aproximado cada 15 s:

```text
Random(0..59) < AI
```

Al aparecer, un valor interno inicia aleatoriamente en `0..99`.

Con la máscara puesta:

```text
+1 por frame
+2 por frame si además lo estás mirando
```

Al superar ~200 se retira.

Si permanece demasiado:

```text
~250 frames -> flicker fuerte
~300 frames -> muerte
```

---

## 3.7. Toy Chica

Mismo concepto que Toy Bonnie.

Spawn aproximado cada 14 s:

```text
Random(0..59) < AI
```

Con máscara:

```text
+1 por frame
+3 por frame si la estás mirando
```

Sale al superar ~200.

Ventana de muerte semejante:

```text
~250 flicker
~300 lethal
```

---

## 3.8. Mangle

**Tipo:** vent system + noise.

### Movimiento

Velocidad inicial aproximada:

```text
3
```

Cada 6 s:

```text
speed = Random(floor(AI/2)) + 1
```

Al girar una esquina vuelve a velocidad 1.

Puede elegir diferentes rutas.

### Vent Snare

Si permanece superpuesta al snare ~0.5 s:

```text
-> vuelve al inicio
```

### Llegada

Si alcanza la abertura mientras monitor está arriba:

```text
-> entra a la oficina
```

Luego puede producir jumpscare y añade ruido.

### Interacciones

- Añade presión sobre Music Man/Lefty mediante ruido.
- Phantom Freddy puede volver especialmente peligroso tener enemigos esperando en las ventilaciones.

---

## 3.9. Balloon Boy (BB)

**Tipo:** side vent / disable flashlight.

Al levantar cámara:

```text
Random(1..30) < AI
```

puede activarlo.

Tiempo de reacción aproximado:

```text
300 - AI*5 frames
```

Counter: cerrar side vent hasta escuchar el golpe.

Si entra:

```text
flashlight disabled ~= 600 frames
```

### Interacciones fuertes

Sin linterna se complican:

- Phantom Freddy;
- Freddles / Nightmare Freddy;
- Nightmare BB cuando corresponda.

---

## 3.10. JJ

Igual base que BB.

Si entra:

```text
door controls disabled ~= 500 frames
```

Esto la convierte en una amenaza indirecta enorme cuando coinciden enemigos de puertas.

BB ocupando el vent puede impedir que JJ ocupe el mismo lugar.

---

## 3.11. Withered Chica

**Tipo:** vent system.

Velocidad inicial aproximada:

```text
6
```

Cada 6 s:

```text
speed = Random(floor(AI/2)) + 1
```

Toma la ruta larga.

Vent Snare puede devolverla al inicio.

Al llegar a la abertura con cámara arriba:

```text
-> queda atascada
```

Mientras está allí, existe un check periódico de muerte.

### Interacción MUY importante

Withered Chica atascada puede **bloquear físicamente la abertura**, impidiendo determinadas resoluciones de:

- Springtrap;
- Ennard;
- Molten Freddy.

Esta interacción debe existir explícitamente en un port.

---

## 3.12. Withered Bonnie

**Tipo:** office intruder / mask.

Cada ~13 s, si monitor está arriba:

```text
Random(0..29) < AI
```

puede aparecer.

Con máscara completamente puesta:

```text
1/30 por frame -> irse
```

Después de ~60 frames con máscara se añade otro intento/failsafe.

Tiempo antes de muerte:

```text
250 - AI*4 frames
```

aprox.

---

## 3.13. Marionette / Puppet

**Tipo:** Music Box.

### Variables

```text
musicBox = 0..100
escaped
```

Drenaje aproximado cada 0.5 s:

```text
floor(AI / 10) + 1
```

Si das cuerda manual:

```text
+10 cada ~300 ms
```

Global Music Box:

```text
+5 cada segundo
```

Al llegar a 0:

```text
escaped = true
```

Con Puppet libre:

- ventilation se drena extremadamente rápido;
- con cámara arriba puede lanzar checks de muerte.

### AI real por bloques

Por divisiones truncadas, muchos niveles comparten el mismo drenaje:

```text
1-9
10-19
20
```

---

## 3.14. Golden Freddy

**Tipo:** office apparition / mask-monitor reaction.

Al bajar/usar monitor se evalúa aproximadamente:

```text
Random(1..40) < AI + 1
```

Tiempo de reacción:

```text
80 - AI frames
```

Counter:

```text
máscara
o
volver a levantar monitor
```

### Secreto Fredbear

Golden Freddy en **AI 1**, con configuración apropiada, permite usar Death Coin para activar el jumpscare secreto de Fredbear.

Ver sección de secretos.

---

## 3.15. Springtrap

**Tipo:** vent system.

Velocidad inicial:

```text
5
```

Cada 6 s:

```text
speed = Random(floor(AI/2)) + 1
```

Toma la ruta larga.

No lo afecta Vent Snare.

En la abertura:

```text
deadline = 400 - AI*10 frames
```

Si expira con monitor arriba y Withered Chica no está bloqueando:

```text
-> muerte
```

---

## 3.16. Phantom Mangle

**Tipo:** non-lethal disruption / noise.

Al abrir cámaras:

```text
Random(0..59) < AI
```

puede aparecer.

Si la observas ~51 frames:

```text
-> entra
-> baja/afecta monitor
-> +1 noise
```

Duración de molestia:

```text
400 + AI*10 frames
```

Puedes hacerla desaparecer cambiando/clicando sistema de Camera/Vent/Duct.

### Interacciones

Su ruido alimenta:

- Music Man;
- Lefty.

---

## 3.17. Phantom Freddy

**Tipo:** non-lethal jumpscare / flashlight pressure.

Empieza con un valor aproximado:

```text
fade = 255
```

Cada 0.25 s sin linterna:

```text
fade -= floor(AI/5) + 1
```

A 120°F también puede perder valor cada ~0.05 s.

Con linterna:

```text
fade += 5 por frame
hasta ~400
```

Al llegar a 0:

```text
-> phantom jumpscare
-> fade = ~1000
```

### Interacción crítica con ventilaciones

La documentación de código indica que durante su jumpscare puede **forzar a enemigos que están esperando en la abertura del vent a entrar**, alrededor de 20 frames después de iniciar el scare.

No es un jumpscare lethal por sí mismo, pero puede convertir otra amenaza en una muerte real.

---

## 3.18. Phantom BB

**Tipo:** non-lethal camera jumpscare.

Al levantar cámara:

```text
Random(0..49) < AI
```

Tiempo para reaccionar:

```text
100 - AI*2 frames
```

Counter:

- cambiar de cámara;
- cambiar a Vent/Duct system.

Si falla:

```text
-> jumpscare phantom
-> monitor baja
```

La bajada forzada del monitor puede coincidir con amenazas de oficina/puertas.

---

## 3.19. Nightmare Freddy

**Tipo:** Freddles + flashlight.

Cada 1 s con cámaras arriba:

```text
Random(0..29) < AI
```

puede añadir un Freddle.

Visualmente pueden verse ~5, pero el contador interno puede continuar hasta aproximadamente 7.

Al alcanzar el límite:

```text
-> Nightmare Freddy lethal
```

Con linterna:

```text
1-2 Freddles: 1/20 por frame de eliminar uno
3+ Freddles:  1/10 por frame
```

### Interacción

BB deshabilitando la linterna es especialmente peligroso.

---

## 3.20. Nightmare Bonnie

**Tipo:** plushie animatronic.

Comparte sistema con:

- Circus Baby
- Nightmare Mangle

Uno de ellos puede ocupar CAM 02 en:

```text
1 AM
3 AM
5 AM
```

Tras aparecer tienes ~20 s para comprar su plush en CAM 07.

Según el reverse engineering más usado:

```text
AI 1-9   -> 10 Faz-Coins
AI 10-19 -> 15 Faz-Coins
AI 20    -> 20 Faz-Coins
```

Existe otra fuente comunitaria que da una fórmula gradual `10 + floor(AI/2)`, pero el spreadsheet de código y guías técnicas modernas reportan el sistema 10/15/20. **Verificar en MFA si quieres fidelidad absoluta.**

Puede camera-stallearse manteniendo CAM 02 seleccionada.

---

## 3.21. Nightmare Fredbear

**Tipo:** left door.

Cada 5 s con monitor arriba:

```text
Random(1..40) < AI
```

puede aparecer.

Ventana de reacción aproximada:

```text
300 - AI*5 frames
```

Da risa/ojos como cue.

Counter: puerta izquierda.

---

## 3.22. Nightmare

Igual base que Nightmare Fredbear, pero:

```text
lado = derecha
```

Counter: puerta derecha.

---

## 3.23. Jack-O-Chica

**Tipo:** temperature + both doors.

Por encima de ~90°F, cada segundo aumenta un contador usando aproximadamente:

```text
progress += Random(AI) * 2
```

Si ambas puertas están cerradas y la temperatura está por debajo de ~100°F:

```text
progress -= 10 por frame
mínimo aproximado -50
```

Si:

```text
progress > 500
```

-> muerte.

### Interacciones

Heater y estrategias de temperatura para Rockstar Freddy/ductos pueden acelerar a Jack-O-Chica.

---

## 3.24. Nightmare Mangle

Mismo subsistema de plushies que Nightmare Bonnie y Circus Baby.

- CAM 02 en 1/3/5 AM.
- ~20 s de gracia.
- comprar plush correspondiente.
- camera stall en CAM 02.

---

## 3.25. Nightmarionne

**Tipo:** cursor hazard.

Tiene varias posiciones posibles en oficina.

Variables aproximadas:

```text
location = 1..6
visibility = 255
```

`255` = prácticamente invisible.

Si cursor lo solapa:

```text
visibility -= floor(AI/5) + 1 por frame
```

Si no:

```text
visibility += 1 por frame
máx. 255
```

Al acercarse a `0` se vuelve letal.

Cuando está completamente invisible su posición puede rerollearse.

### Regla esencial

**No dejes el cursor encima de Nightmarionne.**

---

## 3.26. Nightmare BB

**Tipo:** desk state + flashlight.

Al levantar monitor:

```text
Random(1..40) < AI
```

puede ponerse de pie.

Reglas clave:

- si está **sentado**, alumbrarlo es peligroso;
- si está **de pie**, debes usar la linterna;
- volver a manipular monitor en mal momento puede matar.

Conviene modelarlo como enum:

```haxe
enum NbbState {
    Sitting;
    Standing;
}
```

---

## 3.27. Old Man Consequences

**Tipo:** monitor-lock minigame / non-lethal.

Cada ~5 s:

```text
Random(0..29) < AI
```

puede iniciar el minijuego, siempre que no esté ya activo.

Tiempo de reacción:

```text
250 - AI*5 frames
```

Si fallas:

```text
monitorLock = 300 + AI*10 frames
```

### Interacciones

Un monitor bloqueado complica:

- Puppet;
- Toy Freddy;
- plushies;
- Funtime Foxy;
- Rockstar Bonnie;
- Scrap Baby;
- sistemas Vent/Duct;
- Death Coin / Faz-Coins.

---

## 3.28. Circus Baby

Comparte exactamente el subsistema principal de plushies:

- aparece como una de las tres amenazas CAM 02;
- intervalos 1/3/5 AM;
- ~20 s para comprar su figura/plush;
- precio según AI;
- CAM 02 puede stall.

---

## 3.29. Ballora

**Tipo:** left/right door + audio.

Cada ~14 s:

```text
Random(0..39) < AI
```

puede iniciar ataque.

Selecciona izquierda/derecha.

Tiempo total de reacción reportado:

```text
~170 frames
```

Lights flicker aproximadamente después de 100 frames.

Durante su ataque:

- las cámaras quedan afectadas/deshabilitadas visualmente;
- todavía pueden existir botones interactuables en ciertos casos.

Counter: escuchar música y cerrar la puerta correcta.

---

## 3.30. Funtime Foxy

**Tipo:** Showtime / clock.

Sus horas de Showtime se generan entre horas completas.

Primer Showtime normalmente se escoge dentro de:

```text
1-3 AM
```

Si estás mirando CAM 06 exactamente al llegar la hora:

```text
-> Showtime se retrasa 1-3 horas
```

### Peculiaridad del AI

El AI prácticamente no cambia el concepto de Showtime; se comporta más como `enabled/disabled` que como una escala convencional.

### Camera stall especial

CAM 06 puede retrasar el momento del jumpscare, pero si ya perdiste Showtime puedes morir al volver a abrir el monitor.

---

## 3.31. Ennard

**Tipo:** vent system.

Velocidad inicial aproximada:

```text
1
```

Cada 6 s:

```text
speed = Random(floor(AI/2)) + 1
```

Después de esquinas puede volver a velocidad ~5.

Toma el camino medio.

No afectado por Vent Snare.

En la abertura:

```text
deadline = 400 - AI*10 frames
```

Si expira con monitor arriba y Withered Chica no bloquea:

```text
-> lethal
```

Audio metálico sirve como cue.

---

## 3.32. Trash and the Gang

**Tipo:** distraction / non-lethal.

Incluye apariciones de objetos como Mr. Can-Do y No. 1 Crate.

Ejemplos documentados:

```text
Mr. Can-Do:
spawn/posición ligada a Random(29 - AI)

No. 1 Crate:
check al abrir cámaras
susurra al aparecer
luego aproximadamente cada 7 s
```

Puede disparar su “trash jumpscare” visual con checks periódicos.

No mata, pero tapa visión/audio.

---

## 3.33. Helpy

**Tipo:** office distraction.

Spawn al abrir cámara aproximadamente:

```text
Random(1..40) < AI
```

Tiempo antes del airhorn/jumpscare:

```text
500 - AI*5 frames
```

Counter: click.

### Interacción REALMENTE importante

El reverse engineering indica:

```text
Helpy airhorn -> MusicMan.irritation += 2500
```

No parece despertar genéricamente a todos los personajes sensibles al ruido.

Después de power outage puede dejar de ser clickeable.

---

## 3.34. Happy Frog

**Tipo:** duct system.

Cada ~1.0 s:

```text
Random(0..29) < AI
```

puede moverse.

Audio Lure:

```text
100% efectiva
```

Heater:

```text
NO la empuja
```

Es la excepción principal de los Mediocre Melodies.

---

## 3.35. Mr. Hippo

Cada ~0.95 s:

```text
Random(0..29) < AI
```

Audio Lure:

```text
100% efectiva
```

Heater:

```text
pequeña posibilidad periódica de empujarlo
```

---

## 3.36. Pigpatch

Cada ~0.90 s:

```text
Random(0..29) < AI
```

Audio Lure:

```text
100% efectiva
```

Heater:

```text
puede empujarlo
```

---

## 3.37. Nedd Bear

Cada ~0.85 s:

```text
Random(0..29) < AI
```

Audio Lure:

```text
~50% efectiva
```

Heater:

```text
puede empujarlo
```

---

## 3.38. Orville Elephant

Cada ~0.90 s:

```text
Random(0..29) < AI
```

Audio Lure:

```text
~10% efectiva
```

Heater es mucho más importante para controlarlo.

### Duct rules compartidas

Si un personaje está esperando en un duct cerrado durante ~30 s:

```text
~1/3 de probabilidad de regresar a zona media
```

Si está en duct abierto y monitor arriba:

```text
~50% de intento de jumpscare cada 0.5 s
```

---

## 3.39. Rockstar Freddy

**Tipo:** Faz-Coins / Heater.

Cada ~30 s:

```text
Random(0..29) < AI
```

decide si pedirá monedas.

Se activa al abrir monitor después de haber quedado marcado.

Pide:

```text
5 Faz-Coins
```

### Heater exploit/intended counter

Después de usar Heater durante ~50 frames:

```text
cada segundo ~50% de satisfacerlo automáticamente
```

El Heater provoca glitches/espasmos visuales/voz.

### Interacciones

Usar Heater para salvar monedas puede empeorar:

- Jack-O-Chica;
- Freddy;
- Phantom Freddy;
- Lefty;

pero también puede repeler duct animatronics.

---

## 3.40. Rockstar Bonnie

**Tipo:** guitar search.

Cada ~13 s con cámara arriba:

```text
Random(0..29) < AI
```

puede aparecer.

Su guitarra puede aparecer en:

- right hallway;
- left hallway;
- Funtime Cove;
- Toy Freddy room.

Tiempo aproximado:

```text
~900 frames -> luces empiezan a fallar
~1000 frames -> lethal
```

### Interacciones

Bonnie, OMC, Ballora y otros bloqueos de cámara pueden dificultar encontrar la guitarra.

---

## 3.41. Rockstar Chica

**Tipo:** hall + wet floor sign.

Cada 10 s acumulados sin cámara, si no está en pasillo:

```text
Random(0..29) < AI
```

puede aparecer.

Elige lado ~50/50.

Si el wet floor sign ya está en su lado:

```text
-> se retira inmediatamente
```

Tras ~900 frames en el pasillo puede evaluar condiciones de muerte.

### Camera stall

Puede manipularse manteniendo seleccionada una cámara apropiada y colocando el cartel del lado correcto.

---

## 3.42. Rockstar Foxy

**Tipo:** risk/reward.

Cada ~1 min se evalúa aparición del loro con una fórmula donde **AI más alto hace el loro menos conveniente**.

La ayuda/muerte usa aproximadamente:

```text
roll = Random(1..62) + AI*2

roll <= 60 -> ayuda
roll > 60  -> jumpscare/muerte
```

Posibles ayudas:

- power;
- Faz-Coins;
- bajar temperatura;
- reducir ruido.

### Regla estratégica

Ignorar el loro = Rockstar Foxy no puede matarte por esa interacción.

---

## 3.43. Music Man

**Tipo:** noise-sensitive lethal.

Variable recomendada:

```text
irritation
```

Según ruido:

```text
0 barras -> irritation -= 5/frame
1 barra  -> irritation -= 1/frame
2 barras -> suma periódicamente
3+       -> suma cada frame
```

Escalado de aumento:

```text
1 + floor(AI/5)
```

Helpy:

```text
+2500 irritation
```

Umbrales aproximados:

```text
>5000  -> cymbals cada ~3 s
>6500  -> cada ~2 s
>8000  -> cada ~1 s
>10000 -> lethal
```

### Interacciones directas

- Phantom Mangle
- Mangle
- Phone Guy
- Lolbit
- Fan
- Power Generator
- Heater
- Power A/C
- Helpy

---

## 3.44. El Chip

**Tipo:** ad overlay / non-lethal.

Cada ~10 s, durante la mayor parte de la noche:

```text
Random(0..29) < AI
```

puede mostrar anuncio, siempre que Phone Guy no esté ocupando cierta lógica.

Hay varias imágenes posibles.

Si no lo cierras:

```text
~300 frames -> desaparece solo
```

### Lo importante

El Chip no mata directamente.

Su peligro es **ocultar la pantalla y consumir atención**, pudiendo hacerte fallar otra mecánica.

No parece incrementar Music Man directamente.

---

## 3.45. Funtime Chica

**Tipo:** visual distraction / non-lethal.

Cada ~35 s:

```text
Random(0..29) < AI
```

puede aparecer.

Distorsión visual:

```text
~200..499 frames
```

Con determinados ajustes de efectos visuales su impacto se reduce mucho.

No mata por sí misma.

---

## 3.46. Molten Freddy

**Tipo:** vent system.

Velocidad inicial aproximada:

```text
8
```

Cada 6 s:

```text
speed = Random(floor(AI/2)) + 2
```

Después de esquinas:

```text
speed ~= 5
```

Camino medio.

Vent Snare no lo afecta.

En abertura:

```text
deadline = 400 - AI*10 frames
```

Si monitor arriba y Withered Chica no bloquea:

```text
-> lethal
```

Cue: risa.

---

## 3.47. Scrap Baby

**Tipo:** camera-trigger + controlled shock.

Cada ~5 s con monitor arriba:

```text
Random(0..29) < AI
```

puede aparecer sentada.

Necesita otra instancia/entrada de cámara para avanzar a estado “mirándote”.

Si vuelves a cámara sin shockearla puede ejecutar por frame:

```text
Random(0..99) < AI
```

-> lethal.

Shock:

```text
aprox. -1% power
```

### Recomendación de estados

```text
Inactive
Sitting
Armed
Shocked
```

---

## 3.48. Afton / Scraptrap

**Tipo:** side vent / one-shot attack.

Aproximadamente cada 29 s:

```text
~1/4 de posibilidad de comenzar ataque
```

Fuentes técnicas más detalladas listan oportunidades cercanas a:

```text
0:29
0:58
1:27
1:56
2:25
2:54
3:23
3:52
4:21
```

Al iniciar:

- ruido metálico;
- luces parpadean.

Tiempo de reacción:

```text
130 - AI*3 frames
```

Counter: cerrar side vent.

A AI muy por encima del rango normal la ventana llega a 0, detalle útil si implementas AI uncapped.

---

## 3.49. Lefty

**Tipo:** noise + heat + Global Music Box + camera state.

Variable:

```text
irritation / stageProgress
```

Si ruido >1:

```text
puede aumentar según AI
```

Por encima de 80°F:

```text
+ irritación probabilística
```

Por encima de 100°F:

```text
+ otra capa adicional
```

Global Music Box:

```text
evita nuevo aumento
irritation -= 1/frame
```

Sus fases progresan aproximadamente en bloques de 300.

En torno a:

```text
1800+
```

puede matar en checks de ~1 s con cámara arriba, salvo interacción de CAM 03.

### Interacciones fuertes

Lo empeoran:

- Phantom Mangle;
- Mangle;
- Phone Guy;
- Lolbit;
- Power Generator;
- Fan/Heater/A-C indirectamente por ruido;
- temperatura alta.

Global Music Box es su counter principal.

---

## 3.50. Phone Guy

**Tipo:** audio distraction / noise.

Cada ~20 s:

```text
Random(0..29) < AI
```

puede iniciar llamada si:

- no hay otra llamada;
- Dee Dee/XOR no están ocupando su evento.

Mute button visible:

```text
300 - AI*2 frames
```

El botón se mueve por una ruta predefinida y se detiene cuando llega llamada.

Phone Guy añade aproximadamente:

```text
+1 noise
```

### Interacciones

Puede acelerar:

- Music Man;
- Lefty.

También tapa cues de audio de Ballora, Ennard, Molten Freddy, etc.

---

# 4. Dee Dee

Dee Dee no es un animatrónico lethal directo. Funciona como **modificador dinámico del roster**.

## 4.1. Cuántas veces puede aparecer

Al inicio de la noche se reportan:

```text
4 checks independientes de 1/10
```

La cantidad de checks exitosos determina cuántas apariciones de Dee Dee quedan programadas.

En términos de Haxe:

```haxe
var ddAppearances = 0;

for (_ in 0...4)
    if (rng.chance(0.10))
        ddAppearances++;
```

Luego las consume a través de horas/ventanas de la noche.

---

## 4.2. Qué puede modificar

Investigación comunitaria del código indica que tiene un subconjunto de personajes del roster principal y los seis secretos.

Lista reportada para roster normal:

```text
Freddy
Foxy
Toy Freddy
Toy Bonnie
Toy Chica
Mangle
BB
JJ
Withered Bonnie
Marionette (hay discrepancia con algunas lecturas del MFA)
Golden Freddy
Nightmare Freddy
Nightmare Fredbear
Jack-O-Chica
Nightmarionne
Ballora
Trash and the Gang
Orville
Rockstar Bonnie
Rockstar Foxy
Music Man
Afton
```

Regla general:

```text
solo puede elegir personajes cuyo AI actual sea < 5
```

Si escoge uno:

```text
AI final = 5..10
```

Dependiendo del estado puede:

- añadir un personaje apagado;
- aumentar un personaje ya presente;
- seleccionar uno de los secretos.

---

# 5. Lo que tu MFA ya revela sobre Dee Dee

Tus capturas del `Frame 2` son MUY compatibles con la documentación comunitaria.

Se observó:

```text
DeeDee = 1
crate big.Value D = 0 / 1 / 2
crate big.Value E = 1, 2, 3, 4...
cscharX.Value D < 5
```

y eventos del estilo:

```text
crate big.Value E = 2
+ cschar4.Value D < 5

crate big.Value E = 3
+ cschar5.Value D < 5

crate big.Value E = 4
+ cschar6.Value D < 5
...
```

## Mapeo probable

### `cscharX.Value D`

**Confianza: alta**

Probablemente:

```text
AI level del personaje
```

La evidencia fuerte es precisamente:

```text
Value D < 5
```

que coincide con la regla conocida de Dee Dee.

### `crate big.Value E`

**Confianza: alta-media**

Parece funcionar como:

```text
candidateIndex / characterSelector
```

es decir, un índice para recorrer personajes que Dee Dee puede elegir.

### `crate big.Value D`

**Confianza: media**

Los estados `0`, `1`, `2` alrededor de eventos de Dee Dee parecen un:

```text
deeDeeState
```

posiblemente:

```text
0 = idle
1 = animation / choosing
2 = challenger resolution
```

Hay que inspeccionar las acciones para confirmarlo.

### `crate big.Value C`

**Confianza: baja-media**

Aparecen estados `0..4`, probablemente:

- animation state;
- phase;
- random branch;
- effect index.

No conviene renombrarlo todavía.

### `crate big.Value A`

Tiene condiciones:

```text
A = 0
A > 0
```

y checks temporales. Podría ser un cooldown/timer/enable flag.

**No renombrar sin abrir las acciones.**

---

# 6. XOR / Shadow Dee Dee

XOR reemplaza la lógica normal de Dee Dee en circunstancias especiales.

## 6.1. Aparición

En una noche normal:

```text
aprox. 1/1000 de quedar activada
```

En 50/20 / 10 000 puntos:

```text
queda programada prácticamente siempre
```

Una vez preparada, en:

```text
11 s
21 s
31 s
41 s
...
hasta ~2:51
```

hace aproximadamente:

```text
50% chance de aparecer
```

Existe por tanto una posibilidad diminuta de que todos esos rolls fallen.

---

## 6.2. Secuencia

Después de aparecer y realizar su animación, añade a los seis secretos en orden fijo, aproximadamente cada 7 s:

```text
1. RWQFSFASXC
2. Plushtrap
3. Nightmare Chica
4. Bonnet
5. Minireenas
6. Lolbit
```

Para una implementación limpia:

```haxe
var xorQueue = [
    RWQFSFASXC,
    PLUSH_TRAP,
    NIGHTMARE_CHICA,
    BONNET,
    MINIREENAS,
    LOLBIT
];
```

y un timer de 7 s.

### DD Repel

DD Repel puede evitar Dee Dee y XOR en noches normales, pero **no cancela la XOR forzada de 50/20**.

---

# 7. Los seis personajes secretos de Dee Dee / XOR

## 7.1. RWQFSFASXC / Shadow Bonnie

**No lethal directo.**

Necesita interacción con cámara para completar su aparición.

Después:

```text
oficina/puertas se oscurecen ~20 s
```

Su peligro consiste en esconder:

- ojos de Nightmare/Nightmare Fredbear;
- posiciones/feedback visual;
- otros hazards de oficina.

Conviene modelarlo como:

```text
blackoutTimerFrames
```

---

## 7.2. Plushtrap

Aparece en CAM 06.

Se genera un límite de ataque aleatorio aproximado:

```text
700..1199 frames
~= 11.67..19.98 s
```

Para echarlo:

```text
mantenerlo visible ~100 frames
~= 1.67 s
```

Después huye y no vuelve.

CAM 06 tiene por tanto una interacción simultánea con:

- Plushtrap;
- Funtime Foxy.

---

## 7.3. Nightmare Chica

Su boca superior comienza aproximadamente en:

```text
y = -710
```

Cada frame:

```text
y += 1
```

Si:

```text
y >= 0
```

-> lethal.

Power A/C:

```text
y -= 4 por frame
```

Si retrocede por debajo del punto inicial:

```text
-> queda derrotada por el resto de la noche
```

Es una amenaza de una sola vez.

---

## 7.4. Bonnet

Una vez habilitada:

```text
cada 5 s -> ~50% de aparecer
```

Cruza la oficina de derecha a izquierda.

Counter:

```text
click en la nariz
```

Tras aparecer puede volver a habilitarse aproximadamente:

```text
60 s después
```

Es la secreta que puede reaparecer varias veces.

---

## 7.5. Minireenas

Necesitan una transición de cámara para pegarse a la pantalla.

Una vez visibles:

```text
~2000 frames
~= 33.33 s
```

Luego una nueva interacción con monitor permite que desaparezcan.

No matan, pero bloquean gran parte de la oficina.

---

## 7.6. Lolbit

Una vez habilitado:

```text
cada 5 s -> ~50% de aparecer
```

Al aparecer:

```text
noise += 3
```

Counter:

```text
teclear L O L
```

Si no:

```text
desaparece solo tras ~1000 frames
~= 16.67 s
```

### Interacciones muy peligrosas

Lolbit puede disparar rápidamente:

- Music Man;
- Lefty;

y además tapa señales de audio.

---

# 8. Fredbear

Fredbear no pertenece al roster secreto normal de Dee Dee/XOR.

Es un Easter egg separado.

Procedimiento:

```text
1. Golden Freddy = AI 1
2. resto del roster apagado
3. conseguir 10 Faz-Coins
4. comprar Death Coin
5. hacer aparecer Golden Freddy
6. usar Death Coin sobre él
7. Fredbear ejecuta su jumpscare secreto
```

En algunas versiones/fuentes se indica que Dee Dee añadiendo un personaje puede impedir la condición del Easter egg, por lo que para una réplica fiel conviene comprobar la condición exacta en el MFA.

---

# 9. Death Coin

Cuesta:

```text
10 Faz-Coins
```

Uso único por noche.

Personajes normalmente Death-Coinables:

- Bonnie;
- Foxy;
- Toy Freddy;
- Marionette;
- Funtime Foxy;
- Rockstar Bonnie;
- Lefty.

Usarla sobre Bonnie/Foxy elimina el sistema compartido de Pirate Cove.

Golden Freddy es el caso secreto especial asociado a Fredbear.

---

# 10. Power-Ups

## Frigid

```text
temperatura inicial ~= 50°F
```

Retrasa amenazas relacionadas con calor.

## 3 Coins

Empiezas con:

```text
+3 Faz-Coins
```

## Battery

Empiezas alrededor de:

```text
102% power
```

## DD Repel

Bloquea Dee Dee durante la noche y normalmente evita XOR casual.

No cancela la XOR obligatoria de 50/20.

---

# 11. Interacciones cruzadas: lo más importante para el port

## 11.1. BB -> flashlight systems

Si BB entra:

```text
flashlightEnabled = false
```

Afecta indirectamente:

- Phantom Freddy;
- Nightmare Freddy / Freddles;
- Nightmare BB.

No implementes a BB como simple overlay: debe modificar un **shared FlashlightSystem**.

---

## 11.2. JJ -> door systems

JJ dentro:

```text
doorControlsEnabled = false
```

Esto puede convertir en letales ataques simultáneos de personajes que requieren puertas.

Usa un sistema compartido:

```haxe
doorSystem.lockedBy.add(JJ);
```

en vez de hacer que cada animatrónico pregunte directamente por JJ.

---

## 11.3. Withered Chica -> vent blocker

Cuando queda atascada:

```text
frontVentBlockedByChica = true
```

Springtrap, Ennard y Molten Freddy deben comprobar esa condición antes de resolver su ataque.

---

## 11.4. Phantom Freddy -> vent timing

Su jumpscare no mata directamente.

Pero durante la animación puede forzar la resolución de personajes que esperan en la abertura del sistema de vents.

Eso significa que:

```text
phantom scare != cosmetic only
```

Debe emitir un gameplay event.

Ejemplo Haxe:

```haxe
eventBus.emit(UcnEvent.PhantomFreddyScare(frame));
```

y VentSystem decide qué actores se ven afectados.

---

## 11.5. Phantom Mangle -> Music Man / Lefty

Mientras está activa:

```text
noise += 1
```

Por ello puede:

```text
-> subir MusicMan.irritation
-> subir Lefty.irritation
```

---

## 11.6. Mangle -> Music Man / Lefty

Una vez dentro de la oficina también contribuye ruido.

No basta con cambiar su sprite o marcarla como “entered”.

---

## 11.7. Helpy -> Music Man

El airhorn aplica aproximadamente:

```text
MusicMan.irritation += 2500
```

No debería tratarse como un jumpscare puramente visual.

---

## 11.8. Phone Guy -> noise-sensitive characters

Durante llamada:

```text
noise += 1
```

Además tapa cues de audio:

- Ballora;
- Ennard;
- Molten Freddy;
- Afton.

---

## 11.9. Lolbit -> noise catastrophe

```text
noise += 3
```

Puede llevar instantáneamente el sistema de ruido a niveles peligrosos.

---

## 11.10. Heater: counter con coste

Beneficios:

- empuja varios Mediocre Melodies;
- puede satisfacer Rockstar Freddy;
- elimina Nightmare Chica indirectamente solo mediante A/C, no Heater.

Costes:

- sube temperatura;
- acelera/interactúa con Freddy;
- Jack-O-Chica;
- Phantom Freddy a 120;
- Lefty.

Es un ejemplo perfecto de por qué UCN necesita sistemas globales y no 50 scripts aislados.

---

## 11.11. Global Music Box: triple interacción

Una misma utilidad puede simultáneamente:

```text
+ mantener Puppet
+ neutralizar check de Chica
+ calmar Lefty
```

Esto debería estar implementado en `MusicSystem`, no duplicado en tres clases.

---

## 11.12. OMC / Bonnie / Ballora -> monitor pressure

Los tres pueden reducir la disponibilidad/claridad del monitor de distintas formas.

Eso afecta a todo lo que necesita cámaras:

- Toy Freddy;
- Puppet;
- plushies;
- Funtime Foxy;
- Rockstar Bonnie;
- Scrap Baby;
- Vent/Duct systems;
- Faz-Coins;
- Death Coin.

---

# 12. Personajes no letales y qué alteran realmente

| Personaje | Mata directamente | Qué altera |
|---|---:|---|
| Bonnie | No | inutiliza feed de cámaras |
| Phantom Mangle | No | monitor + ruido |
| Phantom Freddy | No | jumpscare + interacción con vents |
| Phantom BB | No | fuerza bajada del monitor |
| OMC | No | bloquea monitor |
| Trash and the Gang | No | visión/audio |
| Helpy | No | Music Man irritation |
| El Chip | No | overlay / atención |
| Funtime Chica | No | visión/distorsión |
| Phone Guy | No | ruido + tapa audio cues |
| RWQFSFASXC | No | oscuridad |
| Minireenas | No | visión |
| Lolbit | No | ruido + audio/overlay |

En UCN un personaje “no lethal” puede ser extremadamente importante porque cambia el estado compartido que otro animatrónico usa para matarte.

---

# 13. Rare easter eggs y apariciones visuales

## 13.1. Bouncepot, White Rabbit y Tangle

Investigaciones de la comunidad técnica reportan aproximadamente:

```text
1/10000
```

para estas apariciones raras de FNaF World en el escritorio, asociadas a cambios/uso del monitor.

Son **Easter eggs visuales**, no amenazas con IA real.

> Algunas hojas comunitarias contienen bromas/fake mechanics para estos personajes. No deben confundirse con el comportamiento real del juego.

---

## 13.2. TOYSNHK / Vengeful Spirit

La cara puede aparecer en varios lugares raros.

Valores reportados por la comunidad:

```text
puerta izquierda: ~1/10000
abertura central: ~1/10000
aparición de oficina/monitor: del orden de ~1/1000 según contexto
```

Los números exactos presentan pequeñas discrepancias entre análisis comunitarios; revisar eventos de easter eggs del MFA si quieres replicarlos bit-perfect.

---

# 14. Arquitectura recomendada en Haxe

## 14.1. Sistemas

```text
UcnPlayState
├── ClockSystem
├── PowerSystem
├── TemperatureSystem
├── NoiseSystem
├── VentilationSystem
├── CameraSystem
├── DoorSystem
├── FlashlightSystem
├── MaskSystem
├── FazCoinSystem
├── MusicSystem
├── UtilitySystem
├── AnimatronicManager
├── DeeDeeController
├── XorController
└── JumpscareManager
```

---

## 14.2. Base común

```haxe
interface IUcnActor {
    public var ai:Int;
    public var enabled:Bool;

    public function fixedTick(ctx:UcnContext):Void;
    public function reset():Void;
}
```

Contexto compartido:

```haxe
class UcnContext {
    public var frame:Int;
    public var hour:Int;

    public var temperature:Int;
    public var noise:Int;
    public var power:Float;

    public var monitorUp:Bool;
    public var currentCamera:Int;

    public var leftDoorClosed:Bool;
    public var rightDoorClosed:Bool;
    public var frontVentClosed:Bool;
    public var sideVentClosed:Bool;

    public var flashlightEnabled:Bool;
}
```

---

## 14.3. No hagas un `switch` gigante de 50 personajes

Malo:

```haxe
switch (character) {
    case Freddy: ...
    case Bonnie: ...
    case Chica: ...
    // 1300 eventos 2: Electric Boogaloo
}
```

Mejor:

```haxe
for (actor in animatronics)
    actor.fixedTick(ctx);
```

y los sistemas globales publican eventos.

---

## 14.4. Event bus

Ejemplo:

```haxe
enum UcnEvent {
    MonitorRaised;
    MonitorLowered;
    CameraChanged(id:Int);
    NoiseChanged(value:Int);
    TemperatureChanged(value:Int);
    PhantomFreddyScare;
    PowerOut;
    HourChanged(hour:Int);
}
```

Esto sirve para reproducir interacciones como:

```text
Phantom Freddy scare
 -> VentSystem
 -> Mangle/Withered Chica/Springtrap/Ennard/Molten Freddy

Lolbit spawn
 -> NoiseSystem
 -> Music Man
 -> Lefty
```

sin acoplar todas las clases entre sí.

---

# 15. Modelo especial para el vent system

Los cinco principales actores:

```text
Mangle
Withered Chica
Springtrap
Ennard
Molten Freddy
```

pueden compartir:

```haxe
class VentActor {
    public var distance:Float;
    public var speed:Int;
    public var route:VentRoute;
    public var affectedBySnare:Bool;
    public var waitingAtOpening:Bool;
}
```

Distancias aproximadas reportadas:

```text
ruta corta  ~= 127 units
ruta media  ~= 242 units
ruta larga  ~= 279 units
```

Cada segundo:

```text
distance += speed
```

Esto explica por qué Clickteam puede usar muchos eventos separados para cada esquina, mientras Haxe puede usar rutas parametrizadas.

---

# 16. Modelo para Mediocre Melodies

En vez de cinco clases copiadas:

```haxe
class DuctAnimatronic {
    public var moveInterval:Float;
    public var audioLureChance:Float;
    public var heaterPushChance:Float;
    public var heaterImmune:Bool;
}
```

Configuración:

```text
Happy Frog
 interval ~1.00
 lure = 100%
 heaterImmune = true

Mr. Hippo
 interval ~0.95
 lure = 100%
 heater works

Pigpatch
 interval ~0.90
 lure = 100%
 heater works

Nedd Bear
 interval ~0.85
 lure = ~50%
 heater works

Orville
 interval ~0.90
 lure = ~10%
 heater works
```

Así reduces decenas de eventos repetidos.

---

# 17. Modelo para plushie animatronics

```haxe
class PlushieThreat {
    public var character:PlushieCharacter;
    public var spawnHour:Int;
    public var graceFrames:Int = 20 * 60;
    public var purchased:Bool;
}
```

Precio:

```haxe
function plushPrice(ai:Int):Int {
    if (ai >= 20) return 20;
    if (ai >= 10) return 15;
    return 10;
}
```

Si el MFA confirma la fórmula gradual alternativa, cambia solo esa función.

---

# 18. Modelo Dee Dee recomendado

```haxe
class DeeDeeController {
    public var remaining:Int = 0;
    public var state:DeeDeeState = Idle;

    public function rollNight():Void {
        remaining = 0;

        for (_ in 0...4) {
            if (FlxG.random.bool(10))
                remaining++;
        }
    }

    public function pickCandidate(roster:Array<AnimatronicRuntime>):Null<AnimatronicRuntime> {
        var valid = roster.filter(c -> c.ai < 5 && c.deeDeeEligible);
        if (valid.length == 0)
            return null;

        return FlxG.random.getObject(valid);
    }
}
```

No hace falta recrear:

```text
E=1 -> cschar?
E=2 -> cschar?
E=3 -> cschar?
...
```

como 20 `if` distintos.

---

# 19. Tabla compacta de dependencias

| Sistema | Personajes más afectados |
|---|---|
| Left door | Freddy, Nightmare Fredbear, Ballora, Rockstar Chica |
| Right door | Nightmare, Ballora, Rockstar Chica |
| Side vent | BB, JJ, Afton |
| Front/mid vents | Mangle, Withered Chica, Springtrap, Ennard, Molten Freddy |
| Ducts | Happy Frog, Mr. Hippo, Pigpatch, Nedd Bear, Orville |
| Flashlight | Phantom Freddy, Nightmare Freddy, Nightmare BB |
| Freddy Mask | Toy Bonnie, Toy Chica, Withered Bonnie, Golden Freddy |
| Camera availability | Toy Freddy, Puppet, Plushies, Funtime Foxy, Rockstar Bonnie, Scrap Baby |
| Noise | Music Man, Lefty |
| Heat | Freddy, Jack-O-Chica, Phantom Freddy, Lefty |
| Global Music Box | Chica, Puppet, Lefty |
| Faz-Coins | Plushies, Rockstar Freddy, Death Coin |
| Power A/C | temperatura + Nightmare Chica |
| Heater | duct animatronics + Rockstar Freddy + heat-sensitive threats |

---

# 20. Qué buscar ahora dentro del MFA

Para documentar **los Alterable Values reales** del juego y no solo las variables lógicas, conviene hacer esto personaje por personaje.

## Paso 1

Selecciona el objeto del personaje y muestra únicamente eventos relacionados con él.

## Paso 2

Anota cada uso de:

```text
Alterable Value A
Alterable Value B
Alterable Value C
...
Flags
Animation
Position
Visibility
```

## Paso 3

Busca dónde:

```text
se inicializa
se incrementa
se decrementa
se compara con un límite
se resetea
```

## Paso 4

Asigna nombre solo cuando el propósito sea claro.

Ejemplo:

```text
Value A += ...
Value A > 500 -> jumpscare
```

podría renombrarse:

```text
AttackProgress
```

Pero si solo ves:

```text
Value C = 0
Value C = 1
Value C = 2
```

sin acciones claras, déjalo temporalmente como:

```text
UnknownC
```

---

# 21. Plantilla para documentar el MFA original

Usa esta ficha:

```md
## Character

Object:
Qualifier:
Global object: yes/no

### Alterable Values

| Slot | Nombre original | Nombre inferido | Evidencia | Confianza |
|---|---|---|---|---|
| A | Alterable Value A | AttackProgress | sube hasta 500 y mata | Alta |
| B | Alterable Value B | State | valores 0/1/2 | Media |
| C | Alterable Value C | UnknownC | insuficiente | Baja |

### Flags

| Flag | Uso |
|---|---|
| 0 | ... |

### Timers
...

### Interacciones
...
```

Esto te permite mantener separados:

```text
HECHO OBSERVADO EN MFA
vs
HIPÓTESIS
vs
MECÁNICA DOCUMENTADA POR LA COMUNIDAD
```

y evita renombrar mal una variable.

---

# 22. Prioridad para reverse-engineering de Frame 2

Yo lo recorrería en este orden:

```text
1. Global systems
   power
   heat
   noise
   monitor
   doors
   vents
   ducts

2. Character select / AI values
   cscharX.Value D

3. Vent animatronics
   porque comparten mucha lógica

4. Duct animatronics
   porque pueden convertirse en una clase parametrizada

5. Dee Dee / XOR
   ya encontramos su bloque

6. Camera threats

7. Office/mask threats

8. Easter eggs y visuales
```

Así puedes reducir muchísimo los 1343 eventos a un mapa entendible.

---

# 23. Fuentes y fiabilidad

Esta documentación cruza varias fuentes de ingeniería inversa/comunidad:

1. **u/namesmitt — UCN Character Mechanics Overview / AI spreadsheet**
   - Es una de las fuentes técnicas más detalladas disponibles.
   - Contiene fórmulas y contadores derivados del comportamiento/código.
   - Mirror consultado:
     https://www.scribd.com/document/901730775/UCN-Character-Mechanics-Sheet1

2. **TheBones5 — “How ULTIMATE CUSTOM NIGHT Works: Complete AI Breakdown / Guide”**
   - Video técnico de 2024.
   - Declara haber usado/revisado el spreadsheet de namesmitt y material de reverse engineering.
   - https://www.youtube.com/watch?v=BTV1fto4fBg

3. **Ultimate Custom Night Technical Wiki**
   - Wiki comunitaria orientada específicamente a mecánicas exactas.
   - https://ucn-technical.fandom.com/wiki/Ultimate_Custom_Night_Technical_Wiki

4. **r/technicalFNaF — Dee Dee/XOR technical discussion**
   - Útil para probabilidades y comportamiento de los secretos.
   - https://www.reddit.com/r/technicalFNaF/comments/udd4ua/

5. **UCN technical/community pages sobre Death Coin, Plushies, Nightmarionne, Ballora, Afton, XOR, etc.**
   - Usadas para contrastar fórmulas y detectar discrepancias.

6. **Tus capturas del MFA descompilado**
   - Especialmente eventos ~1191-1210 del `Frame 2`.
   - Son la evidencia más valiosa para mapear nombres reales de `Alterable Values`.

---

# 24. Discrepancias conocidas que conviene verificar en el MFA

No conviene fingir precisión donde las fuentes comunitarias no coinciden.

### Bonnie camera jam

Reportado como:

```text
250 + AI*20 frames
```

y en otra página:

```text
300 + AI*20 frames
```

### Precio de plushies

Dos fórmulas publicadas:

```text
10 / 15 / 20 por rangos de AI
```

vs.

```text
10 + floor(AI/2)
```

Las guías de reverse engineering más recientes y descripciones de personajes suelen usar `10 / 15 / 20`.

### Easter eggs visuales

Las probabilidades de TOYSNHK cambian ligeramente según análisis.

### Dee Dee roster

Algunas listas comunitarias incluyen/excluyen determinados personajes en su pool. Tus eventos `cscharX.Value D < 5` pueden resolver esto de forma definitiva.

---

# 25. Conclusión para un port Haxe

La forma correcta de portar UCN no sería traducir 1343 eventos uno por uno.

La equivalencia sería más parecida a:

```text
1343 eventos Clickteam
        ↓
~10 sistemas globales
        +
~15 comportamientos únicos
        +
varios actores parametrizados
```

Muchos personajes comparten plantillas:

```text
VentActor
DuctActor
MaskIntruder
PlushieThreat
CameraDistraction
NoiseSource
DoorAttacker
```

y solo cambian:

```text
interval
AI formula
speed
route
counter
kill condition
```

Eso conserva el comportamiento original sin conservar el spaghetti visual del MFA.

---

## Estado de esta documentación

**Versión:** 0.1 — reverse engineering inicial  
**Base:** UCN PC / Clickteam Fusion + investigación técnica comunitaria  
**Próximo paso recomendado:** mapear los `Alterable Values` reales del `Frame 2` directamente desde el MFA y anexarlos personaje por personaje.
