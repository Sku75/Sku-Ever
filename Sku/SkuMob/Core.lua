local MODULE_NAME = "SkuMob"
local _G = _G

---------------------------------------------------------------------------------------------------------------------------------------
SkuMob = LibStub("AceAddon-3.0"):NewAddon("SkuMob", "AceConsole-3.0", "AceEvent-3.0")
local L = Sku.L


---------------------------------------------------------------------------------------------------------------------------------------

local SkuMobDB = {
	lastTargetGuid = 0,
	nextAudioQ = "",
	lastAudioQ = "",
	}


	---------------------------------------------------------------------------------------------------------------------------------------
-- W4 Phase D (B-step-2): SkuMob is centrally registered as a runtime-toggleable
-- AceAddon. To make "off" genuinely disarm it and "on" (incl. mid-session
-- re-enable) fully re-arm, the WoW-event registration that used to live in
-- OnInitialize (which AceAddon runs ONCE per session) now runs on EVERY enable.
-- Extracted into a helper so OnEnable calls it; AceEvent:RegisterEvent is
-- idempotent (re-registering the same event just replaces), so the repeated
-- OnEnable calls from SkuZOptions profile-switch handlers stay safe.
local function RegisterSkuMobEvents()
	--SkuMob:RegisterEvent("PLAYER_ENTERING_WORLD")
	SkuMob:RegisterEvent("VARIABLES_LOADED")
	SkuMob:RegisterEvent("PLAYER_TARGET_CHANGED")
	SkuMob:RegisterEvent("QUEST_TURNED_IN")
	SkuMob:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
	SkuMob:RegisterEvent("PLAYER_SOFT_FRIEND_CHANGED")
	SkuMob:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
	SkuMob:RegisterEvent("PLAYER_SOFT_TARGET_INTERACTION")
end

-- Build the InCombatSounds lookup + wire it into the options menu. Originally
-- only built at VARIABLES_LOADED; extracted so OnEnable can ensure it exists for
-- a mid-session enable that happens AFTER VARIABLES_LOADED already fired. Safe to
-- call repeatedly (rebuilds the table from current SkuAuras/SkuAudio data).
local function EnsureInCombatSounds()
	SkuMob.InCombatSounds = {}
	SkuMob.InCombatSounds["Interface\\AddOns\\Sku\\SkuMob\\assets\\Target_in_combat_low.mp3"] = L["Default beep sound"]
	for i, v in pairs(SkuAuras.outputSoundFiles) do
		-- W5: Pfad über den Resolver; ohne installiertes Sprachpaket ist tPath nil
		-- und der Eintrag entfällt (nur der Default-Beep bleibt wählbar).
		local tPath = SkuAudioFileIndex and Sku:AudioFile(SkuAudioFileIndex[i])
		if tPath then
			SkuMob.InCombatSounds[tPath] = v
		end
	end
	SkuMob.options.args.InCombatSound.values = SkuMob.InCombatSounds

	if SkuSettings:Sub("SkuMob").InCombatSound == nil then
		SkuSettings:Sub("SkuMob").InCombatSound = "Interface\\AddOns\\Sku\\SkuMob\\assets\\Target_in_combat_low.mp3"
	end

	if SkuMob.InCombatSounds[SkuSettings:Sub("SkuMob").InCombatSound] == nil then
		SkuSettings:Sub("SkuMob").InCombatSound = "Interface\\AddOns\\Sku\\SkuMob\\assets\\Target_in_combat_low.mp3"
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:OnInitialize()
	--dprint("SkuMob OnInitialize")
	-- Event registration moved to OnEnable (re-armable) — see RegisterSkuMobEvents.
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:OutputTargetHealth(aForce)
	if Sku.SafeGUID("target") then
		if UnitCanAttack("player","target") ~= false then
			if aForce then
				SkuMobDB.lastAudioQ = ""
			end

			-- Forever hides the target's health: nothing to announce then
			local hp = Sku.UnitHealthPercent("target")
			if not hp then return end
			local hpPer = math.floor(((hp / 10)) + 1) * 10
			if (hpPer < 100 and hpPer > 0) or aForce then
				if hpPer > 100 then hpPer = 100 end
				if hpPer < 10 then hpPer = 0 end
				if hp == 0 then hpPer = 0 end

				if (Sku.SafeGUID("target") ~= SkuMobDB.lastTargetGuid) then
					SkuMobDB.nextAudioQ = hpPer--SkuMobDB.soundFiles[hpPer]
				end
				
				if  (SkuMobDB.nextAudioQ ~= hpPer) then
					SkuMobDB.nextAudioQ = hpPer
				end
				
				if SkuMobDB.nextAudioQ ~= "" then
					if (SkuMobDB.nextAudioQ ~= SkuMobDB.lastAudioQ) or (Sku.SafeGUID("target") ~= SkuMobDB.lastTargetGuid) then
						SkuOptions.Voice:OutputString(SkuMobDB.nextAudioQ, false, false, 0.3)
						SkuMobDB.lastAudioQ = SkuMobDB.nextAudioQ
						SkuMobDB.nextAudioQ = ""
					end
				end
			end
				
			SkuMobDB.lastTargetGuid = Sku.SafeGUID("target")
		end
	else
		SkuMobDB.lastTargetGuid = 0
		SkuMobDB.nextAudioQ = ""
		SkuMobDB.lastAudioQ = ""
	end

end

---------------------------------------------------------------------------------------------------------------------------------------
-- [v43.2] SKU_KEY_OUTPUTTARGETTOOLTIP -- speak the CURRENT unit's FULL tooltip.
--
-- PLAYER_TARGET_CHANGED below speaks a deliberately short, fixed set on every
-- target change: marker, dead, reaction, combat, name, level, classification,
-- plus tooltip LINE 2 only. Everything from line 3 on has therefore never been
-- reachable -- the faction/city line, the PvP flag, and above all the block the
-- server appends to a beast's tooltip once a Hunter has cast Beast Lore on it
-- (family, diet, tameable). Those lines are injected client-side in C: nothing
-- in the shipped Blizzard Lua builds them and no API returns them, so reading
-- the tooltip is the ONLY way to reach them at all.
--
-- On a key rather than folded into the automatic announce, and deliberately not
-- a setting: the frequent case (tab-targeting in combat) has to stay as terse as
-- it is today, and pressing the key IS the request for detail -- finer-grained
-- than any on/off option, because it is per-press.
--
-- Unit resolution: the hard target first, then the soft targets, so the same key
-- describes whatever the player is currently on rather than only a committed
-- target. softinteract is last -- it is the least likely to be what was meant
-- when anything else exists.
local tTooltipUnitOrder = {"target", "softenemy", "softfriend", "softinteract"}

function SkuMob:OutputTargetTooltip()
	local tUnitId
	for _, tCandidate in ipairs(tTooltipUnitOrder) do
		if UnitExists(tCandidate) then
			tUnitId = tCandidate
			break
		end
	end
	if not tUnitId then
		dprint("SkuMob OutputTargetTooltip: no unit on any of target/softenemy/softfriend/softinteract")
		SkuOptions.Voice:OutputStringBTtts(L["No target"], true, true, 0.3, nil, nil, nil, 1)
		return
	end

	local tTooltip = _G["SkuScanningTooltip"]
	if not tTooltip then
		dprint("SkuMob OutputTargetTooltip: SkuScanningTooltip missing (pre-PLAYER_LOGIN?)")
		return
	end

	-- SkuScanningTooltip is SHARED -- bags, auction house, chat links and quest
	-- text all read this one frame. So: clear before AND after, and restore the
	-- owner exactly as SkuCore:PLAYER_LOGIN set it, or whichever module reads it
	-- next inherits this unit's lines. Same reason SkuUtil:TooltipItemLink has to
	-- validate against the rendered first line -- :GetItem() stays sticky when a
	-- SetX fails.
	local tOk, tErr = pcall(function()
		tTooltip:ClearLines()
		tTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
		tTooltip:SetUnit(tUnitId)
	end)
	if not tOk then
		pcall(function() tTooltip:ClearLines() end)
		dprint("SkuMob OutputTargetTooltip: SetUnit threw for", tUnitId, tostring(tErr))
		return
	end

	local tOkText, tRaw = pcall(TooltipLines_helper, tTooltip:GetRegions())
	pcall(function() tTooltip:ClearLines() end)
	if not tOkText then
		dprint("SkuMob OutputTargetTooltip: TooltipLines_helper threw:", tostring(tRaw))
		return
	end
	if not tRaw or tRaw == "" then
		dprint("SkuMob OutputTargetTooltip: empty tooltip for", tUnitId, tostring(GetUnitName(tUnitId, false)))
		-- A unit DOES exist here, the tooltip just came back empty, so "No target"
		-- would be plainly wrong. Something must still be spoken: a key press with
		-- no audible answer cannot be told apart from a dead keybind.
		SkuOptions.Voice:OutputStringBTtts(L["Unknown"], true, true, 0.3, nil, nil, nil, 1)
		return
	end

	-- No newline handling needed: TooltipLines_helper joins its lines with a
	-- CRLF, and the SkuVoice-1.0 sanitiser already converts those to ";" --
	-- the character the voice layer actually splits parts on.
	local tText = SkuUtil:Unescape(tRaw)
	dprint("SkuMob OutputTargetTooltip: unit", tUnitId, "chars", #tText)
	SkuOptions.Voice:OutputStringBTtts(tText, true, true, 0.3, nil, nil, nil, 1)
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:OnEnable()
	--dprint("SkuMob OnEnable")
	-- Called when the addon is enabled. Re-arm the WoW events on every enable so
	-- a re-enable (toggle / profile switch / reload) restores them.
	RegisterSkuMobEvents()

	-- Ensure the InCombatSounds lookup exists. Normally built at VARIABLES_LOADED,
	-- but if this enable happens mid-session (after that event already fired) the
	-- table may be stale/missing, so (re)build it here too. Guarded against
	-- SkuAuras not yet being available on the very first load (VARIABLES_LOADED
	-- will then build it as before).
	if SkuAuras and SkuAuras.outputSoundFiles and SkuAudioFileIndex then
		EnsureInCombatSounds()
	end

	local ttime = 0
	local f = _G["SkuMobControl"] or CreateFrame("Frame", "SkuMobControl", UIParent)
	SkuMob.controlFrame = f
	f:SetScript("OnUpdate", function(self, time)
		ttime = ttime + time 
		if ttime > 0.25 then
			SkuMob:OutputTargetHealth()
			
			ttime = 0 
		end 
	end)
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:OnDisable()
	-- Real teardown so a disabled SkuMob genuinely does nothing: drop all of this
	-- addon's WoW-event registrations and stop the SkuMobControl OnUpdate driver
	-- (target-health + soft-target polling). The query/menu API (CreateAndUpdate-
	-- SkuMenuFrame, MenuBuilder, PLAYER_TARGET_CHANGED, GetTtsAwareUnitName, ...)
	-- stays defined and callable — disabling only disarms the lifecycle.
	SkuMob:UnregisterAllEvents()

	if SkuMob.controlFrame then
		SkuMob.controlFrame:SetScript("OnUpdate", nil)
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:RefreshVisuals()

end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:PLAYER_ENTERING_WORLD(...)
	

end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:VARIABLES_LOADED(...)
	EnsureInCombatSounds()
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:QUEST_TURNED_IN(...)
	-- process the event
	SkuMob.QuestTurnedIn = true
	C_Timer.After(5, function()
		SkuMob.QuestTurnedIn = false
		SkuOptions:SendTrackingStatusUpdates()
	end)
	SkuOptions:SendTrackingStatusUpdates("I-1")

end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:GetTtsAwareUnitName(aUnitId)
	if SkuSettings:Sub("SkuMob").vocalizePlayerNamePlaceholdersSkuTts ~= true then
		return UnitName(aUnitId)
	else
		local tBestUnitId = aUnitId
		
		if UnitIsUnit(aUnitId, "player") then
			return L["du selbst"]
		end

		if UnitIsUnit(aUnitId, "pet") then
			return L["dein begleiter"]
		end

		-- Only walk the roster when there IS one. Solo, both loops were 44
		-- guaranteed-nil UnitIsUnit calls per invocation -- and PLAYER_TARGET_CHANGED
		-- calls this 45 times per target change.
		-- Order preserved: party is still tested before raid (IsInGroup is true in a
		-- raid too, so a subgroup member keeps answering "party N" as before).
		if IsInGroup() then
			for x = 1, 4 do
				if UnitIsUnit(aUnitId, "party"..x) then
					return "party "..x
				end
			end
		end

		if IsInRaid() then
			for x = 1, GetNumGroupMembers() do
				if UnitIsUnit(aUnitId, "raid"..x) then
					return "raid "..x
				end
			end
		end

		return ""
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- [43.3] softTrace: Breadcrumbs fuer die Softtarget-Forensik ("nach dem Kill
-- greift Interact ploetzlich eine lebende angreifbare Einheit"). Genau EINE
-- Zeile pro PLAYER_SOFT_*_CHANGED, geloggt VOR allen Gates -- damit auch das
-- Leeren des Slots und Picks in DEAKTIVIERTEN Slots (Phantom-softenemy!) im
-- Ring landen, die die Ansage-Logik verschluckt. Lesen:
--   py -3 dev/rework-docs/_dbgtail.py 3000 softTrace
-- t= ist GetTime() mod 100 (Sekunden mit Nachkommastellen), weil der Ring nur
-- sekundengenaue Stempel hat und die fragliche Sequenz innerhalb 1-2 s liegt.
local function tSoftTraceGuid(aGuid)
	if type(aGuid) ~= "string" or aGuid == "" then return "-" end
	local tType = string.match(aGuid, "^(%a+)") or "?"
	local tTail = string.match(aGuid, "(%x+)$") or "?"
	return tType .. "-" .. tTail
end

local function tSoftTraceUnit(aUnitId)
	if UnitExists(aUnitId) ~= true then return "-" end
	-- Entfernungs-Klammer (LibRangeCheck: max,min) -- quantifiziert das "weit
	-- weg" des Phantom-Picks: die gemeldeten 25-30 m liegen UEBER der
	-- SoftTargetInteractRange von 15, das ist der offene Widerspruch.
	local tRng = "?"
	if SkuOptions and SkuOptions.RangeCheck and SkuOptions.RangeCheck.GetRange then
		local tOk, tMax, tMin = pcall(function() return SkuOptions.RangeCheck:GetRange(aUnitId) end)
		if tOk == true then tRng = tostring(tMin or "?") .. "-" .. tostring(tMax or "?") end
	end
	return string.format("%s dead=%d atk=%d typ=%s rng=%s", UnitName(aUnitId) or "?",
		UnitIsDead(aUnitId) == true and 1 or 0,
		UnitCanAttack("player", aUnitId) == true and 1 or 0,
		UnitCreatureType(aUnitId) or "?", tRng)
end

local function tSoftTrace(aSlot, aUnitId, aOldGuid, aNewGuid)
	-- [43.3] Nur unter /skudebug verbose: der Trace ruft pro Softtarget-Wechsel 4x
	-- LibRangeCheck (je Slot + Ziel) auf -- zu teuer, um dauerhaft mitzulaufen.
	local d = Sku.debug
	if not d or d.verbose ~= true then return end
	dprint(string.format("softTrace %s %s->%s  [%s]  tgt=[%s]  combat=%d WL=%s t=%.2f",
		aSlot, tSoftTraceGuid(aOldGuid), tSoftTraceGuid(aNewGuid),
		tSoftTraceUnit(aUnitId), tSoftTraceUnit("target"),
		UnitAffectingCombat("player") == true and 1 or 0,
		tostring(GetCVar("SoftTargetWithLocked")), GetTime() % 100))
end

---------------------------------------------------------------------------------------------------------------------------------------
-- [43.3] Feuert, wenn eine Interaktion tatsaechlich UEBER das Softtarget lief
-- (nicht ueber das Hardtarget) -- unterscheidet im Trace "G lief auf das
-- Softtarget zu" von "G wirkte auf das Hardtarget". Loggt ALLE drei Slots:
-- der Phantom-Pick koennte in einem anderen Slot sitzen als dem interact-Slot
-- (der deaktivierte enemy-Slot kann nachweislich Einheiten halten, und seine
-- Range steht auf 60 -- die 25-30-m-Picks passen zu ihm, nicht zu interact/15).
function SkuMob:PLAYER_SOFT_TARGET_INTERACTION(aEvent, ...)
	local d = Sku.debug
	if not d or d.verbose ~= true then return end
	dprint(string.format("softTrace INTERACTION si=[%s] se=[%s] sf=[%s]  tgt=[%s]  combat=%d WL=%s t=%.2f",
		tSoftTraceUnit("softinteract"), tSoftTraceUnit("softenemy"), tSoftTraceUnit("softfriend"),
		tSoftTraceUnit("target"),
		UnitAffectingCombat("player") == true and 1 or 0,
		tostring(GetCVar("SoftTargetWithLocked")), GetTime() % 100))
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Forever: a unit whose name the soft targeting just spoke is not announced by name a second time when it becomes the
-- hard target a moment later (the name came twice in a row). Level, marker and reaction are still spoken.
local tSoftSpokenGuid, tSoftSpokenTime = nil, 0
local SOFT_SPOKEN_WINDOW = 5
local tSoftQueuedGuid, tSoftQueuedTime = nil, 0
local tLastSoftEnemyGuid
function SkuMob:PLAYER_SOFT_ENEMY_CHANGED(arg1, arg2, arg3)
	tSoftTrace("enemy", "softenemy", arg2, arg3)
	-- UnitExists, not the GUID: a GUID Forever hides is nil too, and that is not "no target"
	if not UnitExists("softenemy") then
		if SkuOptions.db.profile["SkuOptions"].softTargeting.enemy.soundNoTarget ~= " " then
			if Sku.SafeGUID("softenemy") ~= tLastSoftEnemyGuid then
				SkuOptions.Voice:OutputString(SkuOptions.db.profile["SkuOptions"].softTargeting.enemy.soundNoTarget, true, true, 0.3, true)
			end
		end
		tLastSoftEnemyGuid = Sku.SafeGUID("softenemy")
		return
	end
	if SkuOptions.db.profile["SkuOptions"].softTargeting.enemy.enabled ~= true then
		return
	end

	if Sku.SafeGUID("softenemy") ~= Sku.SafeGUID("target") then
		if SkuOptions.db.profile["SkuOptions"].softTargeting.enemy.forPlayers == false and (UnitIsPlayer("softenemy") == true and UnitIsEnemy("player", "softenemy") == true) then
			return
		end
		if SkuOptions.db.profile["SkuOptions"].softTargeting.enemy.forPets == false and (UnitIsPlayer("softenemy") == false and UnitIsEnemy("player", "softenemy") == true and UnitPlayerControlled("softenemy") == true) then
			return
		end
		if SkuOptions.db.profile["SkuOptions"].softTargeting.enemy.forPassive == false and (UnitReaction("player", "softenemy") >= 4 and UnitCanAttack("player", "softenemy") == true) then
			return
		end
		
		if SkuOptions.db.profile["SkuOptions"].softTargeting.enemy.sound ~= " " then
			SkuOptions.Voice:OutputString(SkuOptions.db.profile["SkuOptions"].softTargeting.enemy.sound, true, true, 0.3, true)
		end
		if SkuOptions.db.profile["SkuOptions"].softTargeting.enemy.outputName == true then
			if SkuOptions.db.profile["SkuOptions"].softTargeting.enemy.muteInCombat ~= true or (SkuOptions.db.profile["SkuOptions"].softTargeting.enemy.muteInCombat == true and UnitAffectingCombat("player") ~= true) then
				SkuMob:PLAYER_TARGET_CHANGED("PLAYER_TARGET_CHANGED", "softenemy")
			end
		end
	end
	tLastSoftEnemyGuid = Sku.SafeGUID("softenemy")
end
---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:PLAYER_SOFT_FRIEND_CHANGED(aEvent, aGuid, aNewGuid)
	tSoftTrace("friend", "softfriend", aGuid, aNewGuid)
	if not Sku.SafeGUID("softfriend") then
		return
	end

	if Sku.SafeGUID("softfriend") ~= Sku.SafeGUID("target") then
		if SkuOptions.db.profile["SkuOptions"].softTargeting.friend.forPlayers == false and (UnitIsPlayer("softfriend") == true and UnitIsFriend("player", "softfriend") == true) then
			return
		end
		if SkuOptions.db.profile["SkuOptions"].softTargeting.friend.forPets == false and (UnitIsPlayer("softfriend") == false and UnitIsFriend("player", "softfriend") == true and UnitPlayerControlled("softfriend") == true) then
			return
		end
		if SkuOptions.db.profile["SkuOptions"].softTargeting.friend.sound ~= " " then
			SkuOptions.Voice:OutputString(SkuOptions.db.profile["SkuOptions"].softTargeting.friend.sound, true, true, 0.3, true)
		end
		if SkuOptions.db.profile["SkuOptions"].softTargeting.friend.outputName == true then
			SkuMob:PLAYER_TARGET_CHANGED("PLAYER_TARGET_CHANGED", "softfriend")
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:PLAYER_SOFT_INTERACT_CHANGED(aEvent, aGuid, aNewGuid)
	tSoftTrace("interact", "softinteract", aGuid, aNewGuid)
	-- Diagnose "Ton ja, Name nicht immer": jeder stille Ausstieg und die Namensausgabe landen im Ring
	dprint("SkuMob softInteract event: exists", UnitExists("softinteract"), "name", Sku.SafeName("softinteract"), "guid", tSoftTraceGuid(Sku.SafeGUID("softinteract")), "isTarget", Sku.SafeGUID("softinteract") ~= nil and Sku.SafeGUID("softinteract") == Sku.SafeGUID("target"))
	-- In a Forever instance the unit can exist with a SECRET guid (a corpse to loot): it cannot be compared with the target,
	-- but it is still announced (the name goes through SpeakSecretText below). Only a cleared slot is silent.
	local tSoftGuid = Sku.SafeGUID("softinteract")
	-- A game OBJECT (a quest item to click, a chest) is not a unit: UnitExists is false for it, but UnitName still answers
	-- (readable, or secret in an instance). Only a slot without any name is cleared.
	local tSoftRawName = UnitName("softinteract")
	if not tSoftGuid and not UnitExists("softinteract") and tSoftRawName == nil then
		dprint("SkuMob softInteract: silent - slot cleared")
		return
	end
	if not tSoftGuid then
		dprint("SkuMob softInteract: raw name", tSoftRawName == nil and "nil" or (Sku.IsSecret(tSoftRawName) and "secret" or "readable"))
	end
	if not tSoftGuid then
		dprint("SkuMob softInteract: guid secret, announcing anyway")
	end
	if SkuCore.LootRoll and SkuCore.LootRoll.quietUntil and GetTime() < SkuCore.LootRoll.quietUntil then
		dprint("SkuMob softInteract: silent - a loot roll is being announced")
		return
	end
	local tSoftDead = UnitIsDead("softinteract")
	if Sku.IsSecret(tSoftDead) then tSoftDead = true end -- a secret flag on an interactable unit in an instance: treat as a corpse

	if SkuOptions.db.profile["SkuOptions"].softTargeting.interact.enabled ~= true then
		dprint("SkuMob softInteract: silent - interact soft targeting is off")
		return
	end
	if tSoftGuid and tSoftGuid == Sku.SafeGUID("target") then
		dprint("SkuMob softInteract: silent - already the hard target")
	end
	if not tSoftGuid or tSoftGuid ~= Sku.SafeGUID("target") then
		--print("SkuMob:PLAYER_SOFT_INTERACT_CHANGED(aEvent, ", aGuid, UnitGUID("softinteract"))
		if ((SkuOptions.db.profile["SkuOptions"].softTargeting.interact.soundfor == 2 and UnitExists("softinteract") == false) 
			or (
					(SkuOptions.db.profile["SkuOptions"].softTargeting.interact.soundfor == 3 and UnitExists("softinteract") == true and tSoftDead == true) 
						or 
					UnitExists("softinteract") == false
				)
			or SkuOptions.db.profile["SkuOptions"].softTargeting.interact.soundfor == 4) and SkuOptions.db.profile["SkuOptions"].softTargeting.interact.soundfor > 1
		then			
			if SkuOptions.db.profile["SkuOptions"].softTargeting.interact.sound ~= " " then
				SkuOptions.Voice:OutputString(SkuOptions.db.profile["SkuOptions"].softTargeting.interact.sound, true, true, 0.3, true)
			end
		end
		if ((SkuOptions.db.profile["SkuOptions"].softTargeting.interact.unitNameFor == 2 and UnitExists("softinteract") == false) 
			or ((SkuOptions.db.profile["SkuOptions"].softTargeting.interact.unitNameFor == 3 and UnitExists("softinteract") == true and tSoftDead == true) or UnitExists("softinteract") == false) 
			or SkuOptions.db.profile["SkuOptions"].softTargeting.interact.unitNameFor == 4) and SkuOptions.db.profile["SkuOptions"].softTargeting.interact.unitNameFor > 1
		then
			if SkuOptions.db.profile["SkuOptions"].softTargeting.interact.outputBTTS == true then
				local tName = UnitName("softinteract")
				if not tName then
					dprint("SkuMob softInteract: NO NAME - UnitName returned nil, name not spoken")
				end
				-- Forever: the game sends this event twice for one change; the same unit within 0.6 s is spoken once.
				if Sku.isForever and tName and tSoftGuid and tSoftGuid == tSoftQueuedGuid and (GetTime() - tSoftQueuedTime) < 0.6 then
					dprint("SkuMob softInteract: silent - same unit queued a moment ago")
					tName = nil
				elseif Sku.isForever and tName and tSoftGuid then
					tSoftQueuedGuid, tSoftQueuedTime = tSoftGuid, GetTime()
				end
				if tName then
					C_Timer.After(0.1, function()
						dprint("SkuMob softInteract: speak name", Sku.IsSecret(tName) and "(secret)" or tName)
							if Sku.isForever and tSoftGuid then tSoftSpokenGuid, tSoftSpokenTime = tSoftGuid, GetTime() end
						-- no readable health (no pool, or hidden on Forever): dead only by its flag, else alive
						local hp = Sku.UnitHealthPercent("softinteract") or (tSoftDead and 0 or 100)
						-- An enemy's name is a secret value in a Forever instance (e.g. a corpse to loot); its GUID is a
						-- different restriction and can stay readable, so this point is reached. A secret cannot be
						-- concatenated or queued, it goes through SpeakSecretText.
						if Sku.IsSecret(tName) then
							SkuOptions.Voice:SpeakSecretText(hp == 0 and (L["dead"].." %s") or "%s", tName)
						elseif hp == 0 then
							SkuOptions.Voice:OutputStringBTtts(L["dead"].." "..tName, true, true, 0.2, true, nil, nil, 2)
						else
							SkuOptions.Voice:OutputStringBTtts(tName, true, true, 0.2, true, nil, nil, 2)
						end
					end)
				end
			else
				SkuMob:PLAYER_TARGET_CHANGED("PLAYER_SOFT_INTERACT_CHANGED", "softinteract")
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Ziel Ansage: the readers behind the parts of SkuMob.TA (SkuMob/Options.lua). Each returns a token, a list of tokens or
-- nil. A token is { text = plain or secret string, fmt = format for a secret ("%s", "Gilde %s", "%d"), audio = true
-- when Sku's recorded voice has the words }. A secret value (Forever instance, combat) is never compared or measured:
-- a secret string or number is handed on to SpeakSecretText, a secret flag is skipped.
local function tTAPlain(aValue)
	return aValue ~= nil and not Sku.IsSecret(aValue)
end
local function tTAFlag(aValue)
	return tTAPlain(aValue) and aValue == true
end
local function tTATok(aText, aAudio, aFmt)
	if aText == nil then return nil end
	if Sku.IsSecret(aText) then
		return { text = aText, fmt = aFmt or "%s" }
	end
	if type(aText) ~= "string" or aText == "" then return nil end
	if aFmt then aText = string.format(aFmt, aText) end
	return { text = aText, audio = aAudio == true }
end

local function tTAClassification(aUnitId)
	local c = UnitClassification(aUnitId)
	if not tTAPlain(c) then return nil end
	if c == "worldboss" then return L["world boss"] end
	if c == "rareelite" then return L["Rare Elite"] end
	if c == "elite" then return L["Elite"] end
	if c == "rare" then return L["Rare"] end
	return nil
end

-- Tooltip line 2 (title of an NPC such as "Gastwirt", owner of a pet), as before only when readable and not the level line.
local function tTATooltipLine2(aUnitId)
	local tText
	pcall(function()
		GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
		GameTooltip:SetUnit(aUnitId)
		GameTooltip:Show()
		local tLeft = _G["GameTooltipTextLeft2"]
		if tLeft then tText = tLeft:GetText() end
	end)
	if not tTAPlain(tText) or tText == "" then return nil end
	if string.find(tText, L["level"], 1, true) then return nil end
	return tText
end

-- Which kind of unit: only reads the game never makes secret (UnitIsPlayer, UnitPlayerControlled, UnitCanAttack).
local function tTAClassify(aUnitId)
	if not UnitExists(aUnitId) then return nil end
	if tTAFlag(UnitIsPlayer(aUnitId)) then return "player" end
	if tTAFlag(UnitPlayerControlled(aUnitId)) then
		local tTypeName, tTypeId = UnitCreatureType(aUnitId)
		if (tTAPlain(tTypeId) and tTypeId == 11) or (tTAPlain(tTypeName) and tTypeName == "Totem") then
			return "totem"
		end
		return "pet"
	end
	if tTAFlag(UnitCanAttack("player", aUnitId)) then return "mob" end
	return "npc"
end

local tTAReaders = {
	dead = function(u, c)
		if c.hp == 0 or tTAFlag(UnitIsDead(u)) or tTAFlag(UnitIsGhost(u)) then
			if tTAFlag(UnitIsGhost(u)) then
				return tTATok(Sku.deEn("Geist", "Ghost", "Fantôme"))
			end
			return tTATok(L["dead"], true)
		end
	end,
	name = function(u, c)
		if c.name == nil then return nil end
		-- a player's title goes in front of the name when Titel is on as well (UnitPVPName carries both)
		if c.cat == "player" and c.isOn("title") and not c.nameReplaced and UnitPVPName then
			local tPvp = UnitPVPName(u)
			if tPvp ~= nil then return tTATok(tPvp) end
		end
		return tTATok(c.name, true)
	end,
	title = function(u, c)
		if c.cat == "player" then
			if c.isOn("name") or not UnitPVPName then return nil end
			local tPvp, tName = UnitPVPName(u), UnitName(u)
			if not tTAPlain(tPvp) or not tTAPlain(tName) or tPvp == tName then return nil end
			local tTitle = string.gsub(tPvp, tName, "", 1)
			tTitle = string.gsub(tTitle, "^[%s,]+", "")
			tTitle = string.gsub(tTitle, "[%s,]+$", "")
			return tTATok(tTitle)
		end
		return tTATok(tTATooltipLine2(u), true)
	end,
	realm = function(u)
		local _, tRealm = UnitName(u)
		return tTATok(tRealm, false, Sku.deEn("Realm %s", "Realm %s", "Royaume %s"))
	end,
	guild = function(u)
		if not GetGuildInfo then return nil end
		return tTATok((GetGuildInfo(u)), false, Sku.deEn("Gilde %s", "Guild %s", "Guilde %s"))
	end,
	level = function(u)
		local tLevel = UnitLevel(u)
		if not tTAPlain(tLevel) then return nil end
		if tLevel == -1 then
			return tTATok(L["level"].." "..L["Unknown"], true)
		end
		return tTATok(L["level"].." "..string.format("%02d", tLevel), true)
	end,
	classification = function(u)
		return tTATok(tTAClassification(u), true)
	end,
	race = function(u)
		return tTATok((UnitRace(u)))
	end,
	class = function(u)
		return tTATok((UnitClass(u)))
	end,
	gender = function(u)
		local s = UnitSex(u)
		if not tTAPlain(s) then return nil end
		if s == 2 then return tTATok(Sku.deEn("männlich", "male", "masculin")) end
		if s == 3 then return tTATok(Sku.deEn("weiblich", "female", "féminin")) end
	end,
	faction = function(u)
		local _, tFaction = UnitFactionGroup(u)
		return tTATok(tFaction)
	end,
	role = function(u)
		if not UnitGroupRolesAssigned then return nil end
		local r = UnitGroupRolesAssigned(u)
		if not tTAPlain(r) then return nil end
		if r == "TANK" then return tTATok(Sku.deEn("Tank", "Tank", "Tank")) end
		if r == "HEALER" then return tTATok(Sku.deEn("Heiler", "Healer", "Soigneur")) end
		if r == "DAMAGER" then return tTATok(Sku.deEn("Schadensausteiler", "Damage dealer", "Dégâts")) end
	end,
	pvp = function(u)
		if UnitIsPVPFreeForAll and tTAFlag(UnitIsPVPFreeForAll(u)) then
			return tTATok(Sku.deEn("Jeder gegen jeden PvP", "Free for all PvP", "JcJ chacun pour soi"))
		end
		if tTAFlag(UnitIsPVP(u)) then return tTATok("PvP") end
	end,
	afk = function(u)
		if tTAFlag(UnitIsAFK(u)) then return tTATok("AFK") end
	end,
	dnd = function(u)
		if tTAFlag(UnitIsDND(u)) then return tTATok(Sku.deEn("Nicht stören", "Do not disturb", "Ne pas déranger")) end
	end,
	charmed = function(u)
		if tTAFlag(UnitIsCharmed(u)) then return tTATok(Sku.deEn("beherrscht", "charmed", "charmé")) end
	end,
	reaction = function(u, c)
		if c.cat == "player" then
			if tTAFlag(UnitIsFriend("player", u)) then return tTATok(L["freundlicher spieler"], true) end
			return tTATok(L["feindlicher spieler"], true)
		end
		local r = UnitReaction(u, "player")
		if not tTAPlain(r) then return nil end
		if r <= 3 then return tTATok(Sku.deEn("feindselig", "hostile", "hostile")) end
		if r == 4 then return tTATok(Sku.deEn("neutral", "neutral", "neutre")) end
		return tTATok(Sku.deEn("freundlich", "friendly", "amical"))
	end,
	creatureType = function(u)
		return tTATok((UnitCreatureType(u)))
	end,
	creatureFamily = function(u)
		return tTATok((UnitCreatureFamily(u)))
	end,
	questBoss = function(u)
		if UnitIsQuestBoss and tTAFlag(UnitIsQuestBoss(u)) then
			return tTATok(Sku.deEn("Quest-Boss", "Quest boss", "Boss de quête"))
		end
	end,
	questTarget = function(u)
		if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest and tTAFlag(C_QuestLog.UnitIsRelatedToActiveQuest(u)) then
			return tTATok(Sku.deEn("Questziel", "Quest target", "Cible de quête"))
		end
	end,
	tapped = function(u)
		if UnitIsTapDenied and tTAFlag(UnitIsTapDenied(u)) then
			return tTATok(Sku.deEn("von anderen beansprucht", "tapped by others", "pris par un autre"))
		end
	end,
	-- the yellow name background of the target frame: attackable but not aggressive (only known for the hard target)
	passive = function(u)
		if u ~= "target" or not TargetFrameNameBackground then return nil end
		local r, g, b = TargetFrameNameBackground:GetVertexColor()
		if tTAPlain(r) and tTAPlain(g) and tTAPlain(b) and r > 0.99 and g > 0.99 and b == 0 then
			return tTATok(L["passive"], true)
		end
	end,
	owner = function(u)
		if UnitIsUnit(u, "pet") then return tTATok(Sku.deEn("von dir", "yours", "à toi")) end
		return tTATok(tTATooltipLine2(u))
	end,
	combat = function(u)
		if tTAFlag(UnitAffectingCombat(u)) then return tTATok(L["im kampf"], true) end
	end,
}

---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:PLAYER_TARGET_CHANGED(event, aUnitId)
	C_Timer.After(0.01, function() --this delay is to provide the combat monitor an option to first send output to the tts queue

		aUnitId = aUnitId or "target"
		-- the key "Ziel ansagen" (SKU_KEY_OUTPUTHARDTARGET) asks with event "QUERY": the query sets of Ziel Ansage apply
		local tIsQuery = (event == "QUERY")

		dprint("SkuMob PLAYER_TARGET_CHANGED(event, ", event, aUnitId)

		if aUnitId == "target" then
			SkuCore.RangeCheck:DoRangeCheck(true, nil, "target")

			-- [42.11] Option "no interact soft targeting while an ATTACKABLE hard
			-- target is locked" is a property of WHAT is targeted, so the rule is
			-- re-evaluated here and nowhere else -- no ticker, no polling. No-op
			-- unless the wanted CVar value actually changed.
			SkuOptions:UpdateSoftTargetLockRule()
		end

		if not UnitExists(aUnitId) and aUnitId ~= "softinteract" then
			dprint("SkuMob PTC: silent - unit does not exist", aUnitId)
			if tIsQuery then
				SkuOptions.Voice:OutputStringBTtts(L["No target"], true, true, 0.3, nil, nil, nil, 1)
			end
			return
		end

		local tUnitName = GetUnitName(aUnitId, false)

		-- Players, their pets, totems, you: steered by a player -> no combat beep and no Sku colour. What is SAID about
		-- them is chosen in Ziel Ansage (the old player switches and the placeholder names are gone).
		local tIsPlayerControled = false
		if UnitPlayerControlled(aUnitId) == true or UnitIsUnit("pet", aUnitId) or UnitIsUnit("player", aUnitId) then
			tIsPlayerControled = true
		end

			--[[
			1 Exceptionally hostile
			2 Very Hostile
			3 Hostile
			4 Neutral
			5 Friendly
			6 Very Friendly
			7 Exceptionally friendly
			8 Exalted
			]]


		--target in combat indicator
		-- This block answers one question: is anyone in MY group already fighting
		-- this unit (threat), and is my target's target one of us? That is why the
		-- roster is walked at all -- and it runs on EVERY target change, not just on
		-- a focus call.
		--
		-- 4 and 40 are the real maximum party/raid sizes, so they were never wrong,
		-- only unconditional: solo (the common case) party1-4 and raid1-40 do not
		-- exist and all 88 lookups returned nothing. Worse, GetTtsAwareUnitName
		-- walks the same 44 units internally when the placeholder option is on, so
		-- one target change cost ~2000 UnitIsUnit calls to build an empty table.
		-- Gate on the real group state and walk only the slots the raid actually
		-- has (same idiom as SkuAuras/Core.lua and SkuQuest/Options.lua).
		-- Behaviour-identical: a slot that does not exist yields nothing either way.
		local tIsInGroup = IsInGroup()
		local tRaidSize = IsInRaid() and GetNumGroupMembers() or 0

		-- [v42.13] `name ~= ""` on every insert and on the lookup below. With
		-- vocalizePlayerNamePlaceholdersSkuTts ON, GetTtsAwareUnitName returns ""
		-- for any unit it cannot classify -- including a unit that does not exist --
		-- so "" landed in this set as a KEY. The lookup below then matched "" against
		-- it and set status = true for every target whose target was not a known
		-- groupmate, i.e. for every target, always. See the comment there.
		local tRosterNames = {}
		if tIsInGroup then
			for x = 1, 4 do
				local name, realm = SkuMob:GetTtsAwareUnitName("party"..x)
				if name and name ~= "" then
					tRosterNames[name] = name
				end
			end
		end
		for x = 1, tRaidSize do
			local name, realm = SkuMob:GetTtsAwareUnitName("raid"..x)
			if name and name ~= "" then
				tRosterNames[name] = name
			end
		end
		local name, realm = SkuMob:GetTtsAwareUnitName("pet")
		if name and name ~= "" then
			tRosterNames[name] = name
		end
		local name, realm = SkuMob:GetTtsAwareUnitName("player")
		tRosterNames[name] = name

		local status = nil
		if tIsInGroup then
			for x = 1, 4 do
				if UnitThreatSituation("party"..x, aUnitId) then
					status = UnitThreatSituation("party"..x, aUnitId)
				end
			end
		end
		for x = 1, tRaidSize do
			if UnitThreatSituation("raid"..x, aUnitId) then
				status = UnitThreatSituation("raid"..x, aUnitId)
			end
		end
		if UnitThreatSituation("pet", aUnitId) then
			status = UnitThreatSituation("pet", aUnitId)
		end
		if UnitThreatSituation("player", aUnitId) then
			status = UnitThreatSituation("player", aUnitId)
		end

		-- Is my target attacking me, my pet or a groupmate? That is what makes a mob
		-- "in combat" even when the threat API says nothing.
		-- [v42.13] The `name ~= ""` guard is what makes this test mean anything with
		-- vocalizePlayerNamePlaceholdersSkuTts ON: an unclassifiable targettarget --
		-- no target at all, or a stranger -- comes back as "", which used to match
		-- the "" key in tRosterNames and flag EVERY target as in combat.
		local name, realm = SkuMob:GetTtsAwareUnitName("targettarget")
		-- An enemy's name is a secret value in a Forever instance: it cannot be compared or used as a key. Skipping it
		-- loses nothing: group members' names stay readable, so a secret name is never one of tRosterNames.
		if name and not Sku.IsSecret(name) and name ~= "" then
			if tRosterNames[name] then
				status = true
			end
		end

		-- [Forever] In an instance the threat and target-of-target answers above can be nil or unusable for an enemy, so the
		-- "in combat" beep stayed silent. The unit's own combat flag is not secret there (same reading the nameplate enemy
		-- counter in aqCombat.lua relies on).
		-- Only in an instance (there every enemy in combat fights the group, same rule as the nameplate counter in aqCombat.lua).
		-- In the open world the threat check above answers, and an enemy that only fights a STRANGER must stay silent.
		if not status and Sku.isForever and IsInInstance() and UnitCanAttack("player", aUnitId) then
			local tUnitInCombat = UnitAffectingCombat(aUnitId)
			if tUnitInCombat ~= nil and not Sku.IsSecret(tUnitInCombat) and tUnitInCombat then
				status = true
			end
		end

		-- [41.05] Gegnerstatus Kampf: off = kein Beep, beep/announce = Beep wie bisher.
		local tCombatStatusMode = SkuSettings:Sub("SkuMob").enemyCombatStatusMode or "beep"
		if status and tIsPlayerControled == false and tCombatStatusMode ~= "off" then
			--creature in combat indicator
			local tAudioFile = SkuSettings:Sub("SkuMob").InCombatSound or "Interface\\AddOns\\Sku\\SkuMob\\assets\\Target_in_combat_low.mp3"
			local willPlay, soundHandle = PlaySoundFile(tAudioFile, SkuOptions.db.profile["SkuOptions"].soundChannels.SkuChannel or "Talking Head")
		end

		--raidtarget
		-- Readable marker: its name ("Totenkopf"). Secret marker (Forever instance, combat): its number, spoken through
		-- SpeakSecretText ("8"); it cannot be turned into a name (no table lookup, no comparison). No marker: the Sku colour
		-- of this unit, handed out on the first sight in combat when "Sku-Symbole automatisch setzen" is on.
		local tRaidtarget = GetRaidTargetIndex(aUnitId)
		local tRaidtargetSecret = Sku.IsSecret(tRaidtarget)
		local tRaidtargetRaw = tRaidtarget
		if tRaidtargetSecret then tRaidtarget = nil end
		local tUnitGUID = Sku.SafeGUID(aUnitId)
		local tMarkerToken
		if tRaidtargetSecret then
			tMarkerToken = { text = tRaidtargetRaw, fmt = "%d" }
		elseif tRaidtarget and SkuCore.RaidTargetValues[tRaidtarget] then
			tMarkerToken = { text = SkuCore.RaidTargetValues[tRaidtarget].name, audio = true }
		elseif tRaidtarget == nil or tRaidtarget == "" or tRaidtarget == 0 then
			local tSkuId = SkuCore.aqCombat:aqCombatGetSkuRaidTarget(tUnitGUID)
			if tSkuId == nil and UnitCanAttack("player", aUnitId) and tIsPlayerControled == false and status
				and SkuSettings:Sub("SkuMob").autoSetSkuRaidTargetsToInCombatCreatures == true then
				tSkuId = SkuCore.aqCombat:aqCombatSetSkuRaidTarget(tUnitGUID, 0)
			end
			if tSkuId and SkuCore.RaidTargetValues[tSkuId] then
				tMarkerToken = { text = SkuCore.RaidTargetValues[tSkuId].color, audio = true }
			end
		end

		-- [41.05] spoken combat status "im Kampf", only in the announce mode of Gegnerstatus Kampf
		local tCombatAnnounce = status and tIsPlayerControled == false and tCombatStatusMode == "announce"

		local hp = Sku.UnitHealthPercent(aUnitId) or (UnitIsDead(aUnitId) and 0 or nil)

		if aUnitId == "softinteract" then
			if UnitExists("softinteract") == false then
				hp = 100
			end
			tUnitName = UnitName("softinteract")
		end

		-- the name as it is spoken; a secret name as it is (SpeakSecretText). With "Generische Namen" (Weitere
		-- Zieloptionen, off by default) you, your pet and your group members are named by their role instead.
		local tNameOut = tUnitName
		local tNameReplaced = false
		if SkuSettings:Sub("SkuMob").genericNames == true then
			if UnitIsUnit("player", aUnitId) then
				tNameOut, tNameReplaced = L["du selbst"], true
			elseif UnitIsUnit("pet", aUnitId) then
				tNameOut, tNameReplaced = L["dein begleiter"], true
			elseif IsInRaid() then
				for x = 1, GetNumGroupMembers() do
					if UnitIsUnit("raid"..x, aUnitId) then
						tNameOut, tNameReplaced = "raid "..x, true
						break
					end
				end
			elseif IsInGroup() then
				for x = 1, 4 do
					if UnitIsUnit("party"..x, aUnitId) then
						tNameOut, tNameReplaced = "party "..x, true
						break
					end
				end
			end
		end
		-- Forever: soft targeting spoke this unit's name moments ago -> do not say it again as hard target (not on request).
		if Sku.isForever and aUnitId == "target" and not tIsQuery and tUnitGUID and tUnitGUID == tSoftSpokenGuid
			and (GetTime() - tSoftSpokenTime) < SOFT_SPOKEN_WINDOW then
			dprint("SkuMob PTC: name already spoken by soft targeting, left out")
			tNameOut = nil
			tSoftSpokenGuid = nil
		elseif Sku.isForever and aUnitId ~= "target" and tUnitGUID then
			tSoftSpokenGuid, tSoftSpokenTime = tUnitGUID, GetTime()
		end

		-- Ziel Ansage: the parts chosen for this kind of unit and this situation (SkuMob.TA, SkuMob/Options.lua)
		local tTA = SkuMob.TA
		local tSetKey = tTA:SetFor(tIsQuery)
		local tCat = tTAClassify(aUnitId)
		local tTokens = {}
		local tSeen = {}
		local function tAdd(aToken)
			if aToken == nil then return end
			if aToken.text == nil then
				for _, t in ipairs(aToken) do tAdd(t) end
				return
			end
			if not aToken.fmt then
				if tSeen[aToken.text] then return end
				tSeen[aToken.text] = true
			end
			tTokens[#tTokens + 1] = aToken
		end

		if tMarkerToken then
			tTokens[#tTokens + 1] = tMarkerToken
			if SkuSettings:Sub("SkuMob").repeatRaidTargetMarkers == true then
				tTokens[#tTokens + 1] = tMarkerToken
			end
		end
		local tMarkerOnly = tMarkerToken ~= nil and SkuSettings:Sub("SkuMob").vocalizeRaidTargetOnly == true and hp ~= 0
		if not tMarkerOnly then
			if tCombatAnnounce then
				tAdd({ text = L["im kampf"], audio = true })
			end
			if tCat then
				local tCtx = {
					cat = tCat,
					hp = hp,
					name = tNameOut,
					nameReplaced = tNameReplaced,
					isOn = function(aKey) return tTA:IsOn(tSetKey, tCat, aKey) end,
				}
				for _, tKey in ipairs(tTA.ORDER[tCat]) do
					if tTA:IsOn(tSetKey, tCat, tKey) and tTAReaders[tKey] then
						local tOk, tResult = pcall(tTAReaders[tKey], aUnitId, tCtx)
						if tOk then
							tAdd(tResult)
						else
							dprint("SkuMob TA part failed", tKey, tostring(tResult))
						end
					end
				end
			else
				-- not a unit (a game object for the soft interaction): its name
				tAdd(tTATok(tNameOut, true))
			end
		end

		-- Speak. A secret part -> one line through SpeakSecretText. Only words Sku's recorded voice has, on an NPC or an
		-- enemy -> Sku's voice, as before. Everything else -> Blizzard's voice.
		if #tTokens == 0 then
			dprint("SkuMob PTC: nothing chosen to say", tostring(tCat), tSetKey)
			return
		end
		local tHasSecret = false
		local tAllAudio = (tCat == "npc" or tCat == "mob" or tCat == nil)
		for _, t in ipairs(tTokens) do
			if t.fmt then tHasSecret = true end
			if not t.audio then tAllAudio = false end
		end
		if tHasSecret then
			local tParts, tArgs = {}, {}
			for _, t in ipairs(tTokens) do
				if t.fmt then
					tParts[#tParts + 1] = t.fmt
					tArgs[#tArgs + 1] = t.text
				else
					tParts[#tParts + 1] = (string.gsub(t.text, "%%", "%%%%"))
				end
			end
			local tFormat = table.concat(tParts, ", ")
			dprint("SkuMob PTC speak (secret parts):", tSetKey, tostring(tCat), tFormat)
			SkuOptions.Voice:SpeakSecretText(tFormat, unpack(tArgs))
		else
			local tTexts = {}
			for _, t in ipairs(tTokens) do tTexts[#tTexts + 1] = t.text end
			if tAllAudio then
				local tLine = table.concat(tTexts, ";")
				dprint("SkuMob PTC speak (audio):", tSetKey, tostring(tCat), tLine)
				SkuOptions.Voice:OutputString(tLine, true, true, 0.3)
			else
				local tLine = table.concat(tTexts, ", ")
				dprint("SkuMob PTC speak (btts):", tSetKey, tostring(tCat), tLine)
				SkuOptions.Voice:OutputStringBTtts(tLine, true, true, 0.3, nil, nil, nil, 1)
			end
		end

	end)
end

-- Forever: Blizzard's combat audio alert "Zielname ansagen" (CVar CAASayTargetName) speaks every target's name, with no
-- difference between players, NPCs and enemies, next to Sku's announcement. Sku speaks the names itself now, secret ones
-- in an instance too, so it switches Blizzard's announcement off, once per profile; whoever wants it back can switch
-- it on again in the game's options. (Replaces the old switch "Blizzard Zielname automatisch regeln", which turned it
-- on in every instance.)
function SkuMob:SwitchOffBlizzardTargetName()
	if not Sku.isForever or InCombatLockdown() then return end
	local tDb = SkuSettings:Sub("SkuMob")
	if not tDb or tDb.blizzardTargetNameSwitchedOff == true or GetCVar("CAASayTargetName") == nil then return end
	local tOk, tErr = pcall(SetCVar, "CAASayTargetName", "0")
	dprint("CAA target name switched off", tostring(tOk), tostring(tErr), "readback", tostring(GetCVar("CAASayTargetName")))
	if tOk then tDb.blizzardTargetNameSwitchedOff = true end
end

if Sku.isForever then
	local tFrame = CreateFrame("Frame")
	tFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	tFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	tFrame:SetScript("OnEvent", function(_, aEvent)
		if aEvent == "PLAYER_ENTERING_WORLD" then
			C_Timer.After(1, function() SkuMob:SwitchOffBlizzardTargetName() end)
		else
			SkuMob:SwitchOffBlizzardTargetName()
		end
	end)
end
