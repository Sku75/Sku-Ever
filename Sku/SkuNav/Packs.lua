---------------------------------------------------------------------------------------------------------------------------------------
-- Nav packs: extra navigation data for areas the shipped route data does not cover (new zones, e.g. on WoW: Forever).
--
-- A pack is a Lua file of an addon that depends on Sku (one addon can ship several packs, e.g. SkuPacks) and fills
-- SkuNavPackData[<name>] with plain data (see navpack/build_pack.py for the generator):
--   format        1
--   requireFlag   optional name of a Sku client flag (e.g. "isForever"): the pack is ignored on other clients
--   area          {id, name, continentId, uiMapId, uiMaps = {...}}   new area for SkuDB.InternalAreaTable
--   wpSize (optional, 1-5) size of the route waypoints = how close one must get to count as reached (SkuNavWpSize); default 1
--   idBase/idSize reserved dbIndex block for the pack's route waypoints (custom waypoint range, below 200000)
--   route         {{id, x, y}, ...}                  route waypoints (world coordinates)
--   routeSize     {routeId, size, ...}               optional, flat: waypoints whose size differs from wpSize (from the data's arrival radius)
--   links         {a, b, length, dir, ...}           flat; a/b are route ids, dir 0 both ways, 1 a->b only, 2 b->a only
--   spawns        {{type, gameId, spawnNr, x, y, nameEn, nameDe, roleEn, roleDe, pctX, pctY, dbId}, ...}
--                 type 2 = creature, 3 = object; the wpId is built like Sku's own creature/object waypoints
--                 from dbId (= gameId, or a pack-reserved substitute when the game id does not fit the 20 bit
--                 wpId field, objects above 548575). SkuNav.navPackGameId[type][dbId] gives the game id back.
--   spawnLinks    {spawnIndex, routeId, length, ...} flat
--   questSpawnLinks {type, gameId, spawnNr, routeId, length, ...} flat: ties spawns that Sku's own data makes into waypoints
--                 (same wpId scheme) to the route network
--
--   existingArea  true: area.id is an area Sku already has (e.g. a harbour in Stormwind). The zone name comes from Sku's own
--                 area table in the client language, the area is NOT counted as a route pack area, and the spawns are
--                 tied to Sku's own route network there like data pack spawns (SkuNav:AttachPackSpawns).
--                 With existingArea a pack may also carry its own route waypoints and links (e.g. the swimming network of a
--                 harbour): routeLabel (optional) is appended to the zone name in their names so they cannot collide with
--                 Sku's own "auto <zone>;n" names, and attachRoute = {routeId, ...} lists the route waypoints (the shore
--                 exits) that are tied to Sku's own network. Pack route waypoints are never a target of that tying.
--                 bridge (yards, optional): EVERY route waypoint of the pack is tied to the nearest route waypoint of Sku's own
--                 network within that distance (one link, both ways; none when nothing is that close), so the pack network and
--                 Sku's older network of the same area form one network where they overlap. bridgeAreas = {areaId, ...}
--                 (optional) adds the Sku waypoints of those other areaIds as bridge targets (a city split over districts).
--
-- The pack only ADDS: existing waypoints, names and ids are never replaced (collisions are skipped and counted).
-- Without a pack nothing here runs.
---------------------------------------------------------------------------------------------------------------------------------------
local MODULE_NAME = "SkuNav"
local L = Sku.L

local PACK_FORMAT = 1
local CREATURE_MAX = 299999 -- dbIndex of a creature must stay below the object range (see SkuNav:BuildWpIdFromData)
local OBJECT_MAX = 548575    -- dbIndexBits = 20: base3 (500000) + id must stay below 2^20
local CUSTOM_MAX = 199999

---------------------------------------------------------------------------------------------------------------------------------------
-- Valid packs, sorted by name so the result does not depend on pairs() order.
function SkuNav:GetNavPacks()
	local tList = {}
	if type(SkuNavPackData) ~= "table" then
		return tList
	end
	for tName, tPack in pairs(SkuNavPackData) do
		local tOk = type(tPack) == "table" and tPack.format == PACK_FORMAT
			and type(tPack.area) == "table" and type(tPack.area.id) == "number"
			and type(tPack.area.continentId) == "number" and type(tPack.area.uiMapId) == "number"
			and type(tPack.idBase) == "number" and type(tPack.idSize) == "number"
			and tPack.idBase >= 0 and tPack.idBase + tPack.idSize - 1 <= CUSTOM_MAX
			and type(tPack.route) == "table" and type(tPack.links) == "table"
		-- a pack can name the client it is for (Sku.<flag>, e.g. isForever); on any other client it is ignored
		if tOk and tPack.requireFlag and not Sku[tPack.requireFlag] then
			tOk = false
			dprint("nav pack skipped (other client):", tostring(tName))
		elseif not tOk then
			dprint("nav pack ignored (unknown format or bad header):", tostring(tName))
		end
		if tOk then
			tList[#tList + 1] = {name = tName, data = tPack}
		end
	end
	table.sort(tList, function(a, b) return a.name < b.name end)
	return tList
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Registers one area in the area / map / continent tables (idempotent, first registration wins).
-- The continent id and the zone name for the client's language come from the client itself when it can
-- tell (C_Map), otherwise from the pack.
local function tRegisterArea(aId, aUiMaps, aName, aZoneName, aFallbackContinent)
	if SkuDB.InternalAreaTable[aId] then
		return true
	end
	local tUiMap = aUiMaps[1]
	local tContinent = aFallbackContinent
	local tClientName
	if C_Map and tUiMap then
		if C_Map.GetWorldPosFromMapPos and CreateVector2D then
			local tCont = C_Map.GetWorldPosFromMapPos(tUiMap, CreateVector2D(0.5, 0.5))
			if type(tCont) == "number" then
				tContinent = tCont
			end
		end
		local tInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(tUiMap)
		tClientName = tInfo and tInfo.name
	end
	if not tContinent then
		return false
	end
	local tNames = {}
	for i = 1, #Sku.Locs do
		tNames[Sku.Locs[i]] = aName
	end
	if tClientName and tClientName ~= "" then
		tNames[Sku.Loc] = tClientName
	end
	SkuDB.InternalAreaTable[aId] = {
		ZoneName = aZoneName,
		AreaName_lang = tNames,
		ContinentID = tContinent,
		ParentAreaID = 0,
		Faction = 0,
		Flags = 0,
	}
	for _, tMap in ipairs(aUiMaps) do
		if not SkuDB.ExternalMapID[tMap] then
			SkuDB.ExternalMapID[tMap] = {Name_lang = tNames, ParentExternalMapID = "0", Type = "3", AreaId = aId}
		end
	end
	if not SkuDB.ContinentIds[tContinent] then
		SkuDB.ContinentIds[tContinent] = {Name_lang = tNames}
	end
	return true
end

-- Adds the pack areas of all route packs and data packs. Must run before anything resolves areas (the
-- creature family merge and the cache build call it first thing).
function SkuNav:RegisterNavPackAreas()
	for _, tEntry in ipairs(SkuNav:GetNavPacks()) do
		local tArea = tEntry.data.area
		tRegisterArea(tArea.id, tArea.uiMaps or {tArea.uiMapId}, tArea.name, tEntry.name, tArea.continentId)
	end
	for _, tEntry in ipairs(SkuNav:GetDbPacks()) do
		for _, tArea in ipairs(tEntry.data.areas or {}) do
			tRegisterArea(tArea.id, {tArea.uiMapId}, tArea.name, tEntry.name .. ":" .. tArea.id, nil)
		end
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
local function tAddLink(aRecordFrom, aIndexTo, aLength)
	local tLinks = rawget(aRecordFrom, "links")
	if not tLinks then
		tLinks = {}
		aRecordFrom.links = tLinks
	end
	if not tLinks.byId then
		tLinks.byId = {}
	end
	local tOld = tLinks.byId[aIndexTo]
	if tOld == nil or aLength < tOld then
		tLinks.byId[aIndexTo] = aLength
	end
end

-- Adds one pack to the waypoint cache. Returns a table of counters.
local function tApplyPack(aPackName, aPack)
	local tCache, tLookupAll, tLookupId, tPerContinent, tMT = SkuNav:GetWpCacheInternals()
	local tArea = aPack.area
	local tAreaId, tContinent = tArea.id, tArea.continentId
	local tZone = tArea.name
	local tExisting = SkuDB.InternalAreaTable[tAreaId]
	if aPack.existingArea and tExisting and type(tExisting.AreaName_lang) == "table" then
		tZone = tExisting.AreaName_lang[Sku.Loc] or tExisting.AreaName_lang.enUS or tZone
	end
	local tRouteZone = tZone
	if aPack.existingArea and aPack.routeLabel then
		tRouteZone = tZone .. " " .. aPack.routeLabel
	end
	local tStats = {route = 0, spawns = 0, links = 0, skipped = 0}
	if not SkuDB.InternalAreaTable[tAreaId] then
		-- the area could not be registered (this client does not know the map): add nothing
		tStats.skipped = #aPack.route
		return tStats
	end
	tPerContinent[tContinent] = tPerContinent[tContinent] or {}
	local tPerCont = tPerContinent[tContinent]

	local function tNewRecord(aName, aTypeId, aWpId, aX, aY, aRole, aSize)
		if tLookupAll[aName] or tLookupId[aWpId] then
			tStats.skipped = tStats.skipped + 1
			return nil
		end
		local tIndex = #tCache + 1
		tCache[tIndex] = setmetatable({
			name = aName,
			typeId = aTypeId,
			areaId = tAreaId,
			pack = aPack.existingArea and aPackName or nil,
			wpId = aWpId,
			worldX = aX,
			worldY = aY,
			role = aRole,
			size = aSize,
		}, tMT)
		tLookupAll[aName] = tIndex
		tLookupId[aWpId] = tIndex
		tPerCont[tIndex] = aName
		return tIndex
	end

	-- route waypoints
	local tRouteIndex = {}
	-- routeSize (optional) = {routeId, size, ...}: waypoints whose size differs from wpSize (the arrival radius of the data
	-- per waypoint: narrow passages get a small size, open ground a large one)
	local tRouteSize = {}
	if type(aPack.routeSize) == "table" then
		for i = 1, #aPack.routeSize - 1, 2 do
			local tSz = aPack.routeSize[i + 1]
			if type(tSz) == "number" and tSz >= 1 and tSz <= 5 then
				tRouteSize[aPack.routeSize[i]] = tSz
			end
		end
	end
	for _, tR in ipairs(aPack.route) do
		local tId = tR[1]
		if tId >= 0 and tId < aPack.idSize then
			local tWpId = SkuNav:BuildWpIdFromData(1, aPack.idBase + tId, 1, tAreaId)
			local tIndex = tNewRecord("auto " .. tRouteZone .. ";" .. (tId + 1), 1, tWpId, tR[2], tR[3], nil, tRouteSize[tId] or tonumber(aPack.wpSize))
			if tIndex then
				tRouteIndex[tId] = tIndex
				tStats.route = tStats.route + 1
				if aPack.existingArea and type(aPack.bridge) == "number" and aPack.bridge > 0 then
					SkuNav.navPackBridge[tIndex] = aPack.bridge
					SkuNav.navPackBridgeAreas[tAreaId] = aPack.bridgeAreas
					SkuNav.navPackAttachForce[tAreaId] = SkuNav.navPackAttachForce[tAreaId] or {}
					table.insert(SkuNav.navPackAttachForce[tAreaId], tIndex)
				end
			end
		else
			tStats.skipped = tStats.skipped + 1
		end
	end

	-- route waypoints that must be tied to Sku's own network (shore exits of a swimming network)
	if aPack.existingArea then
		for _, tId in ipairs(aPack.attachRoute or {}) do
			local tIdx = tRouteIndex[tId]
			if tIdx then
				SkuNav.navPackAttachForce[tAreaId] = SkuNav.navPackAttachForce[tAreaId] or {}
				table.insert(SkuNav.navPackAttachForce[tAreaId], tIdx)
			end
		end
	end

	-- route links
	local tLinks = aPack.links
	for i = 1, #tLinks, 4 do
		local tA, tB, tLen, tDir = tRouteIndex[tLinks[i]], tRouteIndex[tLinks[i + 1]], tLinks[i + 2], tLinks[i + 3]
		if tA and tB then
			if tDir == 0 or tDir == 1 then
				tAddLink(tCache[tA], tB, tLen)
			end
			if tDir == 0 or tDir == 2 then
				tAddLink(tCache[tB], tA, tLen)
			end
			tStats.links = tStats.links + 1
		end
	end

	-- explicit, checked seams to Sku's own network (bridgeLinks, flat: routeId, areaId, skuIndex, length, ...): the pack
	-- route waypoint is tied to exactly that Sku route waypoint (id = Sku's own wp id, index is 1-based in WaypointsNew).
	-- The link itself is made in SkuNav:AttachPackSpawns, when Sku's own links exist. Built and validated offline.
	local tBL = aPack.bridgeLinks
	if type(tBL) == "table" then
		SkuNav.navPackBridgeLinks = SkuNav.navPackBridgeLinks or {}
		for i = 1, #tBL - 3, 4 do
			local tRouteIdx = tRouteIndex[tBL[i]]
			if tRouteIdx then
				table.insert(SkuNav.navPackBridgeLinks, {pack = aPackName, route = tRouteIdx, skuId = SkuNav:BuildWpIdFromData(1, tBL[i + 2], 1, tBL[i + 1]), len = tBL[i + 3]})
			end
		end
	end

	-- spawns of the Sku creature/object data (NpcData / objectDataTBC, made into waypoints by the cache build) tied to the
	-- route network: {type, gameId, spawnNr, routeId, length, ...}. Without these a quest NPC cannot be reached over a route.
	local tQSL = aPack.questSpawnLinks or {}
	for i = 1, #tQSL, 5 do
		local tIdx = tLookupId[SkuNav:BuildWpIdFromData(tQSL[i], tQSL[i + 1], tQSL[i + 2], tAreaId)]
		local tRoute = tRouteIndex[tQSL[i + 3]]
		if tIdx and tRoute then
			tAddLink(tCache[tIdx], tRoute, tQSL[i + 4])
			tAddLink(tCache[tRoute], tIdx, tQSL[i + 4])
			tStats.links = tStats.links + 1
			tStats.spawnLinks = (tStats.spawnLinks or 0) + 1
		end
	end

	-- creature / object spawns
	local tSpawnIndex = {}
	local tDe = (Sku.Loc == "deDE")
	for i, tS in ipairs(aPack.spawns or {}) do
		local tType, tGameId, tNr = tS[1], tS[2], tS[3]
		local tDbId = tS[12] or tGameId
		if (tType == 2 and tDbId <= CREATURE_MAX) or (tType == 3 and tDbId <= OBJECT_MAX) then
			local tRole = tDe and tS[9] or tS[8]
			local tRoleString = (tRole and tRole ~= "") and (";" .. tRole) or ""
			local tName = (tDe and tS[7] or tS[6]) .. tRoleString .. ";" .. tZone .. ";" .. tNr .. ";" .. tS[10] .. ";" .. tS[11]
			local tWpId = SkuNav:BuildWpIdFromData(tType, tDbId, tNr, tAreaId)
			local tIndex = tNewRecord(tName, tType, tWpId, tS[4], tS[5], tType == 2 and tRoleString or "")
			if tIndex then
				tSpawnIndex[i] = tIndex
				tStats.spawns = tStats.spawns + 1
				if aPack.existingArea then
					SkuNav.navPackAttachList[tAreaId] = SkuNav.navPackAttachList[tAreaId] or {}
					table.insert(SkuNav.navPackAttachList[tAreaId], tIndex)
				end
				SkuNav.navPackGameId[tType][tDbId] = tGameId
			end
		else
			tStats.skipped = tStats.skipped + 1
		end
	end
	local tSL = aPack.spawnLinks or {}
	for i = 1, #tSL, 3 do
		local tS, tR, tLen = tSpawnIndex[tSL[i]], tRouteIndex[tSL[i + 1]], tSL[i + 2]
		if tS and tR then
			tAddLink(tCache[tS], tR, tLen)
			tAddLink(tCache[tR], tS, tLen)
			tStats.links = tStats.links + 1
		end
	end
	return tStats
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Called by the cache build after the custom-waypoint pass and before the link pass.
function SkuNav:ApplyNavPacks()
	SkuNav.navPacksApplied = {}
	SkuNav.navPackGameId = {[2] = {}, [3] = {}}
	SkuNav.navPackAreas = {}
	SkuNav.navPackAttachList = {}
	SkuNav.navPackAttachForce = {}
	SkuNav.navPackBridge = {}
	SkuNav.navPackBridgeAreas = {}
	SkuNav.navPackBridgeLinks = {}
	for _, tEntry in ipairs(SkuNav:GetNavPacks()) do
		local tStats = tApplyPack(tEntry.name, tEntry.data)
		if not tEntry.data.existingArea then
			SkuNav.navPackAreas[tEntry.data.area.id] = true
		end
		SkuNav.navPacksApplied[tEntry.name] = tStats
		dprint("nav pack", tEntry.name, "route", tStats.route, "spawns", tStats.spawns, "links", tStats.links, "spawnLinks", tStats.spawnLinks or 0, "skipped", tStats.skipped)
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Data packs (SkuDataPack_<Name>, SkuDBPackData[<name>]): quests, creatures, objects and items the shipped
-- SkuDB does not know, built from the Questie Forever database by navpack/build_dbpack.py:
--   format 1, areas {{id, uiMapId, name}}, quests / npcs / objects / items {[id] = row in Sku's own layout},
--   npcSpawns / objectSpawns {[id] = {[areaId] = {{x, y}, ...}}} extra spawns (new areas) for ids Sku already has,
--   npcHide {id, ...} removes the spawns of placeholder creatures Sku's own data has (no waypoint for them),
--   questPatch {[questId] = {[field] = value}} replaces giver / turn-in / objectives (and an OLD/BETA name) of a quest Sku already has,
--   names {<locale> = {quests = {[id] = {name, nil, {text}}}, npcs = {[id] = {name, sub}},
--                      objects = {[id] = name}, items = {[id] = name}}}
-- Merged additively at the end of each SkuDB family build (SkuDB/ChunkLoader.lua): an id Sku already has is
-- never replaced.
function SkuNav:GetDbPacks()
	local tList = {}
	if type(SkuDBPackData) ~= "table" then
		return tList
	end
	for tName, tPack in pairs(SkuDBPackData) do
		if type(tPack) == "table" and tPack.format == PACK_FORMAT and tPack.requireFlag and not Sku[tPack.requireFlag] then
			dprint("data pack skipped (other client):", tostring(tName))
		elseif type(tPack) == "table" and tPack.format == PACK_FORMAT then
			tList[#tList + 1] = {name = tName, data = tPack}
		else
			dprint("data pack ignored (unknown format):", tostring(tName))
		end
	end
	table.sort(tList, function(a, b) return a.name < b.name end)
	return tList
end

local function tMergeAbsent(aInto, aFrom)
	if type(aInto) ~= "table" or type(aFrom) ~= "table" then
		return 0
	end
	local tAdded = 0
	for i, v in pairs(aFrom) do
		if aInto[i] == nil then
			aInto[i] = v
			tAdded = tAdded + 1
		end
	end
	return tAdded
end

-- Keeps only spawn zones Sku can resolve; an unknown zone in a spawn table would make area lookups fail.
local function tKnownZones(aSpawns)
	if type(aSpawns) ~= "table" then
		return nil
	end
	local tOut
	for tZone, tList in pairs(aSpawns) do
		if SkuDB.InternalAreaTable[tZone] then
			tOut = tOut or {}
			tOut[tZone] = tList
		end
	end
	return tOut
end

-- Which spawns came from a data pack (and not from Sku's own data): tPackSpawnZones[type][id][areaId] = true.
-- Only these are ever tied to the route network by SkuNav:AttachPackSpawns.
local tPackSpawnZones = {[2] = {}, [3] = {}}

local function tNoteSpawnZone(aType, aId, aZone)
	local tOfId = tPackSpawnZones[aType][aId]
	if not tOfId then
		tOfId = {}
		tPackSpawnZones[aType][aId] = tOfId
	end
	tOfId[aZone] = true
end

-- Adds spawns for zones the existing row does not have yet.
local function tAddSpawnZones(aRow, aSpawnIndex, aExtra, aType, aId)
	local tKnown = tKnownZones(aExtra)
	if not tKnown then
		return
	end
	aRow[aSpawnIndex] = aRow[aSpawnIndex] or {}
	for tZone, tList in pairs(tKnown) do
		if aRow[aSpawnIndex][tZone] == nil then
			aRow[aSpawnIndex][tZone] = tList
			tNoteSpawnZone(aType, aId, tZone)
		end
	end
end

local tDbMerge = {}

tDbMerge.quests = function(aPack)
	-- Sku's quest code always expects a race mask number (Questie leaves it out for "all races"): 0 is read as
	-- unrestricted by SkuNav:ForeverRaceAllows
	for _, tRow in pairs(aPack.quests or {}) do
		if tRow[6] == nil then
			tRow[6] = 0
		end
	end
	local tAdded = tMergeAbsent(SkuDB.questDataTBC, aPack.quests)
	-- questPatch {[questId] = {[field] = value}}: Sku's own row of this quest has no (usable) giver / turn-in / objectives
	-- (OLD / BETA rows); the pack replaces exactly these fields. Only for rows Sku already has, and only the listed fields.
	for tId, tFields in pairs(aPack.questPatch or {}) do
		local tRow = SkuDB.questDataTBC[tId]
		if type(tRow) == "table" and not (aPack.quests and aPack.quests[tId]) then
			for tField, tValue in pairs(tFields) do
				tRow[tField] = tValue
			end
		end
	end
	for i = 1, #Sku.Locs do
		local tLoc = Sku.Locs[i]
		if Sku:LocaleIsWanted(tLoc) and type(SkuDB.questLookup[tLoc]) == "table" then
			local tNames = aPack.names and aPack.names[tLoc] and aPack.names[tLoc].quests
			tMergeAbsent(SkuDB.questLookup[tLoc], tNames)
			-- quests without a translation get the English name and objective text of the row
			for tId, tRow in pairs(aPack.quests or {}) do
				if SkuDB.questDataTBC[tId] == tRow and SkuDB.questLookup[tLoc][tId] == nil then
					SkuDB.questLookup[tLoc][tId] = {tRow[1], nil, tRow[8]}
				end
			end
		end
	end
	return tAdded
end

tDbMerge.creatures = function(aPack)
	local tData = SkuDB.NpcData.Data
	local tAdded = 0
	local tSpawnIdx, tZoneIdx = SkuDB.NpcData.Keys["spawns"], SkuDB.NpcData.Keys["zoneID"]
	for tId, tRow in pairs(aPack.npcs or {}) do
		if tData[tId] == nil then
			tRow[tSpawnIdx] = tKnownZones(tRow[tSpawnIdx])
			for tZone in pairs(tRow[tSpawnIdx] or {}) do
				tNoteSpawnZone(2, tId, tZone)
			end
			if tRow[tZoneIdx] and tRow[tZoneIdx] ~= 0 and not SkuDB.InternalAreaTable[tRow[tZoneIdx]] then
				tRow[tZoneIdx] = 0
			end
			tData[tId] = tRow
			tAdded = tAdded + 1
		end
	end
	for tId, tExtra in pairs(aPack.npcSpawns or {}) do
		if tData[tId] then
			tAddSpawnZones(tData[tId], tSpawnIdx, tExtra, 2, tId)
		end
	end
	-- npcHide {id, ...}: placeholder creatures of Sku's own data (invisible class-trainer / vendor pedestal markers of the capitals):
	-- their spawns are removed, so they do not show up as waypoints
	for _, tId in ipairs(aPack.npcHide or {}) do
		if tData[tId] then
			tData[tId][tSpawnIdx] = nil
		end
	end
	for i = 1, #Sku.Locs do
		local tLoc = Sku.Locs[i]
		if Sku:LocaleIsWanted(tLoc) and type(SkuDB.NpcData.Names[tLoc]) == "table" then
			local tPackNames = aPack.names and aPack.names[tLoc] and aPack.names[tLoc].npcs
			tMergeAbsent(SkuDB.NpcData.Names[tLoc], tPackNames)
			-- every pack creature needs a name entry in the client's language (the cache build walks this table);
			-- the row carries the English name
			for tId, tRow in pairs(aPack.npcs or {}) do
				if tData[tId] == tRow and SkuDB.NpcData.Names[tLoc][tId] == nil then
					SkuDB.NpcData.Names[tLoc][tId] = {tRow[1], tRow[14]}
				end
			end
		end
	end
	return tAdded
end

tDbMerge.objects = function(aPack)
	local tData = SkuDB.objectDataTBC
	local tAdded = 0
	local tSpawnIdx, tZoneIdx = SkuDB.objectKeys["spawns"], SkuDB.objectKeys["zoneID"]
	for tId, tRow in pairs(aPack.objects or {}) do
		if tData[tId] == nil then
			tRow[tSpawnIdx] = tKnownZones(tRow[tSpawnIdx])
			for tZone in pairs(tRow[tSpawnIdx] or {}) do
				tNoteSpawnZone(3, tId, tZone)
			end
			if tRow[tZoneIdx] and tRow[tZoneIdx] ~= 0 and not SkuDB.InternalAreaTable[tRow[tZoneIdx]] then
				tRow[tZoneIdx] = 0
			end
			tData[tId] = tRow
			tAdded = tAdded + 1
		end
	end
	for tId, tExtra in pairs(aPack.objectSpawns or {}) do
		if tData[tId] then
			tAddSpawnZones(tData[tId], tSpawnIdx, tExtra, 3, tId)
		end
	end
	-- objectLookup.deDE is the key set the other locales are derived from: it gets every pack object
	for i = 1, #Sku.Locs do
		local tLoc = Sku.Locs[i]
		if (tLoc == "deDE" or Sku:LocaleIsWanted(tLoc)) and type(SkuDB.objectLookup[tLoc]) == "table" then
			local tPackNames = aPack.names and aPack.names[tLoc] and aPack.names[tLoc].objects
			tMergeAbsent(SkuDB.objectLookup[tLoc], tPackNames)
			for tId, tRow in pairs(aPack.objects or {}) do
				if tData[tId] == tRow and SkuDB.objectLookup[tLoc][tId] == nil then
					SkuDB.objectLookup[tLoc][tId] = tRow[1]
				end
			end
		end
	end
	return tAdded
end

tDbMerge.items = function(aPack)
	local tAdded = tMergeAbsent(SkuDB.itemDataTBC, aPack.items)
	-- sources (field 2 = creatures, field 3 = objects) Sku's own item row lacks, e.g. the filled phials of
	-- "Crown of the Earth" (moonwells); only ever filled into a nil field
	for tId, tSrc in pairs(aPack.itemSources or {}) do
		local tRow = SkuDB.itemDataTBC[tId]
		if type(tRow) == "table" then
			for tField, tList in pairs(tSrc) do
				if tRow[tField] == nil then
					tRow[tField] = tList
				end
			end
		end
	end
	for i = 1, #Sku.Locs do
		local tLoc = Sku.Locs[i]
		if Sku:LocaleIsWanted(tLoc) and type(SkuDB.itemLookup[tLoc]) == "table" then
			local tPackNames = aPack.names and aPack.names[tLoc] and aPack.names[tLoc].items
			tMergeAbsent(SkuDB.itemLookup[tLoc], tPackNames)
			for tId, tRow in pairs(aPack.items or {}) do
				if SkuDB.itemDataTBC[tId] == tRow and SkuDB.itemLookup[tLoc][tId] == nil then
					SkuDB.itemLookup[tLoc][tId] = tRow[1]
				end
			end
		end
	end
	return tAdded
end

-- Called from SkuDB/ChunkLoader.lua as a step of each family (aFamily: quests, creatures, objects, items).
function SkuNav:MergeDbPacks(aFamily)
	local tMerge = tDbMerge[aFamily]
	if not tMerge then
		return
	end
	SkuNav:RegisterNavPackAreas()
	SkuNav.dbPacksApplied = SkuNav.dbPacksApplied or {}
	for _, tEntry in ipairs(SkuNav:GetDbPacks()) do
		local tAdded = tMerge(tEntry.data)
		SkuNav.dbPacksApplied[tEntry.name .. ":" .. aFamily] = tAdded
		dprint("data pack", tEntry.name, aFamily, "added", tAdded)
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Ties the spawns that a data pack added in areas WITHOUT a route pack to the route network Sku already has there:
-- each such creature / object waypoint with no link at all gets one link (both ways) to the nearest linked route
-- waypoint of the same zone (its area and, on Forever, its sub areas), up to ATTACH_MAX_DIST yards (up to ATTACH_FAR_DIST when none is that close). Runs at the end of the cache build, after the shipped links
-- are in. Only spawns that came from a data pack are touched, Sku's own waypoints and links stay as they are.
-- The link is a straight line (no walls), like Sku's own NPC links. aYield: the build's yield function.
-- [New Forever NPCs engine only, Forever 27.11.2026] New Forever NPCs (data pack) are tied to Sku's route network by a
-- straight line without any wall test, and the way to them can lead through places that cannot be walked. The spawns
-- below were checked offline: the engine has its own target on them and finds the way from the Sku waypoints around.
-- While the player is in the SAME engine area as such a spawn, the route lists offer the engine only; from farther away
-- (where the engine cannot route) Sku's way stays. The ties are not touched. {areaId, mapX, mapY}.
-- GENERATED (navpack/staging-27-11-neunpc/bauen.py): build again after every data pack or engine update.
local ENGINE_ONLY_SPAWNS = {
	[49808] = {{38, 36.52, 48.32}},
	[208920] = {{85, 61.8, 52.0}},
	[211022] = {{1497, 73.4, 33.0}},
	[211653] = {{17, 61.8, 39.4}},
	[214070] = {{1637, 51.6, 64.6}},
	[214101] = {{1657, 59.2, 56.6}, {1657, 59.4, 56.0}, {1657, 59.8, 56.4}, {1657, 59.8, 56.6}},
	[214529] = {{267, 67.48, 14.84}},
	[214954] = {{33, 28.51, 75.76}},
	[215643] = {{33, 26.98, 77.29}},
	[216902] = {{1537, 32.4, 67.4}, {1537, 33.0, 68.6}, {1537, 33.4, 65.4}, {1537, 33.4, 66.4}, {1537, 33.4, 67.0}, {1537, 33.4, 67.6}, {1537, 33.6, 66.0}, {1537, 33.6, 66.8}, {1537, 33.6, 67.8}},
	[216915] = {{36, 35.4, 72.4}, {36, 35.6, 72.0}, {36, 35.6, 72.6}},
	[218115] = {{33, 31.2, 48.4}, {33, 31.2, 48.6}},
	[218230] = {{33, 44.27, 7.9}},
	[221471] = {{10, 45.4, 51.2}, {10, 45.6, 51.2}, {10, 46.4, 47.6}, {10, 46.6, 47.6}},
	[221479] = {{47, 61.4, 34.4}, {47, 61.4, 34.6}},
	[221480] = {{357, 48.4, 12.4}, {357, 48.6, 12.4}},
	[222408] = {{361, 51.4, 82.0}},
	[222684] = {{10, 45.6, 51.2}},
	[222686] = {{47, 61.4, 34.4}, {47, 61.4, 34.6}},
	[222687] = {{357, 48.4, 12.4}, {357, 48.4, 12.6}, {357, 48.6, 12.4}, {357, 48.6, 12.6}},
	[230565] = {{1537, 42.4, 53.8}, {1537, 43.2, 52.4}, {1537, 43.2, 52.6}, {1537, 43.4, 51.2}, {1537, 43.6, 51.2}, {1537, 43.6, 52.2}},
	[233428] = {{85, 31.4, 66.4}, {85, 31.4, 66.6}, {1497, 79.2, 19.4}, {1497, 79.4, 19.8}, {1497, 79.6, 19.4}, {1497, 79.6, 20.0}, {1497, 79.8, 20.6}},
	[246152] = {{85, 60.22, 52.66}},
	[246349] = {{85, 21.85, 45.23}},
	[246378] = {{85, 22.09, 44.66}},
	[246389] = {{85, 21.96, 47.25}},
	[246393] = {{85, 22.69, 44.7}},
	[246795] = {{36, 18.53, 62.43}},
	[246797] = {{36, 17.72, 69.53}},
	[247223] = {{12, 52.41, 43.87}},
	[247226] = {{12, 47.18, 32.16}},
	[247227] = {{12, 46.96, 39.92}},
	[247229] = {{12, 49.48, 40.67}},
	[247264] = {{267, 48.33, 60.04}},
	[248242] = {{12, 65.1, 69.84}},
	[248248] = {{12, 63.2, 72.6}},
	[248265] = {{12, 76.54, 71.92}},
	[248266] = {{12, 82.47, 63.83}},
	[248277] = {{12, 84.75, 79.3}},
	[248415] = {{12, 51.21, 40.8}},
	[248755] = {{130, 65.55, 23.27}},
	[248809] = {{33, 27.78, 77.17}},
	[248840] = {{130, 43.4, 41.1}},
	[249713] = {{40, 42.83, 72.76}},
	[250686] = {{130, 44.52, 43.02}},
	[251001] = {{85, 65.25, 60.2}},
	[251493] = {{267, 46.43, 50.2}},
	[251507] = {{12, 41.15, 66.23}},
	[251953] = {{36, 19.83, 70.2}},
	[251972] = {{36, 17.71, 60.26}},
	[251973] = {{36, 17.61, 60.19}},
	[251975] = {{36, 18.1, 62.0}},
	[251976] = {{36, 18.06, 62.06}},
	[251977] = {{36, 17.15, 61.09}},
	[251978] = {{36, 16.78, 62.27}},
	[251980] = {{36, 15.87, 65.24}},
	[251981] = {{36, 16.46, 65.48}},
	[251997] = {{36, 15.99, 65.55}},
	[251999] = {{36, 15.39, 68.32}},
	[252000] = {{36, 15.89, 68.7}},
	[252020] = {{36, 13.19, 71.58}},
	[252040] = {{36, 14.0, 63.48}},
	[252080] = {{36, 12.89, 66.67}},
	[252083] = {{36, 12.49, 65.94}},
	[252085] = {{36, 14.15, 60.05}},
	[253066] = {{405, 43.48, 78.98}},
	[253092] = {{40, 52.48, 52.97}},
	[253096] = {{405, 69.83, 77.96}},
	[253139] = {{405, 66.25, 79.42}},
	[253140] = {{405, 35.68, 92.23}},
	[253163] = {{405, 69.83, 77.92}},
	[253166] = {{405, 34.46, 86.93}},
	[253279] = {{40, 38.68, 83.7}},
	[253395] = {{40, 51.53, 32.31}},
	[254770] = {{8, 26.51, 30.35}},
	[254775] = {{8, 24.72, 32.64}},
	[257281] = {{36, 38.4, 61.13}},
	[257282] = {{36, 30.62, 61.02}},
	[257296] = {{45, 48.68, 55.78}},
	[257304] = {{45, 33.98, 23.32}},
	[257655] = {{85, 21.916, 44.4979}},
	[257663] = {{85, 86.73, 47.72}},
	[257808] = {{38, 32.17, 65.97}},
	[258043] = {{38, 41.76, 19.05}},
	[258098] = {{1537, 47.1, 13.79}},
	[258203] = {{11, 65.76, 76.52}},
	[258306] = {{1537, 39.24, 33.63}},
	[258415] = {{1497, 70.49, 29.82}},
	[258463] = {{1637, 63.55, 50.54}},
	[258548] = {{1537, 43.53, 27.89}},
	[258572] = {{1657, 63.93, 21.33}},
	[258785] = {{1537, 24.59, 10.0}},
	[258930] = {{12, 41.79, 66.37}},
	[259023] = {{45, 59.84, 27.57}},
	[259084] = {{36, 12.3, 56.3}},
	[259611] = {{130, 45.81, 41.88}},
	[259620] = {{130, 43.4, 40.99}},
	[260093] = {{1497, 47.52, 15.0}},
	[262041] = {{618, 64.84, 33.22}},
	[263399] = {{12, 44.9, 63.36}},
	[263646] = {{1497, 60.34, 86.6}},
	[264943] = {{1537, 33.01, 48.23}},
	[265346] = {{11, 52.75, 80.33}},
	[265575] = {{33, 28.34, 74.81}},
	[265577] = {{618, 61.45, 38.62}},
	[265730] = {{36, 14.37, 64.66}},
	[265811] = {{141, 57.58, 56.64}},
	[265812] = {{85, 57.28, 55.49}},
	[265944] = {{85, 61.75, 51.44}},
	[266484] = {{1497, 58.08, 89.51}},
	[266508] = {{4, 66.73, 31.67}},
	[266847] = {{45, 26.81, 64.44}},
	[267000] = {{36, 20.82, 74.69}},
	[267001] = {{36, 21.74, 74.37}},
	[267008] = {{85, 22.03, 44.73}},
	[267009] = {{85, 65.93, 61.13}},
	[267324] = {{85, 32.6, 65.81}},
	[267325] = {{85, 32.22, 65.82}},
	[267326] = {{85, 32.46, 65.14}},
	[267333] = {{141, 59.39, 38.63}},
	[267334] = {{141, 58.16, 41.42}},
	[267335] = {{141, 59.86, 41.31}},
	[268238] = {{12, 42.01, 66.39}},
	[268992] = {{33, 23.46, 12.79}},
	[269153] = {{38, 31.78, 86.33}},
	[269452] = {{1497, 57.23, 64.75}},
	[269577] = {{3, 54.63, 12.87}},
	[270038] = {{1497, 49.11, 70.14}},
	[270263] = {{47, 14.4, 42.6}},
	[270278] = {{47, 14.4, 43.0}},
	[270280] = {{47, 14.6, 43.0}},
	[270459] = {{36, 11.79, 56.6}},
	[270513] = {{36, 17.75, 60.61}},
	[270582] = {{1637, 46.14, 53.97}},
	[270637] = {{11, 49.36, 42.13}},
	[270844] = {{11, 7.92, 55.8}},
	[271322] = {{11, 51.54, 9.01}},
	[271613] = {{1497, 45.88, 61.7}},
	[271866] = {{10, 17.0, 54.75}},
	[272054] = {{493, 43.92, 73.44}},
	[272526] = {{1497, 70.03, 47.31}},
	[275210] = {{36, 22.9, 64.44}},
	[275212] = {{36, 23.1, 65.07}},
	[275243] = {{36, 10.41, 68.48}},
	[275321] = {{36, 18.44, 63.18}},
	[275322] = {{36, 18.54, 62.41}},
	[275596] = {{36, 12.69, 70.99}},
	[275598] = {{36, 12.63, 71.14}},
	[275603] = {{36, 12.46, 71.11}},
	[275622] = {{36, 14.73, 70.84}},
	[275623] = {{36, 14.73, 71.26}},
	[275625] = {{36, 14.7, 71.25}},
	[275683] = {{141, 37.54, 36.81}},
	[275744] = {{141, 44.66, 58.92}},
	[275954] = {{85, 31.96, 46.35}},
	[276170] = {{36, 11.66, 57.8}},
	[277042] = {{1657, 58.85, 50.23}},
}

-- marks the waypoint records of the listed spawns; run after every build of the waypoint cache
function SkuNav:MarkEngineOnlySpawns()
	if not Sku.isForever then
		return 0
	end
	local tCache, _, tLookupId = SkuNav:GetWpCacheInternals()
	local tData = SkuDB.NpcData and SkuDB.NpcData.Data
	local tSpawnKey = SkuDB.NpcData and SkuDB.NpcData.Keys and SkuDB.NpcData.Keys["spawns"]
	local tCount = 0
	for tId, tList in pairs(ENGINE_ONLY_SPAWNS) do
		local tSpawns = tData and tData[tId] and tData[tId][tSpawnKey]
		for _, t in ipairs(tList) do
			for tNr, tSpawn in ipairs((tSpawns and tSpawns[t[1]]) or {}) do
				-- the position must still be the checked one (a newer data pack may move a spawn)
				if math.abs(t[2] - tSpawn[1]) < 0.05 and math.abs(t[3] - tSpawn[2]) < 0.05 then
					local tIdx = tLookupId[SkuNav:BuildWpIdFromData(2, tId, tNr, t[1])]
					if tIdx and tCache[tIdx] then
						tCache[tIdx].engineOnly = true
						tCount = tCount + 1
					end
				end
			end
		end
	end
	dprint("engine only spawns marked:", tCount)
	return tCount
end

-- Is Sku's way to this waypoint (a record of the waypoint cache) hidden right now?
function SkuNav:IsEngineOnlyRecord(aRecord)
	return aRecord ~= nil and aRecord.engineOnly == true and Sku.isForever == true
		and SkuNav.Engine ~= nil and SkuNav.Engine:SameGroup(aRecord.worldX, aRecord.worldY)
end

function SkuNav:IsEngineOnlyWp(aWpName)
	return SkuNav:IsEngineOnlyRecord(SkuNav:GetWaypointData2(aWpName))
end

-- true when the list is not empty and every waypoint of it is hidden
function SkuNav:AllEngineOnly(aWpNames)
	local tAny = false
	for _, tName in pairs(aWpNames or {}) do
		if not SkuNav:IsEngineOnlyWp(tName) then
			return false
		end
		tAny = true
	end
	return tAny
end

-- [Forever, 27.11.2026] The same rule for the entry points. A hidden waypoint is no Sku entry point. And standing AT such an
-- NPC (within ENGINE_ONLY_STAND_DIST) there is no Sku entry point at all: the Sku waypoints right around it lead the same
-- unwalkable way back (Menethil harbor), so the lists offer the engine entry points only. With aTargetNames (lists for a given
-- target) nothing is taken away when the engine cannot route to any of the targets: Sku stays the only way there.
local ENGINE_ONLY_STAND_DIST = 15
function SkuNav:SkuEntryCandidates(aRoutes, aTargetNames)
	if not (Sku.isForever and SkuNav.Engine) then
		return aRoutes
	end
	if aTargetNames then
		local tEngineCan = false
		for _, tName in pairs(aTargetNames) do
			local tData = SkuNav:GetWaypointData2(tName)
			if tData and SkuNav.Engine:SameGroup(tData.worldX, tData.worldY) then
				tEngineCan = true
				break
			end
		end
		if not tEngineCan then
			return aRoutes
		end
	end
	local rRoutes, tHidden = {}, false
	for k, v in pairs(aRoutes) do
		if SkuNav:IsEngineOnlyWp(v.nearestWP) then
			if v.nearestWpRange <= ENGINE_ONLY_STAND_DIST then
				dprint("engine only spot, no Sku entry points", v.nearestWP, v.nearestWpRange)
				return {}
			end
			tHidden = true
		else
			rRoutes[k] = v
		end
	end
	return tHidden and rRoutes or aRoutes
end

-- Does the player stand at such an NPC (so that SkuEntryCandidates takes all Sku entry points away)?
function SkuNav:AtEngineOnlySpot()
	if not (Sku.isForever and SkuNav.Engine) then
		return false
	end
	local px, py = UnitPosition("player")
	if type(px) ~= "number" then
		return false
	end
	for _, v in pairs(SkuNav:GetAllLinkedWPsInRangeToCoords(px, py, ENGINE_ONLY_STAND_DIST + 1)) do
		if v.nearestWpRange <= ENGINE_ONLY_STAND_DIST and SkuNav:IsEngineOnlyWp(v.nearestWP) then
			return true
		end
	end
	return false
end

local ATTACH_MAX_DIST = 40
local ATTACH_FAR_DIST = 250
local ATTACH_CELL = 50

function SkuNav:AttachPackSpawns(aYield)
	SkuNav:MarkEngineOnlySpawns()
	local tCache, _, tLookupId = SkuNav:GetWpCacheInternals()
	local tRoutePackAreas = SkuNav.navPackAreas or {}
	local tSpawnKeys = {
		[2] = SkuDB.NpcData and SkuDB.NpcData.Keys and SkuDB.NpcData.Keys["spawns"],
		[3] = SkuDB.objectKeys and SkuDB.objectKeys["spawns"],
	}
	local tSources = {[2] = SkuDB.NpcData and SkuDB.NpcData.Data, [3] = SkuDB.objectDataTBC}

	-- 1) the spawn waypoints that need a link, per area
	local tTodo, tTodoCount = {}, 0
	for tType = 2, 3 do
		local tSpawnKey, tSource = tSpawnKeys[tType], tSources[tType]
		if tSpawnKey and tSource then
			for tId, tZones in pairs(tPackSpawnZones[tType]) do
				local tRow = tSource[tId]
				local tSpawns = tRow and tRow[tSpawnKey]
				for tZone in pairs(tZones) do
					local tList = tSpawns and tSpawns[tZone]
					if tList and not tRoutePackAreas[tZone] then
						for tNr = 1, #tList do
							local tIdx = tLookupId[SkuNav:BuildWpIdFromData(tType, tId, tNr, tZone)]
							local tRec = tIdx and tCache[tIdx]
							local tLinks = tRec and rawget(tRec, "links")
							if tRec and not (tLinks and tLinks.byId and next(tLinks.byId)) then
								tTodo[tZone] = tTodo[tZone] or {}
								tTodo[tZone][#tTodo[tZone] + 1] = tIdx
								tTodoCount = tTodoCount + 1
							end
						end
					end
				end
			end
		end
	end
	-- spawns of packs for areas Sku already has (pack field existingArea): tied the same way
	for tZone, tList in pairs(SkuNav.navPackAttachList or {}) do
		for _, tIdx in ipairs(tList) do
			local tRec = tCache[tIdx]
			local tLinks = tRec and rawget(tRec, "links")
			if tRec and not (tLinks and tLinks.byId and next(tLinks.byId)) then
				tTodo[tZone] = tTodo[tZone] or {}
				tTodo[tZone][#tTodo[tZone] + 1] = tIdx
				tTodoCount = tTodoCount + 1
			end
		end
	end
	-- pack route waypoints that are linked inside the pack but still need their tie to Sku's network (attachRoute)
	for tZone, tList in pairs(SkuNav.navPackAttachForce or {}) do
		for _, tIdx in ipairs(tList) do
			tTodo[tZone] = tTodo[tZone] or {}
			tTodo[tZone][#tTodo[tZone] + 1] = tIdx
			tTodoCount = tTodoCount + 1
		end
	end
	-- explicit seams (bridgeLinks of the packs): tie each pack route waypoint to its Sku route waypoint, both ways
	local tSeamStats = {total = 0, ok = 0, missing = 0, noLinks = 0}
	for _, tB in ipairs(SkuNav.navPackBridgeLinks or {}) do
		tSeamStats.total = tSeamStats.total + 1
		local tSkuIdx = tLookupId[tB.skuId]
		local tSkuRec = tSkuIdx and tCache[tSkuIdx]
		if not tSkuRec then
			tSeamStats.missing = tSeamStats.missing + 1
		else
			local tSkuLinks = rawget(tSkuRec, "links")
			if not (tSkuLinks and tSkuLinks.byId and next(tSkuLinks.byId)) then
				tSeamStats.noLinks = tSeamStats.noLinks + 1
			else
				tAddLink(tCache[tB.route], tSkuIdx, tB.len)
				tAddLink(tSkuRec, tB.route, tB.len)
				tSeamStats.ok = tSeamStats.ok + 1
			end
		end
	end
	SkuNav.navPackSeams = tSeamStats
	if tSeamStats.total > 0 then
		dprint("nav pack seams to Sku's network:", tSeamStats.ok, "of", tSeamStats.total, "missing", tSeamStats.missing, "without links", tSeamStats.noLinks)
	end
	SkuNav.navPackAttach = {todo = tTodoCount, attached = 0}
	if tTodoCount == 0 then
		return
	end

	-- 2) grid of the linked route waypoints in those areas
	-- A pack's bridge reaches the Sku waypoints of its own area AND those of the areas it lists in bridgeAreas (a city
	-- is split over several areaIds: districts, sub zones), so tTarget[areaId] = the zones whose grid takes that waypoint.
	local tTarget = {}
	for tZone in pairs(tTodo) do
		tTarget[tZone] = tTarget[tZone] or {}
		table.insert(tTarget[tZone], tZone)
		for _, tOther in ipairs((SkuNav.navPackBridgeAreas and SkuNav.navPackBridgeAreas[tZone]) or {}) do
			if tOther ~= tZone then
				tTarget[tOther] = tTarget[tOther] or {}
				table.insert(tTarget[tOther], tZone)
			end
		end
	end
	-- [Sub area attach, Forever 26.11.2026] Sku gives route waypoints the id of the smallest area they lie in (a harbour,
	-- a tavern, a hall of a city), data pack spawns carry the id of the zone. Looking at the zone id only skipped the
	-- waypoints right next to a spawn and tied it across walls to a farther one (Menethil: the flight master spawn went
	-- to an upper floor of the tavern). So spawns may also be tied to the waypoints of the sub areas of their zone.
	-- Kept in a grid of its own: the ties of a nav pack's route waypoints stay exactly as they were.
	local tZonesAboveCache = {}
	local function tZonesAbove(aAreaId)
		-- a waypoint without an area id has no parent areas (and nil is no table key)
		if not aAreaId then
			return false
		end
		local tList = tZonesAboveCache[aAreaId]
		if tList == nil then
			tList = false
			local tId = aAreaId
			for _ = 1, 6 do
				local tArea = SkuDB.InternalAreaTable and SkuDB.InternalAreaTable[tId]
				tId = tArea and tArea.ParentAreaID
				if not tId or tId == 0 then
					break
				end
				if tTodo[tId] then
					tList = tList or {}
					tList[#tList + 1] = tId
				end
			end
			tZonesAboveCache[aAreaId] = tList
		end
		return tList
	end
	local tGrid, tSubGrid = {}, {}
	local function tGridAdd(aGrid, aZones, aKey, aIdx)
		for _, tZone in ipairs(aZones) do
			local tArea = aGrid[tZone]
			if not tArea then
				tArea = {}
				aGrid[tZone] = tArea
			end
			local tCell = tArea[aKey]
			if not tCell then
				tCell = {}
				tArea[aKey] = tCell
			end
			tCell[#tCell + 1] = aIdx
		end
	end
	for tIdx = 1, #tCache do
		if aYield and tIdx % 20000 == 0 then
			aYield()
		end
		local tRec = tCache[tIdx]
		if tRec and tRec.typeId == 1 and not rawget(tRec, "pack") then
			local tZones = tTarget[tRec.areaId]
			local tAbove = Sku.isForever and tZonesAbove(tRec.areaId)
			if tZones or tAbove then
				local tLinks = rawget(tRec, "links")
				if tLinks and tLinks.byId and next(tLinks.byId) then
					local tCx, tCy = math.floor(tRec.worldX / ATTACH_CELL), math.floor(tRec.worldY / ATTACH_CELL)
					local tKey = tCx * 65536 + tCy
					if tZones then
						tGridAdd(tGrid, tZones, tKey, tIdx)
					end
					if tAbove then
						tGridAdd(tSubGrid, tAbove, tKey, tIdx)
					end
				end
			end
		end
	end

	-- 3) nearest linked route waypoint for every spawn. First within ATTACH_MAX_DIST; a spawn with none that close
	-- (a house off the road, a camp in the open) gets the nearest one within ATTACH_FAR_DIST instead: the route
	-- then leads to the closest known access point and the last stretch is walked free, which is better than no
	-- route at all. Both are counted per area (SkuNav.navPackAttach.areas, shown by /skupackdiag).
	local tAttached, tDone = 0, 0
	local tAreaStats = {}
	-- aBest / aBestD (optional): the best of an earlier grid, only a nearer waypoint replaces it
	local function tNearest(aArea, aRec, aRange, aMaxDist, aBest, aBestD)
		if not aArea then
			return aBest, aBestD
		end
		local tCx, tCy = math.floor(aRec.worldX / ATTACH_CELL), math.floor(aRec.worldY / ATTACH_CELL)
		local tBest, tBestD = aBest, aBestD
		for dx = -aRange, aRange do
			for dy = -aRange, aRange do
				local tCell = aArea[(tCx + dx) * 65536 + (tCy + dy)]
				if tCell then
					for k = 1, #tCell do
						local tR = tCache[tCell[k]]
						local ddx, ddy = tR.worldX - aRec.worldX, tR.worldY - aRec.worldY
						local tD = math.sqrt(ddx * ddx + ddy * ddy)
						if tD <= aMaxDist and (not tBestD or tD < tBestD) then
							tBest, tBestD = tCell[k], tD
						end
					end
				end
			end
		end
		return tBest, tBestD
	end
	for tZone, tList in pairs(tTodo) do
		local tArea, tSub = tGrid[tZone], tSubGrid[tZone]
		local tS = {todo = #tList, near = 0, far = 0, none = 0, noRoutes = tArea == nil and tSub == nil}
		tAreaStats[tZone] = tS
		if tArea or tSub then
			for x = 1, #tList do
				tDone = tDone + 1
				if aYield and tDone % 2000 == 0 then
					aYield()
				end
				local tIdx = tList[x]
				local tRec = tCache[tIdx]
				local tBridge = SkuNav.navPackBridge and SkuNav.navPackBridge[tIdx]
				local tBest, tBestD
				if tBridge then
					tBest, tBestD = tNearest(tArea, tRec, math.ceil(tBridge / ATTACH_CELL), tBridge)
				else
					tBest, tBestD = tNearest(tArea, tRec, 1, ATTACH_MAX_DIST)
				end
				-- sub area waypoints: for spawns only, never for the route waypoints of a pack
				local tSpawnSub = (not tBridge and tRec.typeId ~= 1) and tSub or nil
				tBest, tBestD = tNearest(tSpawnSub, tRec, 1, ATTACH_MAX_DIST, tBest, tBestD)
				local tKind = "near"
				if not tBest and not tBridge then
					tBest, tBestD = tNearest(tArea, tRec, math.ceil(ATTACH_FAR_DIST / ATTACH_CELL), ATTACH_FAR_DIST)
					tBest, tBestD = tNearest(tSpawnSub, tRec, math.ceil(ATTACH_FAR_DIST / ATTACH_CELL), ATTACH_FAR_DIST, tBest, tBestD)
					tKind = "far"
				end
				if tBest then
					local tLen = math.max(1, math.floor(tBestD + 0.5))
					tAddLink(tRec, tBest, tLen)
					tAddLink(tCache[tBest], tIdx, tLen)
					tAttached = tAttached + 1
					tS[tKind] = tS[tKind] + 1
				else
					tS.none = tS.none + 1
				end
			end
		end
	end
	SkuNav.navPackAttach.attached = tAttached
	SkuNav.navPackAttach.areas = tAreaStats
	dprint("nav pack spawns tied to the route network:", tAttached, "of", tTodoCount)
	for tZone, tS in pairs(tAreaStats) do
		if tS.todo >= 50 then
			dprint("  area", tZone, "todo", tS.todo, "near", tS.near, "far", tS.far, "none", tS.none, tS.noRoutes and "(no linked route waypoints)" or "")
		end
	end
end

---------------------------------------------------------------------------------------------------------------------------------------
-- Race check for WoW: Forever. Its quest masks use the ChrRaces PlayableRaceBit encoding (QuestieDB), and the
-- Skyborne races sit on bits 32/33, which the client's 32 bit "bit" library cannot see. So the test is done with
-- arithmetic, exactly like Questie does it. Returns true / false, or nil when this is not Forever or the race is unknown
-- (the caller then keeps Sku's own result).
local tForeverRaceMaskById = {
	[1] = 1, [2] = 2, [3] = 4, [4] = 8, [5] = 16, [6] = 32, [7] = 64, [8] = 128, [9] = 256, [10] = 512, [11] = 1024,
	[22] = 2097152, [24] = 8388608, [25] = 16777216, [26] = 33554432,
	[95] = 4294967296, -- Skyborne, Alliance
	[96] = 8589934592, -- Skyborne, Horde
}
local TWO_32 = 4294967296

function SkuNav:ForeverRaceAllows(aMask)
	if not Sku.isForever then
		return nil
	end
	if not aMask or aMask == 0 then
		return true
	end
	local tRaceId = select(3, UnitRace("player"))
	local tFlag = tForeverRaceMaskById[tRaceId]
	if not tFlag then
		return nil
	end
	if (aMask % (2 * tFlag)) >= tFlag then
		return true
	end
	-- older faction-wide masks (Sku's shipped data) do not know the Skyborne bits: let a Skyborne through when the
	-- mask is the whole faction
	local tRaces = SkuDB.raceKeys
	if tRaces and (tFlag == 4294967296 or tFlag == 8589934592) then
		local tLow = aMask % TWO_32
		local tWhole = (tFlag == 4294967296) and tRaces.ALL_ALLIANCE or tRaces.ALL_HORDE
		if tWhole and bit.band(tLow, tWhole) == tWhole then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------------------------------------------------------------------
-- /skupackdiag: shows why quests of the current area are (not) listed under "Questdatenbank > Start in Zone".
-- It repeats the filter chain of SkuQuest:GetUnsortedAvailableQuestsTable step by step and counts what is left.
-- Output goes to the chat window and to the Sku debug log.
local function tDiagOut(aText)
	print("|cffffc040SkuPack|r " .. aText)
	dprint("skupackdiag", aText)
end

function SkuNav:PackProbe()
	-- Messung 12.11.2026: Anleger Sturmwind (Objekt 390005) erreichbar? Kuerzester Weg vom Anleger bis zum Spieler.
		local tCache2, _, tLookup2 = SkuNav:GetWpCacheInternals()
		local tPx, tPy = UnitPosition("player")
		for _, tProbe in ipairs({{3, 390005, 1, 1519, "Anleger"}, {3, 390004, 1, 1519, "Am Schiff"}}) do
			local tI = tLookup2[SkuNav:BuildWpIdFromData(tProbe[1], tProbe[2], tProbe[3], tProbe[4])]
			local tRec = tI and tCache2[tI]
			if not tRec then
				tDiagOut("Messung " .. tProbe[5] .. ": Eintrag nicht im Cache")
			else
				local tLinks = rawget(tRec, "links")
				local tN = 0
				for _ in pairs((tLinks and tLinks.byId) or {}) do tN = tN + 1 end
				local tDist, tHeap, tReached, tBestD, tBestName = {[tI] = 0}, {{0, tI}}, 0, nil, nil
				while #tHeap > 0 do
					local tBi = 1
					for k = 2, #tHeap do if tHeap[k][1] < tHeap[tBi][1] then tBi = k end end
					local tTop = table.remove(tHeap, tBi)
					local tD, tU = tTop[1], tTop[2]
					if tD <= tDist[tU] then
						tReached = tReached + 1
						local tR = tCache2[tU]
						if tR.typeId == 1 and not rawget(tR, "pack") and tPx then
							local tdx, tdy = tR.worldX - tPx, tR.worldY - tPy
							local tE = math.sqrt(tdx * tdx + tdy * tdy)
							if tE < 25 and (not tBestD or tD < tBestD) then tBestD, tBestName = tD, tR.name end
						end
						local tL = rawget(tR, "links")
						for tV, tLen in pairs((tL and tL.byId) or {}) do
							local tNd = tD + tLen
							if tNd < 4000 and (not tDist[tV] or tDist[tV] > tNd) then
								tDist[tV] = tNd
								tHeap[#tHeap + 1] = {tNd, tV}
							end
						end
					end
				end
				tDiagOut("Messung " .. tProbe[5] .. ": " .. tN .. " Verbindungen, bis 4000 yd erreichbar " .. tReached .. " Wegpunkte, Weg bis ans Netz neben dir: " .. tostring(tBestD and math.floor(tBestD) or "keiner"))
			end
		end
end

function SkuNav:PackDiagnose()
	local tUiMap = SkuNav.Geo:GetBestMapForUnit("player")
	local tArea = SkuNav.Geo:GetAreaIdFromUiMapId(tUiMap)
	tDiagOut("Karte " .. tostring(tUiMap) .. ", Gebiet " .. tostring(tArea) .. ", Stufe " .. tostring(UnitLevel("player"))
		.. ", Volk " .. tostring(select(2, UnitRace("player"))) .. ", Fraktion " .. tostring(UnitFactionGroup("player")))
	for tName, tN in pairs(SkuNav.dbPacksApplied or {}) do
		tDiagOut("Datenpack " .. tName .. ": " .. tostring(tN) .. " hinzugefuegt")
	end
	for tName, tS in pairs(SkuNav.navPacksApplied or {}) do
		tDiagOut("Wegpack " .. tName .. ": " .. tS.route .. " Wegpunkte, " .. tS.links .. " Verbindungen, uebersprungen " .. tS.skipped)
	end
	local tSeams = SkuNav.navPackSeams
	if tSeams and tSeams.total > 0 then
		tDiagOut("Naehte zu Skus Netz: " .. tSeams.ok .. " von " .. tSeams.total .. " verbunden, Wegpunkt fehlt " .. tSeams.missing .. ", ohne Verbindungen " .. tSeams.noLinks)
	end
	SkuNav:PackProbe()
	local tAttach = SkuNav.navPackAttach
	if tAttach then
		tDiagOut("Neue Spawns in Gebieten ohne Wegpack: " .. tAttach.todo .. " ohne Verbindung, " .. tAttach.attached .. " ans Netz gehaengt")
		local tS = tAttach.areas and tArea and tAttach.areas[tArea]
		if tS then
			tDiagOut("In diesem Gebiet: " .. tS.todo .. " zu verbinden, nah (bis 40 yd) " .. tS.near .. ", fern (bis 250 yd) " .. tS.far
				.. ", ohne Anschluss " .. tS.none .. (tS.noRoutes and ", keine verbundenen Routenwegpunkte im Gebiet" or ""))
		end
	end
	if not tArea then
		tDiagOut("Kein Gebiet zur Karte bekannt: ExternalMapID fehlt")
		return
	end
	local K = SkuDB.questKeys
	local tStage = {}
	local function tCount(aName) tStage[aName] = (tStage[aName] or 0) + 1 end
	local tOrder = {"im Gebiet (Start-NPC/Objekt)", "nicht abgeschlossen", "Stufe passt", "nicht im Questlog", "Volk/Fraktion", "Klasse", "Vorquests",
		"Ruf/Exklusiv", "nicht Event-gesperrt", "von Questie nicht gesperrt"}
	local tLevel = UnitLevel("player")
	local tFaction = UnitFactionGroup("player")
	local _, tClassFile = UnitClass("player")
	local _, _, tRaceId = UnitRace("player")
	local tRaceInfo = C_CreatureInfo.GetRaceInfo(tRaceId)
	local tLog = {}
	for i = 1, Sku.Compat.GetNumQuestLogEntries() do
		local _, _, _, tHeader, _, _, _, tQid = Sku.Compat.GetQuestLogTitle(i)
		if tQid and not tHeader then tLog[tQid] = true end
	end
	local tSamples = {}
	for tId, tRow in pairs(SkuDB.questDataTBC) do
		local tSb = tRow[K["startedBy"]]
		local tZone
		if tSb and tSb[1] and tSb[1][1] and SkuDB.NpcData.Data[tSb[1][1]] then
			tZone = SkuDB.NpcData.Data[tSb[1][1]][SkuDB.NpcData.Keys["zoneID"]]
		elseif tSb and tSb[2] and tSb[2][1] and SkuDB.objectDataTBC[tSb[2][1]] then
			tZone = SkuDB.objectDataTBC[tSb[2][1]][SkuDB.objectKeys["zoneID"]]
		end
		if tZone == tArea then
			tCount(tOrder[1])
			local tFail
			if C_QuestLog.IsQuestFlaggedCompleted(tId) then tFail = 2
			else tCount(tOrder[2]) end
			if not tFail then
				if (tRow[K["requiredLevel"]] or 0) > tLevel then tFail = 3 else tCount(tOrder[3]) end
			end
			if not tFail then
				if tLog[tId] then tFail = 4 else tCount(tOrder[4]) end
			end
			if not tFail then
				local tMask = tRow[K["requiredRaces"]]
				local tOk = false
				local tForever = SkuNav:ForeverRaceAllows(tMask)
				if tForever ~= nil then
					tOk = tForever
				elseif tMask then
					for tKey, tBit in pairs(SkuDB.raceKeys) do
						if bit.band(tBit, tMask) > 0 then
							if (tKey == "ALL_HORDE" and tFaction == "Horde") or (tKey == "ALL_ALLIANCE" and tFaction == "Alliance") then tOk = true end
							if tRaceInfo and string.upper(string.gsub(tKey, "_", "")) == string.upper(tRaceInfo.clientFileString) then tOk = true end
						end
					end
				else
					tOk = true
				end
				if tOk then tCount(tOrder[5]) else tFail = 5 end
			end
			if not tFail then
				local tCl = tRow[K["requiredClasses"]]
				local tOk = not tCl
				if tCl then
					for tKey, tBit in pairs(SkuDB.classKeys) do
						if bit.band(tBit, tCl) > 0 and tKey == tClassFile then tOk = true end
					end
				end
				if tOk then tCount(tOrder[6]) else tFail = 6 end
			end
			if not tFail then
				local tOk = true
				for _, tPre in pairs(tRow[K["preQuestGroup"]] or {}) do
					if not C_QuestLog.IsQuestFlaggedCompleted(tonumber(tPre)) then tOk = false end
				end
				local tSingle = tRow[K["preQuestSingle"]]
				if tSingle and next(tSingle) then
					local tAny = false
					for _, tPre in pairs(tSingle) do
						if C_QuestLog.IsQuestFlaggedCompleted(tonumber(tPre)) then tAny = true end
					end
					if not tAny then tOk = false end
				end
				if tOk then tCount(tOrder[7]) else tFail = 7 end
			end
			if not tFail then
				local tOk = true
				for _, tEx in pairs(tRow[K["exclusiveTo"]] or {}) do
					if C_QuestLog.IsQuestFlaggedCompleted(tEx) or tLog[tEx] then tOk = false end
				end
				if tRow[K["requiredMinRep"]] or tRow[K["requiredMaxRep"]] then tOk = false end
				if tOk then tCount(tOrder[8]) else tFail = 8 end
			end
			if not tFail then
				if SkuQuest:IsEventQuestInactive(tId) then tFail = 9 else tCount(tOrder[9]) end
			end
			if not tFail then
				if SkuQuest:IsQuestieUnavailable(tId) then tFail = 10 else tCount(tOrder[10]) end
			end
			if tFail and #tSamples < 4 then
				tSamples[#tSamples + 1] = tId .. " (" .. tostring(SkuDB.questLookup[Sku.Loc][tId] and SkuDB.questLookup[Sku.Loc][tId][1]) .. ") ausgeschieden bei: " .. tOrder[tFail]
			end
		end
	end
	for i = 1, #tOrder do
		tDiagOut(tOrder[i] .. ": " .. (tStage[tOrder[i]] or 0))
	end
	for _, tS in ipairs(tSamples) do
		tDiagOut(tS)
	end
	tDiagOut("Questie bereit: " .. tostring(SkuQuest:QuestieReady()))
end

SLASH_SKUPACKDIAG1 = "/skupackdiag"
SlashCmdList["SKUPACKDIAG"] = function()
	local tOk, tErr = pcall(SkuNav.PackDiagnose, SkuNav)
	if not tOk then
		tDiagOut("Fehler: " .. tostring(tErr))
	end
end
