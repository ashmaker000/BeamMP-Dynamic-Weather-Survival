# Dynamic Weather Survival

Dynamic Weather Survival is a command-driven BeamNG.drive and BeamMP weather system. It provides dynamic rain, snow, fog, cloud cover, temperature, brightness, water levels, slippery roads, vehicle wind, forest wind, hail, lightning, EMP effects, and destructive survival events without an in-game UI app.

## Source layout

The mod root is the canonical client source:

```text
AshWeather/
|-- art/
|-- lua/
|-- scripts/
|-- settings/
|-- README.md
`-- BeamMPResources/
    |-- build-client-resource.ps1
    |-- Client/
    |   `-- DynamicWeatherSurvivalClient.zip
    `-- Server/
        `-- AshSurvival/
            `-- main.lua
```

Do not edit files inside the generated client ZIP. Edit the root client files, then rebuild the resource.

## Weather profiles

The client provides Clear Break, Dense Overcast, Morning Fog, Cold Drizzle, Heavy Rain, Heavy Snow, Thunderstorm, Hail Core, and Heavy Storm profiles.

Profiles control precipitation type and amount, cloud cover, fog, temperature, brightness, road grip, water rise, wind, windbursts, duration, and selection weight. Runtime values transition gradually between profiles.

BeamNG 0.39 profile cloud coverage uses the native volumetric range rather than the old normalized `0..1` range. Dynamic Weather Survival supplies its native presets through `art/weather/ashweather.json`.

## Dynamic environment

- BeamNG 0.39 volumetric cloud and fog transitions use `core_weather.switchWeather()` with mod-owned presets.
- `core_environment.setState()` continues to coordinate time, cloud motion, fog fallback, and physics ground wind.
- Physics ground wind is applied through `core_environment.setGroundWind()`. Safety-limited vehicle-local `obj:setWind()` updates make the active vehicle feel phase wind after spawn/reset.
- Rain accumulation raises existing `WaterPlane` and `WaterBlock` objects progressively. Server-wide rainfall controls the rise, while dry weather drains water back to its original map height.
- Rain changes compatible terrain asphalt to wet grip.
- Road materials darken and become progressively more reflective as rain accumulates, then dry gradually after rain stops.
- Visual road wetness is capped at 24 likely road materials and applies one material reload per frame to limit transition stutter.
- Snow and hail use icy grip.
- Original terrain ground models are restored when conditions clear or the extension stops.
- Localized microburst wind retains speed and mass safety scaling.
- A `ForestWindEmitter` drives supported trees and groundcover.
- Wind direction, gust strength, and windburst frequency change with the active profile.
- BeamMP phases apply weather server-wide so all players experience the same phase. Synchronized event coordinates keep lightning, hail, and windburst events consistent between clients.
- Standing water can produce speed, tyre-contact, and vehicle-mass-scaled aquaplaning without permanently changing tyre configuration.
- Severe wind uses a capped pool of recycled debris objects to limit frame-time impact.
- Precipitation, native volumetric clouds, fog, temperature, and brightness transition dynamically.
- The level's initial 0.39 environment state is restored when Dynamic Weather Survival stops or unloads.

## Single-player

The unpacked mod runs directly from this folder. The extension loads through `scripts/ash_weather/modScript.lua`.

Single-player actions are available under `Options > Controls > Gameplay`, including activation, deactivation, preset cycling, random weather, storms, lightning, and environment reset.

Open the BeamNG console, select `GE - Lua`, and load the extension if it is not already available:

```lua
extensions.load("ashWeatherMain")
```

Common single-player console commands:

```lua
extensions.ashWeatherMain.handleBeamMpWeatherCommand("activate")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("deactivate")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("clear")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("overcast")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("drizzle")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("rain")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("snow")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("storm")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("supercell")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("hail")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("microburst")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("lightning;lightningStrikeCount=1")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("barrage;lightningStrikeCount=4")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("windburst")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("random")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("cycle")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("dynamic_on")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("dynamic_off")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("reset")
```

Single-player damage and targeted test examples:

```lua
extensions.ashWeatherMain.handleBeamMpWeatherCommand("settings;vehicleDamageEnabled=true;destructiveWeatherEnabled=true;lightningExplosionsEnabled=false")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("lightning;lightningStrikeCount=1;lightningForceVehicleTarget=true;lightningVehicleHitChance=1")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("hail;hailStoneCount=300;hailDamageChance=0.84;hailRadius=155;vehicleDamageEnabled=true")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("test_emp;empTier=2")
extensions.ashWeatherMain.handleBeamMpWeatherCommand("reset_damage")
```

## BeamMP installation

Build the command-only client resource from the canonical root source:

```powershell
.\BeamMPResources\build-client-resource.ps1
```

Install:

1. Copy `BeamMPResources/Client/DynamicWeatherSurvivalClient.zip` to the server's `Resources/Client` directory.
2. Copy `BeamMPResources/Server/AshSurvival` to the server's `Resources/Server` directory.
3. Restart the BeamMP server.

The generated BeamMP client excludes single-player input actions and contains no UI app.

## BeamMP commands

Player chat commands use `/survival`. `help`, `status`, and `clients` are available to all players. The remaining commands require an administrator when the server `admins` table is populated.

Core and phase commands:

```text
/survival help
/survival start
/survival stop
/survival status
/survival clients
/survival phase calm|drizzle|rain|snow|snowextreme|storm|hail|severe|extreme|eye|cataclysm
/survival setphase <phase>
```

Weather event commands:

```text
/survival hail small|medium|large|apocalyptic
/survival hail [stones] [chance%] [radius]
/survival microburst
/survival lightning
/survival lightning 3 80 self player
/survival lightning 1 80 self vehicle
/survival barrage
```

Runtime configuration commands:

```text
/survival cfg hail stones N chance P radius M progression on|off
/survival cfg wind speed N bursts on|off heavy on|off
/survival cfg wind speed default
/survival cfg features shelter on|off flood on|off aquaplaning on|off debris on|off aftermath on|off tyre P fire P
/survival cfg aftermath shelter on|off flood on|off aquaplaning on|off debris on|off aftermath on|off tyre P fire P
/survival cfg lightning count N radius M player P vehicle P direct M splash M emp P destroy P none P forcevehicle on|off scope self|all explosions on|off
/survival cfg cell enabled on|off radius M fade M speed MPS
/survival damage on|off
/survival destructive on|off
/survival heavy on|off
```

Testing and administration commands:

```text
/survival test lightning PlayerName
/survival test emp PlayerName 1|2|3
/survival test hail PlayerName small|medium|large|apocalyptic
/survival resetdamage PlayerName
/survival down PlayerName
/survival revive PlayerName
/survival ping
/survival debug on|off
```

`/survival hailcfg ...` and `/survival lightningcfg ...` remain supported as shorter aliases for their corresponding `cfg` commands. `/survival storm` and `/survival supercell` are also direct phase aliases. Common misspellings `lighting` and `lightnight` are accepted as lightning aliases.

Server console commands use the same subcommands with the `ashsurvival` prefix and no leading slash:

```text
ashsurvival start
ashsurvival phase severe
ashsurvival lightning 3 80 all player
ashsurvival stop
```

When the `admins` table in `BeamMPResources/Server/AshSurvival/main.lua` is empty, every player can control survival. Add exact player names to restrict control commands.

## Survival phases

The automatic server-wide sequence is Calm, Rain, Storm, Hail Core, Severe, Last Stand, Eye of the Storm, and Cataclysm. Most phases last five minutes; Eye of the Storm lasts one minute. Manually selected phases continue through the normal timeline and are not locked indefinitely.

Drizzle uses light rain and never generates automatic lightning. Rain checks for one synchronized lightning strike every 30 seconds with a 12% success chance. Single-player Rain uses a 5% chance on its 12-second weather check.

Rain has a configurable 10% chance to become the rare Whiteout snow phase. `/survival phase snow` forces Whiteout manually.

`/survival phase snowextreme` starts Extreme Whiteout in the Severe timeline slot. It uses heavy snow, icy roads, severe crosswinds, and one synchronized lightning strike every 14 seconds. Hail, microbursts, heavy-storm barrages, and explosions remain disabled in that phase.

Damage, destructive weather, heavy mode, lightning, hail, wind, storm-cell, shelter, flood, aquaplaning, debris, and aftermath settings are saved by the server in `settings_runtime.lua`. Restarts, phase changes, and late joins retain them.

## Lightning

- Strikes are server-authoritative. Each event carries an ID, seed, timestamp, and selected damage recipient. Exact server coordinates are shared when available; a seeded synchronized fallback is used otherwise.
- The default random vehicle target chance is 5%.
- Direct hits can produce EMP, destruction, or no effect using configurable percentages.
- EMP effects cut engine power and disturb vehicle electrics.
- Direct-hit memory escalates repeated strikes and decays after a quiet period.
- Vehicle height and elevation increase susceptibility slightly; five overhead raycasts reduce or block risk under partial or full cover.
- EMP aftermath can discharge electric storage slightly, leave temporary electrical faults, scorch a tyre, and ignite a vehicle at configured tier-three probabilities.
- Bundled close, mid, far, and rolling thunder audio plays from the strike position.
- Lightning uses the Thor texture atlas, procedural forked geometry, impact corona, sparks, and repeated return strokes.

## Hail

Hail presets control stone count, hit chance, and radius. Server hail events carry an ID, seed, timestamp, and event coordinate when available. Hail ramps from small/light to peak intensity and then decays. Five-point overhead exposure reduces impacts under partial cover, while each accepted stone damages its selected body area. Hail does not intentionally use whole-vehicle explosion logic.

`/survival resetdamage PlayerName` clears Dynamic Weather Survival strike memory and temporary EMP/wind/electrical effects. It does not repair existing BeamNG body deformation.

## Configuration

Edit:

- `settings/ashWeather/profiles.json` for profile appearance, timing, wind, water, grip, precipitation, `roadWetRoughness`, and weights.
- `settings/ashWeather/levels.json` for per-map profile order, weights, rain object names, lightning-reactive objects, and transition timing.
- `BeamMPResources/Server/AshSurvival/main.lua` for survival phases, rare snow chance, hail defaults, lightning defaults, and administrators.

If external JSON configuration is missing or invalid, the client uses built-in defaults.

## Validation

Before deployment:

1. Run `luac -p lua/ge/extensions/ashWeatherMain.lua`.
2. Run `luac -p BeamMPResources/Server/AshSurvival/main.lua`.
3. Parse both files under `settings/ashWeather` as JSON.
4. Run `BeamMPResources/build-client-resource.ps1`.
5. Confirm the ZIP contains `lua`, `scripts`, `settings`, `art`, and `README.md`, with no UI or input-action directories.
6. Test phase synchronization with at least two BeamMP clients, including one late join.

## Runtime limitations

- Dynamic water requires map `WaterPlane` or `WaterBlock` objects.
- Dynamic road grip requires compatible `TerrainBlock` asphalt materials.
- Visual road wetness requires identifiable `DecalRoad`, `MeshRoad`, or road-named material objects. Unsupported maps retain physical wet grip without the reflective material effect.
- Forest and groundcover movement depends on the active map objects supporting physics ground wind or `ForestWindEmitter`.
- Map-specific object names can be added through `settings/ashWeather/levels.json`.
