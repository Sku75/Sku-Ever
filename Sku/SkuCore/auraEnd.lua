---------------------------------------------------------------------------------------------------------------------------------------
-- Announcement when a tracked aura is gone (a DoT on the target, a buff on the player), on WoW Forever.
-- In combat the aura APIs are closed to addons, but Blizzard's cooldown manager (Blizzard_CooldownViewer) shows the
-- player's Tracked Buffs / Tracked Bars and leaves plain facts on its item frames: whether the aura is up (IsActive),
-- on which unit (auraDataUnit) and its spell ids. This module only reads those facts, never an aura value. What the
-- player puts into the cooldown manager's Tracked Buffs / Tracked Bars is what gets announced.
-- Idea and the frame facts: WowVision (retail/monitors/CdmAuraMonitor.lua), used with the author's permission.
---------------------------------------------------------------------------------------------------------------------------------------
if not Sku.isForever then return end

local L = Sku.L

local AuraEnd = SkuCore:NewModule("AuraEnd")
SkuCore.AuraEnd = AuraEnd

SkuCore:RegisterToggleableModule("AuraEnd", function()
	return Sku.deEn("Aura-Ende-Ansage", "Aura end announcement", "Annonce de fin d'aura")
end)

local VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
local TICK_SECONDS = 0.5
-- The viewers force their items inactive for a moment after a target change; the ticks right after are not judged.
local QUIET_TICKS = 3

-- Per item frame: what it showed at the last tick. Weak keys: the viewers pool their frames.
local gState = setmetatable({}, { __mode = "k" })
local gQuietTicks = 0
local gTicker = nil
local gEventFrame = nil
local gCommandRegistered = false

local function tPlain(aValue)
	return aValue ~= nil and not Sku.IsSecret(aValue)
end

local function tSpellName(aId)
	if tPlain(aId) and aId ~= 0 and C_Spell and C_Spell.GetSpellName then
		return C_Spell.GetSpellName(aId)
	end
	return nil
end

-- the cooldown info of an item frame (a table of ids; single ids can be secret while the aura is up)
local function tInfo(aFrame)
	if not aFrame.GetCooldownInfo then return nil end
	local tInfo = aFrame:GetCooldownInfo()
	if type(tInfo) == "table" and not Sku.IsSecret(tInfo) then
		return tInfo
	end
	return nil
end

-- The name the cooldown manager shows the entry under: linked spell, tooltip override, override, base spell.
local ID_KEYS = { "linkedSpellID", "overrideTooltipSpellID", "overrideSpellID", "spellID" }
local function tNameFromInfo(aInfo)
	if type(aInfo) ~= "table" or Sku.IsSecret(aInfo) then return nil end
	for _, tKey in ipairs(ID_KEYS) do
		local tName = tSpellName(aInfo[tKey])
		if tName then return tName end
	end
	return nil
end

local function tPlainName(aFrame)
	return tNameFromInfo(tInfo(aFrame))
end

-- The settings window's items (cooldownManagerForever.lua) name an aura the same way, so the sound set there is found.
function AuraEnd:NameFromInfo(aInfo)
	return tNameFromInfo(aInfo)
end

-- The sound the player picked for an aura (a key of SkuCore.outputSoundFiles), or nil: then the name is spoken.
function AuraEnd:GetSound(aName)
	local tSounds = SkuSettings:Sub("SkuCore").auraEndSounds
	return tSounds and tSounds[aName] or nil
end

-- Whether the aura's name is spoken as well when a sound is set (without a sound it is always spoken).
function AuraEnd:GetAlsoSpeak(aName)
	local tAlso = SkuSettings:Sub("SkuCore").auraEndAlsoSpeak
	return tAlso and tAlso[aName] == true or false
end

function AuraEnd:SetAlsoSpeak(aName, aValue)
	local tDb = SkuSettings:Sub("SkuCore")
	tDb.auraEndAlsoSpeak = tDb.auraEndAlsoSpeak or {}
	tDb.auraEndAlsoSpeak[aName] = aValue and true or nil
end

function AuraEnd:SetSound(aName, aSoundKey)
	local tDb = SkuSettings:Sub("SkuCore")
	tDb.auraEndSounds = tDb.auraEndSounds or {}
	tDb.auraEndSounds[aName] = aSoundKey
end

local function tViewerFrames()
	local tFrames = {}
	for _, tViewerName in ipairs(VIEWERS) do
		local tViewer = _G[tViewerName]
		if tViewer and tViewer.GetItemFrames then
			local tList = tViewer:GetItemFrames()
			if type(tList) == "table" then
				for _, tFrame in ipairs(tList) do
					tFrames[#tFrames + 1] = tFrame
				end
			end
		end
	end
	return tFrames
end

-- Whether the item frame shows its aura right now. A frame that is not drawn shows nothing: a viewer the player
-- shows only in combat unregisters its events, so its items keep stale data.
local function tAuraShown(aFrame)
	local tUnit = aFrame.auraDataUnit
	if not tPlain(tUnit) or aFrame.auraDataCached == nil then return false end
	if aFrame.IsVisible and not aFrame:IsVisible() then return false end
	if aFrame.IsActive then
		return aFrame:IsActive() == true
	end
	return true
end

local function tCooldownId(aFrame)
	local tI = tInfo(aFrame)
	if tI and tPlain(tI.cooldownID) then return tI.cooldownID end
	return nil
end

-- What the module sees, as one line for the debug ring (SkuDebugLog / the error log): each viewer shown or not, and per
-- item frame "name:unit:data:visible:active". Written only when it changes.
local gLastSummary
local function tSummary(aFrames)
	-- cvar: cooldownViewerEnabled (the viewers draw nothing when it is off); setting: the Edit Mode visibility of the
	-- viewer, 0 always / 1 in combat / 2 hidden (Enum.CooldownViewerVisibleSetting)
	local tAvailable = C_CooldownViewer and C_CooldownViewer.IsCooldownViewerAvailable and C_CooldownViewer.IsCooldownViewerAvailable()
	local tParts = { "cvar=" .. tostring(GetCVar("cooldownViewerEnabled")) .. " available=" .. tostring(tAvailable) }
	for _, tViewerName in ipairs(VIEWERS) do
		local tViewer = _G[tViewerName]
		tParts[#tParts + 1] = tViewerName .. "=" .. (tViewer and (tViewer:IsShown() and "shown" or "hidden") or "missing")
			.. (tViewer and (" setting=" .. tostring(tViewer.visibleSetting)) or "")
	end
	-- No call into the settings data provider here (GetOrderedCooldownIDs*, nor the viewers' GetCooldownIDs, which
	-- ask it): those rebuild its cached display data whenever it is dirty, the cache then counts as written by Sku,
	-- and Blizzard's layout switch on level-up / talent change reads it and gets blocked at
	-- C_UnitAuras.SetHiddenGroupBuffs (ADDON_ACTION_BLOCKED, Sku-Ever 0.43). Only plain fields are read below.
	-- inside the viewers: each pool frame as name/cooldownID/shown-or-hidden+Active-or-inactive+unit
	for _, tViewerName in ipairs(VIEWERS) do
		local tViewer = _G[tViewerName]
		if tViewer then
			local tPool = {}
			if tViewer.itemFramePool then
				for tFrame in tViewer.itemFramePool:EnumerateActive() do
					tPool[#tPool + 1] = tostring(tPlainName(tFrame) or "?") .. "/" .. tostring(tCooldownId(tFrame))
						.. "/" .. (tFrame:IsShown() and "s" or "h") .. ((tFrame.IsActive and tFrame:IsActive()) and "A" or "i")
						.. (tPlain(tFrame.auraDataUnit) and tFrame.auraDataUnit or "")
				end
			end
			tParts[#tParts + 1] = "[" .. tViewerName .. " pool=" .. table.concat(tPool, ",") .. "]"
		end
	end
	for _, tFrame in ipairs(aFrames) do
		tParts[#tParts + 1] = tostring(tPlainName(tFrame) or "?")
			.. ":" .. tostring(tPlain(tFrame.auraDataUnit) and tFrame.auraDataUnit or "-")
			.. ":" .. (tFrame.auraDataCached ~= nil and "data" or "nodata")
			.. ":" .. ((tFrame.IsVisible and tFrame:IsVisible()) and "vis" or "hid")
			.. ":" .. ((tFrame.IsActive and tFrame:IsActive()) and "active" or "inactive")
	end
	return table.concat(tParts, " ")
end

local function tTick()
	local tQuiet = gQuietTicks > 0
	if tQuiet then gQuietTicks = gQuietTicks - 1 end

	local tFrames = tViewerFrames()
	local tSum = tSummary(tFrames)
	if tSum ~= gLastSummary then
		gLastSummary = tSum
		dprint("auraEnd sees", #tFrames, tSum)
	end

	for _, tFrame in ipairs(tFrames) do
		local tState = gState[tFrame]
		if not tState then
			tState = {}
			gState[tFrame] = tState
		end

		local tId = tCooldownId(tFrame)
		local tName = tPlainName(tFrame)
		if tName then tState.name = tName end

		-- the viewer gave the frame another entry: start over without a verdict
		if tId ~= nil and tState.cooldownId ~= nil and tState.cooldownId ~= tId then
			tState.shown = nil
			tState.name = tName
		end
		if tId ~= nil then tState.cooldownId = tId end

		local tShown = tAuraShown(tFrame)
		if tState.shown == true and not tShown and not tQuiet and tState.name then
			local tSound = AuraEnd:GetSound(tState.name)
			if tSound then
				dprint("auraEnd", tState.name, tSound)
				SkuOptions.Voice:OutputString(tSound, false, true, 0.3, true)
			end
			if not tSound or AuraEnd:GetAlsoSpeak(tState.name) then
				local tText = tState.name .. " " .. Sku.deEn("fehlt", "missing", "manque")
				dprint("auraEnd", tText)
				SkuOptions.Voice:OutputStringBTtts(tText, false, true, 0.2)
			end
		end
		tState.shown = tShown
	end
end

local function tOnEvent(aFrame, aEvent)
	if aEvent == "PLAYER_REGEN_DISABLED" or aEvent == "PLAYER_REGEN_ENABLED" then
		-- the viewers' state at the start and end of every fight, for the debug ring
		dprint("auraEnd " .. aEvent, tSummary(tViewerFrames()))
		return
	end
	gQuietTicks = QUIET_TICKS
end

-- The cooldown manager draws nothing while its CVar is off (it is off by default; the game's own switch is under
-- Options, Advanced, Cooldown Viewer). Without it there are no tracked items to read.
function AuraEnd:IsViewerEnabled()
	return GetCVar("cooldownViewerEnabled") == "1"
end

function AuraEnd:SetViewerEnabled(aOn)
	SetCVar("cooldownViewerEnabled", aOn and "1" or "0")
	return AuraEnd:IsViewerEnabled() == (aOn and true or false)
end

-- Once per account: switch the cooldown manager on if it is off, and say so. After that the player's choice stands.
local function tEnsureViewerOn()
	local tDb = SkuSettings:Sub("SkuCore")
	if tDb.auraEndSwitchedViewerOn or AuraEnd:IsViewerEnabled() then return end
	if InCombatLockdown() then return end
	if AuraEnd:SetViewerEnabled(true) then
		tDb.auraEndSwitchedViewerOn = true
		SkuOptions.Voice:OutputStringBTtts(Sku.deEn("Cooldown Manager eingeschaltet", "Cooldown manager switched on", "Gestionnaire de recharge activé"), false, true, 0.2)
	else
		dprint("auraEnd could not switch the cooldown manager on")
	end
end

function AuraEnd:OnEnable()
	C_Timer.After(5, tEnsureViewerOn)
	gQuietTicks = QUIET_TICKS
	-- /skuaura reads the tracked auras (time left and stacks are only readable out of combat)
	if SkuOptions and SkuOptions.RegisterChatCommand and not gCommandRegistered then
		gCommandRegistered = true
		SkuOptions:RegisterChatCommand("skuaura", function() AuraEnd:SpeakTracked() end)
	end
	if not gEventFrame then
		gEventFrame = CreateFrame("Frame")
		gEventFrame:SetScript("OnEvent", tOnEvent)
	end
	gEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	gEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	gEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	gEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	if not gTicker then
		gTicker = C_Timer.NewTicker(TICK_SECONDS, tTick)
	end
end

function AuraEnd:OnDisable()
	if gEventFrame then gEventFrame:UnregisterAllEvents() end
	if gTicker then
		gTicker:Cancel()
		gTicker = nil
	end
end

-- The text of a font string if the game lets us have it (secret in combat).
local function tTextOf(aFontString)
	if not aFontString or not aFontString.GetText then return nil end
	local tText = aFontString:GetText()
	if tPlain(tText) and tText ~= "" then return tText end
	return nil
end

local function tTimerText(aFrame)
	local tCooldown = aFrame.Cooldown
	if tCooldown and tCooldown.GetCountdownFontString then
		local tText = tTextOf(tCooldown:GetCountdownFontString())
		if tText then return tText end
	end
	if aFrame.Bar then return tTextOf(aFrame.Bar.Duration) end
	return nil
end

local function tStacksText(aFrame)
	if aFrame.GetApplicationsFontString then
		return tTextOf(aFrame:GetApplicationsFontString())
	end
	return nil
end

-- What the tracked auras read right now, one line each.
function AuraEnd:GetTrackedTexts()
	local tTexts = {}
	for _, tFrame in ipairs(tViewerFrames()) do
		local tName = tPlainName(tFrame) or (gState[tFrame] and gState[tFrame].name)
		if tName then
			local tText
			if tAuraShown(tFrame) then
				tText = tName
				local tTimer = tTimerText(tFrame)
				if tTimer then
					tText = tText .. ", " .. tTimer
				elseif C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
					tText = tText .. ", " .. L["not readable in combat"]
				end
				local tStacks = tStacksText(tFrame)
				if tStacks then tText = tText .. ", " .. tStacks end
			else
				tText = tName .. " " .. Sku.deEn("fehlt", "missing", "manque")
			end
			tTexts[#tTexts + 1] = tText
		end
	end
	return tTexts
end

function AuraEnd:SpeakTracked()
	if not SkuCore:IsModuleEnabled("AuraEnd") then return end
	local tTexts = AuraEnd:GetTrackedTexts()
	if #tTexts == 0 then
		tTexts[1] = Sku.deEn("Keine verfolgten Auren im Cooldown Manager", "No tracked auras in the cooldown manager", "Aucune aura suivie dans le gestionnaire de recharge")
	end
	SkuOptions.Voice:OutputStringBTtts(table.concat(tTexts, ". "), true, true, 0.2)
end
