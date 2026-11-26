local MODULE_NAME = "SkuMob"
local L = Sku.L
local PetAbandon = Sku.Compat.PetAbandon
local PetRename = Sku.Compat.PetRename
local LeaveParty = Sku.Compat.LeaveParty

SkuMob.InCombatSounds = {
	["Interface\\AddOns\\Sku\\SkuMob\\assets\\Target_in_combat_low.mp3"] = L["Default beep sound"],
}

SkuMob.options = {
	name = MODULE_NAME,
	type = "group",
	-- W2-MC1: per-key storage get/set removed — these nodes are schema-managed.
	-- The menu reads/writes via SkuSettings:Get/Set("SkuMob", key); scope/type/
	-- default come from the SkuSettings:Register schema below. Re-add get/set on a
	-- node ONLY if it needs a side effect (it then uses the inline handler again).
	-- Monitor, Ziel Ansage, Weitere Zieloptionen (SkuMob.TA:MenuBuilder below), in this order. What a target announcement
	-- says (name, level, class ...) is no longer set here but per kind of unit in SkuMob.TA.
	args = {
		InCombatSound={
			name = L["Sound if target is in combat"],
			order = 1,
			desc = "",
			type = "select",
			values = SkuMob.InCombatSounds,
		},
		autoSetSkuRaidTargetsToInCombatCreatures = {
			name = L["Auto set private Sku raid targets on in combat targets without a raid target"],
			order = 2,
			desc = "",
			type = "toggle",
		},
		vocalizeRaidTargetOnly = {
			name = L["Only raid icon for targets with icon"],
			order = 3,
			desc = "",
			type = "toggle",
		},
		repeatRaidTargetMarkers = {
			name = L["Repeat raid target markers on units"],
			order = 4,
			desc = "",
			type = "toggle",
		},
		-- you, your pet and group members by their role ("du selbst", "dein begleiter", "party 2") instead of their name
		genericNames = {
			name = Sku.deEn("Generische Namen", "Generic names", "Noms génériques"),
			order = 5,
			desc = "",
			type = "toggle",
		},
	}
}
---------------------------------------------------------------------------------------------------------------------------------------
SkuMob.defaults = {
	enable = true,
	vocalizeRaidTargetOnly = false,
	dontVocalizePlayerReactionAndLevelInCombat = true,
	vocalizePlayerNamePlaceholders = true,
	vocalizePlayerNamePlaceholdersSkuTts = false,
	repeatRaidTargetMarkers = true,
	autoSetSkuRaidTargetsToInCombatCreatures = true,
	InCombatSound = "Interface\\AddOns\\Sku\\SkuMob\\assets\\Target_in_combat_low.mp3",	
}

-- Settings schema for SkuMob (Sku 42 rework, W1 Phase B). All keys profile
-- scope. Declared here as the single source of truth (scope/default/type) for
-- W2 menu generation and future Get/Set use; SkuMob's own access currently runs
-- through SkuSettings:Sub (see Core.lua and the option handlers above).
SkuSettings:Register("SkuMob", {
	["enable"]                                     = { scope = "profile", default = true,  type = "boolean" },
	["vocalizeRaidTargetOnly"]                     = { scope = "profile", default = false, type = "boolean" },
	["dontVocalizePlayerReactionAndLevelInCombat"] = { scope = "profile", default = true,  type = "boolean" },
	["vocalizePlayerNamePlaceholders"]             = { scope = "profile", default = true,  type = "boolean" },
	["vocalizePlayerNamePlaceholdersSkuTts"]       = { scope = "profile", default = false, type = "boolean" },
	["repeatRaidTargetMarkers"]                    = { scope = "profile", default = true,  type = "boolean" },
	["autoSetSkuRaidTargetsToInCombatCreatures"]   = { scope = "profile", default = true , type = "boolean" },
	["InCombatSound"]                              = { scope = "profile", default = "Interface\\AddOns\\Sku\\SkuMob\\assets\\Target_in_combat_low.mp3", type = "string" },
	["enemyCombatStatusMode"]                      = { scope = "profile", default = "beep", type = "string" },
	["genericNames"]                               = { scope = "profile", default = false, type = "boolean" },
	["blizzardTargetNameAuto"]                    = { scope = "profile", default = true,  type = "boolean" },
	["blizzardTargetNameOriginal"]                = { scope = "profile", default = "", type = "string" },
})
---------------------------------------------------------------------------------------------------------------------------------------
-- =========================================================================
-- ALTER TARGET-MENÜ-CODE (auskommentiert, Backup-Stand vor Neuaufbau)
-- =========================================================================
-- Funktioniert auf Anniversary 2.5.5 nicht zuverlässig:
--   * Hook auf MenuUtil.CreateContextMenu greift nicht, weil das
--     klassische Target-Dropdown über ToggleDropDownMenu/DropDownList1
--     läuft (nicht über das moderne Retail-MenuUtil).
--   * Funktionen wie "Instanzen zurücksetzen" feuern nicht, weil die
--     UIDropDownMenu-Buttons globalen State (UIDROPDOWNMENU_*) lesen,
--     den nur der echte Mausklick setzt.
--   * Das DropDownList1-Frame schließt nicht zuverlässig → Menü taucht
--     immer wieder auf.
-- Wir bauen das Target-Menü darum komplett neu mit direkten WoW-API-
-- Aufrufen. Falls die Neufassung Probleme macht, einfach diesen Block
-- wieder aktivieren und den neuen unten auskommentieren.
--[[
function SkuMob:MenuBuilder(aParentEntry)
	--dprint("SkuMob:MenuBuilder", aParentEntry)
	local tNewSubMenuEntry = SkuOptions:InjectMenuItems(aParentEntry, {L["Target menu"]}, SkuGenericMenuItem)
	if _G["TargetFrame"] then
		tNewSubMenuEntry.macrotext = "/click TargetFrame RightButton"
	end

	local tNewMenuEntry =  SkuOptions:InjectMenuItems(aParentEntry, {L["Options"]}, SkuGenericMenuItem)
	tNewMenuEntry.sorting = true
	SkuOptions:IterateOptionsArgs(SkuMob.options.args, tNewMenuEntry, SkuSettings:Sub("SkuMob"))
end

---------------------------------------------------------------------------------------------------------------------------------------
--hook CreateContextMenu to get notified
local thooked = MenuUtil.CreateContextMenu
local function hooknew(a, b, c, d)
	--print("CreateContextMenu", a, b, c, d)
	C_Timer.After(0.1, function()
		SkuMob:CreateAndUpdateSkuMenuFrame()
	end)
	local result = thooked(a, b, c, d)
	return result
end
MenuUtil.CreateContextMenu = hooknew

---------------------------------------------------------------------------------------------------------------------------------------
-- build SABs to be mapped to unnamed menu entries to reference them by a name
function SkuMob:CreateAndUpdateSkuMenuFrame()
	if SkuState:IsInCombat() == true then
		return
	end

	if not _G["SkuMenuFrame"] then
		local tSkuMenuFrame = CreateFrame("Button", "SkuMenuFrame", _G["UIParent"])
		tSkuMenuFrame:SetPoint("CENTER", _G["UIParent"], "CENTER")
		tSkuMenuFrame:SetSize(0, 0)
		tSkuMenuFrame:Hide()

		for x = 1, 100 do
			local tFrame = CreateFrame("Button", "SkuCoreSecureMenuButton"..x, tSkuMenuFrame, "SecureActionButtonTemplate, UIPanelButtonTemplate")
			tFrame:SetAttribute("type", "click")
			tFrame:SetAttribute("clickbutton", nil)
			tFrame:RegisterForClicks("AnyUp", "AnyDown")
			tFrame:SetPoint("CENTER", _G["SkuMenuFrame"], "CENTER", 0, -(x * 20))
			tFrame:SetSize(0, 0)
			tFrame:SetText("")
			tFrame:RegisterForClicks("AnyDown", "AnyUp")
			tFrame:Hide()
		end
	end

	if _G["SkuMenuFrame"]:IsShown() then
		_G["SkuMenuFrame"]:Hide()
	end
	for x = 1, 100 do
		if _G["SkuCoreSecureMenuButton"..x]:IsShown() then
			_G["SkuCoreSecureMenuButton"..x]:Hide()
		end
	end

	if not Menu.GetManager() then
		return
	end
	if not Menu.GetManager():GetOpenMenu() then
		return
	end
	if not Menu.GetManager():GetOpenMenu():GetLayoutChildren() then
		return
	end

	local counter = 1
	for i, child in ipairs(Menu.GetManager():GetOpenMenu():GetLayoutChildren()) do
		if child.frameTemplateOrFrameType == "Button" then
			if child.fontString then
				if child.fontString.GetText then
					_G["SkuMenuFrame"]:Show()
					local tFrame = _G["SkuCoreSecureMenuButton"..counter]
					tFrame:SetAttribute("type", "click")
					tFrame:SetAttribute("clickbutton", child)
					tFrame:SetText(child.fontString:GetText())
					tFrame:Show()
					counter = counter + 1
				end
			end
		end
	end
end
]]

-- =========================================================================
-- NEUES TARGET-MENÜ (direkter WoW-API-Aufruf)
-- =========================================================================

-- Stub für CreateAndUpdateSkuMenuFrame: SkuCore:CheckFrames() ruft sie
-- jeden Tick auf. Wir lassen die Signatur stehen, machen aber nichts.
function SkuMob:CreateAndUpdateSkuMenuFrame()
	-- intentionally empty: alter Retail-Mirror-Pfad ist abgeschaltet.
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------------------------------------------------------------------
local function tSay(aText)
	if SkuOptions and SkuOptions.Voice and SkuOptions.Voice.OutputStringBTtts then
		pcall(function()
			SkuOptions.Voice:OutputStringBTtts(aText, true, true, 0.2, nil, nil, nil, 2)
		end)
	end
end

-- Aufruf einer ggf. fehlenden Globalen — TBC- vs. Modern-API-Wechsel
-- abfangen. Wenn eine Funktion existiert, mit den Args aufrufen,
-- sonst nil zurückgeben (kein Fehler).
local function tCall(aFn, ...)
	if type(aFn) == "function" then
		local ok, r = pcall(aFn, ...)
		if ok then return r end
	end
	return nil
end

-- Vereinheitlichter Action-Eintrag.
local function tAddAction(aParent, aLabel, aFunc, aTooltip)
	local tEntry = SkuOptions:InjectMenuItems(aParent, {aLabel}, SkuGenericMenuItem)
	tEntry.sorting = true
	if aTooltip then tEntry.textFull = aTooltip end
	tEntry.OnAction = function()
		pcall(aFunc)
	end
	return tEntry
end

local function tInGroup()
	if _G.IsInGroup then return IsInGroup() end
	if _G.GetNumPartyMembers then return GetNumPartyMembers() > 0 end
	return false
end

local function tIsLeader()
	if _G.UnitIsGroupLeader then return UnitIsGroupLeader("player") end
	if _G.IsPartyLeader then return IsPartyLeader() == 1 end
	return false
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Raid-Marker-Untermenü.
---------------------------------------------------------------------------------------------------------------------------------------
local tRaidMarkers = {
	[0] = L["MOB_MarkerRemove"],
	[1] = L["MOB_MarkerStar"],
	[2] = L["MOB_MarkerCircle"],
	[3] = L["MOB_MarkerDiamond"],
	[4] = L["MOB_MarkerTriangle"],
	[5] = L["MOB_MarkerMoon"],
	[6] = L["MOB_MarkerSquare"],
	[7] = L["MOB_MarkerCross"],
	[8] = L["MOB_MarkerSkull"],
}

local function tBuildRaidMarkerSubmenu(aParent, aUnit)
	local tEntry = SkuOptions:InjectMenuItems(aParent, {L["MOB_SetMarker"]}, SkuGenericMenuItem)
	tEntry.sorting = true
	tEntry.dynamic = true
	tEntry.BuildChildren = function(self)
		for i = 0, 8 do
			tAddAction(self, tRaidMarkers[i], function()
				tCall(_G.SetRaidTarget, aUnit, i)
				tSay(tRaidMarkers[i])
			end)
		end
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Melden-Submenü (Report).
---------------------------------------------------------------------------------------------------------------------------------------
local tReportReasons = {
	{ label = L["MOB_ReportSpam"],       type = "spam"   },
	{ label = L["MOB_ReportLanguage"],   type = "language" },
	{ label = L["MOB_ReportSexual"],     type = "sexual" },
	{ label = L["MOB_ReportHarassment"], type = "harassment" },
	{ label = L["MOB_ReportCheating"],   type = "cheating" },
	{ label = L["MOB_ReportBadName"],    type = "name" },
}

local function tBuildReportSubmenu(aParent)
	local tEntry = SkuOptions:InjectMenuItems(aParent, {L["MOB_ReportPlayer"]}, SkuGenericMenuItem)
	tEntry.sorting = true
	tEntry.dynamic = true
	tEntry.BuildChildren = function(self)
		for _, r in ipairs(tReportReasons) do
			tAddAction(self, r.label, function()
				tCall(_G.ReportPlayer, r.type, "target")
				tSay(L["MOB_ReportSent"] .. r.label)
			end, L["MOB_ReportTooltip"] .. r.label)
		end
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Plündermethode-Submenü (nur für Anführer).
---------------------------------------------------------------------------------------------------------------------------------------
local tLootMethods = {
	{ label = L["MOB_LootFFA"],        method = "freeforall" },
	{ label = L["MOB_LootRoundRobin"], method = "roundrobin" },
	{ label = L["MOB_LootNBG"],        method = "needbeforegreed" },
	{ label = L["MOB_LootGroup"],      method = "group" },
	{ label = L["MOB_LootMaster"],     method = "master" },
}

local function tBuildLootMethodSubmenu(aParent)
	local tEntry = SkuOptions:InjectMenuItems(aParent, {L["MOB_LootMethod"]}, SkuGenericMenuItem)
	tEntry.sorting = true
	tEntry.dynamic = true
	tEntry.BuildChildren = function(self)
		for _, lm in ipairs(tLootMethods) do
			tAddAction(self, lm.label, function()
				tCall(_G.SetLootMethod, lm.method, UnitName("player"))
				tSay(L["MOB_LootMethodSet"] .. lm.label)
			end)
		end
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Pet-Modus-Submenü.
---------------------------------------------------------------------------------------------------------------------------------------
local function tBuildPetModeSubmenu(aParent)
	local tEntry = SkuOptions:InjectMenuItems(aParent, {L["MOB_PetMode"]}, SkuGenericMenuItem)
	tEntry.sorting = true
	tEntry.dynamic = true
	tEntry.BuildChildren = function(self)
		tAddAction(self, L["MOB_PetAggressive"], function()
			tCall(_G.PetAggressiveMode)
			tSay(L["MOB_PetSetAggressive"])
		end)
		tAddAction(self, L["MOB_PetDefensive"], function()
			tCall(_G.PetDefensiveMode)
			tSay(L["MOB_PetSetDefensive"])
		end)
		tAddAction(self, L["MOB_PetPassive"], function()
			tCall(_G.PetPassiveMode)
			tSay(L["MOB_PetSetPassive"])
		end)
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Hauptbuilder: Aktionen je nach Ziel.
---------------------------------------------------------------------------------------------------------------------------------------
local function tBuildTargetMenu(aParent)
	local tHasTarget  = UnitExists("target") and true or false
	local tIsSelf     = tHasTarget and UnitIsUnit("target", "player")
	local tIsPlayer   = tHasTarget and UnitIsPlayer("target")
	local tIsPet      = tHasTarget and UnitIsUnit("target", "pet")

	-- =========================================================
	-- ZWEIG 1: Anderer Spieler im Ziel
	-- =========================================================
	if tHasTarget and not tIsSelf and tIsPlayer then
		tAddAction(aParent, L["MOB_Inspect"],
			function() tCall(_G.InspectUnit, "target") end,
			L["MOB_InspectTip"])

		tAddAction(aParent, L["MOB_Follow"],
			function() tCall(_G.FollowUnit, "target") end,
			L["MOB_FollowTip"])

		tAddAction(aParent, L["MOB_Trade"],
			function() tCall(_G.InitiateTrade, "target") end,
			L["MOB_TradeTip"])

		tAddAction(aParent, L["MOB_Duel"],
			function() tCall(_G.StartDuel, "target") end,
			L["MOB_DuelTip"])

		tAddAction(aParent, L["MOB_Whisper"], function()
			local n = UnitName("target")
			-- ChatFrame_OpenChat is a deprecated alias (nil with loadDeprecationFallbacks off).
			local tOpen = (_G.ChatFrameUtil and ChatFrameUtil.OpenChat) or _G.ChatFrame_OpenChat
			if n and tOpen then
				tOpen("/w " .. n .. " ")
			end
		end, L["MOB_WhisperTip"])

		tAddAction(aParent, L["MOB_InviteToGroup"], function()
			local n = UnitName("target")
			if not n then return end
			if _G.C_PartyInfo and _G.C_PartyInfo.InviteUnit then
				_G.C_PartyInfo.InviteUnit(n)
			elseif _G.InviteUnit then
				InviteUnit(n)
			end
			tSay(n .. L["MOB_Invited"])
		end, L["MOB_InviteToGroupTip"])

		if Sku.isForever and SkuCore and SkuCore.Friends and SkuCore.Friends.FriendRequestMacro then
			-- Forever: the old character friend list is off, a friend is a Battle.net request (friends.lua, Friends.FriendRequestMacro).
			-- The request goes out as a secure macro on a second Enter, so opening the submenu sends nothing.
			local tAddF = SkuOptions:InjectMenuItems(aParent, {Sku.deEn("Freundschaftsanfrage senden", "send friend request", "envoyer une demande d'ami")}, SkuGenericMenuItem)
			tAddF.sorting = true
			tAddF.textFull = Sku.deEn("Schickt dem Ziel eine Freundschaftsanfrage über Battle.net. Die Person muss sie annehmen.", "Sends the target a friend request through Battle.net. They have to accept it.", "Envoie une demande d'ami à la cible par Battle.net. Elle doit l'accepter.")
			tAddF.dynamic = true
			tAddF.BuildChildren = function(self)
				local tN, tRealm = UnitName("target")
				if type(tN) == "string" and type(tRealm) == "string" and tRealm ~= "" then tN = tN .. "-" .. tRealm end
				local tOk, tMacro, tClean = pcall(SkuCore.Friends.FriendRequestMacro, tN)
				if not tOk or not tMacro then
					SkuOptions:InjectMenuItems(self, {Sku.deEn("Name des Ziels nicht lesbar", "target name not readable", "nom de la cible illisible")}, SkuGenericMenuItem)
					return
				end
				local tYes = SkuOptions:InjectMenuItems(self, {Sku.deEn("Anfrage senden an: ", "send request to: ", "envoyer la demande à : ") .. tClean}, SkuGenericMenuItem)
				tYes.sorting = true
				tYes.macrotext = tMacro
				tYes.secureMacro = true
				tYes.OnAction = function()
					tSay(Sku.deEn("Freundschaftsanfrage gesendet", "friend request sent", "demande d'ami envoyée"))
				end
			end
		else
		tAddAction(aParent, L["MOB_AddFriend"], function()
			local n = UnitName("target")
			if not n then return end
			if _G.C_FriendList and _G.C_FriendList.AddFriend then
				_G.C_FriendList.AddFriend(n)
			elseif _G.AddFriend then
				AddFriend(n)
			end
			tSay(n .. L["MOB_FriendAdded"])
		end, L["MOB_AddFriendTip"])
		end

		tAddAction(aParent, L["MOB_ToggleIgnore"], function()
			local n = UnitName("target")
			if not n then return end
			if _G.C_FriendList and _G.C_FriendList.AddOrDelIgnore then
				_G.C_FriendList.AddOrDelIgnore(n)
			elseif _G.AddOrDelIgnore then
				AddOrDelIgnore(n)
			end
			tSay(n .. L["MOB_IgnoreToggled"])
		end, L["MOB_ToggleIgnoreTip"])

		-- Anführer-Aktionen
		if tIsLeader() and (UnitInParty("target") or UnitInRaid("target")) then
			tAddAction(aParent, L["MOB_PromoteLeader"],
				function() tCall(_G.PromoteToLeader, "target") end,
				L["MOB_PromoteLeaderTip"])

			tAddAction(aParent, L["MOB_RemoveFromGroup"], function()
				if _G.UninviteUnit then
					UninviteUnit(UnitName("target"))
					tSay(UnitName("target") .. L["MOB_Removed"])
				end
			end, L["MOB_RemoveFromGroupTip"])
		end

		tBuildReportSubmenu(aParent)
		tBuildRaidMarkerSubmenu(aParent, "target")
	end

	-- =========================================================
	-- ZWEIG 2: Eigenes Pet im Ziel
	-- =========================================================
	if tIsPet then
		local _, tPlayerClass = UnitClass("player")

		if tPlayerClass == "HUNTER" then
			-- ===================== JAEGER-PET =====================
			tAddAction(aParent, L["MOB_PetAttack"],
				function() tCall(_G.PetAttack) end,
				L["MOB_PetAttackTip"])

			tAddAction(aParent, L["MOB_PetRecall"],
				function() tCall(_G.PetFollow) end,
				L["MOB_PetRecallTip"])

			-- PetDismiss: macrotext (ADDON_ACTION_FORBIDDEN-Fix)
			do
				local tEntry = SkuOptions:InjectMenuItems(aParent, {L["MOB_PetDismiss"]}, SkuGenericMenuItem)
				tEntry.sorting = true
				tEntry.textFull = L["MOB_PetDismissTip"]
				tEntry.macrotext = "/petdismiss"
				tEntry.secureMacro = true
				tEntry.OnAction = function()
					tSay(L["MOB_PetDismissed"])
				end
			end

			-- PetRelease: Sicherheitsabfrage (PetAbandon ist PERMANENT!)
			-- Forever: C_PetInfo.PetAbandon() called from Sku code or from Sku clicking Blizzard's RELEASE_PET popup does
			-- nothing, but the same call from a secure macro works (confirmed 09.11.2026; it failed only for a quest pet,
			-- which the game does not release). So: submenu with a cancel entry and the macro entry, and an honest
			-- spoken result a moment later.
			if Sku.isForever and _G.C_PetInfo and _G.C_PetInfo.PetAbandon then
				local tRel = SkuOptions:InjectMenuItems(aParent, {L["MOB_PetRelease"]}, SkuGenericMenuItem)
				tRel.sorting = true
				tRel.textFull = L["MOB_PetReleaseTip"]
				tRel.dynamic = true
				tRel.BuildChildren = function(self)
					tAddAction(self, L["MOB_PetReleaseCancel"], function()
						tSay(L["EQ_Cancelled"] or "")
					end, L["MOB_PetReleaseWarning"])
					local tYes = SkuOptions:InjectMenuItems(self, {L["MOB_PetReleaseYes"]}, SkuGenericMenuItem)
					tYes.sorting = true
					tYes.textFull = L["MOB_PetReleaseWarning"]
					tYes.macrotext = "/run C_PetInfo.PetAbandon()"
					tYes.secureMacro = true
					tYes.OnAction = function()
						local tHadPet = UnitExists("pet")
						C_Timer.After(2, function()
							if not tHadPet then
								return
							end
							if UnitExists("pet") then
								dprint("SkuMob PetAbandon: secure macro, pet still there")
								tSay(L["MOB_PetReleaseFailed"])
							else
								dprint("SkuMob PetAbandon: secure macro, pet gone")
								tSay(L["MOB_PetReleased"])
							end
						end)
					end
				end
			else
			tAddAction(aParent, L["MOB_PetRelease"], function()
				if not SkuCore or not SkuCore.ConfirmButtonShow then
					tSay(L["MOB_PetReleaseTip"])
					return
				end
				local tPrompt = L["MOB_PetReleaseWarning"]
				SkuCore:ConfirmButtonShow(
					tPrompt,
					function()
						-- Do not claim success blindly: on Forever the call can return without doing anything, so
						-- check whether the pet is really gone and, if not, retry with the pet's own number
						-- (what Blizzard's stable window passes) before telling the user it failed.
						local tPetName = UnitName("pet")
						PetAbandon()
						C_Timer.After(1.5, function()
							if not UnitExists("pet") then
								tSay(L["MOB_PetReleased"])
								return
							end
							local tNumber
							if tPetName and C_StableInfo and C_StableInfo.GetActivePetList then
								for _, tInfo in ipairs(C_StableInfo.GetActivePetList() or {}) do
									if tInfo.name == tPetName then
										tNumber = tInfo.petNumber
										break
									end
								end
							end
							dprint("SkuMob PetAbandon: pet still there, retry with petNumber", tNumber)
							if tNumber then
								PetAbandon(tNumber)
							end
							C_Timer.After(1.5, function()
								if UnitExists("pet") then
									dprint("SkuMob PetAbandon: pet still there after retry")
									tSay(L["MOB_PetReleaseFailed"])
								else
									tSay(L["MOB_PetReleased"])
								end
							end)
						end)
					end,
					function()
						tSay(L["EQ_Cancelled"] or "")
					end)
				if _G.C_Timer and _G.C_Timer.After
					and SkuOptions and SkuOptions.Voice
					and SkuOptions.Voice.OutputStringBTtts then
					_G.C_Timer.After(0.5, function()
						pcall(function()
							SkuOptions.Voice:OutputStringBTtts(
								tPrompt, true, true, 0.1, nil, nil, nil, 2)
						end)
					end)
				end
			end, L["MOB_PetReleaseTip"])
			end

			-- PetRename
			tAddAction(aParent, L["MOB_PetRename"], function()
				SkuOptions:CloseMenu()
				C_Timer.After(0.3, function()
					SkuOptions:EditBoxShow("", function(self)
						local newName = self:GetText()
						if newName and newName ~= "" then
							local tSafeName = newName:gsub('["\\\r\n]', '')
							local ok = pcall(PetRename, tSafeName)
							if ok then
								SkuOptions.Voice:OutputStringBTtts(L["MOB_PetRenamed"]..tSafeName, true, true, 0.2)
								SkuMob.pendingPetRename = nil
							else
								SkuMob.pendingPetRename = tSafeName
								SkuOptions.Voice:OutputStringBTtts(L["MOB_PetRenameSaved"], true, true, 0.2)
							end
						end
					end)
					SkuOptions.Voice:OutputStringBTtts(L["MOB_PetRenamePrompt"], false, true, 0.2)
				end)
			end, L["MOB_PetRenameTip"])

			-- Forever: feed the pet with one key (choose food + key), SkuCore/petFeed.lua
			if Sku.isForever then
				SkuCore.PetFeed:MenuBuilder(aParent)
			end

			if SkuMob.pendingPetRename then
				local tSafeName = SkuMob.pendingPetRename:gsub('["\\\r\n]', '')
				local tConfirmLabel = L["MOB_PetRenameConfirm"] .. tSafeName
				local tEntry = SkuOptions:InjectMenuItems(aParent, {tConfirmLabel}, SkuGenericMenuItem)
				tEntry.sorting = true
				tEntry.textFull = L["MOB_PetRenameTip"]
				-- the macro runs in the global environment, where Forever has only C_PetInfo.PetRename
				tEntry.macrotext = (_G.PetRename and '/run PetRename("' or '/run C_PetInfo.PetRename("') .. tSafeName .. '")'
				tEntry.secureMacro = true
				tEntry.OnAction = function()
					tSay(L["MOB_PetRenamed"] .. tSafeName)
					SkuMob.pendingPetRename = nil
				end
			end

			tBuildPetModeSubmenu(aParent)
			tBuildRaidMarkerSubmenu(aParent, "target")

		else
			-- ===================== HEXENMEISTER / ANDERE PETS =====================
			tBuildRaidMarkerSubmenu(aParent, "target")

			tAddAction(aParent, L["MOB_SetFocus"],
				function() tCall(_G.FocusUnit, "target") end,
				L["MOB_SetFocusTip"])

			tAddAction(aParent, L["MOB_Interact"],
				function() tCall(_G.InteractUnit, "target") end,
				L["MOB_InteractTip"])

			-- PetDismiss (Freigeben)
			do
				local tEntry = SkuOptions:InjectMenuItems(aParent, {L["MOB_PetDismiss"]}, SkuGenericMenuItem)
				tEntry.sorting = true
				tEntry.textFull = L["MOB_PetDismissTip"]
				tEntry.macrotext = "/petdismiss"
				tEntry.secureMacro = true
				tEntry.OnAction = function()
					tSay(L["MOB_PetDismissed"])
				end
			end
		end
	end

	-- =========================================================
	-- ZWEIG 3: Selbst im Ziel oder kein Ziel
	-- =========================================================
	if tIsSelf or not tHasTarget then
		tAddAction(aParent, L["MOB_ResetInstances"], function()
			tCall(_G.ResetInstances)
			tSay(L["MOB_InstancesReset"])
		end, L["MOB_ResetInstancesTip"])

		if tInGroup() then
			tAddAction(aParent, L["MOB_LeaveGroup"], function()
				LeaveParty()
				tSay(L["MOB_GroupLeft"])
			end, L["MOB_LeaveGroupTip"])

			if tIsLeader() then
				tBuildLootMethodSubmenu(aParent)
			end
		end

		tBuildRaidMarkerSubmenu(aParent, "player")
	end

	-- =========================================================
	-- ZWEIG 4: Anderer Charakter (NPC, freundlich/feindlich, kein Spieler)
	-- =========================================================
	if tHasTarget and not tIsSelf and not tIsPlayer and not tIsPet then
		tBuildRaidMarkerSubmenu(aParent, "target")
	end

	if #aParent == 0 then
		SkuOptions:InjectMenuItems(aParent, {L["MOB_NoActions"]}, SkuGenericMenuItem)
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuMob:MenuBuilder(aParentEntry)
	-- W7: the top-level entry IS the target action menu now (no "Mob" wrapper, no
	-- nested "Zielmenue" level). The SkuMob options moved to Einstellungen ->
	-- Sonstiges (built from SkuCore:MenuBuilder). The target menu itself is a
	-- dynamic API list rebuilt on each open against the current target/status.
	tBuildTargetMenu(aParentEntry)
end


---------------------------------------------------------------------------------------------------------------------------------------
-- Ziel Ansage (Monitor -> Ziel Ansage). What a target announcement says, chosen per kind of unit and per situation:
-- "inCombat"/"outOfCombat" for every target change (and the soft target announcements), "queryInCombat"/
-- "queryOutOfCombat" for the key "Ziel ansagen" (SKU_KEY_OUTPUTHARDTARGET). Which one applies is decided at the
-- moment of the change or the key press. The parts are read and spoken in SkuMob/Core.lua (tTAReaders); this block
-- holds the list of parts, their defaults, the stored choices and the menu. Replaces the old player switches
-- (vocalizePlayerNamePlaceholders, ...SkuTts, dontVocalizePlayerReactionAndLevelInCombat) and Blizzard's own target
-- name announcement, which Sku switches off (Core.lua).
-- Idea and the default values: WowVision (Targeting, Names), rebuilt in Sku's own way; no code taken over.
---------------------------------------------------------------------------------------------------------------------------------------
SkuMob.TA = {}
local TA = SkuMob.TA
local TA_VERSION = 1

TA.CATEGORIES = { "player", "npc", "mob", "pet", "totem" }
TA.SETS = { "inCombat", "outOfCombat", "queryInCombat", "queryOutOfCombat" }

function TA:CategoryLabel(aCat)
	if aCat == "player" then return Sku.deEn("Spieler", "Players", "Joueurs") end
	if aCat == "npc" then return Sku.deEn("Freundliche NPCs", "Friendly NPCs", "PNJ amicaux") end
	if aCat == "mob" then return Sku.deEn("Gegner", "Enemies", "Ennemis") end
	if aCat == "pet" then return Sku.deEn("Begleiter", "Pets", "Familiers") end
	return Sku.deEn("Totems", "Totems", "Totems")
end

-- key -> label. One list for all kinds; TA.ORDER says which kind offers which part, in speaking order.
local tPartLabels = {
	dead = { "Tot", "Dead", "Mort" },
	name = { "Name", "Name", "Nom" },
	title = { "Titel", "Title", "Titre" },
	realm = { "Realm", "Realm", "Royaume" },
	guild = { "Gilde", "Guild", "Guilde" },
	level = { "Stufe", "Level", "Niveau" },
	classification = { "Selten, Elite oder Boss", "Rare, elite or boss", "Rare, élite ou boss" },
	race = { "Rasse", "Race", "Race" },
	class = { "Klasse", "Class", "Classe" },
	gender = { "Geschlecht", "Gender", "Sexe" },
	faction = { "Fraktion", "Faction", "Faction" },
	role = { "Gruppenrolle", "Group role", "Rôle de groupe" },
	pvp = { "PvP-Status", "PvP status", "Statut JcJ" },
	afk = { "Abwesend", "Away", "Absent" },
	dnd = { "Nicht stören", "Do not disturb", "Ne pas déranger" },
	charmed = { "Beherrscht", "Charmed", "Charmé" },
	reaction = { "Reaktion", "Reaction", "Réaction" },
	creatureType = { "Kreaturentyp", "Creature type", "Type de créature" },
	creatureFamily = { "Kreaturenfamilie", "Creature family", "Famille de créature" },
	questBoss = { "Quest-Boss", "Quest boss", "Boss de quête" },
	questTarget = { "Questziel", "Quest target", "Cible de quête" },
	tapped = { "Von anderen beansprucht", "Tapped by others", "Pris par un autre" },
	passive = { "Passiv", "Passive", "Passif" },
	owner = { "Besitzer", "Owner", "Propriétaire" },
	combat = { "Ziel im Kampf", "Target in combat", "Cible en combat" },
}
function TA:PartLabel(aKey)
	local t = tPartLabels[aKey]
	if not t then return aKey end
	return Sku.deEn(t[1], t[2], t[3])
end

TA.ORDER = {
	player = { "dead", "name", "title", "realm", "guild", "level", "race", "class", "gender", "faction", "role", "pvp", "afk", "dnd", "charmed", "reaction", "combat" },
	npc = { "dead", "name", "title", "level", "classification", "creatureType", "creatureFamily", "reaction", "questBoss", "questTarget", "combat" },
	mob = { "dead", "name", "title", "level", "classification", "creatureType", "creatureFamily", "reaction", "passive", "questBoss", "questTarget", "tapped", "charmed", "combat" },
	pet = { "dead", "name", "owner", "level", "creatureType", "creatureFamily", "reaction", "combat" },
	totem = { "name", "owner", "reaction" },
}

-- Defaults { in combat, out of combat } per kind and part; a part not listed is off in both.
local tDefaults = {
	player = { dead = { true, true }, name = { true, true }, title = { false, true }, guild = { false, true }, level = { false, true },
		race = { false, true }, class = { true, true }, charmed = { true, false } },
	npc = { dead = { true, true }, name = { true, true }, title = { false, true }, level = { false, true }, classification = { false, true },
		questTarget = { false, true } },
	mob = { dead = { true, true }, name = { true, true }, title = { false, true }, level = { true, true }, classification = { true, true },
		creatureType = { false, true }, reaction = { false, true }, passive = { true, true }, questBoss = { false, true },
		questTarget = { false, true }, tapped = { false, true } },
	pet = { dead = { true, true }, name = { true, true }, owner = { true, true }, level = { false, true }, creatureFamily = { false, true } },
	totem = { name = { true, true }, owner = { true, true } },
}

local function tDefaultSet(aSet)
	local tSet = {}
	for _, tCat in ipairs(TA.CATEGORIES) do
		tSet[tCat] = {}
		for _, tKey in ipairs(TA.ORDER[tCat]) do
			local d = tDefaults[tCat][tKey]
			local tValue
			if aSet == "queryOutOfCombat" then
				-- the key is the request for detail: everything the unit has
				tValue = true
			elseif aSet == "inCombat" then
				tValue = (d and d[1]) == true
			else
				-- outOfCombat, and queryInCombat (the middle version)
				tValue = (d and d[2]) == true
			end
			tSet[tCat][tKey] = tValue
		end
	end
	return tSet
end

-- The stored choices of the current profile. Set once per profile on first use (the defaults, plus the Sku colour
-- markers on and the old placeholder voice off), afterwards only the player changes them.
function TA:Data()
	local tDb = SkuSettings:Sub("SkuMob")
	if type(tDb.targetAnnounce) ~= "table" or tDb.targetAnnounce.v ~= TA_VERSION or type(tDb.targetAnnounce.sets) ~= "table" then
		tDb.targetAnnounce = { v = TA_VERSION, sets = {} }
		for _, tSet in ipairs(TA.SETS) do
			tDb.targetAnnounce.sets[tSet] = tDefaultSet(tSet)
		end
		tDb.autoSetSkuRaidTargetsToInCombatCreatures = true
		tDb.vocalizePlayerNamePlaceholdersSkuTts = false
		dprint("SkuMob TA: Ziel Ansage set to its defaults for this profile")
	end
	return tDb.targetAnnounce
end

function TA:ResetAll()
	local tData = self:Data()
	for _, tSet in ipairs(TA.SETS) do
		tData.sets[tSet] = tDefaultSet(tSet)
	end
end

function TA:IsOn(aSet, aCat, aKey)
	local tSets = self:Data().sets
	if type(tSets[aSet]) ~= "table" then tSets[aSet] = tDefaultSet(aSet) end
	local tSet = tSets[aSet]
	if type(tSet[aCat]) ~= "table" then tSet[aCat] = tDefaultSet(aSet)[aCat] or {} end
	if tSet[aCat][aKey] == nil then
		local tDef = tDefaultSet(aSet)[aCat]
		tSet[aCat][aKey] = (tDef and tDef[aKey]) == true
	end
	return tSet[aCat][aKey] == true
end

function TA:SetOn(aSet, aCat, aKey, aValue)
	self:IsOn(aSet, aCat, aKey)
	self:Data().sets[aSet][aCat][aKey] = aValue == true
end

-- Which set applies now: the key press asks for the query sets.
function TA:SetFor(aIsQuery)
	local tInCombat = InCombatLockdown() == true
	if SkuState and SkuState.IsInCombat then
		tInCombat = SkuState:IsInCombat() == true
	end
	if aIsQuery then
		return tInCombat and "queryInCombat" or "queryOutOfCombat"
	end
	return tInCombat and "inCombat" or "outOfCombat"
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Menu
local function tAddCategoryLevels(aParent, aSet)
	for _, tCat in ipairs(TA.CATEGORIES) do
		local tCatEntry = SkuOptions:InjectMenuItems(aParent, { TA:CategoryLabel(tCat) }, SkuGenericMenuItem)
		tCatEntry.dynamic = true
		tCatEntry.BuildChildren = function(self)
			for _, tKey in ipairs(TA.ORDER[tCat]) do
				local tEntry = SkuOptions:InjectMenuItems(self, { TA:PartLabel(tKey) }, SkuGenericMenuItem)
				SkuOptions:MakeToggleNode(tEntry, {
					label = TA:PartLabel(tKey),
					get = function() return TA:IsOn(aSet, tCat, tKey) end,
					set = function(_, aNewValue) TA:SetOn(aSet, tCat, tKey, aNewValue) end,
				})
			end
		end
	end
end

local function tKeyBindLabel()
	local tConst = "SKU_KEY_OUTPUTHARDTARGET"
	local tKey1 = SkuOptions:SkuKeyBindsGetBinding(tConst) or ""
	local tKey2 = SkuOptions:SkuKeyBindsGetBinding2(tConst) or ""
	local tFriendlyKey1 = (tKey1 ~= "" and tKey1) or L["nichts"]
	local tFriendlyKey2 = (tKey2 ~= "" and tKey2) or L["nichts"]
	if SkuCore.Keys and SkuCore.Keys.LocNames then
		for kLocKey, vLocKey in pairs(SkuCore.Keys.LocNames) do
			tFriendlyKey1 = gsub(tFriendlyKey1, kLocKey, vLocKey)
			tFriendlyKey2 = gsub(tFriendlyKey2, kLocKey, vLocKey)
		end
	end
	return L[tConst]..L[" Taste 1: "]..tFriendlyKey1..L[" Taste 2: "]..tFriendlyKey2
end

function TA:MenuBuilder(aParent)
	-- 1. back to the defaults (all four sets)
	local tReset = SkuOptions:InjectMenuItems(aParent, { Sku.deEn("Auf Standard zurücksetzen", "Reset to defaults", "Rétablir les valeurs par défaut") }, SkuGenericMenuItem)
	tReset.OnAction = function()
		TA:ResetAll()
		SkuOptions.Voice:OutputStringBTtts(Sku.deEn("Standardwerte wiederhergestellt", "Defaults restored", "Valeurs par défaut rétablies"), true, true, 0.2, nil, nil, nil, 2)
	end

	-- 2. and 3. every target change
	local tIn = SkuOptions:InjectMenuItems(aParent, { Sku.deEn("Zielansage im Kampf", "Target announcement in combat", "Annonce de cible en combat") }, SkuGenericMenuItem)
	tIn.dynamic = true
	tIn.BuildChildren = function(self) tAddCategoryLevels(self, "inCombat") end
	local tOut = SkuOptions:InjectMenuItems(aParent, { Sku.deEn("Zielansage nicht im Kampf", "Target announcement out of combat", "Annonce de cible hors combat") }, SkuGenericMenuItem)
	tOut.dynamic = true
	tOut.BuildChildren = function(self) tAddCategoryLevels(self, "outOfCombat") end

	-- 4. the key "Ziel ansagen"
	local tQuery = SkuOptions:InjectMenuItems(aParent, { Sku.deEn("Ziel auf Abfrage", "Target on request", "Cible sur demande") }, SkuGenericMenuItem)
	tQuery.dynamic = true
	tQuery.BuildChildren = function(self)
		local tKeyEntry = SkuOptions:InjectMenuItems(self, { tKeyBindLabel() }, SkuGenericMenuItem)
		tKeyEntry.isSelect = true
		tKeyEntry.dynamic = true
		tKeyEntry.bindingConst = "SKU_KEY_OUTPUTHARDTARGET"
		tKeyEntry.OnAction = function(s, aValue, aName)
			if aName == L["Neu belegen"] then
				if SkuCore.RebindSkuKey then SkuCore:RebindSkuKey(s, false) end
			elseif aName == L["Sekundäre Taste neu belegen"] then
				if SkuCore.RebindSkuKey then SkuCore:RebindSkuKey(s, true) end
			elseif aName == L["Belegung löschen"] then
				SkuOptions:SkuKeyBindsDeleteBinding(s.bindingConst)
				s.name = tKeyBindLabel()
				SkuOptions.Voice:OutputStringBTtts(L["Belegung gelöscht"], true, true, 0.2)
			elseif aName == L["Sekundäre Belegung löschen"] then
				SkuOptions:SkuKeyBindsDeleteBinding2(s.bindingConst)
				s.name = tKeyBindLabel()
				SkuOptions.Voice:OutputStringBTtts(L["Sekundäre Belegung gelöscht"], true, true, 0.2)
			end
		end
		tKeyEntry.BuildChildren = function(s)
			SkuOptions:InjectMenuItems(s, { L["Neu belegen"] }, SkuGenericMenuItem)
			SkuOptions:InjectMenuItems(s, { L["Sekundäre Taste neu belegen"] }, SkuGenericMenuItem)
			SkuOptions:InjectMenuItems(s, { L["Belegung löschen"] }, SkuGenericMenuItem)
			SkuOptions:InjectMenuItems(s, { L["Sekundäre Belegung löschen"] }, SkuGenericMenuItem)
		end
		local tQIn = SkuOptions:InjectMenuItems(self, { Sku.deEn("Im Kampf", "In combat", "En combat") }, SkuGenericMenuItem)
		tQIn.dynamic = true
		tQIn.BuildChildren = function(s) tAddCategoryLevels(s, "queryInCombat") end
		local tQOut = SkuOptions:InjectMenuItems(self, { Sku.deEn("Außerhalb des Kampfes", "Out of combat", "Hors combat") }, SkuGenericMenuItem)
		tQOut.dynamic = true
		tQOut.BuildChildren = function(s) tAddCategoryLevels(s, "queryOutOfCombat") end
	end

	-- 5. the former "Ziel Optionen", plus the combat status of an enemy (same value as under Barrierefreiheit)
	local tMore = SkuOptions:InjectMenuItems(aParent, { Sku.deEn("Weitere Zieloptionen", "More target options", "Autres options de cible") }, SkuGenericMenuItem)
	tMore.dynamic = true
	tMore.BuildChildren = function(self)
		SkuOptions:IterateOptionsArgs(SkuMob.options.args, self, SkuSettings:Sub("SkuMob"), "SkuMob")
		local tStatus = SkuOptions:InjectMenuItems(self, { L["Gegnerstatus Kampf"] }, SkuGenericMenuItem)
		tStatus.dynamic = true
		tStatus.isSelect = true
		tStatus.GetCurrentValue = function()
			local m = SkuSettings:Sub("SkuMob").enemyCombatStatusMode or "beep"
			if m == "off" then return L["aus"] elseif m == "announce" then return L["Ansage"] end
			return L["Beep"]
		end
		tStatus.OnAction = function(s, aValue, aName)
			local p = SkuSettings:Sub("SkuMob")
			if aName == L["aus"] then
				p.enemyCombatStatusMode = "off"
			elseif aName == L["Ansage"] then
				p.enemyCombatStatusMode = "announce"
			else
				p.enemyCombatStatusMode = "beep"
			end
		end
		tStatus.BuildChildren = function(s)
			SkuOptions:InjectMenuItems(s, { L["aus"] }, SkuGenericMenuItem)
			SkuOptions:InjectMenuItems(s, { L["Beep"] }, SkuGenericMenuItem)
			SkuOptions:InjectMenuItems(s, { L["Ansage"] }, SkuGenericMenuItem)
		end
		for _, tChild in ipairs(self.children) do tChild.noStepUpAfterSelect = true end
	end
end
