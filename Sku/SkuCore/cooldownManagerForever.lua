---------------------------------------------------------------------------------------------------------------------------------------
-- Cooldown manager settings window (CooldownViewerSettings, /cdm) on WoW Forever.
-- This is where the player decides which spells and auras the cooldown manager shows: Tracked Buffs and Tracked Bars
-- hold the auras that auraEnd.lua announces. The window is made of item frames in categories; the menu lists the tabs
-- (Spells, Auras), the categories and their items, and offers for each item the same moves as the item's own context
-- menu: Blizzard's CooldownViewerSettingsItemMixin:AssignToCategory with the categories from
-- CooldownViewerSettings:GetValidAssignmentCategories, checked by the layout manager's GetCooldownCategoryChangeStatus.
-- Not in the menu: search, the gear menu, layouts, alerts and the Group Buffs tab.
-- Changes made from addon code taint the cooldown viewers' data, which breaks their aura handling in combat until the
-- interface is reloaded (WowVision measured this in game and does the same: it asks for a reload). So every change says
-- so, and the menu has a Reload Interface entry.
-- Source: Blizzard_CooldownViewer (Retail 12.x); WowVision retail/cooldownManager.lua for what is worth operating.
---------------------------------------------------------------------------------------------------------------------------------------
if not Sku.isForever then return end

local L = Sku.L

local function tSay(aText)
	SkuOptions.Voice:OutputStringBTtts(aText, true, true, 0.2)
end

-- Entry in a list; a second label on the same level gets a number (otherwise one overwrites the other).
local function tAdd(aParentChilds, aLabel, aEntry)
	aLabel = SkuUtil:Unescape(tostring(aLabel or "?"))
	local tKey, tN = aLabel, 1
	while aParentChilds[tKey] do
		tN = tN + 1
		tKey = aLabel .. " #" .. tN
	end
	aEntry.textFirstLine = tKey
	table.insert(aParentChilds, tKey)
	aParentChilds[tKey] = aEntry
	return aEntry
end

local function tText(aParentChilds, aLabel)
	tAdd(aParentChilds, aLabel, {
		frameName = "CooldownViewerSettings",
		RoC = "Child",
		type = "Text",
		obj = CooldownViewerSettings,
		textFull = "",
		childs = {},
	})
end

local function tAction(aParentChilds, aLabel, aFunc, aIdentity)
	return tAdd(aParentChilds, aLabel, {
		frameName = "CooldownViewerSettingsAction",
		RoC = "Child",
		type = "Button",
		obj = CooldownViewerSettings,
		textFull = "",
		childs = {},
		func = aFunc,
		click = aFunc ~= nil,
		skuIdentity = aIdentity,
	})
end

local function tGroup(aParentChilds, aLabel, aIdentity)
	return tAdd(aParentChilds, aLabel, {
		frameName = "CooldownViewerSettingsGroup",
		RoC = "Child",
		type = "Button",
		obj = CooldownViewerSettings,
		textFull = "",
		childs = {},
		skuIdentity = aIdentity,
	})
end

local gChanged = false
local gHideHooked = false

local function tReloadHint()
	return Sku.deEn(
		"Änderungen gelten erst nach dem Neuladen der Oberfläche. Im Menü des Fensters gibt es den Eintrag Oberfläche neu laden.",
		"Changes only apply after the interface is reloaded. The window menu has an entry Reload interface.",
		"Les changements ne s'appliquent qu'après le rechargement de l'interface. Le menu de la fenêtre contient l'entrée Recharger l'interface.")
end

local function tMarkChanged()
	if not gChanged then
		gChanged = true
		tSay(tReloadHint())
	end
end

-- The game writes the layout when the settings window is hidden (CooldownViewerSettingsMixin:OnHide ->
-- CheckSaveCurrentLayout). A reload with the window still open, or a move never followed by closing it, lost the change
-- (measured 2026-11-09: after a reload the viewers' provider still had the old 7 entries). So save as the close would.
local function tSaveLayout()
	local tFrame = CooldownViewerSettings
	if tFrame and tFrame.CheckSaveCurrentLayout then
		tFrame:CheckSaveCurrentLayout()
	end
end

local function tReload()
	tSaveLayout()
	if C_UI and C_UI.Reload then
		C_UI.Reload()
	else
		ReloadUI()
	end
end

local function tActiveFrames(aPool)
	local tFrames = {}
	if aPool then
		for tFrame in aPool:EnumerateActive() do
			tFrames[#tFrames + 1] = tFrame
		end
	end
	return tFrames
end

local function tItemName(aItem)
	local tName = aItem.GetNameText and aItem:GetNameText()
	if type(tName) ~= "string" or tName == "" then
		local tInfo = aItem.GetCooldownInfo and aItem:GetCooldownInfo()
		local tSpellId = tInfo and (tInfo.overrideTooltipSpellID or tInfo.overrideSpellID or tInfo.spellID)
		tName = tSpellId and C_Spell.GetSpellName(tSpellId) or "?"
	end
	return tName
end

-- The sounds Sku ships (SkuCore.outputSoundFiles: key -> "aura;sound#name"), sorted by name once.
local gSoundList
local function tSoundList()
	if not gSoundList then
		gSoundList = {}
		for tKey, tFriendly in pairs(SkuCore.outputSoundFiles or {}) do
			-- full = the entry name the menu plays on hover (templates.lua OnEnter finds "aura;sound#<name>")
			gSoundList[#gSoundList + 1] = { key = tKey, full = tostring(tFriendly), name = tostring(tFriendly):match("#(.*)$") or tostring(tFriendly) }
		end
		table.sort(gSoundList, function(a, b) return a.name < b.name end)
	end
	return gSoundList
end

local function tSoundName(aKey)
	for _, tSound in ipairs(tSoundList()) do
		if tSound.key == aKey then return tSound.name end
	end
	return aKey
end

local function tPlaySample(aKey)
	SkuOptions.Voice:OutputString(aKey, true, true, 0.3, true)
end

-- "Sound when gone: <current>" with the list of sounds inside. Enter on a sound picks it and plays it once.
local function tSoundGroup(aParentChilds, aAuraName, aId)
	if not aAuraName or not SkuCore.AuraEnd then return end
	local tCurrent = SkuCore.AuraEnd:GetSound(aAuraName)
	local tLabel = Sku.deEn("Sound wenn weg", "Sound when gone", "Son quand disparue") .. ": "
		.. (tCurrent and tSoundName(tCurrent) or Sku.deEn("keiner, Name wird gesprochen", "none, name is spoken", "aucun, le nom est dit"))
	local tAlso = SkuCore.AuraEnd:GetAlsoSpeak(aAuraName)
	tLabel = tLabel .. (tCurrent and (", " .. Sku.deEn("Name zusätzlich", "name too", "nom aussi") .. " " .. (tAlso and Sku.deEn("an", "on", "oui") or Sku.deEn("aus", "off", "non"))) or "")
	local tGroupEntry = tGroup(aParentChilds, tLabel, "cdmsound:" .. tostring(aId))
	tAction(tGroupEntry.childs, Sku.deEn("Name zusätzlich zum Sound sprechen", "Also speak the name after the sound", "Dire aussi le nom après le son")
		.. ": " .. (tAlso and Sku.deEn("an", "on", "oui") or Sku.deEn("aus", "off", "non")), function()
		SkuCore.AuraEnd:SetAlsoSpeak(aAuraName, not tAlso)
		tSay(not tAlso and Sku.deEn("Name wird zusätzlich gesprochen", "Name is spoken too", "Le nom est dit aussi")
			or Sku.deEn("Nur der Sound", "Sound only", "Son seulement"))
	end)
	tAction(tGroupEntry.childs, Sku.deEn("Kein Sound, Name sprechen", "No sound, speak the name", "Pas de son, dire le nom"), function()
		SkuCore.AuraEnd:SetSound(aAuraName, nil)
		tSay(Sku.deEn("Name wird gesprochen", "Name is spoken", "Le nom est dit"))
	end)
	for _, tSound in ipairs(tSoundList()) do
		local tKey = tSound.key
		-- Named like Sku's own sound list ("aura;sound#brass 1"): the menu plays it when the cursor lands on it. Enter
		-- only confirms the pick. A plain action (no click), so the entry keeps the menu's own OnEnter.
		tAdd(tGroupEntry.childs, tSound.full, {
			frameName = "CooldownViewerSettingsAction",
			RoC = "Child",
			type = "Button",
			obj = CooldownViewerSettings,
			textFull = "",
			childs = {},
			func = function()
				SkuCore.AuraEnd:SetSound(aAuraName, tKey)
				tSay(Sku.deEn("Gewählt", "Chosen", "Choisi"))
			end,
		})
	end
end

-- One item: its name (the moves are inside) and what the game says about it.
local function tItem(aParentChilds, aFrame, aItem)
	local tLabel = tItemName(aItem)
	if aItem.IsKnown and not aItem:IsKnown() then
		tLabel = tLabel .. ", " .. Sku.deEn("nicht gelernt", "not learned", "non appris")
	end
	local tId = aItem:GetCooldownID()
	local tEntry = tGroup(aParentChilds, tLabel, "cdmitem:" .. tostring(tId))

	local tLayout = aFrame:GetLayoutManager()
	local tCategories = aFrame:GetValidAssignmentCategories(aItem)
	for _, tCategory in ipairs(tCategories) do
		local tMoveLabel = tCategory:GetCategoryAssignmentText()
		local tStatus = tLayout and tLayout:GetCooldownCategoryChangeStatus(tId, tCategory:GetCategory())
		if tStatus == (Enum.CooldownLayoutStatus and Enum.CooldownLayoutStatus.Success) then
			tAction(tEntry.childs, tMoveLabel, function()
				-- Die Viewer (BuffIcon u.a.) brauchen die neue Sicht erst nach dem Neuladen. Live aktualisieren
				-- liefe unter Sku-Taint und wirft Fehler (secret/forbidden). Darum die Meldung "Daten geaendert"
				-- an die Viewer sperren; das Einstellungsfenster zeichnet sich selbst neu.
				local tLayout = CooldownViewerSettings and CooldownViewerSettings.GetLayoutManager
					and CooldownViewerSettings:GetLayoutManager()
				if tLayout and tLayout.LockNotifications then tLayout:LockNotifications() end
				aItem:AssignToCategory(tCategory)
				tSaveLayout()
				if tLayout and tLayout.UnlockNotifications then
					tLayout.needsNotificationAfterUnlock = false
					tLayout:UnlockNotifications()
				end
				tSay(Sku.deEn("Verschoben", "Moved", "Déplacé"))
				tMarkChanged()
			end)
		else
			tAction(tEntry.childs, tMoveLabel .. ", " .. Sku.deEn("nicht möglich", "not possible", "impossible"), nil)
		end
	end
	if #tEntry.childs == 0 then
		tText(tEntry.childs, "Text: " .. Sku.deEn("Keine Verschiebung möglich", "No move possible", "Aucun déplacement possible"))
	end

	-- the sound for "this aura is gone" (auraEnd.lua): without one the name is spoken
	local tAuraName = SkuCore.AuraEnd and SkuCore.AuraEnd:NameFromInfo(aItem.GetCooldownInfo and aItem:GetCooldownInfo()) or tItemName(aItem)
	tSoundGroup(tEntry.childs, tAuraName, tId)
end

local function tCategory(aParentChilds, aFrame, aCategory)
	local tObject = aCategory:GetCategoryObject()
	local tTitle = tObject and tObject:GetTitle() or "?"
	local tKey = tostring(tObject and tObject:GetCategory())
	local tEntry = tGroup(aParentChilds, tTitle, "cdmcat:" .. tKey)

	dprint("cdm category", tTitle, tKey, aCategory:IsCollapsed() and "collapsed" or "open", "mode", tostring(aFrame.displayMode))
	if aCategory:IsCollapsed() then
		tAction(tEntry.childs, Sku.deEn("Ausgeklappt anzeigen", "Expand", "Déplier"), function()
			aCategory:ToggleCollapsed()
		end)
		return
	end

	local tItems = tActiveFrames(aCategory.itemPool)
	table.sort(tItems, function(a, b) return (a:GetOrderIndex() or 0) < (b:GetOrderIndex() or 0) end)
	local tCount = 0
	for _, tItemFrame in ipairs(tItems) do
		if not tItemFrame:IsEmptyCategory() then
			dprint("cdm item", tTitle, tItemName(tItemFrame))
			tItem(tEntry.childs, aFrame, tItemFrame)
			tCount = tCount + 1
		end
	end
	dprint("cdm category items", tTitle, tCount)
	if tCount == 0 then
		tText(tEntry.childs, "Text: " .. Sku.deEn("Leer", "Empty", "Vide"))
	end
end

function SkuCore:Build_CooldownViewerSettings(aParentChilds)
	local tFrame = CooldownViewerSettings

	if not gHideHooked then
		gHideHooked = true
		tFrame:HookScript("OnHide", function()
			if gChanged then tSay(tReloadHint()) end
		end)
	end

	-- tabs (Group Buffs is left out)
	for _, tTab in ipairs(tFrame.TabButtons or {}) do
		if tTab:IsShown() and tTab.displayMode ~= "groupBuffs" and not tTab.isTabDisabled then
			local tLabel = L["Tab"] .. " " .. tostring(tTab.normalTooltipText or tTab.tooltipText or tTab.displayMode)
			local tSelected = (tFrame.displayMode == tTab.displayMode)
			if tSelected then tLabel = tLabel .. " (" .. L["selected"] .. ")" end
			local tMode = tTab.displayMode
			tAction(aParentChilds, tLabel, (not tSelected) and function() tFrame:SetDisplayMode(tMode) end or nil, "cdmtab:" .. tostring(tMode))
		end
	end

	-- categories, top to bottom as the window draws them
	if tFrame.displayMode ~= "groupBuffs" then
		local tCategories = tActiveFrames(tFrame.categoryPool)
		table.sort(tCategories, function(a, b) return (a:GetTop() or 0) > (b:GetTop() or 0) end)
		for _, tCategoryFrame in ipairs(tCategories) do
			tCategory(aParentChilds, tFrame, tCategoryFrame)
		end
	end

	if tFrame.UndoButton and tFrame.UndoButton:IsShown() then
		tAction(aParentChilds, Sku.deEn("Änderungen zurücknehmen", "Revert changes", "Annuler les changements"), function()
			tFrame.UndoButton:Click()
		end)
	end
	tAction(aParentChilds, Sku.deEn("Oberfläche neu laden", "Reload interface", "Recharger l'interface"), tReload)
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Root menu entry "Cooldown Manager": opens the settings window (what /cdm does), whose menu is built above. The window
-- lives in Blizzard_CooldownViewer, loaded on demand if it is not there yet.
local function tOpenWindow()
	if not CooldownViewerSettings and C_AddOns and C_AddOns.LoadAddOn then
		C_AddOns.LoadAddOn("Blizzard_CooldownViewer")
	end
	if not CooldownViewerSettings then
		tSay(Sku.deEn("Der Cooldown Manager ist nicht verfügbar", "The cooldown manager is not available", "Le gestionnaire de recharge n'est pas disponible"))
		return
	end
	SkuOptions:CloseMenu()
	-- a frame later: the menu has to be closed before the window is up, or the window menu is built under it
	C_Timer.After(0.1, function()
		if not CooldownViewerSettings:IsVisible() then
			CooldownViewerSettings:ShowUIPanel()
		end
	end)
end

SkuMenu:RegisterModule("CooldownManager", {
	label = function() return Sku.deEn("Cooldown Manager", "Cooldown manager", "Gestionnaire de recharge") end,
	build = function(entry)
		local tOpen = SkuOptions:InjectMenuItems(entry, {Sku.deEn("Fenster öffnen", "Open window", "Ouvrir la fenêtre")}, SkuGenericMenuItem)
		tOpen.OnAction = function() tOpenWindow() end

		-- the game's switch for the whole cooldown manager (CVar cooldownViewerEnabled)
		if SkuCore.AuraEnd then
			local tOn = SkuCore.AuraEnd:IsViewerEnabled()
			local tSwitch = SkuOptions:InjectMenuItems(entry, {Sku.deEn("Cooldown Manager ist ", "Cooldown manager is ", "Le gestionnaire de recharge est ")
				.. (tOn and Sku.deEn("an", "on", "activé") or Sku.deEn("aus", "off", "désactivé"))
				.. ", " .. Sku.deEn("Enter schaltet um", "Enter switches", "Entrée bascule")}, SkuGenericMenuItem)
			tSwitch.OnAction = function()
				local tNow = SkuCore.AuraEnd:IsViewerEnabled()
				if InCombatLockdown() then
					tSay(Sku.deEn("Im Kampf nicht möglich", "Not possible in combat", "Impossible en combat"))
					return
				end
				if SkuCore.AuraEnd:SetViewerEnabled(not tNow) then
					tSay(not tNow and Sku.deEn("Cooldown Manager an", "Cooldown manager on", "Gestionnaire activé")
						or Sku.deEn("Cooldown Manager aus", "Cooldown manager off", "Gestionnaire désactivé"))
				else
					tSay(Sku.deEn("Das Spiel erlaubt es gerade nicht", "The game does not allow it right now", "Le jeu ne le permet pas pour l'instant"))
				end
			end
		end
	end,
})

-- in the root menu just before Einstellungen
for tIndex, tId in ipairs(SkuMenu.rootLayout) do
	if tId == "Einstellungen" then
		table.insert(SkuMenu.rootLayout, tIndex, "CooldownManager")
		break
	end
end
