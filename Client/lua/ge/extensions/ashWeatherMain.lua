local M = {}
M.BUILD_ID = "2026-08-20-dws1"

local MOD_NAME = "AshWeather"

local randomSeeded = false
local uniqueObjectCounter = 0
local beamMpHandlersRegistered = false
local LIGHTNING_HIT_DECAY_SECONDS = 600
local NATIVE_WEATHER_PRESETS = {
  clear = "ash_clear",
  overcast = "ash_overcast",
  foggy = "ash_fog",
  drizzle = "ash_rain",
  rain = "ash_rain",
  snow = "ash_rain",
  storm = "ash_storm",
  hail = "ash_storm",
  supercell = "ash_storm"
}

local playThunderAtPosition
local getCurrentBaseProfileId
local writeLog
local registerBeamMpHandlers
local startTransition
local applyWeatherValues

local function cloneTable(value)
  if type(value) ~= "table" then
    return value
  end

  local copy = {}
  for key, item in pairs(value) do
    copy[key] = cloneTable(item)
  end
  return copy
end

local function notifyClient(message)
  if type(guihooks) == "table" and type(guihooks.message) == "function" then
    pcall(guihooks.message, "[Dynamic Weather Survival] " .. tostring(message), 5, "AshWeather")
  end
end

local weatherProfiles = {
  clear = {
    id = "clear",
    label = "Clear Break",
    tod = 0.58,
    windSpeed = 0.12,
    fogDensity = 0.0008,
    rainEnabled = false,
    rainAmount = 0,
    precipitationType = "rain",
    cloudCover = 0.10,
    temperatureC = 22,
    brightness = 1.0,
    roadCondition = "dry",
    roadWetRoughness = 0,
    maxWaterRise = 0,
    waterRiseRate = 0,
    burstMinInterval = 90,
    burstMaxInterval = 180,
    burstMinMultiplier = 1.08,
    burstMaxMultiplier = 1.28,
    weight = 3.2,
    minDuration = 180,
    maxDuration = 360
  },
  overcast = {
    id = "overcast",
    label = "Dense Overcast",
    tod = 0.70,
    windSpeed = 0.42,
    fogDensity = 0.0020,
    rainEnabled = false,
    rainAmount = 0,
    precipitationType = "rain",
    cloudCover = 1.70,
    temperatureC = 16,
    brightness = 0.76,
    roadCondition = "dry",
    roadWetRoughness = 0,
    maxWaterRise = 0,
    waterRiseRate = 0,
    burstMinInterval = 55,
    burstMaxInterval = 130,
    burstMinMultiplier = 1.12,
    burstMaxMultiplier = 1.38,
    weight = 2.4,
    minDuration = 160,
    maxDuration = 320
  },
  foggy = {
    id = "foggy",
    label = "Morning Fog",
    tod = 0.28,
    windSpeed = 0.07,
    fogDensity = 0.0140,
    rainEnabled = false,
    rainAmount = 0,
    precipitationType = "rain",
    cloudCover = 0.90,
    temperatureC = 9,
    brightness = 0.62,
    roadCondition = "dry",
    roadWetRoughness = 0,
    maxWaterRise = 0,
    waterRiseRate = 0,
    burstMinInterval = 110,
    burstMaxInterval = 240,
    burstMinMultiplier = 1.04,
    burstMaxMultiplier = 1.20,
    weight = 1.4,
    minDuration = 120,
    maxDuration = 220
  },
  drizzle = {
    id = "drizzle",
    label = "Cold Drizzle",
    tod = 0.68,
    windSpeed = 0.38,
    fogDensity = 0.0040,
    rainEnabled = true,
    rainAmount = 350,
    precipitationType = "rain",
    cloudCover = 2.60,
    temperatureC = 11,
    brightness = 0.68,
    roadCondition = "wet",
    roadWetRoughness = 0.28,
    maxWaterRise = 0.18,
    waterRiseRate = 0.05,
    burstMinInterval = 40,
    burstMaxInterval = 95,
    burstMinMultiplier = 1.15,
    burstMaxMultiplier = 1.48,
    weight = 1.8,
    minDuration = 140,
    maxDuration = 240
  },
  rain = {
    id = "rain",
    label = "Heavy Rain",
    tod = 0.73,
    windSpeed = 0.62,
    fogDensity = 0.0040,
    rainEnabled = true,
    rainAmount = 1300,
    precipitationType = "rain",
    cloudCover = 2.60,
    temperatureC = 13,
    brightness = 0.58,
    roadCondition = "wet",
    roadWetRoughness = 0.18,
    maxWaterRise = 0.55,
    waterRiseRate = 0.10,
    burstMinInterval = 28,
    burstMaxInterval = 70,
    burstMinMultiplier = 1.22,
    burstMaxMultiplier = 1.65,
    weight = 1.2,
    minDuration = 100,
    maxDuration = 220
  },
  storm = {
    id = "storm",
    label = "Thunderstorm",
    tod = 0.82,
    windSpeed = 0.98,
    fogDensity = 0.0070,
    rainEnabled = true,
    rainAmount = 2200,
    precipitationType = "rain",
    cloudCover = 3.60,
    temperatureC = 10,
    brightness = 0.42,
    roadCondition = "wet",
    roadWetRoughness = 0.11,
    maxWaterRise = 0.95,
    waterRiseRate = 0.16,
    burstMinInterval = 14,
    burstMaxInterval = 38,
    burstMinMultiplier = 1.45,
    burstMaxMultiplier = 2.15,
    weight = 0.7,
    minDuration = 70,
    maxDuration = 150
  },
  hail = {
    id = "hail",
    label = "Hail Core",
    tod = 0.84,
    windSpeed = 1.12,
    fogDensity = 0.0070,
    rainEnabled = true,
    rainAmount = 2500,
    precipitationType = "hail",
    cloudCover = 3.60,
    temperatureC = 4,
    brightness = 0.36,
    roadCondition = "ice",
    roadWetRoughness = 0,
    maxWaterRise = 0.75,
    waterRiseRate = 0.14,
    burstMinInterval = 11,
    burstMaxInterval = 30,
    burstMinMultiplier = 1.60,
    burstMaxMultiplier = 2.50,
    weight = 0.42,
    minDuration = 55,
    maxDuration = 120
  },
  supercell = {
    id = "supercell",
    label = "Heavy Storm",
    tod = 0.88,
    windSpeed = 1.48,
    fogDensity = 0.0070,
    rainEnabled = true,
    rainAmount = 3200,
    precipitationType = "rain",
    cloudCover = 3.60,
    temperatureC = 8,
    brightness = 0.28,
    roadCondition = "wet",
    roadWetRoughness = 0.07,
    maxWaterRise = 1.40,
    waterRiseRate = 0.22,
    burstMinInterval = 8,
    burstMaxInterval = 22,
    burstMinMultiplier = 1.85,
    burstMaxMultiplier = 3.05,
    weight = 0.22,
    minDuration = 45,
    maxDuration = 95
  },
  snow = {
    id = "snow",
    label = "Heavy Snow",
    tod = 0.66,
    windSpeed = 0.48,
    fogDensity = 0.0040,
    rainEnabled = true,
    rainAmount = 1100,
    precipitationType = "snow",
    cloudCover = 2.60,
    temperatureC = -5,
    brightness = 0.64,
    roadCondition = "ice",
    roadWetRoughness = 0,
    maxWaterRise = 0,
    waterRiseRate = 0,
    burstMinInterval = 35,
    burstMaxInterval = 90,
    burstMinMultiplier = 1.18,
    burstMaxMultiplier = 1.58,
    weight = 0.35,
    minDuration = 120,
    maxDuration = 260
  }
}

local levelOverrides = {
  default = {
    label = "Default",
    presetOrder = { "clear", "overcast", "foggy", "drizzle", "rain", "snow", "storm", "hail", "supercell" },
    profileWeights = {
      clear = 1.0,
      overcast = 1.0,
      foggy = 1.0,
      drizzle = 1.0,
      rain = 1.0,
      snow = 0.45,
      storm = 1.0,
      hail = 0.8,
      supercell = 0.45
    },
    rainObjects = {
      "rain",
      "Rain",
      "rainDrops",
      "precipitation",
      "Precipitation"
    },
    lightningObjects = {},
    transitionMin = 18,
    transitionMax = 45,
    startupProfile = "clear"
  },
  west_coast_usa = {
    label = "West Coast USA",
    presetOrder = { "clear", "overcast", "drizzle", "rain", "storm", "hail", "supercell", "clear" },
    profileWeights = {
      clear = 1.2,
      overcast = 1.1,
      foggy = 0.3,
      drizzle = 1.3,
      rain = 1.1,
      storm = 1.5,
      hail = 1.0,
      supercell = 0.75
    },
    rainObjects = {
      "rain",
      "wcusaRainEmitter",
      "storm_rain_main"
    },
    lightningObjects = {},
    transitionMin = 16,
    transitionMax = 38,
    startupProfile = "overcast"
  },
  italy = {
    label = "Italy",
    presetOrder = { "clear", "clear", "overcast", "drizzle", "storm", "hail", "supercell" },
    profileWeights = {
      clear = 1.6,
      overcast = 1.0,
      foggy = 0.2,
      drizzle = 0.8,
      rain = 0.6,
      storm = 0.9,
      hail = 0.45,
      supercell = 0.28
    },
    rainObjects = {
      "rain",
      "italyRain",
      "italyStormEmitter"
    },
    lightningObjects = {},
    transitionMin = 20,
    transitionMax = 50,
    startupProfile = "clear"
  },
  east_coast_usa = {
    label = "East Coast USA",
    presetOrder = { "foggy", "overcast", "drizzle", "rain", "storm", "hail", "supercell", "clear" },
    profileWeights = {
      clear = 0.9,
      overcast = 1.2,
      foggy = 1.5,
      drizzle = 1.1,
      rain = 1.0,
      storm = 1.2,
      hail = 1.1,
      supercell = 0.65
    },
    rainObjects = {
      "rain",
      "ecusaRain",
      "eastCoastStormRain"
    },
    lightningObjects = {},
    transitionMin = 18,
    transitionMax = 42,
    startupProfile = "foggy"
  }
}

local builtinWeatherProfiles = cloneTable(weatherProfiles)
local builtinLevelOverrides = cloneTable(levelOverrides)

local state = {
  enabled = false,
  activated = false,
  dynamicMode = true,
  levelName = "default",
  sessionScope = "freeroam",
  autoActivateCareer = false,
  autoActivateFreeroam = false,
  persistCareer = true,
  persistFreeroam = true,
  lightningEnabled = true,
  autoLightningEnabled = true,
  autoLightningStrikeCount = 2,
  autoLightningInterval = 12.0,
  windBurstsEnabled = true,
  stormBiasScale = 1.0,
  transitionScale = 1.0,
  vehicleDamageEnabled = false,
  damageTier = "realistic",
  destructiveWeatherEnabled = true,
  hailEnabled = true,
  hailDamageChance = 0.42,
  hailStoneCount = 18,
  hailRadius = 85,
  hailDamageInterval = 2.6,
  microburstEnabled = true,
  lightningStrikeRadius = 50,
  lightningVehicleHitChance = 0.05,
  lightningPlayerHitChance = 0.0,
  lightningForcePlayerTarget = false,
  lightningForceVehicleTarget = false,
  lightningDirectDamageRadius = 2,
  lightningSplashDamageRadius = 4,
  lightningEmpEffectChance = 0.55,
  lightningDestroyChance = 0.15,
  lightningNoEffectChance = 0.30,
  lightningExplosionsEnabled = false,
  lightningAftermathEnabled = true,
  lightningTyreDamageChance = 0.12,
  lightningFireChance = 0.08,
  lightningIgnoreShelter = false,
  pendingLightningEvent = nil,
  pendingSyncedLightning = {},
  serverBuildId = nil,
  serverAutoLightning = false,
  processedServerEvents = {},
  serverStormCell = nil,
  localStormIntensity = 1,
  shelterDetectionEnabled = true,
  localizedFloodingEnabled = true,
  aquaplaningEnabled = true,
  aquaplaneTimer = 0,
  windDebrisEnabled = true,
  windDebris = {},
  windDebrisTimer = 0,
  windDebrisNonce = 0,
  hailProgressionEnabled = true,
  pendingHailDuration = nil,
  pendingHailEvent = nil,
  pendingHailTestDamage = false,
  rainfallAccumulation = 0,
  heavyStormMode = false,
  heavyStormInterval = 2.0,
  activeProfileId = "clear",
  currentProfileId = "clear",
  targetProfileId = nil,
  timeInProfile = 0,
  nextChangeIn = 240,
  transition = nil,
  restoredFromSerialize = false,
  saveTimer = 0,
  timeSinceBurst = 0,
  nextBurstCheckIn = 12,
  timeSinceLightning = 0,
  nextLightningCheckIn = 18,
  heavyStormTimer = 0,
  burst = nil,
  lightningFlash = nil,
  lightningVisualNonce = 0,
  lightningVisualStrength = 0.0,
  lightningEnvironment = nil,
  stormAmbienceTimer = 0,
  severeWindBoost = nil,
  hailstorm = nil,
  hailTimer = 0,
  nextHailCheckIn = 18,
  microburst = nil,
  microburstTimer = 0,
  nextMicroburstCheckIn = 22,
  vehicleHazardCooldowns = {},
  hailLineOfSightCache = {},
  vehicleLocalWindEffects = {},
  vehicleElectricalEffects = {},
  vehicleEmpShutdownEffects = {},
  lightningVehicleHitCounts = {},
  windDirectionTimer = 0,
  windDirectionChangeInterval = 60,
  windDirectionRadians = 0,
  windDirectionStartRadians = 0,
  windDirectionTargetRadians = 0,
  windDirectionTurnElapsed = 0,
  windDirectionTurnDuration = 18,
  playerPhaseWindTimer = 0,
  playerPhaseWindGustTimer = 0,
  playerPhaseWindGust = 1.0,
  playerPhaseWindLastVehicleKey = nil,
  appliedWindSpeed = 0,
  dynamicPrecipitation = nil,
  dynamicPrecipitationCreated = false,
  dynamicPrecipitationActive = false,
  appliedPrecipitationAmount = nil,
  appliedPrecipitationType = nil,
  appliedPrecipitationEnabled = nil,
  forestWindEmitter = nil,
  forestWindEmitterCreated = false,
  forestWindOriginal = nil,
  appliedForestWindStrength = nil,
  appliedForestGustFrequency = nil,
  waterObjects = {},
  waterObjectsInitialized = false,
  waterOffset = 0,
  waterUpdateTimer = 0,
  waterWarningShown = false,
  roadMaterialCache = {},
  roadCondition = "dry",
  roadWarningShown = false,
  roadWetness = 0,
  roadWetTargetRoughness = 0,
  roadWetAppliedRoughness = 0,
  roadWetMaterialQueue = {},
  roadWetSavedRoughness = {},
  roadWetSavedDiffuse = {},
  roadVisualBaselineRoughness = {},
  roadVisualBaselineDiffuse = {},
  roadWetLastRainRoughness = 0,
  nativeWeatherWarningShown = false,
  nativeWeatherTransitionRemaining = 0,
  nativeWeatherRestoreDelay = nil,
  originalTemperatureK = nil,
  appliedTemperatureC = nil,
  environmentStateApiLogged = false,
  environmentApplyElapsed = 1,
  environmentApplyInterval = 0.10,
  environmentApplyPending = false,
  worldLightning = nil,
  worldLightnings = {},
  strikeResidue = {},
  activeImpactEmitters = {},
  activeThunderEmitters = {},
  activeLightningRibbonMeshes = {},
  thunderQueue = {},
  currentValues = {
    tod = weatherProfiles.clear.tod,
    windSpeed = weatherProfiles.clear.windSpeed,
    fogDensity = weatherProfiles.clear.fogDensity,
    rainEnabled = weatherProfiles.clear.rainEnabled,
    rainAmount = weatherProfiles.clear.rainAmount,
    precipitationType = weatherProfiles.clear.precipitationType,
    cloudCover = weatherProfiles.clear.cloudCover,
    temperatureC = weatherProfiles.clear.temperatureC,
    brightness = weatherProfiles.clear.brightness,
    roadCondition = weatherProfiles.clear.roadCondition,
    roadWetRoughness = weatherProfiles.clear.roadWetRoughness,
    maxWaterRise = weatherProfiles.clear.maxWaterRise,
    waterRiseRate = weatherProfiles.clear.waterRiseRate
  },
  rainObjectsActive = false
}

writeLog = function(level, message)
  log(level, MOD_NAME, message)
end

local function ensureRandomSeed()
  if randomSeeded then
    return
  end

  local seed = os.time()
  if getMissionFilename then
    local ok, mission = pcall(getMissionFilename)
    if ok and type(mission) == "string" then
      seed = seed + #mission
    end
  end

  math.randomseed(seed)
  math.random()
  math.random()
  math.random()
  randomSeeded = true
end

local function reseedAfterSyncedLightning()
  local seed = os.time() + uniqueObjectCounter + math.floor((os.clock() or 0) * 100000)
  math.randomseed(seed)
  math.random()
  math.random()
  math.random()
end

local function runWithLightningSeed(seed, fn)
  local numericSeed = tonumber(seed)
  if not numericSeed then
    return fn()
  end

  math.randomseed(math.floor(numericSeed) % 2147483647)
  math.random()
  math.random()
  math.random()
  local ok, result = pcall(fn)
  reseedAfterSyncedLightning()
  if not ok then
    error(result)
  end
  return result
end

local function clamp(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function nextUniqueObjectName(prefix)
  uniqueObjectCounter = uniqueObjectCounter + 1
  return string.format("%s_%d", prefix, uniqueObjectCounter)
end

local function sanitizeId(value)
  local sanitized = tostring(value or "default"):gsub("[^%w_%-]", "_")
  if sanitized == "" then
    return "default"
  end
  return sanitized
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function lerpWrapped(a, b, t)
  local diff = ((b - a + 0.5) % 1.0) - 0.5
  local result = a + diff * t
  if result < 0 then
    result = result + 1
  elseif result > 1 then
    result = result - 1
  end
  return result
end

local function getProfile(profileId)
  return weatherProfiles[profileId] or weatherProfiles.clear
end

local function getSessionScope()
  if career_career or career_modules_inventory or career_saveSystem then
    return "career"
  end
  return "freeroam"
end

local function getLevelName()
  if core_levels and type(core_levels.getLevelName) == "function" then
    local ok, value = pcall(core_levels.getLevelName, getMissionFilename and getMissionFilename() or nil)
    if ok and value and value ~= "" then
      return value
    end
  end

  if getMissionFilename then
    local ok, mission = pcall(getMissionFilename)
    if ok and type(mission) == "string" then
      local level = mission:match("/levels/([^/]+)/")
      if level then
        return level
      end
    end
  end

  return "default"
end

local function getLevelConfig()
  return levelOverrides[state.levelName] or levelOverrides.default
end

local function getSessionSavePath()
  return string.format("settings/ashWeather/%s_%s.json", sanitizeId(state.sessionScope), sanitizeId(state.levelName))
end

local function shouldPersistSession()
  if state.sessionScope == "career" then
    return state.persistCareer
  end
  return state.persistFreeroam
end

local function getProfileDuration(profileId)
  local profile = getProfile(profileId)
  if profile.maxDuration <= profile.minDuration then
    return profile.minDuration
  end
  return profile.minDuration + math.random() * (profile.maxDuration - profile.minDuration)
end

local function getTransitionDuration()
  local config = getLevelConfig()
  local minDuration = config.transitionMin or 18
  local maxDuration = config.transitionMax or minDuration
  if maxDuration <= minDuration then
    return minDuration * state.transitionScale
  end
  return (minDuration + math.random() * (maxDuration - minDuration)) * state.transitionScale
end

local function tryCoreEnvironment(functionName, ...)
  if not core_environment then
    return false, "core_environment unavailable"
  end

  local fn = core_environment[functionName]
  if type(fn) ~= "function" then
    return false, functionName .. " unavailable"
  end

  local ok, result = pcall(fn, ...)
  if not ok then
    return false, result
  end

  return true, result
end

local function supportsNativeEnvironmentState()
  return core_environment
    and type(core_environment.setState) == "function"
    and type(core_environment.getState) == "function"
    and type(core_environment.setGroundWind) == "function"
end

local function setObjectHidden(obj, hidden)
  if not obj then
    return false
  end

  if type(obj.setHidden) == "function" then
    obj:setHidden(hidden)
    return true
  end

  if type(obj.setField) == "function" then
    obj:setField("hidden", 0, hidden and "1" or "0")
    return true
  end

  return false
end

local function setObjectActive(obj, enabled)
  if not obj then
    return false
  end

  if obj.active ~= nil then
    obj.active = enabled
    return true
  end

  if type(obj.setField) == "function" then
    obj:setField("enabled", 0, enabled and "1" or "0")
    return true
  end

  return false
end

M.weatherRuntime = {}

function M.weatherRuntime.nativeWeatherPresetAvailable(presetName)
  if not core_weather or type(core_weather.getPresets) ~= "function" then
    return false
  end
  local ok, presets = pcall(core_weather.getPresets)
  if not ok or type(presets) ~= "table" then
    return false
  end
  for _, candidate in ipairs(presets) do
    if candidate == presetName then
      return true
    end
  end
  return false
end

function M.weatherRuntime.switchNativeWeather(profileId, duration)
  local presetName = NATIVE_WEATHER_PRESETS[profileId] or NATIVE_WEATHER_PRESETS.overcast
  if not core_weather or type(core_weather.switchWeather) ~= "function" or not M.weatherRuntime.nativeWeatherPresetAvailable(presetName) then
    if not state.nativeWeatherWarningShown then
      state.nativeWeatherWarningShown = true
      writeLog("W", "BeamNG native AshWeather presets are unavailable; using environment-state fallback")
    end
    return false
  end

  local transitionDuration = math.max(0.1, tonumber(duration) or 0.1)
  local ok, err = pcall(core_weather.switchWeather, presetName, transitionDuration)
  if not ok then
    writeLog("W", "Unable to switch native weather preset: " .. tostring(err))
    return false
  end
  state.nativeWeatherTransitionRemaining = transitionDuration + 0.1
  return true
end

function M.weatherRuntime.activateNativeWeather(profileId)
  local presetName = NATIVE_WEATHER_PRESETS[profileId] or NATIVE_WEATHER_PRESETS.overcast
  if not core_weather or type(core_weather.activate) ~= "function" or not M.weatherRuntime.nativeWeatherPresetAvailable(presetName) then
    return false
  end
  local ok, err = pcall(core_weather.activate, presetName)
  if not ok then
    writeLog("W", "Unable to activate native weather preset: " .. tostring(err))
    return false
  end

  -- In 0.39, activate() does not cancel an existing switchWeather() interpolation.
  -- Replace it with a zero-difference transition so stale values cannot overwrite this preset.
  if type(core_weather.switchWeather) == "function" then
    local switched, switchErr = pcall(core_weather.switchWeather, presetName, 0.01)
    if not switched then
      writeLog("W", "Unable to settle native weather preset: " .. tostring(switchErr))
    end
  end
  state.nativeWeatherTransitionRemaining = 0
  return true
end

function M.weatherRuntime.postApplyObject(obj)
  if not M.weatherRuntime.isSceneObjectValid(obj) then return false end
  local ok = pcall(function()
    if type(obj.postApply) == "function" then obj:postApply() end
  end)
  return ok
end

function M.weatherRuntime.isSceneObjectValid(obj)
  if not obj then return false end
  local ok, id = pcall(function() return obj:getID() end)
  if not ok or not tonumber(id) or tonumber(id) <= 0 then return false end
  if scenetree and type(scenetree.findObjectById) == "function" then
    local foundOk, found = pcall(scenetree.findObjectById, tonumber(id))
    return foundOk and found ~= nil
  end
  return true
end

function M.weatherRuntime.findSceneObjectsByClass(className)
  local objects = {}
  local seen = {}
  if not scenetree then
    return objects
  end
  local finder = scenetree.findClassObjects or scenetree.findSubClassObjects
  if type(finder) ~= "function" then
    return objects
  end
  local ok, names = pcall(finder, className)
  if not ok or type(names) ~= "table" then
    ok, names = pcall(finder, scenetree, className)
  end
  if not ok or type(names) ~= "table" then
    return objects
  end
  for _, name in ipairs(names) do
    local obj = scenetree.findObject(name)
    if obj and not seen[tostring(obj)] then
      seen[tostring(obj)] = true
      objects[#objects + 1] = obj
    end
  end
  return objects
end

function M.weatherRuntime.ensureDynamicPrecipitation()
  if state.dynamicPrecipitation and type(state.dynamicPrecipitation.setField) == "function" then
    return state.dynamicPrecipitation
  end
  if not createObject or not scenetree then
    return nil
  end
  local obj = createObject("Precipitation")
  if not obj then
    return nil
  end
  obj.numOfDrops = 0
  obj.splashSize = 0
  obj.splashMS = 0
  obj.animateSplashes = 0
  obj.boxWidth = 24
  obj.boxHeight = 20
  obj.boxoceanHeight = 10
  obj.dropSize = 1
  obj.doCollision = true
  obj.hitVehicles = true
  obj.rotateWithCamVel = false
  obj.followCam = true
  obj.useWind = true
  obj.minSpeed = 0.3
  obj.maxSpeed = 0.7
  obj.minMass = 4
  obj.maxMass = 5
  obj.canSave = false
  local ok = pcall(obj.registerObject, obj, "ashWeather_dynamic_precipitation")
  if not ok then
    pcall(obj.delete, obj)
    return nil
  end
  state.dynamicPrecipitation = obj
  state.dynamicPrecipitationCreated = true
  return obj
end

function M.weatherRuntime.applyDynamicPrecipitation(values)
  local enabled = values.rainEnabled == true and (tonumber(values.rainAmount) or 0) > 0
  local obj = M.weatherRuntime.ensureDynamicPrecipitation()
  if not obj then
    return false
  end
  local precipitationType = tostring(values.precipitationType or "rain")
  local dataBlockName = precipitationType == "snow" and "Snow_menu" or "rain_medium"
  local dataBlock = scenetree and scenetree.findObject(dataBlockName) or nil
  local amount = enabled and math.floor(clamp(tonumber(values.rainAmount) or 0, 0, 5000)) or 0
  local changed = state.appliedPrecipitationAmount ~= amount
    or state.appliedPrecipitationType ~= precipitationType
    or state.appliedPrecipitationEnabled ~= enabled
  if changed then
    if dataBlock then
      obj.dataBlock = dataBlock
    end
    obj.numOfDrops = amount
    obj.dropSize = precipitationType == "snow" and 0.75 or 1.0
    obj.minSpeed = 0.3
    obj.maxSpeed = 0.7
    obj.minMass = 4
    obj.maxMass = 5
    setObjectHidden(obj, not enabled)
    M.weatherRuntime.postApplyObject(obj)
    state.appliedPrecipitationAmount = amount
    state.appliedPrecipitationType = precipitationType
    state.appliedPrecipitationEnabled = enabled
  end
  state.dynamicPrecipitationActive = enabled and dataBlock ~= nil
  return dataBlock ~= nil
end

function M.weatherRuntime.removeDynamicPrecipitation()
  local obj = state.dynamicPrecipitation
  if obj then
    if state.dynamicPrecipitationCreated and type(obj.delete) == "function" then
      pcall(obj.delete, obj)
    else
      obj.numOfDrops = 0
      setObjectHidden(obj, true)
    end
  end
  state.dynamicPrecipitation = nil
  state.dynamicPrecipitationCreated = false
  state.dynamicPrecipitationActive = false
  state.appliedPrecipitationAmount = nil
  state.appliedPrecipitationType = nil
  state.appliedPrecipitationEnabled = nil
end

function M.weatherRuntime.ensureForestWindEmitter()
  if state.forestWindEmitter then
    if M.weatherRuntime.isSceneObjectValid(state.forestWindEmitter) then return state.forestWindEmitter end
    state.forestWindEmitter = nil
    state.forestWindEmitterCreated = false
    state.forestWindOriginal = nil
    state.appliedForestWindStrength = nil
    state.appliedForestGustFrequency = nil
  end
  local objects = M.weatherRuntime.findSceneObjectsByClass("ForestWindEmitter")
  local obj = objects[1]
  if obj then
    state.forestWindOriginal = {
      strength = tonumber(obj.strength) or 0,
      gustFrequency = tonumber(obj.gustFrequency) or 0,
      windEnabled = obj.windEnabled ~= false
    }
  elseif createObject then
    obj = createObject("ForestWindEmitter")
    if obj then
      obj.canSave = false
      local ok = pcall(obj.registerObject, obj, "ashWeather_forest_wind")
      if not ok then
        pcall(obj.delete, obj)
        obj = nil
      else
        state.forestWindEmitterCreated = true
      end
    end
  end
  state.forestWindEmitter = obj
  return obj
end

function M.weatherRuntime.applyForestWind(windSpeed)
  local obj = M.weatherRuntime.ensureForestWindEmitter()
  if not obj then
    return
  end
  local profile = getProfile(getCurrentBaseProfileId())
  local strength = clamp((tonumber(windSpeed) or 0) * 0.35, 0, 6)
  local gustFrequency = clamp(60 / math.max(2, tonumber(profile.burstMinInterval) or 60), 0, 8)
  if state.appliedForestWindStrength ~= strength or state.appliedForestGustFrequency ~= gustFrequency then
    local ok = pcall(function()
      obj.windEnabled = strength > 0.001
      obj.strength = strength
      obj.gustFrequency = gustFrequency
      if type(obj.postApply) == "function" then obj:postApply() end
    end)
    if not ok then
      state.forestWindEmitter = nil
      state.forestWindEmitterCreated = false
      state.forestWindOriginal = nil
      state.appliedForestWindStrength = nil
      state.appliedForestGustFrequency = nil
      return
    end
    state.appliedForestWindStrength = strength
    state.appliedForestGustFrequency = gustFrequency
  end
end

function M.weatherRuntime.restoreForestWind()
  local obj = state.forestWindEmitter
  if not M.weatherRuntime.isSceneObjectValid(obj) then
    state.forestWindEmitter = nil
    state.forestWindEmitterCreated = false
    state.forestWindOriginal = nil
    state.appliedForestWindStrength = nil
    state.appliedForestGustFrequency = nil
    return
  end
  pcall(function()
    if state.forestWindEmitterCreated and type(obj.delete) == "function" then
      obj:delete()
    elseif state.forestWindOriginal then
      obj.strength = state.forestWindOriginal.strength
      obj.gustFrequency = state.forestWindOriginal.gustFrequency
      obj.windEnabled = state.forestWindOriginal.windEnabled
      if type(obj.postApply) == "function" then obj:postApply() end
    end
  end)
  state.forestWindEmitter = nil
  state.forestWindEmitterCreated = false
  state.forestWindOriginal = nil
  state.appliedForestWindStrength = nil
  state.appliedForestGustFrequency = nil
end

function M.weatherRuntime.applyTemperature(temperatureC)
  local value = clamp(tonumber(temperatureC) or 15, -40, 55)
  if state.appliedTemperatureC and math.abs(state.appliedTemperatureC - value) < 0.05 then
    return
  end
  if state.originalTemperatureK == nil and core_environment and type(core_environment.getTemperatureK) == "function" then
    local ok, original = pcall(core_environment.getTemperatureK)
    if ok and tonumber(original) and tonumber(original) > 0 then
      state.originalTemperatureK = tonumber(original)
    end
  end
  if be and type(be.setSeaLevelTemperatureK) == "function" then
    pcall(be.setSeaLevelTemperatureK, be, value + 273.15)
    state.appliedTemperatureC = value
  end
end

function M.weatherRuntime.restoreTemperature()
  if state.originalTemperatureK and be and type(be.setSeaLevelTemperatureK) == "function" then
    pcall(be.setSeaLevelTemperatureK, be, state.originalTemperatureK)
  end
  state.appliedTemperatureC = nil
  state.originalTemperatureK = nil
end

function M.weatherRuntime.initializeWaterObjects()
  if state.waterObjectsInitialized then
    return
  end
  state.waterObjectsInitialized = true
  for _, className in ipairs({ "WaterPlane", "WaterBlock" }) do
    for _, obj in ipairs(M.weatherRuntime.findSceneObjectsByClass(className)) do
      if type(obj.getPosition) == "function" and type(obj.setPosition) == "function" then
        local ok, position = pcall(obj.getPosition, obj)
        if ok and position then
          state.waterObjects[#state.waterObjects + 1] = {
            obj = obj,
            basePosition = vec3(position)
          }
        end
      end
    end
  end
  if #state.waterObjects == 0 and not state.waterWarningShown then
    writeLog("I", "No WaterPlane or WaterBlock objects found; dynamic water level disabled for this map")
    state.waterWarningShown = true
  end
end

function M.weatherRuntime.setWaterOffset(offset)
  state.waterOffset = math.max(0, tonumber(offset) or 0)
  for index = #state.waterObjects, 1, -1 do
    local entry = state.waterObjects[index]
    if entry.obj and type(entry.obj.setPosition) == "function" then
      local position = entry.basePosition + vec3(0, 0, state.waterOffset)
      local ok = pcall(entry.obj.setPosition, entry.obj, position)
      if ok then
        M.weatherRuntime.postApplyObject(entry.obj)
      else
        table.remove(state.waterObjects, index)
      end
    else
      table.remove(state.waterObjects, index)
    end
  end
end

function M.weatherRuntime.updateDynamicWater(dt)
  M.weatherRuntime.initializeWaterObjects()
  if #state.waterObjects == 0 then
    return
  end
  state.waterUpdateTimer = (state.waterUpdateTimer or 0) + dt
  if state.waterUpdateTimer < 1.0 then
    return
  end
  local elapsed = state.waterUpdateTimer
  state.waterUpdateTimer = 0
  local values = state.currentValues or {}
  local localIntensity = state.serverStormCell and clamp(state.localStormIntensity or 0, 0, 1) or 1
  local rainingHere = values.rainEnabled and localIntensity > 0.03
  local accumulation = tonumber(state.rainfallAccumulation) or 0
  if rainingHere then
    accumulation = math.min(1, accumulation + elapsed * (0.0025 + (tonumber(values.rainAmount) or 0) * 0.0045) * localIntensity)
  else
    accumulation = math.max(0, accumulation - elapsed * 0.0022)
  end
  state.rainfallAccumulation = accumulation
  local floodScale = state.localizedFloodingEnabled and accumulation or (rainingHere and 1 or 0)
  local target = math.max(0, tonumber(values.maxWaterRise) or 0) * floodScale * localIntensity
  local rate = rainingHere and math.max(0, tonumber(values.waterRiseRate) or 0) or 0.45
  local step = rate * elapsed / 60
  local nextOffset = state.waterOffset or 0
  if nextOffset < target then
    nextOffset = math.min(target, nextOffset + step)
  elseif nextOffset > target then
    nextOffset = math.max(target, nextOffset - step)
  end
  if math.abs(nextOffset - (state.waterOffset or 0)) > 0.0001 then
    M.weatherRuntime.setWaterOffset(nextOffset)
  end
end

function M.weatherRuntime.restoreWaterObjects()
  if state.waterObjectsInitialized then
    M.weatherRuntime.setWaterOffset(0)
  end
  state.waterObjects = {}
  state.waterObjectsInitialized = false
  state.waterOffset = 0
  state.waterUpdateTimer = 0
end

local wetRoadGroundModels = {
  ASPHALT = true,
  ASPHALT_OLD = true,
  ASPHALT_WET = true,
  ASPHALT_WET2 = true,
  ASPHALT_WET3 = true,
  ASPHALT_WET_MKDW = true,
  ASPHALT_ICY = true,
  ASPHALT_ICY_MKDW = true,
  CONCRETE = true,
  CONCRETE2 = true,
  GROUNDMODEL_ASPHALT1 = true,
  GROUNDMODEL_ASPHALT_OLD = true,
  ICE = true
}

local dryRoadGroundModels = {
  ASPHALT_WET = "ASPHALT",
  ASPHALT_WET2 = "ASPHALT",
  ASPHALT_WET3 = "ASPHALT",
  ASPHALT_WET_MKDW = "ASPHALT",
  ASPHALT_ICY = "ASPHALT",
  ASPHALT_ICY_MKDW = "ASPHALT",
  ICE = "ASPHALT"
}

local roadWetConfig = {
  materialCap = 24,
  accumulationRate = 0.004,
  dryingRate = 0.0025,
  materialWords = {
    "road", "asphalt", "concrete", "pavement", "tarmac", "sidewalk", "curb", "kerb",
    "track", "blacktop", "macadam", "raceway", "speedway", "circuit", "racetrack", "cobble"
  },
  exclusions = {
    "sky", "cloud", "glass", "window", "water", "tree", "foliage", "grass", "plant", "leaf",
    "wheel", "tire", "glow", "decal", "sign", "smoke", "fire", "emissive", "grid", "border",
    "crack", "crossing", "skidmark", "marking", "arrow", "paint"
  }
}

function M.weatherRuntime.nameContainsAny(value, words)
  local lower = string.lower(tostring(value or ""))
  for _, word in ipairs(words) do
    if string.find(lower, word, 1, true) then
      return true
    end
  end
  return false
end

function M.weatherRuntime.collectRoadVisualMaterials()
  local result = {}
  local count = 0
  if not scenetree or type(scenetree.findClassObjects) ~= "function" then
    return result
  end

  local function add(materialName)
    if count >= roadWetConfig.materialCap or not materialName or materialName == "" or result[materialName] then
      return
    end
    if M.weatherRuntime.nameContainsAny(materialName, roadWetConfig.exclusions) then
      return
    end
    result[materialName] = true
    count = count + 1
  end

  local function addFromRoadObjects(className, fieldName)
    for _, objectName in ipairs(scenetree.findClassObjects(className) or {}) do
      if count >= roadWetConfig.materialCap then
        return
      end
      local obj = scenetree.findObject(objectName)
      if obj and type(obj.getField) == "function" then
        local materialName = obj:getField(fieldName, 0)
        if not materialName or materialName == "" then
          materialName = obj:getField(fieldName, "")
        end
        add(materialName)
      end
    end
  end

  addFromRoadObjects("DecalRoad", "Material")
  addFromRoadObjects("MeshRoad", "topMaterial")
  for _, materialName in ipairs(scenetree.findClassObjects("Material") or {}) do
    if count >= roadWetConfig.materialCap then
      break
    end
    if M.weatherRuntime.nameContainsAny(materialName, roadWetConfig.materialWords) then
      add(materialName)
    end
  end
  return result
end

function M.weatherRuntime.darkenRoadColor(value, multiplier)
  local r, g, b, a
  if type(value) == "string" then
    r, g, b, a = value:match("([%-%d%.eE]+)[%s,]+([%-%d%.eE]+)[%s,]+([%-%d%.eE]+)[%s,]*([%-%d%.eE]*)")
  end
  r = tonumber(r) or 1
  g = tonumber(g) or 1
  b = tonumber(b) or 1
  a = tonumber(a) or 1
  return string.format("%g %g %g %g", r * multiplier, g * multiplier, b * multiplier, a)
end

function M.weatherRuntime.applyRoadVisualWetness(materialName, roughness)
  local material = scenetree and scenetree.findObject(materialName) or nil
  if not material or type(material.getField) ~= "function" or type(material.setField) ~= "function" then
    return
  end

  local layers = math.max(1, tonumber(material.activeLayers) or 1)
  state.roadWetSavedRoughness[materialName] = state.roadWetSavedRoughness[materialName] or {}
  state.roadWetSavedDiffuse[materialName] = state.roadWetSavedDiffuse[materialName] or {}
  state.roadVisualBaselineRoughness[materialName] = state.roadVisualBaselineRoughness[materialName] or {}
  state.roadVisualBaselineDiffuse[materialName] = state.roadVisualBaselineDiffuse[materialName] or {}
  local darkness = 0.6 + 0.35 * clamp((roughness - 0.07) / 0.43, 0, 1)
  for layer = 0, layers - 1 do
    if state.roadVisualBaselineRoughness[materialName][layer] == nil then
      state.roadVisualBaselineRoughness[materialName][layer] = { value = material:getField("roughnessFactor", layer) or "" }
    end
    if state.roadVisualBaselineDiffuse[materialName][layer] == nil then
      state.roadVisualBaselineDiffuse[materialName][layer] = { value = material:getField("diffuseColor", layer) or "" }
    end
    state.roadWetSavedRoughness[materialName][layer] = state.roadVisualBaselineRoughness[materialName][layer]
    state.roadWetSavedDiffuse[materialName][layer] = state.roadVisualBaselineDiffuse[materialName][layer]
    material:setField("roughnessFactor", layer, tostring(roughness))
    material:setField("diffuseColor", layer, M.weatherRuntime.darkenRoadColor(state.roadWetSavedDiffuse[materialName][layer].value, darkness))
  end
  if type(material.reload) == "function" then
    pcall(material.reload, material)
  end
end

function M.weatherRuntime.restoreRoadVisualMaterial(materialName)
  local material = scenetree and scenetree.findObject(materialName) or nil
  if not material or type(material.setField) ~= "function" then
    return
  end
  local roughnessBaseline = state.roadVisualBaselineRoughness[materialName] or state.roadWetSavedRoughness[materialName] or {}
  local diffuseBaseline = state.roadVisualBaselineDiffuse[materialName] or state.roadWetSavedDiffuse[materialName] or {}
  for layer, original in pairs(roughnessBaseline) do
    material:setField("roughnessFactor", layer, original.value ~= "" and original.value or "1")
  end
  for layer, original in pairs(diffuseBaseline) do
    material:setField("diffuseColor", layer, original.value ~= "" and original.value or "1 1 1 1")
  end
  if type(material.reload) == "function" then
    pcall(material.reload, material)
  end
end

function M.weatherRuntime.setRoadVisualWetnessTarget(roughness)
  roughness = tonumber(roughness) or 0
  if math.abs(roughness - (state.roadWetTargetRoughness or 0)) < 0.001 then
    return
  end
  state.roadWetTargetRoughness = roughness
  state.roadWetMaterialQueue = {}
  local source = roughness > 0 and M.weatherRuntime.collectRoadVisualMaterials() or state.roadWetSavedRoughness
  for materialName in pairs(source) do
    state.roadWetMaterialQueue[#state.roadWetMaterialQueue + 1] = materialName
  end
end

function M.weatherRuntime.updateRoadWetness(dt)
  local values = state.currentValues or {}
  local localIntensity = state.serverStormCell and clamp(state.localStormIntensity or 0, 0, 1) or 1
  local raining = values.rainEnabled == true
    and values.precipitationType == "rain"
    and (tonumber(values.rainAmount) or 0) > 0
    and localIntensity > 0.03
  local desiredRoughness = clamp((tonumber(values.roadWetRoughness) or 0) * localIntensity, 0, 1)
  if raining and desiredRoughness > 0 then
    state.roadWetness = math.min(1, (state.roadWetness or 0) + roadWetConfig.accumulationRate * dt * localIntensity)
    state.roadWetLastRainRoughness = desiredRoughness
  else
    state.roadWetness = math.max(0, (state.roadWetness or 0) - roadWetConfig.dryingRate * dt)
  end

  local visualRoughness = 0
  if state.roadWetness > 0.02 and (state.roadWetLastRainRoughness or 0) > 0 then
    local wetTarget = lerp(0.5, state.roadWetLastRainRoughness, state.roadWetness)
    visualRoughness = math.floor(wetTarget / 0.05 + 0.5) * 0.05
  end
  M.weatherRuntime.setRoadVisualWetnessTarget(visualRoughness)

  local materialName = table.remove(state.roadWetMaterialQueue)
  if materialName then
    if state.roadWetTargetRoughness > 0 then
      M.weatherRuntime.applyRoadVisualWetness(materialName, state.roadWetTargetRoughness)
    else
      M.weatherRuntime.restoreRoadVisualMaterial(materialName)
    end
    if #state.roadWetMaterialQueue == 0 then
      state.roadWetAppliedRoughness = state.roadWetTargetRoughness
      if state.roadWetTargetRoughness <= 0 then
        state.roadWetSavedRoughness = {}
        state.roadWetSavedDiffuse = {}
        state.roadWetLastRainRoughness = 0
      end
    end
  end
end

function M.weatherRuntime.restoreRoadVisualWetness()
  for materialName in pairs(state.roadWetSavedRoughness) do
    M.weatherRuntime.restoreRoadVisualMaterial(materialName)
  end
  state.roadWetness = 0
  state.roadWetTargetRoughness = 0
  state.roadWetAppliedRoughness = 0
  state.roadWetMaterialQueue = {}
  state.roadWetSavedRoughness = {}
  state.roadWetSavedDiffuse = {}
  state.roadWetLastRainRoughness = 0
end

function M.weatherRuntime.clearRainRoadEffects()
  state.rainfallAccumulation = 0
  state.aquaplaneTimer = 0
  M.weatherRuntime.applyRoadCondition("dry")
  M.weatherRuntime.restoreRoadVisualWetness()
end

function M.weatherRuntime.applyRoadCondition(condition)
  condition = (condition == "wet" or condition == "ice") and condition or "dry"
  if state.roadCondition == condition and (condition ~= "dry" or next(state.roadMaterialCache) == nil) then
    return
  end
  local changed = false
  for _, terrain in ipairs(M.weatherRuntime.findSceneObjectsByClass("TerrainBlock")) do
    if type(terrain.getMaterialCount) == "function" and type(terrain.getMaterial) == "function" then
      local terrainKey = tostring(terrain)
      local count = tonumber(terrain:getMaterialCount()) or 0
      for index = 0, count - 1 do
        local material = terrain:getMaterial(index)
        if material then
          local key = terrainKey .. ":" .. tostring(index)
          if condition == "dry" then
            local original = state.roadMaterialCache[key]
            if original then
              material.groundmodelName = original
              state.roadMaterialCache[key] = nil
              changed = true
            end
          else
            local current = tostring(material.groundmodelName or "")
            if wetRoadGroundModels[current] then
              state.roadMaterialCache[key] = state.roadMaterialCache[key] or dryRoadGroundModels[current] or current
              local target = condition == "ice" and "ICE" or "ASPHALT_WET"
              if current ~= target then
                material.groundmodelName = target
                changed = true
              end
            end
          end
        end
      end
    end
  end
  state.roadCondition = condition
  if changed and be and type(be.reloadCollision) == "function" then
    pcall(be.reloadCollision, be)
    writeLog("I", "Road condition changed to " .. condition)
  elseif not changed and condition ~= "dry" and not state.roadWarningShown then
    writeLog("I", "No compatible TerrainBlock asphalt materials found; dynamic road grip unavailable on this map")
    state.roadWarningShown = true
  end
end

local function applyStormSkyControls(intensity, values)
  intensity = clamp(tonumber(intensity) or 0, 0, 1)

  if not scenetree then
    return intensity
  end

  local function setFieldIfPossible(obj, field, value)
    if obj and type(obj.setField) == "function" then
      pcall(obj.setField, obj, field, 0, tostring(value))
      return true
    end
    return false
  end

  values = values or {}
  local cloudCover = clamp(tonumber(values.cloudCover) or (0.34 + intensity * 0.62), 0, 1)
  local cloudSpeed = clamp(0.1 + (tonumber(values.windSpeed) or intensity) * 0.12, 0.05, 2.5)
  local skyBrightness = clamp(tonumber(values.brightness) or (1.0 - intensity * 0.46), 0.05, 1.5)

  local skyObjectNames = {
    "sunsky",
    "SunSky",
    "theSun",
    "sun",
    "ScatterSky",
    "sky"
  }
  local appliedSkyObjects = {}

  for _, name in ipairs(skyObjectNames) do
    local obj = scenetree.findObject(name)
    local key = obj and tostring(obj) or nil
    if obj and not appliedSkyObjects[key] then
      appliedSkyObjects[key] = true
      setFieldIfPossible(obj, "brightness", skyBrightness)
      setFieldIfPossible(obj, "exposure", 0.72 + skyBrightness * 0.58)
      setFieldIfPossible(obj, "shadowSoftness", 0.18 + intensity * 0.62)
      M.weatherRuntime.postApplyObject(obj)
    end
  end

  for _, obj in ipairs(M.weatherRuntime.findSceneObjectsByClass("ScatterSky")) do
    local key = tostring(obj)
    if not appliedSkyObjects[key] then
      appliedSkyObjects[key] = true
      setFieldIfPossible(obj, "brightness", skyBrightness)
      setFieldIfPossible(obj, "exposure", 0.72 + skyBrightness * 0.58)
      setFieldIfPossible(obj, "shadowSoftness", 0.18 + intensity * 0.62)
      M.weatherRuntime.postApplyObject(obj)
    end
  end

  local cloudObjectNames = {
    "clouds",
    "Clouds",
    "cloudLayer",
    "CloudLayer",
    "cloudLayer0",
    "CloudLayer0",
    "cloudLayer1",
    "CloudLayer1"
  }
  local appliedCloudObjects = {}

  for _, name in ipairs(cloudObjectNames) do
    local obj = scenetree.findObject(name)
    local key = obj and tostring(obj) or nil
    if obj and not appliedCloudObjects[key] then
      appliedCloudObjects[key] = true
      setFieldIfPossible(obj, "coverage", cloudCover)
      setFieldIfPossible(obj, "cloudCover", cloudCover)
      setFieldIfPossible(obj, "windSpeed", cloudSpeed)
      setFieldIfPossible(obj, "baseColor", string.format("%0.3f %0.3f %0.3f 1", 0.74 - intensity * 0.32, 0.78 - intensity * 0.35, 0.82 - intensity * 0.38))
      M.weatherRuntime.postApplyObject(obj)
    end
  end

  for _, obj in ipairs(M.weatherRuntime.findSceneObjectsByClass("CloudLayer")) do
    local key = tostring(obj)
    if not appliedCloudObjects[key] then
      appliedCloudObjects[key] = true
      setFieldIfPossible(obj, "coverage", cloudCover)
      setFieldIfPossible(obj, "windSpeed", cloudSpeed)
      setFieldIfPossible(obj, "baseColor", string.format("%0.3f %0.3f %0.3f 1", 0.74 - intensity * 0.32, 0.78 - intensity * 0.35, 0.82 - intensity * 0.38))
      M.weatherRuntime.postApplyObject(obj)
    end
  end

  return intensity
end

local function toggleRainObjects(enabled)
  local config = getLevelConfig()
  local changed = 0

  if not scenetree or not config or not config.rainObjects then
    return changed
  end

  for _, name in ipairs(config.rainObjects) do
    local obj = scenetree.findObject(name)
    if obj and setObjectHidden(obj, not enabled) then
      changed = changed + 1
    end
  end

  state.rainObjectsActive = enabled
  if enabled and changed == 0 then
    writeLog("W", "No mapped rain scene objects found; using fallback rain streak renderer")
  end
  return changed
end

local function pulseLightningObjects()
  local config = getLevelConfig()
  if not scenetree or not config or not config.lightningObjects then
    return
  end

  for _, name in ipairs(config.lightningObjects) do
    local obj = scenetree.findObject(name)
    if obj then
      setObjectActive(obj, true)
    end
  end
end

local function clearLightningObjects()
  local config = getLevelConfig()
  if not scenetree or not config or not config.lightningObjects then
    return
  end

  for _, name in ipairs(config.lightningObjects) do
    local obj = scenetree.findObject(name)
    if obj then
      setObjectActive(obj, false)
    end
  end
end

local function tryReadJsonFile(path)
  if type(readJsonFile) ~= "function" then
    return nil
  end

  local ok, data = pcall(readJsonFile, path)
  if ok then
    return data
  end
  return nil
end

local function tryWriteJsonFile(path, data)
  if type(serializeJsonToFile) == "function" then
    local ok = pcall(serializeJsonToFile, path, data, true)
    if ok then
      return true
    end
  end

  if type(jsonEncode) == "function" and type(writeFile) == "function" then
    local ok, encoded = pcall(jsonEncode, data)
    if ok and type(encoded) == "string" then
      local writeOk = pcall(writeFile, path, encoded)
      if writeOk then
        return true
      end
    end
  end

  return false
end

local function normalizeProfile(profileId, profile)
  if type(profile) ~= "table" then
    return nil
  end

  local base = cloneTable(builtinWeatherProfiles[profileId] or {})
  for key, value in pairs(profile) do
    base[key] = value
  end

  base.id = tostring(base.id or profileId)
  base.label = tostring(base.label or base.id)
  base.tod = clamp(tonumber(base.tod) or 0.5, 0, 1)
  base.windSpeed = math.max(0, tonumber(base.windSpeed) or 0)
  base.fogDensity = math.max(0, tonumber(base.fogDensity) or 0)
  base.rainEnabled = base.rainEnabled == true
  base.rainAmount = math.max(0, tonumber(base.rainAmount) or (base.rainEnabled and 1000 or 0))
  base.precipitationType = (base.precipitationType == "snow" or base.precipitationType == "hail") and base.precipitationType or "rain"
  base.cloudCover = clamp(tonumber(base.cloudCover) or 0.3, 0, 4)
  base.temperatureC = clamp(tonumber(base.temperatureC) or 15, -40, 55)
  base.brightness = clamp(tonumber(base.brightness) or 1, 0.05, 1.5)
  base.roadCondition = (base.roadCondition == "wet" or base.roadCondition == "ice") and base.roadCondition or "dry"
  base.roadWetRoughness = clamp(tonumber(base.roadWetRoughness) or 0, 0, 1)
  base.maxWaterRise = clamp(tonumber(base.maxWaterRise) or 0, 0, 10)
  base.waterRiseRate = clamp(tonumber(base.waterRiseRate) or 0, 0, 5)
  base.burstMinInterval = math.max(2, tonumber(base.burstMinInterval) or 30)
  base.burstMaxInterval = math.max(base.burstMinInterval, tonumber(base.burstMaxInterval) or base.burstMinInterval)
  base.burstMinMultiplier = math.max(1, tonumber(base.burstMinMultiplier) or 1.1)
  base.burstMaxMultiplier = math.max(base.burstMinMultiplier, tonumber(base.burstMaxMultiplier) or base.burstMinMultiplier)
  base.weight = math.max(0, tonumber(base.weight) or 1)
  base.minDuration = math.max(1, tonumber(base.minDuration) or 120)
  base.maxDuration = math.max(base.minDuration, tonumber(base.maxDuration) or base.minDuration)

  return base
end

local function mergeExternalProfiles(data)
  if type(data) ~= "table" then
    return 0
  end

  local source = type(data.profiles) == "table" and data.profiles or data
  local changed = 0
  for profileId, profile in pairs(source) do
    local id = sanitizeId(profileId)
    local normalized = normalizeProfile(id, profile)
    if normalized then
      weatherProfiles[id] = normalized
      changed = changed + 1
    end
  end
  return changed
end

local function normalizeStringArray(value)
  if type(value) ~= "table" then
    return nil
  end

  local result = {}
  for _, item in ipairs(value) do
    if type(item) == "string" and item ~= "" then
      result[#result + 1] = item
    end
  end
  return result
end

local function mergeExternalLevelOverrides(data)
  if type(data) ~= "table" then
    return 0
  end

  local source = type(data.levels) == "table" and data.levels or data
  local changed = 0
  for levelId, config in pairs(source) do
    if type(config) == "table" then
      local id = sanitizeId(levelId)
      local merged = cloneTable(levelOverrides[id] or {})
      for key, value in pairs(config) do
        merged[key] = value
      end

      merged.label = tostring(merged.label or id)
      merged.presetOrder = normalizeStringArray(merged.presetOrder) or cloneTable(levelOverrides.default.presetOrder)
      merged.rainObjects = normalizeStringArray(merged.rainObjects) or {}
      merged.lightningObjects = normalizeStringArray(merged.lightningObjects) or {}
      merged.profileWeights = type(merged.profileWeights) == "table" and merged.profileWeights or {}
      for profileId, weight in pairs(merged.profileWeights) do
        merged.profileWeights[profileId] = math.max(0, tonumber(weight) or 0)
      end
      merged.transitionMin = math.max(1, tonumber(merged.transitionMin) or 18)
      merged.transitionMax = math.max(merged.transitionMin, tonumber(merged.transitionMax) or merged.transitionMin)
      merged.startupProfile = weatherProfiles[merged.startupProfile] and merged.startupProfile or "clear"

      levelOverrides[id] = merged
      changed = changed + 1
    end
  end
  return changed
end

local function loadExternalWeatherConfig()
  weatherProfiles = cloneTable(builtinWeatherProfiles)
  levelOverrides = cloneTable(builtinLevelOverrides)

  local profileCount = mergeExternalProfiles(tryReadJsonFile("settings/ashWeather/profiles.json"))
  local levelCount = mergeExternalLevelOverrides(tryReadJsonFile("settings/ashWeather/levels.json"))

  if profileCount > 0 or levelCount > 0 then
    writeLog("I", string.format("Loaded external weather config (%d profiles, %d level overrides)", profileCount, levelCount))
  end
end

local function getTimeOfDayState()
  local ok, currentTod = tryCoreEnvironment("getTimeOfDay")
  if ok and type(currentTod) == "table" then
    return currentTod
  end

  return {
    time = state.currentValues.tod or 0.5,
    play = false,
    dayScale = 1,
    nightScale = 1,
    dayLength = 1200,
    azimuthOverride = nil
  }
end

local function getStormVisualIntensity()
  local intensity = 0

  if state.heavyStormMode then
    intensity = math.max(intensity, 1.0)
  end

  if state.lightningFlash then
    intensity = math.max(intensity, 0.85)
  end

  if state.stormAmbienceTimer and state.stormAmbienceTimer > 0 then
    intensity = math.max(intensity, clamp(state.stormAmbienceTimer / 7.0, 0, 1))
  end

  if getCurrentBaseProfileId() == "supercell" then
    intensity = math.max(intensity, 0.82)
  elseif getCurrentBaseProfileId() == "hail" then
    intensity = math.max(intensity, 0.64)
  elseif getCurrentBaseProfileId() == "storm" then
    intensity = math.max(intensity, 0.45)
  elseif getCurrentBaseProfileId() == "rain" then
    intensity = math.max(intensity, 0.22)
  end

  return intensity
end

local function getWindDirectionTiming(profileId)
  if profileId == "rain" or profileId == "drizzle" or profileId == "overcast" or profileId == "snow" then
    return 0.25, 90, 24
  elseif profileId == "storm" then
    return 0.45, 75, 22
  elseif profileId == "hail" then
    return 0.65, 65, 20
  elseif profileId == "supercell" then
    return 0.95, 60, 18
  end
  return 0, 120, 30
end

local function getWindVector(windSpeed)
  local speed = tonumber(windSpeed) or 0
  if speed <= 0.001 then
    return 0, 0, 0
  end

  local angle = state.windDirectionRadians or 0
  return math.cos(angle) * speed, math.sin(angle) * speed, speed
end

local function applyWindDirection(windSpeed)
  local x, y, speed = getWindVector(windSpeed)
  tryCoreEnvironment("setWindSpeed", speed)
  local groundWindApplied = tryCoreEnvironment("setGroundWind", x, y, 0)
  if not groundWindApplied then
    tryCoreEnvironment("setWind", x, y, 0)
  end
  if speed > 0.001 then
    tryCoreEnvironment("setCloudWindDirection", x / speed, y / speed)
  end
  state.appliedWindSpeed = speed
end

local function updateWindDirection(dt)
  local profileId = getCurrentBaseProfileId()
  local turnRange, interval, turnDuration = getWindDirectionTiming(profileId)

  if state.windDirectionTargetRadians == nil then
    state.windDirectionTargetRadians = state.windDirectionRadians or 0
  end

  if (state.windDirectionTurnElapsed or 0) < (state.windDirectionTurnDuration or turnDuration) then
    state.windDirectionTurnElapsed = math.min(
      (state.windDirectionTurnElapsed or 0) + dt,
      state.windDirectionTurnDuration or turnDuration
    )
    local progress = state.windDirectionTurnElapsed / math.max(0.01, state.windDirectionTurnDuration or turnDuration)
    local eased = progress * progress * (3 - 2 * progress)
    local startAngle = state.windDirectionStartRadians or state.windDirectionRadians or 0
    local targetAngle = state.windDirectionTargetRadians or startAngle
    local delta = ((targetAngle - startAngle + math.pi) % (math.pi * 2)) - math.pi
    state.windDirectionRadians = startAngle + delta * eased
    applyWeatherValues(state.currentValues)
  end

  state.windDirectionTimer = (state.windDirectionTimer or 0) + dt
  if state.windDirectionTimer >= interval then
    state.windDirectionTimer = 0
    state.windDirectionChangeInterval = interval
    state.windDirectionStartRadians = state.windDirectionRadians or 0
    state.windDirectionTargetRadians = state.windDirectionStartRadians + (math.random() * 2 - 1) * math.pi * turnRange
    state.windDirectionTurnElapsed = 0
    state.windDirectionTurnDuration = turnDuration
  end
end

applyWeatherValues = function(values)
  if values ~= state.currentValues then
    state.currentValues = {
      tod = values.tod,
      windSpeed = values.windSpeed,
      fogDensity = values.fogDensity,
      rainEnabled = values.rainEnabled,
      rainAmount = values.rainAmount,
      precipitationType = values.precipitationType,
      cloudCover = values.cloudCover,
      temperatureC = values.temperatureC,
      brightness = values.brightness,
      roadCondition = values.roadCondition,
      roadWetRoughness = values.roadWetRoughness,
      maxWaterRise = values.maxWaterRise,
      waterRiseRate = values.waterRiseRate
    }
  end
  values = state.currentValues
  state.environmentApplyPending = true
  if (state.environmentApplyElapsed or 0) < (state.environmentApplyInterval or 0.10) then
    return
  end
  state.environmentApplyElapsed = 0
  state.environmentApplyPending = false

  local tod = getTimeOfDayState()
  -- Weather changes visibility and brightness, but never controls the clock.
  local appliedTod = tod.time or values.tod or 0.5
  local appliedFogDensity = values.fogDensity
  local appliedWindSpeed = values.windSpeed
  local appliedRainEnabled = values.rainEnabled
  local localStormIntensity = state.serverStormCell and clamp(state.localStormIntensity or 0, 0, 1) or 1
  if state.serverStormCell then
    if appliedWindSpeed ~= nil then appliedWindSpeed = appliedWindSpeed * (0.12 + localStormIntensity * 0.88) end
    if appliedFogDensity ~= nil then appliedFogDensity = appliedFogDensity * (0.18 + localStormIntensity * 0.82) end
    appliedRainEnabled = appliedRainEnabled and localStormIntensity > 0.03
  end

  if state.lightningEnvironment and appliedWindSpeed ~= nil then
    appliedWindSpeed = appliedWindSpeed * (1 + state.lightningEnvironment.windBoost)
  end

  if state.burst and state.burst.active and appliedWindSpeed ~= nil then
    appliedWindSpeed = appliedWindSpeed * state.burst.multiplier
  end

  if state.severeWindBoost and appliedWindSpeed ~= nil then
    appliedWindSpeed = appliedWindSpeed * state.severeWindBoost.multiplier
  end

  local nativeStateApplied = false
  if supportsNativeEnvironmentState() then
    local windX, windY, windSpeed = getWindVector(appliedWindSpeed)
    local environmentState = {
      time = appliedTod,
      play = tod.play == true,
      windSpeed = windSpeed,
      groundWind = { x = windX, y = windY, z = 0 },
      cloudCover = state.serverStormCell and ((tonumber(values.cloudCover) or 0) * (0.25 + localStormIntensity * 0.75)) or values.cloudCover
    }
    if windSpeed > 0.001 then
      environmentState.cloudWindDirection = { x = windX / windSpeed, y = windY / windSpeed, z = 0 }
    end
    if appliedFogDensity ~= nil then
      environmentState.fogDensity = appliedFogDensity * 1000
    end

    nativeStateApplied = tryCoreEnvironment("setState", environmentState)
    if nativeStateApplied then
      state.appliedWindSpeed = windSpeed
      if not state.environmentStateApiLogged then
        state.environmentStateApiLogged = true
        writeLog("I", "Using BeamNG 0.39 environment state and physics ground wind APIs")
      end
    end
  end

  if not nativeStateApplied then
    tryCoreEnvironment("setTimeOfDay", {
      time = appliedTod,
      play = tod.play == true
    })
    if appliedFogDensity ~= nil then
      tryCoreEnvironment("setFogDensity", appliedFogDensity)
    end
    applyStormSkyControls(getStormVisualIntensity(), values)
    if appliedWindSpeed ~= nil then
      applyWindDirection(appliedWindSpeed)
    end
  end

  if appliedWindSpeed ~= nil then
    M.weatherRuntime.applyForestWind(appliedWindSpeed)
  end

  local precipitationValues = values
  if state.serverStormCell then
    precipitationValues = cloneTable(values)
    precipitationValues.rainEnabled = appliedRainEnabled
    precipitationValues.rainAmount = (tonumber(values.rainAmount) or 0) * localStormIntensity
  end
  local dynamicPrecipitationReady = M.weatherRuntime.applyDynamicPrecipitation(precipitationValues)
  if dynamicPrecipitationReady then
    if state.rainObjectsActive then
      toggleRainObjects(false)
    end
  elseif state.rainObjectsActive ~= appliedRainEnabled then
    toggleRainObjects(appliedRainEnabled)
  end

  M.weatherRuntime.applyTemperature(values.temperatureC)
  local localRoadCondition = values.roadCondition
  if state.serverStormCell and localStormIntensity < 0.12 then localRoadCondition = "dry" end
  M.weatherRuntime.applyRoadCondition(localRoadCondition)

end

function M.weatherRuntime.preserveTimeOfDay(timeValue)
  local preservedTime = tonumber(timeValue)
  if not preservedTime or type(state.currentValues) ~= "table" then
    return false
  end

  state.currentValues.tod = clamp(preservedTime, 0, 1)
  state.environmentApplyElapsed = state.environmentApplyInterval or 0.10
  applyWeatherValues(state.currentValues)
  return true
end

local function buildProfileSnapshot(profileId)
  local profile = getProfile(profileId)
  return {
    tod = profile.tod,
    windSpeed = profile.windSpeed,
    fogDensity = profile.fogDensity,
    rainEnabled = profile.rainEnabled,
    rainAmount = profile.rainAmount,
    precipitationType = profile.precipitationType,
    cloudCover = profile.cloudCover,
    temperatureC = profile.temperatureC,
    brightness = profile.brightness,
    roadCondition = profile.roadCondition,
    roadWetRoughness = profile.roadWetRoughness,
    maxWaterRise = profile.maxWaterRise,
    waterRiseRate = profile.waterRiseRate
  }
end

local function getPlayerVehicle()
  if not be or type(be.getPlayerVehicle) ~= "function" then
    return nil
  end

  local ok, veh = pcall(be.getPlayerVehicle, be, 0)
  if ok and veh then
    return veh
  end
  return nil
end

local function getPlayerPosition()
  local veh = getPlayerVehicle()
  if veh and type(veh.getPosition) == "function" then
    local ok, pos = pcall(veh.getPosition, veh)
    if ok and pos then
      local wrapped = vec3(pos)
      return wrapped
    end
  end
  return vec3(0, 0, 0)
end

function M.weatherRuntime.updateServerStormCell(dt)
  local cell = state.serverStormCell
  if not cell then
    state.localStormIntensity = 1
    return
  end
  cell.x = cell.x + (cell.vx or 0) * dt
  cell.y = cell.y + (cell.vy or 0) * dt
  local position = getPlayerPosition()
  local dx, dy = position.x - cell.x, position.y - cell.y
  local distance = math.sqrt(dx * dx + dy * dy)
  local radius = math.max(1, cell.radius or 460)
  local edgeFade = math.min(radius, math.max(1, cell.edgeFade or 180))
  local innerRadius = math.max(0, radius - edgeFade)
  local intensity
  if distance <= innerRadius then
    intensity = 1
  elseif distance >= radius then
    intensity = 0
  else
    local normalized = 1 - ((distance - innerRadius) / edgeFade)
    intensity = normalized * normalized * (3 - 2 * normalized)
  end
  state.localStormIntensity = clamp(intensity * (cell.intensity or 1), 0, 1)
end

local function getVehiclePosition(veh)
  if veh and type(veh.getPosition) == "function" then
    local ok, pos = pcall(veh.getPosition, veh)
    if ok and pos then
      return vec3(pos)
    end
  end
  return nil
end

local function getDistanceToPlayer(position)
  local playerPos = getPlayerPosition()
  return (position - playerPos):length()
end

local function getHorizontalDistanceToPlayer(position)
  local playerPos = getPlayerPosition()
  local dx = position.x - playerPos.x
  local dy = position.y - playerPos.y
  return math.sqrt(dx * dx + dy * dy)
end

local function getPerceivedStrikeDistance(position)
  local horizontalDistance = getHorizontalDistanceToPlayer(position)
  return math.max(0, horizontalDistance - 6.5)
end

getCurrentBaseProfileId = function()
  if state.targetProfileId then
    return state.targetProfileId
  end
  return state.activeProfileId
end

local function getGroundHeightBelow(position)
  if be and type(be.getSurfaceHeightBelow) == "function" then
    local ok, height = pcall(be.getSurfaceHeightBelow, be, position)
    if ok and type(height) == "number" then
      return height
    end
  end
  return position.z
end

local function resolveLightningRayHit(startPos, endPos)
  if type(castRay) ~= "function" then
    return nil
  end

  local ok, hit = pcall(castRay, startPos, endPos, true, true)
  if ok and hit and hit.pt then
    return hit
  end
  return nil
end

local function buildLightningPolyline(startPos, endPos, segments, offsetScale)
  local points = {}
  local direction = endPos - startPos
  local right = vec3(1, 0, 0)
  if math.abs(direction.x) > 0.1 or math.abs(direction.y) > 0.1 then
    right = vec3(-direction.y, direction.x, 0):normalized()
  end
  local forward = vec3(direction.x, direction.y, 0)
  if forward:length() < 0.001 then
    forward = vec3(0, 1, 0)
  else
    forward = forward:normalized()
  end

  for index = 0, segments do
    local t = index / segments
    local point = startPos + direction * t
    if index ~= 0 and index ~= segments then
      local horizontalJitter = (math.random() * 2 - 1) * offsetScale * (1 - t * 0.55)
      local forwardJitter = (math.random() * 2 - 1) * offsetScale * 0.35
      point = point + right * horizontalJitter + forward * forwardJitter
    end
    points[#points + 1] = point
  end

  return points
end

local function buildOffsetLightningLayer(points, jitterScale)
  local layered = {}
  for index, point in ipairs(points) do
    local offsetPoint = vec3(point)
    if index ~= 1 and index ~= #points then
      offsetPoint = offsetPoint + vec3(
        (math.random() * 2 - 1) * jitterScale,
        (math.random() * 2 - 1) * jitterScale,
        (math.random() * 2 - 1) * jitterScale * 0.35
      )
    end
    layered[#layered + 1] = offsetPoint
  end
  return layered
end

local lightningColorPalettes = {
  {
    name = "blue",
    leader = { 0.58, 0.78, 1.00 },
    branch = { 0.64, 0.84, 1.00 },
    bolt = { 0.70, 0.90, 1.00 },
    core = { 0.92, 0.98, 1.00 },
    shell = { 0.38, 0.62, 1.00 },
    cloud = { 0.54, 0.72, 1.00 }
  },
  {
    name = "white",
    leader = { 0.90, 0.94, 1.00 },
    branch = { 0.92, 0.96, 1.00 },
    bolt = { 0.96, 0.99, 1.00 },
    core = { 1.00, 1.00, 1.00 },
    shell = { 0.82, 0.90, 1.00 },
    cloud = { 0.88, 0.94, 1.00 }
  },
  {
    name = "orange",
    leader = { 1.00, 0.58, 0.22 },
    branch = { 1.00, 0.66, 0.30 },
    bolt = { 1.00, 0.76, 0.36 },
    core = { 1.00, 0.95, 0.74 },
    shell = { 1.00, 0.42, 0.12 },
    cloud = { 1.00, 0.52, 0.18 }
  },
  {
    name = "red",
    leader = { 1.00, 0.26, 0.20 },
    branch = { 1.00, 0.34, 0.28 },
    bolt = { 1.00, 0.48, 0.38 },
    core = { 1.00, 0.88, 0.82 },
    shell = { 0.95, 0.10, 0.08 },
    cloud = { 1.00, 0.20, 0.16 }
  },
  {
    name = "yellow",
    leader = { 1.00, 0.86, 0.30 },
    branch = { 1.00, 0.90, 0.42 },
    bolt = { 1.00, 0.96, 0.55 },
    core = { 1.00, 1.00, 0.86 },
    shell = { 1.00, 0.74, 0.16 },
    cloud = { 1.00, 0.86, 0.28 }
  }
}

local function pickLightningColorPalette()
  return lightningColorPalettes[math.random(#lightningColorPalettes)] or lightningColorPalettes[2]
end

local function paletteColor(palette, key, alpha)
  local color = (palette and palette[key]) or lightningColorPalettes[2][key] or { 1, 1, 1 }
  return ColorF(color[1], color[2], color[3], alpha)
end

local LIGHTNING_RIBBON_MATERIAL = "ashWeather_thor_lightning_ribbon_v5"
local LIGHTNING_RIBBON_HALO_MATERIAL = "ashWeather_thor_lightning_halo_v3"
local LIGHTNING_RIBBON_HOTCORE_MATERIAL = "ashWeather_thor_lightning_hotcore_v1"
local LIGHTNING_RIBBON_MATERIAL_FILE = "/art/ashWeather/lightningMaterials.cs"
local LIGHTNING_ATLAS_FRAME_COUNT = 32
local LIGHTNING_ATLAS_FRAMES_PER_SECOND = 30
local LIGHTNING_PARTICLE_DATA_FILE = "art/ashWeather/lightningParticleData.json"
local LIGHTNING_PARTICLE_EMITTER_FILE = "art/ashWeather/lightningParticleEmitterData.json"
local lightningRibbonMaterialLoaded = false
local lightningRibbonMaterialWarningShown = false
local lightningRibbonSpawnLogged = false
local lightningImpactParticlesLoaded = false
local lightningImpactParticleWarningShown = false

local function lightningRibbonMaterialAvailable()
  return scenetree
    and type(scenetree.findObject) == "function"
    and scenetree.findObject(LIGHTNING_RIBBON_MATERIAL) ~= nil
    and scenetree.findObject(LIGHTNING_RIBBON_HALO_MATERIAL) ~= nil
    and scenetree.findObject(LIGHTNING_RIBBON_HOTCORE_MATERIAL) ~= nil
end

local function ensureLightningRibbonMaterial()
  if lightningRibbonMaterialLoaded and lightningRibbonMaterialAvailable() then
    return true
  end

  if TorqueScriptLua and type(TorqueScriptLua.exec) == "function" then
    pcall(TorqueScriptLua.exec, LIGHTNING_RIBBON_MATERIAL_FILE)
    if lightningRibbonMaterialAvailable() then
      lightningRibbonMaterialLoaded = true
      lightningRibbonMaterialWarningShown = false
      writeLog("I", "Loaded Thor lightning ribbon material")
      return true
    end
  end

  if not lightningRibbonMaterialWarningShown then
    writeLog("W", "Thor lightning ribbon material is unavailable; using scripted lightning lines")
    lightningRibbonMaterialWarningShown = true
  end
  return false
end

local function lightningImpactParticlesAvailable()
  return scenetree
    and type(scenetree.findObject) == "function"
    and scenetree.findObject("AshWeatherLightningCoronaEmitter") ~= nil
    and scenetree.findObject("AshWeatherMetalSparkEmitter") ~= nil
end

local function ensureLightningImpactParticles()
  if lightningImpactParticlesLoaded and lightningImpactParticlesAvailable() then
    return true
  end
  if type(loadJsonMaterialsFile) == "function" then
    pcall(loadJsonMaterialsFile, LIGHTNING_PARTICLE_DATA_FILE)
    pcall(loadJsonMaterialsFile, LIGHTNING_PARTICLE_EMITTER_FILE)
    if lightningImpactParticlesAvailable() then
      lightningImpactParticlesLoaded = true
      lightningImpactParticleWarningShown = false
      writeLog("I", "Loaded AshWeather lightning corona and spark particles")
      return true
    end
  end
  if not lightningImpactParticleWarningShown then
    writeLog("W", "AshWeather lightning impact particles are unavailable; using base impact particles")
    lightningImpactParticleWarningShown = true
  end
  return false
end

local function deleteLightningRibbonMesh(meshObj)
  if not meshObj then
    return
  end
  pcall(function()
    local sceneObject = meshObj.obj
    if sceneObject and type(sceneObject.delete) == "function" then
      sceneObject:delete()
    elseif type(meshObj.delete) == "function" then
      meshObj:delete()
    end
  end)
end

local function buildLightningRibbonMesh(points, width, cameraPos, material, atlasFrame)
  if not points or #points < 2 then
    return nil
  end

  local verts = {}
  local uvs = {}
  local normals = {}
  local faces = {}
  local distances = { 0 }
  local totalDistance = 0
  local frame = math.floor(tonumber(atlasFrame) or 0) % LIGHTNING_ATLAS_FRAME_COUNT
  local frameU0 = frame / LIGHTNING_ATLAS_FRAME_COUNT
  local frameU1 = (frame + 1) / LIGHTNING_ATLAS_FRAME_COUNT

  for index = 2, #points do
    totalDistance = totalDistance + points[index]:distance(points[index - 1])
    distances[index] = totalDistance
  end

  for index, point in ipairs(points) do
    local previousPoint = points[math.max(1, index - 1)]
    local nextPoint = points[math.min(#points, index + 1)]
    local tangent = nextPoint - previousPoint
    if tangent:length() < 0.0001 then
      tangent = vec3(0, 0, -1)
    else
      tangent:normalize()
    end

    local viewDirection = cameraPos - point
    if viewDirection:length() < 0.0001 then
      viewDirection = vec3(0, -1, 0)
    else
      viewDirection:normalize()
    end

    local side = tangent:cross(viewDirection)
    if side:length() < 0.0001 then
      side = tangent:cross(vec3(0, 1, 0))
    end
    if side:length() < 0.0001 then
      side = vec3(1, 0, 0)
    else
      side:normalize()
    end

    local halfWidth = width * 0.5
    local leftPoint = point - side * halfWidth
    local rightPoint = point + side * halfWidth
    local v = totalDistance > 0 and (distances[index] / totalDistance) or 0

    verts[#verts + 1] = { x = leftPoint.x, y = leftPoint.y, z = leftPoint.z }
    verts[#verts + 1] = { x = rightPoint.x, y = rightPoint.y, z = rightPoint.z }
    normals[#normals + 1] = { x = viewDirection.x, y = viewDirection.y, z = viewDirection.z }
    normals[#normals + 1] = { x = viewDirection.x, y = viewDirection.y, z = viewDirection.z }
    uvs[#uvs + 1] = { u = frameU0, v = v }
    uvs[#uvs + 1] = { u = frameU1, v = v }
  end

  for index = 0, #points - 2 do
    local a = index * 2
    local b = a + 1
    local c = a + 2
    local d = a + 3
    faces[#faces + 1] = { v = a, u = a, n = a }
    faces[#faces + 1] = { v = c, u = c, n = c }
    faces[#faces + 1] = { v = d, u = d, n = d }
    faces[#faces + 1] = { v = a, u = a, n = a }
    faces[#faces + 1] = { v = d, u = d, n = d }
    faces[#faces + 1] = { v = b, u = b, n = b }
  end

  return {
    verts = verts,
    uvs = uvs,
    normals = normals,
    faces = faces,
    material = material or LIGHTNING_RIBBON_MATERIAL
  }
end

local function copyLightningRibbonPoints(points)
  local copied = {}
  for index, point in ipairs(points or {}) do
    copied[index] = vec3(point)
  end
  return copied
end

local function animateLightningRibbonPoints(points, age, amplitude, phase)
  local animated = {}
  local pointCount = #points
  for index, point in ipairs(points) do
    local animatedPoint = vec3(point)
    if index > 1 and index < pointCount then
      local wave = age * 54 + index * 1.73 + phase
      animatedPoint = animatedPoint + vec3(
        math.sin(wave) * amplitude,
        math.cos(wave * 1.31) * amplitude * 0.72,
        math.sin(wave * 0.83) * amplitude * 0.20
      )
    end
    animated[index] = animatedPoint
  end
  return animated
end

local function getLightningReturnStrokePulse(age)
  local strokeStarts = { 0, 0.09, 0.17 }
  local strokeDurations = { 0.070, 0.052, 0.046 }
  local strongestPulse = 0
  local strokeIndex = 1
  for index, startTime in ipairs(strokeStarts) do
    local progress = (age - startTime) / strokeDurations[index]
    if progress >= 0 and progress <= 1 then
      local pulse = (1 - progress) ^ 0.55
      if pulse > strongestPulse then
        strongestPulse = pulse
        strokeIndex = index
      end
    end
  end
  return strongestPulse, strokeIndex
end

local function buildAnimatedLightningRibbonMeshes(paths, age, cameraPos)
  local meshes = {}
  local strokePulse, strokeIndex = getLightningReturnStrokePulse(age)
  local visibility = 0.10 + strokePulse * 0.90
  for _, path in ipairs(paths or {}) do
    local movementPhase = path.phase + (strokeIndex - 1) * 2.31
    local movementScale = path.width * (0.038 + strokePulse * 0.018)
    local points = animateLightningRibbonPoints(path.points, age, movementScale, movementPhase)
    local atlasFrame = (24 + math.floor(age * LIGHTNING_ATLAS_FRAMES_PER_SECOND + path.phase * 3) + (strokeIndex - 1) * 7) % LIGHTNING_ATLAS_FRAME_COUNT
    local corePulse = (0.96 + math.sin(age * 48 + path.phase) * 0.10) * visibility
    local alignedWidth = path.width * corePulse
    local haloMesh = buildLightningRibbonMesh(
      points,
      alignedWidth,
      cameraPos,
      LIGHTNING_RIBBON_HALO_MATERIAL,
      atlasFrame
    )
    local coreMesh = buildLightningRibbonMesh(
      points,
      alignedWidth,
      cameraPos,
      LIGHTNING_RIBBON_MATERIAL,
      atlasFrame
    )
    local hotCoreMesh = buildLightningRibbonMesh(
      points,
      alignedWidth,
      cameraPos,
      LIGHTNING_RIBBON_HOTCORE_MATERIAL,
      atlasFrame
    )
    if haloMesh then
      meshes[#meshes + 1] = haloMesh
    end
    if coreMesh then
      meshes[#meshes + 1] = coreMesh
    end
    if hotCoreMesh then
      meshes[#meshes + 1] = hotCoreMesh
    end
  end
  return meshes
end

local function spawnTexturedLightningRibbons(strike)
  if not strike or not ensureLightningRibbonMaterial() or not createObject then
    return false
  end

  local cameraPos = strike.impactPoint + vec3(0, -100, 25)
  if core_camera and type(core_camera.getPosition) == "function" then
    cameraPos = vec3(core_camera.getPosition())
  end

  local paths = {}
  local strikeHeight = (strike.startPoint - strike.impactPoint):length()
  local mainWidth = clamp(strikeHeight * 0.12, 18, 32)
  if strike.mainBolt and #strike.mainBolt >= 2 then
    paths[#paths + 1] = {
      points = copyLightningRibbonPoints(strike.mainBolt),
      width = mainWidth,
      phase = 0.35
    }
  end

  for index, branch in ipairs(strike.branches or {}) do
    if #branch >= 2 then
      paths[#paths + 1] = {
        points = copyLightningRibbonPoints(branch),
        width = mainWidth * 0.48,
        phase = index * 0.91 + 1.2
      }
    end
  end
  for index, branch in ipairs(strike.upperBranches or {}) do
    if #branch >= 2 then
      paths[#paths + 1] = {
        points = copyLightningRibbonPoints(branch),
        width = mainWidth * 0.36,
        phase = index * 1.17 + 2.4
      }
    end
  end

  if #paths == 0 then
    return false
  end

  local meshes = buildAnimatedLightningRibbonMeshes(paths, 0, cameraPos)

  local ok, meshObj = pcall(createObject, "ProceduralMesh")
  if not ok or not meshObj or type(meshObj.createMesh) ~= "function" then
    return false
  end

  meshObj:setPosition(vec3(0, 0, 0))
  meshObj.canSave = false
  local registered = pcall(meshObj.registerObject, meshObj, nextUniqueObjectName("ashweather_lightning_ribbon"))
  if not registered then
    deleteLightningRibbonMesh(meshObj)
    return false
  end
  if scenetree and scenetree.MissionGroup then
    scenetree.MissionGroup:addObject(meshObj.obj)
  end

  local created = pcall(meshObj.createMesh, meshObj, { meshes })
  if not created then
    deleteLightningRibbonMesh(meshObj)
    return false
  end

  state.activeLightningRibbonMeshes[#state.activeLightningRibbonMeshes + 1] = {
    obj = meshObj,
    age = 0,
    duration = math.max(0.65, (strike.duration or 0.28) + (strike.impactDuration or 0.30)),
    paths = paths,
    cameraPos = cameraPos,
    updateTimer = 0,
    updateInterval = 1 / LIGHTNING_ATLAS_FRAMES_PER_SECOND
  }
  if not lightningRibbonSpawnLogged then
    writeLog("I", string.format("Spawned Thor lightning ribbon with %d textured surfaces at %.1fm width", #meshes, mainWidth))
    lightningRibbonSpawnLogged = true
  end
  return true
end

local function updateLightningRibbonMeshes(dt)
  for index = #state.activeLightningRibbonMeshes, 1, -1 do
    local entry = state.activeLightningRibbonMeshes[index]
    entry.age = entry.age + dt
    if entry.age >= entry.duration then
      deleteLightningRibbonMesh(entry.obj)
      table.remove(state.activeLightningRibbonMeshes, index)
    else
      entry.updateTimer = (entry.updateTimer or 0) + dt
      if entry.updateTimer >= entry.updateInterval then
        entry.updateTimer = entry.updateTimer - entry.updateInterval
        if core_camera and type(core_camera.getPosition) == "function" then
          entry.cameraPos = vec3(core_camera.getPosition())
        end
        local meshes = buildAnimatedLightningRibbonMeshes(entry.paths, entry.age, entry.cameraPos)
        if #meshes > 0 then
          local updated = pcall(function()
            entry.obj:createMesh({ meshes })
          end)
          if not updated then
            deleteLightningRibbonMesh(entry.obj)
            table.remove(state.activeLightningRibbonMeshes, index)
          end
        end
      end
    end
  end
end

local function buildLightningShell(points, layerCount, baseJitter, falloff)
  local shell = {}
  for layerIndex = 1, layerCount do
    local layerJitter = baseJitter * (1 - ((layerIndex - 1) * (falloff or 0.12)))
    shell[#shell + 1] = buildOffsetLightningLayer(points, math.max(layerJitter, baseJitter * 0.28))
  end
  return shell
end

local function buildSteppedLightningPolyline(startPos, endPos, segments, offsetScale)
  local points = {}
  local direction = endPos - startPos
  local right = vec3(1, 0, 0)
  if math.abs(direction.x) > 0.1 or math.abs(direction.y) > 0.1 then
    right = vec3(-direction.y, direction.x, 0):normalized()
  end
  local forward = vec3(direction.x, direction.y, 0)
  if forward:length() < 0.001 then
    forward = vec3(0, 1, 0)
  else
    forward = forward:normalized()
  end

  local carriedOffset = vec3(0, 0, 0)
  for index = 0, segments do
    local t = index / segments
    local point = startPos + direction * t
    if index ~= 0 and index ~= segments then
      if index % 2 == 0 then
        carriedOffset = vec3(
          right.x * ((math.random() * 2 - 1) * offsetScale * (1 - t * 0.45)) + forward.x * ((math.random() * 2 - 1) * offsetScale * 0.18),
          right.y * ((math.random() * 2 - 1) * offsetScale * (1 - t * 0.45)) + forward.y * ((math.random() * 2 - 1) * offsetScale * 0.18),
          ((math.random() * 2 - 1) * offsetScale * 0.14)
        )
      end
      point = point + carriedOffset
    end
    points[#points + 1] = point
  end

  return points
end

local function buildBranchCluster(mainBolt, branchCount, spreadScale)
  local branches = {}
  local highestBranchStartIndex = math.max(2, math.floor((#mainBolt - 1) * 0.70))
  for _ = 1, branchCount do
    local branchStartIndex = math.random(2, highestBranchStartIndex)
    local branchStart = mainBolt[branchStartIndex]
    local branchEnd = branchStart + vec3(
      (math.random() * 2 - 1) * spreadScale,
      (math.random() * 2 - 1) * spreadScale,
      -(14 + math.random() * (spreadScale * 1.3))
    )
    branches[#branches + 1] = buildSteppedLightningPolyline(branchStart, branchEnd, 4 + math.random(4), 3.5 + math.random() * 3.5)
  end
  return branches
end

local function createImpactResidue(strike)
  local sparks = {}
  local sparkCount = 7 + math.random(7)
  for _ = 1, sparkCount do
    sparks[#sparks + 1] = {
      offset = vec3(
        (math.random() * 2 - 1) * (0.35 + math.random() * 0.9),
        (math.random() * 2 - 1) * (0.35 + math.random() * 0.9),
        0.04 + math.random() * 0.18
      ),
      radius = 0.06 + math.random() * 0.12,
      age = math.random() * 0.08,
      duration = 0.14 + math.random() * 0.24
    }
  end

  local smokeWisps = {}
  local smokeCount = strike.bigHit and (4 + math.random(3)) or (2 + math.random(2))
  for _ = 1, smokeCount do
    smokeWisps[#smokeWisps + 1] = {
      offset = vec3(
        (math.random() * 2 - 1) * (0.18 + math.random() * 0.42),
        (math.random() * 2 - 1) * (0.18 + math.random() * 0.42),
        0.02 + math.random() * 0.08
      ),
      drift = vec3(
        (math.random() * 2 - 1) * 0.12,
        (math.random() * 2 - 1) * 0.12,
        0.16 + math.random() * 0.34
      ),
      radius = (strike.bigHit and 0.30 or 0.18) + math.random() * (strike.bigHit and 0.28 or 0.16),
      age = math.random() * 0.10,
      duration = (strike.bigHit and 1.2 or 0.75) + math.random() * (strike.bigHit and 0.9 or 0.45)
    }
  end

  state.strikeResidue[#state.strikeResidue + 1] = {
    position = vec3(strike.impactPoint),
    age = 0,
    duration = (strike.bigHit and 1.45 or 0.90) + math.random() * (strike.bigHit and 0.70 or 0.40),
    bloomDuration = 0.14 + math.random() * 0.10,
    bloomRadius = (strike.bigHit and 2.8 or 1.6) + math.random() * (strike.bigHit and 1.7 or 0.8),
    scorchRadius = (strike.bigHit and 1.4 or 0.8) + math.random() * (strike.bigHit and 0.8 or 0.45),
    dustRadius = (strike.bigHit and 2.4 or 1.3) + math.random() * (strike.bigHit and 1.2 or 0.6),
    smokeWisps = smokeWisps,
    sparks = sparks,
    bigHit = strike.bigHit == true
  }
end

local function spawnImpactEmitter(emitterName, position, scale, duration)
  if not createObject then
    return
  end

  local emitter = createObject("ParticleEmitterNode")
  if not emitter then
    return
  end

  emitter:setField("dataBlock", 0, "lightExampleEmitterNodeData1")
  emitter:setField("emitter", 0, emitterName)
  emitter.scale = Point3F(scale, scale, scale)
  emitter:setPosition(position:toPoint3F())
  emitter:registerObject(nextUniqueObjectName("ashweather_impact_" .. emitterName))

  while #state.activeImpactEmitters >= 48 do
    local oldest = table.remove(state.activeImpactEmitters, 1)
    if oldest and oldest.obj and type(oldest.obj.delete) == "function" then
      pcall(oldest.obj.delete, oldest.obj)
    end
  end
  state.activeImpactEmitters[#state.activeImpactEmitters + 1] = {
    obj = emitter,
    age = 0,
    duration = duration or 0.45
  }
end

local function spawnImpactParticles(strike)
  local impactPoint = strike.impactPoint + vec3(0, 0, 0.02)
  local configs = {
    { name = "BNGP_1", scale = 0.45, duration = 0.22, spread = 0.16 },
    { name = "BNGP_26", scale = 0.68, duration = 0.28, spread = 0.24 },
    { name = "BNGP_9", scale = 0.92, duration = 0.40, spread = 0.34 }
  }
  local burstCount = 3 + math.random(3)
  local sizeBias = strike.impactEmitterScale or 1.0

  for burstIndex = 1, burstCount do
    local config = configs[((burstIndex - 1) % #configs) + 1]
    local position = impactPoint + vec3(
      (math.random() * 2 - 1) * config.spread * sizeBias,
      (math.random() * 2 - 1) * config.spread * sizeBias,
      math.random() * 0.06 * sizeBias
    )
    local scale = config.scale * sizeBias * (0.65 + math.random() * 1.25)
    local duration = config.duration * (0.82 + math.random() * 0.55)
    spawnImpactEmitter(config.name, position, scale, duration)
  end

  if strike.bigHit then
    spawnImpactEmitter("BNGP_26", impactPoint + vec3(0, 0, 0.03), 1.7 + math.random() * 1.1, 0.46 + math.random() * 0.18)
    spawnImpactEmitter("BNGP_9", impactPoint, 1.9 + math.random() * 1.3, 0.54 + math.random() * 0.24)
  else
    spawnImpactEmitter("BNGP_1", impactPoint, 0.32 + math.random() * 0.22, 0.09 + math.random() * 0.06)
  end

  if ensureLightningImpactParticles() then
    local coronaScale = strike.hitVehicle and 1.35 or 0.88
    spawnImpactEmitter(
      "AshWeatherLightningCoronaEmitter",
      impactPoint + vec3(0, 0, 0.08),
      coronaScale * sizeBias,
      strike.hitVehicle and 0.32 or 0.22
    )
    if strike.hitVehicle then
      spawnImpactEmitter("AshWeatherMetalSparkEmitter", impactPoint + vec3(0, 0, 0.10), 0.72 * sizeBias, 0.34)
      spawnImpactEmitter("AshWeatherMetalSparkEmitter", impactPoint + vec3(0, 0, 0.18), 0.48 * sizeBias, 0.24)
    end
  end
end

local function spawnScorchAftermathParticles(strike)
  if not strike.bigHit then
    return
  end

  local impactPoint = strike.impactPoint + vec3(0, 0, 0.02)
  spawnImpactEmitter("BNGP_26", impactPoint + vec3(0, 0, 0.04), 1.15 + math.random() * 0.45, 1.10 + math.random() * 0.40)
  spawnImpactEmitter("BNGP_1", impactPoint, 0.82 + math.random() * 0.28, 1.55 + math.random() * 0.55)
  spawnImpactEmitter("BNGP_9", impactPoint + vec3((math.random() * 2 - 1) * 0.12, (math.random() * 2 - 1) * 0.12, 0), 0.74 + math.random() * 0.24, 1.85 + math.random() * 0.55)
end

local function updateImpactEmitters(dt)
  if #state.activeImpactEmitters == 0 then
    return
  end

  for index = #state.activeImpactEmitters, 1, -1 do
    local entry = state.activeImpactEmitters[index]
    entry.age = entry.age + dt
    if entry.age >= entry.duration then
      if entry.obj and type(entry.obj.delete) == "function" then
        pcall(entry.obj.delete, entry.obj)
      end
      table.remove(state.activeImpactEmitters, index)
    end
  end
end

local function trackThunderEmitter(emitter, duration)
  if not emitter then
    return
  end

  while #state.activeThunderEmitters >= 24 do
    local oldest = table.remove(state.activeThunderEmitters, 1)
    if oldest and oldest.obj and type(oldest.obj.delete) == "function" then
      pcall(oldest.obj.delete, oldest.obj)
    end
  end
  state.activeThunderEmitters[#state.activeThunderEmitters + 1] = {
    obj = emitter,
    age = 0,
    duration = duration or 18
  }
end

local function updateThunderEmitters(dt)
  if #state.activeThunderEmitters == 0 then
    return
  end

  for index = #state.activeThunderEmitters, 1, -1 do
    local entry = state.activeThunderEmitters[index]
    entry.age = entry.age + dt
    if entry.age >= entry.duration then
      if entry.obj and type(entry.obj.delete) == "function" then
        pcall(entry.obj.delete, entry.obj)
      end
      table.remove(state.activeThunderEmitters, index)
    end
  end
end

local function playVehicleElectricalPop(position)
  playThunderAtPosition({
    position = vec3(position),
    soundFile = "art/sound/ashweather/lightning_strike_close_sync.ogg",
    emitterScale = 5,
    forceEmitter = true,
    volume = 0.42
  })
end

local function getVehicleEffectKey(veh)
  if veh and type(veh.getID) == "function" then
    local ok, id = pcall(veh.getID, veh)
    if ok and id ~= nil then
      return tostring(id)
    end
  end
  return tostring(veh)
end

local function queueVehicleLua(veh, command)
  if veh and type(veh.queueLuaCommand) == "function" then
    local ok = pcall(veh.queueLuaCommand, veh, command)
    return ok == true
  end
  return false
end

local function resetVehicleLocalWind(veh)
  local windX, windY = getWindVector(state.appliedWindSpeed)
  queueVehicleLua(veh, string.format(
    "if obj and obj.setWind then obj:setWind(%.3f, %.3f, 0) end",
    windX,
    windY
  ))
end

local function queueSafeVehicleWind(veh, x, y, maxWind)
  if not veh or type(veh.queueLuaCommand) ~= "function" then
    return false
  end

  local limit = math.max(0, tonumber(maxWind) or 22)
  local length = math.sqrt((x * x) + (y * y))
  if limit > 0 and length > limit then
    local scale = limit / length
    x = x * scale
    y = y * scale
  end

  return queueVehicleLua(veh, string.format([[
    local windX = %.3f
    local windY = %.3f
    local maxWind = %.3f
    local speed = 0
    if electrics and electrics.values then
      speed = math.abs(tonumber(electrics.values.wheelspeed) or tonumber(electrics.values.airspeed) or tonumber(electrics.values.gpsspeed) or 0)
    end
    local mass = 0
    local nodeCount = 0
    if v and v.data and v.data.nodes then
      for _, node in pairs(v.data.nodes) do
        nodeCount = nodeCount + 1
        mass = mass + (tonumber(node.nodeWeight) or tonumber(node.weight) or tonumber(node.mass) or 0)
      end
    end
    if mass <= 0 then
      mass = math.max(900, nodeCount * 22)
    end
    local massScale = math.max(0.45, math.min(1.35, 1500 / mass))
    local speedScale = math.max(0.36, math.min(1.0, 1 - (speed / 85)))
    local finalX = windX * massScale * speedScale
    local finalY = windY * massScale * speedScale
    local finalLength = math.sqrt(finalX * finalX + finalY * finalY)
    if maxWind > 0 and finalLength > maxWind then
      local finalScale = maxWind / finalLength
      finalX = finalX * finalScale
      finalY = finalY * finalScale
    end
    if obj and obj.setWind then obj:setWind(finalX, finalY, 0) end
  ]], x, y, limit))
end

local function resetVehicleElectrics(veh)
  queueVehicleLua(veh, [[
    if electrics then
      if electrics.set_warn_signal then electrics.set_warn_signal(false) end
      if electrics.set_lightbar_signal then electrics.set_lightbar_signal(0) end
      if electrics.set_fog_lights then electrics.set_fog_lights(false) end
      if electrics.light_flash_highbeams then electrics.light_flash_highbeams(false) end
      if electrics.setLightsState then electrics.setLightsState(0) end
      if electrics.horn then electrics.horn(false) end
      if electrics.values then
        electrics.values.horn = 0
        electrics.values.hazard_enabled = 0
        electrics.values.signal_left_input = 0
        electrics.values.signal_right_input = 0
        electrics.values.brake = 0
        electrics.values.parkingbrake = 0
        electrics.values.steering = 0
      end
    end
  ]])
end

local function startVehicleLocalWind(veh, duration, strength)
  if not veh or type(veh.queueLuaCommand) ~= "function" then
    return
  end

  local key = getVehicleEffectKey(veh)
  state.vehicleLocalWindEffects[key] = {
    vehicle = veh,
    elapsed = 0,
    duration = duration or 3.5,
    timer = 0,
    strength = strength or 26
  }
end

local function startVehicleElectricalChaos(veh, duration, intensity)
  if not veh or type(veh.queueLuaCommand) ~= "function" then
    return
  end

  local key = getVehicleEffectKey(veh)
  state.vehicleElectricalEffects[key] = {
    vehicle = veh,
    elapsed = 0,
    duration = duration or 7,
    timer = 0,
    intensity = clamp(tonumber(intensity) or 1.0, 0.25, 2.0)
  }
end

local function startVehicleEmpShutdown(veh, duration)
  if not veh or type(veh.queueLuaCommand) ~= "function" then
    return
  end

  local key = getVehicleEffectKey(veh)
  state.vehicleEmpShutdownEffects[key] = {
    vehicle = veh,
    elapsed = 0,
    duration = duration or 6,
    timer = 0
  }
end

local function updateVehicleLocalWindEffects(dt)
  for key, effect in pairs(state.vehicleLocalWindEffects) do
    effect.elapsed = effect.elapsed + dt
    effect.timer = effect.timer + dt

    if effect.elapsed >= effect.duration then
      resetVehicleLocalWind(effect.vehicle)
      state.vehicleLocalWindEffects[key] = nil
    elseif effect.timer >= 0.12 then
      effect.timer = 0
      local strength = effect.strength or 26
      local x = (math.random() * 2 - 1) * strength
      local y = (math.random() * 2 - 1) * strength
      if not queueSafeVehicleWind(effect.vehicle, x, y, 44) then
        state.vehicleLocalWindEffects[key] = nil
      end
    end
  end
end

local function getPhaseWindVehicleScale(profileId)
  if profileId == "rain" or profileId == "drizzle" or profileId == "overcast" or profileId == "snow" then
    return 1.0
  elseif profileId == "storm" then
    return 1.12
  elseif profileId == "hail" then
    return 1.22
  elseif profileId == "supercell" then
    return state.heavyStormMode and 1.38 or 1.30
  end
  return 0
end

local function clearPlayerPhaseWind(veh)
  if veh then
    resetVehicleLocalWind(veh)
  elseif type(activeVehiclesIterator) == "function" then
    for _, activeVehicle in activeVehiclesIterator() do
      resetVehicleLocalWind(activeVehicle)
    end
  else
    local playerVehicle = getPlayerVehicle()
    if playerVehicle then
      resetVehicleLocalWind(playerVehicle)
    end
  end
  state.playerPhaseWindLastVehicleKey = nil
end

local function updatePlayerPhaseWind(dt)
  state.playerPhaseWindTimer = (state.playerPhaseWindTimer or 0) + dt
  state.playerPhaseWindGustTimer = (state.playerPhaseWindGustTimer or 0) + dt

  if state.playerPhaseWindGustTimer >= 1.2 then
    state.playerPhaseWindGustTimer = 0
    state.playerPhaseWindGust = 0.78 + math.random() * 0.54
  end

  if state.playerPhaseWindTimer < 0.50 then
    return
  end
  state.playerPhaseWindTimer = 0

  local vehicles = {}
  if type(activeVehiclesIterator) == "function" then
    for _, activeVehicle in activeVehiclesIterator() do
      vehicles[#vehicles + 1] = activeVehicle
    end
  else
    local playerVehicle = getPlayerVehicle()
    if playerVehicle then
      vehicles[1] = playerVehicle
    end
  end
  if #vehicles == 0 then
    state.playerPhaseWindLastVehicleKey = nil
    return
  end

  local profileId = getCurrentBaseProfileId()
  local windSpeed = tonumber(state.appliedWindSpeed) or tonumber(state.currentValues and state.currentValues.windSpeed) or 0
  local scale = getPhaseWindVehicleScale(profileId)
  if windSpeed <= 0.001 or scale <= 0 then
    for _, veh in ipairs(vehicles) do
      resetVehicleLocalWind(veh)
    end
    return
  end

  local angle = state.windDirectionRadians or 0
  local gust = state.playerPhaseWindGust or 1.0
  local directionWobble = (math.random() * 2 - 1) * 0.10
  local strength = windSpeed * scale * gust
  local x = math.cos(angle + directionWobble) * strength
  local y = math.sin(angle + directionWobble) * strength
  local maxWind = profileId == "supercell" and (state.heavyStormMode and 38 or 30) or 22
  for _, veh in ipairs(vehicles) do
    local vehicleKey = getVehicleEffectKey(veh)
    if not state.vehicleLocalWindEffects[vehicleKey] then
      if windSpeed <= 0.001 or scale <= 0 then
        resetVehicleLocalWind(veh)
      else
        queueSafeVehicleWind(veh, x, y, maxWind)
      end
    end
  end
end

local function queueVehicleEngineOff(veh)
  return queueVehicleLua(veh, [[
    if electrics and electrics.values then
      electrics.values.ignition = 0
      electrics.values.starter = 0
      electrics.values.engineRunning = 0
      electrics.values.rpm = 0
    end
    if controller and controller.mainController then
      if controller.mainController.setEngineIgnition then controller.mainController:setEngineIgnition(0) end
      if controller.mainController.setStarter then controller.mainController:setStarter(false) end
      if controller.mainController.setIgnition then controller.mainController:setIgnition(false) end
    end
    if drivetrain and drivetrain.engine and drivetrain.engine.stopEngine then
      pcall(drivetrain.engine.stopEngine, drivetrain.engine)
    end
    if powertrain and powertrain.getDevices then
      for _, device in pairs(powertrain.getDevices() or {}) do
        if device then
          if device.setIgnition then pcall(device.setIgnition, device, false) end
          if device.setStarter then pcall(device.setStarter, device, false) end
          if device.stopEngine then pcall(device.stopEngine, device) end
        end
      end
    end
  ]])
end

local function updateVehicleEmpShutdownEffects(dt)
  for key, effect in pairs(state.vehicleEmpShutdownEffects) do
    effect.elapsed = effect.elapsed + dt
    effect.timer = effect.timer + dt

    if effect.elapsed >= effect.duration then
      state.vehicleEmpShutdownEffects[key] = nil
    elseif effect.timer >= 0.18 then
      effect.timer = 0
      if not queueVehicleEngineOff(effect.vehicle) then
        state.vehicleEmpShutdownEffects[key] = nil
      end
    end
  end
end

local function updateVehicleElectricalEffects(dt)
  for key, effect in pairs(state.vehicleElectricalEffects) do
    effect.elapsed = effect.elapsed + dt
    effect.timer = effect.timer + dt

    if effect.elapsed >= effect.duration then
      resetVehicleElectrics(effect.vehicle)
      state.vehicleElectricalEffects[key] = nil
    elseif effect.timer >= math.max(0.08, 0.22 / (effect.intensity or 1.0)) then
      effect.timer = 0
      if not queueVehicleLua(effect.vehicle, [[
        if electrics then
          if electrics.toggle_left_signal and math.random() < 0.45 then electrics.toggle_left_signal() end
          if electrics.toggle_right_signal and math.random() < 0.45 then electrics.toggle_right_signal() end
          if electrics.toggle_warn_signal and math.random() < 0.34 then electrics.toggle_warn_signal() end
          if electrics.toggle_lights and math.random() < 0.52 then electrics.toggle_lights() end
          if electrics.set_warn_signal and math.random() < 0.24 then electrics.set_warn_signal(math.random() < 0.5) end
          if electrics.light_flash_highbeams and math.random() < 0.22 then electrics.light_flash_highbeams(math.random() < 0.5) end
          if electrics.set_fog_lights and math.random() < 0.18 then electrics.set_fog_lights(math.random() < 0.5) end
          if electrics.setLightsState and math.random() < 0.30 then electrics.setLightsState(math.random(0, 2)) end
          if electrics.horn then electrics.horn(math.random() < 0.16) end
          if electrics.values then
            electrics.values.lowbeam = math.random() < 0.50 and 1 or 0
            electrics.values.highbeam = math.random() < 0.35 and 1 or 0
            electrics.values.hazard_enabled = math.random() < 0.55 and 1 or 0
            electrics.values.signal_left_input = math.random() < 0.50 and 1 or 0
            electrics.values.signal_right_input = math.random() < 0.50 and 1 or 0
            electrics.values.horn = math.random() < 0.12 and 1 or 0
          end
        end
      ]]) then
        state.vehicleElectricalEffects[key] = nil
      end
    end
  end
end

local function clearVehicleTransientEffects()
  for key, effect in pairs(state.vehicleLocalWindEffects) do
    resetVehicleLocalWind(effect.vehicle)
    state.vehicleLocalWindEffects[key] = nil
  end
  for key, effect in pairs(state.vehicleElectricalEffects) do
    resetVehicleElectrics(effect.vehicle)
    state.vehicleElectricalEffects[key] = nil
  end
  for key in pairs(state.vehicleEmpShutdownEffects) do
    state.vehicleEmpShutdownEffects[key] = nil
  end
end

local function findStrikeTarget(anchor, forceVehicleTarget)
  local playerVehicle = getPlayerVehicle()
  local playerVehiclePos = getVehiclePosition(playerVehicle)
  if playerVehiclePos and (forceVehicleTarget or (playerVehiclePos - anchor):length() <= (state.lightningStrikeRadius or 50)) then
    local susceptibility = M.weatherRuntime.getLightningSusceptibility(playerVehicle, playerVehiclePos, anchor)
    if (forceVehicleTarget and (state.lightningIgnoreShelter or susceptibility > 0.05)) or math.random() <= (state.lightningVehicleHitChance or 0.05) * susceptibility then
      return playerVehicle, playerVehiclePos
    end
  end

  if type(activeVehiclesIterator) ~= "function" then
    return nil, nil
  end

  local bestVehicle = nil
  local bestPosition = nil
  local bestDistance = math.huge

  for _, veh in activeVehiclesIterator() do
    local pos = getVehiclePosition(veh)
    if pos then
      local distance = (pos - anchor):length()
      local susceptibility = M.weatherRuntime.getLightningSusceptibility(veh, pos, anchor)
      local selected = (forceVehicleTarget and (state.lightningIgnoreShelter or susceptibility > 0.05)) or math.random() <= (state.lightningVehicleHitChance or 0.05) * susceptibility
      if selected and (forceVehicleTarget or distance > 3) and distance < (state.lightningStrikeRadius or 50) and distance < bestDistance then
        bestDistance = distance
        bestVehicle = veh
        bestPosition = pos
      end
    end
  end

  if not bestVehicle then
    return nil, nil
  end

  return bestVehicle, bestPosition
end

local function damageVehicleFromStrike(veh, directHit, strike)
  if not state.vehicleDamageEnabled then
    return
  end

  if not veh or type(veh.queueLuaCommand) ~= "function" then
    return
  end

  local command
  local outcome = "none"
  local empEngineCutDuration = 0
  local electricalShutdown = [[
    if electrics then
      electrics.values.lowbeam = 0
      electrics.values.highbeam = 0
      electrics.values.hazard_enabled = 1
      electrics.values.signal_left_input = 1
      electrics.values.signal_right_input = 1
    end
    if controller and controller.mainController then
      if controller.mainController.setEngineIgnition then controller.mainController:setEngineIgnition(0) end
      if controller.mainController.setStarter then controller.mainController:setStarter(false) end
    end
  ]]

  if directHit then
    local hitKey = getVehicleEffectKey(veh)
    local now = os.clock()
    local memory = state.lightningVehicleHitCounts[hitKey]
    if type(memory) ~= "table" then
      memory = { count = tonumber(memory) or 0, lastHit = now }
    end
    if memory.lastHit and now - memory.lastHit >= LIGHTNING_HIT_DECAY_SECONDS then
      memory.count = 0
    end
    local hitCount = (tonumber(memory.count) or 0) + 1
    memory.count = hitCount
    memory.lastHit = now
    state.lightningVehicleHitCounts[hitKey] = memory

    if hitCount <= 3 then
      outcome = "emp"
      writeLog("I", string.format("Vehicle lightning hit %d/4: EMP", hitCount))
    else
      state.lightningVehicleHitCounts[hitKey] = { count = 0, lastHit = now }
      outcome = state.lightningExplosionsEnabled and "explode" or "hardBreakIgnite"
      writeLog("I", "Vehicle lightning hit 4/4: critical destructive strike")
    end
  else
    local noEffectChance = clamp(tonumber(state.lightningNoEffectChance) or 0.30, 0, 1)
    local empChance = clamp(tonumber(state.lightningEmpEffectChance) or 0.55, 0, 1)
    local splashRoll = math.random()
    if splashRoll < math.min(0.72, noEffectChance + 0.22) then
      return
    elseif splashRoll < math.min(0.98, noEffectChance + empChance + 0.34) then
      outcome = "emp"
    else
      outcome = "ignite"
    end
  end

  if not state.lightningExplosionsEnabled and (outcome == "explode" or outcome == "catastrophic") then
    outcome = "hardBreakIgnite"
  end

  if outcome == "none" then
    return
  elseif outcome == "emp" then
    local directMemory = directHit and state.lightningVehicleHitCounts[getVehicleEffectKey(veh)] or nil
    local empTier = directHit and math.max(1, math.min(3, tonumber(directMemory and directMemory.count) or 1)) or 2
    local chaosDuration = empTier == 1 and 5 or (empTier == 2 and 5 or 6.5)
    local engineCutDuration = empTier == 1 and 0 or (empTier == 2 and 3.5 or 5)
    empEngineCutDuration = engineCutDuration
    local chaosIntensity = empTier == 1 and 0.85 or (empTier == 2 and 1.15 or 1.6)
    startVehicleElectricalChaos(veh, chaosDuration, chaosIntensity)
    if engineCutDuration > 0 then
      startVehicleEmpShutdown(veh, engineCutDuration)
    end
    if empTier >= 3 then
      startVehicleLocalWind(veh, directHit and 4.0 or 2.2, directHit and 42 or 22)
    elseif empTier == 2 then
      startVehicleLocalWind(veh, directHit and 2.5 or 1.8, directHit and 24 or 14)
    end
    command = [[
      if electrics then
        electrics.values.lowbeam = math.random() < 0.5 and 1 or 0
        electrics.values.highbeam = math.random() < 0.35 and 1 or 0
        electrics.values.hazard_enabled = 1
        electrics.values.signal_left_input = math.random() < 0.5 and 1 or 0
        electrics.values.signal_right_input = math.random() < 0.5 and 1 or 0
        electrics.values.horn = math.random() < 0.18 and 1 or 0
      end
    ]]
    if engineCutDuration > 0 then
      command = command .. [[
        if electrics then
          electrics.values.ignition = 0
          electrics.values.starter = 0
          electrics.values.engineRunning = 0
          electrics.values.rpm = 0
        end
      ]]
    end
    if empTier >= 3 then
      command = command .. [[
        if electrics and electrics.values then
          electrics.values.brake = math.random() < 0.45 and 0.35 or 0
          electrics.values.parkingbrake = math.random() < 0.18 and 1 or 0
          electrics.values.steering = (math.random() * 2 - 1) * 0.18
        end
      ]]
    end
    if state.lightningAftermathEnabled and empTier >= 2 then
      command = command .. string.format([[
        if energyStorage and energyStorage.getStorages then
          for _, storage in pairs(energyStorage.getStorages() or {}) do
            if storage and storage.energyType == "electricEnergy" and storage.setStoredEnergy and storage.storedEnergy then
              storage:setStoredEnergy(storage.storedEnergy * %.4f)
            end
          end
        end
        if %d >= 3 and wheels and wheels.wheels and beamstate and beamstate.deflateTire and math.random() < %.5f then
          local candidates = {}
          for wheelId, wheel in pairs(wheels.wheels) do
            if wheel and wheel.hasTire ~= false and not wheel.isTireDeflated then candidates[#candidates + 1] = wheelId end
          end
          if #candidates > 0 then beamstate.deflateTire(candidates[math.random(#candidates)]) end
        end
        if %d >= 3 and fire and fire.igniteCar and math.random() < %.5f then fire.igniteCar() end
      ]], empTier == 2 and 0.997 or 0.990, empTier, state.lightningTyreDamageChance or 0.12, empTier, state.lightningFireChance or 0.08)
    end
    if engineCutDuration > 0 then
      command = command .. [[
      if controller and controller.mainController then
        if controller.mainController.setEngineIgnition then controller.mainController:setEngineIgnition(0) end
        if controller.mainController.setStarter then controller.mainController:setStarter(false) end
      end
      if drivetrain and drivetrain.engine and drivetrain.engine.stopEngine then
        pcall(drivetrain.engine.stopEngine, drivetrain.engine)
      end
      if powertrain and powertrain.getDevices then
        for _, device in pairs(powertrain.getDevices() or {}) do
          if device and device.setIgnition then pcall(device.setIgnition, device, false) end
          if device and device.stopEngine then pcall(device.stopEngine, device) end
        end
      end
      ]]
    end
  elseif outcome == "ignite" then
    if not directHit then
      command = [[
        if fire and fire.igniteCar then fire.igniteCar() end
      ]]
    else
      command = [[
        if fire and fire.igniteCar then fire.igniteCar() end
      ]]
    end
  elseif outcome == "breakIgnite" then
    command = [[
      beamstate.breakAllBreakgroups()
      if fire and fire.igniteCar then fire.igniteCar() end
    ]]
  elseif outcome == "hardBreakIgnite" then
    command = [[
      beamstate.breakAllBreakgroups()
      beamstate.breakAllBreakgroups()
      if fire and fire.igniteCar then fire.igniteCar() end
    ]]
  elseif outcome == "explode" then
    command = [[
      beamstate.breakAllBreakgroups()
      if fire and fire.igniteCar then fire.igniteCar() end
    ]]
  else
    command = [[
      beamstate.breakAllBreakgroups()
      beamstate.breakAllBreakgroups()
      if fire and fire.igniteCar then fire.igniteCar() end
    ]]
  end

  if directHit and (strike and strike.bigHit or state.damageTier ~= "mild") and (outcome ~= "emp" or empEngineCutDuration > 0) then
    command = command .. electricalShutdown
  end

  queueVehicleLua(veh, command)
end

function M.weatherRuntime.testEmpTier(tier)
  local veh = getPlayerVehicle()
  if not veh then return false end
  local normalizedTier = math.floor(clamp(tonumber(tier) or 1, 1, 3))
  local key = getVehicleEffectKey(veh)
  state.lightningVehicleHitCounts[key] = { count = normalizedTier - 1, lastHit = os.clock() }
  local previousDamage = state.vehicleDamageEnabled
  state.vehicleDamageEnabled = true
  damageVehicleFromStrike(veh, true, { bigHit = true, test = true })
  state.vehicleDamageEnabled = previousDamage
  return true
end

function M.weatherRuntime.resetPlayerWeatherDamage()
  local veh = getPlayerVehicle()
  if not veh then return false end
  local key = getVehicleEffectKey(veh)
  state.lightningVehicleHitCounts[key] = nil
  state.vehicleElectricalEffects[key] = nil
  state.vehicleEmpShutdownEffects[key] = nil
  state.vehicleLocalWindEffects[key] = nil
  for cooldownKey in pairs(state.vehicleHazardCooldowns) do
    if cooldownKey:sub(1, #key + 1) == key .. ":" then state.vehicleHazardCooldowns[cooldownKey] = nil end
  end
  resetVehicleElectrics(veh)
  resetVehicleLocalWind(veh)
  return true
end

local function getVehicleHazardKey(veh)
  if veh and type(veh.getID) == "function" then
    local ok, id = pcall(veh.getID, veh)
    if ok and id ~= nil then
      return tostring(id)
    end
  end
  return tostring(veh)
end

function M.weatherRuntime.getVehicleShelterExposure(veh, position)
  if not state.shelterDetectionEnabled or state.lightningIgnoreShelter then return 1 end
  if type(castRay) ~= "function" or not position then return 1 end
  local key = getVehicleHazardKey(veh)
  local now = os.clock()
  local cached = state.hailLineOfSightCache[key]
  if cached and cached.expiresAt and now < cached.expiresAt and cached.exposure ~= nil then return cached.exposure end

  local center = vec3(position)
  local half = vec3(0.9, 1.8, 0.75)
  if veh and type(veh.getSpawnWorldOOBB) == "function" then
    local ok, box = pcall(veh.getSpawnWorldOOBB, veh)
    if ok and box then
      local centerOk, boxCenter = pcall(box.getCenter, box)
      local halfOk, halfExtents = pcall(box.getHalfExtents, box)
      if centerOk and boxCenter then center = vec3(boxCenter) end
      if halfOk and halfExtents then half = vec3(halfExtents) end
    end
  end

  local offsets = {
    vec3(0, 0, 0),
    vec3(half.x * 0.62, 0, 0),
    vec3(-half.x * 0.62, 0, 0),
    vec3(0, half.y * 0.62, 0),
    vec3(0, -half.y * 0.62, 0)
  }
  local exposed = 0
  for _, offset in ipairs(offsets) do
    local target = center + offset + vec3(0, 0, half.z + 0.12)
    local source = target + vec3(0, 0, 75)
    local clear = true
    local ok, hit = pcall(castRay, source, target, true, true)
    if ok and hit and hit.pt then clear = (vec3(hit.pt) - target):length() <= 2.25 end
    if clear then exposed = exposed + 1 end
  end
  local exposure = exposed / #offsets
  state.hailLineOfSightCache[key] = { exposure = exposure, clear = exposure > 0, expiresAt = now + 0.55 }
  return exposure
end

function M.weatherRuntime.getLightningSusceptibility(veh, position, anchor)
  local exposure = M.weatherRuntime.getVehicleShelterExposure(veh, position)
  if exposure <= 0 then return 0 end
  local height = 1.5
  if veh and type(veh.getSpawnWorldOOBB) == "function" then
    local ok, box = pcall(veh.getSpawnWorldOOBB, veh)
    if ok and box then
      local halfOk, half = pcall(box.getHalfExtents, box)
      if halfOk and half then height = math.max(0.5, tonumber(half.z) and half.z * 2 or 1.5) end
    end
  end
  local tallFactor = 1 + clamp((height - 1.5) * 0.12, 0, 0.35)
  local elevationFactor = 1 + clamp(((position and position.z or 0) - (anchor and anchor.z or 0)) * 0.01, 0, 0.25)
  return exposure * tallFactor * elevationFactor
end

local function queueVehicleHazardDamage(veh, hazardName, severity, cooldown)
  if not state.destructiveWeatherEnabled or not state.vehicleDamageEnabled then
    return false
  end
  if not veh or type(veh.queueLuaCommand) ~= "function" then
    return false
  end

  local key = getVehicleHazardKey(veh) .. ":" .. tostring(hazardName)
  local now = os.clock()
  local nextAllowed = state.vehicleHazardCooldowns[key] or 0
  if now < nextAllowed then
    return false
  end
  state.vehicleHazardCooldowns[key] = now + (cooldown or 5)
  if hazardName == "microburst" then
    startVehicleLocalWind(veh, 3.4, 32)
  end

  local command
  if severity == "rattle" then
    command = [[
      if electrics then
        electrics.values.hazard_enabled = 1
      end
    ]]
  elseif severity == "damage" then
    command = [[
      if electrics then electrics.values.hazard_enabled = 1 end
      if obj and v and v.data and v.data.nodes then
        local sideForce = vec3((math.random() * 2 - 1) * 2600, (math.random() * 2 - 1) * 2600, 0)
        local applied = 0
        for _, node in pairs(v.data.nodes) do
          if node and node.cid and not node.wheelID and math.random() < 0.08 then
            obj:applyForceVector(node.cid, sideForce)
            applied = applied + 1
            if applied >= 8 then break end
          end
        end
      end
    ]]
  elseif severity == "ignite" then
    command = [[
      if electrics then electrics.values.hazard_enabled = 1 end
      if fire and fire.igniteCar then fire.igniteCar() end
    ]]
  else
    command = [[
      if electrics then electrics.values.hazard_enabled = 1 end
      if fire and fire.igniteCar then fire.igniteCar() end
    ]]
  end

  veh:queueLuaCommand(command)
  return true
end

function M.weatherRuntime.updateAquaplaning(dt)
  state.aquaplaneTimer = (state.aquaplaneTimer or 0) + dt
  if state.aquaplaneTimer < 0.35 then return end
  state.aquaplaneTimer = 0
  local wetness = clamp(tonumber(state.roadWetness) or 0, 0, 1)
  local localIntensity = state.serverStormCell and clamp(state.localStormIntensity or 0, 0, 1) or 1
  if not state.aquaplaningEnabled or wetness < 0.35 or localIntensity < 0.08 then return end
  local veh = getPlayerVehicle()
  if not veh then return end
  queueVehicleLua(veh, string.format([[
    local wetness = %.4f
    local localIntensity = %.4f
    local speed = electrics and electrics.values and math.abs(tonumber(electrics.values.wheelspeed) or tonumber(electrics.values.airspeed) or 0) or 0
    if speed > 18 and wheels and wheels.wheels and obj then
      local mass = 0
      local nodeCount = 0
      for _, node in pairs(v and v.data and v.data.nodes or {}) do
        nodeCount = nodeCount + 1
        mass = mass + (tonumber(node.nodeWeight) or tonumber(node.weight) or tonumber(node.mass) or 0)
      end
      if mass <= 0 then mass = math.max(900, nodeCount * 22) end
      local speedFactor = math.min(1, (speed - 18) / 30)
      local massFactor = math.max(0.30, math.min(1.25, 1450 / mass))
      local force = (550 + 2450 * speedFactor) * wetness * localIntensity * massFactor
      local direction = math.random() < 0.5 and -1 or 1
      local applied = 0
      for _, wheel in pairs(wheels.wheels) do
        if wheel and wheel.node1 and (tonumber(wheel.downForce) or 0) > 20 and math.random() < 0.46 then
          obj:applyForceVector(wheel.node1, vec3(direction * force, (math.random() * 2 - 1) * force * 0.22, force * 0.035))
          applied = applied + 1
          if applied >= 2 then break end
        end
      end
    end
  ]], wetness, localIntensity))
end

function M.weatherRuntime.removeWindDebris(index)
  local debris = state.windDebris[index]
  if debris and debris.obj then
    pcall(function() if type(debris.obj.delete) == "function" then debris.obj:delete() end end)
  end
  table.remove(state.windDebris, index)
end

function M.weatherRuntime.clearWindDebris()
  for index = #state.windDebris, 1, -1 do M.weatherRuntime.removeWindDebris(index) end
end

function M.weatherRuntime.spawnWindDebris()
  if type(createObject) ~= "function" or #state.windDebris >= 12 then return end
  local playerPos = getPlayerPosition()
  local angle = (state.windDirectionRadians or 0) + math.pi
  local side = (math.random() * 2 - 1) * 28
  local forward = 22 + math.random() * 35
  local position = playerPos + vec3(math.cos(angle) * forward - math.sin(angle) * side, math.sin(angle) * forward + math.cos(angle) * side, 1.0 + math.random() * 4)
  local obj = createObject("TSStatic")
  if not obj then return end
  obj:setField("shapeName", 0, "art/shapes/garage_and_dealership/Clutter/debris_m_can_a.DAE")
  obj.canSave = false
  obj:setScale(vec3(0.45, 0.45, 0.45))
  obj:setPosition(position:toPoint3F())
  state.windDebrisNonce = (state.windDebrisNonce or 0) + 1
  obj:registerObject("ashWeatherWindDebris_" .. tostring(state.windDebrisNonce))
  local speed = math.max(8, tonumber(state.appliedWindSpeed) or 8)
  local travelAngle = state.windDirectionRadians or 0
  state.windDebris[#state.windDebris + 1] = {
    obj = obj,
    position = position,
    velocity = vec3(math.cos(travelAngle) * speed * (0.8 + math.random() * 0.6), math.sin(travelAngle) * speed * (0.8 + math.random() * 0.6), 2 + math.random() * 5),
    age = 0,
    lifetime = 3.5 + math.random() * 3.5
  }
end

function M.weatherRuntime.updateWindDebris(dt)
  local profileId = getCurrentBaseProfileId()
  local severe = profileId == "hail" or profileId == "supercell" or (profileId == "storm" and state.burst ~= nil)
  local localIntensity = state.serverStormCell and clamp(state.localStormIntensity or 0, 0, 1) or 1
  if not state.windDebrisEnabled or not severe or localIntensity < 0.35 then
    if #state.windDebris > 0 then M.weatherRuntime.clearWindDebris() end
    return
  end
  state.windDebrisTimer = (state.windDebrisTimer or 0) + dt
  local spawnInterval = state.heavyStormMode and 0.55 or 1.1
  if state.windDebrisTimer >= spawnInterval then
    state.windDebrisTimer = 0
    M.weatherRuntime.spawnWindDebris()
  end
  local playerVeh = getPlayerVehicle()
  local playerPos = getVehiclePosition(playerVeh)
  for index = #state.windDebris, 1, -1 do
    local debris = state.windDebris[index]
    debris.age = debris.age + dt
    debris.velocity.z = debris.velocity.z - 6.5 * dt
    debris.position = debris.position + debris.velocity * dt
    local valid = debris.obj and type(debris.obj.setPosition) == "function" and pcall(debris.obj.setPosition, debris.obj, debris.position:toPoint3F())
    local hit = playerPos and (debris.position - playerPos):length() <= 2.1
    if hit then queueVehicleHazardDamage(playerVeh, "windDebris", "damage", 2.5) end
    if not valid or hit or debris.age >= debris.lifetime or (playerPos and debris.position.z < playerPos.z - 3) then
      M.weatherRuntime.removeWindDebris(index)
    end
  end
end

local hailHitZones = {
  {
    name = "windshield",
    breakgroups = { "windshield", "windshield_F", "glass_windshield" },
    weight = 1.25
  },
  {
    name = "rear_glass",
    breakgroups = { "backlight", "rear_windshield", "glass_rear" },
    weight = 0.75
  },
  {
    name = "left_windows",
    breakgroups = { "door_FL_window", "door_RL_window", "sideglass_L" },
    weight = 0.8
  },
  {
    name = "right_windows",
    breakgroups = { "door_FR_window", "door_RR_window", "sideglass_R" },
    weight = 0.8
  },
  {
    name = "lights",
    breakgroups = { "headlightglass_L", "headlightglass_R", "taillightglass_L", "taillightglass_R" },
    weight = 0.8
  },
  {
    name = "hood",
    breakgroups = { "hood", "hood_latch" },
    weight = 1.0
  },
  {
    name = "roof",
    breakgroups = { "roof", "roofrack" },
    weight = 1.15
  },
  {
    name = "trunk",
    breakgroups = { "trunk", "tailgate" },
    weight = 0.75
  },
  {
    name = "front_left_fender",
    breakgroups = { "fender_L", "fender_FL", "quarterpanel_FL" },
    weight = 0.55
  },
  {
    name = "front_right_fender",
    breakgroups = { "fender_R", "fender_FR", "quarterpanel_FR" },
    weight = 0.55
  },
  {
    name = "left_doors",
    breakgroups = { "door_FL", "door_RL", "door_L" },
    weight = 0.75
  },
  {
    name = "right_doors",
    breakgroups = { "door_FR", "door_RR", "door_R" },
    weight = 0.75
  },
  {
    name = "front_bumper",
    breakgroups = { "bumper_F", "fascia_F", "grille" },
    weight = 0.45
  },
  {
    name = "rear_bumper",
    breakgroups = { "bumper_R", "fascia_R" },
    weight = 0.45
  }
}

local function pickWeightedHailZone()
  local total = 0
  for _, zone in ipairs(hailHitZones) do
    total = total + zone.weight
  end
  local pick = math.random() * total
  local cumulative = 0
  for _, zone in ipairs(hailHitZones) do
    cumulative = cumulative + zone.weight
    if pick <= cumulative then
      return zone
    end
  end
  return hailHitZones[#hailHitZones]
end

local function queueHailStoneHit(veh, zone, strength, forceDamage)
  if not forceDamage and (not state.destructiveWeatherEnabled or not state.vehicleDamageEnabled) then
    return false
  end
  if not veh or type(veh.queueLuaCommand) ~= "function" or not zone then
    return false
  end

  local breakgroupList = ""
  for index, groupName in ipairs(zone.breakgroups) do
    if index > 1 then
      breakgroupList = breakgroupList .. ","
    end
    breakgroupList = breakgroupList .. string.format("%q", groupName)
  end

  local command = string.format([[
    local groups = {%s}
    local strength = %0.3f
    local zoneName = %q
    if electrics then
      electrics.values.hazard_enabled = 1
    end
    if beamstate then
      for _, groupName in ipairs(groups) do
        if beamstate.breakBreakGroup then
          pcall(beamstate.breakBreakGroup, groupName)
        elseif beamstate.breakGroup then
          pcall(beamstate.breakGroup, groupName)
        end
      end
    end
    if obj and v and v.data and v.data.nodes then
      local width = math.max(0.2, obj:getInitialWidth() or 1.8)
      local length = math.max(0.2, obj:getInitialLength() or 4.2)
      local height = math.max(0.2, obj:getInitialHeight() or 1.4)
      local function inZone(p)
        local nx = p.x / (width * 0.5)
        local ny = p.y / (length * 0.5)
        local nz = p.z / height
        if zoneName == "windshield" then return math.abs(nx) < 0.72 and ny < -0.05 and ny > -0.58 and nz > 0.42 end
        if zoneName == "rear_glass" then return math.abs(nx) < 0.72 and ny > 0.05 and ny < 0.62 and nz > 0.42 end
        if zoneName == "left_windows" then return nx > 0.35 and ny > -0.45 and ny < 0.45 and nz > 0.36 end
        if zoneName == "right_windows" then return nx < -0.35 and ny > -0.45 and ny < 0.45 and nz > 0.36 end
        if zoneName == "lights" then return math.abs(nx) > 0.35 and (ny < -0.65 or ny > 0.65) and nz > 0.12 and nz < 0.55 end
        if zoneName == "hood" then return math.abs(nx) < 0.78 and ny < -0.38 and nz > 0.18 and nz < 0.62 end
        if zoneName == "roof" then return math.abs(nx) < 0.78 and ny > -0.35 and ny < 0.35 and nz > 0.58 end
        if zoneName == "trunk" then return math.abs(nx) < 0.78 and ny > 0.38 and nz > 0.18 and nz < 0.66 end
        if zoneName == "front_left_fender" then return nx > 0.25 and ny < -0.45 and nz > 0.08 and nz < 0.58 end
        if zoneName == "front_right_fender" then return nx < -0.25 and ny < -0.45 and nz > 0.08 and nz < 0.58 end
        if zoneName == "left_doors" then return nx > 0.35 and ny > -0.35 and ny < 0.45 and nz > 0.10 and nz < 0.65 end
        if zoneName == "right_doors" then return nx < -0.35 and ny > -0.35 and ny < 0.45 and nz > 0.10 and nz < 0.65 end
        if zoneName == "front_bumper" then return math.abs(nx) < 0.88 and ny < -0.72 and nz < 0.35 end
        if zoneName == "rear_bumper" then return math.abs(nx) < 0.88 and ny > 0.72 and nz < 0.35 end
        return false
      end

      local candidates = {}
      for _, node in pairs(v.data.nodes) do
        if node and node.cid and not node.wheelID then
          local p = obj:getNodePositionRelative(node.cid)
          if p and inZone(p) then
            candidates[#candidates + 1] = node.cid
          end
        end
      end

      local force = 4200 + (strength * 7600)
      local hitCount = math.min(#candidates, math.max(1, math.floor(1 + strength * 2.2)))
      for i = 1, hitCount do
        local cid = candidates[math.random(#candidates)]
        obj:applyForceVector(cid, vec3((math.random() * 2 - 1) * force * 0.16, (math.random() * 2 - 1) * force * 0.16, -force))
      end
    end
  ]], breakgroupList, strength, zone.name)

  veh:queueLuaCommand(command)
  return true
end

local function getVehiclesInRadius(center, radius)
  local vehicles = {}
  if type(activeVehiclesIterator) ~= "function" or not center then
    return vehicles
  end

  for _, veh in activeVehiclesIterator() do
    local pos = getVehiclePosition(veh)
    if pos and (pos - center):length() <= radius then
      vehicles[#vehicles + 1] = {
        vehicle = veh,
        position = pos
      }
    end
  end

  return vehicles
end

local function isHailPathClear(veh, position)
  return M.weatherRuntime.getVehicleShelterExposure(veh, position)
end

local function applyHailStoneImpacts(hail)
  if not hail then
    return 0
  end
  if (tonumber(hail.intensity) or 0) <= 0.03 then return 0 end

  local center = getPlayerPosition()
  local vehicles = getVehiclesInRadius(center, state.hailRadius or 85)
  if #vehicles == 0 then
    return 0
  end

  local hits = 0
  local zoneHits = {}
  local configuredStones = math.floor(clamp((state.hailStoneCount or 18) * hail.intensity, 1, 1020))
  local stoneCount = math.floor(clamp(configuredStones, 1, 260))
  for _ = 1, stoneCount do
    if math.random() <= (state.hailDamageChance or 0.42) then
      local entry = vehicles[math.random(#vehicles)]
      local exposure = isHailPathClear(entry.vehicle, entry.position)
      if exposure > 0 and math.random() <= exposure then
        local zone = pickWeightedHailZone()
        local distance = (entry.position - center):length()
        local distanceFalloff = 1 - clamp(distance / (state.hailRadius or 85), 0, 0.75)
        local strength = clamp(0.35 + hail.intensity * 0.55 + distanceFalloff * 0.22 + math.random() * 0.18, 0, 1.25)
        if queueHailStoneHit(entry.vehicle, zone, strength, hail.testDamage == true) then
          hits = hits + 1
          zoneHits[zone.name] = (zoneHits[zone.name] or 0) + 1
        end
      end
    end
  end

  return hits, zoneHits
end

local function getHazardChance(profileId, hazardName)
  if profileId == "supercell" then
    if hazardName == "hail" then return 0.56 end
    return 0.50
  end
  if profileId == "hail" then
    if hazardName == "hail" then return 0.72 end
    if hazardName == "microburst" then return 0.32 end
    return 0.10
  end
  if profileId == "storm" then
    if hazardName == "hail" then return 0.24 end
    if hazardName == "microburst" then return 0.22 end
  end
  if state.heavyStormMode then
    if hazardName == "hail" then return 0.25 end
    if hazardName == "microburst" then return 0.30 end
  end
  return 0
end

local function startHailstorm(reason)
  if not state.hailEnabled or state.hailstorm then
    return
  end

  local profileId = getCurrentBaseProfileId()
  local peakIntensity = profileId == "supercell" and 1.0 or (profileId == "hail" and 1.0 or 0.68)
  local serverEvent = state.pendingHailEvent
  state.hailstorm = {
    elapsed = 0,
    duration = state.pendingHailDuration or (26 + math.random() * 30),
    peakIntensity = peakIntensity,
    intensity = state.hailProgressionEnabled and peakIntensity * 0.22 or peakIntensity,
    visualTimer = 0,
    damageTimer = 0,
    reason = reason or "weather",
    eventId = serverEvent and serverEvent.eventId or nil,
    eventTimestamp = serverEvent and serverEvent.eventTimestamp or nil,
    syncSeed = serverEvent and tonumber(serverEvent.hailSyncSeed) or nil,
    center = serverEvent and tonumber(serverEvent.cellX) and vec3(tonumber(serverEvent.cellX), tonumber(serverEvent.cellY) or 0, tonumber(serverEvent.cellZ) or 0) or nil
  }
  state.hailstorm.testDamage = state.pendingHailTestDamage == true
  state.pendingHailDuration = nil
  state.pendingHailEvent = nil
  state.pendingHailTestDamage = false
  state.stormAmbienceTimer = math.max(state.stormAmbienceTimer or 0, 6)
  writeLog("I", string.format("Hail core started for %.1f seconds (%s)", state.hailstorm.duration, state.hailstorm.reason))
end

local function startMicroburst(reason)
  if not state.microburstEnabled or state.microburst then
    return
  end

  local profileId = getCurrentBaseProfileId()
  local multiplier = profileId == "supercell" and 4.8 or (profileId == "hail" and 3.9 or 3.2)
  state.microburst = {
    elapsed = 0,
    duration = 9 + math.random() * 10,
    radius = 70 + math.random() * 55,
    center = getPlayerPosition(),
    damageTimer = 0,
    reason = reason or "weather"
  }
  state.severeWindBoost = {
    multiplier = multiplier
  }
  state.stormAmbienceTimer = math.max(state.stormAmbienceTimer or 0, 8)
  applyWeatherValues(state.currentValues)
  writeLog("I", string.format("Microburst started for %.1f seconds (x%.1f wind)", state.microburst.duration, multiplier))
end

local function drawHailVisual(dt)
  if not state.hailstorm or not debugDrawer then
    return
  end

  local hail = state.hailstorm
  if (tonumber(hail.intensity) or 0) <= 0.03 then return end
  hail.visualTimer = (hail.visualTimer or 0) + dt
  local playerPos = getPlayerPosition()
  local visualScale = clamp((state.hailStoneCount or 18) / 90, 0.35, 4.2)
  local count = math.floor((26 + hail.intensity * 58) * visualScale)
  local canDrawStone = type(debugDrawer.drawSphere) == "function"
  for index = 1, count do
    local angle = math.random() * 6.28318530718
    local radius = math.random() * 90
    local height = 14 + math.random() * 48
    local streak = 4 + math.random() * 7
    local top = playerPos + vec3(math.cos(angle) * radius, math.sin(angle) * radius, height)
    local bottom = top + vec3(-1.8 - math.random() * 2.2, -0.8 - math.random() * 2.0, -streak)
    debugDrawer:drawLine(top:toPoint3F(), bottom:toPoint3F(), ColorF(0.72, 0.76, 0.78, 0.38))
    if canDrawStone and index % 2 == 0 then
      local stoneRadius = 0.035 + math.random() * 0.055 + hail.intensity * 0.018
      debugDrawer:drawSphere(bottom:toPoint3F(), stoneRadius, ColorF(0.48, 0.50, 0.52, 0.88))
      debugDrawer:drawSphere(bottom:toPoint3F(), stoneRadius * 0.48, ColorF(0.82, 0.88, 0.92, 0.62))
    end
  end
end

local function damageVehiclesNear(center, radius, hazardName, severity, cooldown)
  if type(activeVehiclesIterator) ~= "function" or not center then
    return 0
  end

  local damaged = 0
  for _, veh in activeVehiclesIterator() do
    local pos = getVehiclePosition(veh)
    if pos then
      local distance = (pos - center):length()
      if distance <= radius and queueVehicleHazardDamage(veh, hazardName, severity, cooldown) then
        damaged = damaged + 1
      end
    end
  end
  return damaged
end

local function updateHailstorm(dt)
  if not state.hailstorm then
    return
  end

  local hail = state.hailstorm
  hail.elapsed = hail.elapsed + dt
  hail.damageTimer = hail.damageTimer + dt
  local progress = clamp(hail.elapsed / math.max(0.1, hail.duration), 0, 1)
  local progressionScale = 1
  if state.hailProgressionEnabled then
    if progress < 0.30 then
      progressionScale = 0.22 + (progress / 0.30) * 0.78
    elseif progress > 0.80 then
      progressionScale = math.max(0.18, (1 - progress) / 0.20)
    end
  end
  local localIntensity = state.serverStormCell and clamp(state.localStormIntensity or 0, 0, 1) or 1
  hail.intensity = (hail.peakIntensity or hail.intensity or 1) * progressionScale * localIntensity
  drawHailVisual(dt)

  if hail.damageTimer >= (state.hailDamageInterval or 2.6) then
    hail.damageTimer = 0
    local hits, zoneHits = applyHailStoneImpacts(hail)
    if hits > 0 then
      local parts = {}
      for zoneName, count in pairs(zoneHits or {}) do
        parts[#parts + 1] = zoneName .. "=" .. tostring(count)
      end
      writeLog("I", string.format("Hail stones hit %d body panel(s): %s", hits, table.concat(parts, ", ")))
    end
  end

  if hail.elapsed >= hail.duration then
    state.hailstorm = nil
    writeLog("I", "Hail core ended")
  end
end

local function updateMicroburst(dt)
  if not state.microburst then
    return
  end

  local burst = state.microburst
  burst.elapsed = burst.elapsed + dt
  burst.damageTimer = burst.damageTimer + dt
  burst.center = getPlayerPosition()

  if burst.damageTimer >= 2.0 then
    burst.damageTimer = 0
    damageVehiclesNear(burst.center, burst.radius, "microburst", "damage", 5.5)
  end

  if burst.elapsed >= burst.duration then
    state.microburst = nil
    state.severeWindBoost = nil
    applyWeatherValues(state.currentValues)
    writeLog("I", "Microburst ended")
  end
end

local function drawFallbackRain(dt)
  if not debugDrawer or not state.currentValues or not state.currentValues.rainEnabled or state.dynamicPrecipitationActive then
    return
  end

  if state.currentValues.precipitationType == "snow" then
    return
  end

  local profileId = getCurrentBaseProfileId()
  local intensity = 0.35
  if profileId == "rain" then
    intensity = 0.58
  elseif profileId == "storm" then
    intensity = 0.82
  elseif profileId == "hail" or profileId == "supercell" then
    intensity = 1.0
  elseif profileId == "drizzle" then
    intensity = 0.32
  end
  if state.serverStormCell then intensity = intensity * clamp(state.localStormIntensity or 0, 0, 1) end
  if intensity <= 0.03 then return end

  local playerPos = getPlayerPosition()
  local count = math.floor(22 + intensity * 72)
  local windPush = (state.severeWindBoost and state.severeWindBoost.multiplier or 1) * 1.4
  for _ = 1, count do
    local angle = math.random() * 6.28318530718
    local radius = math.random() * 82
    local height = 8 + math.random() * 42
    local dropLength = 3.2 + intensity * 5.4 + math.random() * 3.5
    local top = playerPos + vec3(math.cos(angle) * radius, math.sin(angle) * radius, height)
    local bottom = top + vec3(-windPush - math.random() * 2.5, -0.7 - math.random() * 1.9, -dropLength)
    debugDrawer:drawLine(top:toPoint3F(), bottom:toPoint3F(), ColorF(0.56, 0.72, 0.95, 0.22 + intensity * 0.28))
  end
end

local function updateSevereHazards(dt)
  drawFallbackRain(dt)

  if state.serverStormCell then
    updateHailstorm(dt)
    updateMicroburst(dt)
    return
  end

  if not state.destructiveWeatherEnabled then
    updateHailstorm(dt)
    updateMicroburst(dt)
    return
  end

  local profileId = getCurrentBaseProfileId()

  if state.hailEnabled and not state.hailstorm then
    state.hailTimer = state.hailTimer + dt
    if state.hailTimer >= state.nextHailCheckIn then
      state.hailTimer = 0
      state.nextHailCheckIn = 16 + math.random() * 28
      if math.random() <= getHazardChance(profileId, "hail") then
        startHailstorm("scheduled")
      end
    end
  end

  if state.microburstEnabled and not state.microburst then
    state.microburstTimer = state.microburstTimer + dt
    if state.microburstTimer >= state.nextMicroburstCheckIn then
      state.microburstTimer = 0
      state.nextMicroburstCheckIn = 18 + math.random() * 34
      if math.random() <= getHazardChance(profileId, "microburst") then
        startMicroburst("scheduled")
      end
    end
  end

  updateHailstorm(dt)
  updateMicroburst(dt)
end

local function playThunderForStrike(strike)
  local distance = getPerceivedStrikeDistance(strike.impactPoint)
  local sequenceContinuing = state.lightningFlash and state.lightningFlash.remaining and state.lightningFlash.remaining > 1
  local primarySound = "art/sound/ashweather/thunder_far_sync.ogg"
  local emitterScale = 4
  local tailScale = 3
  local volume = 0.28

  if distance < 45 or strike.bigHit then
    primarySound = "art/sound/ashweather/thunder_close_sync.ogg"
    emitterScale = 6
    tailScale = 5
    volume = 0.38
  elseif distance < 120 then
    primarySound = "art/sound/ashweather/thunder_mid_sync.ogg"
    emitterScale = 5
    tailScale = 4
    volume = 0.32
  end

  playThunderAtPosition({
    position = vec3(strike.impactPoint),
    soundFile = primarySound,
    emitterScale = emitterScale,
    forceEmitter = distance < 70 or strike.bigHit,
    volume = volume
  })

  if not sequenceContinuing then
    playThunderAtPosition({
      position = vec3(
        strike.impactPoint.x + (math.random() * 2 - 1) * 7.0,
        strike.impactPoint.y + (math.random() * 2 - 1) * 7.0,
        strike.impactPoint.z
      ),
      soundFile = "art/sound/ashweather/thunder_roll_sync.ogg",
      emitterScale = tailScale,
      volume = volume * 0.72
    })
  end
end

local function playLightningStrikeSound(strike)
  local distance = getPerceivedStrikeDistance(strike.impactPoint)
  local soundFile = "art/sound/ashweather/lightning_strike_far_sync.ogg"
  local emitterScale = 5
  local volume = 0.58

  if distance < 70 or strike.bigHit then
    soundFile = "art/sound/ashweather/lightning_strike_close_sync.ogg"
    emitterScale = 7
    volume = 0.72
  elseif distance < 100 then
    soundFile = "art/sound/ashweather/lightning_strike_far_sync.ogg"
    emitterScale = 5
  end

  playThunderAtPosition({
    position = vec3(strike.impactPoint),
    soundFile = soundFile,
    emitterScale = emitterScale,
    forceEmitter = true,
    volume = volume
  })
end

local function soundPathForEmitter(soundFile)
  local value = tostring(soundFile or "")
  if value:sub(1, 1) == "/" then
    return value
  end
  return "/" .. value
end

M.weatherRuntime.thunderEmitterLifetimes = {
  ["art/sound/ashweather/lightning_strike_close_sync.ogg"] = 1.5,
  ["art/sound/ashweather/lightning_strike_far_sync.ogg"] = 8.5,
  ["art/sound/ashweather/thunder_close_sync.ogg"] = 7.1,
  ["art/sound/ashweather/thunder_far_sync.ogg"] = 5.9,
  ["art/sound/ashweather/thunder_mid_sync.ogg"] = 5.9,
  ["art/sound/ashweather/thunder_roll_sync.ogg"] = 11.8
}

function M.weatherRuntime.getThunderEmitterLifetime(entry)
  return tonumber(entry.cleanupAfter) or M.weatherRuntime.thunderEmitterLifetimes[tostring(entry.soundFile or "")] or 8
end

playThunderAtPosition = function (entry)
  if entry.forceEmitter then
    local emitter = createObject and createObject("SFXEmitter") or nil
    if emitter then
      local emitterScale = entry.emitterScale or 10
      emitter.scale = Point3F(emitterScale, emitterScale, emitterScale)
      emitter.fileName = String(soundPathForEmitter(entry.soundFile))
      emitter.volume = entry.volume or 0.45
      emitter.playOnAdd = true
      emitter.isLooping = false
      emitter.isStreaming = false
      emitter.is3D = true
      emitter:setPosition(entry.position:toPoint3F())
      emitter:registerObject(nextUniqueObjectName("ashweather_thunder"))
      trackThunderEmitter(emitter, M.weatherRuntime.getThunderEmitterLifetime(entry))
      return true
    end
  end

  if Engine and Engine.Audio and type(Engine.Audio.playOnce) == "function" then
    local ok = pcall(
      Engine.Audio.playOnce,
      "AudioGui",
      entry.soundFile,
      {position = entry.position:toPoint3F(), volume = entry.volume or 0.45}
    )
    if ok then
      return true
    end
  end

  local emitter = createObject and createObject("SFXEmitter") or nil
  if not emitter then
    return false
  end

  local emitterScale = entry.emitterScale or 10
  emitter.scale = Point3F(emitterScale, emitterScale, emitterScale)
  emitter.fileName = String(soundPathForEmitter(entry.soundFile))
  emitter.volume = entry.volume or 0.45
  emitter.playOnAdd = true
  emitter.isLooping = false
  emitter.isStreaming = false
  emitter.is3D = true
  emitter:setPosition(entry.position:toPoint3F())
  emitter:registerObject(nextUniqueObjectName("ashweather_thunder"))
  trackThunderEmitter(emitter, M.weatherRuntime.getThunderEmitterLifetime(entry))
  return true
end

local function updateThunderQueue(dt)
  if #state.thunderQueue == 0 then
    return
  end

  for index = #state.thunderQueue, 1, -1 do
    local entry = state.thunderQueue[index]
    entry.timer = entry.timer - dt
    if entry.timer <= 0 then
      playThunderAtPosition(entry)
      table.remove(state.thunderQueue, index)
    end
  end
end

local function applyStrikeImpactDamage(strike)
  if strike.impactApplied then
    return
  end

  strike.impactApplied = true

  local targetVehicle = strike.hitVehicle
  if targetVehicle then
    local pos = getVehiclePosition(targetVehicle)
    if pos then
      playVehicleElectricalPop(pos)
    end
    damageVehicleFromStrike(targetVehicle, true, strike)
  end
end

local function startLightningEnvironmentPulse(strike)
  local distance = getDistanceToPlayer(strike.impactPoint)
  local closeness = 1 - clamp(distance / 90.0, 0, 1)

  state.lightningEnvironment = {
    age = 0,
    duration = 0.18 + closeness * 0.28 + (strike.bigHit and 0.10 or 0.0),
    afterglowDuration = 0.55 + closeness * 0.55,
    windPeak = 0.10 + closeness * 0.36 + (strike.bigHit and 0.08 or 0.0),
    windBoost = 0.10 + closeness * 0.36 + (strike.bigHit and 0.08 or 0.0)
  }
  applyWeatherValues(state.currentValues)
end

local function createWorldLightningStrike(reason)
  local anchor = getPlayerPosition()
  local serverEvent = state.pendingLightningEvent
  state.pendingLightningEvent = nil
  local serverX = serverEvent and tonumber(serverEvent.strikeX)
  local serverY = serverEvent and tonumber(serverEvent.strikeY)
  local serverZ = serverEvent and tonumber(serverEvent.strikeZ)
  local authoritativePoint = serverX and serverY and serverZ and vec3(serverX, serverY, serverZ) or nil
  local targetVehicle, vehicleTargetPos = nil, nil
  if authoritativePoint and serverEvent.lightningAuthoritativeVehicleTarget == true then
    local candidate = getPlayerVehicle()
    local candidatePos = getVehiclePosition(candidate)
    if candidatePos and (state.lightningIgnoreShelter or M.weatherRuntime.getVehicleShelterExposure(candidate, candidatePos) > 0) then
      targetVehicle, vehicleTargetPos = candidate, candidatePos
    end
  elseif not authoritativePoint then
    targetVehicle, vehicleTargetPos = findStrikeTarget(anchor, state.lightningForceVehicleTarget)
  end
  local usePlayerTarget = (not authoritativePoint) and (not state.lightningForceVehicleTarget) and (state.lightningForcePlayerTarget or math.random() < (state.lightningPlayerHitChance or 0))
  local useVehicleTarget = (not usePlayerTarget) and vehicleTargetPos ~= nil
  local visualDirectHit = authoritativePoint and serverEvent.lightningVisualDirectHit == true or (useVehicleTarget or usePlayerTarget)

  local target
  local impactPoint
  if authoritativePoint then
    target = vec3(authoritativePoint.x, authoritativePoint.y, authoritativePoint.z)
    target.z = getGroundHeightBelow(target)
    impactPoint = vec3(target.x, target.y, target.z + 0.04)
  elseif usePlayerTarget then
    local playerImpact = getGroundHeightBelow(anchor)
    impactPoint = vec3(anchor.x, anchor.y, playerImpact + 0.04)
    target = vec3(anchor.x, anchor.y, math.max(impactPoint.z + 0.18, anchor.z + 0.38))
  elseif useVehicleTarget then
    writeLog("I", "Lightning direct vehicle target selected")
    local groundImpact = getGroundHeightBelow(vehicleTargetPos)
    impactPoint = vec3(vehicleTargetPos.x, vehicleTargetPos.y, groundImpact + 0.04)
    target = vec3(vehicleTargetPos.x, vehicleTargetPos.y, math.max(impactPoint.z + 0.18, vehicleTargetPos.z + 0.38))
  else
    local maxRadius = math.max(1, state.lightningStrikeRadius or 50)
    local distance = 4 + math.random() * maxRadius
    local angle = math.random() * math.pi * 2
    target = vec3(
      anchor.x + math.cos(angle) * distance,
      anchor.y + math.sin(angle) * distance,
      anchor.z
    )
    target.z = getGroundHeightBelow(target)
    impactPoint = vec3(target.x, target.y, target.z + 0.04)
  end

  local start = vec3(target.x, target.y, target.z + 165 + math.random() * 95)
  local rayHit = resolveLightningRayHit(start, target)
  if rayHit and rayHit.pt then
    local hitPoint = vec3(rayHit.pt)
    local hitNormal = rayHit.norm and vec3(rayHit.norm) or vec3(0, 0, 1)
    local directTolerance = 1.75
    if useVehicleTarget and targetVehicle and type(targetVehicle.getSpawnWorldOOBB) == "function" then
      local boxOk, box = pcall(targetVehicle.getSpawnWorldOOBB, targetVehicle)
      if boxOk and box then
        local halfOk, half = pcall(box.getHalfExtents, box)
        if halfOk and half then directTolerance = math.max(directTolerance, half.z * 2 + 0.65) end
      end
    end
    local blockedVehicleTarget = useVehicleTarget and not state.lightningIgnoreShelter and (hitPoint - target):length() > directTolerance
    target = hitPoint
    impactPoint = hitPoint + hitNormal * 0.04
    if blockedVehicleTarget then
      targetVehicle = nil
      useVehicleTarget = false
    end
  end
  local leaderBolt = buildSteppedLightningPolyline(start, target, 15 + math.random(6), 16 + math.random() * 12)
  local mainBolt = buildLightningPolyline(start, target, 18 + math.random(6), 9 + math.random() * 8)
  local coreBolt = buildOffsetLightningLayer(mainBolt, 0.55 + math.random() * 0.35)
  local returnBolt = buildSteppedLightningPolyline(start, target, 20 + math.random(5), 4.5 + math.random() * 3.2)
  local glowBoltA = buildOffsetLightningLayer(mainBolt, 1.8 + math.random() * 1.4)
  local glowBoltB = buildOffsetLightningLayer(mainBolt, 3.2 + math.random() * 2.1)
  local haloBolt = buildOffsetLightningLayer(mainBolt, 5.5 + math.random() * 2.8)
  local branches = buildBranchCluster(mainBolt, 5 + math.random(5), 18 + math.random() * 12)
  local upperBranches = buildBranchCluster(leaderBolt, 2 + math.random(3), 12 + math.random() * 9)
  local secondaryStrokeEnabled = math.random() < (getCurrentBaseProfileId() == "storm" and 0.42 or 0.24)
  local boltThickness = (visualDirectHit and 1.7 or 1.35) + math.random() * 1.8
  local bigHit = math.random() < (visualDirectHit and 0.50 or 0.26)
  local colorPalette = pickLightningColorPalette()
  local mainShells, coreShells, leaderShells, returnShells
  local branchShells = {}
  local upperBranchShells = {}

  state.worldLightning = {
    reason = reason or "strike",
    age = 0,
    duration = 0.24 + math.random() * 0.08,
    impactDuration = 0.26 + math.random() * 0.12,
    leaderDuration = 0.035 + math.random() * 0.025,
    mainDelay = 0.022 + math.random() * 0.028,
    mainDuration = 0.090 + math.random() * 0.040,
    afterglowDuration = 0.06 + math.random() * 0.04,
    flickerRate = 52 + math.random() * 28,
    leaderBolt = leaderBolt,
    mainBolt = mainBolt,
    coreBolt = coreBolt,
    returnBolt = returnBolt,
    glowBoltA = glowBoltA,
    glowBoltB = glowBoltB,
    haloBolt = haloBolt,
    branches = branches,
    upperBranches = upperBranches,
    mainShells = mainShells,
    coreShells = coreShells,
    leaderShells = leaderShells,
    returnShells = returnShells,
    branchShells = branchShells,
    upperBranchShells = upperBranchShells,
    startPoint = start,
    targetPoint = target,
    impactPoint = impactPoint,
    impactRadius = 3.8 + math.random() * 3.6,
    directDamageRadius = state.lightningDirectDamageRadius or 2,
    splashDamageRadius = state.lightningSplashDamageRadius or 4,
    hitVehicle = useVehicleTarget and targetVehicle or nil,
    impactApplied = false,
    audioPlayed = false,
    bigHit = bigHit,
    colorPalette = colorPalette,
    boltThickness = boltThickness,
    cloudRadius = 16 + math.random() * 10,
    returnPulse = 0.7 + math.random() * 0.6,
    secondStrokeEnabled = secondaryStrokeEnabled,
    secondStrokeDelay = 0.11 + math.random() * 0.14,
    secondStrokeDuration = 0.08 + math.random() * 0.06,
    secondStrokePower = 1.1 + math.random() * 0.9,
    impactEmitterScale = 0.9 + boltThickness * 0.5 + math.random() * 0.55
  }
  state.worldLightning.eventId = serverEvent and serverEvent.eventId or nil
  state.worldLightning.eventTimestamp = serverEvent and serverEvent.eventTimestamp or nil
  state.worldLightnings[#state.worldLightnings + 1] = state.worldLightning
  state.worldLightning.texturedRibbonSpawned = spawnTexturedLightningRibbons(state.worldLightning)
  if not state.worldLightning.texturedRibbonSpawned then
    state.worldLightning.mainShells = buildLightningShell(mainBolt, 8 + math.random(4), 1.1 + boltThickness * 1.05, 0.09)
    state.worldLightning.coreShells = buildLightningShell(coreBolt, 5 + math.random(3), 0.46 + boltThickness * 0.46, 0.15)
    state.worldLightning.leaderShells = buildLightningShell(leaderBolt, 5, 0.70 + boltThickness * 0.46, 0.13)
    state.worldLightning.returnShells = buildLightningShell(returnBolt, 5 + math.random(2), 0.52 + boltThickness * 0.48, 0.13)
    for index, branch in ipairs(branches) do
      state.worldLightning.branchShells[index] = buildLightningShell(branch, 4 + math.random(2), 0.44 + boltThickness * 0.34, 0.18)
    end
    for index, branch in ipairs(upperBranches) do
      state.worldLightning.upperBranchShells[index] = buildLightningShell(branch, 3, 0.36 + boltThickness * 0.26, 0.22)
    end
  end
  playLightningStrikeSound(state.worldLightning)
  playThunderForStrike(state.worldLightning)
  state.worldLightning.audioPlayed = true
  startLightningEnvironmentPulse(state.worldLightning)
  state.lightningIgnoreShelter = false
end

local function drawLightningPolyline(points, colorValue)
  if not debugDrawer or type(debugDrawer.drawLine) ~= "function" then
    return
  end

  for index = 1, #points - 1 do
    debugDrawer:drawLine(points[index]:toPoint3F(), points[index + 1]:toPoint3F(), colorValue)
  end
end

local function drawLightningShell(shellLayers, colorValue)
  if not shellLayers then
    return
  end

  for _, layer in ipairs(shellLayers) do
    drawLightningPolyline(layer, colorValue)
  end
end

local function getPhasePulse(age, startTime, riseDuration, holdDuration, fallDuration)
  if age < startTime then
    return 0
  end

  local t = age - startTime
  if t < riseDuration then
    return clamp(t / math.max(riseDuration, 0.0001), 0, 1)
  end

  t = t - riseDuration
  if t < holdDuration then
    return 1
  end

  t = t - holdDuration
  if t < fallDuration then
    return clamp(1 - (t / math.max(fallDuration, 0.0001)), 0, 1)
  end

  return 0
end

local function updateLightningEnvironment(dt)
  if not state.lightningEnvironment then
    return
  end

  local env = state.lightningEnvironment
  env.age = env.age + dt

  local flashLife = 1 - clamp(env.age / math.max(env.duration, 0.0001), 0, 1)
  local afterglowLife = 1 - clamp((env.age - env.duration * 0.35) / math.max(env.afterglowDuration, 0.0001), 0, 1)
  env.windBoost = env.windPeak * math.max(0, flashLife * 0.72 + math.max(0, afterglowLife) * 0.45)

  if env.age >= env.duration + env.afterglowDuration then
    state.lightningEnvironment = nil
    applyWeatherValues(state.currentValues)
    return
  end

  applyWeatherValues(state.currentValues)
end

local function updateStormAmbience(dt)
  if not state.stormAmbienceTimer or state.stormAmbienceTimer <= 0 then
    return
  end

  state.stormAmbienceTimer = math.max(0, state.stormAmbienceTimer - dt)
  applyWeatherValues(state.currentValues)
end

function M.weatherRuntime.drawSingleWorldLightning(strike, dt)
  strike.age = strike.age + dt

  if strike.age > strike.duration + strike.impactDuration then
    return false
  end

  if strike.age > strike.mainDelay + strike.mainDuration * 0.28 and not strike.impactApplied then
    applyStrikeImpactDamage(strike)
    if not strike.audioPlayed then
      playLightningStrikeSound(strike)
      playThunderForStrike(strike)
      strike.audioPlayed = true
    end
    spawnImpactParticles(strike)
    spawnScorchAftermathParticles(strike)
  end

  if not debugDrawer then
    return true
  end

  local normalizedAge = clamp(strike.age / strike.duration, 0, 1)
  local leaderPulse = getPhasePulse(strike.age, 0, strike.leaderDuration * 0.22, strike.leaderDuration * 0.35, strike.leaderDuration * 0.65)
  local mainPulse = getPhasePulse(strike.age, strike.mainDelay, 0.012, strike.mainDuration * 0.34, strike.mainDuration * 0.70)
  local afterglowPulse = getPhasePulse(strike.age, strike.mainDelay + strike.mainDuration * 0.28, 0.02, strike.afterglowDuration * 0.24, strike.afterglowDuration)
  local phaseBlend = math.max(mainPulse, afterglowPulse * 0.55)
  local returnFlash = math.max(0, math.sin(normalizedAge * math.pi * strike.returnPulse)) * math.max(mainPulse, afterglowPulse * 0.45)
  local secondStrokeAlpha = 0
  if strike.secondStrokeEnabled and strike.age >= strike.secondStrokeDelay and strike.age <= strike.secondStrokeDelay + strike.secondStrokeDuration then
    local secondStrokeProgress = clamp((strike.age - strike.secondStrokeDelay) / strike.secondStrokeDuration, 0, 1)
    secondStrokeAlpha = (1 - secondStrokeProgress) * 0.95
  end
  local strobe = 0.76 + math.max(0, math.sin(strike.age * strike.flickerRate)) * 0.24
  local leaderAlpha = clamp((leaderPulse * 0.86) + phaseBlend * 0.14 - normalizedAge * 0.10, 0, 0.88)
  local haloAlpha = 0
  local glowAlphaA = 0
  local glowAlphaB = 0
  local coreAlpha = (0.68 + returnFlash * 0.24) * math.max(mainPulse, secondStrokeAlpha * 0.55)
  local boltAlpha = (0.84 + returnFlash * 0.12) * math.max(mainPulse, leaderPulse * 0.22)
  local palette = strike.colorPalette or lightningColorPalettes[2]

  local leaderColor = paletteColor(palette, "leader", leaderAlpha * strobe * 0.72)
  local haloColor = ColorF(0.26, 0.46, 0.98, haloAlpha)
  local glowColorB = ColorF(0.36, 0.60, 1.0, glowAlphaB * strobe)
  local glowColorA = ColorF(0.55, 0.80, 1.0, glowAlphaA * strobe)
  local branchColor = paletteColor(palette, "branch", coreAlpha * 0.62)
  local boltColor = paletteColor(palette, "bolt", boltAlpha)
  local coreColor = paletteColor(palette, "core", coreAlpha)
  local secondStrokeColor = paletteColor(palette, "core", secondStrokeAlpha)
  local leaderShellColor = paletteColor(palette, "shell", leaderAlpha * strobe * 0.20)
  local mainShellColor = paletteColor(palette, "shell", (0.22 + returnFlash * 0.10) * strobe * math.max(mainPulse, afterglowPulse * 0.35))
  local coreShellColor = paletteColor(palette, "core", (0.38 + returnFlash * 0.18) * math.max(mainPulse, secondStrokeAlpha * 0.45))
  local branchShellColor = paletteColor(palette, "shell", coreAlpha * 0.14)
  local secondStrokeShellColor = paletteColor(palette, "shell", secondStrokeAlpha * 0.38)

  -- Scripted lines remain only as a fallback if the textured procedural mesh cannot be created.
  if not strike.texturedRibbonSpawned and leaderColor.alpha > 0.01 then
    if not strike.texturedRibbonSpawned then
      drawLightningShell(strike.leaderShells, leaderShellColor)
    end
    drawLightningPolyline(strike.leaderBolt, leaderColor)
  end
  if not strike.texturedRibbonSpawned and branchColor.alpha > 0.01 then
    for index, branch in ipairs(strike.branches) do
      if not strike.texturedRibbonSpawned then
        drawLightningShell(strike.branchShells and strike.branchShells[index], branchShellColor)
      end
      drawLightningPolyline(branch, branchColor)
    end
    for index, branch in ipairs(strike.upperBranches) do
      if not strike.texturedRibbonSpawned then
        drawLightningShell(strike.upperBranchShells and strike.upperBranchShells[index], paletteColor(palette, "shell", branchShellColor.alpha * 0.45))
      end
      drawLightningPolyline(branch, paletteColor(palette, "branch", branchColor.alpha * 0.45))
    end
  end
  if not strike.texturedRibbonSpawned and mainShellColor.alpha > 0.01 then
    if not strike.texturedRibbonSpawned then
      drawLightningShell(strike.mainShells, mainShellColor)
    end
    drawLightningPolyline(strike.mainBolt, boltColor)
    if not strike.texturedRibbonSpawned then
      drawLightningShell(strike.coreShells, coreShellColor)
    end
    drawLightningPolyline(strike.coreBolt, coreColor)
  end
  if not strike.texturedRibbonSpawned and secondStrokeAlpha > 0 then
    drawLightningPolyline(strike.glowBoltA, paletteColor(palette, "bolt", secondStrokeAlpha * 0.42 * strike.secondStrokePower))
    if not strike.texturedRibbonSpawned then
      drawLightningShell(strike.returnShells, secondStrokeShellColor)
    end
    drawLightningPolyline(strike.returnBolt, secondStrokeColor)
  end

  if not strike.texturedRibbonSpawned and type(debugDrawer.drawSphere) == "function" then
    local cloudPoint = strike.mainBolt[1]
    local cloudRadius = strike.cloudRadius * (0.78 + returnFlash * 0.55 + leaderPulse * 0.18)
    debugDrawer:drawSphere(cloudPoint:toPoint3F(), cloudRadius, paletteColor(palette, "cloud", 0.10 + returnFlash * 0.12 + afterglowPulse * 0.08))
    debugDrawer:drawSphere(cloudPoint:toPoint3F(), cloudRadius * 0.45, paletteColor(palette, "core", 0.14 + returnFlash * 0.10 + mainPulse * 0.10))
  end

  return true
end

local function drawWorldLightning(dt)
  for index = #state.worldLightnings, 1, -1 do
    if not M.weatherRuntime.drawSingleWorldLightning(state.worldLightnings[index], dt) then
      table.remove(state.worldLightnings, index)
    end
  end
  state.worldLightning = state.worldLightnings[#state.worldLightnings]
end

local function drawStrikeResidue(dt)
  if #state.strikeResidue == 0 or not debugDrawer or type(debugDrawer.drawSphere) ~= "function" then
    return
  end

  for index = #state.strikeResidue, 1, -1 do
    local residue = state.strikeResidue[index]
    residue.age = residue.age + dt
    if residue.age >= residue.duration then
      table.remove(state.strikeResidue, index)
    else
      local bloomLife = 1 - clamp(residue.age / math.max(residue.bloomDuration, 0.0001), 0, 1)
      local scorchLife = 1 - clamp(residue.age / math.max(residue.duration, 0.0001), 0, 1)
      local dustLife = 1 - clamp(residue.age / math.max(residue.duration * 0.75, 0.0001), 0, 1)
      debugDrawer:drawSphere(residue.position:toPoint3F(), residue.scorchRadius * (0.82 + scorchLife * 0.20), ColorF(0.16, 0.10, 0.08, scorchLife * 0.34))
      debugDrawer:drawSphere(residue.position:toPoint3F(), residue.dustRadius * (0.48 + dustLife * 0.36), ColorF(0.42, 0.38, 0.34, dustLife * 0.10))
      if bloomLife > 0 then
        debugDrawer:drawSphere(residue.position:toPoint3F(), residue.bloomRadius * (0.60 + bloomLife * 0.95), ColorF(0.98, 0.97, 0.90, bloomLife * 0.28))
        debugDrawer:drawSphere(residue.position:toPoint3F(), residue.bloomRadius * (0.34 + bloomLife * 0.56), ColorF(1.0, 0.86, 0.34, bloomLife * 0.26))
      end

      for smokeIndex = #residue.smokeWisps, 1, -1 do
        local wisp = residue.smokeWisps[smokeIndex]
        wisp.age = wisp.age + dt
        if wisp.age >= wisp.duration then
          table.remove(residue.smokeWisps, smokeIndex)
        else
          local smokeLife = 1 - (wisp.age / wisp.duration)
          local smokePos = residue.position + wisp.offset + (wisp.drift * wisp.age * 0.75)
          debugDrawer:drawSphere(smokePos:toPoint3F(), wisp.radius * (0.72 + (1 - smokeLife) * 0.85), ColorF(0.26, 0.26, 0.28, smokeLife * 0.16))
          debugDrawer:drawSphere(smokePos:toPoint3F(), wisp.radius * 0.58, ColorF(0.42, 0.40, 0.38, smokeLife * 0.09))
        end
      end

      for sparkIndex = #residue.sparks, 1, -1 do
        local spark = residue.sparks[sparkIndex]
        spark.age = spark.age + dt
        if spark.age >= spark.duration then
          table.remove(residue.sparks, sparkIndex)
        else
          local sparkLife = 1 - (spark.age / spark.duration)
          local flicker = 0.70 + math.max(0, math.sin((residue.age + spark.age) * 55 + sparkIndex)) * 0.30
          local sparkPos = residue.position + spark.offset
          debugDrawer:drawSphere(sparkPos:toPoint3F(), spark.radius * (0.55 + sparkLife * 0.95), ColorF(1.0, 0.82, 0.20, sparkLife * flicker))
          debugDrawer:drawSphere(sparkPos:toPoint3F(), spark.radius * 0.38, ColorF(1.0, 0.97, 0.72, sparkLife * 0.95))
        end
      end
    end
  end
end

local function getLightningChance(profileId)
  if profileId == "supercell" then
    return 0.88
  end
  if profileId == "hail" then
    return 0.54
  end
  if profileId == "storm" then
    return 0.65
  end
  if profileId == "rain" then
    return 0.05
  end
  return 0.0
end

local function getBurstWindMultiplier(profileId)
  local profile = getProfile(profileId)
  local minimum = math.max(1, tonumber(profile.burstMinMultiplier) or 1.08)
  local maximum = math.max(minimum, tonumber(profile.burstMaxMultiplier) or minimum)
  return minimum + math.random() * (maximum - minimum)
end

local function getNextBurstInterval(profileId)
  local profile = getProfile(profileId)
  local minimum = math.max(2, tonumber(profile.burstMinInterval) or 30)
  local maximum = math.max(minimum, tonumber(profile.burstMaxInterval) or minimum)
  return minimum + math.random() * (maximum - minimum)
end

local function getSerializableState()
  return {
    activated = state.activated,
    enabled = state.enabled,
    dynamicMode = state.dynamicMode,
    levelName = state.levelName,
    sessionScope = state.sessionScope,
    activeProfileId = state.activeProfileId,
    currentProfileId = state.currentProfileId,
    targetProfileId = state.targetProfileId,
    timeInProfile = state.timeInProfile,
    nextChangeIn = state.nextChangeIn,
    transition = state.transition,
    currentValues = state.currentValues,
    rainObjectsActive = state.rainObjectsActive,
    lightningEnabled = state.lightningEnabled,
    autoLightningEnabled = state.autoLightningEnabled,
    autoLightningStrikeCount = state.autoLightningStrikeCount,
    autoLightningInterval = state.autoLightningInterval,
    lightningStrikeRadius = state.lightningStrikeRadius,
    lightningVehicleHitChance = state.lightningVehicleHitChance,
    lightningPlayerHitChance = state.lightningPlayerHitChance,
    lightningForcePlayerTarget = state.lightningForcePlayerTarget,
    lightningForceVehicleTarget = state.lightningForceVehicleTarget,
    lightningDirectDamageRadius = state.lightningDirectDamageRadius,
    lightningSplashDamageRadius = state.lightningSplashDamageRadius,
    lightningEmpEffectChance = state.lightningEmpEffectChance,
    lightningDestroyChance = state.lightningDestroyChance,
    lightningNoEffectChance = state.lightningNoEffectChance,
    lightningExplosionsEnabled = state.lightningExplosionsEnabled,
    windBurstsEnabled = state.windBurstsEnabled,
    stormBiasScale = state.stormBiasScale,
    transitionScale = state.transitionScale,
    vehicleDamageEnabled = state.vehicleDamageEnabled,
    damageTier = state.damageTier,
    destructiveWeatherEnabled = state.destructiveWeatherEnabled,
    hailEnabled = state.hailEnabled,
    hailDamageChance = state.hailDamageChance,
    hailStoneCount = state.hailStoneCount,
    hailRadius = state.hailRadius,
    hailDamageInterval = state.hailDamageInterval,
    microburstEnabled = state.microburstEnabled,
    heavyStormMode = state.heavyStormMode,
    heavyStormInterval = state.heavyStormInterval
  }
end

local function saveSessionState(reason)
  if not shouldPersistSession() then
    return false
  end

  local payload = getSerializableState()
  payload.savedAt = os.time()
  payload.reason = reason or "periodic"

  local ok = tryWriteJsonFile(getSessionSavePath(), payload)
  if ok then
    writeLog("I", string.format("Saved weather state for %s on '%s' (%s)", state.sessionScope, state.levelName, payload.reason))
  end
  return ok
end

local function loadSessionState()
  if not shouldPersistSession() then
    return nil
  end

  return tryReadJsonFile(getSessionSavePath())
end

local function triggerLightning(reason, syncSeed)
  if not state.lightningEnabled then
    return
  end

  local info = {
    levelName = state.levelName,
    sessionScope = state.sessionScope,
    profileId = getCurrentBaseProfileId(),
    reason = reason or "random"
  }

  state.lightningVisualNonce = state.lightningVisualNonce + 1
  state.lightningVisualStrength = 0
  state.stormAmbienceTimer = math.max(state.stormAmbienceTimer or 0, 6.5)

  pulseLightningObjects()
  runWithLightningSeed(syncSeed, function()
    createWorldLightningStrike(info.reason)
  end)
  extensions.hook("onAshWeatherLightning", info)
  writeLog("I", string.format("Lightning hook fired during '%s' (%s)", getProfile(info.profileId).label, info.reason))
end

function M.weatherRuntime.queueSyncedLightning(settings)
  state.pendingSyncedLightning[#state.pendingSyncedLightning + 1] = {
    settings = settings,
    delay = math.max(0, tonumber(settings.lightningSyncDelay) or 0.35)
  }
end

function M.weatherRuntime.updateSyncedLightning(dt)
  for index = #state.pendingSyncedLightning, 1, -1 do
    local entry = state.pendingSyncedLightning[index]
    entry.delay = entry.delay - dt
    if entry.delay <= 0 then
      table.remove(state.pendingSyncedLightning, index)
      state.pendingLightningEvent = entry.settings
      triggerLightning("beammp synchronized", tonumber(entry.settings.lightningSyncSeed))
    end
  end
end

local function startLightningSequence(reason, forcedCount, syncSeed)
  if not state.lightningEnabled then
    return
  end

  local strikeCount = tonumber(forcedCount)
  if not strikeCount or strikeCount < 1 then
    strikeCount = math.random(1, 3)
    if getCurrentBaseProfileId() == "supercell" then
      strikeCount = math.random(4, 7)
    elseif getCurrentBaseProfileId() == "hail" then
      strikeCount = math.random(3, 5)
    elseif getCurrentBaseProfileId() == "storm" then
      strikeCount = math.random(2, 4)
    end
  end
  strikeCount = math.floor(clamp(strikeCount, 1, 8))

  local numericSeed = tonumber(syncSeed)
  state.lightningFlash = {
    reason = reason or "sequence",
    remaining = strikeCount,
    timer = 0,
    phase = "idle",
    phaseDuration = numericSeed and 0.06 or (0.05 + math.random() * 0.06),
    syncSeed = numericSeed,
    fired = 0
  }

  writeLog("I", string.format("Lightning strike sequence started (%d flashes)", strikeCount))
end

local function updateLightningSequence(dt)
  if not state.lightningFlash then
    return
  end

  local flash = state.lightningFlash
  flash.timer = flash.timer + dt
  if flash.timer < flash.phaseDuration then
    return
  end

  flash.timer = 0

  if flash.phase == "idle" then
    flash.phase = "flash"
    flash.phaseDuration = flash.syncSeed and 0.055 or (0.04 + math.random() * 0.05)
    pulseLightningObjects()
    flash.fired = (flash.fired or 0) + 1
    local strikeSeed = flash.syncSeed and (flash.syncSeed + flash.fired * 7919) or nil
    triggerLightning(flash.reason, strikeSeed)
    return
  end

  clearLightningObjects()
  flash.remaining = flash.remaining - 1
  if flash.remaining <= 0 then
    state.lightningFlash = nil
    return
  end

  flash.phase = "idle"
  flash.phaseDuration = flash.syncSeed and (0.11 + ((flash.fired or 1) % 4) * 0.045) or (0.08 + math.random() * 0.22)
end

local function maybeStartWindBurst()
  if not state.windBurstsEnabled or state.burst then
    return
  end

  local profileId = getCurrentBaseProfileId()
  local severeProfile = profileId == "storm" or profileId == "hail" or profileId == "supercell"
  state.burst = {
    active = true,
    elapsed = 0,
    duration = 2.5 + math.random() * (severeProfile and 4.5 or 3.0),
    multiplier = getBurstWindMultiplier(profileId)
  }

  applyWeatherValues(state.currentValues)
  writeLog("I", string.format("Wind burst started for %.1f seconds (x%.2f)", state.burst.duration, state.burst.multiplier))
end

local function updateWindBurst(dt)
  if not state.windBurstsEnabled then
    return
  end

  if not state.burst or not state.burst.active then
    if state.serverStormCell then return end
    state.timeSinceBurst = state.timeSinceBurst + dt
    if state.timeSinceBurst >= state.nextBurstCheckIn then
      state.timeSinceBurst = 0
      state.nextBurstCheckIn = getNextBurstInterval(getCurrentBaseProfileId())
      maybeStartWindBurst()
    end
    return
  end

  state.burst.elapsed = state.burst.elapsed + dt
  if state.burst.elapsed >= state.burst.duration then
    state.burst = nil
    applyWeatherValues(state.currentValues)
    writeLog("I", "Wind burst ended")
  else
    applyWeatherValues(state.currentValues)
  end
end

local function updateLightning(dt)
  if not state.lightningEnabled then
    return
  end

  if state.serverStormCell then return end

  -- BeamMP sends authoritative strikes with shared coordinates and seeds. Do
  -- not also run the per-client scheduler, or every client renders extra,
  -- unsynchronised heavy-storm sequences.
  if state.serverAutoLightning then return end

  if not state.autoLightningEnabled and not state.heavyStormMode then
    return
  end

  if state.heavyStormMode then
    state.heavyStormTimer = state.heavyStormTimer + dt
    if state.heavyStormTimer >= state.heavyStormInterval then
      state.heavyStormTimer = 0
      if getCurrentBaseProfileId() ~= "storm" and not state.transition then
        startTransition("storm", math.max(0.35, getTransitionDuration() * 0.45), "heavy storm")
      end
      startLightningSequence("heavy storm", math.max(state.autoLightningStrikeCount + 1, 2))
    end
    return
  end

  state.timeSinceLightning = state.timeSinceLightning + dt
  if state.timeSinceLightning < state.autoLightningInterval then
    return
  end

  state.timeSinceLightning = 0

  local profileId = getCurrentBaseProfileId()
  if math.random() <= getLightningChance(profileId) then
    if state.autoLightningStrikeCount > 1 then
      startLightningSequence("scheduled", state.autoLightningStrikeCount)
    else
      triggerLightning("scheduled")
    end
  end
end

local function finishTransition()
  if not state.transition then
    return
  end

  state.activeProfileId = state.transition.targetProfileId
  state.currentProfileId = state.transition.targetProfileId
  state.targetProfileId = nil
  state.transition = nil
  state.timeInProfile = 0
  state.nextChangeIn = getProfileDuration(state.activeProfileId)
  state.timeSinceBurst = 0
  state.timeSinceLightning = 0
  state.nextBurstCheckIn = getNextBurstInterval(state.activeProfileId)
  M.weatherRuntime.activateNativeWeather(state.activeProfileId)

  writeLog("I", string.format("Weather settled into '%s' for %.0f seconds", getProfile(state.activeProfileId).label, state.nextChangeIn))
end

startTransition = function(targetProfileId, duration, reason)
  local targetProfile = getProfile(targetProfileId)
  local sourceValues = {
    tod = state.currentValues.tod,
    windSpeed = state.currentValues.windSpeed,
    fogDensity = state.currentValues.fogDensity,
    rainEnabled = state.currentValues.rainEnabled,
    rainAmount = state.currentValues.rainAmount,
    precipitationType = state.currentValues.precipitationType,
    cloudCover = state.currentValues.cloudCover,
    temperatureC = state.currentValues.temperatureC,
    brightness = state.currentValues.brightness,
    roadCondition = state.currentValues.roadCondition,
    roadWetRoughness = state.currentValues.roadWetRoughness,
    maxWaterRise = state.currentValues.maxWaterRise,
    waterRiseRate = state.currentValues.waterRiseRate
  }

  local targetKeepsFrozenRoads = targetProfile.precipitationType == "snow" or targetProfile.roadCondition == "ice"
  if targetProfile.rainEnabled ~= true and not targetKeepsFrozenRoads then
    M.weatherRuntime.clearRainRoadEffects()
    sourceValues.rainEnabled = false
    sourceValues.rainAmount = 0
    sourceValues.roadCondition = "dry"
    sourceValues.roadWetRoughness = 0
  end

  state.currentProfileId = targetProfileId
  state.targetProfileId = targetProfileId
  state.timeInProfile = 0
  state.burst = nil
  state.windDirectionTimer = 0
  state.windDirectionStartRadians = state.windDirectionRadians or 0
  state.windDirectionTargetRadians = state.windDirectionRadians or 0
  state.windDirectionTurnElapsed = state.windDirectionTurnDuration or 18
  state.transition = {
    sourceValues = sourceValues,
    targetValues = buildProfileSnapshot(targetProfileId),
    sourceProfileId = state.activeProfileId,
    targetProfileId = targetProfileId,
    elapsed = 0,
    duration = math.max(0.01, duration or getTransitionDuration()),
    reason = reason or "scheduled"
  }
  M.weatherRuntime.switchNativeWeather(targetProfileId, state.transition.duration)

  writeLog("I", string.format("Transitioning to '%s' over %.0f seconds (%s)", targetProfile.label, state.transition.duration, state.transition.reason))
end

local function applyTransitionStep(dt)
  if not state.transition then
    return
  end

  state.transition.elapsed = state.transition.elapsed + dt
  local progress = clamp(state.transition.elapsed / state.transition.duration, 0, 1)

  local sourceValues = state.transition.sourceValues
  local targetValues = state.transition.targetValues
  local useTargetRain = progress >= 0.55

  applyWeatherValues({
    tod = lerpWrapped(sourceValues.tod, targetValues.tod, progress),
    windSpeed = lerp(sourceValues.windSpeed, targetValues.windSpeed, progress),
    fogDensity = lerp(sourceValues.fogDensity, targetValues.fogDensity, progress),
    rainEnabled = useTargetRain and targetValues.rainEnabled or sourceValues.rainEnabled,
    rainAmount = lerp(sourceValues.rainAmount or 0, targetValues.rainAmount or 0, progress),
    precipitationType = useTargetRain and targetValues.precipitationType or sourceValues.precipitationType,
    cloudCover = lerp(sourceValues.cloudCover or 0.3, targetValues.cloudCover or 0.3, progress),
    temperatureC = lerp(sourceValues.temperatureC or 15, targetValues.temperatureC or 15, progress),
    brightness = lerp(sourceValues.brightness or 1, targetValues.brightness or 1, progress),
    roadCondition = useTargetRain and targetValues.roadCondition or sourceValues.roadCondition,
    roadWetRoughness = lerp(sourceValues.roadWetRoughness or 0, targetValues.roadWetRoughness or 0, progress),
    maxWaterRise = lerp(sourceValues.maxWaterRise or 0, targetValues.maxWaterRise or 0, progress),
    waterRiseRate = lerp(sourceValues.waterRiseRate or 0, targetValues.waterRiseRate or 0, progress)
  })

  if progress >= 1 then
    applyWeatherValues(targetValues)
    finishTransition()
  end
end

local function weightedRandomProfile(excludedProfileId, forceStormWeight)
  local config = getLevelConfig()
  local candidates = config.presetOrder or levelOverrides.default.presetOrder
  local totalWeight = 0
  local weighted = {}

  for _, profileId in ipairs(candidates) do
    local profile = weatherProfiles[profileId]
    if profile and profileId ~= excludedProfileId then
      local weight = profile.weight * ((config.profileWeights and config.profileWeights[profileId]) or 1)
      if profileId == "storm" and forceStormWeight then
        weight = weight * forceStormWeight
      end
      if profileId == "storm" or profileId == "hail" or profileId == "supercell" then
        weight = weight * state.stormBiasScale
      end
      if weight > 0 then
        totalWeight = totalWeight + weight
        weighted[#weighted + 1] = {
          id = profileId,
          cumulative = totalWeight
        }
      end
    end
  end

  if #weighted == 0 then
    return excludedProfileId or config.startupProfile or "clear"
  end

  local pick = math.random() * totalWeight
  for _, entry in ipairs(weighted) do
    if pick <= entry.cumulative then
      return entry.id
    end
  end

  return weighted[#weighted].id
end

local function selectScheduledProfile()
  local currentId = state.activeProfileId
  local forceStormWeight = nil

  if currentId == "overcast" or currentId == "drizzle" or currentId == "rain" then
    forceStormWeight = 1.75
  elseif currentId == "storm" then
    forceStormWeight = 0.35
  end

  return weightedRandomProfile(currentId, forceStormWeight)
end

local function applyProfileInstant(profileId, reason)
  local profile = getProfile(profileId)
  if profile.rainEnabled ~= true and profile.precipitationType ~= "snow" then
    M.weatherRuntime.clearRainRoadEffects()
  end
  state.activeProfileId = profileId
  state.currentProfileId = profileId
  state.targetProfileId = nil
  state.transition = nil
  state.timeInProfile = 0
  state.nextChangeIn = getProfileDuration(profileId)
  state.burst = nil
  state.windDirectionTimer = 0
  state.windDirectionStartRadians = state.windDirectionRadians or 0
  state.windDirectionTargetRadians = state.windDirectionRadians or 0
  state.windDirectionTurnElapsed = state.windDirectionTurnDuration or 18
  state.timeSinceBurst = 0
  state.timeSinceLightning = 0
  state.nextBurstCheckIn = getNextBurstInterval(profileId)
  M.weatherRuntime.activateNativeWeather(profileId)
  state.environmentApplyElapsed = state.environmentApplyInterval or 0.10
  applyWeatherValues(buildProfileSnapshot(profileId))
  writeLog("I", string.format("Applied '%s' instantly (%s)", profile.label, reason or "instant"))
end

local function clearActiveWeatherEffects()
  state.transition = nil
  state.burst = nil
  state.lightningFlash = nil
  state.lightningEnvironment = nil
  state.stormAmbienceTimer = 0
  state.severeWindBoost = nil
  state.hailstorm = nil
  state.microburst = nil
  state.hailTimer = 0
  state.microburstTimer = 0
  state.vehicleHazardCooldowns = {}
  state.hailLineOfSightCache = {}
  state.serverStormCell = nil
  state.localStormIntensity = 1
  state.rainfallAccumulation = 0
  state.pendingLightningEvent = nil
  state.pendingSyncedLightning = {}
  state.pendingHailDuration = nil
  state.pendingHailEvent = nil
  state.pendingHailTestDamage = false
  M.weatherRuntime.clearWindDebris()
  clearPlayerPhaseWind()
  clearVehicleTransientEffects()
  state.lightningVehicleHitCounts = {}
  state.worldLightning = nil
  state.worldLightnings = {}
  state.strikeResidue = {}
  for _, entry in ipairs(state.activeImpactEmitters) do
    if entry.obj and type(entry.obj.delete) == "function" then
      pcall(entry.obj.delete, entry.obj)
    end
  end
  state.activeImpactEmitters = {}
  for _, entry in ipairs(state.activeThunderEmitters) do
    if entry.obj and type(entry.obj.delete) == "function" then
      pcall(entry.obj.delete, entry.obj)
    end
  end
  state.activeThunderEmitters = {}
  for _, entry in ipairs(state.activeLightningRibbonMeshes) do
    deleteLightningRibbonMesh(entry.obj)
  end
  state.activeLightningRibbonMeshes = {}
  state.thunderQueue = {}
  state.timeSinceBurst = 0
  state.timeSinceLightning = 0
  state.heavyStormTimer = 0
  clearLightningObjects()
  M.weatherRuntime.clearRainRoadEffects()
  M.weatherRuntime.restoreWaterObjects()
  M.weatherRuntime.restoreForestWind()
  M.weatherRuntime.restoreTemperature()
  M.weatherRuntime.removeDynamicPrecipitation()
end

function M.weatherRuntime.releaseLevelObjectReferences()
  state.dynamicPrecipitation = nil
  state.dynamicPrecipitationCreated = false
  state.dynamicPrecipitationActive = false
  state.appliedPrecipitationAmount = nil
  state.appliedPrecipitationType = nil
  state.appliedPrecipitationEnabled = nil
  state.forestWindEmitter = nil
  state.forestWindEmitterCreated = false
  state.forestWindOriginal = nil
  state.appliedForestWindStrength = nil
  state.appliedForestGustFrequency = nil
  state.waterObjects = {}
  state.waterObjectsInitialized = false
  state.waterOffset = 0
  state.roadMaterialCache = {}
  state.roadWetMaterialQueue = {}
  state.roadWetSavedRoughness = {}
  state.roadWetSavedDiffuse = {}
  state.roadVisualBaselineRoughness = {}
  state.roadVisualBaselineDiffuse = {}
  state.windDebris = {}
  state.activeImpactEmitters = {}
  state.activeThunderEmitters = {}
  state.activeLightningRibbonMeshes = {}
  state.worldLightning = nil
  state.worldLightnings = {}
  state.strikeResidue = {}
  state.thunderQueue = {}
  state.hailstorm = nil
  state.microburst = nil
end

local function activateWeather(reason)
  state.enabled = true
  state.activated = true
  state.saveTimer = 0
  state.heavyStormTimer = 0
  applyProfileInstant(state.activeProfileId or getLevelConfig().startupProfile or "clear", reason or "activated")
  writeLog("I", "Weather system activated")
end

local function deactivateWeather(reason)
  if state.enabled and state.activated and shouldPersistSession() then
    saveSessionState(reason or "deactivate")
  end

  clearActiveWeatherEffects()
  state.enabled = false
  state.activated = false
  if M.weatherRuntime.switchNativeWeather("clear", 0.25) then
    state.nativeWeatherRestoreDelay = 0.4
  elseif supportsNativeEnvironmentState() then
    tryCoreEnvironment("reset_init")
  else
    tryCoreEnvironment("reset")
  end
  writeLog("I", "Weather system deactivated")
end

local function setSystemEnabled(enabled)
  if enabled then
    activateWeather("toggle")
  else
    deactivateWeather("toggle")
  end
end

local function toggleSystem()
  setSystemEnabled(not state.enabled)
end

local function cyclePreset()
  if not state.enabled then
    activateWeather("manual cycle")
    return
  end

  local config = getLevelConfig()
  local order = config.presetOrder or levelOverrides.default.presetOrder
  local currentId = state.currentProfileId or state.activeProfileId
  local currentIndex = 1

  for index, profileId in ipairs(order) do
    if profileId == currentId then
      currentIndex = index
      break
    end
  end

  local nextIndex = (currentIndex % #order) + 1
  startTransition(order[nextIndex], getTransitionDuration(), "manual cycle")
end

local function triggerRandomWeather()
  if not state.enabled then
    activateWeather("manual random")
    return
  end
  startTransition(selectScheduledProfile(), getTransitionDuration(), "manual random")
end

local function triggerStormNow()
  if not state.enabled then
    activateWeather("forced storm")
  end
  startTransition("storm", getTransitionDuration() * 0.75, "forced storm")
end

local function triggerLightningSequence()
  startLightningSequence("manual")
end

local function toggleDynamicMode()
  state.dynamicMode = not state.dynamicMode
  state.timeInProfile = 0
  writeLog("I", "Dynamic weather " .. (state.dynamicMode and "enabled" or "paused"))
end

local function toggleAutoCycle()
  toggleDynamicMode()
end

local function resetToDefault()
  clearActiveWeatherEffects()
  if M.weatherRuntime.switchNativeWeather("clear", 0.25) then
    state.nativeWeatherRestoreDelay = 0.4
  else
    local resetFunction = supportsNativeEnvironmentState() and "reset_init" or "reset"
    local ok, err = tryCoreEnvironment(resetFunction)
    if not ok then
      writeLog("W", "Unable to reset environment: " .. tostring(err))
    end
  end

  toggleRainObjects(false)
  state.transition = nil
  state.targetProfileId = nil
  state.activeProfileId = getLevelConfig().startupProfile or "clear"
  state.currentProfileId = state.activeProfileId
  state.timeInProfile = 0
  state.nextChangeIn = getProfileDuration(state.activeProfileId)
  state.timeSinceBurst = 0
  state.timeSinceLightning = 0
  state.heavyStormTimer = 0
  state.burst = nil
  state.lightningFlash = nil
  state.currentValues = buildProfileSnapshot(state.activeProfileId)

  writeLog("I", "Weather environment reset")
end

local function updateScheduling(dt)
  if state.transition then
    applyTransitionStep(dt)
    return
  end

  -- The BeamMP server advances survival phases for every client. Running the
  -- single-player scheduler as well causes clients to diverge and needlessly
  -- swaps wet/dry ground models, each of which reloads static collision.
  if state.serverBuildId ~= nil then
    return
  end

  if not state.dynamicMode then
    return
  end

  state.timeInProfile = state.timeInProfile + dt
  if state.timeInProfile >= state.nextChangeIn then
    startTransition(selectScheduledProfile(), getTransitionDuration(), "scheduled")
  end
end

local function onUpdate(dtReal, dtSim)
  registerBeamMpHandlers()

  local realDt = tonumber(dtReal) or tonumber(dtSim) or 0
  state.nativeWeatherTransitionRemaining = math.max(0, (state.nativeWeatherTransitionRemaining or 0) - realDt)
  if state.nativeWeatherRestoreDelay then
    state.nativeWeatherRestoreDelay = state.nativeWeatherRestoreDelay - realDt
    if state.nativeWeatherRestoreDelay <= 0 then
      state.nativeWeatherRestoreDelay = nil
      state.nativeWeatherTransitionRemaining = 0
      if supportsNativeEnvironmentState() then
        tryCoreEnvironment("reset_init")
      else
        tryCoreEnvironment("reset")
      end
    end
  end

  if not state.enabled or not state.activated then
    return
  end

  local dt = dtSim or dtReal or 0
  if dt <= 0 then
    return
  end
  state.environmentApplyElapsed = (state.environmentApplyElapsed or 0) + dt

  M.weatherRuntime.updateServerStormCell(dt)
  updateScheduling(dt)
  updateWindDirection(dt)
  updateWindBurst(dt)
  M.weatherRuntime.updateSyncedLightning(dt)
  updateLightning(dt)
  updateLightningSequence(dt)
  updateSevereHazards(dt)
  updateLightningEnvironment(dt)
  updateStormAmbience(dt)
  drawWorldLightning(dt)
  drawStrikeResidue(dt)
  updateImpactEmitters(dt)
  updateThunderEmitters(dt)
  updateLightningRibbonMeshes(dt)
  updateThunderQueue(dt)
  updatePlayerPhaseWind(dt)
  M.weatherRuntime.updateDynamicWater(dt)
  M.weatherRuntime.updateRoadWetness(dt)
  M.weatherRuntime.updateAquaplaning(dt)
  M.weatherRuntime.updateWindDebris(dt)
  updateVehicleLocalWindEffects(dt)
  updateVehicleEmpShutdownEffects(dt)
  updateVehicleElectricalEffects(dt)
  if state.environmentApplyPending then
    applyWeatherValues(state.currentValues)
  end

  if shouldPersistSession() then
    state.saveTimer = state.saveTimer + dt
    if state.saveTimer >= 30 then
      state.saveTimer = 0
      saveSessionState("periodic")
    end
  end
end

function M.weatherRuntime.restoreCurrentValues(savedValues, profileId)
  local fallback = buildProfileSnapshot(profileId)
  if type(savedValues) ~= "table" then
    return fallback
  end
  return {
    tod = tonumber(savedValues.tod) or fallback.tod,
    windSpeed = tonumber(savedValues.windSpeed) or fallback.windSpeed,
    fogDensity = tonumber(savedValues.fogDensity) or fallback.fogDensity,
    rainEnabled = savedValues.rainEnabled == true,
    rainAmount = tonumber(savedValues.rainAmount) or fallback.rainAmount,
    precipitationType = tostring(savedValues.precipitationType or fallback.precipitationType),
    cloudCover = tonumber(savedValues.cloudCover) or fallback.cloudCover,
    temperatureC = tonumber(savedValues.temperatureC) or fallback.temperatureC,
    brightness = tonumber(savedValues.brightness) or fallback.brightness,
    roadCondition = tostring(savedValues.roadCondition or fallback.roadCondition),
    roadWetRoughness = tonumber(savedValues.roadWetRoughness) or fallback.roadWetRoughness,
    maxWaterRise = tonumber(savedValues.maxWaterRise) or fallback.maxWaterRise,
    waterRiseRate = tonumber(savedValues.waterRiseRate) or fallback.waterRiseRate
  }
end

local function applyPersistedData(data)
  state.activeProfileId = weatherProfiles[data.activeProfileId] and data.activeProfileId or state.activeProfileId
  state.currentProfileId = weatherProfiles[data.currentProfileId] and data.currentProfileId or state.activeProfileId
  state.targetProfileId = weatherProfiles[data.targetProfileId] and data.targetProfileId or nil
  state.timeInProfile = tonumber(data.timeInProfile) or 0
  state.nextChangeIn = tonumber(data.nextChangeIn) or getProfileDuration(state.activeProfileId)
  state.transition = type(data.transition) == "table" and data.transition or nil
  state.rainObjectsActive = data.rainObjectsActive == true
  state.lightningEnabled = data.lightningEnabled ~= false
  state.autoLightningEnabled = data.autoLightningEnabled ~= false
  state.autoLightningStrikeCount = math.floor(clamp(tonumber(data.autoLightningStrikeCount) or 2, 1, 8))
  state.autoLightningInterval = clamp(tonumber(data.autoLightningInterval) or 12.0, 1.0, 30.0)
  state.lightningStrikeRadius = clamp(tonumber(data.lightningStrikeRadius) or 50, 1, 500)
  state.lightningVehicleHitChance = clamp(tonumber(data.lightningVehicleHitChance) or 0.05, 0, 1)
  state.lightningPlayerHitChance = clamp(tonumber(data.lightningPlayerHitChance) or 0, 0, 1)
  state.lightningForcePlayerTarget = data.lightningForcePlayerTarget == true
  state.lightningForceVehicleTarget = data.lightningForceVehicleTarget == true
  state.lightningDirectDamageRadius = clamp(tonumber(data.lightningDirectDamageRadius) or 2, 0.1, 100)
  state.lightningSplashDamageRadius = clamp(tonumber(data.lightningSplashDamageRadius) or 4, 0.1, 250)
  state.lightningEmpEffectChance = clamp(tonumber(data.lightningEmpEffectChance) or 0.55, 0, 1)
  state.lightningDestroyChance = clamp(tonumber(data.lightningDestroyChance) or 0.15, 0, 1)
  state.lightningNoEffectChance = clamp(tonumber(data.lightningNoEffectChance) or 0.30, 0, 1)
  state.lightningExplosionsEnabled = data.lightningExplosionsEnabled == true
  state.windBurstsEnabled = data.windBurstsEnabled ~= false
  state.stormBiasScale = clamp(tonumber(data.stormBiasScale) or 1.0, 0.1, 4.0)
  state.transitionScale = clamp(tonumber(data.transitionScale) or 1.0, 0.25, 4.0)
  state.vehicleDamageEnabled = data.vehicleDamageEnabled == true
  state.damageTier = (data.damageTier == "mild" or data.damageTier == "realistic" or data.damageTier == "cinematic") and data.damageTier or "realistic"
  state.destructiveWeatherEnabled = data.destructiveWeatherEnabled ~= false
  state.hailEnabled = data.hailEnabled ~= false
  state.hailDamageChance = clamp(tonumber(data.hailDamageChance) or 0.42, 0, 1)
  state.hailStoneCount = math.floor(clamp(tonumber(data.hailStoneCount) or 18, 1, 1020))
  state.hailRadius = clamp(tonumber(data.hailRadius) or 85, 5, 300)
  state.hailDamageInterval = clamp(tonumber(data.hailDamageInterval) or 2.6, 0.5, 10)
  state.microburstEnabled = data.microburstEnabled ~= false
  state.heavyStormMode = data.heavyStormMode == true
  state.heavyStormInterval = clamp(tonumber(data.heavyStormInterval) or 2.0, 0.5, 30.0)
  state.dynamicMode = data.dynamicMode ~= false
  state.currentValues = M.weatherRuntime.restoreCurrentValues(data.currentValues, state.activeProfileId)
end

local function onExtensionLoaded()
  ensureRandomSeed()
  registerBeamMpHandlers()
  writeLog("I", "Client build " .. M.BUILD_ID)
  loadExternalWeatherConfig()
  state.levelName = getLevelName()
  state.sessionScope = getSessionScope()

  local config = getLevelConfig()
  if state.restoredFromSerialize then
    state.restoredFromSerialize = false
    applyWeatherValues(state.currentValues)
    writeLog("I", string.format("Restored weather state for level '%s' using preset set '%s'", state.levelName, config.label or state.levelName))
    return
  end

  local persisted = loadSessionState()
  local shouldAutoActivate = (state.sessionScope == "career" and state.autoActivateCareer) or (state.sessionScope == "freeroam" and state.autoActivateFreeroam)

  if type(persisted) == "table" then
    applyPersistedData(persisted)
    if shouldAutoActivate and persisted.activated ~= false and persisted.enabled ~= false then
      state.enabled = true
      state.activated = true
      applyWeatherValues(state.currentValues)
      writeLog("I", string.format("Loaded saved %s weather state for '%s'", state.sessionScope, state.levelName))
      return
    end
  end

  local startupProfile = config.startupProfile or "clear"
  local randomStart = weightedRandomProfile(nil, 1.15)
  local initialProfile = state.dynamicMode and randomStart or startupProfile
  state.activeProfileId = initialProfile
  state.currentProfileId = initialProfile
  state.currentValues = buildProfileSnapshot(initialProfile)

  if shouldAutoActivate then
    activateWeather("auto-activate")
    writeLog("I", string.format("Auto-activated for %s on level '%s' using preset set '%s'", state.sessionScope, state.levelName, config.label or state.levelName))
  else
    state.enabled = false
    state.activated = false
    writeLog("I", string.format("Loaded inactive for %s on level '%s'. Bind and use 'Activate Dynamic Weather' to start.", state.sessionScope, state.levelName))
  end
end

local function onSerialize()
  local data = getSerializableState()
  data.restoredFromSerialize = false
  return data
end

local function onDeserialized(data)
  if type(data) ~= "table" then
    return
  end

  state.enabled = data.enabled == true
  state.activated = data.activated == true
  state.dynamicMode = data.dynamicMode ~= false
  state.levelName = data.levelName or getLevelName()
  state.sessionScope = data.sessionScope or getSessionScope()
  state.activeProfileId = weatherProfiles[data.activeProfileId] and data.activeProfileId or "clear"
  state.currentProfileId = weatherProfiles[data.currentProfileId] and data.currentProfileId or state.activeProfileId
  state.targetProfileId = weatherProfiles[data.targetProfileId] and data.targetProfileId or nil
  state.timeInProfile = tonumber(data.timeInProfile) or 0
  state.nextChangeIn = tonumber(data.nextChangeIn) or getProfileDuration(state.activeProfileId)
  state.transition = type(data.transition) == "table" and data.transition or nil
  state.rainObjectsActive = data.rainObjectsActive == true
  state.lightningEnabled = data.lightningEnabled ~= false
  state.autoLightningEnabled = data.autoLightningEnabled ~= false
  state.autoLightningStrikeCount = math.floor(clamp(tonumber(data.autoLightningStrikeCount) or 2, 1, 8))
  state.autoLightningInterval = clamp(tonumber(data.autoLightningInterval) or 12.0, 1.0, 30.0)
  state.lightningStrikeRadius = clamp(tonumber(data.lightningStrikeRadius) or 50, 1, 500)
  state.lightningVehicleHitChance = clamp(tonumber(data.lightningVehicleHitChance) or 0.05, 0, 1)
  state.lightningPlayerHitChance = clamp(tonumber(data.lightningPlayerHitChance) or 0, 0, 1)
  state.lightningForcePlayerTarget = data.lightningForcePlayerTarget == true
  state.lightningForceVehicleTarget = data.lightningForceVehicleTarget == true
  state.lightningDirectDamageRadius = clamp(tonumber(data.lightningDirectDamageRadius) or 2, 0.1, 100)
  state.lightningSplashDamageRadius = clamp(tonumber(data.lightningSplashDamageRadius) or 4, 0.1, 250)
  state.lightningEmpEffectChance = clamp(tonumber(data.lightningEmpEffectChance) or 0.55, 0, 1)
  state.lightningDestroyChance = clamp(tonumber(data.lightningDestroyChance) or 0.15, 0, 1)
  state.lightningNoEffectChance = clamp(tonumber(data.lightningNoEffectChance) or 0.30, 0, 1)
  state.lightningExplosionsEnabled = data.lightningExplosionsEnabled == true
  state.windBurstsEnabled = data.windBurstsEnabled ~= false
  state.stormBiasScale = clamp(tonumber(data.stormBiasScale) or 1.0, 0.1, 4.0)
  state.transitionScale = clamp(tonumber(data.transitionScale) or 1.0, 0.25, 4.0)
  state.vehicleDamageEnabled = data.vehicleDamageEnabled == true
  state.damageTier = (data.damageTier == "mild" or data.damageTier == "realistic" or data.damageTier == "cinematic") and data.damageTier or "realistic"
  state.destructiveWeatherEnabled = data.destructiveWeatherEnabled ~= false
  state.hailEnabled = data.hailEnabled ~= false
  state.hailDamageChance = clamp(tonumber(data.hailDamageChance) or 0.42, 0, 1)
  state.hailStoneCount = math.floor(clamp(tonumber(data.hailStoneCount) or 18, 1, 1020))
  state.hailRadius = clamp(tonumber(data.hailRadius) or 85, 5, 300)
  state.hailDamageInterval = clamp(tonumber(data.hailDamageInterval) or 2.6, 0.5, 10)
  state.microburstEnabled = data.microburstEnabled ~= false
  state.heavyStormMode = data.heavyStormMode == true
  state.heavyStormInterval = clamp(tonumber(data.heavyStormInterval) or 2.0, 0.5, 30.0)
  state.restoredFromSerialize = true

  state.currentValues = M.weatherRuntime.restoreCurrentValues(data.currentValues, state.activeProfileId)
end

local function onExtensionUnloaded()
  if state.enabled and state.activated and shouldPersistSession() then
    saveSessionState("unload")
  end
  clearActiveWeatherEffects()
  clearLightningObjects()
  M.weatherRuntime.releaseLevelObjectReferences()
  if supportsNativeEnvironmentState() then
    tryCoreEnvironment("reset_init")
  else
    tryCoreEnvironment("reset")
  end
end

function M.weatherRuntime.onClientEndMission()
  if state.enabled and state.activated and shouldPersistSession() then
    saveSessionState("level unload")
  end

  -- Scene objects are destroyed during level teardown, but GE extensions can
  -- continue updating on the main menu. Never retain their userdata there.
  state.enabled = false
  state.activated = false
  state.transition = nil
  state.burst = nil
  state.lightningFlash = nil
  M.weatherRuntime.releaseLevelObjectReferences()
end

local function getUiState()
  return {
    activated = state.activated,
    enabled = state.enabled,
    dynamicMode = state.dynamicMode,
    levelName = state.levelName,
    sessionScope = state.sessionScope,
    activeProfileId = state.activeProfileId,
    activeProfileLabel = getProfile(state.activeProfileId).label,
    targetProfileId = state.targetProfileId,
    currentWindSpeed = state.currentValues.windSpeed,
    currentFogDensity = state.currentValues.fogDensity,
    rainEnabled = state.currentValues.rainEnabled,
    roadWetness = state.roadWetness,
    stormBiasScale = state.stormBiasScale,
    transitionScale = state.transitionScale,
    vehicleDamageEnabled = state.vehicleDamageEnabled,
    damageTier = state.damageTier,
    destructiveWeatherEnabled = state.destructiveWeatherEnabled,
    hailEnabled = state.hailEnabled,
    hailDamageChance = state.hailDamageChance,
    hailStoneCount = state.hailStoneCount,
    hailRadius = state.hailRadius,
    hailDamageInterval = state.hailDamageInterval,
    microburstEnabled = state.microburstEnabled,
    hailActive = state.hailstorm ~= nil,
    microburstActive = state.microburst ~= nil,
    heavyStormMode = state.heavyStormMode,
    heavyStormInterval = state.heavyStormInterval,
    serverAutoLightning = state.serverAutoLightning,
    lightningEnabled = state.lightningEnabled,
    autoLightningEnabled = state.autoLightningEnabled,
    autoLightningStrikeCount = state.autoLightningStrikeCount,
    autoLightningInterval = state.autoLightningInterval,
    lightningStrikeRadius = state.lightningStrikeRadius,
    lightningVehicleHitChance = state.lightningVehicleHitChance,
    lightningPlayerHitChance = state.lightningPlayerHitChance,
    lightningForcePlayerTarget = state.lightningForcePlayerTarget,
    lightningForceVehicleTarget = state.lightningForceVehicleTarget,
    lightningDirectDamageRadius = state.lightningDirectDamageRadius,
    lightningSplashDamageRadius = state.lightningSplashDamageRadius,
    lightningEmpEffectChance = state.lightningEmpEffectChance,
    lightningDestroyChance = state.lightningDestroyChance,
    lightningNoEffectChance = state.lightningNoEffectChance,
    lightningExplosionsEnabled = state.lightningExplosionsEnabled,
    windBurstsEnabled = state.windBurstsEnabled,
    lightningVisualNonce = state.lightningVisualNonce,
    lightningVisualStrength = state.lightningVisualStrength,
    persistCareer = state.persistCareer,
    persistFreeroam = state.persistFreeroam,
    autoActivateCareer = state.autoActivateCareer,
    autoActivateFreeroam = state.autoActivateFreeroam,
    timeToNextChange = math.max(0, state.nextChangeIn - state.timeInProfile),
    inTransition = state.transition ~= nil,
    burstActive = state.burst ~= nil,
    lightningSequenceActive = state.lightningFlash ~= nil
  }
end

local function setUiSettings(settings)
  if type(settings) ~= "table" then
    return
  end

  if settings.dynamicMode ~= nil then
    state.dynamicMode = settings.dynamicMode == true
  end
  if settings.lightningEnabled ~= nil then
    state.lightningEnabled = settings.lightningEnabled == true
  end
  if settings.autoLightningEnabled ~= nil then
    state.autoLightningEnabled = settings.autoLightningEnabled == true
    state.timeSinceLightning = 0
  end
  if settings.serverAutoLightning ~= nil then
    local serverOwnsLightning = settings.serverAutoLightning == true
    if serverOwnsLightning and not state.serverAutoLightning then
      state.lightningFlash = nil
      state.heavyStormTimer = 0
      state.timeSinceLightning = 0
    end
    state.serverAutoLightning = serverOwnsLightning
  end
  if settings.autoLightningStrikeCount ~= nil then
    state.autoLightningStrikeCount = math.floor(clamp(tonumber(settings.autoLightningStrikeCount) or state.autoLightningStrikeCount, 1, 8))
  end
  if settings.autoLightningInterval ~= nil then
    state.autoLightningInterval = clamp(tonumber(settings.autoLightningInterval) or state.autoLightningInterval, 1.0, 30.0)
    state.timeSinceLightning = 0
  end
  if settings.lightningStrikeRadius ~= nil then
    state.lightningStrikeRadius = clamp(tonumber(settings.lightningStrikeRadius) or state.lightningStrikeRadius, 1, 500)
  end
  if settings.lightningVehicleHitChance ~= nil then
    state.lightningVehicleHitChance = clamp(tonumber(settings.lightningVehicleHitChance) or state.lightningVehicleHitChance, 0, 1)
  end
  if settings.lightningPlayerHitChance ~= nil then
    state.lightningPlayerHitChance = clamp(tonumber(settings.lightningPlayerHitChance) or state.lightningPlayerHitChance, 0, 1)
  end
  if settings.lightningForcePlayerTarget ~= nil then
    state.lightningForcePlayerTarget = settings.lightningForcePlayerTarget == true
  end
  if settings.lightningForceVehicleTarget ~= nil then
    state.lightningForceVehicleTarget = settings.lightningForceVehicleTarget == true
  end
  if settings.lightningDirectDamageRadius ~= nil then
    state.lightningDirectDamageRadius = clamp(tonumber(settings.lightningDirectDamageRadius) or state.lightningDirectDamageRadius, 0.1, 100)
  end
  if settings.lightningSplashDamageRadius ~= nil then
    state.lightningSplashDamageRadius = clamp(tonumber(settings.lightningSplashDamageRadius) or state.lightningSplashDamageRadius, 0.1, 250)
  end
  if settings.lightningEmpEffectChance ~= nil then
    state.lightningEmpEffectChance = clamp(tonumber(settings.lightningEmpEffectChance) or state.lightningEmpEffectChance, 0, 1)
  end
  if settings.lightningDestroyChance ~= nil then
    state.lightningDestroyChance = clamp(tonumber(settings.lightningDestroyChance) or state.lightningDestroyChance, 0, 1)
  end
  if settings.lightningNoEffectChance ~= nil then
    state.lightningNoEffectChance = clamp(tonumber(settings.lightningNoEffectChance) or state.lightningNoEffectChance, 0, 1)
  end
  if settings.lightningExplosionsEnabled ~= nil then
    state.lightningExplosionsEnabled = settings.lightningExplosionsEnabled == true
  end
  if settings.lightningAftermathEnabled ~= nil then
    state.lightningAftermathEnabled = settings.lightningAftermathEnabled == true
  end
  if settings.lightningTyreDamageChance ~= nil then
    state.lightningTyreDamageChance = clamp(tonumber(settings.lightningTyreDamageChance) or state.lightningTyreDamageChance, 0, 1)
  end
  if settings.lightningFireChance ~= nil then
    state.lightningFireChance = clamp(tonumber(settings.lightningFireChance) or state.lightningFireChance, 0, 1)
  end
  if settings.lightningIgnoreShelter ~= nil then
    state.lightningIgnoreShelter = settings.lightningIgnoreShelter == true
  end
  if settings.windBurstsEnabled ~= nil then
    state.windBurstsEnabled = settings.windBurstsEnabled == true
    if not state.windBurstsEnabled then
      state.burst = nil
      state.timeSinceBurst = 0
    end
  end
  local weatherWindSpeed = settings.weatherWindSpeed or settings.windSpeed
  if weatherWindSpeed ~= nil then
    state.currentValues.windSpeed = math.max(0, tonumber(weatherWindSpeed) or state.currentValues.windSpeed or 0)
    applyWeatherValues(state.currentValues)
  end
  if settings.persistCareer ~= nil then
    state.persistCareer = settings.persistCareer == true
  end
  if settings.persistFreeroam ~= nil then
    state.persistFreeroam = settings.persistFreeroam == true
  end
  if settings.autoActivateCareer ~= nil then
    state.autoActivateCareer = settings.autoActivateCareer == true
  end
  if settings.autoActivateFreeroam ~= nil then
    state.autoActivateFreeroam = settings.autoActivateFreeroam == true
  end
  if settings.stormBiasScale ~= nil then
    state.stormBiasScale = clamp(tonumber(settings.stormBiasScale) or state.stormBiasScale, 0.1, 4.0)
  end
  if settings.transitionScale ~= nil then
    state.transitionScale = clamp(tonumber(settings.transitionScale) or state.transitionScale, 0.25, 4.0)
  end
  if settings.vehicleDamageEnabled ~= nil then
    state.vehicleDamageEnabled = settings.vehicleDamageEnabled == true
  end
  if settings.damageTier == "mild" or settings.damageTier == "realistic" or settings.damageTier == "cinematic" then
    state.damageTier = settings.damageTier
  end
  if settings.destructiveWeatherEnabled ~= nil then
    state.destructiveWeatherEnabled = settings.destructiveWeatherEnabled == true
  end
  if settings.hailEnabled ~= nil then
    state.hailEnabled = settings.hailEnabled == true
  end
  if settings.hailDamageChance ~= nil then
    state.hailDamageChance = clamp(tonumber(settings.hailDamageChance) or state.hailDamageChance, 0, 1)
  end
  if settings.hailStoneCount ~= nil then
    state.hailStoneCount = math.floor(clamp(tonumber(settings.hailStoneCount) or state.hailStoneCount, 1, 1020))
  end
  if settings.hailRadius ~= nil then
    state.hailRadius = clamp(tonumber(settings.hailRadius) or state.hailRadius, 5, 300)
  end
  if settings.hailDamageInterval ~= nil then
    state.hailDamageInterval = clamp(tonumber(settings.hailDamageInterval) or state.hailDamageInterval, 0.5, 10)
  end
  if settings.hailProgressionEnabled ~= nil then
    state.hailProgressionEnabled = settings.hailProgressionEnabled == true
  end
  if settings.hailDuration ~= nil then
    state.pendingHailDuration = clamp(tonumber(settings.hailDuration) or 45, 5, 180)
  end
  if settings.hailTestDamage ~= nil then state.pendingHailTestDamage = settings.hailTestDamage == true end
  if settings.shelterDetectionEnabled ~= nil then state.shelterDetectionEnabled = settings.shelterDetectionEnabled == true end
  if settings.localizedFloodingEnabled ~= nil then state.localizedFloodingEnabled = settings.localizedFloodingEnabled == true end
  if settings.aquaplaningEnabled ~= nil then state.aquaplaningEnabled = settings.aquaplaningEnabled == true end
  if settings.windDebrisEnabled ~= nil then state.windDebrisEnabled = settings.windDebrisEnabled == true end
  if settings.microburstEnabled ~= nil then
    state.microburstEnabled = settings.microburstEnabled == true
  end
  if settings.heavyStormMode ~= nil then
    state.heavyStormMode = settings.heavyStormMode == true
    state.heavyStormTimer = 0
  end
  if settings.heavyStormInterval ~= nil then
    state.heavyStormInterval = clamp(tonumber(settings.heavyStormInterval) or state.heavyStormInterval, 0.5, 30.0)
  end

end

local function parseBeamMpCommandPayload(payload)
  if type(payload) == "table" then
    local settings = {}
    for key, value in pairs(payload) do
      settings[key] = value
    end
    local command = tostring(settings.command or settings.action or ""):lower()
    settings.command = nil
    settings.action = nil
    return command, settings
  end

  local command = tostring(payload or ""):lower()
  local settings = {}

  for part in tostring(payload or ""):gmatch("[^;]+") do
    local key, value = part:match("^%s*([%w_]+)%s*=%s*([%w_%-%.]+)%s*$")
    if key and value then
      local normalizedValue = value:lower()
      if normalizedValue == "true" then
        settings[key] = true
      elseif normalizedValue == "false" then
        settings[key] = false
      else
        settings[key] = tonumber(value) or value
      end
    end
  end

  local firstPart = tostring(payload or ""):match("^%s*([^;]+)")
  if firstPart then
    command = firstPart:match("^%s*([%w_%-]+)") or command
    command = command:lower()
  end

  return command, settings
end

function M.weatherRuntime.acceptServerEvent(eventId)
  if eventId == nil or tostring(eventId) == "" then return true end
  local key = tostring(eventId)
  local now = os.clock()
  local expiresAt = state.processedServerEvents[key]
  if expiresAt and expiresAt > now then return false end
  state.processedServerEvents[key] = now + 300
  for id, expiry in pairs(state.processedServerEvents) do
    if expiry <= now then state.processedServerEvents[id] = nil end
  end
  return true
end

function M.weatherRuntime.applyStormCellEvent(settings)
  if settings.cellActive ~= true then
    state.serverStormCell = nil
    state.localStormIntensity = 1
    return
  end
  local x, y, z = tonumber(settings.cellX), tonumber(settings.cellY), tonumber(settings.cellZ)
  if not x or not y or not z then return end
  state.serverStormCell = {
    id = settings.eventId,
    x = x,
    y = y,
    z = z,
    vx = tonumber(settings.cellVx) or 0,
    vy = tonumber(settings.cellVy) or 0,
    radius = math.max(1, tonumber(settings.cellRadius) or 460),
    edgeFade = math.max(1, tonumber(settings.cellEdgeFade) or 180),
    intensity = clamp(tonumber(settings.cellIntensity) or 1, 0, 2),
    receivedAt = os.clock()
  }
end

local function handleBeamMpWeatherCommand(payload)
  local command, settings = parseBeamMpCommandPayload(payload)

  if settings.ashWeatherServerBuild and settings.ashWeatherServerBuild ~= state.serverBuildId then
    state.serverBuildId = tostring(settings.ashWeatherServerBuild)
    writeLog("I", "Server build " .. state.serverBuildId .. "; client build " .. M.BUILD_ID)
  end

  if command ~= "settings" and next(settings) ~= nil then
    setUiSettings(settings)
  end

  local transientEvent = command == "lightning" or command == "strike" or command == "barrage" or command == "lightningsequence" or command == "hail" or command == "hailburst" or command == "windburst" or command == "test_emp" or command == "reset_damage"
  if transientEvent and not M.weatherRuntime.acceptServerEvent(settings.eventId) then
    writeLog("I", "Ignored duplicate server weather event " .. tostring(settings.eventId))
    return
  end

  if command == "stormcell" then
    M.weatherRuntime.applyStormCellEvent(settings)
  elseif command == "activate" or command == "start" then
    activateWeather("beammp")
    notifyClient("Weather activated")
  elseif command == "ping" then
    writeLog("I", "BeamMP ping received")
    notifyClient("BeamMP weather bridge active")
  elseif command == "deactivate" or command == "stop" then
    deactivateWeather("beammp")
    notifyClient("Weather stopped")
  elseif command == "random" then
    triggerRandomWeather()
    notifyClient("Random weather transition")
  elseif command == "clear" then
    if not state.enabled then
      state.activeProfileId = "clear"
      state.currentProfileId = "clear"
      activateWeather("beammp clear")
    else
      applyProfileInstant("clear", "beammp clear")
    end
    notifyClient("Clear weather forced")
  elseif command == "overcast" or command == "drizzle" or command == "rain" or command == "snow" then
    if not state.enabled then
      activateWeather("beammp " .. command)
    end
    startTransition(command, math.max(1.0, getTransitionDuration() * 0.55), "beammp " .. command)
    notifyClient(getProfile(command).label .. " forced")
  elseif command == "storm" then
    triggerStormNow()
    notifyClient("Storm forced")
  elseif command == "thunderstorm" then
    if not state.enabled then
      activateWeather("beammp thunderstorm")
    end
    startTransition("storm", math.max(1.0, getTransitionDuration() * 0.55), "beammp thunderstorm")
    notifyClient("Thunderstorm forced")
  elseif command == "supercell" or command == "heavy_storm" or command == "heavystorm" then
    if not state.enabled then
      activateWeather("beammp supercell")
    end
    startTransition("supercell", math.max(1.0, getTransitionDuration() * 0.55), "beammp supercell")
    notifyClient("Severe supercell forced")
  elseif command == "hail" then
    if not state.enabled then
      activateWeather("beammp hail")
    end
    state.pendingHailEvent = settings
    if settings.eventId ~= nil then state.hailstorm = nil end
    startTransition("hail", math.max(1.0, getTransitionDuration() * 0.55), "beammp hail")
    startHailstorm("beammp")
    notifyClient("Hail core forced")
  elseif command == "hailburst" then
    if not state.enabled then
      activateWeather("beammp hail burst")
    end
    state.pendingHailEvent = settings
    if settings.eventId ~= nil then state.hailstorm = nil end
    startHailstorm("beammp periodic burst")
  elseif command == "microburst" then
    if not state.enabled then
      activateWeather("beammp microburst")
    end
    startMicroburst("beammp")
    notifyClient("Microburst forced")
  elseif command == "lightning" or command == "strike" then
    local currentTime = getTimeOfDayState().time
    if not state.enabled then
      activateWeather("beammp lightning")
    end
    M.weatherRuntime.preserveTimeOfDay(currentTime)
    local strikeCount = math.floor(clamp(tonumber(settings.lightningStrikeCount) or tonumber(settings.autoLightningStrikeCount) or 1, 1, 20))
    local syncSeed = tonumber(settings.lightningSyncSeed)
    local authoritativeStrike = tonumber(settings.strikeX) and tonumber(settings.strikeY) and tonumber(settings.strikeZ)
    local synchronizedStrike = authoritativeStrike or (settings.eventId ~= nil and settings.lightningSyncDelay ~= nil)
    if synchronizedStrike then
      M.weatherRuntime.queueSyncedLightning(settings)
    elseif strikeCount > 1 then
      state.pendingLightningEvent = settings
      startLightningSequence("beammp", strikeCount, syncSeed)
    else
      state.pendingLightningEvent = settings
      triggerLightning("beammp", syncSeed)
    end
    notifyClient("Lightning strike forced")
  elseif command == "barrage" or command == "lightningsequence" then
    local currentTime = getTimeOfDayState().time
    if not state.enabled then
      activateWeather("beammp barrage")
    end
    M.weatherRuntime.preserveTimeOfDay(currentTime)
    startLightningSequence("beammp barrage", math.floor(clamp(tonumber(settings.lightningStrikeCount) or state.autoLightningStrikeCount or 3, 1, 20)), tonumber(settings.lightningSyncSeed))
    notifyClient("Lightning barrage forced")
  elseif command == "windburst" then
    local burstMultiplier = clamp(tonumber(settings.burstMultiplier) or 2, 1, 6)
    local cellX, cellY = tonumber(settings.cellX), tonumber(settings.cellY)
    if cellX and cellY then
      local position = getPlayerPosition()
      local dx, dy = position.x - cellX, position.y - cellY
      local distance = math.sqrt(dx * dx + dy * dy)
      local radius = math.max(1, tonumber(settings.cellRadius) or 460)
      local exposure = clamp(1 - distance / radius, 0, 1)
      burstMultiplier = 1 + (burstMultiplier - 1) * exposure
    end
    state.burst = {
      active = true,
      elapsed = 0,
      duration = clamp(tonumber(settings.burstDuration) or 4, 0.5, 20),
      multiplier = burstMultiplier,
      authoritative = true,
      eventId = settings.eventId,
      eventSeed = settings.eventSeed,
      center = cellX and cellY and vec3(cellX, cellY, tonumber(settings.cellZ) or 0) or nil
    }
    applyWeatherValues(state.currentValues)
  elseif command == "test_emp" then
    M.weatherRuntime.testEmpTier(math.floor(clamp(tonumber(settings.empTier) or 1, 1, 3)))
  elseif command == "reset_damage" then
    M.weatherRuntime.resetPlayerWeatherDamage()
  elseif command == "cycle" then
    cyclePreset()
  elseif command == "reset" then
    resetToDefault()
  elseif command == "dynamic_on" then
    state.dynamicMode = true
  elseif command == "dynamic_off" then
    state.dynamicMode = false
  elseif command == "destructive_on" then
    state.destructiveWeatherEnabled = true
  elseif command == "destructive_off" then
    state.destructiveWeatherEnabled = false
  elseif command == "settings" then
    setUiSettings(settings)
  else
    writeLog("W", "Ignored unknown BeamMP weather command: " .. tostring(payload))
    if type(TriggerServerEvent) == "function" then
      TriggerServerEvent("AshSurvivalClientReady", "unknown:" .. tostring(payload))
    end
    return
  end

  if command ~= "stormcell" and type(TriggerServerEvent) == "function" then
    TriggerServerEvent(
      "AshSurvivalClientReady",
      string.format(
        "ack:%s profile=%s rain=%s enabled=%s",
        command,
        tostring(getCurrentBaseProfileId()),
        tostring(state.currentValues and state.currentValues.rainEnabled),
        tostring(state.enabled)
      )
    )
  end
  if command ~= "stormcell" then
    writeLog("I", "Handled BeamMP weather command: " .. command)
  end
end

local function onBeamMPMessage(eventName, payload)
  if eventName ~= nil and tostring(eventName) ~= "ash_survival" and payload == nil then
    return handleBeamMpWeatherCommand(eventName)
  end
  return handleBeamMpWeatherCommand(payload or eventName)
end

registerBeamMpHandlers = function()
  if beamMpHandlersRegistered then
    return
  end

  if type(AddEventHandler) ~= "function" then
    return
  end

  AddEventHandler("AshSurvivalWeatherCommand", handleBeamMpWeatherCommand)
  beamMpHandlersRegistered = true
  if type(TriggerServerEvent) == "function" then
    TriggerServerEvent("AshSurvivalClientReady", "ready")
  end
  writeLog("I", "Registered BeamMP weather command handler")
end

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onClientEndMission = M.weatherRuntime.onClientEndMission
M.onUpdate = onUpdate
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.state = state

M.activateWeather = activateWeather
M.deactivateWeather = deactivateWeather
M.applyProfileInstant = applyProfileInstant
M.cyclePreset = cyclePreset
M.triggerRandomWeather = triggerRandomWeather
M.triggerStormNow = triggerStormNow
M.triggerLightning = triggerLightning
M.triggerLightningSequence = triggerLightningSequence
M.toggleSystem = toggleSystem
M.toggleDynamicMode = toggleDynamicMode
M.toggleAutoCycle = toggleAutoCycle
M.resetToDefault = resetToDefault
M.getUiState = getUiState
M.setUiSettings = setUiSettings
M.handleBeamMpWeatherCommand = handleBeamMpWeatherCommand
M.onBeamMPMessage = onBeamMPMessage

registerBeamMpHandlers()

return M
