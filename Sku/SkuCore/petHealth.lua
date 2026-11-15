---------------------------------------------------------------------------------------------------------------------------------------
-- Pet health by key (SKU_KEY_PETHEALTH, no default key, set in the key menu; dispatched in SkuZOptions/Core.lua like
-- SKU_KEY_TARGETHEALTH, so it also works in combat). Spoken as "Pet <percent>", rounded up like Blizzard's combat audio
-- alerts (CombatAudioAlertManagerMixin:GetUnitHealthPercent: math.ceil): a living pet is never "0".
-- On WoW Forever the pet's health is a secret value: Sku cannot read, compare or calculate with it, only hand it to the
-- speech output (SkuVoice:SpeakSecretText). The rounding then comes from a curve, the only arithmetic allowed on a secret.
---------------------------------------------------------------------------------------------------------------------------------------
local L = Sku.L

-- [0, 1] -> [0.999, 100.999]; "%d" cuts the fraction, so this is math.ceil of the percentage (a dead pet stays 0, 0.4 % becomes 1).
local tCeilTo100

function SkuCore:SpeakPetHealth()
	if not UnitExists("pet") then
		SkuOptions.Voice:OutputStringBTtts(L["No pet"], true, true, 0.2)
		return
	end
	local tMax = UnitHealthMax("pet")
	local tHealth = UnitHealth("pet")
	-- Either value can be secret on its own: the max can be readable while the current health is not.
	if Sku.IsSecret(tMax) or Sku.IsSecret(tHealth) then
		if not tCeilTo100 then
			tCeilTo100 = C_CurveUtil.CreateCurve()
			tCeilTo100:SetType(Enum.LuaCurveType.Linear)
			tCeilTo100:AddPoint(0.0, 0.999)
			tCeilTo100:AddPoint(1.0, 100.999)
		end
		SkuOptions.Voice:SpeakSecretText(L["Pet %d"], UnitHealthPercent("pet", true, tCeilTo100))
		return
	end
	local tPercent = tMax > 0 and math.ceil(tHealth / tMax * 100) or 0
	SkuOptions.Voice:OutputStringBTtts(string.format(L["Pet %d"], tPercent), true, true, 0.2)
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Automatic announcement in combat (WoW Forever only, setting petHealthAuto, default on): while the player is in combat and has a
-- living pet, the pet's health is spoken every PET_HEALTH_AUTO_INTERVAL seconds, the first time a few seconds after the fight
-- starts. The value is secret, so it cannot be compared against a threshold ("only below 50 %"); a fixed interval is the only
-- thing that can be decided without reading it. The key (SKU_KEY_PETHEALTH) works as before, whatever this setting says.
---------------------------------------------------------------------------------------------------------------------------------------
local PET_HEALTH_AUTO_INTERVAL = 10   -- default; the player can choose one of PET_HEALTH_INTERVALS (setting petHealthInterval)
local PET_HEALTH_AUTO_FIRST = 4
local PET_HEALTH_INTERVALS = {5, 10, 15, 20}

local function tPetHealthInterval()
	if not (SkuSettings and SkuSettings.Get) then return PET_HEALTH_AUTO_INTERVAL end
	local tOk, tVal = pcall(SkuSettings.Get, SkuSettings, "SkuCore", "petHealthInterval")
	if not tOk or type(tVal) ~= "number" then return PET_HEALTH_AUTO_INTERVAL end
	for _, v in ipairs(PET_HEALTH_INTERVALS) do
		if v == tVal then return tVal end
	end
	return PET_HEALTH_AUTO_INTERVAL
end

local function tPetHealthAutoEnabled()
	if not Sku.isForever then return false end
	if not (SkuSettings and SkuSettings.Get) then return true end
	local tOk, tVal = pcall(SkuSettings.Get, SkuSettings, "SkuCore", "petHealthAuto")
	if not tOk then return true end
	return tVal ~= false
end

local tPetHealthTicker
local tPetHealthFirst

local function tPetHealthAutoStop()
	if tPetHealthTicker then tPetHealthTicker:Cancel() tPetHealthTicker = nil end
	if tPetHealthFirst then tPetHealthFirst:Cancel() tPetHealthFirst = nil end
end

local function tPetHealthAutoTick()
	if not UnitAffectingCombat("player") then
		tPetHealthAutoStop()
		return
	end
	if not UnitExists("pet") then return end
	local tDead = UnitIsDead("pet")
	if not Sku.IsSecret(tDead) and tDead then return end
	if tPetHealthAutoEnabled() then
		SkuCore:SpeakPetHealth()
	end
end

local tPetHealthAutoFrame = CreateFrame("Frame")
tPetHealthAutoFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
tPetHealthAutoFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
tPetHealthAutoFrame:SetScript("OnEvent", function(self, aEvent)
	tPetHealthAutoStop()
	if aEvent == "PLAYER_REGEN_DISABLED" and tPetHealthAutoEnabled() then
		tPetHealthFirst = C_Timer.NewTimer(PET_HEALTH_AUTO_FIRST, function()
			tPetHealthFirst = nil
			tPetHealthAutoTick()
			if UnitAffectingCombat("player") then
				tPetHealthTicker = C_Timer.NewTicker(tPetHealthInterval(), tPetHealthAutoTick)
			end
		end)
	end
end)

-- Einstellungen -> Allgemein: "Pet-Gesundheit im Kampf automatisch ansagen" (only offered on Forever).
function SkuCore.PetHealthAutoMenuBuilder(aParentEntry)
	if not Sku.isForever then return end
	local tNewMenuEntry = SkuOptions:InjectMenuItems(aParentEntry, {
		Sku.deEn("Pet-Gesundheit im Kampf automatisch ansagen",
			"Announce pet health automatically in combat",
			"Annoncer automatiquement la santé du familier en combat"),
	}, SkuGenericMenuItem)
	tNewMenuEntry.sorting = true
	tNewMenuEntry.GetCurrentValue = function(self, aValue, aName)
		if tPetHealthAutoEnabled() == true then
			return L["Yes"]
		else
			return L["No"]
		end
	end
	tNewMenuEntry.OnAction = function(self, aValue, aName)
		if aName == L["No"] then
			SkuSettings:Set("SkuCore", "petHealthAuto", false)
		elseif aName == L["Yes"] then
			SkuSettings:Set("SkuCore", "petHealthAuto", true)
		end
	end
	SkuOptions:MakeInPlaceToggle(tNewMenuEntry, L["No"], L["Yes"])

	-- Interval between the announcements (5, 10, 15 or 20 seconds). Takes effect with the next fight.
	local function tLabel(aSeconds)
		return aSeconds..Sku.deEn(" Sekunden", " seconds", " secondes")
	end
	local tIntervalEntry = SkuOptions:InjectMenuItems(aParentEntry, {
		Sku.deEn("Pet-Gesundheit im Kampf: Abstand der Ansagen",
			"Pet health in combat: time between announcements",
			"Santé du familier en combat : intervalle entre les annonces"),
	}, SkuGenericMenuItem)
	tIntervalEntry.sorting = true
	tIntervalEntry.isSelect = true
	tIntervalEntry.dynamic = true
	tIntervalEntry.GetCurrentValue = function(self, aValue, aName)
		return tLabel(tPetHealthInterval())
	end
	tIntervalEntry.OnAction = function(self, aValue, aName)
		local tSeconds = tonumber(string.match(tostring(aName or ""), "%d+"))
		for _, v in ipairs(PET_HEALTH_INTERVALS) do
			if v == tSeconds then
				SkuSettings:Set("SkuCore", "petHealthInterval", v)
				return
			end
		end
	end
	tIntervalEntry.BuildChildren = function(self)
		for _, v in ipairs(PET_HEALTH_INTERVALS) do
			SkuOptions:InjectMenuItems(self, {tLabel(v)}, SkuGenericMenuItem)
		end
	end
end
