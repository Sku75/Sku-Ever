-- Messfunktion (nur Forever): schreibt bei jeder Aenderung Kampfstatus von Spieler
-- und Pet, Ziele und Abstand ins Debug-Log (Kategorie "combatProbe"), damit man
-- sieht, WAS beim Abbruch eines Kampfes zuerst kippt. Nur Lesen, greift nirgends ein.
if not (Sku and Sku.isForever) then return end

local function tSafe(aFunc, ...)
	local tOk, a, b, c = pcall(aFunc, ...)
	if tOk then return a, b, c end
	return nil
end

local function tYN(aValue)
	if issecretvalue and issecretvalue(aValue) then return "geheim" end
	if aValue == nil then return "-" end
	return aValue and "ja" or "nein"
end

local function tDist()
	local py, px = tSafe(UnitPosition, "player")
	local qy, qx = tSafe(UnitPosition, "pet")
	if type(py) == "number" and type(qy) == "number" then
		return string.format("%.0f", math.sqrt((px - qx) ^ 2 + (py - qy) ^ 2))
	end
	-- positions are not readable on Forever: fall back to the range library (min-max yards)
	local tOk, tMax, tMin = pcall(function() return SkuOptions.RangeCheck:GetRange("pet") end)
	if tOk and (tMax or tMin) then return tostring(tMin or "?") .. "-" .. tostring(tMax or "?") end
	return "?"
end

local tLast = ""
local function tSnapshot(aReason)
	local tPetExists = tSafe(UnitExists, "pet") == true
	local tTargetExists = tSafe(UnitExists, "target") == true
	local tPetTargetExists = tSafe(UnitExists, "pettarget") == true
	local tState = table.concat({
		"ichKampf=" .. tYN(tSafe(UnitAffectingCombat, "player")),
		"pet=" .. tYN(tPetExists),
		"petKampf=" .. (tPetExists and tYN(tSafe(UnitAffectingCombat, "pet")) or "-"),
		"petZiel=" .. tYN(tPetTargetExists),
		"ziel=" .. tYN(tTargetExists),
		"zielKampf=" .. (tTargetExists and tYN(tSafe(UnitAffectingCombat, "target")) or "-"),
		"zielTot=" .. (tTargetExists and tYN(tSafe(UnitIsDead, "target")) or "-"),
		"zielIstPetZiel=" .. ((tTargetExists and tPetTargetExists) and tYN(tSafe(UnitIsUnit, "target", "pettarget")) or "-"),
		"fokus=" .. tYN(tSafe(UnitExists, "focus")),
		"abstandPet=" .. (tPetExists and tDist() or "-"),
	}, " ")
	-- Ticker nur bei Aenderung loggen, Ereignisse immer.
	if aReason == "tick" and tState == tLast then return end
	tLast = tState
	dprint("combatProbe", aReason, tState)
end

local tFrame = CreateFrame("Frame")
for _, tEvent in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED",
	"PLAYER_FOCUS_CHANGED", "PET_ATTACK_START", "PET_ATTACK_STOP", "UNIT_PET", "PLAYER_UNGHOST",
	"UI_ERROR_MESSAGE", "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "PET_BAR_UPDATE" }) do
	pcall(tFrame.RegisterEvent, tFrame, tEvent)
end
tFrame:SetScript("OnEvent", function(_, aEvent, aArg1, aArg2)
	if aEvent == "UI_ERROR_MESSAGE" then
		-- the game's own refusal texts ("target too far", "no path", ...) -- often the actual reason
		local tText = (issecretvalue and issecretvalue(aArg2)) and "geheim" or tostring(aArg2)
		dprint("combatProbe", "FEHLERMELDUNG", tText)
		return
	end
	if aEvent == "PET_BAR_UPDATE" then return end -- too chatty, only wanted inside snapshots
	tSnapshot(aEvent)
end)

-- Who calls the commands that end a pet attack? Logged with a short call stack, so the caller is visible.
-- (hooksecurefunc only watches; it changes nothing and cannot taint the original.)
for _, tName in ipairs({ "PetAttack", "PetFollow", "PetStopAttack", "PetPassiveMode", "PetDefensiveMode",
	"PetAssistMode", "PetWait", "AttackTarget", "StopAttack", "ClearTarget", "TargetUnit", "FocusUnit", "ClearFocus" }) do
	if type(_G[tName]) == "function" then
		hooksecurefunc(tName, function()
			local tStack = tSafe(debugstack, 3, 8, 0) or "?"
			dprint("combatProbe", "AUFRUF", tName, (tostring(tStack):gsub("[\r\n]+", " | "):sub(1, 700)))
		end)
	end
end

C_Timer.NewTicker(0.5, function()
	tSnapshot("tick")
end)

-- Test fuer die Markierungs-Ansage (nur Forever): kann man eine GEHEIME Markierungsnummer ueber select/string.sub in ein Wort
-- uebersetzen? Laeuft automatisch (hoechstens 6x pro Sitzung), wenn ein Ziel mit Markierung angewaehlt wird, und schreibt
-- "MARKERTEST ..." ins Log; zusaetzlich als Befehl /skumarkertest (kommt in manchen Faellen nicht an).
local tMarkerTestCount = 0
local function tMarkerTest(aSpeak)
	local tIdx = GetRaidTargetIndex("target")
	if tIdx == nil then return end
	tMarkerTestCount = tMarkerTestCount + 1
	local tSecret = issecretvalue and issecretvalue(tIdx) or false
	local tOkSelect, tSel = pcall(function() return (select(tIdx, "Stern", "Kreis", "Diamant", "Dreieck", "Mond", "Quadrat", "Kreuz", "Totenkopf")) end)
	local tSelOut = tOkSelect and ((issecretvalue and issecretvalue(tSel)) and "geheim" or tostring(tSel)) or "Fehler"
	local tOkSub, tSub = pcall(function() return string.sub("ABCDEFGH", tIdx, tIdx) end)
	local tSubOut = tOkSub and ((issecretvalue and issecretvalue(tSub)) and "geheim" or tostring(tSub)) or "Fehler"
	local tOkFmt = pcall(function() return string.format("%d", tIdx) end)
	local tOkRep = pcall(function() return string.rep("x", tIdx) end)
	dprint("combatProbe", "MARKERTEST", "nummer", tSecret and "geheim" or tostring(tIdx), "select", tSelOut, "sub", tSubOut,
		"format", tOkFmt and "ok" or "Fehler", "rep", tOkRep and "ok" or "Fehler")
	if aSpeak then
		SkuOptions.Voice:OutputStringBTtts("Markertest. Nummer " .. (tSecret and "geheim" or tostring(tIdx)) .. ". Select " .. tSelOut .. ". Sub " .. tSubOut .. ".", true, true, 0.2)
	end
end
local tMarkerFrame = CreateFrame("Frame")
tMarkerFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
tMarkerFrame:SetScript("OnEvent", function()
	if tMarkerTestCount < 6 then
		C_Timer.After(0.3, function() tMarkerTest(false) end)
	end
end)
SLASH_SKUMARKERTEST1 = "/skumarkertest"
SlashCmdList["SKUMARKERTEST"] = function() tMarkerTest(true) end

-- Messung "Folgen bricht ab" (nur Forever): schreibt bei AUTOFOLLOW_BEGIN/END, was zu dem Zeitpunkt los ist (Dauer, Abstand zum
-- Ziel, Kampf, Reittier, Zauber, letzte Fehlermeldung des Spiels, Zahl der Start/Stopp-Wechsel der Bewegung), damit man sieht,
-- WAS das Folgen beendet. Die Bewegungswechsel werden nur gezaehlt, nicht einzeln geloggt (sie kamen ~90 mal pro Sekunde).
local tFollowFrame = CreateFrame("Frame")
local tLastUiError, tLastUiErrorAt = "", 0
for _, tEvent in ipairs({ "AUTOFOLLOW_BEGIN", "AUTOFOLLOW_END", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
	"PLAYER_MOUNT_DISPLAY_CHANGED", "UI_ERROR_MESSAGE", "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "PLAYER_TARGET_CHANGED" }) do
	pcall(tFollowFrame.RegisterEvent, tFollowFrame, tEvent)
end
local tFollowActive, tFollowStart, tMoveFlips = false, 0, 0
local function tFollowSnap(aReason, aArg1)
	local tRange = "?"
	local tOk, tMax, tMin = pcall(function() return SkuOptions.RangeCheck:GetRange("target") end)
	if tOk and (tMax or tMin) then tRange = tostring(tMin or "?") .. "-" .. tostring(tMax or "?") end
	dprint("combatProbe", "FOLGEN", aReason, tostring(aArg1 or ""), "nach=" .. string.format("%.1f", tFollowActive and (GetTime() - tFollowStart) or 0) .. "s",
		"zielAbstand=" .. tRange, "ziel=" .. tYN(tSafe(UnitExists, "target")), "zielTot=" .. tYN(tSafe(UnitIsDead, "target")),
		"ichKampf=" .. tYN(tSafe(UnitAffectingCombat, "player")), "reittier=" .. tYN(tSafe(IsMounted)),
		"zauber=" .. (tSafe(UnitCastingInfo, "player") and "ja" or "nein"), "bewegungswechsel=" .. tMoveFlips,
		"letzteFehlermeldung=" .. tLastUiError .. " (vor " .. string.format("%.1f", GetTime() - tLastUiErrorAt) .. " s)")
end
tFollowFrame:SetScript("OnEvent", function(_, aEvent, aArg1, aArg2)
	if aEvent == "UI_ERROR_MESSAGE" then
		tLastUiError = (issecretvalue and issecretvalue(aArg2)) and "geheim" or tostring(aArg2)
		tLastUiErrorAt = GetTime()
		return
	end
	if aEvent == "AUTOFOLLOW_BEGIN" then tFollowActive, tFollowStart, tMoveFlips = true, GetTime(), 0 tFollowSnap(aEvent, aArg1) return end
	if aEvent == "AUTOFOLLOW_END" then tFollowSnap(aEvent) tFollowActive = false return end
	if not tFollowActive then return end
	if aEvent == "PLAYER_STARTED_MOVING" or aEvent == "PLAYER_STOPPED_MOVING" then tMoveFlips = tMoveFlips + 1 return end
	if (aEvent == "UNIT_SPELLCAST_START" or aEvent == "UNIT_SPELLCAST_STOP") and aArg1 ~= "player" then return end
	tFollowSnap(aEvent)
end)
