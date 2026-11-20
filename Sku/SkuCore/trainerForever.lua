---------------------------------------------------------------------------------------------------------------------------------------
-- Class trainer and beast training on WoW Forever.
-- Both use the same window (ClassTrainerFrame). It is a scroll box without the old ClassTrainerSkill1..N buttons, so the
-- list is built from the trainer API. Beast training (C_Trainer.GetTrainerType() == Enum.TrainerType.Pet) costs the
-- pet's training points instead of money.
--
-- BuyTrainerService is protected on Forever, so Sku never calls it. Choosing a skill is a secure click on the row in
-- Blizzard's window, learning is a secure click on Blizzard's own ClassTrainerTrainButton.
---------------------------------------------------------------------------------------------------------------------------------------
if not Sku.isForever then return end

local L = Sku.L

local function tSay(aText)
	SkuOptions.Voice:OutputStringBTtts(aText, false, true, 0.2)
end

local function tIsPet()
	return C_Trainer.GetTrainerType() == Enum.TrainerType.Pet
end

-- The pet's free training points (nil when they cannot be read).
local function tPetPoints()
	local tTotal, tUsed = C_PetInfo.GetPetTrainingPoints()
	if type(tTotal) == "number" and type(tUsed) == "number" then
		return math.max(tTotal - tUsed, 0)
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Skills the pet already knows. The window still offers them as learnable, and the server then refuses with "your pet
-- already knows ...". Two sources keep them out of the way: the pet spellbook (same name, same or higher rank) and a
-- remembered refusal (per pet GUID, name and rank), learned on the first attempt.
local function tRankNumber(aRankText)
	return tonumber(tostring(aRankText or ""):match("(%d+)")) or 1
end

local function tKnownStore()
	local tStore = SkuSettings:Sub("SkuCore", nil, "char")
	tStore.petKnownSkills = tStore.petKnownSkills or {}
	return tStore.petKnownSkills
end

local function tKnownKey(aName, aRankText)
	return tostring(Sku.SafeGUID("pet") or "?") .. "|" .. tostring(aName) .. "|" .. tRankNumber(aRankText)
end

local function tPetSpellbookRank(aName)
	local tBest
	for i = 1, C_SpellBook.HasPetSpells() or 0 do
		local tSpell, tSub = C_SpellBook.GetSpellBookItemName(i, Enum.SpellBookSpellBank.Pet)
		if tSpell == aName then
			local tRank = tonumber(tostring(tSub or ""):match("(%d+)")) or 0
			if not tBest or tRank > tBest then tBest = tRank end
		end
	end
	return tBest
end

local function tPetSkillKnown(aName, aRankText)
	if tKnownStore()[tKnownKey(aName, aRankText)] then return true end
	local tKnownRank = tPetSpellbookRank(aName)
	return tKnownRank ~= nil and tKnownRank > 0 and tRankNumber(aRankText) <= tKnownRank
end

local function tIsAlreadyKnownMessage(aMessage)
	if type(aMessage) ~= "string" or type(ERR_PET_SPELL_ALREADY_KNOWN) ~= "string" then return false end
	local tPrefix = ERR_PET_SPELL_ALREADY_KNOWN:match("^(.-)%%s")
	return tPrefix ~= nil and tPrefix ~= "" and aMessage:sub(1, #tPrefix) == tPrefix
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Blizzard's row (frame object) of a service index; nil while it is not built.
local function tRowFor(aSkillIndex)
	-- A trade skill's step ("Apprentice Tailoring", ...) is not in the list: Blizzard shows it on its own button above it.
	local tStepIndex = GetTrainerServiceStepIndex and GetTrainerServiceStepIndex()
	if tStepIndex and tStepIndex == aSkillIndex then
		local tStepButton = ClassTrainerFrame.skillStepButton
		return (tStepButton and tStepButton:IsShown()) and tStepButton or nil
	end
	local tBox = ClassTrainerFrame.ScrollBox
	if not (tBox and tBox.FindFrameByPredicate) then return nil end
	return tBox:FindFrameByPredicate(function(_, aElementData)
		local tData = aElementData and (aElementData.data or aElementData)
		return tData and tData.skillIndex == aSkillIndex
	end)
end

-- Blizzard's list is a scroll box that builds only the rows in view. Returns true when it is longer than its window.
local function tListScrolls()
	local tBox = ClassTrainerFrame.ScrollBox
	local tVisible = tBox and tBox.GetVisibleExtentPercentage and tBox:GetVisibleExtentPercentage() or 1
	return tVisible > 0 and tVisible < 1
end

-- Is the service in view (its row is built)? The trade skill's step button above the list always counts.
local function tServiceInView(aSkillIndex)
	local tStepIndex = GetTrainerServiceStepIndex and GetTrainerServiceStepIndex()
	if tStepIndex and tStepIndex == aSkillIndex then return true end
	local tBox = ClassTrainerFrame.ScrollBox
	if not (tBox and tBox.FindFrameByPredicate) then return false end
	return tBox:FindFrameByPredicate(function(_, aElementData)
		local tData = aElementData and (aElementData.data or aElementData)
		return tData and tData.skillIndex == aSkillIndex
	end) ~= nil
end

-- Pages Blizzard's list by one window height (aDirection -1 back, 1 forward), then rebuilds the menu.
local function tPageList(aDirection)
	local tBox = ClassTrainerFrame.ScrollBox
	if not (tBox and tBox.GetScrollPercentage and tBox.SetScrollPercentage) then return end
	local tVisible = tBox.GetVisibleExtentPercentage and tBox:GetVisibleExtentPercentage() or 0.3
	local tStep = (tVisible > 0 and tVisible < 1) and (tVisible / (1 - tVisible)) or 0.3
	local tNew = math.min(math.max(tBox:GetScrollPercentage() + aDirection * tStep, 0), 1)
	local tAtEnd = (tNew == tBox:GetScrollPercentage())
	pcall(tBox.SetScrollPercentage, tBox, tNew, true)
	dprint("trainerRow", "blaettern", aDirection, "neu", tostring(tNew))
	C_Timer.After(0.3, function()
		if not ClassTrainerFrame:IsVisible() then return end
		SkuCore:RefreshWindowMenuQuietly()
		if tAtEnd then
			tSay(aDirection > 0 and Sku.deEn("Ende der Liste", "end of list", "fin de la liste")
				or Sku.deEn("Anfang der Liste", "start of list", "début de la liste"))
		end
	end)
end

-- Adds a "page back" / "page forward" entry when Blizzard's list is longer than its window.
local function tAddPageButton(aParentChilds, aDirection)
	local tBox = ClassTrainerFrame.ScrollBox
	local tVisible = tBox and tBox.GetVisibleExtentPercentage and tBox:GetVisibleExtentPercentage() or 1
	if not (tVisible > 0 and tVisible < 1) then return end
	local tLabel = aDirection > 0 and Sku.deEn("Liste weiter blättern", "Page list forward", "Page suivante")
		or Sku.deEn("Liste zurück blättern", "Page list back", "Page précédente")
	table.insert(aParentChilds, tLabel)
	aParentChilds[tLabel] = {
		RoC = "Child",
		type = "Button",
		skuIdentity = "pagelist:" .. aDirection,
		textFirstLine = tLabel,
		textFull = "",
		childs = {},
		click = true,
		quietClick = true,
		func = function() tPageList(aDirection) end,
	}
end

-- Service index of the skill chosen in Blizzard's window (nil when none is chosen).
local function tSelectedIndex()
	local tFrame = ClassTrainerFrame
	if not (tFrame.selectedService and tFrame.displayIndexToSkillIndex) then return nil end
	return tFrame.displayIndexToSkillIndex[tFrame.selectedService]
end

local tOpenAt            -- when the window was first built, to tell Blizzard's preselection from a choice
local tLearnLabel        -- label of the "Learn" entry of the last build
local tSelectionHooked

-- Enter on an entry is bound straight to Blizzard's row, so Sku does not run along. A post hook on
-- ClassTrainer_SetSelection announces the choice and rebuilds the menu.
local function tHookSelection()
	if tSelectionHooked or not ClassTrainer_SetSelection then return end
	tSelectionHooked = true
	hooksecurefunc("ClassTrainer_SetSelection", function()
		C_Timer.After(0.2, function()
			if not ClassTrainerFrame:IsVisible() then return end
			local tIdx = tSelectedIndex()
			-- Only a real choice after the first build counts; Blizzard's preselection on opening stays silent.
			local tChanged = tIdx and tOpenAt and GetTime() - tOpenAt > 1.5
			SkuCore:RefreshWindowMenuQuietly()
			if not tChanged then return end
			-- After a choice the focus goes to the "Learn: <skill>" entry and reads it. Without one (not
			-- learnable) the choice only announces the name.
			local function tFocusLearn(aLast)
				if not ClassTrainerFrame:IsVisible() then return end
				local tNow = SkuOptions.currentMenuPosition
				local tList = tNow and tNow.parent and tNow.parent.children
				local tHit
				if tLearnLabel and tList then
					for _, tChild in ipairs(tList) do
						if type(tChild.name) == "string" and tChild.name:find(tLearnLabel, 1, true) then tHit = tChild break end
					end
				end
				if tHit then
					SkuOptions.currentMenuPosition = tHit
					-- OnEnter sets up the secure Enter binding of the entry (otherwise Enter does nothing)
					if tHit.OnEnter then tHit:OnEnter() end
					SkuOptions:VocalizeCurrentMenuName()
				elseif not aLast then
					C_Timer.After(0.4, function() tFocusLearn(true) end)
				else
					local tName = GetTrainerServiceInfo(tIdx)
					if tName then tSay(tName .. " " .. L["selected"]) end
				end
			end
			C_Timer.After(0.35, function() tFocusLearn(false) end)
		end)
	end)
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Says whether the skill was learned, after checking the result (the server answers asynchronously).
local tErrorFrame, tLastError
local LEARN_IDENTITY = "frame:ClassTrainerTrainButton"

local function tVerify(aIndex, aName, aIsPet, aCost, aPointsBefore, aMoneyBefore, aRankText)
	if not tErrorFrame then
		tErrorFrame = CreateFrame("Frame")
		tErrorFrame:SetScript("OnEvent", function(_, _, _, aMessage)
			if type(aMessage) == "string" then tLastError = aMessage end
		end)
	end
	tLastError = nil
	tErrorFrame:RegisterEvent("UI_ERROR_MESSAGE")
	dprint("trainerBuy", "index", aIndex, "name", tostring(aName), "pet", tostring(aIsPet), "cost", tostring(aCost), "points", tostring(aPointsBefore))

	local function tFinish(aLearned)
		tErrorFrame:UnregisterEvent("UI_ERROR_MESSAGE")
		if aLearned then
			local tText = aName .. " " .. L["learned"]
			if aIsPet then
				local tFree = tPetPoints()
				if tFree then tText = tText .. ", " .. L["Training points left"] .. ": " .. tFree end
			end
			tSay(tText)
		else
			local tText = aName .. " " .. L["not learned"]
			local tFree = aIsPet and tPetPoints() or nil
			if tLastError and tLastError ~= "" then
				tText = tText .. ". " .. tLastError
				-- "already known": remember it, so the skill is not in the list next time
				if aIsPet and tIsAlreadyKnownMessage(tLastError) then
					tKnownStore()[tKnownKey(aName, aRankText)] = true
					tText = tText .. " " .. L["Will be listed as learned."]
				end
			elseif aIsPet and tFree and tonumber(aCost) and aCost > tFree then
				tText = tText .. ". " .. L["Not enough training points"] .. ": " .. aCost .. " " .. L["needed"] .. ", " .. tFree .. " " .. L["free"]
			end
			tSay(tText)
		end
		dprint("trainerBuy", "result", tostring(aLearned), tostring(tLastError))
		if ClassTrainerFrame:IsVisible() then
			-- The "Learn" entry is gone after learning. If the cursor is still on it (checked by identity, a quiet
			-- refresh may have replaced the node meanwhile), its identity becomes the skill's, so the refresh puts the
			-- cursor on the skill's row instead of at the top. A cursor the player moved on stays where it is.
			local tPos = SkuOptions.currentMenuPosition
			if aLearned and tPos and tPos.skuIdentity == LEARN_IDENTITY then
				tPos.skuIdentity = "skill:" .. aName .. " " .. (aRankText or "")
			end
			SkuCore:RefreshWindowMenuQuietly()
		end
	end

	local function tCheck(aFinal)
		-- Observed on Forever: GetTrainerServiceInfo returns name, state, ?, ?, rank text
		local tName, tState = GetTrainerServiceInfo(aIndex)
		local tFreeNow = tPetPoints()
		local tLearned = (tName ~= aName) or (tState ~= "available")
			or (aIsPet and aPointsBefore and tFreeNow and tFreeNow < aPointsBefore)
			or ((not aIsPet) and aMoneyBefore and GetMoney() < aMoneyBefore)
		if tLearned then
			tFinish(true)
		elseif aFinal then
			tFinish(false)
		else
			C_Timer.After(1.0, function() tCheck(true) end)
		end
	end
	C_Timer.After(0.7, function() tCheck(false) end)
end

---------------------------------------------------------------------------------------------------------------------------------------
local function tAddText(aParentChilds, aLabel, aFrameName)
	table.insert(aParentChilds, aLabel)
	aParentChilds[aLabel] = {
		frameName = aFrameName,
		RoC = "Child",
		type = "FontString",
		textFirstLine = aLabel,
		textFull = "",
		childs = {},
	}
end

function SkuCore:Build_ClassTrainerFrameForever(aParentChilds)
	local tIsPet = tIsPet()
	local tFreePoints = tIsPet and tPetPoints() or nil

	-- Beast training has no trainer NPC (UnitName("npc") is empty), only the pet.
	local tTitle
	if tIsPet then
		tTitle = L["Wildtierausbildung"]
		local tPetName = UnitName("pet")
		if tPetName and tPetName ~= "" then tTitle = tTitle .. ": " .. tPetName end
	else
		local tTrainerName = UnitName("npc")
		tTitle = (tTrainerName and tTrainerName ~= "") and tTrainerName or L["Class Trainer"]
	end
	table.insert(aParentChilds, tTitle)
	aParentChilds[tTitle] = {
		frameName = "ClassTrainerFrame",
		RoC = "Child",
		type = "FontString",
		obj = ClassTrainerFrame,
		skuIdentity = "frame:ClassTrainerFrame",
		textFirstLine = tTitle,
		textFull = "",
		childs = {},
	}

	if tIsPet then
		tAddText(aParentChilds,
			tFreePoints and (L["Training points left"] .. ": " .. tFreePoints) or L["Training points unknown"],
			"ClassTrainerFramePoints")
	end

	tAddPageButton(aParentChilds, -1)

	local tStateNames = {
		available = L["learnable"],
		unavailable = L["not learnable"],
		used = L["bekannt"],
		header = L["category"],
	}
	local tNum = GetNumTrainerServices() or 0
	local tSelectedIndex = tSelectedIndex()
	tLearnLabel = nil
	tOpenAt = tOpenAt or GetTime()
	if not ClassTrainerFrame.skuOnHideHooked then
		ClassTrainerFrame.skuOnHideHooked = true
		ClassTrainerFrame:HookScript("OnHide", function() tOpenAt = nil end)
	end
	tHookSelection()

	-- Only what Blizzard's window shows right now is listed; the rest is reached with the page entries. If no row is
	-- built yet (window just opened), everything is listed so the menu is never empty.
	local tOnlyInView = false
	if tListScrolls() then
		for i = 1, tNum do
			if tServiceInView(i) then tOnlyInView = true break end
		end
	end

	-- Beast training: the entries are listed alphabetically (same name = Blizzard's order, so the ranks stay ascending).
	-- Class and profession trainers keep Blizzard's order.
	local tOrder = {}
	for i = 1, tNum do tOrder[i] = i end
	if tIsPet then
		local tSortName = {}
		for i = 1, tNum do
			local tN = GetTrainerServiceInfo(i)
			tSortName[i] = string.lower(type(tN) == "string" and tN or "")
		end
		table.sort(tOrder, function(a, b)
			if tSortName[a] ~= tSortName[b] then return tSortName[a] < tSortName[b] end
			return a < b
		end)
	end

	for _, i in ipairs(tOrder) do
		-- Observed on Forever: name, state, ?, ?, rank text
		local tName, tState, _, _, tRankText = GetTrainerServiceInfo(i)
		if tName and tName ~= "" and (not tOnlyInView or tServiceInView(i)) then
			local tCost = GetTrainerServiceCost(i)
			if not (tonumber(tCost) and tCost > 0) then tCost = nil end

			local tStateText = tStateNames[tState] or tostring(tState or "")
			if tIsPet and tState == "available" and tCost and tFreePoints and tCost > tFreePoints then
				tStateText = L["not enough points"]
			end
			-- Already learned (the game still reports it as learnable): listed as learned, cannot be chosen.
			local tKnownSkill = tIsPet and tState == "available" and tPetSkillKnown(tName, tRankText)
			if tKnownSkill or (tIsPet and tState == "used") then
				tStateText = L["learned"]
			end

			local tLabel = tName
			if tRankText and tRankText ~= "" then tLabel = tLabel .. " " .. tRankText end
			tLabel = tLabel .. " (" .. tStateText .. ")"

			-- details: cost, requirements, description
			local tParts = { tName }
			if tRankText and tRankText ~= "" then tParts[#tParts + 1] = tRankText end
			if tCost then
				if tIsPet then
					tParts[#tParts + 1] = L["Cost"] .. ": " .. tCost .. " " .. L["training points"]
				else
					tParts[#tParts + 1] = L["Cost"] .. ": " .. SkuGetCoinText(tCost, true)
				end
			end
			local tLevel = GetTrainerServiceLevelReq(i)
			if tonumber(tLevel) and tLevel > 0 then
				tParts[#tParts + 1] = L["Level"] .. ": " .. tLevel
			end
			local tSkillName, tSkillRank = GetTrainerServiceSkillReq(i)
			if tSkillName and tSkillName ~= "" then
				tParts[#tParts + 1] = tSkillName .. (tSkillRank and (" " .. tSkillRank) or "")
			end
			local tDesc = GetTrainerServiceDescription(i)
			if type(tDesc) == "string" and tDesc ~= "" then tParts[#tParts + 1] = tDesc end

			local tRow = (tState == "available" and not tKnownSkill) and tRowFor(i) or nil
			if tState == "available" and not tKnownSkill and not tRow then
				tLabel = tLabel .. ", " .. L["cannot be selected, reopen the window"]
				dprint("trainerRow", "keine Zeile", "index", i, "name", tostring(tName), "stufe", tostring(tLevel),
					"beruf", tostring(tSkillName), tostring(tSkillRank), "zeilenGebaut", tostring(ClassTrainerFrame.ScrollBox ~= nil))
			end
			if i == tSelectedIndex then
				tLabel = tLabel .. ", " .. L["selected"]
			end
			table.insert(aParentChilds, tLabel)
			local tEntry = {
				RoC = "Child",
				type = "Button",
				obj = tRow,
				-- The label changes with the state (", selected"); the identity keeps the cursor on the row.
				skuIdentity = "skill:" .. tName .. " " .. (tRankText or ""),
				textFirstLine = tLabel,
				textFull = table.concat(tParts, "\r\n"),
				childs = {},
			}
			if tRow then
				-- Choosing = Enter bound straight to Blizzard's row (directClickButton). A secure click would hand
				-- the row the name of the menu key ("ENTER"), but the row only answers to "LeftButton". The binding
				-- needs a real named button, a global alias of the unnamed row never receives it, so a named secure
				-- button clicks the row with "LeftButton".
				tEntry.directAction = true
				tEntry.noMenuNumbers = true
				local tAlias = "SkuTrainerRow" .. i
				local tProxy = _G[tAlias]
				if not (tProxy and tProxy.skuTrainerProxy) then
					tProxy = CreateFrame("Button", tAlias, UIParent, "SecureActionButtonTemplate")
					tProxy.skuTrainerProxy = true
					-- Key down only: with "AnyUp" too, one press clicked the row twice (two selections, two rebuilds).
					tProxy:RegisterForClicks("AnyDown")
					tProxy:SetAttribute("type", "click")
				end
				if not InCombatLockdown() then
					tProxy:SetAttribute("clickbutton", tRow)
				end
				tEntry.directClickButton = tAlias
				tEntry.func = function() end
			elseif tKnownSkill or tState == "used" then
				-- Enter says so and leaves the cursor on the row (a quiet click keeps it there).
				tEntry.click = true
				tEntry.quietClick = true
				tEntry.func = function() tSay(L["Already learned"]) end
			end
			aParentChilds[tLabel] = tEntry
		end
	end

	tAddPageButton(aParentChilds, 1)

	-- Learn: secure click on Blizzard's own Learn button for the chosen skill.
	local tTrainButton = ClassTrainerTrainButton
	if tSelectedIndex and tTrainButton and tTrainButton:IsVisible() then
		local tSelName, tSelState, _, _, tSelRankText = GetTrainerServiceInfo(tSelectedIndex)
		if tSelName and tSelState == "available" and not (tIsPet and tPetSkillKnown(tSelName, tSelRankText)) then
			local tSelCost = GetTrainerServiceCost(tSelectedIndex)
			tSelCost = (tonumber(tSelCost) and tSelCost > 0) and tSelCost or nil
			local tLabel = L["Learn"] .. ": " .. tSelName
			local tCanTrain = tTrainButton:IsEnabled() == true
			if not tCanTrain then
				-- Say WHY (Blizzard greys the button out for: too little money, too few pet points, no free profession slot).
				local tReason = L["not possible right now"]
				if not tIsPet and tSelCost and GetMoney() < tSelCost then
					tReason = Sku.deEn("nicht genug Geld, es kostet ", "not enough money, it costs ", "pas assez d'argent, coût ")
						.. SkuGetCoinText(tSelCost, true) .. ", " .. Sku.deEn("du hast ", "you have ", "vous avez ") .. SkuGetCoinText(GetMoney(), true)
				elseif tIsPet and tSelCost and tPetPoints() and tSelCost > tPetPoints() then
					tReason = L["Not enough training points"] .. ": " .. tSelCost .. " " .. L["needed"] .. ", " .. tPetPoints() .. " " .. L["free"]
				elseif ClassTrainerTrainButton.disableReason ~= nil then
					tReason = Sku.deEn("kein freier Berufsplatz", "no free profession slot", "aucun emplacement de métier libre")
				end
				dprint("trainerRow", "lernen gesperrt", "index", tSelectedIndex, "name", tostring(tSelName), "kosten", tostring(tSelCost),
					"geld", tostring(GetMoney()), "grund", tostring(ClassTrainerTrainButton.disableReason))
				tLabel = tLabel .. " (" .. tReason .. ")"
			end
			local tPointsBefore = tIsPet and tPetPoints() or nil
			local tMoneyBefore = GetMoney()
			local tSelIndex = tSelectedIndex
			tLearnLabel = tLabel
			table.insert(aParentChilds, tLabel)
			aParentChilds[tLabel] = {
				frameName = "ClassTrainerTrainButton",
				RoC = "Child",
				type = "Button",
				obj = tTrainButton,
				skuIdentity = LEARN_IDENTITY,
				textFirstLine = tLabel,
				textFull = "",
				noMenuNumbers = true,
				childs = {},
				directAction = tCanTrain or nil,
				secureClickFrame = tCanTrain and tTrainButton or nil,
				func = tCanTrain and function()
					tVerify(tSelIndex, tSelName, tIsPet, tSelCost, tPointsBefore, tMoneyBefore, tSelRankText)
				end or nil,
			}
		end
	end
	if tNum == 0 then
		tAddText(aParentChilds, L["Menu empty"], nil)
	end
end
