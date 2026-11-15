local MODULE_NAME = "SkuNav"
local L = Sku.L

-- File-level state that used to leak into _G through a missing "local".
local tUnitDbWaypointData
local function BuildSortedUniqueRouteWps(tRoutesInRange)
	local tSortedWaypointList = {}
	-- a lookup set instead of scanning the whole list for every entry (that scan with a string join per step took over half a
	-- second for the ~1,700 entry candidates on the big Forever maps, 11.11.2026)
	local tSeen = {}
	for k, v in SkuSpairs(tRoutesInRange, function(t,a,b) return t[b].nearestWpRange > t[a].nearestWpRange end) do
		local tEntry = v.nearestWpRange..L[";Meter"].."#"..v.nearestWP
		if not tSeen[tEntry] then
			tSeen[tEntry] = true
			table.insert(tSortedWaypointList, tEntry)
		end
	end
	return tSortedWaypointList
end


local ssub = string.sub
local slen = string.len

SkuNav.ClickClackSoundsets = {}

-- [41.05] Fix fuer leeres "Ton fuer Klick bei Beacons"-Menue (Timing-Rennen):
-- Die Klick-Toene werden vom externen Addon SkuBeaconSoundsets erst im Event
-- PLAYER_ENTERING_WORLD registriert; SkuNav\Core.lua (geschuetzt) befuellt die
-- Liste dort aber SYNCHRON und damit oft zu frueh (leer). Dieser additive
-- Nachzieher baut die Liste kurz NACH dem Event neu auf und zeigt die Auswahl
-- darauf um. Aendert die geschuetzte Core.lua nicht; schlimmstenfalls ein No-Op.
local tCCFixFrame = CreateFrame("Frame")
tCCFixFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
tCCFixFrame:SetScript("OnEvent", function()
	C_Timer.After(2, function()
		pcall(function()
			if not (SkuOptions and SkuOptions.BeaconLib and SkuOptions.BeaconLib.GetClickClackSoundSets) then return end
			local t = {}
			t["off"] = L["Nichts"]
			for k, v in pairs(SkuOptions.BeaconLib:GetClickClackSoundSets()) do
				if type(v) == "table" and v.friendlyName then
					t[k] = v.friendlyName
				end
			end
			SkuNav.ClickClackSoundsets = t
			if SkuNav.options and SkuNav.options.args and SkuNav.options.args.clickClackSoundset then
				SkuNav.options.args.clickClackSoundset.values = t
			end
		end)
	end)
end)

SkuNav.StandardWpReachedRanges = {
   [1] = L["1 Meter"],
   [2] = L["2 Meter"],
   [3] = L["3 Meter"],
   [4] = L["Auto"],
}

SkuNav.RoutesMaxDistances = {
   [2000] = "2000 "..L["meters"],
   [3000] = "3000 "..L["meters"],
   [4000] = "4000 "..L["meters"],
   [5000] = "5000 "..L["meters"],
   [6000] = "6000 "..L["meters"],
   [8000] = "8000 "..L["meters"],
   [20000] = L["Unlimited"],
}

local timeForVisitedToExpireValues = {L["disabled"], "1 "..L["minute"]}
for i=2, 30 do
	timeForVisitedToExpireValues[i+1] = i .. L[" Minuten"]
end


SkuNav.options = {
	name = MODULE_NAME,
	type = "group",
	args = {
		beaconVolume = {
			order = 2,
			name = L["Beacon Volume"],
			desc = "",
			type = "range",
		},
		beaconSoundSetNarrow = {
			order = 3,
			name = L["narrow beacon sound set"],
			desc = "",
			type = "select",
			values = SkuNav.BeaconSoundSetNames,
			OnAction = function(self, info, val)
				local tPlayerPosX, tPlayerPosY = UnitPosition("player")
				if not SkuOptions.BeaconLib:CreateBeacon("SkuOptions", "sampleBeacon", SkuNav.BeaconSoundSetNames[val], tPlayerPosX + 10, tPlayerPosY, -3, 0, SkuSettings:Sub("SkuNav").beaconVolume, SkuSettings:Sub("SkuNav").clickClackRange, nil, nil, nil, nil, SkuSettings:Sub("SkuNav").clickClackSoundset) then
					return
				end
				SkuOptions.BeaconLib:StartBeacon("SkuOptions", "sampleBeacon")
				C_Timer.After(1, function()
					SkuOptions.BeaconLib:DestroyBeacon("SkuOptions", "sampleBeacon")
				end)
			end,	
			set = function(info,val)
				SkuSettings:Sub("SkuNav").beaconSoundSetNarrow = SkuNav.BeaconSoundSetNames[val]
			end,
			get = function(info)
				return SkuSettings:Sub("SkuNav").beaconSoundSetNarrow
			end
		},
		beaconSoundSetWide = {
			order = 4,
			name = L["wide beacon sound set"],
			desc = "",
			type = "select",
			values = SkuNav.BeaconSoundSetNames,
			OnAction = function(self, info, val)
				local tPlayerPosX, tPlayerPosY = UnitPosition("player")
				if not SkuOptions.BeaconLib:CreateBeacon("SkuOptions", "sampleBeacon", SkuNav.BeaconSoundSetNames[val], tPlayerPosX + 10, tPlayerPosY, -3, 0, SkuSettings:Sub("SkuNav").beaconVolume, SkuSettings:Sub("SkuNav").clickClackRange, nil, nil, nil, nil, SkuSettings:Sub("SkuNav").clickClackSoundset) then
					return
				end
				SkuOptions.BeaconLib:StartBeacon("SkuOptions", "sampleBeacon")
				C_Timer.After(1, function()
					SkuOptions.BeaconLib:DestroyBeacon("SkuOptions", "sampleBeacon")
				end)
			end,				
			set = function(info,val)
				SkuSettings:Sub("SkuNav").beaconSoundSetWide = SkuNav.BeaconSoundSetNames[val]
			end,
			get = function(info)
				return SkuSettings:Sub("SkuNav").beaconSoundSetWide
			end
		},
		beaconSoundSetLast = {
			order = 4.5,
			name = L["last beacon sound set"],
			desc = "",
			type = "select",
			values = SkuNav.BeaconSoundSetNames,
			OnAction = function(self, info, val)
				local tPlayerPosX, tPlayerPosY = UnitPosition("player")
				if not SkuOptions.BeaconLib:CreateBeacon("SkuOptions", "sampleBeacon", SkuNav.BeaconSoundSetNames[val], tPlayerPosX + 10, tPlayerPosY, -3, 0, SkuSettings:Sub("SkuNav").beaconVolume, SkuSettings:Sub("SkuNav").clickClackRange, nil, nil, nil, nil, SkuSettings:Sub("SkuNav").clickClackSoundset) then
					return
				end
				SkuOptions.BeaconLib:StartBeacon("SkuOptions", "sampleBeacon")
				C_Timer.After(1, function()
					SkuOptions.BeaconLib:DestroyBeacon("SkuOptions", "sampleBeacon")
				end)
			end,
			set = function(info,val)
				SkuSettings:Sub("SkuNav").beaconSoundSetLast = SkuNav.BeaconSoundSetNames[val]
			end,
			get = function(info)
				return SkuSettings:Sub("SkuNav").beaconSoundSetLast
			end
		},
		clickClackEnabled = {
			order = 5,
			name = L["Klick bei Beacons"],
			desc = "",
			type = "toggle",
			OnAction = function(self, info, val)
			end,
		},
		clickClackRange = {
			order = 6,
			name = L["Winkel für Klick bei Beacons"],
			desc = "",
			type = "range",
		},
		clickClackSoundset = {
			order = 7,
			name = L["Ton für Klick bei Beacons"],
			desc = "",
			type = "select",
			values = SkuNav.ClickClackSoundsets,
			OnAction = function(self, info, val)
			end,
		},
		vocalizeFullDirectionDistance = {
			order = 8,
			name = L["Detailed direction and distance"],
			desc = "",
			type = "toggle",
		},
		vocalizeZoneNames = {
			order = 9,
			name = L["Announce zone names"],
			desc = "",
			type = "toggle",
		},
		nearbyWpRange = {
			order = 10,
			name = L["Range for near route starts"],
			desc = "",
			type = "range",
		},
		standardWpReachedRange = {
			order = 11,
			name = L["Waypoint reached at"],
			desc = "",
			type = "select",
			values = SkuNav.StandardWpReachedRanges,
		},
		autoGlobalDirection = {
			order = 12,
			name = L["Auto announce global direction"],
			desc = "",
			type = "toggle",
		},
		showGlobalDirectionInWaypointLists = {
			order = 13,
			name = L["Show global direction in waypoint lists"],
			desc = "",
			type = "toggle",
		},
		trackVisited = {
			order = 14,
			name = L["Track whether waypoints were visited"],
			desc = "",
			type = "toggle",
		},
		timeForVisitedToExpire = {
			order = 15,
			name = L["visited automatically expires after"],
			desc = "",
			type = "select",
			values = timeForVisitedToExpireValues,
		},
		showGatherWaypoints = {
			order = 16,
			name = L["Show herbs and mining node waypoints"],
			desc = "",
			type = "toggle",
			OnAction = function(self, info, val)
				-- [DB rework lever E] Was a hand-wire of SessionRouteData from
				-- SkuDB.routedata Waypoints+Links; the TBC link half is freed
				-- after login and the correct per-client wiring lives in
				-- LoadDefaultMapData.
				SkuNav:LoadDefaultMapData(true)
				SkuNav:CreateWaypointCache()

				for x = 1, 4 do
					local tWaypointName = L["Quick waypoint"]..";"..x
					SkuNav:UpdateQuickWP(tWaypointName, true)
				end			
			end,
			set = function(info,val)
				SkuSettings:Sub("SkuNav").showGatherWaypoints = val
			end,
			get = function(info)
				return SkuSettings:Sub("SkuNav").showGatherWaypoints
			end
		},	
		showRoutesOnMinimap = {
			order = 17,
			name = L["Show routes on minimap"],
			desc = "",
			type = "toggle",
		},
		showSkuMM = {
			order = 18,
			name = L["Show extra minimap"],
			desc = "",
			type = "toggle",
		},

		tomtomWp = {
			order = 19,
			name = L["Auto sound on Tom Tom arrow"],
			desc = "",
			type = "toggle",
		},		
		
		autoNextWaypoint={
			name = L["Auto switching to next similar waypoint"],
			type = "group",
			order = 20,
			args= {
				nonVocalized = {
					order = 5,
					name = L["Don't announce waypoint switching"],
					desc = "",
					type = "toggle",
				},
				reachRange = {
					order = 10,
					name = L["Range for counting a waypoint as reached and switching to next waypoint"],
					desc = "",
					type = "range",
				},
			},
		},
		outputDistance = {
			order = 2,
			name = L["output Distance to next waypoint"],
			desc = "",
			type = "range",
		},
		routesMaxDistance = {
			order = 20,
			name = L["Maximum distance for destinations in routes list"],
			desc = "",
			type = "select",
			values = SkuNav.RoutesMaxDistances,
		},
	}
}
---------------------------------------------------------------------------------------------------------------------------------------
SkuNav.defaults = {
	enable = true,
	--[[
	includeDefaultMapWaypoints = true,
	includeDefaultInkeeperWaypoints = true,
	includeDefaultPostboxWaypoints = true,
	includeDefaultTaxiWaypoints = true,
	]]
	beaconVolume = 35,
	beaconSoundSetNarrow = "Beacon 2",
	beaconSoundSetWide = "Beacon 4",
	beaconSoundSetLast = "Beacon 3",
	vocalizeFullDirectionDistance = true,
	vocalizeZoneNames = true,
	showRoutesOnMinimap = false,
	showSkuMM = false,
	nearbyWpRange = 30,
	tomtomWp = false,
	standardWpReachedRange = 4,
	clickClackEnabled = true,
	clickClackRange = 5,
	clickClackSoundset = "click",
	autoGlobalDirection = false,
	showGlobalDirectionInWaypointLists = true,
	trackVisited = true,
	timeForVisitedToExpire = 6, -- 5 minutes
	showGatherWaypoints = false,
	autoNextWaypoint = {
		nonVocalized = true,
		reachRange = 3,
	},
	outputDistance = 0,
	routesMaxDistance = Sku.isForever and 3000 or 5000,
}

-- Settings schema for SkuNav (Sku 42 rework, W2 M-C1 / W1 Phase C). Single
-- source of truth (scope/default/type) for the menu's schema-managed get/set.
-- All keys profile scope (the menu's options.args only touch SkuSettings:Sub(
-- "SkuNav") -- profile). Kept nodes (beaconSoundSetNarrow/Wide/Last transform the
-- value + play a sample beacon; showGatherWaypoints rebuilds the waypoint cache)
-- still carry inline get/set, but are declared here too for completeness.
-- Select value tables are keyed by the stored value: StandardWpReachedRanges,
-- timeForVisitedToExpireValues and RoutesMaxDistances use number keys (=> number),
-- ClickClackSoundsets and the beacon sets use string keys (=> string).
SkuSettings:Register("SkuNav", {
	["beaconVolume"]                       = { scope = "profile", default = 35,         type = "number"  },
	["beaconSoundSetNarrow"]               = { scope = "profile", default = "Beacon 2", type = "string"  },
	["beaconSoundSetWide"]                 = { scope = "profile", default = "Beacon 4", type = "string"  },
	["beaconSoundSetLast"]                 = { scope = "profile", default = "Beacon 3", type = "string"  },
	["clickClackEnabled"]                  = { scope = "profile", default = true,       type = "boolean" },
	["clickClackRange"]                    = { scope = "profile", default = 5,          type = "number"  },
	["clickClackSoundset"]                 = { scope = "profile", default = "click",    type = "string"  },
	["vocalizeFullDirectionDistance"]      = { scope = "profile", default = true,       type = "boolean" },
	["vocalizeZoneNames"]                  = { scope = "profile", default = true,       type = "boolean" },
	["nearbyWpRange"]                      = { scope = "profile", default = 30,         type = "number"  },
	["standardWpReachedRange"]             = { scope = "profile", default = 4,          type = "number"  },
	["autoGlobalDirection"]                = { scope = "profile", default = false,      type = "boolean" },
	["showGlobalDirectionInWaypointLists"] = { scope = "profile", default = true,       type = "boolean" },
	["trackVisited"]                       = { scope = "profile", default = true,       type = "boolean" },
	["timeForVisitedToExpire"]             = { scope = "profile", default = 6,          type = "number"  },
	["showGatherWaypoints"]                = { scope = "profile", default = false,      type = "boolean" },
	["showRoutesOnMinimap"]                = { scope = "profile", default = false,      type = "boolean" },
	["showSkuMM"]                          = { scope = "profile", default = false,      type = "boolean" },
	["tomtomWp"]                           = { scope = "profile", default = false,      type = "boolean" },
	["autoNextWaypoint.nonVocalized"]      = { scope = "profile", default = true,       type = "boolean" },
	["autoNextWaypoint.reachRange"]        = { scope = "profile", default = 3,          type = "number"  },
	["outputDistance"]                     = { scope = "profile", default = 0,          type = "number"  },
	["routesMaxDistance"]                  = { scope = "profile", default = Sku.isForever and 3000 or 5000, type = "number"  },
})

local sfind = string.find

---------------------------------------------------------------------------------------------------------------------------------------
local function SkuSpairs(t, order)
	local tSFunction = function(a,b) return order(t, a, b) end
	local keys = {}
	for k in pairs(t) do keys[#keys+1] = k end
	if order then
		table.sort(keys, tSFunction)
	else
		table.sort(keys)
	end
	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- (string, optional<string>) -> string
function SkuNav:getAnnotatedWaypointLabel(originalLabel, id)
	--print("getAnnotatedWaypointLabel", originalLabel, id)

	local tSkuWpName = id or ssub(originalLabel, string.find(originalLabel, "#") + 1)

	--layer
	local tLayerText = SkuNav:GetLayerText(SkuNav:GetNonAutoLevel(nil, nil, tSkuWpName, nil))

	-- Build the prefix (visited marker + layer). Both pieces end in ";", which
	-- would otherwise glue directly onto originalLabel's leading distance number
	-- (e.g. "E 0;2 Meter") — some TTS voices then spell that number digit by
	-- digit. Insert a space after the prefix so the distance is never glued to a
	-- semicolon. No prefix (no layer, not visited) → return the label unchanged.
	local tPrefix = tLayerText
	if SkuNav:waypointWasVisited(tSkuWpName) then
		tPrefix = L["visited"]..";"..tPrefix
	end

	if tPrefix ~= "" then
		return tPrefix.." "..originalLabel
	end
	return originalLabel
end

-- [Engine route, Forever 13.11.2026] Floor question at the entry point. Forever tells Sku no height, so where several floors are
-- possible at the player's position (Engine:FloorChoices) the entry point gets a level of its own: the floors from the lowest up,
-- and only below the floor the target list of the entry point. The target entries carry the floor (self.floorZ of the level they
-- are built on -> engineTarget.floorZ), the engine routes from that floor. A clear floor: nothing changes.
local function SkuNav_WrapEntryWithFloors(aNode, aFloors)
	local tBuild = aNode.BuildChildren
	local tSorting = aNode.sorting
	aNode.sorting = nil
	aNode.BuildChildren = function(self)
		local tN = #aFloors
		for i, tZ in ipairs(aFloors) do
			local tDe = (Sku.Loc == "deDE")
			local tPos = ""
			if tN > 1 and i == 1 then tPos = tDe and ", unterste" or ", lowest" end
			if tN > 1 and i == tN then tPos = tDe and ", oberste" or ", highest" end
			local tLabel = (tDe and "Ebene " or "Floor ")..i..(tDe and " von " or " of ")..tN..tPos
			local tFloor = SkuOptions:InjectMenuItems(self, {tLabel}, SkuGenericMenuItem)
			tFloor.dynamic = true
			tFloor.sorting = tSorting
			tFloor.floorZ = tZ
			tFloor.BuildChildren = tBuild
		end
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- [Engine route, Forever 13.11.2026] "Nearby routes" of a waypoint: where Sku has no route from its entry points to the target (or
-- the target is an engine target that is no Sku waypoint at all), the entry "<distance> Meter#<target>;Engine" stands in the list.
-- Picking it lets the engine compute the way from where the player stands (SkuNav.RouteFollowOnAction does the following).
local function SkuNav_AddEngineRouteLeaf(aParent, aName, aX, aY)
	local tPlayX, tPlayY = UnitPosition("player")
	local tDist = math.floor(math.sqrt((aX - tPlayX) ^ 2 + (aY - tPlayY) ^ 2))
	local tLabel = tDist..L[";Meter"].."#"..aName
	if string.sub(aName, -7) ~= ";Engine" then tLabel = tLabel..";Engine" end
	local tLeaf = SkuOptions:InjectMenuItems(aParent, {tLabel}, SkuGenericMenuItem)
	-- Floor question (like the entry points of Shift-F10): where the player's floor is unclear (Engine:FloorChoices) the engine entry
	-- gets the floors below it, and below a floor the route (the target) to pick. A clear floor: the entry is a plain leaf.
	local tFloors = SkuNav.Engine and SkuNav.Engine:FloorChoices()
	if tFloors then
		tLeaf.BuildChildren = function(self)
			local tFloor = self.floorZ
			local tRoute = SkuOptions:InjectMenuItems(self, {tDist..L[";Meter"].."#"..aName..((string.sub(aName, -7) ~= ";Engine") and ";Engine" or "")}, SkuGenericMenuItem)
			tRoute.OnEnter = function(self)
				SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_CloseRoute = nil
				SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_EngineTarget = {x = aX, y = aY, name = aName, floorZ = tFloor}
			end
		end
		SkuNav_WrapEntryWithFloors(tLeaf, tFloors)
		tLeaf.dynamic = true
		return tLeaf
	end
	tLeaf.OnEnter = function(self)
		SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_CloseRoute = nil
		SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_EngineTarget = {x = aX, y = aY, name = aName}
	end
	return tLeaf
end

-- [Entry points, Forever 13.11.2026] Engine entry points under the Sku entry points of a target's route list ("Nearby routes", the
-- quest menus): up to 3 (the nearest points of the engine's data, Engine:EntryPoints), always, labelled "... Engine". Under an entry
-- the target(s) as engine leaves: picking one lets the engine compute the way from where the player stands, on the floor of the
-- entry point. aTargets = {{name =, x =, y =}, ...} (targets inside the engine zone only; nearest ten are shown).
-- [Forever] Number of Sku entry points: 4 where the engine adds its own below them (the engine covers the player's map), else the old
-- number (aOld: 6 for Shift-F10, 10 for the other lists).
function SkuNav.MaxSkuEntryPoints(aOld)
	if Sku.isForever and SkuNav.Engine and SkuNav.Engine:PlayerInZone() then return 4 end
	return aOld
end

function SkuNav.AddEngineEntryPointsForTargets(aParent, aTargets, aMax)
	if not (SkuNav.Engine and SkuNav.Engine:PlayerInZone()) then return 0 end
	local tTargets = {}
	local tPlayX, tPlayY = UnitPosition("player")
	for _, t in ipairs(aTargets or {}) do
		if t.x and t.y and SkuNav.Engine:PointInZone(t.x, t.y) then
			tTargets[#tTargets + 1] = {name = t.name, x = t.x, y = t.y, dist = math.floor(math.sqrt((t.x - tPlayX) ^ 2 + (t.y - tPlayY) ^ 2))}
		end
	end
	if #tTargets == 0 then return 0 end
	table.sort(tTargets, function(a, b) return a.dist < b.dist end)
	local tPoints = SkuNav.Engine:EntryPoints(aMax or 3)
	for _, tP in ipairs(tPoints) do
		local tEntry = SkuOptions:InjectMenuItems(aParent, {((Sku.Loc == "deDE") and "Einstiegspunkt " or "Entry point ")..tP.dist..L[";Meter"].."#"..tP.name..";Engine"}, SkuGenericMenuItem)
		tEntry.dynamic = true
		tEntry.sorting = true
		tEntry.BuildChildren = function(self)
			local tFloorZ = self.floorZ
			for i, t in ipairs(tTargets) do
				if i > 10 then break end
				local tLeaf = SkuOptions:InjectMenuItems(self, {t.dist..L[";Meter"].."#"..t.name..((string.sub(t.name, -7) ~= ";Engine") and ";Engine" or "")}, SkuGenericMenuItem)
				tLeaf.OnEnter = function(self)
					SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_CloseRoute = nil
					SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_EngineTarget = {x = t.x, y = t.y, name = t.name, floorZ = tFloorZ}
				end
			end
		end
		local tFl = SkuNav.Engine:FloorChoices()
		if tFl then SkuNav_WrapEntryWithFloors(tEntry, tFl) end
	end
	return #tPoints
end

-- same for a list of Sku waypoint names (the quest menus): the targets are the waypoints' own positions
function SkuNav.AddEngineEntryPointsForWpNames(aParent, aNames)
	local tTargets = {}
	for _, tName in ipairs(aNames or {}) do
		local tData = SkuNav:GetWaypointData2(tName)
		if tData and tData.worldX then tTargets[#tTargets + 1] = {name = tName, x = tData.worldX, y = tData.worldY} end
	end
	return SkuNav.AddEngineEntryPointsForTargets(aParent, tTargets)
end

-- [Quest book, Forever 15.11.2026] The engine target next to the Sku targets: under every Sku entry point of the quest book route
-- lists the engine way to the same NPC is offered as an entry "<distance> Meter#<name>;Engine" (the engine computes the way from where
-- the player stands; where the player's floor is unclear the floor question follows, as with the engine entry points). Without it a
-- Sku route that does not lead to the NPC (Tower of Azora, other floors) had no alternative under the Sku entry points. Up to aMax (3)
-- nearest waypoints of the names that lie in the engine zone.
function SkuNav.AddEngineLeavesForWpNames(aParent, aNames, aMax)
	if not (Sku.isForever and SkuNav.Engine and SkuNav.Engine:PlayerInZone()) then return 0 end
	local tPlayX, tPlayY = UnitPosition("player")
	if type(tPlayX) ~= "number" or type(tPlayY) ~= "number" then return 0 end
	local tTargets = {}
	for _, tName in ipairs(aNames or {}) do
		local tData = SkuNav:GetWaypointData2(tName)
		if tData and tData.worldX and SkuNav.Engine:PointInZone(tData.worldX, tData.worldY) then
			tTargets[#tTargets + 1] = {name = tName, x = tData.worldX, y = tData.worldY, dist = (tData.worldX - tPlayX) ^ 2 + (tData.worldY - tPlayY) ^ 2}
		end
	end
	table.sort(tTargets, function(a, b) return a.dist < b.dist end)
	local rCount = 0
	for _, t in ipairs(tTargets) do
		if rCount >= (aMax or 3) then break end
		SkuNav_AddEngineRouteLeaf(aParent, t.name, t.x, t.y)
		rCount = rCount + 1
	end
	return rCount
end

---------------------------------------------------------------------------------------------------------------------------------------
local function SkuNav_MenuBuilder_WaypointSelectionMenu(aParent, aSortedWaypointList)
	--dprint("SkuNav_MenuBuilder_WaypointSelectionMenu")
	for i, waypointName in pairs(aSortedWaypointList) do
		local tNewMenuEntry = SkuOptions:InjectMenuItems(aParent, {SkuNav:getAnnotatedWaypointLabel(waypointName)}, SkuGenericMenuItem)
		tNewMenuEntry.dynamic = true
		tNewMenuEntry.BuildChildren = function(self)
			SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_NPC = nil
			SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_CloseRoute = nil
			SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_EngineTarget = nil

			--select wp
			local tNewMenuEntrySub = SkuOptions:InjectMenuItems(self, {L["Auswählen"]}, SkuGenericMenuItem)
			tNewMenuEntrySub.OnEnter = function(self)
				SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_NPC = waypointName
				SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_EngineTarget = nil
			end

			--close rts
			local tNewMenuEntrySub = SkuOptions:InjectMenuItems(self, {L["Nahe Routen"]}, SkuGenericMenuItem)
			tNewMenuEntrySub.dynamic = true
			-- Option 2: the nearby-routes list streams in as data arrives;
			-- mark it volatile so navigating the list silently re-reads it.
			tNewMenuEntrySub.volatileChildren = true
			tNewMenuEntrySub.BuildChildren = function(self)
				local tPlayX, tPlayY = UnitPosition("player")
				local tRoutesInRange = SkuNav:GetAllLinkedWPsInRangeToCoords(tPlayX, tPlayY, SkuNav.MaxMetaEntryRange)--SkuSettings:Sub("SkuNav").nearbyWpRange)
				if string.find(SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_NPC, "#") then
					SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_NPC = ssub(SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_NPC, string.find(SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_NPC, "#") + 1)
				end
				local wpTable = {SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_NPC}
				local tMaxAllowedDistanceToTargetWp = 500
				-- an engine target (F9 entry ";Engine") is no Sku waypoint yet: Sku has no routes to it, only the engine way is offered
				local tEnginePending = SkuNav.Engine and SkuNav.Engine.pendingWaypoints and SkuNav.Engine.pendingWaypoints[wpTable[1]]
				if tEnginePending then
					if SkuNav.Engine:PlayerInZone() then
						if SkuNav.AddEngineEntryPointsForTargets(self, {{name = wpTable[1], x = tEnginePending.x, y = tEnginePending.y}}, 6) == 0 then
							SkuNav_AddEngineRouteLeaf(self, wpTable[1], tEnginePending.x, tEnginePending.y)
						end
					else
						SkuNav:InjectWpListEmptyHint(self)
					end
					return
				end
				local tSortedWaypointList = BuildSortedUniqueRouteWps(tRoutesInRange)
				local tFloors = SkuNav.Engine and SkuNav.Engine:FloorChoices()
				-- Sku's way to the target from its nearest entry point? Otherwise the engine entry follows (same test as the engine entry
				-- point of the route list: only where Sku has no route).
				local tTargetData = SkuNav:GetWaypointData2(wpTable[1])
				local tEngineLeafWanted = false
				if tTargetData and tTargetData.worldX and SkuNav.Engine and SkuNav.Engine:PlayerInZone() and SkuNav.Engine:PointInZone(tTargetData.worldX, tTargetData.worldY) then
					tEngineLeafWanted = true
					local tFirstEntry = tSortedWaypointList[1]
					if tFirstEntry and string.find(tFirstEntry, "#") then
						local tReach = SkuNav:GetAllMetaTargetsFromWp5(ssub(tFirstEntry, string.find(tFirstEntry, "#") + 1), SkuSettings:Sub("SkuNav").routesMaxDistance, SkuNav.MaxMetaWPs, nil, true)
						for _, tNear in ipairs(SkuNav:GetNearestWpsWithLinksToWp(wpTable[1], 10, tMaxAllowedDistanceToTargetWp) or {}) do
							if tReach[tNear.wpName] then tEngineLeafWanted = false break end
						end
					end
				end
				if #tSortedWaypointList == 0 then
					if tEngineLeafWanted then
						if SkuNav.AddEngineEntryPointsForTargets(self, {{name = wpTable[1], x = tTargetData.worldX, y = tTargetData.worldY}}, 6) == 0 then
							SkuNav_AddEngineRouteLeaf(self, wpTable[1], tTargetData.worldX, tTargetData.worldY)
						end
					else
						SkuNav:InjectWpListEmptyHint(self)
					end
				else
					local tCount = 0
					for k, v in SkuSpairs(tSortedWaypointList) do
						if tCount < SkuNav.MaxSkuEntryPoints(10) then
							local tSkuWpName = ssub(v, string.find(v, "#") + 1)
							local tLayerText = SkuNav:GetLayerText(SkuNav:GetNonAutoLevel(nil, nil, tSkuWpName, nil))

							local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Entry point: "]..tLayerText..v}, SkuGenericMenuItem)
							tNewMenuEntry.dynamic = true
							tNewMenuEntry.sorting = true
							tNewMenuEntry.BuildChildren = function(self)
								if #tSortedWaypointList == 0 then
									SkuNav:InjectWpListEmptyHint(self)
								else
									SkuNav:BackupFollowState()
									local tMetapaths = SkuNav:GetAllMetaTargetsFromWp5(ssub(v, string.find(v, "#") + 1), SkuSettings:Sub("SkuNav").routesMaxDistance, SkuNav.MaxMetaWPs, nil, true)
									SkuSettings:Sub("SkuNav").metapathFollowingStart = v
									SkuSettings:Sub("SkuNav").metapathFollowingMetapaths = tMetapaths
									SkuSettings:Sub("SkuNav").metapathFollowingTarget = nil

									local tResults = {}
									for wpIndex, wpName in pairs(wpTable) do
										local tNearWps = SkuNav:GetNearestWpsWithLinksToWp(wpName, 10, tMaxAllowedDistanceToTargetWp)
										local tBestRouteWeightedLength = 100000
										for x = 1, #tNearWps do
											if tMetapaths[tNearWps[x].wpName] then
												local EndMetapathWpObj = SkuNav:GetWaypointData2(tNearWps[x].wpName)
												local tEndTargetWpObj = SkuNav:GetWaypointData2(wpName)
												local tDistToEndTargetWp = SkuNav:Distance(EndMetapathWpObj.worldX, EndMetapathWpObj.worldY, tEndTargetWpObj.worldX, tEndTargetWpObj.worldY)

												local tDirectionTargetWp = ""
												if SkuSettings:Sub("SkuNav").showGlobalDirectionInWaypointLists == true then
													local tDirectionString = SkuNav:GetDirectionToAsString(tEndTargetWpObj.worldX, tEndTargetWpObj.worldY)
													if tDirectionString then
														tDirectionTargetWp = ";"..tDirectionString
													end
												end

												if (tMetapaths[tNearWps[x].wpName].distance / SkuNav.BestRouteWeightedLengthModForMetaDistance) + tDistToEndTargetWp < tBestRouteWeightedLength then
													tBestRouteWeightedLength = (tMetapaths[tNearWps[x].wpName].distance / SkuNav.BestRouteWeightedLengthModForMetaDistance) + tDistToEndTargetWp
													tResults[wpName] = {
														metarouteIndex = tNearWps[x].wpName,
														metapathLength = tMetapaths[tNearWps[x].wpName].distance,
														distanceTargetWp = tNearWps[x].distance,
														targetWpName = wpName,
														weightedDistance = tBestRouteWeightedLength,
														direction = tDirectionTargetWp,
													}
												end
											end
										end
									end

									do -- build choices
										local tSortedList = {}
										for k,v in SkuSpairs(tResults, function(t,a,b) return t[b].weightedDistance > t[a].weightedDistance end) do
											table.insert(tSortedList, k)
										end
										if #tSortedList == 0 then
											SkuNav:InjectWpListEmptyHint(self)
										else
											for tK, tV in ipairs(tSortedList) do
												local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {tResults[tV].metapathLength..";"..L["plus"]..";"..tResults[tV].distanceTargetWp..L[";Meter"]..tResults[tV].direction.."#"..tV}, SkuGenericMenuItem)
												tNewMenuEntry.OnEnter = function(self, aValue, aName)
													SkuSettings:Sub("SkuNav").metapathFollowingTarget = tResults[tV].metarouteIndex
													SkuSettings:Sub("SkuNav").metapathFollowingEndTarget = tResults[tV].targetWpName
													SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_EngineTarget = nil
													SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_CloseRoute = true
												end
											end
										end
									end
								end
							end
							if tFloors then SkuNav_WrapEntryWithFloors(tNewMenuEntry, tFloors) end
							tCount = tCount + 1
						end
					end
					-- Forever: below the (at most 4) Sku entry points ALWAYS up to 3 engine entry points (labelled "Engine")
					if tTargetData and tTargetData.worldX then
						if SkuNav.AddEngineEntryPointsForTargets(self, {{name = wpTable[1], x = tTargetData.worldX, y = tTargetData.worldY}}) == 0 and tEngineLeafWanted then
							SkuNav_AddEngineRouteLeaf(self, wpTable[1], tTargetData.worldX, tTargetData.worldY)
						end
					end
				end

			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
-- Shared navigation menu builders/actions, hoisted to module scope so BOTH the
-- normal Nav menu AND the dedicated Shift-F9/Shift-F10 quick entries
-- (SkuNav:UpdateQuickRootEntry) can reuse them without duplicating logic and
-- without walking a localized menu path. Behaviour is identical to the former
-- inline closures they were extracted from.

-- Waypoint selection action (the "Auswählen" isSelect target): selects the
-- chosen waypoint / closes a route, exactly as before.
function SkuNav.WaypointSelectOnAction(self, aValue, aName)
			--dprint("OnAction Auswählen", self.name,aValue,  aName, SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_NPC, SkuSettings:Sub("SkuNav").metapathFollowingStart)
			if SkuSettings:Sub("SkuNav").routeRecording == true then
				SkuOptions.Voice:OutputStringBTtts(L["Error"], false, true, 0.3, true)
				SkuOptions.Voice:OutputStringBTtts(L["Recording in progress"], false, true, 0.3, true)
				return
			end

			-- [Engine route] the engine entry of "Nearby routes" was picked: the engine computes the way
			local tEngineTarget = SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_EngineTarget
			if tEngineTarget then
				SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_EngineTarget = nil
				SkuNav.RouteFollowOnAction(self, {engineTarget = tEngineTarget}, tEngineTarget.name)
				return
			end

			if SkuSettings:Sub("SkuNav").metapathFollowing == true or SkuSettings:Sub("SkuNav").selectedWaypoint ~= "" then
				SkuNav:EndFollowingWpOrRt()
			end

			if SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_CloseRoute then
				--close rt
				SkuSettings:Sub("SkuNav").metapathFollowing = false
				if SkuSettings:Sub("SkuNav").metapathFollowingStart then
					if SkuSettings:Sub("SkuNav").metapathFollowingMetapaths then
						if string.find(SkuSettings:Sub("SkuNav").metapathFollowingStart, "#") then
							SkuSettings:Sub("SkuNav").metapathFollowingStart = ssub(SkuSettings:Sub("SkuNav").metapathFollowingStart, string.find(SkuSettings:Sub("SkuNav").metapathFollowingStart, "#") + 1)
						end
						SkuSettings:Sub("SkuNav").metapathFollowingMetapaths = SkuNav:GetAllMetaTargetsFromWp5(SkuSettings:Sub("SkuNav").metapathFollowingStart, SkuSettings:Sub("SkuNav").routesMaxDistance, SkuNav.MaxMetaWPs, SkuSettings:Sub("SkuNav").metapathFollowingTarget, true)--
						SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[#SkuSettings:Sub("SkuNav").metapathFollowingMetapaths+1] = SkuSettings:Sub("SkuNav").metapathFollowingEndTarget
						SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[SkuSettings:Sub("SkuNav").metapathFollowingEndTarget] = SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[SkuSettings:Sub("SkuNav").metapathFollowingTarget]
						table.insert(SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[SkuSettings:Sub("SkuNav").metapathFollowingEndTarget].pathWps, SkuSettings:Sub("SkuNav").metapathFollowingEndTarget)
						SkuSettings:Sub("SkuNav").metapathFollowingTarget = SkuSettings:Sub("SkuNav").metapathFollowingEndTarget
						
						local tBaseName = SkuNav:StripBaseNameFromWaypointName(SkuSettings:Sub("SkuNav").metapathFollowingTarget)
						if tBaseName then
							SkuNav.lastSelectedWaypointFullName = SkuSettings:Sub("SkuNav").metapathFollowingTarget
						end						
						
						SkuSettings:Sub("SkuNav").metapathFollowingCurrentWp = 1
						SkuSettings:Sub("SkuNav").metapathFollowing = true
						SkuNav:SelectWP(SkuSettings:Sub("SkuNav").metapathFollowingStart, true)
						SkuOptions.Voice:OutputStringBTtts(L["Metaroute folgen gestartet"], false, true, 0.2)
						SkuOptions:CloseMenu()
						SkuDispatcher:TriggerSkuEvent("SKU_CLOSEROUTE_STARTED")
					end
				end
			else
				--just a wp
				if aName == L["Auswählen"] and SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_NPC then
					local tUncleanValue = SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_NPC
					local tCleanValue = SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_NPC
					local tPos = string.find(tUncleanValue, "#")
					if tPos then
						tCleanValue = ssub(tUncleanValue,  tPos + 1)
					end
					aName = tCleanValue
				end

				if (SkuOptions.tmpNpcWayPointNameBuilder_Npc and SkuOptions.tmpNpcWayPointNameBuilder_Npc ~= "") and (SkuOptions.tmpNpcWayPointNameBuilder_Npc and SkuOptions.tmpNpcWayPointNameBuilder_Zone ~= "") then
					aName = SkuOptions.tmpNpcWayPointNameBuilder_Npc..";"..SkuOptions.tmpNpcWayPointNameBuilder_Zone..";"..aName
					SkuOptions.tmpNpcWayPointNameBuilder_Npc = ""
					SkuOptions.tmpNpcWayPointNameBuilder_Zone = ""
					SkuOptions.tmpNpcWayPointNameBuilder_Coords = ""
				end

				if SkuNav.Engine then SkuNav.Engine:EnsureTempWaypoint(aName) end

				if SkuNav:GetWaypointData2(aName) then
					local tBaseName = SkuNav:StripBaseNameFromWaypointName(aName)
					if tBaseName then
						SkuNav.lastSelectedWaypointFullName = aName
					end

					SkuNav:SelectWP(aName)
					--dprint("auswahl", aName)
					--lastDirection = SkuNav:GetDirectionTo(worldx, worldy, SkuNav:GetWaypointData2(SkuSettings:Sub("SkuNav").selectedWaypoint).worldX, SkuNav:GetWaypointData2(SkuSettings:Sub("SkuNav").selectedWaypoint).worldY)
					--PlaySound(835)
					SkuOptions:CloseMenu()
					SkuDispatcher:TriggerSkuEvent("SKU_WAYPOINT_STARTED")
				else
					SkuOptions.Voice:OutputStringBTtts(L["Error"], false, true, 0.3, true)
					SkuOptions.Voice:OutputStringBTtts(L["Wegpunkt nicht ausgewählt"], false, true, 0.3, true)
				end
			end
end

-- Builds the "current map, by distance" waypoint list into aParentNode.
function SkuNav.WaypointsCurrentMapBuildChildren(self)
	local tAutoLen = slen(L["auto"]) + 1
				SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_CloseRoute = nil
				local tCurrentAreaId = SkuNav:GetAreaIdFromUiMapId(SkuNav:GetBestMapForUnit("player"))
				local tSubAreaIds = SkuNav:GetSubAreaIds(tCurrentAreaId)
				tSubAreaIds[tCurrentAreaId] = tCurrentAreaId

				local tWaypointList = {}
				local tSkuWpPositions = {}
				-- unsorted and fetched once: the result is sorted by distance below anyway (before: two sorted calls, 11.11.2026)
				local tListWPs, tListState, tListInit = SkuNav:ListWaypoints2(false, nil, tCurrentAreaId)
				if tListWPs then
					local tPlayX, tPlayY = UnitPosition("player")
					for i, v in tListWPs, tListState, tListInit do
						local tWayP = SkuNav:GetWaypointData2(v)
						if tWayP then
							if tSubAreaIds[tonumber(tWayP.areaId)] then
								if ssub(v, 1, tAutoLen) ~= L["auto"].." " then
								--if not sfind(v, L["auto"]..";") then
								--if not sfind(v, L["Quick waypoint"]) and not sfind(v, "auto;") then
									local tWpX, tWpY = tWayP.worldX, tWayP.worldY
									local tDistance, _  = SkuNav:Distance(tPlayX, tPlayY, tWpX, tWpY)
									-- add direction to wp
									local tDirectionTargetWp = ""
									if SkuSettings:Sub("SkuNav").showGlobalDirectionInWaypointLists == true then
										local tDirectionString = SkuNav:GetDirectionToAsString(tWpX, tWpY)
										if tDirectionString then
											tDirectionTargetWp = ";"..tDirectionString
										end
									end									
									tWaypointList[v] = {distance = tDistance, direction = tDirectionTargetWp,}
									tSkuWpPositions[#tSkuWpPositions + 1] = {tWpX, tWpY}
								end
							end
						end
					end
				end
				-- [Engine route, Forever prototype 12.11.2026] targets that Sku offers no waypoint for (none within 30 yd), marked "Engine"
				if SkuNav.Engine and SkuNav.Engine:PlayerInZone() then
					for _, tE in ipairs(SkuNav.Engine:ListWaypointTargets(tSkuWpPositions)) do
						local tDirE = ""
						if SkuSettings:Sub("SkuNav").showGlobalDirectionInWaypointLists == true then
							local tDirString = SkuNav:GetDirectionToAsString(tE.x, tE.y)
							if tDirString then tDirE = ";"..tDirString end
						end
						tWaypointList[tE.key] = {distance = tE.dist, direction = tDirE,}
					end
				end
				for q = 1, 4 do
					local tWayP = SkuNav:GetWaypointData2(L["Quick waypoint"]..";"..q)
					if tWayP then
						if tSubAreaIds[tonumber(tWayP.areaId)] then
							local tWpX, tWpY = tWayP.worldX, tWayP.worldY
							local tPlayX, tPlayY = UnitPosition("player")
							local tDistance, _  = SkuNav:Distance(tPlayX, tPlayY, tWpX, tWpY)
							-- add direction to wp
							local tDirectionTargetWp = ""
							if SkuSettings:Sub("SkuNav").showGlobalDirectionInWaypointLists == true then
								local tDirectionString = SkuNav:GetDirectionToAsString(tWpX, tWpY)
								if tDirectionString then
									tDirectionTargetWp = ";"..tDirectionString
								end
							end									
							tWaypointList[L["Quick waypoint"]..";"..q] = {distance = tDistance, direction = tDirectionTargetWp,}
						end
					end
				end

				local tSortedWaypointList = {}
				for k,v in SkuSpairs(tWaypointList, function(t,a,b) return t[b].distance > t[a].distance end) do --nach wert
					table.insert(tSortedWaypointList, v.distance..L[";Meter"]..v.direction.."#"..k)
				end
				if #tSortedWaypointList == 0 then
					SkuNav:InjectWpListEmptyHint(self)
				else
					--local tNewMenuEntry = SkuOptions:InjectMenuItems(self, tSortedWaypointList, SkuGenericMenuItem)
					SkuNav_MenuBuilder_WaypointSelectionMenu(self, tSortedWaypointList)
				end
end

-- Starts following the selected route / unit route (the isSelect target for the
-- route-destination and unit-route lists).
function SkuNav.RouteFollowOnAction(self, aValue, aName)
		dprint("OnAction", self.name, aValue, aName)

		SkuNav:ClearWaypointsTemporary()

		if SkuSettings:Sub("SkuNav").routeRecording == true then
			SkuOptions.Voice:OutputStringBTtts(L["Error"], false, true, 0.3, true)
			SkuOptions.Voice:OutputStringBTtts(L["Recording in progress"], false, true, 0.3, true)
			return
		end

		--if SkuSettings:Sub("SkuNav").metapathFollowing == true or SkuSettings:Sub("SkuNav").selectedWaypoint ~= "" then
		if SkuSettings:Sub("SkuNav").metapathFollowing == true or SkuSettings:Sub("SkuNav").selectedWaypoint ~= "" then
			SkuNav:EndFollowingWpOrRt()
		end

		SkuSettings:Sub("SkuNav").metapathFollowing = false


		SkuSettings:Sub("SkuNav").metapathFollowingStart = SkuSettings:Sub("SkuNav").metapathFollowingStartTMP
		SkuSettings:Sub("SkuNav").metapathFollowingMetapaths = SkuMetapathFollowingMetapathsTMP

		-- [Engine route, Forever prototype 12.11.2026] a list entry of the engine targets: the engine computes the way, the
		-- unit route ("Einheiten Route") below follows it. Sku's own routes are not touched. No route -> say why, stop.
		SkuNav.engineWorldPoints = nil
		-- (the menu calls OnAction on the select target with the picked entry as aValue)
		local tEngineTarget = (type(aValue) == "table" and aValue.engineTarget) or (self and self.engineTarget)
		if tEngineTarget then
			if not (SkuNav.Engine and SkuNav.Engine:PrepareFollow(tEngineTarget)) then
				return
			end
		end

		if SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypoint == true and SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData then
			if #SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData < 2 then
				return
			end
			-- without a world position every route point would silently fall back to the player's position
			local tUiMap = SkuNav:GetUiMapIdFromAreaId(SkuNav:GetAreaIdFromUiMapId(SkuNav:GetBestMapForUnit("player")))
			if not SkuNav.engineWorldPoints and not SkuNav:WorldFromMap(tUiMap, 0.5, 0.5) then
				dprint("RouteFollowOnAction: no world position for map", tUiMap)
				SkuOptions.Voice:OutputStringBTtts(L["Error"], false, true, 0.3, true)
				return
			end

			-- the "<name> visible / not visible" call is for units that move (quest unit routes); an engine route leads to a fixed place
			if SkuNav.engineWorldPoints then
				SkuSettings:Sub("SkuNav").metapathFollowingTargetName = nil
			elseif string.find(aName, ";") then
				SkuSettings:Sub("SkuNav").metapathFollowingTargetName = ssub(aName, 1, string.find(aName, ";") - 1)
			end
			
			SkuSettings:Sub("SkuNav").metapathFollowingStart = L["Einheiten;Route;"].."1"
			SkuSettings:Sub("SkuNav").metapathFollowingTarget = L["Einheiten;Route;"]..#SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData
			SkuSettings:Sub("SkuNav").metapathFollowingMetapaths = {}
			SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[1] = SkuSettings:Sub("SkuNav").metapathFollowingTarget
			SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[SkuSettings:Sub("SkuNav").metapathFollowingTarget] = {
				pathWps = {},
				distance = 0,
			}
				
			--build metaroute table
			for x = 1, #SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData do
				--create tmp wps
				local tCurrentAreaId = SkuNav:GetAreaIdFromUiMapId(SkuNav:GetBestMapForUnit("player"))
				local isUiMap = SkuNav:GetUiMapIdFromAreaId(tCurrentAreaId)
				local tX, tY
				if SkuNav.engineWorldPoints then
					tX, tY = SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData[x][1], SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData[x][2]
				else
					tX, tY = SkuNav:WorldFromMap(isUiMap, SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData[x][1] / 100, SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData[x][2] / 100)
				end
				local tNameOfNewWp = SkuNav:CreateWaypoint(L["Einheiten;Route;"]..x, tX, tY, 1, true, true)
				if tNameOfNewWp then
					--add to mt rt
					SkuSettings:Sub("SkuNav").WaypointsTemporary[#SkuSettings:Sub("SkuNav").WaypointsTemporary + 1] = tNameOfNewWp
					table.insert(SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[SkuSettings:Sub("SkuNav").metapathFollowingTarget].pathWps, tNameOfNewWp)
				end
			end

			local tDistance = 0
			local tDistanceToStartWp = 0
			for z = 2, #SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[SkuSettings:Sub("SkuNav").metapathFollowingTarget].pathWps do
				local tWpA = SkuNav:GetWaypointData2(SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[SkuSettings:Sub("SkuNav").metapathFollowingTarget].pathWps[z - 1])
				local tWpB = SkuNav:GetWaypointData2(SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[SkuSettings:Sub("SkuNav").metapathFollowingTarget].pathWps[z])
				tDistance = tDistance + SkuNav:Distance(tWpA.worldX, tWpA.worldY, tWpB.worldX, tWpB.worldY)
				if tDistanceToStartWp == 0 then
					tDistanceToStartWp = tDistance
				end
			end
			SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[SkuSettings:Sub("SkuNav").metapathFollowingTarget].distance = tDistance
			SkuSettings:Sub("SkuNav").metapathFollowingMetapaths[SkuSettings:Sub("SkuNav").metapathFollowingTarget].distanceToStartWp = tDistanceToStartWp

			SkuNav.engineWorldPoints = nil
			--start follow
			SkuSettings:Sub("SkuNav").metapathFollowingCurrentWp = 1
			SkuSettings:Sub("SkuNav").metapathFollowing = true

			SkuNav:SelectWP(SkuSettings:Sub("SkuNav").metapathFollowingStart, true)
			SkuOptions.Voice:OutputStringBTtts(L["Einheiten Route folgen gestartet"], false, true, 0.2)
			SkuOptions:CloseMenu()
			SkuDispatcher:TriggerSkuEvent("SKU_UNITROUTE_STARTED")
			return
		elseif SkuSettings:Sub("SkuNav").metapathFollowingStart then
			if SkuSettings:Sub("SkuNav").metapathFollowingMetapaths then
				if string.find(SkuSettings:Sub("SkuNav").metapathFollowingStart, "#") then
					SkuSettings:Sub("SkuNav").metapathFollowingStart = ssub(SkuSettings:Sub("SkuNav").metapathFollowingStart, string.find(SkuSettings:Sub("SkuNav").metapathFollowingStart, "#") + 1)
				end
				SkuSettings:Sub("SkuNav").metapathFollowingMetapaths = SkuNav:GetAllMetaTargetsFromWp5(SkuSettings:Sub("SkuNav").metapathFollowingStart, SkuSettings:Sub("SkuNav").routesMaxDistance, SkuNav.MaxMetaWPs, aName)--
				SkuSettings:Sub("SkuNav").metapathFollowingTarget = aName
				SkuSettings:Sub("SkuNav").metapathFollowingCurrentWp = 1
				SkuSettings:Sub("SkuNav").metapathFollowing = true

				local tBaseName = SkuNav:StripBaseNameFromWaypointName(SkuSettings:Sub("SkuNav").metapathFollowingTarget)
				if tBaseName then
					SkuNav.lastSelectedWaypointFullName = SkuSettings:Sub("SkuNav").metapathFollowingTarget
				end
				
				SkuNav:SelectWP(SkuSettings:Sub("SkuNav").metapathFollowingStart, true)
				SkuOptions.Voice:OutputStringBTtts(L["Metaroute folgen gestartet"], false, true, 0.2)

				SkuOptions:CloseMenu()
				SkuDispatcher:TriggerSkuEvent("SKU_ROUTE_STARTED")
			end
		end
end

-- Builds the "nearby route destinations, by distance" list into aParentNode.
function SkuNav.RouteDestinationsBuildChildren(self)
			--SkuSettings:Sub("SkuNav").metapathFollowingMetapaths = nil
			--SkuSettings:Sub("SkuNav").metapathFollowingStart = nil
			SkuSettings:Sub("SkuNav").metapathFollowingStartTMP = nil
			SkuMetapathFollowingMetapathsTMP = nil
			local tPlayX, tPlayY = UnitPosition("player")
			local tRoutesInRange = SkuNav:GetAllLinkedWPsInRangeToCoords(tPlayX, tPlayY, SkuNav.MaxMetaEntryRange)--SkuSettings:Sub("SkuNav").nearbyWpRange)

			local tSortedWaypointList = BuildSortedUniqueRouteWps(tRoutesInRange)
			local tFloors = SkuNav.Engine and SkuNav.Engine:FloorChoices()

			-- [Engine route, Forever 13.11.2026] ALWAYS 4 Sku entry points on top and below them up to 3 engine entry points (the
			-- nearest points of the engine's data, Engine:EntryPoints), wherever the engine covers the player's map. Sku's entries
			-- keep their order and their children; under an engine entry stand the targets Sku reaches from its nearest entry
			-- point plus the targets Sku has no route to; the engine computes the way from where the player stands, on the floor
			-- of the entry point.
			local tEnginePoints = {}
			if SkuNav.Engine and SkuNav.Engine:PlayerInZone() then
				-- where Sku has no entry point at all the engine gets 6 (as before), otherwise 3 below the Sku ones
				tEnginePoints = SkuNav.Engine:EntryPoints(#tSortedWaypointList == 0 and 6 or 3)
			end
			local function tAddEngineEntryPoints()
				for _, tP in ipairs(tEnginePoints) do
					local tDir = ""
					if SkuSettings:Sub("SkuNav").showGlobalDirectionInWaypointLists == true then
						local tDirString = SkuNav:GetDirectionToAsString(tP.x, tP.y)
						if tDirString then tDir = " "..tDirString end
					end
					local tEngineEntry = SkuOptions:InjectMenuItems(self, {((Sku.Loc == "deDE") and "Einstiegspunkt " or "Entry point ")..tP.dist..L[";Meter"]..tDir.."#"..tP.name..";Engine"}, SkuGenericMenuItem)
					tEngineEntry.dynamic = true
					tEngineEntry.sorting = true
					tEngineEntry.BuildChildren = function(self)
						local tPlayX, tPlayY = UnitPosition("player")
						local tReach = {}
						local tFirst = tSortedWaypointList[1]
						if tFirst and string.find(tFirst, "#") then
							tReach = SkuNav:GetAllMetaTargetsFromWp5(ssub(tFirst, string.find(tFirst, "#") + 1), SkuSettings:Sub("SkuNav").routesMaxDistance, SkuNav.MaxMetaWPs)
						end
						local tTargets = {}
						for tName in pairs(tReach) do
							local tData = SkuNav:GetWaypointData2(tName)
							if tData and tData.worldX and SkuNav.Engine:PointInZone(tData.worldX, tData.worldY) then
								tTargets[#tTargets + 1] = {x = tData.worldX, y = tData.worldY, name = tName, kind = ""}
							end
						end
						for _, tT in ipairs(SkuNav.Engine:ListTargets(tReach)) do tTargets[#tTargets + 1] = tT end
						for _, tT in ipairs(tTargets) do
							tT.dist = math.floor(math.sqrt((tT.x - tPlayX) ^ 2 + (tT.y - tPlayY) ^ 2))
						end
						table.sort(tTargets, function(a, b) return a.dist < b.dist end)
						dprint("engineRoute engine entry", "targets", #tTargets)
						if #tTargets == 0 then
							SkuNav:InjectWpListEmptyHint(self)
							return
						end
						for _, tT in ipairs(tTargets) do
							local tDir = ""
							if SkuSettings:Sub("SkuNav").showGlobalDirectionInWaypointLists == true then
								local tDirString = SkuNav:GetDirectionToAsString(tT.x, tT.y)
								if tDirString then tDir = ";"..tDirString end
							end
							local tLabel = tT.dist..L[";Meter"]..tDir.."#"..tT.name..((tT.kind and tT.kind ~= "") and (";"..tT.kind) or "")
							local tChild = SkuOptions:InjectMenuItems(self, {tLabel}, SkuGenericMenuItem)
							tT.floorZ = self.floorZ
							tChild.engineTarget = tT
							tChild.OnEnter = function(self)
								SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypoint = nil
								SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData = nil
							end
						end
					end
					if tFloors then SkuNav_WrapEntryWithFloors(tEngineEntry, tFloors) end
				end
			end

			if #tSortedWaypointList == 0 and #tEnginePoints == 0 then
				SkuNav:InjectWpListEmptyHint(self)
			else
				local tCount = 0
				local tMaxEntryPoints = SkuNav.MaxSkuEntryPoints(Sku.isForever and 6 or 10)
				for k, v in SkuSpairs(tSortedWaypointList) do
					if tCount < tMaxEntryPoints then

						local tSkuWpName = ssub(v, string.find(v, "#") + 1)
						local tLayerText = SkuNav:GetLayerText(SkuNav:GetNonAutoLevel(nil, nil, tSkuWpName, nil))

						local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Entry point: "]..tLayerText..v}, SkuGenericMenuItem)
						tNewMenuEntry.dynamic = true
						tNewMenuEntry.sorting = true
						tNewMenuEntry.BuildChildren = function(self)
							SkuSettings:Sub("SkuNav").metapathFollowingStartTMP = v
							local tMetapaths = SkuNav:GetAllMetaTargetsFromWp5(ssub(v, string.find(v, "#") + 1), SkuSettings:Sub("SkuNav").routesMaxDistance, SkuNav.MaxMetaWPs)--
							SkuMetapathFollowingMetapathsTMP = tMetapaths
							local tData = {}
							for i, v in pairs(tMetapaths) do--
								tData[i] = tMetapaths[i].distance
							end

							local tSortedList = {}
							for k,v in SkuSpairs(tData, function(t,a,b) return t[b] > t[a] end) do
								table.insert(tSortedList, k)
							end
							-- [Engine route, Forever prototype 12.11.2026] targets that Sku has NO route to stand in this same list, sorted in
							-- by distance and marked "Engine". Sku's own entries are unchanged; a target that Sku reaches is never added.
							local tEngineTargets = {}
							if SkuNav.Engine and SkuNav.Engine:Available() then
								tEngineTargets = SkuNav.Engine:ListTargets(tMetapaths)
								dprint("engineRoute list", "engine targets", #tEngineTargets)
							end
							local tEngineNext = 1
							local function tAddEngineTargets(aUpToDist)
								while tEngineTargets[tEngineNext] and (aUpToDist == nil or tEngineTargets[tEngineNext].dist <= aUpToDist) do
									local tT = tEngineTargets[tEngineNext]
									tEngineNext = tEngineNext + 1
									local tDir = ""
									if SkuSettings:Sub("SkuNav").showGlobalDirectionInWaypointLists == true then
										local tDirString = SkuNav:GetDirectionToAsString(tT.x, tT.y)
										if tDirString then tDir = ";"..tDirString end
									end
									local tChild = SkuOptions:InjectMenuItems(self, {tT.dist..L[";Meter"]..tDir.."#"..tT.name..";"..tT.kind..";Engine"}, SkuGenericMenuItem)
									tT.floorZ = self.floorZ
									tChild.engineTarget = tT
									tChild.OnEnter = function(self)
										SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypoint = nil
										SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData = nil
									end
								end
							end
							if #tSortedList == 0 and #tEngineTargets == 0 then
								SkuNav:InjectWpListEmptyHint(self)
							else
								for tK, tV in ipairs(tSortedList) do
									tAddEngineTargets(tMetapaths[tV].distance)
									local tDistText = tMetapaths[tV].distance..L[";Meter"]..""--
									if tMetapaths[tV].distance >= SkuSettings:Sub("SkuNav").routesMaxDistance then
										tDistText = L["weit"]
									end

									-- add direction to wp
									local tDirectionTargetWp = ""
									if SkuSettings:Sub("SkuNav").showGlobalDirectionInWaypointLists == true then
										local tWpData = SkuNav:GetWaypointData2(tV)
										local tDirectionString = SkuNav:GetDirectionToAsString(tWpData.worldX, tWpData.worldY)
										if tDirectionString then
											tDirectionTargetWp = ";"..tDirectionString
										end
									end
									tDistText = tDistText..tDirectionTargetWp									

									local tNewMenuEntry = SkuOptions:InjectMenuItems(self, { SkuNav:getAnnotatedWaypointLabel(tDistText .. "#" .. tV, tV) }, SkuGenericMenuItem) --
									tNewMenuEntry.OnEnter = function(self)
										SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypoint = nil
										SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData = nil
									end
			
								end
								tAddEngineTargets(nil)
							end

						end
						if tFloors then SkuNav_WrapEntryWithFloors(tNewMenuEntry, tFloors) end
						tCount = tCount + 1
					end
				end
				tAddEngineEntryPoints()
			end

end

---------------------------------------------------------------------------------------------------------------------------------------
-- Shift-F9 / Shift-F10 quick entries. Modelled on the Shift-F11 "Aktionsleisten"
-- entry (SkuCore:UpdateActionBarsRootEntry / ActionBarsShowHandler): these are NOT
-- browsable menu nodes -- they are spliced into the root ONLY for a quick-key
-- session (SkuNav.navQuickMenuActive) and removed again when the Sku menu closes
-- (SkuZOptions OnHide clears the flag). This replaces the old fragile, localized
-- audio-menu-path walk (MenuQuickSelect1/2 -> SlashFunc) with a direct open of a
-- single controlled node that reuses the SAME builders the normal menu uses.
-- navQuickMenuActive is "waypoints" (nearby waypoints on the current map) or
-- "routes" (nearby route destinations).
SkuNav.navQuickMenuActive = SkuNav.navQuickMenuActive or nil

function SkuNav:UpdateQuickRootEntry()
	if not SkuOptions or not SkuOptions.Menu then return end
	local tExisting
	for x = 1, #SkuOptions.Menu do
		if SkuOptions.Menu[x].isNavQuickRoot then tExisting = SkuOptions.Menu[x] break end
	end
	local tMode = SkuNav.navQuickMenuActive
	if tMode == "waypoints" or tMode == "routes" then
		-- Drop a stale entry from the other mode so a fresh one is built.
		if tExisting and tExisting.navQuickMode ~= tMode and SkuMenu and SkuMenu.Remove then
			SkuMenu:Remove(tExisting)
			tExisting = nil
		end
		if not tExisting then
			local tLabel = (tMode == "routes") and L["Ziele Entfernung"] or L["Aktuelle Karte Entfernung"]
			local tEntry = SkuOptions:InjectMenuItems(SkuOptions.Menu, {tLabel}, SkuGenericMenuItem)
			tEntry.id = (tMode == "routes") and "navRouteDestinationsQuick" or "navWaypointsQuick"
			tEntry.isNavQuickRoot = true
			tEntry.navQuickMode = tMode
			tEntry.dynamic = true
			tEntry.sorting = true
			tEntry.isSelect = true
			if tMode == "routes" then
				tEntry.OnAction = SkuNav.RouteFollowOnAction
				-- LEFT (OnBack) from a quick-list item drops into the full Navigation
				-- menu instead of the bare root: wrap the shared builder to tag each
				-- top-level child with the redirect. Only the quick entry does this;
				-- the same builder used by the normal menu is untouched.
				tEntry.BuildChildren = function(self)
					SkuNav.RouteDestinationsBuildChildren(self)
					for _, c in ipairs(self.children or {}) do c.OnBack = SkuNav.QuickBackToNavMenu end
				end
			else
				tEntry.OnAction = SkuNav.WaypointSelectOnAction
				-- LEFT (OnBack) drops into the full "Direct waypoint" menu.
				tEntry.BuildChildren = function(self)
					SkuNav.WaypointsCurrentMapBuildChildren(self)
					for _, c in ipairs(self.children or {}) do c.OnBack = SkuNav.QuickBackToDirectWaypointMenu end
				end
			end
		end
	elseif tExisting and SkuMenu and SkuMenu.Remove then
		SkuMenu:Remove(tExisting)
	end
end

-- Shift-F9: open the "nearby waypoints (current map)" list directly. Sets the
-- session flag (so UpdateQuickRootEntry splices the entry) then navigates to it by
-- its stable id -- SlashFunc handles opening the menu and the combat/moving defer.
function SkuNav:OpenWaypointsQuick()
	SkuNav.navQuickMenuActive = "waypoints"
	pcall(function() SkuOptions:SlashFunc(Sku.MENU_ROOT .. ",navWaypointsQuick") end)
end

-- Shift-F10: open the "nearby route destinations" list directly.
function SkuNav:OpenRouteDestinationsQuick()
	SkuNav.navQuickMenuActive = "routes"
	pcall(function() SkuOptions:SlashFunc(Sku.MENU_ROOT .. ",navRouteDestinationsQuick") end)
end

-- LEFT-arrow (OnBack) redirects for the two quick lists: instead of stepping back
-- to the bare root, land in the fuller menu the quick key is a shortcut into
-- (Shift-F9 -> "Direct waypoint", Shift-F10 -> the Navigation menu). Clearing
-- navQuickMenuActive first makes the SlashFunc preamble drop the now-orphan quick
-- root (UpdateQuickRootEntry), so it doesn't linger among the root entries. Set as
-- the OnBack of the quick list's top-level items; called as item:OnBack() so self
-- is that item (used only to fire its OnLeave, matching the generic OnBack).
function SkuNav.QuickBackToDirectWaypointMenu(self)
	if self and self.OnLeave then pcall(function() self:OnLeave() end) end
	SkuNav.navQuickMenuActive = nil
	pcall(function() SkuOptions:SlashFunc(Sku.MENU_ROOT .. ",SkuNav,navDirectWaypoint") end)
end

function SkuNav.QuickBackToNavMenu(self)
	if self and self.OnLeave then pcall(function() self:OnLeave() end) end
	SkuNav.navQuickMenuActive = nil
	pcall(function() SkuOptions:SlashFunc(Sku.MENU_ROOT .. ",SkuNav") end)
end

---------------------------------------------------------------------------------------------------------------------------------------
function SkuNav:MenuBuilder(aParentEntry)
	--dprint("SkuNav:MenuBuilder", aParentEntry)
	-- Nav menu is FLATTENED: the former "Wegpunkt" and "Route folgen" wrapper
	-- levels are gone -- their entries are injected DIRECTLY under Nav (the two
	-- builder closures below are invoked at the bottom of this function). Also
	-- removed here: the top-level "Alles abwählen" action (redundant with the
	-- dedicated Shift-F12 cancel key, SkuNav:CancelNavigationSilent) and the
	-- "Optionen" settings group (all nav settings moved to Einstellungen ->
	-- Navigation, the beacon ones into its "Beacon Soundeinstellungen" subentry).

	--wps (flattened: the former "Wegpunkt" submenu's children, built under Nav)
	local tBuildWaypointNodes = function(self)
		--[[
		local tNewMenuEntry = SkuOptions:BuildMenuSegment_TitleBuilder(self, L["New"])
		tNewMenuEntry.OnAction = function(self, aValue, aName)
			--dprint("Wegpunkt neu OnAction", self.name, aName, self.TMPSize, self.selectTarget, self.selectTarget.name, self.selectTarget.TMPSize)
			--dprint(self.selectTarget.TMPSize)
			if SkuSettings:Sub("SkuNav").metapathFollowing == true or SkuSettings:Sub("SkuNav").selectedWaypoint ~= "" then
				SkuOptions.Voice:OutputStringBTtts(L["Error"], false, true, 0.3, true)
				SkuOptions.Voice:OutputStringBTtts(L["Active waypoint or route or recording"], false, true, 0.3, true)
				return
			end
			if aName == L["Nothing selected"] then
				return
			end

			if sfind(aName, L["Selected"]..";") > 0 then
				aName = ssub(aName, slen(L["Selected"]..";") + 1)
			end
			if SkuNav:GetWaypointData2(aName) then
				SkuOptions.Voice:OutputStringBTtts(L["nicht erstellt"], false, true, 0.3, true)
				SkuOptions.Voice:OutputStringBTtts(L["name schon vorhanden"], false, true, 0.3, true)
				return
			end

			local tRName = SkuNav:CreateWaypoint(aName, nil, nil, self.selectTarget.TMPSize or 1)
			if tRName then
				--PlaySound(835)
				SkuOptions.Voice:OutputStringBTtts(L["Wegpunkt erstellt"], false, true, 0.2)
			end
		end
]]
		-- Top-level node renamed to "Direct waypoint" (was "Auswählen"). Only the
		-- DISPLAY label changes here; the L["Auswählen"] key is still used for the
		-- per-waypoint "select" sub-option and the aName check in WaypointSelectOnAction.
		local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {Sku.deEn("Direkter Wegpunkt", "Direct waypoint", "Point de passage direct")}, SkuGenericMenuItem)
		tNewMenuEntry.id = "navDirectWaypoint"   -- stable target for the Shift-F9 LEFT redirect
		tNewMenuEntry.dynamic = true
		tNewMenuEntry.isSelect = true
		tNewMenuEntry.OnAction = SkuNav.WaypointSelectOnAction
		tNewMenuEntry.BuildChildren = function(self)
			SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_CloseRoute = nil
			--wps in current map sortet by range
			local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Aktuelle Karte Entfernung"]}, SkuGenericMenuItem)
			tNewMenuEntry.id = "navWaypointCurrentMap"
			tNewMenuEntry.dynamic = true
			tNewMenuEntry.sorting = true
			tNewMenuEntry.BuildChildren = SkuNav.WaypointsCurrentMapBuildChildren

			--recent wps 
			if #SkuSettings:Sub("SkuNav").RecentWPs > 0 then
				local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Recent"]}, SkuGenericMenuItem)
				tNewMenuEntry.dynamic = true
				tNewMenuEntry.sorting = true
				tNewMenuEntry.BuildChildren = function(self)
					for i, v in pairs(SkuSettings:Sub("SkuNav").RecentWPs) do
						--dprint("recent: ", i, v)
					end
					if #SkuSettings:Sub("SkuNav").RecentWPs == 0 then
						local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Empty;list"]}, SkuGenericMenuItem)
					else
						local tNewMenuEntry = SkuOptions:InjectMenuItems(self, SkuSettings:Sub("SkuNav").RecentWPs, SkuGenericMenuItem)
					end
				end
			end

			-- all wps
			local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Alle aktueller Kontinent"]}, SkuGenericMenuItem)
			tNewMenuEntry.dynamic = true
			tNewMenuEntry.sorting = true
			tNewMenuEntry.BuildChildren = function(self)
				SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_CloseRoute = nil
				local tPlayerContintentId = select(3, SkuNav:GetAreaData(SkuNav:GetCurrentAreaId()))
				local tWaypointList = SkuNav:ListWaypoints2(false, nil, nil, tPlayerContintentId, nil, true, true)
		
				if #tWaypointList == 0 then
					SkuNav:InjectWpListEmptyHint(self)
				else
					local tNewMenuEntry = SkuOptions:InjectMenuItems(self, tWaypointList, SkuGenericMenuItem)
				end
			end

			--wps in current map sortet by range with auto wps
			local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Aktuelle Karte Entfernung mit Auto"]}, SkuGenericMenuItem)
			tNewMenuEntry.dynamic = true
			tNewMenuEntry.sorting = true
			tNewMenuEntry.BuildChildren = function(self)
				SkuOptions.SkuNav_MenuBuilder_WaypointSelectionMenu_CloseRoute = nil
				local tCurrentAreaId = SkuNav:GetAreaIdFromUiMapId(SkuNav:GetBestMapForUnit("player"))
				local tSubAreaIds = SkuNav:GetSubAreaIds(tCurrentAreaId)
				tSubAreaIds[tCurrentAreaId] = tCurrentAreaId

				local tWaypointList = {}
				for i, v in SkuNav:ListWaypoints2(true, nil, tCurrentAreaId) do
					local tWayP = SkuNav:GetWaypointData2(v)
					if tWayP then
						if tSubAreaIds[tonumber(tWayP.areaId)] then
							if not sfind(v, L["Quick waypoint"]) then
								local tWpX, tWpY = tWayP.worldX, tWayP.worldY
								local tPlayX, tPlayY = UnitPosition("player")
								local tDistance, _  = SkuNav:Distance(tPlayX, tPlayY, tWpX, tWpY)
								tWaypointList[v] = tDistance
							end
						end
					end
				end

				local tSortedWaypointList = {}
				for k,v in SkuSpairs(tWaypointList, function(t,a,b) return t[b] > t[a] end) do --nach wert
					table.insert(tSortedWaypointList, v..L[";Meter"].."#"..k)
				end
				if #tSortedWaypointList == 0 then
					SkuNav:InjectWpListEmptyHint(self)
				else
					local tNewMenuEntry = SkuOptions:InjectMenuItems(self, tSortedWaypointList, SkuGenericMenuItem)
				end
			end
		end

		local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Clear visited"]}, SkuGenericMenuItem)
		tNewMenuEntry.OnAction = function(self, aValue, aName)
			SkuNav:clearVisitedWaypoints()
			PlaySound(835)
		end

		local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Set Quick Waypoint to coordinates"]}, SkuGenericMenuItem)
		tNewMenuEntry.dynamic = true
		tNewMenuEntry.isSelect = true
		tNewMenuEntry.tQWPNumber = nil
		tNewMenuEntry.OnAction = function(self, aValue, aName)
			local tCoords = {x = nil, y = nil,}
			SkuOptions:EditBoxShow("", function(a, b, c) 
				local tText = SkuOptionsEditBoxEditBox:GetText() 
				tText = string.gsub(tText, ",", "%.")
				if self.tQWPNumber and tText ~= "" and tonumber(tText) ~= nil and tonumber(tText) > 0 and tonumber(tText) < 100 then
					tCoords.x = tonumber(tText)
					C_Timer.After(0.1, function()
						SkuOptions:EditBoxShow("", function(a, b, c) 
							local tText = SkuOptionsEditBoxEditBox:GetText() 
							tText = string.gsub(tText, ",", "%.")
							if tText ~= "" and tonumber(tText) ~= nil and tonumber(tText) > 0 and tonumber(tText) < 100 then
								tCoords.y = tonumber(tText)
								if SkuNav:GetCurrentAreaId() then
									if SkuNav:GetUiMapIdFromAreaId(SkuNav:GetCurrentAreaId()) then
										local tx, ty = SkuNav:GetWorldCoordinatesFromZone(tCoords.x / 100, tCoords.y / 100, SkuNav:GetUiMapIdFromAreaId(SkuNav:GetCurrentAreaId()))
										SkuNav:UpdateQuickWP(L["Quick waypoint"]..";"..self.tQWPNumber, false, ty, tx)
									end
								end
							else
								SkuOptions.Voice:OutputStringBTtts("y"..L[" invalid. canceled."].." "..SkuOptions.currentMenuPosition.name, true, true, 0.3, true, nil, nil, 2)
							end
						end)
						SkuOptions.Voice:OutputStringBTtts(L["enter y value"], true, true, 0.3, true, nil, nil, 2)
					end)
		
				else
					SkuOptions.Voice:OutputStringBTtts("x"..L[" invalid. canceled."].." "..SkuOptions.currentMenuPosition.name, true, true, 0.3, true, nil, nil, 2)
				end
			end)
			C_Timer.After(0.1, function()
				SkuOptions.Voice:OutputStringBTtts(L["enter x value"], true, true, 0.3, true, nil, nil, 2)
			end)
		end
		tNewMenuEntry.BuildChildren = function(self)
			for i = 1, 4 do
				local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Quick waypoint"].." "..i}, SkuGenericMenuItem)
				tNewMenuEntry.OnEnter = function(self)
					self.parent.tQWPNumber = i
				end
			end
		end

--[[
		local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Verwalten"]}, SkuGenericMenuItem)
		tNewMenuEntry.dynamic = true
		tNewMenuEntry.BuildChildren = function(self)
			--
			local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Löschen"]}, SkuGenericMenuItem)
			tNewMenuEntry.dynamic = true
			tNewMenuEntry.sorting = true
			tNewMenuEntry.isSelect = true
			tNewMenuEntry.OnAction = function(self, aValue, aName, aChildName)
				--dprint("OnAction Löschen", self.name, aValue, aName, aChildName)
				if SkuSettings:Sub("SkuNav").metapathFollowing == true or SkuSettings:Sub("SkuNav").routeRecording == true then
					SkuOptions.Voice:OutputStringBTtts(L["Error"], false, true, 0.3, true)
					SkuOptions.Voice:OutputStringBTtts(L["Active waypoint or route or recording"], false, true, 0.3, true)
					return
				end
	
				if aName == L["Löschen"] then
					if SkuSettings:Sub("SkuNav").selectedWaypoint == aChildName then
						SkuNav:SelectWP("", true)
					end
					local wpObj = SkuNav:GetWaypointData2(aChildName)
					if wpObj then
						local tSuccess = SkuNav:DeleteWaypoint(aChildName)
						if tSuccess == true then
							SkuSettings:Sub("SkuNav", nil, "global").hasCustomMapData = true
							SkuOptions.Voice:OutputStringBTtts(L["Wegpunkt gelöscht"], false, true, 0.2)
						elseif tSuccess == false then
							SkuOptions.Voice:OutputStringBTtts(L["Error"], false, true, 0.3, true)
							SkuOptions.Voice:OutputStringBTtts(L["Wird in route verwendet;Erst die Route löschen"], false, true, 0.3, true)
						else
							SkuOptions.Voice:OutputStringBTtts(L["Unbekannter Fehler"], false, true, 0.3, true)
						end
					else
						SkuOptions.Voice:OutputStringBTtts(L["Unbekannter Fehler"], false, true, 0.3, true)
					end
				end
			end
			tNewMenuEntry.BuildChildren = function(self)
				local tWaypointList = {}
				local _, _, tPlayerContinentID  = SkuNav:GetAreaData(SkuNav:GetCurrentAreaId())
				for i, v in SkuNav:ListWaypoints2(false, "custom", SkuNav:GetCurrentAreaId(), tPlayerContinentID) do --aSort, aFilter, aAreaId, aContinentId, aExcludeRoute
					if not sfind(v, L["Quick waypoint"]) then
						local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {v}, SkuGenericMenuItem)
						tNewMenuEntry.dynamic = true
						tNewMenuEntry.BuildChildren = function(self)
							local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Löschen"]}, SkuGenericMenuItem)
							local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Abbrechen"]}, SkuGenericMenuItem)
						end
					end
				end
			end

			local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Kommentar zuweisen"]}, SkuGenericMenuItem)
			tNewMenuEntry.dynamic = true
			tNewMenuEntry.sorting = true
			tNewMenuEntry.isSelect = true
			tNewMenuEntry.OnAction = function(self, aValue, aName, aChildName)
				--dprint("OnAction Kommentar zuweisen", self, aValue, aName, aChildName)
				local tWpData = SkuNav:GetWaypointData2(aName)
				if tWpData then
					if tWpData.typeId ~= 1 then
						return
					end
					SkuOptions:EditBoxShow("test", function(a, b, c) 
						local tText = SkuOptionsEditBoxEditBox:GetText() 
						if tText ~= "" then
							-- [v43.2 i18n] The rebuilt literal used to list deDE and enUS
							-- only, while the very next line indexes comments[Sku.Loc].
							-- On any client whose locale is neither (frFR since v42.11)
							-- that is a nil index and assigning a comment threw, so a
							-- French user could not annotate a waypoint at all. Seed the
							-- CLIENT's bucket, and only that one - a comment the user
							-- types is in their language, and creating empty sibling
							-- buckets would be read back as "no comments" anyway.
							if not tWpData.comments then
								tWpData.comments = {}
							end
							if not tWpData.comments[Sku.Loc] then
								tWpData.comments[Sku.Loc] = {}
							end
							tWpData.comments[Sku.Loc][#tWpData.comments[Sku.Loc] + 1] = tText
							SkuNav:SetWaypoint(aName, tWpData)
							SkuSettings:Sub("SkuNav", nil, "global").hasCustomMapData = true
							SkuOptions.Voice:OutputStringBTtts(L["Kommentar zugewiesen"], false, true, 0.3, true)
						else
							SkuOptions.Voice:OutputStringBTtts(L["Kommentar leer"], false, true, 0.3, true)
						end
					end)
					SkuOptions.Voice:OutputStringBTtts(L["Jetzt kommentar eingeben und mit ENTER abschließen oder mit ESC abbrechen"], false, true, 0.3, true)
				end
			end
			tNewMenuEntry.BuildChildren = function(self)
				local tWaypointList = {}
				local _, _, tPlayerContinentID  = SkuNav:GetAreaData(SkuNav:GetCurrentAreaId())
				for i, v in SkuNav:ListWaypoints2(false, "custom", nil, tPlayerContinentID) do --aSort, aFilter, aAreaId, aContinentId, aExcludeRoute
					if not sfind(v, L["Quick waypoint"]) then
						local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {v}, SkuGenericMenuItem)
					end
				end
			end
		end
		]]
	end

	--rts (flattened): the route-destinations list ("Ziele Entfernung") is no
	-- longer a browsable menu entry -- it opens directly via Shift-F10
	-- (SkuNav:OpenRouteDestinationsQuick). Only "Einheiten Route" stays here; it
	-- uses the shared route-follow action SkuNav.RouteFollowOnAction.
	local tBuildRouteNodes = function(self)
		local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Einheiten Route"]}, SkuGenericMenuItem)
		tNewMenuEntry.dynamic = true
		tNewMenuEntry.sorting = true
		tNewMenuEntry.isSelect = true
		tNewMenuEntry.OnAction = SkuNav.RouteFollowOnAction
		tNewMenuEntry.BuildChildren = function(self)
			SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypoint = nil
			--SkuSettings:Sub("SkuNav").metapathFollowingMetapaths = nil
			--SkuSettings:Sub("SkuNav").metapathFollowingStart = nil
			SkuSettings:Sub("SkuNav").metapathFollowingStartTMP = nil
			SkuMetapathFollowingMetapathsTMP = nil
	
			local tCurrentAreaId = SkuNav:GetAreaIdFromUiMapId(SkuNav:GetBestMapForUnit("player"))
			tUnitDbWaypointData = {}

			local tWaypointList = {}
			for i, v in pairs(SkuDB.NpcData.Names[Sku.Loc]) do
				if SkuDB.NpcData.Data[i] then
					local tSpawns = SkuDB.NpcData.Data[i][7]
					local tCreatureDbExtraWaypoints = SkuDB.NpcData.Data[i][8]
					if tSpawns and tCreatureDbExtraWaypoints then
						if tCreatureDbExtraWaypoints[tCurrentAreaId] then
							for is, vs in pairs(tSpawns) do
								if tCurrentAreaId == is then
									local tData = SkuDB.InternalAreaTable[is]
									if tData then
										local tNumberOfSpawns = #vs
										local tSubname = SkuDB.NpcData.Names[Sku.Loc][i][2]
										local tRolesString = ""
										if not tSubname then
											local tRoles = SkuNav:GetNpcRoles(v[1], i)
											if #tRoles > 0 then
												for i, v in pairs(tRoles) do
													tRolesString = tRolesString..";"..v
												end
												tRolesString = tRolesString..""
											end
										else
											tRolesString = tRolesString..";"..tSubname
										end
										for sp = 1, 1 do
											local tWayP = SkuNav:GetWaypointData2(v[1]..tRolesString..";"..tData.AreaName_lang[Sku.Loc]..";"..sp..";"..vs[sp][1]..";"..vs[sp][2])
											if tWayP then
												local tWpX, tWpY = tWayP.worldX, tWayP.worldY
												local tPlayX, tPlayY = UnitPosition("player")
												local tDistance, _  = SkuNav:Distance(tPlayX, tPlayY, tWpX, tWpY)
												tWaypointList[v[1]..tRolesString..";"..tData.AreaName_lang[Sku.Loc]..";"..sp..";"..vs[sp][1]..";"..vs[sp][2]] = tDistance
												tUnitDbWaypointData[v[1]..tRolesString..";"..tData.AreaName_lang[Sku.Loc]..";"..sp..";"..vs[sp][1]..";"..vs[sp][2]] = tCreatureDbExtraWaypoints[tCurrentAreaId][1]
											end
										end
									end
								end
							end
						end
					end
				end
			end

			local tSortedWaypointList = {}
			for k,v in SkuSpairs(tWaypointList, function(t,a,b) return t[b] > t[a] end) do --nach wert
				table.insert(tSortedWaypointList, v..L[";Meter"].."#"..k)
			end
			if #tSortedWaypointList == 0 then
				SkuNav:InjectWpListEmptyHint(self)
			else
				for i, v in pairs(tSortedWaypointList) do
					local tNewMenuEntrySub = SkuOptions:InjectMenuItems(self, {v}, SkuGenericMenuItem)
					tNewMenuEntrySub.OnEnter = function(self)
						local tClearedName = self.name
						if sfind(tClearedName, "#") then
							tClearedName = ssub(tClearedName, string.find(tClearedName, "#") + 1)
						end
						if tUnitDbWaypointData[tClearedName] then
							SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypoint = true
							SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData = tUnitDbWaypointData[tClearedName]
						end
					end
				end
			end
		end
	end

	tBuildRouteNodes(aParentEntry)      -- Einheiten Route at the top
	tBuildWaypointNodes(aParentEntry)

	-- [41.02.08] Menuepunkt "Daten" vollstaendig ausgeblendet (Nutzerwunsch).
	-- RUECKBAU: dieses "if false then" und das zugehoerige "end" weiter unten entfernen.
	if false then
	local tNewMenuEntry = SkuOptions:InjectMenuItems(aParentEntry, {L["Daten"]}, SkuGenericMenuItem)
	tNewMenuEntry.dynamic = true
	tNewMenuEntry.BuildChildren = function(self)
		--[[ Import deaktiviert - nur ueber SkuMapper Tool
		local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Import"]}, SkuGenericMenuItem)
		tNewMenuEntry.OnAction = function(self, aValue, aName)
			if SkuSettings:Sub("SkuNav").metapathFollowing == true or SkuSettings:Sub("SkuNav").routeRecording == true or SkuSettings:Sub("SkuNav").selectedWaypoint ~= "" then
				SkuOptions.Voice:OutputStringBTtts(L["Error"], false, true, 0.3, true)
				SkuOptions.Voice:OutputStringBTtts(L["Active waypoint or route or recording"], false, true, 0.3, true)
				return
			end
			SkuNav:ImportWpAndLinkData()
		end
		]]

		local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Export"]}, SkuGenericMenuItem)
		tNewMenuEntry.OnAction = function(self, aValue, aName)
			if SkuSettings:Sub("SkuNav").metapathFollowing == true or SkuSettings:Sub("SkuNav").routeRecording == true or SkuSettings:Sub("SkuNav").selectedWaypoint ~= "" then
				SkuOptions.Voice:OutputStringBTtts(L["Error"], false, true, 0.3, true)
				SkuOptions.Voice:OutputStringBTtts(L["Active waypoint or route or recording"], false, true, 0.3, true)
				return
			end
			--SkuOptions:ExportWpAndRouteData()
			SkuNav:ExportWpAndLinkData()
		end

		--[[ Entfernt in v41.01.03: Gefaehrlicher Menuepunkt der alle benutzerdefinierten Navigationsdaten unwiderruflich loescht
		local tNewMenuEntry = SkuOptions:InjectMenuItems(self, {L["Alle Routen und Wegpunkte löschen"]}, SkuGenericMenuItem)
		tNewMenuEntry.OnAction = function(self, aValue, aName)
			if SkuSettings:Sub("SkuNav").metapathFollowing == true or SkuSettings:Sub("SkuNav").routeRecording == true or SkuSettings:Sub("SkuNav").selectedWaypoint ~= "" then
				SkuOptions.Voice:OutputStringBTtts(L["Error"], false, true, 0.3, true)
				SkuOptions.Voice:OutputStringBTtts(L["Active waypoint or route or recording"], false, true, 0.3, true)
				return
			end
			SkuDB.SessionRouteData.Waypoints = {}
			SkuDB.SessionRouteData.Links = {}
			SkuSettings:Sub("SkuNav", nil, "global").hasCustomMapData = nil
			--SkuNav:CreateWaypointCache()
			SkuNav:PLAYER_ENTERING_WORLD()
			SkuOptions.Voice:OutputStringBTtts(L["Alles gelöscht"], false, true, 0.3, true)
		end
		]]
	end
	end -- [41.02.08] schliesst das ausblendende "if false then" fuer "Daten"

	-- Settings ("Optionen") intentionally NOT built here anymore: the nav settings
	-- now live under Einstellungen -> Navigation (SkuCore/Options.lua), the beacon
	-- ones in its "Beacon Soundeinstellungen" subentry there. They render the SAME
	-- SkuNav.options.args via IterateOptionsArgs against SkuSettings:Sub("SkuNav"),
	-- so saved values are unchanged.
end
