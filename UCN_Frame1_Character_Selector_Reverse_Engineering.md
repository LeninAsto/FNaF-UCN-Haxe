# Ultimate Custom Night — Frame 1 / Character Selector
## Reverse engineering técnico del selector, puntuación, challenges, Power-Ups, oficinas, trofeos y persistencia de Dee Dee

**Versión:** 0.1  
**Objetivo:** documentar el `Frame 1` del MFA original de *Ultimate Custom Night* como sistema de configuración de la noche y puente hacia `Frame 2` (gameplay).

> Esta guía distingue tres niveles:
>
> - **CONFIRMADO:** comportamiento visible del juego o documentado de forma consistente.
> - **COMUNIDAD / SAVE:** información obtenida de investigación comunitaria del archivo `CN`.
> - **HIPÓTESIS MFA:** arquitectura probable que conviene comprobar directamente en los eventos del `Frame 1`.

---

# 1. Qué es realmente `Frame 1`

Aunque visualmente parezca “solo el menú de los 50 animatrónicos”, técnicamente el selector es uno de los frames más importantes del juego.

Su trabajo es mantener y preparar:

```text
50 AI levels
score potencial
high score
best 50/20 time

preset/challenge seleccionado
challenges completados

inventario de Power-Ups
Power-Ups elegidos para la siguiente noche

office skin seleccionada
offices desbloqueadas

character info / descriptions
visual effects toggle

trofeos del menú

cutscene/intermission progress

valores alterados por Dee Dee al regresar desde Frame 2
```

Por eso, para un port, conviene pensar en este frame como:

```text
CharacterSelectState
+
SaveData
+
NightConfigBuilder
```

---

# 2. Flujo general

Modelo probable:

```text
START GAME
   |
   v
INTRO
   |
   v
FRAME 1 - CHARACTER SELECT
   |
   +--> cargar CN / save
   |
   +--> mostrar high score
   +--> desbloquear offices según high score
   +--> mostrar trophy según progreso
   +--> cargar challenge stars
   +--> cargar Power-Up inventory
   +--> conservar AI actual de cada personaje
   |
   +--> player edita AI / preset / Power-Ups / office
   |
   v
GO!
   |
   v
FRAME 2 - NIGHT
   |
   +--> Dee Dee puede modificar AI
   +--> final/death calcula score/rewards
   |
   v
FRAME 1
```

El detalle muy interesante es que el roster no necesariamente se reconstruye siempre desde cero.

Dee Dee puede modificar valores durante `Frame 2`, y esos valores pueden verse reflejados al volver al selector.

---

# 3. Los 50 slots

UCN tiene **50 personajes seleccionables**.

Cada uno tiene:

```text
AI ∈ [0, 20]
```

Interpretación:

```text
0  -> desactivado
1  -> mínima dificultad activa
...
20 -> dificultad máxima
```

El selector debe almacenar **50 números**, no solo 50 booleanos.

En el MFA es bastante probable que cada card sea un objeto tipo:

```text
cschar 1
cschar 2
cschar 3
...
```

y que uno de sus Alterable Values almacene el AI.

De las capturas del `Frame 2` ya vimos:

```text
Alterable Value D of (cschar X) < 5
```

dentro de la lógica de Dee Dee.

Por eso la inferencia más fuerte hasta ahora es:

```text
cscharX.Value D = AI level
```

**Confianza: alta.**

Para verificarlo en Frame 1:

```text
1. poner un personaje en AI 7;
2. buscar qué Alterable Value de su cschar cambia a 7;
3. usar "Find all events" sobre ese Value.
```

---

# 4. Orden del roster

Orden normal de los 50 personajes:

```text
01 Freddy
02 Bonnie
03 Chica
04 Foxy

05 Toy Freddy
06 Toy Bonnie
07 Toy Chica
08 Mangle
09 BB
10 JJ
11 Withered Chica
12 Withered Bonnie
13 Marionette
14 Golden Freddy

15 Springtrap
16 Phantom Mangle
17 Phantom Freddy
18 Phantom BB

19 Nightmare Freddy
20 Nightmare Bonnie
21 Nightmare Fredbear
22 Nightmare
23 Jack-O-Chica
24 Nightmare Mangle
25 Nightmarionne
26 Nightmare BB
27 Old Man Consequences

28 Circus Baby
29 Ballora
30 Funtime Foxy
31 Ennard

32 Trash and the Gang
33 Helpy
34 Happy Frog
35 Mr. Hippo
36 Pigpatch
37 Nedd Bear
38 Orville Elephant
39 Rockstar Freddy
40 Rockstar Bonnie
41 Rockstar Chica
42 Rockstar Foxy
43 Music Man
44 El Chip
45 Funtime Chica
46 Molten Freddy
47 Scrap Baby
48 Afton
49 Lefty
50 Phone Guy
```

Para el port recomiendo que este orden sea un ID estable:

```haxe
enum abstract CharacterId(Int) from Int to Int {
    var Freddy = 0;
    var Bonnie = 1;
    // ...
    var PhoneGuy = 49;
}
```

No uses el nombre del sprite como identidad lógica.

---

# 5. Controles de AI

El menú permite ajustar manualmente cada AI entre `0..20`.

Además hay controles globales/preset rápidos.

La documentación comunitaria confirma botones para establecer el roster a niveles globales como:

```text
0
5
10
20
```

y algunas fuentes describen además una operación tipo incremento global.

La parte segura para replicar es:

```haxe
function setAllAI(level:Int) {
    for (c in roster)
        c.ai = level;
}
```

con:

```haxe
level = clamp(level, 0, 20);
```

---

# 6. Puntuación potencial

La fórmula base es extremadamente simple:

```text
cada punto de AI = 10 score
```

Por tanto:

```text
score = Σ(ai[i] * 10)
```

Ejemplos:

```text
Freddy AI 20 -> 200 pts

Freddy 20
Bonnie 10
Chica 5

= (20 + 10 + 5) * 10
= 350 pts
```

Con los 50 a AI 20:

```text
50 * 20 * 10
= 10,000 pts
```

Este es el valor mostrado antes de comenzar una noche 50/20.

Los personajes secretos añadidos durante gameplay pueden aumentar el score final; la documentación comunitaria reporta un máximo efectivo de aproximadamente:

```text
10,600
```

cuando XOR incorpora sus seis amenazas secretas.

---

# 7. Dee Dee modifica el roster Y el selector posterior

Este detalle es especialmente importante para tu reverse engineering.

Si Dee Dee añade o aumenta un personaje normal durante la noche:

```text
Frame 2:
character.ai cambia
```

Cuando el jugador vuelve al Character Select, el personaje normal afectado puede aparecer:

```text
encendido
+
mostrando el AI al que Dee Dee lo dejó
```

Esto está documentado por la comunidad como una forma de descubrir qué personaje modificó Dee Dee cuando no fue evidente durante la partida.

## Consecuencia técnica

Eso sugiere que el `Frame 1` y `Frame 2` comparten los valores del roster mediante:

```text
Global Objects
o
Global Values
o
objetos persistentes / referencias globales
```

en vez de hacer:

```text
Frame 1 roster
    -> copiar a Frame 2
    -> destruir
```

y reconstruir limpio al volver.

Probablemente el flujo real es más parecido a:

```text
cscharX.Value D
      |
      v
Frame 2 lee AI
      |
Dee Dee modifica el mismo estado
      |
      v
Frame 1 vuelve a mostrar Value D
```

Esto explicaría perfectamente el comportamiento.

---

# 8. Qué pasa si Dee Dee modifica un personaje ya activo

Dee Dee tiene dos resultados principales.

## Caso A — personaje nuevo

```text
Freddy = 0

Dee Dee selecciona Freddy
-> Freddy = AI aproximadamente 5..10
-> "A NEW CHALLENGER HAS APPEARED!"
```

Al regresar al selector:

```text
Freddy aparece activado al nuevo AI
```

## Caso B — personaje ya activo y bajo

```text
Freddy = 2
```

Dee Dee puede aumentarlo aproximadamente a:

```text
5..10
```

En este caso puede no aparecer el mensaje:

```text
A NEW CHALLENGER HAS APPEARED
```

porque técnicamente no añadió un personaje nuevo; alteró uno existente.

Al regresar al selector:

```text
Freddy sigue encendido,
pero ahora con el AI modificado.
```

## Personajes secretos

```text
RWQFSFASXC
Plushtrap
Nightmare Chica
Bonnet
Minireenas
Lolbit
```

no tienen slots normales en `Frame 1`.

Por tanto:

```text
NO aparecen añadidos al selector
```

aunque hayan sido activados durante la noche.

---

# 9. Implicación para un port Haxe

Usa algo como:

```haxe
class NightConfig {
    public var ai:Array<Int>;
}
```

`Frame 1` lo edita:

```haxe
config.ai[Freddy] = 10;
```

`Frame 2` lo consume y Dee Dee puede modificar una copia runtime:

```haxe
runtime.ai[Freddy] = 8;
```

Si quieres replicar el comportamiento exacto del UCN original al volver:

```haxe
selector.ai = runtime.ai.copy();
```

Pero los secretos permanecen en otro storage:

```haxe
runtime.secretActors
```

y no generan cards.

---

# 10. High Score y Best Time

El juego almacena el mejor score superado.

En el archivo de guardado `CN`, la comunidad identificó:

```ini
hs=...
```

como High Score.

Ruta clásica de Windows:

```text
%APPDATA%\MMFApplications\CN
```

El selector registra también el mejor tiempo de 50/20. Valores identificados:

```ini
bestminutes=
besttens=
bestseconds=
besttenths=
```

Ejemplo comunitario:

```ini
bestminutes=4
besttens=3
bestseconds=0
besttenths=0
```

≈ `4:30.0`.

En Haxe es mejor guardar milisegundos y formatear la UI.

---

# 11. Ratings de High Score

| Score | Rating |
|---:|---|
| 0 | Great Job! |
| 2000 | Fantastic! |
| 4000 | Amazing! |
| 6000 | Stupendous! |
| 8000 | Perfect! |
| 10000 | Unbeatable! |

---

# 12. Oficinas seleccionables

| Office | Unlock |
|---|---:|
| UCN / default | 0 |
| Sister Location | 2000 |
| FNaF 3 | 5000 |
| FNaF 4 | 8000 |

Son esencialmente skins; no deberían cambiar reglas de AI/timers.

Lógica probable:

```text
if hs >= 2000 -> unlock office 2
if hs >= 5000 -> unlock office 3
if hs >= 8000 -> unlock office 4
```

La selección debe guardarse aparte del unlock.

---

# 13. Trofeos de Freddy del menú

Añadidos oficialmente en el patch `1.032`:

```text
High Score >= 8000 -> Freddy bronce
High Score >= 9000 -> Freddy plata
beat 50/20          -> Freddy oro
```

El trofeo dorado representa completar 50/20; en un port conviene guardar:

```haxe
beat5020:Bool;
```

separado de `highScore`.

---

# 14. Power-Ups

Cuatro consumibles:

```text
Frigid
3 Coins
Battery
DD Repel
```

Se reciben aleatoriamente al terminar intentos/noches.

El save `CN` usa, según reverse engineering comunitario:

```ini
i1 = Frigid
i2 = 3 Coins
i3 = Battery
i4 = DD Repel
```

El stock normal de UI se limita aproximadamente a `0..9` por tipo.

## Frigid

```text
start temperature = 50°F
```

en vez de 60°F.

## 3 Coins

```text
start Faz-Coins = 3
```

## Battery

```text
start power = 102%
```

## DD Repel

Bloquea Dee Dee normal esa noche, pero no la XOR forzada de 50/20.

Los consumibles armados se gastan al jugar esa noche. La UI permite combinar varios tipos en un mismo intento.

La probabilidad exacta de recibir rewards no está suficientemente documentada públicamente: conviene buscar el `Random(...)` real en el MFA.

---

# 15. Challenges

Hay **16 challenges**. Seleccionar uno equivale conceptualmente a:

```text
reset roster
+
aplicar tabla predeterminada de AI
+
selectedChallenge = id
```

Cuando se completa, aparece una estrella.

En el save se han identificado:

```ini
ch1=1
...
ch16=1
```

como flags de completion; también aparece `ch0`, cuyo propósito exacto conviene verificar en el MFA.

Orden:

```text
01 Bears Attack 1
02 Bears Attack 2
03 Bears Attack 3
04 Pay Attention 1
05 Pay Attention 2
06 Ladies Night 1
07 Ladies Night 2
08 Ladies Night 3
09 Creepy Crawlies 1
10 Creepy Crawlies 2
11 Nightmares Attack
12 Springtrapped
13 Old Friends
14 Chaos 1
15 Chaos 2
16 Chaos 3
```

---

# 16. Presets exactos de Challenges

## Bears Attack 1 — 410 pts

```text
Freddy 10
Golden Freddy 1
Phantom Freddy 1
Nightmare Fredbear 10
Nightmare 10
Helpy 1
Nedd Bear 1
Rockstar Freddy 5
Molten Freddy 1
Lefty 1
```

> Hay guías tardías que muestran Helpy 5, pero el listado original del demo/Steam usa Helpy 1 y así cuadra el total de 41 AI = 410 puntos. Verificar contra el MFA.

## Bears Attack 2 — 1010 pts

```text
Freddy 10
Toy Freddy 1
Golden Freddy 10
Phantom Freddy 5
Nightmare Freddy 5
Nightmare Fredbear 10
Nightmare 10
Helpy 10
Nedd Bear 10
Rockstar Freddy 10
Molten Freddy 10
Lefty 10
```

## Bears Attack 3 — 1400 pts

```text
Freddy 20
Toy Freddy 5
Golden Freddy 10
Phantom Freddy 10
Nightmare Freddy 10
Nightmare Fredbear 20
Nightmare 20
Helpy 5
Nedd Bear 10
Rockstar Freddy 10
Molten Freddy 10
Lefty 10
```

## Pay Attention 1 — 800 pts

```text
BB 5
JJ 5
Marionette 5
Nightmare BB 5
Old Man Consequences 5
Funtime Foxy 5
Helpy 10
Music Man 10
El Chip 5
Funtime Chica 10
Afton 5
Phone Guy 10
```

## Pay Attention 2 — 2000 pts

```text
BB 20
JJ 20
Marionette 10
Nightmare BB 20
Old Man Consequences 10
Funtime Foxy 10
Helpy 20
Music Man 20
El Chip 10
Funtime Chica 20
Afton 20
Phone Guy 20
```

## Ladies Night 1 — 360 pts

```text
Chica 5
Toy Chica 5
Mangle 5
JJ 1
Withered Chica 5
Jack-O-Chica 5
Circus Baby 1
Ballora 1
Happy Frog 5
Rockstar Chica 1
Funtime Chica 1
Scrap Baby 1
```

## Ladies Night 2 — 810 pts

```text
Chica 5
Toy Chica 10
Mangle 5
JJ 5
Withered Chica 10
Jack-O-Chica 10
Nightmare Mangle 1
Circus Baby 5
Ballora 5
Happy Frog 10
Rockstar Chica 5
Funtime Chica 5
Scrap Baby 5
```

## Ladies Night 3 — 1800 pts

```text
Chica 10
Toy Chica 20
Mangle 10
JJ 10
Withered Chica 20
Jack-O-Chica 20
Nightmare Mangle 10
Circus Baby 10
Ballora 10
Funtime Foxy 10
Happy Frog 20
Rockstar Chica 10
Funtime Chica 10
Scrap Baby 10
```

## Creepy Crawlies 1 — 900 pts

```text
Mangle 10
Withered Chica 5
Withered Bonnie 10
Marionette 5
Springtrap 10
Phantom Mangle 5
Ennard 10
Happy Frog 5
Mr. Hippo 5
Pigpatch 5
Nedd Bear 5
Orville Elephant 5
Music Man 5
Molten Freddy 5
```

## Creepy Crawlies 2 — 2510 pts

```text
Mangle 20
Withered Chica 20
Withered Bonnie 20
Marionette 10
Springtrap 20
Phantom Mangle 10
Ennard 20
Happy Frog 20
Mr. Hippo 20
Pigpatch 20
Nedd Bear 20
Orville Elephant 20
Music Man 10
Molten Freddy 20
Afton 1
```

## Nightmares Attack — 2800 pts

```text
Withered Bonnie 20
Golden Freddy 20
Nightmare Freddy 20
Nightmare Bonnie 20
Nightmare Fredbear 20
Nightmare 20
Jack-O-Chica 20
Nightmare Mangle 20
Nightmarionne 20
Nightmare BB 20
Music Man 20
Molten Freddy 20
Scrap Baby 20
Lefty 20
```

## Springtrapped — 1700 pts

```text
JJ 20
Springtrap 20
Phantom Mangle 20
Phantom Freddy 20
Phantom BB 20
Nightmarionne 10
Trash and Gang 10
Rockstar Foxy 20
Afton 20
Lefty 20
```

## Old Friends — 2600 pts

```text
Freddy 20
Bonnie 20
Chica 20
Foxy 20
Toy Freddy 20
Toy Bonnie 20
Toy Chica 20
Mangle 20
BB 20
Marionette 20
Springtrap 20
Circus Baby 20
Phone Guy 20
```

## Chaos 1 — 1140 pts

```text
Toy Freddy 5
Withered Bonnie 5
Marionette 5
Phantom Mangle 5
Nightmare Freddy 5
Nightmare Fredbear 5
Nightmare 5
Jack-O-Chica 5
Old Man Consequences 5
Circus Baby 20
Ballora 5
Trash and Gang 1
Helpy 5
Happy Frog 1
Mr. Hippo 1
Pigpatch 1
Rockstar Freddy 5
Rockstar Bonnie 5
Rockstar Foxy 5
Music Man 5
El Chip 5
Funtime Chica 5
Afton 5
```

## Chaos 2 — 2500 pts

```text
Freddy 5
Toy Bonnie 5
Toy Chica 5
Marionette 10
Golden Freddy 10
Phantom Freddy 20
Phantom BB 10
Nightmare Bonnie 10
Nightmare Mangle 5
Old Man Consequences 10
Circus Baby 5
Trash and Gang 10
Helpy 10
Happy Frog 5
Mr. Hippo 5
Pigpatch 5
Rockstar Freddy 5
Rockstar Chica 5
Rockstar Foxy 10
Music Man 20
El Chip 10
Funtime Chica 10
Scrap Baby 20
Afton 20
Phone Guy 10
```

## Chaos 3 — 5100 pts

```text
Bonnie 20
Foxy 20
Toy Bonnie 5
Toy Chica 5
Mangle 5
BB 5
JJ 5
Withered Chica 5
Withered Bonnie 20
Phantom Mangle 20
Phantom BB 20
Nightmare Bonnie 20
Nightmarionne 20
Nightmare BB 20
Old Man Consequences 20
Ennard 20
Trash and Gang 20
Helpy 20
Happy Frog 10
Mr. Hippo 10
Pigpatch 10
Nedd Bear 20
Orville Elephant 20
Rockstar Freddy 10
Rockstar Bonnie 20
Rockstar Chica 20
Rockstar Foxy 20
Music Man 20
El Chip 20
Funtime Chica 20
Lefty 20
Phone Guy 20
```

---

# 17. Cómo debería funcionar `selectChallenge()` en Haxe

No codifiques 16 bloques gigantes de setters.

```haxe
typedef ChallengeEntry = {
    var character:CharacterId;
    var ai:Int;
}

typedef ChallengePreset = {
    var id:Int;
    var name:String;
    var entries:Array<ChallengeEntry>;
}
```

```haxe
function selectChallenge(preset:ChallengePreset) {
    setAllAI(0);

    for (entry in preset.entries)
        roster[entry.character].ai = entry.ai;

    selectedChallenge = preset.id;
}
```

Un challenge se completa por identidad de preset, no por coincidir casualmente con el mismo score.

Dee Dee puede modificar el roster durante el challenge, así que el flag `selectedChallenge` debe sobrevivir independientemente de los AI runtime.

---

# 18. Character Information

El selector incluye una opción para mostrar/ocultar descripciones al pasar por cada card.

Conviene separar:

```haxe
class CharacterDefinition {
    var name:String;
    var description:String;
    var portrait:String;
}
```

from:

```haxe
class CharacterRuntime {
    var ai:Int;
}
```

La descripción es UI, no lógica de AI.

---

# 19. Visual Effects / Low Detail

Una actualización oficial añadió el toggle `Visual Effects` / modo de detalle bajo para mejorar FPS.

Debe ser un setting global:

```haxe
visualEffects:Bool;
```

Ejemplo: Funtime Chica sigue pudiendo activar su evento, pero su distorsión visual puede omitirse si los efectos están desactivados.

---

# 20. Cutscenes / Intermissions por score

Milestones documentados:

| Score | Intermission |
|---:|---|
| 700 | Bear of Vengeance 1 |
| 1400 | Toy Chica 1 |
| 2100 | Bear of Vengeance 2 |
| 2800 | Toy Chica 2 |
| 3500 | Bear of Vengeance 3 |
| 4200 | Toy Chica 3 |
| 4900 | Bear of Vengeance 4 |
| 5600 | Toy Chica 4 |
| 6300 | Bear of Vengeance 5 |
| 7000 | Toy Chica 5 |
| 7700 | Bear of Vengeance 6 |
| 8400 | Toy Chica 6 |
| 9100 | Toy Chica 7 |
| 9800 | Golden Freddy final intermission |

El save usa una key `ep`, asociada por la comunidad al progreso de episodios/intermissions. Hay que comprobar en el MFA cómo avanza exactamente.

El sistema es secuencial: un score enorme no debería reproducir automáticamente todos los episodios pendientes de una sola vez.

---

# 21. Archivo `CN`

Ruta PC clásica:

```text
%APPDATA%\MMFApplications\CN
```

Claves conocidas/reportadas:

```ini
[CN]
adjust=1
hs=10000

i1=...
i2=...
i3=...
i4=...

ch0=1
ch1=1
...
ch16=1

ep=...

bestminutes=...
besttens=...
bestseconds=...
besttenths=...
```

Mapeo con evidencia comunitaria:

| Key | Uso |
|---|---|
| `hs` | High Score |
| `i1` | Frigid |
| `i2` | 3 Coins |
| `i3` | Battery |
| `i4` | DD Repel |
| `ch1..ch16` | challenge completado |
| `ep` | progreso de intermissions |
| `best*` | 50/20 best time |
| `adjust` | no confirmado con seguridad |

No renombres `adjust` aún.

---

# 22. Persistente vs temporal

## Save persistente

```haxe
typedef UcnSave = {
    var highScore:Int;
    var powerups:PowerUpInventory;
    var completedChallenges:Array<Bool>;
    var episodeProgress:Int;
    var best5020Ms:Int;
    var beat5020:Bool;
    var selectedOffice:Int;
    var showDescriptions:Bool;
    var visualEffects:Bool;
}
```

## Setup de la próxima noche

```haxe
typedef NightSetup = {
    var ai:Array<Int>;
    var selectedChallenge:Null<Int>;
    var useFrigid:Bool;
    var useThreeCoins:Bool;
    var useBattery:Bool;
    var useDdRepel:Bool;
    var office:Int;
}
```

## Runtime

No deben regresar al selector cosas como:

```text
attack progress
timers internos
temperature
noise
power
vent positions
music box
secret actor runtime state
```

Solo el roster/configuración y progreso persistente relevante.

---

# 23. Arquitectura Haxe sugerida

```text
UcnGameData
├── UcnSave
├── NightSetup
└── NightSession
```

```haxe
class CharacterSelectState extends FlxState {
    var roster:Array<CharacterConfig>;
    var save:UcnSave;
    var setup:NightSetup;

    override function create() {
        loadSave();
        buildCards();
        refreshScore();
        refreshUnlocks();
        refreshTrophy();
    }
}
```

Score reactivo:

```haxe
function calculateScore():Int {
    var result = 0;

    for (character in roster)
        result += character.ai * 10;

    return result;
}
```

---

# 24. Challenges como datos

En vez de hardcodear cientos de acciones Clickteam:

```json
{
  "name": "Bears Attack 1",
  "characters": {
    "freddy": 10,
    "goldenFreddy": 1,
    "phantomFreddy": 1,
    "nightmareFredbear": 10,
    "nightmare": 10,
    "helpy": 1,
    "neddBear": 1,
    "rockstarFreddy": 5,
    "moltenFreddy": 1,
    "lefty": 1
  }
}
```

Esto hace que challenges/mods sean data-driven.

---

# 25. NightConfig que pasa a Frame 2

```haxe
typedef NightConfig = {
    var ai:Array<Int>;
    var office:OfficeId;
    var frigid:Bool;
    var threeCoins:Bool;
    var battery:Bool;
    var ddRepel:Bool;
    var challenge:Null<Int>;
    var visualEffects:Bool;
}
```

Al pulsar GO:

```haxe
NightSession.begin(buildNightConfig());
FlxG.switchState(() -> new PlayState());
```

---

# 26. Dee Dee runtime y write-back

```haxe
class NightSession {
    public var initialAI:Array<Int>;
    public var runtimeAI:Array<Int>;
}
```

Inicio:

```haxe
runtimeAI = config.ai.copy();
```

Dee Dee:

```haxe
runtimeAI[target] = newLevel;
```

Retorno al menú si buscas fidelidad al original:

```haxe
for (i in 0...50)
    selectorRoster[i].ai = runtimeAI[i];
```

Los seis secretos no se copian porque no tienen slot.

---

# 27. Qué buscar ahora en el MFA de Frame 1

## A. `cscharX.Value D`

Busca:

```text
Value D + 1
Value D - 1
Value D = 20
Value D = 0
```

Si coincide con clicks de la card, confirmamos definitivamente `Value D = AI`.

## B. Score

Busca una suma de todos los `Value D` y `* 10`. Es posible que Clickteam tenga una expresión gigantesca.

## C. Set All

Probablemente verás una fila con decenas de acciones:

```text
cschar1.D = 20
cschar2.D = 20
...
```

En Haxe será un loop.

## D. Challenges

Un challenge debería mostrar una lluvia de `Set Value D`. Compara uno con las tablas anteriores para identificar exactamente qué `cschar` corresponde a qué personaje.

## E. Office popup

Busca thresholds:

```text
2000
5000
8000
```

## F. Trophy

Busca:

```text
8000
9000
```

y una condición especial de 50/20 / best time / completion.

## G. Power-Ups / INI

Busca strings:

```text
i1
i2
i3
i4
```

y separa stock vs checkbox seleccionado.

## H. Start of Frame

Aquí probablemente se hace:

```text
read INI
refresh high score
enable offices
show trophy
show challenge stars
restore power-up counts
```

---

# 28. Mapa mental final de Frame 1

```text
FRAME 1
│
├── RosterController
│   ├── 50 Character Cards
│   ├── AI +/-
│   ├── Set All
│   └── Score
│
├── ChallengeController
│   ├── 16 presets
│   └── 16 completion stars
│
├── PowerUpController
│   ├── Frigid
│   ├── 3 Coins
│   ├── Battery
│   └── DD Repel
│
├── OfficeController
│   ├── Default
│   ├── SL @ 2000
│   ├── FNaF3 @ 5000
│   └── FNaF4 @ 8000
│
├── ProgressController
│   ├── High Score
│   ├── Best 50/20 Time
│   ├── Intermissions
│   └── Trophy
│
├── Settings
│   ├── Character Info
│   └── Visual Effects
│
└── GO
    └── NightConfig -> Frame 2
```

---

# 29. Fuentes consultadas

## Oficiales / primarias

- Steam — Ultimate Custom Night  
  https://store.steampowered.com/app/871720/Ultimate_Custom_Night/

- GameJolt oficial de Scott Cawthon  
  https://gamejolt.com/games/UltimateCN/349545

- Steam Community announcements / Patch 1.032  
  Confirma estatuas de bronce a 8000+, plata a 9000+ y oro al completar 50/20.

## Comunidad / reverse engineering

- Five Nights at Freddy's Wiki — UCN  
  https://freddy-fazbears-pizza.fandom.com/wiki/Ultimate_Custom_Night

- UCN Wiki — Character Selection / Power-Ups  
  https://fnaf-ucn.fandom.com/wiki/Ultimate_Custom_Night

- Dee Dee — The Ultimate Custom Night Wiki  
  https://the-fnaf-ultimate-custom-night.fandom.com/wiki/Dee-Dee

- Steam Community — UCN Preset Challenges  
  https://steamcommunity.com/app/871720/discussions/0/1726450077641029989/

- Steam Community — MMFApplication save fields  
  https://steamcommunity.com/app/871720/discussions/0/1726450077654167840/

- PCGamingWiki — save location  
  https://www.pcgamingwiki.com/wiki/Ultimate_Custom_Night

---

# 30. Conclusión

El `Frame 1` no es solo una UI. Es el **constructor de la configuración completa de la noche y el dashboard del progreso persistente**.

La pista más fuerte para tu MFA sigue siendo:

```text
cscharX.Value D ≈ AI level
```

y el detalle de Dee Dee es buenísimo para reverse engineering:

```text
Dee Dee modifica un personaje normal en Frame 2
       ↓
muere/termina la noche
       ↓
Frame 1 vuelve
       ↓
el card aparece con el AI modificado
```

Eso sugiere que el selector y gameplay comparten —directa o indirectamente— el mismo estado de AI de los `cschar`.

En Haxe, la traducción limpia sería:

```text
CharacterDefinition[50]
CharacterConfig[50]
NightConfig
NightSession
SaveData
```

y no 50 sprites usados como mini-bases de datos llenas de `Alterable Value A/B/C/D` 😭.
