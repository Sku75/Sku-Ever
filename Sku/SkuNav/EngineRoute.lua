---------------------------------------------------------------------------------------------------------------------------------------
-- Engine route (Forever, 12./13.11.2026): the WowNav engine (NavNetwork.lua) as the way out when Sku has NO route.
--
-- Rules:
--   * Sku's own routes keep absolute priority and stay unchanged. This file never touches a Sku waypoint, link or route.
--   * The engine is only offered for targets that Sku cannot reach (the list entry "Engine-Ziele").
--   * Forever gives no player height. The height comes from a table of Sku waypoints with their floor (Engine_Heights_*.lua);
--     without a clear height there is NO route (better none than the wrong floor).
-- Data: addon SkuPacks (Engine_NavNetwork.lua, Engine_Index.lua and the zone files of small groups) and the load-on-demand addon
-- of a big group (loaded the first time the player is inside that group). Without the data Sku.Engine:Available() is false and
-- nothing here has any effect.
--   Engine_Data_<zone>.lua     the zone's net (WVN7[zoneId])
--   SkuEngineHeights[key]      {x, y, z1[, z2...]} height of Sku waypoints, for the whole group
--   SkuEngineTargets[key]      {x, y, nameDe, nameEn, kindDe[, kindEn]} targets, for the whole group
---------------------------------------------------------------------------------------------------------------------------------------
local MODULE_NAME = "SkuNav"
local L = Sku.L

local Engine = {}
SkuNav.Engine = Engine

local HEIGHT_RADIUS = 12      -- yd: Sku waypoints this close to the player tell the floor
local HEIGHT_CELL = 20
local TARGET_SKU_RADIUS = 30  -- yd: a Sku waypoint this close to a target that Sku can reach = Sku has a route there

-- Groups of engine zones that hang together by seams. key = id under which the group's heights and targets are stored.
-- addon = load-on-demand addon with the group's data (the zone nets are big: loaded only when the player is in the group).
local GROUPS = {
	{key = 84, zones = {84, 37, 52}, addon = "SkuEngineEK"},   -- Stormwind City, Elwynn Forest, Westfall
	{key = 87, zones = {87}},                                    -- Ironforge
}

local tIndexLoaded
local tGrids = {}
local tLoadTried = {}
local tLastZ

local function tNet()
	return _G.WowVisionNavigationNavNetwork
end

local function tLog(...)
	if dprint then dprint("engineRoute", ...) end
end

-- engine and index present on this client?
function Engine:Available()
	if not Sku.isForever then return false end
	local N = tNet()
	if not (N and N.LoadIndex and N.Bind and N.Route) then return false end
	if type(_G.WVN7Index) ~= "table" then return false end
	if not tIndexLoaded then
		tIndexLoaded = N.LoadIndex(_G.WVN7Index) and true or false
	end
	return tIndexLoaded
end

local function tHasData(aGroup)
	return (_G.SkuEngineTargets and _G.SkuEngineTargets[aGroup.key] and _G.SkuEngineHeights and _G.SkuEngineHeights[aGroup.key]) and true or false
end

-- data of the group on this client? A load-on-demand addon is loaded the first time it is needed (once; not in combat).
local function tDataReady(aGroup)
	if tHasData(aGroup) then return true end
	if aGroup.addon and not tLoadTried[aGroup.addon] then
		if InCombatLockdown and InCombatLockdown() then return false end
		tLoadTried[aGroup.addon] = true
		local tLoad = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
		if tLoad then tLoad(aGroup.addon) end
		tLog("loaded addon", aGroup.addon, tHasData(aGroup))
		return tHasData(aGroup)
	end
	return false
end

-- all zones of the group loaded into the engine
local function tLoadGroup(aGroup)
	local N = tNet()
	for _, z in ipairs(aGroup.zones) do
		if not (N.zones and N.zones[z]) then N.LoadZone(z) end
	end
end

-- The group (with data) the world position lies in, or nil.
local function tGroupAt(x, y)
	local N = tNet()
	for _, id in ipairs(N.ZonesForPoint(x, y) or {}) do
		for _, g in ipairs(GROUPS) do
			for _, z in ipairs(g.zones) do
				if id == z then
					if tDataReady(g) then return g end
					return nil
				end
			end
		end
	end
	return nil
end

local function tInZone(x, y)
	return tGroupAt(x, y) ~= nil
end

-- The group of the PLAYER's position: the zone boxes of the index are rectangles (they reach into zones that have no data), so
-- the map must really have a floor at that point; otherwise the engine is not offered there.
local function tPlayerGroupAt(x, y)
	local tGroup = tGroupAt(x, y)
	if not tGroup then return nil end
	tLoadGroup(tGroup)
	if #(tNet().HeightBands(x, y) or {}) == 0 then return nil end
	return tGroup
end

local function tBuildGrid(aGroup)
	if tGrids[aGroup.key] then return tGrids[aGroup.key] end
	local tGrid = {}
	tGrids[aGroup.key] = tGrid
	for _, p in ipairs(_G.SkuEngineHeights[aGroup.key] or {}) do
		local k = math.floor(p[1] / HEIGHT_CELL) * 65536 + math.floor(p[2] / HEIGHT_CELL)
		tGrid[k] = tGrid[k] or {}
		tGrid[k][#tGrid[k] + 1] = p
	end
	return tGrid
end

-- Is this world point in a zone the engine data covers?
function Engine:PointInZone(x, y)
	return self:Available() and type(x) == "number" and type(y) == "number" and tInZone(x, y)
end

-- Is the player in a zone the engine data covers?
function Engine:PlayerInZone()
	if not self:Available() then return false end
	local px, py = UnitPosition("player")
	return type(px) == "number" and type(py) == "number" and tPlayerGroupAt(px, py) ~= nil
end

-- Height of the player's floor. Forever gives no height, so: the floors the map has at (x, y) (engine bands) are matched with the
-- floors of the Sku waypoints around (Engine_Heights): a band that no nearby Sku waypoint can stand on is out. Exactly one band
-- left = the floor. Several left: the one nearest to the last known height (within 6 yd). Nothing clear: nil (no route).
function Engine:PlayerHeight(x, y, aGroup)
	local N = tNet()
	aGroup = aGroup or tGroupAt(x, y)
	if not aGroup then return nil end
	tLoadGroup(aGroup)
	local bands = N.HeightBands(x, y) or {}
	if #bands == 0 then return nil end
	-- floors that count as one layer (bands at most 2 yd apart) are merged by the engine's own rule inside Bind; here: distinct bands
	local grid = tBuildGrid(aGroup)
	local cx, cy = math.floor(x / HEIGHT_CELL), math.floor(y / HEIGHT_CELL)
	local zs = {}
	for _, radius in ipairs({HEIGHT_RADIUS, HEIGHT_RADIUS * 2}) do
		for dx = -1, 1 do
			for dy = -1, 1 do
				for _, p in ipairs(grid[(cx + dx) * 65536 + (cy + dy)] or {}) do
					if (p[1] - x) ^ 2 + (p[2] - y) ^ 2 <= radius ^ 2 then
						for i = 3, #p do zs[#zs + 1] = p[i] end
					end
				end
			end
		end
		if #zs > 0 then break end
	end
	local left = {}
	for _, band in ipairs(bands) do
		local supported = (#zs == 0)
		for _, z in ipairs(zs) do
			if z >= band.zMin - 3 and z <= band.zMax + 3 then supported = true break end
		end
		if supported then left[#left + 1] = (band.zMin + band.zMax) / 2 end
	end
	table.sort(left)
	-- layers at most 2 yd apart are the same
	local layers = {}
	for _, z in ipairs(left) do
		if #layers > 0 and z - layers[#layers] <= 2 then layers[#layers] = (layers[#layers] + z) / 2 else layers[#layers + 1] = z end
	end
	if #layers == 1 then
		tLastZ = layers[1]
		return layers[1], "clear"
	end
	if #layers > 1 and tLastZ then
		local best, bd
		for _, z in ipairs(layers) do
			local dz = math.abs(z - tLastZ)
			if not bd or dz < bd then best, bd = z, dz end
		end
		if bd <= 6 then
			tLastZ = best
			return best, "last"
		end
	end
	return nil
end

-- Engine route from the player's position to a target (x, y). Returns a list of world points {{x, y}, ...} or nil, reason.
function Engine:Route(aTx, aTy)
	if not self:Available() then return nil, "unavailable" end
	local N = tNet()
	local px, py = UnitPosition("player")
	if type(px) ~= "number" or type(py) ~= "number" then return nil, "no_position" end
	local tGroup = tPlayerGroupAt(px, py)
	if not tGroup then return nil, "wrong_zone" end
	if tGroupAt(aTx, aTy) ~= tGroup then return nil, "wrong_zone" end
	tLoadGroup(tGroup)
	local pz, how = self:PlayerHeight(px, py, tGroup)
	if not pz then return nil, "height_unknown" end
	local start, why = N.Bind(px, py, pz)
	if not start then return nil, why or "no_start" end
	-- target height: not known, so every floor of the map at the target is tried, the shortest route wins
	local best
	-- a target of the catalog (landing, boarding point on the ship, fishing spot, ...) has a node of its own at its coordinates
	-- (the dock model of the engine): the route ends exactly on it, no cell is needed there
	for _, t in ipairs(_G.SkuEngineTargets[tGroup.key] or {}) do
		if math.abs(t[1] - aTx) < 0.5 and math.abs(t[2] - aTy) < 0.5 then
			for _, z in ipairs(tGroup.zones) do
				local zone = N.zones and N.zones[z]
				local i = zone and N.TargetNodeAt and N.TargetNodeAt(zone, t[1], t[2], nil, 3)
				if i then
					local goal = N.NodeTargetBinding(zone, i, t[1], t[2], "target_node")
					local r = N.Route(start, goal)
					if r and (not best or r.length < best.length) then best = r end
					break
				end
			end
			break
		end
	end
	for _, band in ipairs(not best and N.HeightBands(aTx, aTy) or {}) do
		local tz = (band.zMin + band.zMax) / 2
		local goal = N.Bind(aTx, aTy, tz)
		if goal then
			local r = N.Route(start, goal)
			if r and (not best or r.length < best.length) then best = r end
		end
	end
	if not best then return nil, "no_route" end
	local pts = {}
	for _, id in ipairs(best.path) do
		local x, y = N.Position(id)
		if x and y then
			local last = pts[#pts]
			if not last or math.sqrt((last[1] - x) ^ 2 + (last[2] - y) ^ 2) >= 2 then
				pts[#pts + 1] = {x, y}
			end
		end
	end
	tLog("route", "length", math.floor(best.length), "points", #pts, "height", pz, how)
	return pts, nil, best.length
end

-- Positions of ALL named Sku waypoints (targets) of the engine zones, whatever area or route they belong to. A WV target counts as
-- "Sku has it" when one of these lies within TARGET_SKU_RADIUS: the engine only fills in where Sku offers nothing.
local namedCache, namedCacheTime
local namedHooked = false
-- the cached list is dropped as soon as a (non-temporary, non-quick) waypoint is created or deleted, so it is never out of date
local function tNamedDirty(self, aName, ...)
	if type(aName) == "string" then
		local tLow = string.lower(aName)
		if string.find(tLow, "^schnellwegpunkt") or string.find(tLow, "^quick waypoint") then return end
	end
	namedCache = nil
end
local function tHookNamed()
	if namedHooked or not hooksecurefunc then return end
	namedHooked = true
	hooksecurefunc(SkuNav, "CreateWaypoint", function(self, aName, aX, aY, aSize, aForce, aIsTemp)
		if not aIsTemp then tNamedDirty(self, aName) end
	end)
	hooksecurefunc(SkuNav, "DeleteWaypoint", function(self, aName, aIsTemp)
		if not aIsTemp then tNamedDirty(self, aName) end
	end)
end
function Engine:SkuNamedPositions()
	tHookNamed()
	if namedCache and namedCacheTime and GetTime() - namedCacheTime < 600 then return namedCache end
	local rPos = {}
	local tList, tState, tInit = SkuNav:ListWaypoints2(false)
	if not tList then return rPos end
	local tAutoLen = string.len(L["auto"]) + 1
	for _, v in tList, tState, tInit do
		local tLow = string.lower(v)
		if string.sub(v, 1, tAutoLen) ~= L["auto"].." " and string.sub(v, -7) ~= ";Engine"
			and not string.find(tLow, "^schnellwegpunkt") and not string.find(tLow, "^quick waypoint") then
			local tD = SkuNav:GetWaypointData2(v)
			if tD and tD.worldX and tInZone(tD.worldX, tD.worldY) then
				rPos[#rPos + 1] = {tD.worldX, tD.worldY, v}
			end
		end
	end
	-- an empty result means Sku's waypoint cache is not ready yet: do not keep it
	if #rPos > 0 then namedCache, namedCacheTime = rPos, GetTime() end
	return rPos
end

-- spatial grid of {x, y} positions (cell = TARGET_SKU_RADIUS) so that "is a Sku waypoint within the radius?" is not a scan of all
local function tPosGrid(aLists)
	local rGrid = {}
	for _, tList in ipairs(aLists) do
		for i = 1, #tList do
			local w = tList[i]
			local k = math.floor(w[1] / TARGET_SKU_RADIUS) * 65536 + math.floor(w[2] / TARGET_SKU_RADIUS)
			local c = rGrid[k]
			if not c then c = {} rGrid[k] = c end
			c[#c + 1] = w
		end
	end
	return rGrid
end

local function tNearGrid(aGrid, x, y)
	local cx, cy = math.floor(x / TARGET_SKU_RADIUS), math.floor(y / TARGET_SKU_RADIUS)
	for dx = -1, 1 do
		for dy = -1, 1 do
			local c = aGrid[(cx + dx) * 65536 + (cy + dy)]
			if c then
				for i = 1, #c do
					local w = c[i]
					if (w[1] - x) ^ 2 + (w[2] - y) ^ 2 <= TARGET_SKU_RADIUS ^ 2 then return true end
				end
			end
		end
	end
	return false
end

-- One entry per name and kind, the one nearest to the player (as Sku's own unit lists do: the way goes to the nearest one).
-- Same limit as Sku's own route lists (routesMaxDistance): what is farther away than that is not offered. The straight line is
-- never longer than the way, so this is the generous side of that limit.
local function tMaxDistance()
	local tMax = SkuSettings and SkuSettings:Sub("SkuNav").routesMaxDistance
	return type(tMax) == "number" and tMax or nil
end

local function tTargetsWithoutSku(aGroup, aGrid, px, py, aMaxDist)
	local rBest, rOrder = {}, {}
	for _, t in ipairs(_G.SkuEngineTargets[aGroup.key] or {}) do
		if not tNearGrid(aGrid, t[1], t[2]) then
			local tName = (Sku.Loc == "deDE") and t[3] or t[4]
			local tKind = (Sku.Loc == "deDE") and t[5] or (t[6] or t[5])
			local tKey = tName.."\1"..tKind
			local d = math.sqrt((t[1] - px) ^ 2 + (t[2] - py) ^ 2)
			local b = rBest[tKey]
			if aMaxDist and d > aMaxDist then
				-- too far
			elseif not b then
				b = {x = t[1], y = t[2], name = tName, kind = tKind, dist = d}
				rBest[tKey] = b
				rOrder[#rOrder + 1] = b
			elseif d < b.dist then
				b.x, b.y, b.dist = t[1], t[2], d
			end
		end
	end
	return rOrder
end

-- Targets of this group that Sku cannot reach. aReachable = set of Sku waypoint names that Sku can reach from the player
-- (from the route list's own search); a target counts as reachable by Sku when such a waypoint lies near it.
function Engine:ListTargets(aReachable)
	local rList = {}
	if not self:Available() then return rList end
	local px, py = UnitPosition("player")
	if type(px) ~= "number" then return rList end
	local tGroup = tPlayerGroupAt(px, py)
	if not tGroup then return rList end
	local tSkuNear = {}
	if aReachable then
		for tName in pairs(aReachable) do
			local tData = SkuNav:GetWaypointData2(tName)
			if tData and tData.worldX then
				tSkuNear[#tSkuNear + 1] = {tData.worldX, tData.worldY}
			end
		end
	end
	local tNamed = self:SkuNamedPositions()
	local tMaxDist = tMaxDistance()
	for _, t in ipairs(tTargetsWithoutSku(tGroup, tPosGrid({tSkuNear, tNamed}), px, py, tMaxDist)) do
		t.dist = math.floor(t.dist)
		rList[#rList + 1] = t
	end
	-- Sku's own targets that Sku cannot reach from this entry point (e.g. the harbor is an island of Sku's net): the engine
	-- walks there. Only when the caller gave the reachable set; a target Sku reaches is never added.
	-- Sku names every spawn of a unit by its own waypoint ("Name;Role;Area;3;75.6;9.6"): of the spawns of one name only the nearest
	-- one is offered (as with the catalog targets above), otherwise the list holds thousands of entries.
	if aReachable then
		local tBest, tOrder = {}, {}
		for _, w in ipairs(tNamed) do
			local d = (w[1] - px) ^ 2 + (w[2] - py) ^ 2
			if not aReachable[w[3]] and not (tMaxDist and d > tMaxDist ^ 2) then
				local tKey = string.gsub(w[3], ";%d+;[%d%.]+;[%d%.]+$", "")
				local b = tBest[tKey]
				if not b then
					b = {x = w[1], y = w[2], name = w[3], kind = "", d2 = d}
					tBest[tKey] = b
					tOrder[#tOrder + 1] = b
				elseif d < b.d2 then
					b.x, b.y, b.name, b.d2 = w[1], w[2], w[3], d
				end
			end
		end
		for _, b in ipairs(tOrder) do
			b.dist = math.floor(math.sqrt(b.d2))
			b.d2 = nil
			rList[#rList + 1] = b
		end
	end
	table.sort(rList, function(a, b) return a.dist < b.dist end)
	return rList
end

-- Called by SkuNav.RouteFollowOnAction when the picked list entry is an engine target. Fills the data that the unit route
-- ("Einheiten Route") follows (world points) and returns true; otherwise says why not and returns false.
function Engine:PrepareFollow(aTarget)
	local pts, why = self:Route(aTarget.x, aTarget.y)
	if not pts then
		SkuOptions.Voice:OutputStringBTtts(L["Error"], false, true, 0.3, true)
		-- plain texts, no new Sku.L keys (the locale library raises an error for a missing key)
		local tDe = (Sku.Loc == "deDE")
		local tText = {
			height_unknown = tDe and "Engine Route: Hoehe unklar" or "Engine route: height unclear",
			wrong_zone = tDe and "Engine Route: nicht in diesem Gebiet" or "Engine route: not in this area",
			no_route = tDe and "Engine Route: keine Route gefunden" or "Engine route: no route found",
		}
		SkuOptions.Voice:OutputStringBTtts(tText[why] or tText.no_route, false, true, 0.3, true)
		tLog("no route", tostring(why))
		return false
	end
	-- the last point is the target itself
	pts[#pts + 1] = {aTarget.x, aTarget.y}
	SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypoint = true
	SkuSettings:Sub("SkuNav").metapathFollowingUnitDbWaypointData = pts
	SkuNav.engineWorldPoints = true
	return true
end

-- Shift-F9 list (waypoints of the current map): targets of the group that have NO Sku waypoint near (aSkuPositions = list of {x, y} of
-- every waypoint Sku offers on this map). Returns {key = list entry name, x, y, dist}. The entry is made a real (temporary)
-- waypoint only when it is picked (EnsureTempWaypoint), so Sku's data stays as it is.
Engine.pendingWaypoints = {}
function Engine:ListWaypointTargets(aSkuPositions)
	local rList = {}
	Engine.pendingWaypoints = {}
	if not self:PlayerInZone() then return rList end
	local px, py = UnitPosition("player")
	local tGroup = tPlayerGroupAt(px, py)
	if not tGroup then return rList end
	aSkuPositions = aSkuPositions or {}
	for _, t in ipairs(tTargetsWithoutSku(tGroup, tPosGrid({aSkuPositions, self:SkuNamedPositions()}), px, py)) do
		local name = t.name..";"..t.kind..";Engine"
		local entry = {key = name, x = t.x, y = t.y, dist = math.floor(t.dist)}
		rList[#rList + 1] = entry
		Engine.pendingWaypoints[name] = entry
	end
	return rList
end

-- Called when a waypoint list entry is picked: if it is an engine target, make it a temporary waypoint (like Sku's own
-- temporary waypoints of the unit routes) so that Sku can select and follow it. Returns true when it did.
function Engine:EnsureTempWaypoint(aName)
	local entry = Engine.pendingWaypoints[aName]
	if not entry then return false end
	if SkuNav:GetWaypointData2(aName) then return true end
	SkuNav:ClearWaypointsTemporary()
	local tName = SkuNav:CreateWaypoint(aName, entry.x, entry.y, 1, true, true)
	if not tName then return false end
	SkuSettings:Sub("SkuNav").WaypointsTemporary = SkuSettings:Sub("SkuNav").WaypointsTemporary or {}
	SkuSettings:Sub("SkuNav").WaypointsTemporary[#SkuSettings:Sub("SkuNav").WaypointsTemporary + 1] = tName
	return true
end

-- Warm-up: after logging in or changing the zone, inside a group with engine data, load the data and decode the zones one after
-- the other in the background, so that the first list does not hang (loading the big addon and decoding the zone nets takes
-- a second or more). Elsewhere nothing is loaded. Not in combat.
function Engine:Preload()
	if not self:Available() then return end
	if InCombatLockdown and InCombatLockdown() then return end
	local px, py = UnitPosition("player")
	if type(px) ~= "number" or type(py) ~= "number" then return end
	local tGroup = tGroupAt(px, py)   -- loads the data addon the first time
	if not tGroup then return end
	local N = tNet()
	for i, z in ipairs(tGroup.zones) do
		C_Timer.After((i - 1) * 0.5, function()
			if not (N.zones and N.zones[z]) then N.LoadZone(z) end
		end)
	end
	C_Timer.After(#tGroup.zones * 0.5, function() tBuildGrid(tGroup) end)
	-- the names of Sku's waypoints take ~0.4 s to collect: do it now, not when the first list is opened (kept 10 minutes)
	C_Timer.After(#tGroup.zones * 0.5 + 6, function()
		if not (InCombatLockdown and InCombatLockdown()) then namedCache = nil; Engine:SkuNamedPositions() end
	end)
end

if Sku.isForever and CreateFrame and C_Timer then
	local tPreloadFrame = CreateFrame("Frame")
	tPreloadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	tPreloadFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	tPreloadFrame:SetScript("OnEvent", function()
		C_Timer.After(8, function() Engine:Preload() end)
	end)
end
