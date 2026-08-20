local PLUGIN_NAME = "AshSurvival"
local BUILD_ID = "2026-08-20-dws1"
local CLIENT_EVENT = "AshSurvivalWeatherCommand"
local lightningConfigLine
local hailConfigLine
local phaseListLine
local lightningSeedCounter = 0
local eventCounter = 0

local scriptSource = debug.getinfo(1, "S").source or ""
local scriptPath = tostring(scriptSource):gsub("^@", "")
local scriptDir = scriptPath:match("^(.*[\\/])") or ""
local SETTINGS_FILE = scriptDir .. "settings_runtime.lua"

local config = {
  command = "/survival",
  consoleCommand = "ashsurvival",
  admins = {},
  tickMs = 1000,
  phaseLengthSeconds = 300,
  allowAllWhenNoAdmins = true,
  lightning = {
    count = 1,
    radius = 50,
    playerChance = 0,
    vehicleChance = 5,
    directRadius = 2,
    splashRadius = 4,
    empChance = 55,
    destroyChance = 15,
    noEffectChance = 30,
    forceVehicle = false,
    scope = "all",
    explosions = false
  },
  hail = {
    stones = 18,
    chance = 42,
    radius = 85,
    progression = true
  },
  wind = {
    bursts = true,
    heavy = false,
    speedOverride = nil
  },
  stormCell = {
    enabled = true,
    localizedWeather = false,
    radius = 460,
    edgeFade = 180,
    driftSpeed = 8,
    broadcastSeconds = 2
  },
  features = {
    shelter = true,
    localizedFlooding = true,
    aquaplaning = true,
    debris = true,
    lightningAftermath = true
  },
  aftermath = {
    tyreChance = 12,
    fireChance = 8
  },
  rareSnowChancePercent = 10,
  snowPhase = {
    name = "Whiteout",
    command = "snow;vehicleDamageEnabled=false;destructiveWeatherEnabled=false;hailEnabled=false;microburstEnabled=false;heavyStormMode=false;serverAutoLightning=false;autoLightningEnabled=false;windBurstsEnabled=true;weatherWindSpeed=2.40",
    announce = "A rare cold front has turned the rain to heavy snow. Roads are icing over."
  },
  snowExtremePhase = {
    name = "Extreme Whiteout",
    command = "snow;vehicleDamageEnabled=true;damageTier=realistic;destructiveWeatherEnabled=false;hailEnabled=false;microburstEnabled=false;heavyStormMode=false;serverAutoLightning=true;autoLightningEnabled=false;autoLightningInterval=14;autoLightningStrikeCount=1;windBurstsEnabled=true;weatherWindSpeed=10.25",
    announce = "Extreme thundersnow has engulfed the map. Lightning is active but remains isolated."
  },
  drizzlePhase = {
    name = "Drizzle",
    command = "drizzle;vehicleDamageEnabled=false;destructiveWeatherEnabled=false;hailEnabled=false;microburstEnabled=false;heavyStormMode=false;serverAutoLightning=false;autoLightningEnabled=false;windBurstsEnabled=true;weatherWindSpeed=0.80",
    announce = "Light drizzle is moving across the map. Lightning is not expected."
  },
  phases = {
    {
      name = "Calm",
      command = "clear;vehicleDamageEnabled=false;heavyStormMode=false;serverAutoLightning=false;autoLightningEnabled=false;hailEnabled=false;microburstEnabled=false;windBurstsEnabled=false;weatherWindSpeed=0",
      announce = "Survival weather online. The storm is building."
    },
    {
      name = "Rain",
      command = "rain;vehicleDamageEnabled=false;heavyStormMode=false;serverAutoLightning=true;autoLightningEnabled=false;autoLightningInterval=30;autoLightningChance=12;autoLightningStrikeCount=1;windBurstsEnabled=true;weatherWindSpeed=1.60",
      announce = "Rain bands are moving in. An isolated lightning strike is possible."
    },
    {
      name = "Storm",
      command = "storm;vehicleDamageEnabled=true;damageTier=realistic;heavyStormMode=false;serverAutoLightning=true;autoLightningEnabled=false;autoLightningInterval=12;autoLightningStrikeCount=1;windBurstsEnabled=true;weatherWindSpeed=3.25",
      announce = "The storm is live. Vehicle damage is enabled."
    },
    {
      name = "Hail Core",
      command = "hail;vehicleDamageEnabled=true;damageTier=realistic;destructiveWeatherEnabled=true;hailEnabled=true;microburstEnabled=true;heavyStormMode=false;serverAutoLightning=true;autoLightningEnabled=false;autoLightningInterval=10;autoLightningStrikeCount=1;windBurstsEnabled=true;weatherWindSpeed=6.65;hailStoneCount=90;hailDamageChance=0.92;hailRadius=165;hailDamageInterval=0.65",
      announce = "Large hail is crossing the map."
    },
    {
      name = "Severe",
      command = "supercell;vehicleDamageEnabled=true;damageTier=cinematic;destructiveWeatherEnabled=true;hailEnabled=true;microburstEnabled=true;heavyStormMode=true;heavyStormInterval=4;serverAutoLightning=true;autoLightningEnabled=false;autoLightningInterval=8;autoLightningStrikeCount=2;windBurstsEnabled=true;weatherWindSpeed=10.25",
      announce = "A severe supercell has formed. Keep moving."
    },
    {
      name = "Last Stand",
      durationSeconds = 300,
      command = "supercell;vehicleDamageEnabled=true;damageTier=cinematic;destructiveWeatherEnabled=true;hailEnabled=true;microburstEnabled=true;heavyStormMode=true;heavyStormInterval=2;serverAutoLightning=true;autoLightningEnabled=false;autoLightningInterval=6;autoLightningStrikeCount=3;windBurstsEnabled=true;weatherWindSpeed=15.30",
      announce = "Last stand. Lightning and hail frequency are maxed."
    },
    {
      name = "Eye of the Storm",
      durationSeconds = 60,
      command = "overcast;vehicleDamageEnabled=true;damageTier=realistic;destructiveWeatherEnabled=true;hailEnabled=false;microburstEnabled=false;heavyStormMode=false;serverAutoLightning=false;autoLightningEnabled=false;windBurstsEnabled=true;weatherWindSpeed=0.70",
      announce = "The eye is overhead. This calm will not last."
    },
    {
      name = "Cataclysm",
      command = "supercell;vehicleDamageEnabled=true;damageTier=cinematic;destructiveWeatherEnabled=true;hailEnabled=true;microburstEnabled=true;heavyStormMode=true;heavyStormInterval=1.5;serverAutoLightning=true;autoLightningEnabled=false;autoLightningInterval=5;autoLightningStrikeCount=3;windBurstsEnabled=true;weatherWindSpeed=18.50",
      announce = "The back wall has arrived. Conditions are catastrophic."
    }
  }
}

local hailPresets = {
  small = { stones = 52, chance = 34, radius = 80 },
  medium = { stones = 102, chance = 62, radius = 115 },
  large = { stones = 300, chance = 84, radius = 155 },
  apocalyptic = { stones = 1020, chance = 100, radius = 220 }
}

local phaseAliases = {
  calm = 1,
  start = 1,
  rain = 2,
  rainy = 2,
  storm = 3,
  stormy = 3,
  hail = 4,
  hailcore = 4,
  severe = 5,
  supercell = 5,
  extreme = 6,
  laststand = 6,
  last = 6,
  eye = 7,
  cataclysm = 8,
  catastrophic = 8
}

local state = {
  running = false,
  startedAt = 0,
  elapsed = 0,
  phaseIndex = 0,
  players = {},
  lastCommand = nil,
  debug = false,
  vehicleDamageOverride = nil,
  destructiveWeatherOverride = nil,
  heavyStormOverride = nil,
  lastAutoLightningAt = 0,
  lastAutoWindburstAt = 0,
  lastAutoHailAt = 0,
  lastStormCellBroadcastAt = 0,
  phaseOverride = nil,
  stormCell = nil
}

local function copyTable(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, entry in pairs(value) do
    result[key] = copyTable(entry)
  end
  return result
end

local function serializeLua(value, indent)
  indent = indent or ""
  if type(value) == "number" or type(value) == "boolean" then
    return tostring(value)
  elseif type(value) == "string" then
    return string.format("%q", value)
  elseif type(value) == "table" then
    local nextIndent = indent .. "  "
    local parts = { "{\n" }
    for key, entry in pairs(value) do
      local encodedKey = type(key) == "string" and key:match("^[%a_][%w_]*$") and key or ("[" .. serializeLua(key, nextIndent) .. "]")
      parts[#parts + 1] = nextIndent .. encodedKey .. " = " .. serializeLua(entry, nextIndent) .. ",\n"
    end
    parts[#parts + 1] = indent .. "}"
    return table.concat(parts)
  end
  return "nil"
end

local function persistedSettingsSnapshot()
  return {
    lightning = copyTable(config.lightning),
    hail = copyTable(config.hail),
    wind = copyTable(config.wind),
    stormCell = copyTable(config.stormCell),
    features = copyTable(config.features),
    aftermath = copyTable(config.aftermath),
    vehicleDamageOverride = state.vehicleDamageOverride,
    destructiveWeatherOverride = state.destructiveWeatherOverride,
    heavyStormOverride = state.heavyStormOverride
  }
end

local function savePersistentSettings()
  local file, err = io.open(SETTINGS_FILE, "w")
  if not file then
    print(PLUGIN_NAME .. " unable to save settings: " .. tostring(err))
    return false
  end
  file:write("return ")
  file:write(serializeLua(persistedSettingsSnapshot()))
  file:write("\n")
  file:close()
  return true
end

local function mergeKnownSettings(target, source)
  if type(target) ~= "table" or type(source) ~= "table" then return end
  for key, current in pairs(target) do
    local incoming = source[key]
    if incoming ~= nil and type(incoming) == type(current) then
      target[key] = incoming
    end
  end
end

local function loadPersistentSettings()
  local chunk = loadfile(SETTINGS_FILE)
  if not chunk then return false end
  local ok, data = pcall(chunk)
  if not ok or type(data) ~= "table" then
    print(PLUGIN_NAME .. " ignored invalid persisted settings")
    return false
  end
  mergeKnownSettings(config.lightning, data.lightning)
  mergeKnownSettings(config.hail, data.hail)
  mergeKnownSettings(config.wind, data.wind)
  if type(data.wind) == "table" and type(data.wind.speedOverride) == "number" then
    config.wind.speedOverride = data.wind.speedOverride
  end
  mergeKnownSettings(config.stormCell, data.stormCell)
  mergeKnownSettings(config.features, data.features)
  mergeKnownSettings(config.aftermath, data.aftermath)
  if type(data.vehicleDamageOverride) == "boolean" then state.vehicleDamageOverride = data.vehicleDamageOverride end
  if type(data.destructiveWeatherOverride) == "boolean" then state.destructiveWeatherOverride = data.destructiveWeatherOverride end
  if type(data.heavyStormOverride) == "boolean" then state.heavyStormOverride = data.heavyStormOverride end

  config.lightning.count = math.max(1, math.min(20, math.floor(tonumber(config.lightning.count) or 1)))
  config.lightning.radius = math.max(1, math.min(500, tonumber(config.lightning.radius) or 50))
  config.lightning.vehicleChance = math.max(0, math.min(100, tonumber(config.lightning.vehicleChance) or 5))
  config.lightning.playerChance = math.max(0, math.min(100, tonumber(config.lightning.playerChance) or 0))
  config.hail.stones = math.max(1, math.min(1020, math.floor(tonumber(config.hail.stones) or 18)))
  config.hail.chance = math.max(0, math.min(100, tonumber(config.hail.chance) or 42))
  config.hail.radius = math.max(5, math.min(300, tonumber(config.hail.radius) or 85))
  config.stormCell.radius = math.max(80, math.min(5000, tonumber(config.stormCell.radius) or 460))
  config.stormCell.edgeFade = math.max(20, math.min(config.stormCell.radius, tonumber(config.stormCell.edgeFade) or 180))
  config.stormCell.driftSpeed = math.max(0, math.min(100, tonumber(config.stormCell.driftSpeed) or 8))
  return true
end

local function nowSeconds()
  return os.time()
end

local function chat(target, message)
  MP.SendChatMessage(target, "[Dynamic Weather Survival] " .. message)
end

local function isAdmin(playerName)
  if playerName == "console" then
    return true
  end
  if config.allowAllWhenNoAdmins and next(config.admins) == nil then
    return true
  end
  return config.admins[playerName] == true
end

local function splitWords(value)
  local words = {}
  for word in tostring(value or ""):gmatch("%S+") do
    words[#words + 1] = word
  end
  return words
end

local function joinWords(args, startIndex, endIndex)
  local parts = {}
  for index = startIndex, endIndex or #args do
    if args[index] ~= nil then parts[#parts + 1] = tostring(args[index]) end
  end
  return table.concat(parts, " ")
end

local function sendClientCommand(playerId, command)
  state.lastCommand = command
  local ok, err = MP.TriggerClientEvent(playerId, CLIENT_EVENT, command)
  if ok == false then
    print(PLUGIN_NAME .. " failed to send client command '" .. tostring(command) .. "': " .. tostring(err))
  elseif state.debug then
    print(PLUGIN_NAME .. " sent client command to " .. tostring(playerId) .. ": " .. tostring(command))
  end
  return ok ~= false
end

local function broadcastClientCommand(command)
  sendClientCommand(-1, command)
end

local function boolText(value)
  return value and "true" or "false"
end

local function percentToChance(value)
  return math.max(0, math.min(100, tonumber(value) or 0)) / 100
end

local function nextLightningSeed()
  lightningSeedCounter = (lightningSeedCounter + 1) % 100000
  return (nowSeconds() * 1000 + lightningSeedCounter) % 2147483647
end

local function nextEventId(prefix)
  eventCounter = (eventCounter + 1) % 1000000
  return string.format("%s-%d-%d", tostring(prefix or "weather"), nowSeconds(), eventCounter)
end

local function connectedPlayers()
  local players = {}
  if not MP.GetPlayers then return players end
  for id, name in pairs(MP.GetPlayers() or {}) do
    local connected = not MP.IsPlayerConnected or MP.IsPlayerConnected(id)
    if connected then
      local x, y, z
      if MP.GetPlayerVehicles and MP.GetPositionRaw then
        for vehicleId in pairs(MP.GetPlayerVehicles(id) or {}) do
          local raw, err = MP.GetPositionRaw(id, vehicleId)
          local pos = type(raw) == "table" and raw.pos or nil
          if (err == nil or err == "") and type(pos) == "table" then
            x, y, z = tonumber(pos[1]), tonumber(pos[2]), tonumber(pos[3])
            if x and y and z then break end
          end
        end
      elseif MP.GetPlayerPosition then
        local raw = MP.GetPlayerPosition(id)
        local sx, sy, sz = tostring(raw or ""):match("^%s*([^,%s]+)[,%s]+([^,%s]+)[,%s]+([^,%s]+)%s*$")
        x, y, z = tonumber(sx), tonumber(sy), tonumber(sz)
      end
      if x and y and z then
        players[#players + 1] = { id = id, name = tostring(name or id), x = x, y = y, z = z }
      end
    end
  end
  return players
end

local function ensureStormCell()
  if not config.stormCell.enabled then
    state.stormCell = nil
    return nil
  end
  if not state.stormCell then
    local players = connectedPlayers()
    if #players == 0 then return nil end
    local anchor = players[math.random(1, #players)]
    local angle = math.random() * math.pi * 2
    local speed = math.max(0, tonumber(config.stormCell.driftSpeed) or 8)
    state.stormCell = {
      id = nextEventId("cell"),
      x = anchor.x + math.cos(angle) * 240,
      y = anchor.y + math.sin(angle) * 240,
      z = anchor.z,
      vx = math.cos(angle + math.pi * 0.35) * speed,
      vy = math.sin(angle + math.pi * 0.35) * speed,
      radius = math.max(80, tonumber(config.stormCell.radius) or 460),
      edgeFade = math.max(20, tonumber(config.stormCell.edgeFade) or 180),
      intensity = 1
    }
  end
  return state.stormCell
end

local function stormCellPayload(active)
  local cell = active and ensureStormCell() or state.stormCell
  if not cell then
    return "stormcell;cellActive=false;eventId=" .. nextEventId("cell-off") .. ";eventTimestamp=" .. tostring(nowSeconds())
  end
  return table.concat({
    "stormcell",
    "cellActive=" .. boolText(active == true),
    "eventId=" .. tostring(cell.id),
    "eventTimestamp=" .. tostring(nowSeconds()),
    "cellX=" .. tostring(cell.x),
    "cellY=" .. tostring(cell.y),
    "cellZ=" .. tostring(cell.z),
    "cellVx=" .. tostring(cell.vx),
    "cellVy=" .. tostring(cell.vy),
    "cellRadius=" .. tostring(cell.radius),
    "cellEdgeFade=" .. tostring(cell.edgeFade),
    "cellIntensity=" .. tostring(cell.intensity)
  }, ";")
end

local function broadcastStormCell(active, target)
  local payload = stormCellPayload(active)
  if target ~= nil then
    sendClientCommand(target, payload)
  else
    broadcastClientCommand(payload)
  end
end

local function appendPersistentSettings(command)
  local parts = { tostring(command or "") }
  parts[#parts + 1] = "ashWeatherServerBuild=" .. BUILD_ID
  if state.vehicleDamageOverride ~= nil then
    parts[#parts + 1] = "vehicleDamageEnabled=" .. boolText(state.vehicleDamageOverride)
  end
  if state.destructiveWeatherOverride ~= nil then
    parts[#parts + 1] = "destructiveWeatherEnabled=" .. boolText(state.destructiveWeatherOverride)
  end
  if state.heavyStormOverride ~= nil then
    parts[#parts + 1] = "heavyStormMode=" .. boolText(state.heavyStormOverride)
  end
  parts[#parts + 1] = "lightningVehicleHitChance=" .. tostring(percentToChance(config.lightning.vehicleChance))
  parts[#parts + 1] = "lightningEmpEffectChance=" .. tostring(percentToChance(config.lightning.empChance))
  parts[#parts + 1] = "lightningDestroyChance=" .. tostring(percentToChance(config.lightning.destroyChance))
  parts[#parts + 1] = "lightningNoEffectChance=" .. tostring(percentToChance(config.lightning.noEffectChance))
  if not tostring(command or ""):match("^lightning[;_]?") then
    parts[#parts + 1] = "lightningForceVehicleTarget=" .. boolText(config.lightning.forceVehicle)
  end
  parts[#parts + 1] = "lightningExplosionsEnabled=" .. boolText(config.lightning.explosions)
  parts[#parts + 1] = "hailStoneCount=" .. tostring(config.hail.stones)
  parts[#parts + 1] = "hailDamageChance=" .. tostring(percentToChance(config.hail.chance))
  parts[#parts + 1] = "hailRadius=" .. tostring(config.hail.radius)
  parts[#parts + 1] = "hailProgressionEnabled=" .. boolText(config.hail.progression)
  parts[#parts + 1] = "windBurstsEnabled=" .. boolText(config.wind.bursts)
  if config.wind.speedOverride ~= nil then
    parts[#parts + 1] = "weatherWindSpeed=" .. tostring(config.wind.speedOverride)
  end
  parts[#parts + 1] = "shelterDetectionEnabled=" .. boolText(config.features.shelter)
  parts[#parts + 1] = "localizedFloodingEnabled=" .. boolText(config.features.localizedFlooding)
  parts[#parts + 1] = "aquaplaningEnabled=" .. boolText(config.features.aquaplaning)
  parts[#parts + 1] = "windDebrisEnabled=" .. boolText(config.features.debris)
  parts[#parts + 1] = "lightningAftermathEnabled=" .. boolText(config.features.lightningAftermath)
  parts[#parts + 1] = "lightningTyreDamageChance=" .. tostring(percentToChance(config.aftermath.tyreChance))
  parts[#parts + 1] = "lightningFireChance=" .. tostring(percentToChance(config.aftermath.fireChance))
  return table.concat(parts, ";")
end

local function buildLightningPayload(commandName, overrides)
  overrides = overrides or {}
  local count = tonumber(overrides.count) or config.lightning.count
  local radius = tonumber(overrides.radius) or config.lightning.radius
  local playerChance = overrides.playerChance ~= nil and tonumber(overrides.playerChance) or config.lightning.playerChance
  local vehicleChance = overrides.vehicleChance ~= nil and tonumber(overrides.vehicleChance) or config.lightning.vehicleChance
  local directRadius = tonumber(overrides.directRadius) or config.lightning.directRadius
  local splashRadius = tonumber(overrides.splashRadius) or config.lightning.splashRadius
  local empChance = overrides.empChance ~= nil and tonumber(overrides.empChance) or config.lightning.empChance
  local destroyChance = overrides.destroyChance ~= nil and tonumber(overrides.destroyChance) or config.lightning.destroyChance
  local noEffectChance = overrides.noEffectChance ~= nil and tonumber(overrides.noEffectChance) or config.lightning.noEffectChance
  local forcePlayer = overrides.forcePlayer == true
  local forceVehicle
  if overrides.forceVehicle ~= nil then
    forceVehicle = overrides.forceVehicle == true
  else
    forceVehicle = config.lightning.forceVehicle == true
  end
  local syncSeed = tonumber(overrides.syncSeed) or nextLightningSeed()

  local parts = {
    commandName or "lightning",
    "lightningStrikeCount=" .. tostring(math.max(1, math.min(20, math.floor(count)))),
    "lightningStrikeRadius=" .. tostring(math.max(1, math.min(500, radius))),
    "lightningPlayerHitChance=" .. tostring(percentToChance(playerChance)),
    "lightningVehicleHitChance=" .. tostring(percentToChance(vehicleChance)),
    "lightningDirectDamageRadius=" .. tostring(math.max(0.1, math.min(100, directRadius))),
    "lightningSplashDamageRadius=" .. tostring(math.max(0.1, math.min(250, splashRadius))),
    "lightningEmpEffectChance=" .. tostring(percentToChance(empChance)),
    "lightningDestroyChance=" .. tostring(percentToChance(destroyChance)),
    "lightningNoEffectChance=" .. tostring(percentToChance(noEffectChance)),
    "lightningForcePlayerTarget=" .. boolText(forcePlayer),
    "lightningForceVehicleTarget=" .. boolText(forceVehicle),
    "lightningAuthoritativeVehicleTarget=" .. boolText(overrides.authoritativeVehicleTarget == true),
    "lightningVisualDirectHit=" .. boolText(overrides.visualDirectHit == true),
    "lightningSyncDelay=" .. tostring(math.max(0, tonumber(overrides.syncDelay) or 0.35)),
    "lightningExplosionsEnabled=" .. boolText(config.lightning.explosions),
    "lightningSyncSeed=" .. tostring(syncSeed),
    "eventSeed=" .. tostring(syncSeed),
    "eventId=" .. tostring(overrides.eventId or nextEventId("lightning")),
    "eventTimestamp=" .. tostring(overrides.eventTimestamp or nowSeconds()),
    "lightningIgnoreShelter=" .. boolText(overrides.ignoreShelter == true)
  }
  if tonumber(overrides.x) and tonumber(overrides.y) and tonumber(overrides.z) then
    parts[#parts + 1] = "strikeX=" .. tostring(overrides.x)
    parts[#parts + 1] = "strikeY=" .. tostring(overrides.y)
    parts[#parts + 1] = "strikeZ=" .. tostring(overrides.z)
  end
  return table.concat(parts, ";")
end

local function buildHailPayload(overrides)
  overrides = overrides or {}
  local stones = tonumber(overrides.stones) or config.hail.stones
  local chance = tonumber(overrides.chance) or config.hail.chance
  local radius = tonumber(overrides.radius) or config.hail.radius
  local cell = ensureStormCell()
  local seed = tonumber(overrides.syncSeed) or nextLightningSeed()
  return appendPersistentSettings(table.concat({
    tostring(overrides.command or "hail"),
    "vehicleDamageEnabled=true",
    "destructiveWeatherEnabled=true",
    "hailEnabled=true",
    "hailStoneCount=" .. tostring(math.max(1, math.min(1020, math.floor(stones)))),
    "hailDamageChance=" .. tostring(percentToChance(chance)),
    "hailRadius=" .. tostring(math.max(5, math.min(300, radius))),
    "hailDamageInterval=" .. tostring(stones >= 90 and 0.65 or 1.0),
    "hailDuration=" .. tostring(math.max(5, math.min(180, tonumber(overrides.duration) or 45))),
    "hailTestDamage=" .. boolText(overrides.testDamage == true),
    "hailSyncSeed=" .. tostring(seed),
    "eventSeed=" .. tostring(seed),
    "cellX=" .. tostring(cell and cell.x or 0),
    "cellY=" .. tostring(cell and cell.y or 0),
    "cellZ=" .. tostring(cell and cell.z or 0),
    "cellRadius=" .. tostring(cell and cell.radius or config.stormCell.radius),
    "eventId=" .. tostring(overrides.eventId or nextEventId("hail")),
    "eventTimestamp=" .. tostring(overrides.eventTimestamp or nowSeconds())
  }, ";"))
end

local function appendHailEventMetadata(command, duration)
  local cell = ensureStormCell()
  local seed = nextLightningSeed()
  return table.concat({
    tostring(command or "hail"),
    "hailDuration=" .. tostring(math.max(5, math.min(180, tonumber(duration) or 45))),
    "hailTestDamage=false",
    "hailSyncSeed=" .. tostring(seed),
    "eventSeed=" .. tostring(seed),
    "cellX=" .. tostring(cell and cell.x or 0),
    "cellY=" .. tostring(cell and cell.y or 0),
    "cellZ=" .. tostring(cell and cell.z or 0),
    "cellRadius=" .. tostring(cell and cell.radius or config.stormCell.radius),
    "eventId=" .. nextEventId("hail"),
    "eventTimestamp=" .. tostring(nowSeconds())
  }, ";")
end

local function applyHailPreset(name)
  local preset = hailPresets[tostring(name or ""):lower()]
  if not preset then
    return false
  end
  config.hail.stones = preset.stones
  config.hail.chance = preset.chance
  config.hail.radius = preset.radius
  return true
end

local function sendScopedCommand(playerId, scope, command)
  if scope == "self" and playerId and playerId >= 0 then
    sendClientCommand(playerId, command)
  else
    broadcastClientCommand(command)
  end
end

local function randomStormCellPoint(radiusOverride)
  local cell = ensureStormCell()
  if not cell then
    local players = connectedPlayers()
    if #players == 0 then return nil end
    local player = players[math.random(1, #players)]
    return player.x, player.y, player.z
  end
  local radius = math.min(cell.radius, math.max(1, tonumber(radiusOverride) or cell.radius))
  local angle = math.random() * math.pi * 2
  local distance = math.sqrt(math.random()) * radius
  return cell.x + math.cos(angle) * distance, cell.y + math.sin(angle) * distance, cell.z
end

local function broadcastAuthoritativeLightning(count, radius, targetPlayerId, forceVehicle, ignoreShelter, forcePlayer)
  local strikeCount = math.max(1, math.min(20, math.floor(tonumber(count) or 1)))
  for strikeIndex = 1, strikeCount do
    local players = connectedPlayers()
    local selected
    local groundTarget
    local requested
    if targetPlayerId ~= nil then
      for _, player in ipairs(players) do if player.id == targetPlayerId then requested = player break end end
      if forceVehicle then
        selected = requested
      elseif forcePlayer then
        groundTarget = requested
      elseif requested and math.random() * 100 < config.lightning.vehicleChance then
        selected = requested
      elseif requested and math.random() * 100 < config.lightning.playerChance then
        groundTarget = requested
      end
    elseif #players > 0 then
      if forceVehicle then
        selected = players[math.random(1, #players)]
      elseif forcePlayer then
        groundTarget = players[math.random(1, #players)]
      elseif math.random() * 100 < config.lightning.vehicleChance then
        selected = players[math.random(1, #players)]
      elseif math.random() * 100 < config.lightning.playerChance then
        groundTarget = players[math.random(1, #players)]
      end
    end

    local x, y, z
    local coordinateTarget = selected or groundTarget
    if coordinateTarget then x, y, z = coordinateTarget.x, coordinateTarget.y, coordinateTarget.z else x, y, z = randomStormCellPoint(radius) end
    local eventId = nextEventId("lightning")
    local syncSeed = nextLightningSeed()
    local recipients = players
    if targetPlayerId ~= nil and not forceVehicle then recipients = requested and { requested } or {} end
    local sharedPayload = {
      count = 1,
      radius = radius,
      forceVehicle = false,
      authoritativeVehicleTarget = false,
      visualDirectHit = coordinateTarget ~= nil,
      syncDelay = 0.35 + (strikeIndex - 1) * 0.35,
      ignoreShelter = false,
      x = x,
      y = y,
      z = z,
      eventId = eventId,
      eventTimestamp = nowSeconds(),
      syncSeed = syncSeed
    }
    if targetPlayerId == nil and not selected then
      broadcastClientCommand(appendPersistentSettings(buildLightningPayload("lightning", sharedPayload)))
    else
      for _, player in ipairs(recipients) do
        local isTarget = selected and player.id == selected.id
        local payload = appendPersistentSettings(buildLightningPayload("lightning", {
        count = 1,
        radius = radius,
        forceVehicle = false,
        authoritativeVehicleTarget = isTarget,
        visualDirectHit = coordinateTarget ~= nil,
        syncDelay = 0.35 + (strikeIndex - 1) * 0.35,
        ignoreShelter = ignoreShelter == true and isTarget,
        x = x,
        y = y,
        z = z,
        eventId = eventId,
        eventTimestamp = nowSeconds(),
        syncSeed = syncSeed
        }))
        sendClientCommand(player.id, payload)
      end
    end
  end
  return true
end

local function updateStormCell(dt)
  local cell = ensureStormCell()
  if not cell then return end
  cell.x = cell.x + cell.vx * dt
  cell.y = cell.y + cell.vy * dt

  local players = connectedPlayers()
  if #players > 0 then
    local nearest, nearestDistance
    for _, player in ipairs(players) do
      local dx, dy = player.x - cell.x, player.y - cell.y
      local distance = math.sqrt(dx * dx + dy * dy)
      if not nearestDistance or distance < nearestDistance then
        nearest, nearestDistance = player, distance
      end
    end
    if nearest then cell.z = nearest.z end
    if nearestDistance and nearestDistance > cell.radius * 3 then
      local angle = math.atan(nearest.y - cell.y, nearest.x - cell.x)
      local speed = math.max(0, tonumber(config.stormCell.driftSpeed) or 8)
      cell.vx = math.cos(angle) * speed
      cell.vy = math.sin(angle) * speed
    end
  end
end

local function maybeBroadcastWindburst(phase)
  if not config.wind.bursts or not phase or not phase.command or phase.command:find("windBurstsEnabled=true", 1, true) == nil then return end
  local severity = math.max(1, state.phaseIndex or 1)
  local interval = math.max(7, 42 - severity * 5)
  if nowSeconds() - (state.lastAutoWindburstAt or 0) < interval then return end
  state.lastAutoWindburstAt = nowSeconds()
  local multiplier = math.min(4.5, 1.25 + severity * 0.34 + math.random() * 0.45)
  local duration = math.min(12, 2.5 + severity * 0.65 + math.random() * 2.5)
  local cell = ensureStormCell()
  local seed = nextLightningSeed()
  broadcastClientCommand(appendPersistentSettings(table.concat({
    "windburst",
    "eventId=" .. nextEventId("windburst"),
    "eventSeed=" .. tostring(seed),
    "eventTimestamp=" .. tostring(nowSeconds()),
    "burstMultiplier=" .. tostring(multiplier),
    "burstDuration=" .. tostring(duration),
    "cellX=" .. tostring(cell and cell.x or 0),
    "cellY=" .. tostring(cell and cell.y or 0),
    "cellZ=" .. tostring(cell and cell.z or 0),
    "cellRadius=" .. tostring(cell and cell.radius or config.stormCell.radius)
  }, ";")))
end

local function maybeBroadcastHail(phase)
  if not phase or not phase.command or phase.command:find("hailEnabled=true", 1, true) == nil then return end
  local interval = state.phaseIndex >= 6 and 34 or (state.phaseIndex >= 5 and 42 or 50)
  if nowSeconds() - (state.lastAutoHailAt or 0) < interval then return end
  state.lastAutoHailAt = nowSeconds()
  broadcastClientCommand(buildHailPayload({ command = "hailburst", duration = math.max(30, interval - 6) }))
end

local function phaseDuration(index)
  local phase = config.phases[index]
  return tonumber(phase and phase.durationSeconds) or config.phaseLengthSeconds
end

local function elapsedAtPhaseStart(phaseIndex)
  local elapsed = 0
  for index = 1, math.max(1, phaseIndex) - 1 do
    elapsed = elapsed + phaseDuration(index)
  end
  return elapsed
end

local function sendPhaseWarnings(phaseIndex)
  if phaseIndex == 2 then
    chat(-1, "A rare lightning strike is possible.")
  elseif phaseIndex == 3 then
    chat(-1, "Severe gust front incoming.")
    chat(-1, "Lightning risk rising.")
  elseif phaseIndex == 4 then
    chat(-1, "Hail core overhead.")
  elseif phaseIndex == 5 then
    chat(-1, "Severe gust front incoming.")
    chat(-1, "Hail core overhead.")
  elseif phaseIndex == 6 then
    chat(-1, "Severe gust front incoming.")
    chat(-1, "Lightning risk critical.")
  elseif phaseIndex == 7 then
    chat(-1, "Eye of the storm. Use the break wisely.")
  elseif phaseIndex >= 8 then
    chat(-1, "Extreme back-wall winds incoming.")
    chat(-1, "Lightning risk critical.")
  end
end

local function getActivePhase()
  return state.phaseOverride or config.phases[state.phaseIndex]
end

local function stormCellPhaseActive()
  return state.running and config.stormCell.enabled and config.stormCell.localizedWeather == true and state.phaseIndex > 1 and state.phaseIndex ~= 7
end

local function phasePayload(phase)
  local command = phase and phase.command or "activate"
  if tostring(command):match("^hail;") then command = appendHailEventMetadata(command, 45) end
  return appendPersistentSettings(command)
end

local function setPhase(phaseIndex, phaseOverride)
  local phase = phaseOverride or config.phases[phaseIndex]
  if not phase then
    return
  end

  state.phaseIndex = phaseIndex
  state.phaseOverride = phaseOverride
  state.lastAutoLightningAt = nowSeconds()
  state.lastAutoWindburstAt = nowSeconds()
  state.lastAutoHailAt = nowSeconds()
  broadcastClientCommand(phasePayload(phase))
  local cellActive = stormCellPhaseActive()
  if cellActive then ensureStormCell() else state.stormCell = nil end
  broadcastStormCell(cellActive)
  chat(-1, phase.announce .. " Phase: " .. phase.name .. ".")
  if phaseOverride == config.snowPhase then
    chat(-1, "Whiteout conditions. Expect low visibility, crosswinds, and icy roads.")
  elseif phaseOverride == config.snowExtremePhase then
    chat(-1, "Extreme whiteout conditions. Isolated lightning and severe crosswinds are active.")
  elseif phaseOverride == config.drizzlePhase then
    -- The drizzle announcement already confirms that lightning is disabled.
  else
    sendPhaseWarnings(phaseIndex)
  end
end

local function forcePhaseByName(name)
  local key = tostring(name or ""):lower():gsub("%s+", ""):gsub("%-", "")
  if key == "snow" or key == "whiteout" then
    state.running = true
    state.elapsed = elapsedAtPhaseStart(2)
    state.startedAt = nowSeconds() - state.elapsed
    setPhase(2, config.snowPhase)
    return true
  end
  if key == "snowextreme" or key == "extremesnow" or key == "blizzard" or key == "thundersnow" then
    state.running = true
    state.elapsed = elapsedAtPhaseStart(5)
    state.startedAt = nowSeconds() - state.elapsed
    setPhase(5, config.snowExtremePhase)
    return true
  end
  if key == "drizzle" then
    state.running = true
    state.elapsed = elapsedAtPhaseStart(2)
    state.startedAt = nowSeconds() - state.elapsed
    setPhase(2, config.drizzlePhase)
    return true
  end
  local phaseIndex = tonumber(name) or phaseAliases[key]
  if not phaseIndex or not config.phases[phaseIndex] then
    return false
  end

  state.running = true
  state.elapsed = elapsedAtPhaseStart(phaseIndex)
  state.startedAt = nowSeconds() - state.elapsed
  setPhase(phaseIndex)
  return true
end

local function currentPhaseIndex()
  if not state.running then
    return 0
  end
  local accumulated = 0
  for index, _ in ipairs(config.phases) do
    accumulated = accumulated + phaseDuration(index)
    if state.elapsed < accumulated then
      return index
    end
  end
  return #config.phases
end

local function countAlivePlayers()
  local count = 0
  for _, player in pairs(state.players) do
    if player.alive then
      count = count + 1
    end
  end
  return count
end

local function statusLine()
  if not state.running then
    return "Stopped. Use /survival start."
  end

  local phase = getActivePhase()
  local damageText = state.vehicleDamageOverride == nil and "phase" or (state.vehicleDamageOverride and "on" or "off")
  local destructiveText = state.destructiveWeatherOverride == nil and "phase" or (state.destructiveWeatherOverride and "on" or "off")
  return string.format(
    "Running for %ds. Phase: %s. Alive players: %d. Damage: %s. Destructive: %s. %s. %s.",
    state.elapsed,
    phase and phase.name or "Unknown",
    countAlivePlayers(),
    damageText,
    destructiveText,
    lightningConfigLine(),
    hailConfigLine()
  )
end

local function sendHelp(playerId)
  chat(playerId, "/survival start|stop|status|help | phase calm|rain|snow|snowextreme|storm|hail|severe|extreme | hail small|medium|large|apocalyptic | lightning [count] [radius] [self|all] [player|vehicle]")
  chat(playerId, "/survival test lightning PlayerName | test emp PlayerName 1-3 | test hail PlayerName small|medium|large|apocalyptic | resetdamage PlayerName")
  chat(playerId, "/survival cfg hail|lightning|wind|features ... | damage/destructive/heavy on|off | down/revive PlayerName")
  chat(playerId, "Lightning cfg keys: count radius player vehicle direct splash emp destroy none forcevehicle scope explosions.")
  chat(playerId, "Aliases still work: storm, supercell, hail, microburst, barrage, hailcfg, lightningcfg. " .. phaseListLine())
end

local function sendClientStatus(playerId)
  local lines = {}
  for id, player in pairs(state.players) do
    lines[#lines + 1] = string.format(
      "%s:%s client=%s lastAck=%s",
      tostring(id),
      player.name,
      player.clientReady and "ready" or "missing",
      player.lastAck or "never"
    )
  end

  if #lines == 0 then
    chat(playerId, "No tracked players.")
  else
    chat(playerId, table.concat(lines, " | "))
  end
end

local function findPlayerByName(name)
  local wanted = tostring(name or ""):lower()
  for playerId, player in pairs(state.players) do
    if player.name:lower() == wanted then
      return playerId, player
    end
  end
  return nil, nil
end

local function setPlayerAliveByName(name, alive)
  local _, player = findPlayerByName(name)
  if not player then
    return false
  end
  player.alive = alive
  return true
end

local function parseKeyValueArgs(args, startIndex)
  local result = {}
  local index = startIndex
  while index <= #args do
    local key = tostring(args[index] or ""):lower()
    local value = args[index + 1]
    if value ~= nil then
      result[key] = value
      index = index + 2
    else
      result[key] = true
      index = index + 1
    end
  end
  return result
end

local function setBooleanConfig(target, key, value)
  local normalized = tostring(value or ""):lower()
  if normalized == "on" or normalized == "true" then target[key] = true return true end
  if normalized == "off" or normalized == "false" then target[key] = false return true end
  return false
end

local function applyWindConfig(values)
  if values.speed then config.wind.speedOverride = math.max(0, math.min(100, tonumber(values.speed) or config.wind.speedOverride or 0)) end
  if values.clear == "speed" or values.speed == "default" then config.wind.speedOverride = nil end
  setBooleanConfig(config.wind, "bursts", values.bursts)
  setBooleanConfig(config.wind, "heavy", values.heavy)
end

local function applyFeatureConfig(values)
  setBooleanConfig(config.features, "shelter", values.shelter)
  setBooleanConfig(config.features, "localizedFlooding", values.flood or values.flooding)
  setBooleanConfig(config.features, "aquaplaning", values.aquaplaning or values.aqua)
  setBooleanConfig(config.features, "debris", values.debris)
  setBooleanConfig(config.features, "lightningAftermath", values.aftermath)
  if values.tyre then config.aftermath.tyreChance = math.max(0, math.min(100, tonumber(values.tyre) or config.aftermath.tyreChance)) end
  if values.fire then config.aftermath.fireChance = math.max(0, math.min(100, tonumber(values.fire) or config.aftermath.fireChance)) end
end

local function applyStormCellConfig(values)
  if values.radius then config.stormCell.radius = math.max(80, math.min(5000, tonumber(values.radius) or config.stormCell.radius)) end
  if values.fade or values.edge then config.stormCell.edgeFade = math.max(20, math.min(config.stormCell.radius, tonumber(values.fade or values.edge) or config.stormCell.edgeFade)) end
  if values.speed then config.stormCell.driftSpeed = math.max(0, math.min(100, tonumber(values.speed) or config.stormCell.driftSpeed)) end
  setBooleanConfig(config.stormCell, "enabled", values.enabled)
  if state.stormCell then
    state.stormCell.radius = config.stormCell.radius
    state.stormCell.edgeFade = config.stormCell.edgeFade
    local currentSpeed = math.sqrt(state.stormCell.vx * state.stormCell.vx + state.stormCell.vy * state.stormCell.vy)
    if currentSpeed > 0 then
      state.stormCell.vx = state.stormCell.vx / currentSpeed * config.stormCell.driftSpeed
      state.stormCell.vy = state.stormCell.vy / currentSpeed * config.stormCell.driftSpeed
    end
  end
end

local function applyLightningConfig(values)
  if values.count then config.lightning.count = math.max(1, math.min(20, math.floor(tonumber(values.count) or config.lightning.count))) end
  if values.radius then config.lightning.radius = math.max(1, math.min(500, tonumber(values.radius) or config.lightning.radius)) end
  local playerValue = values.player or values.hitplayer or values.playerchance
  local vehicleValue = values.vehicle or values.car or values.hitvehicle or values.vehiclechance
  if playerValue then config.lightning.playerChance = math.max(0, math.min(100, tonumber(playerValue) or config.lightning.playerChance)) end
  if vehicleValue then config.lightning.vehicleChance = math.max(0, math.min(100, tonumber(vehicleValue) or config.lightning.vehicleChance)) end
  if values.direct then config.lightning.directRadius = math.max(0.1, math.min(100, tonumber(values.direct) or config.lightning.directRadius)) end
  if values.splash then config.lightning.splashRadius = math.max(0.1, math.min(250, tonumber(values.splash) or config.lightning.splashRadius)) end
  if values.emp then config.lightning.empChance = math.max(0, math.min(100, tonumber(values.emp) or config.lightning.empChance)) end
  if values.destroy then config.lightning.destroyChance = math.max(0, math.min(100, tonumber(values.destroy) or config.lightning.destroyChance)) end
  local noEffectValue = values.none or values.noeffect or values.noop
  if noEffectValue then config.lightning.noEffectChance = math.max(0, math.min(100, tonumber(noEffectValue) or config.lightning.noEffectChance)) end
  local forceVehicleValue = values.forcevehicle or values.vehicleforce or values.targetvehicle
  if forceVehicleValue == "on" or forceVehicleValue == "true" then config.lightning.forceVehicle = true end
  if forceVehicleValue == "off" or forceVehicleValue == "false" then config.lightning.forceVehicle = false end
  if values.scope == "self" or values.scope == "all" then config.lightning.scope = values.scope end
  if values.explosions == "on" or values.explosions == "true" then config.lightning.explosions = true end
  if values.explosions == "off" or values.explosions == "false" then config.lightning.explosions = false end
end

lightningConfigLine = function()
  return string.format(
    "Lightning cfg: count=%d radius=%.0f player=%d%% vehicle=%d%% direct=%.1f splash=%.1f emp=%d%% destroy=%d%% none=%d%% forceVehicle=%s scope=%s explosions=%s",
    config.lightning.count,
    config.lightning.radius,
    config.lightning.playerChance,
    config.lightning.vehicleChance,
    config.lightning.directRadius,
    config.lightning.splashRadius,
    config.lightning.empChance,
    config.lightning.destroyChance,
    config.lightning.noEffectChance,
    config.lightning.forceVehicle and "on" or "off",
    config.lightning.scope,
    config.lightning.explosions and "on" or "off"
  )
end

hailConfigLine = function()
  return string.format(
    "Hail cfg: stones=%d chance=%d%% radius=%.0f",
    config.hail.stones,
    config.hail.chance,
    config.hail.radius
  )
end

phaseListLine = function()
  local names = {}
  for index, phase in ipairs(config.phases) do
    names[#names + 1] = tostring(index) .. "=" .. phase.name
  end
  names[#names + 1] = "snow=" .. config.snowPhase.name .. " (rare/manual)"
  names[#names + 1] = "snowextreme=" .. config.snowExtremePhase.name .. " (manual)"
  return "Phases: " .. table.concat(names, ", ")
end

local function startSurvival()
  state.running = true
  state.startedAt = nowSeconds()
  state.elapsed = 0
  for _, player in pairs(state.players) do
    player.alive = true
  end
  setPhase(1)
end

local function stopSurvival()
  state.running = false
  state.elapsed = 0
  state.phaseIndex = 0
  state.lastAutoLightningAt = 0
  state.phaseOverride = nil
  state.stormCell = nil
  broadcastClientCommand("deactivate")
  broadcastStormCell(false)
  chat(-1, "Survival stopped.")
end

local function maybeBroadcastSyncedLightning(phase)
  if not phase or not phase.command or phase.command:find("serverAutoLightning=true", 1, true) == nil then
    return
  end

  local interval = tonumber(phase.command:match("autoLightningInterval=([%d%.]+)")) or 10
  if interval <= 0 then
    return
  end
  if nowSeconds() - (state.lastAutoLightningAt or 0) < interval then
    return
  end

  state.lastAutoLightningAt = nowSeconds()
  local chance = math.max(0, math.min(100, tonumber(phase.command:match("autoLightningChance=([%d%.]+)")) or 100))
  if math.random() * 100 >= chance then
    return
  end
  local count = tonumber(phase.command:match("autoLightningStrikeCount=([%d%.]+)")) or config.lightning.count
  broadcastAuthoritativeLightning(count, config.lightning.radius)
end

local function handleCommand(playerId, playerName, args)
  local subcommand = tostring(args[2] or "help"):lower()

  if subcommand == "help" then
    sendHelp(playerId)
    return
  end

  if subcommand == "status" then
    chat(playerId, statusLine())
    return
  end

  if subcommand == "clients" then
    sendClientStatus(playerId)
    return
  end

  if not isAdmin(playerName) then
    chat(playerId, "You are not allowed to control survival.")
    return
  end

  if subcommand == "start" then
    startSurvival()
  elseif subcommand == "stop" then
    stopSurvival()
  elseif subcommand == "phase" or subcommand == "setphase" then
    if forcePhaseByName(args[3]) then
      chat(-1, "Phase forced by " .. playerName .. ".")
    else
      chat(playerId, "Unknown phase. " .. phaseListLine())
    end
  elseif phaseAliases[subcommand] and subcommand ~= "rain" and subcommand ~= "storm" and subcommand ~= "hail" and subcommand ~= "supercell" then
    forcePhaseByName(subcommand)
    chat(-1, "Phase forced by " .. playerName .. ".")
  elseif subcommand == "storm" then
    forcePhaseByName("storm")
    chat(-1, "Storm phase forced by " .. playerName .. ".")
  elseif subcommand == "supercell" then
    forcePhaseByName("severe")
    chat(-1, "Severe phase forced by " .. playerName .. ".")
  elseif subcommand == "hail" then
    local presetName = tostring(args[3] or ""):lower()
    local usedPreset = applyHailPreset(presetName)
    if not usedPreset and tonumber(args[3]) then
      config.hail.stones = math.max(1, math.min(1020, math.floor(tonumber(args[3]) or config.hail.stones)))
    end
    if not usedPreset and tonumber(args[4]) then
      config.hail.chance = math.max(0, math.min(100, tonumber(args[4]) or config.hail.chance))
    end
    if not usedPreset and tonumber(args[5]) then
      config.hail.radius = math.max(5, math.min(300, tonumber(args[5]) or config.hail.radius))
    end
    savePersistentSettings()
    broadcastClientCommand(buildHailPayload())
    chat(-1, "Hail core" .. (usedPreset and (" (" .. presetName .. ")") or "") .. " forced by " .. playerName .. ".")
  elseif subcommand == "hailcfg" or (subcommand == "cfg" and tostring(args[3] or ""):lower() == "hail") then
    local values = parseKeyValueArgs(args, subcommand == "cfg" and 4 or 3)
    if values.stones then config.hail.stones = math.max(1, math.min(1020, math.floor(tonumber(values.stones) or config.hail.stones))) end
    if values.chance then config.hail.chance = math.max(0, math.min(100, tonumber(values.chance) or config.hail.chance)) end
    if values.radius then config.hail.radius = math.max(5, math.min(300, tonumber(values.radius) or config.hail.radius)) end
    if values.progression then setBooleanConfig(config.hail, "progression", values.progression) end
    savePersistentSettings()
    chat(playerId, hailConfigLine())
  elseif subcommand == "cfg" and tostring(args[3] or ""):lower() == "wind" then
    applyWindConfig(parseKeyValueArgs(args, 4))
    savePersistentSettings()
    broadcastClientCommand(appendPersistentSettings("settings"))
    chat(playerId, string.format("Wind cfg: bursts=%s heavy=%s speed=%s", config.wind.bursts and "on" or "off", config.wind.heavy and "on" or "off", config.wind.speedOverride and tostring(config.wind.speedOverride) or "phase"))
  elseif subcommand == "cfg" and (tostring(args[3] or ""):lower() == "features" or tostring(args[3] or ""):lower() == "aftermath") then
    applyFeatureConfig(parseKeyValueArgs(args, 4))
    savePersistentSettings()
    broadcastClientCommand(appendPersistentSettings("settings"))
    chat(playerId, "Feature configuration saved and synchronized.")
  elseif subcommand == "cfg" and (tostring(args[3] or ""):lower() == "cell" or tostring(args[3] or ""):lower() == "stormcell") then
    applyStormCellConfig(parseKeyValueArgs(args, 4))
    savePersistentSettings()
    broadcastStormCell(stormCellPhaseActive())
    chat(playerId, string.format("Storm cell cfg: enabled=%s radius=%.0f fade=%.0f speed=%.1f", config.stormCell.enabled and "on" or "off", config.stormCell.radius, config.stormCell.edgeFade, config.stormCell.driftSpeed))
  elseif subcommand == "microburst" then
    broadcastClientCommand(appendPersistentSettings("microburst;vehicleDamageEnabled=true;destructiveWeatherEnabled=true;microburstEnabled=true"))
    chat(-1, "Microburst forced by " .. playerName .. ".")
  elseif subcommand == "lightning" or subcommand == "lighting" or subcommand == "lightnight" or subcommand == "strike" then
    local overrides = {}
    overrides.count = tonumber(args[3]) or config.lightning.count
    overrides.radius = tonumber(args[4]) or config.lightning.radius
    local scope = config.lightning.scope
    local forcePlayer = false
    local forceVehicle = false
    for index = 3, #args do
      local value = tostring(args[index] or ""):lower()
      if value == "self" or value == "all" then scope = value end
      if value == "player" or value == "hitplayer" then forcePlayer = true end
      if value == "vehicle" or value == "car" or value == "hitvehicle" or value == "hitcar" then forceVehicle = true end
    end
    overrides.forcePlayer = forcePlayer
    overrides.forceVehicle = forceVehicle
    if forceVehicle then
      if scope == "self" and playerId >= 0 then
        broadcastAuthoritativeLightning(overrides.count, overrides.radius, playerId, true, false)
      else
        for _, player in ipairs(connectedPlayers()) do
          broadcastAuthoritativeLightning(overrides.count, overrides.radius, player.id, true, false)
        end
      end
    elseif scope == "self" and playerId >= 0 then
      broadcastAuthoritativeLightning(overrides.count, overrides.radius, playerId, false, false, forcePlayer)
    else
      broadcastAuthoritativeLightning(overrides.count, overrides.radius, nil, false, false, forcePlayer)
    end
    chat(-1, string.format("Lightning sent by %s (%d strike(s), radius %.0f, scope %s%s).", playerName, tonumber(overrides.count) or config.lightning.count, tonumber(overrides.radius) or config.lightning.radius, scope, forceVehicle and ", vehicle target" or ""))
  elseif subcommand == "lightningcfg" or (subcommand == "cfg" and tostring(args[3] or ""):lower() == "lightning") then
    local values = parseKeyValueArgs(args, subcommand == "cfg" and 4 or 3)
    applyLightningConfig(values)
    savePersistentSettings()
    chat(playerId, lightningConfigLine())
  elseif subcommand == "barrage" then
    broadcastAuthoritativeLightning(math.max(config.lightning.count, 4), config.lightning.radius, config.lightning.scope == "self" and playerId or nil, false, false)
    chat(-1, "Lightning barrage sent by " .. playerName .. ".")
  elseif subcommand == "test" then
    local testType = tostring(args[3] or ""):lower()
    if testType == "lightning" then
      local targetName = joinWords(args, 4)
      local targetId, target = findPlayerByName(targetName)
      if targetId then
        broadcastAuthoritativeLightning(1, config.lightning.radius, targetId, true, true)
        chat(playerId, "Direct lightning test sent to " .. target.name .. ".")
      else
        chat(playerId, "Player not found: " .. targetName)
      end
    elseif testType == "emp" then
      local tier = math.max(1, math.min(3, math.floor(tonumber(args[#args]) or 1)))
      local targetName = joinWords(args, 4, #args - 1)
      local targetId, target = findPlayerByName(targetName)
      if targetId then
        sendClientCommand(targetId, appendPersistentSettings(table.concat({ "test_emp", "empTier=" .. tostring(tier), "eventId=" .. nextEventId("emp-test"), "eventTimestamp=" .. tostring(nowSeconds()) }, ";")))
        chat(playerId, string.format("EMP tier %d test sent to %s.", tier, target.name))
      else
        chat(playerId, "Player not found: " .. targetName)
      end
    elseif testType == "hail" then
      local presetName = tostring(args[#args] or ""):lower()
      local preset = hailPresets[presetName]
      local targetName = joinWords(args, 4, #args - 1)
      local targetId, target = findPlayerByName(targetName)
      if not preset then
        chat(playerId, "Unknown hail preset. Use small, medium, large, or apocalyptic.")
      elseif not targetId then
        chat(playerId, "Player not found: " .. targetName)
      else
        sendClientCommand(targetId, buildHailPayload({ stones = preset.stones, chance = preset.chance, radius = preset.radius, duration = 35, testDamage = true }))
        chat(playerId, presetName .. " hail test sent to " .. target.name .. ".")
      end
    else
      chat(playerId, "Use /survival test lightning PlayerName | test emp PlayerName 1-3 | test hail PlayerName size")
    end
  elseif subcommand == "resetdamage" then
    local targetName = joinWords(args, 3)
    local targetId, target = findPlayerByName(targetName)
    if targetId then
      sendClientCommand(targetId, "reset_damage;eventId=" .. nextEventId("reset-damage") .. ";eventTimestamp=" .. tostring(nowSeconds()))
      chat(playerId, "Weather damage memory and temporary effects reset for " .. target.name .. ".")
    else
      chat(playerId, "Player not found: " .. targetName)
    end
  elseif subcommand == "ping" then
    broadcastClientCommand("ping")
    chat(playerId, "Ping sent. Use /survival clients to check client acknowledgements.")
  elseif subcommand == "debug" then
    state.debug = tostring(args[3] or ""):lower() == "on"
    chat(playerId, "Debug logging " .. (state.debug and "enabled." or "disabled."))
  elseif subcommand == "damage" then
    local enabled = tostring(args[3] or ""):lower() == "on"
    state.vehicleDamageOverride = enabled
    savePersistentSettings()
    broadcastClientCommand("settings;vehicleDamageEnabled=" .. tostring(enabled))
    chat(-1, "Vehicle damage " .. (enabled and "enabled." or "disabled."))
  elseif subcommand == "destructive" then
    local enabled = tostring(args[3] or ""):lower() == "on"
    state.destructiveWeatherOverride = enabled
    savePersistentSettings()
    broadcastClientCommand("settings;destructiveWeatherEnabled=" .. tostring(enabled))
    chat(-1, "Destructive weather " .. (enabled and "enabled." or "disabled."))
  elseif subcommand == "heavy" then
    local enabled = tostring(args[3] or ""):lower() == "on"
    state.heavyStormOverride = enabled
    config.wind.heavy = enabled
    savePersistentSettings()
    broadcastClientCommand("settings;heavyStormMode=" .. tostring(enabled))
    chat(-1, "Heavy storm mode " .. (enabled and "enabled." or "disabled."))
  elseif subcommand == "down" then
    local targetName = joinWords(args, 3)
    if setPlayerAliveByName(targetName, false) then
      chat(-1, targetName .. " is marked down.")
    else
      chat(playerId, "Player not found.")
    end
  elseif subcommand == "revive" then
    local targetName = joinWords(args, 3)
    if setPlayerAliveByName(targetName, true) then
      chat(-1, targetName .. " is back in survival.")
    else
      chat(playerId, "Player not found.")
    end
  else
    sendHelp(playerId)
  end
end

function AshSurvivalTick()
  if not state.running then
    return
  end

  state.elapsed = nowSeconds() - state.startedAt
  local nextPhase = currentPhaseIndex()
  if nextPhase ~= state.phaseIndex then
    local rareSnow = nextPhase == 2 and math.random(1, 100) <= config.rareSnowChancePercent
    setPhase(nextPhase, rareSnow and config.snowPhase or nil)
  end
  local phase = getActivePhase()
  if stormCellPhaseActive() then
    updateStormCell(config.tickMs / 1000)
    if nowSeconds() - (state.lastStormCellBroadcastAt or 0) >= math.max(1, tonumber(config.stormCell.broadcastSeconds) or 2) then
      state.lastStormCellBroadcastAt = nowSeconds()
      broadcastStormCell(true)
    end
  end
  maybeBroadcastSyncedLightning(phase)
  maybeBroadcastWindburst(phase)
  maybeBroadcastHail(phase)
end

function AshSurvivalChat(playerId, playerName, message)
  if message == config.command or message:sub(1, #config.command + 1) == config.command .. " " then
    handleCommand(playerId, playerName, splitWords(message))
    return 1
  end
  return 0
end

function AshSurvivalConsole(input)
  local args = splitWords(input)
  if args[1] ~= config.consoleCommand then
    return nil
  end

  handleCommand(-1, "console", args)
  return statusLine()
end

function AshSurvivalPlayerJoining(playerId)
  local name = MP.GetPlayerName(playerId)
  state.players[playerId] = {
    name = name,
    alive = not state.running,
    clientReady = false,
    lastAck = nil
  }

  sendClientCommand(playerId, "ping")

  if state.running then
    state.players[playerId].alive = true
    sendClientCommand(playerId, "activate")
    local phase = getActivePhase()
    if phase then
      sendClientCommand(playerId, phasePayload(phase))
    end
    broadcastStormCell(stormCellPhaseActive(), playerId)
    chat(playerId, statusLine())
  end
end

function AshSurvivalPlayerDisconnect(playerId)
  state.players[playerId] = nil
end

function AshSurvivalClientReady(...)
  local args = {...}
  local playerId = tonumber(args[1])
  local data = args[2]
  if not playerId then
    print(PLUGIN_NAME .. " client event without player id: " .. tostring(args[1]))
    return
  end

  local player = state.players[playerId]
  if not player then
    local name = MP.GetPlayerName(playerId)
    player = {
      name = name,
      alive = not state.running
    }
    state.players[playerId] = player
  end

  local wasReady = player.clientReady == true
  player.clientReady = true
  player.lastAck = tostring(data or "ready")
  if state.debug or not wasReady or player.lastAck == "ready" then
    print(PLUGIN_NAME .. " client ready: " .. tostring(playerId) .. " " .. tostring(player.name) .. " " .. tostring(player.lastAck))
  end

  if state.running and not wasReady then
    sendClientCommand(playerId, "activate")
    local phase = getActivePhase()
    if phase then
      sendClientCommand(playerId, phasePayload(phase))
    end
    broadcastStormCell(stormCellPhaseActive(), playerId)
  end
end

function onInit()
  math.randomseed(nowSeconds())
  local loaded = loadPersistentSettings()
  MP.RegisterEvent("AshSurvivalTick", "AshSurvivalTick")
  MP.RegisterEvent("onChatMessage", "AshSurvivalChat")
  MP.RegisterEvent("onConsoleInput", "AshSurvivalConsole")
  MP.RegisterEvent("onPlayerJoining", "AshSurvivalPlayerJoining")
  MP.RegisterEvent("onPlayerDisconnect", "AshSurvivalPlayerDisconnect")
  MP.RegisterEvent("AshSurvivalClientReady", "AshSurvivalClientReady")
  MP.CreateEventTimer("AshSurvivalTick", config.tickMs)
  print(PLUGIN_NAME .. " build " .. BUILD_ID .. " loaded" .. (loaded and " with persistent settings" or ""))
end
