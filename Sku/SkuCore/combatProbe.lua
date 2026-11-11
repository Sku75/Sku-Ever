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
	if type(py) ~= "number" or type(qy) ~= "number" then return "?" end
	return string.format("%.0f", math.sqrt((px - qx) ^ 2 + (py - qy) ^ 2))
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
	"PLAYER_FOCUS_CHANGED", "PET_ATTACK_START", "PET_ATTACK_STOP", "UNIT_PET", "PLAYER_UNGHOST" }) do
	pcall(tFrame.RegisterEvent, tFrame, tEvent)
end
tFrame:SetScript("OnEvent", function(_, aEvent)
	tSnapshot(aEvent)
end)

C_Timer.NewTicker(0.5, function()
	tSnapshot("tick")
end)
