---------------------------------------------------------------------------------------------------------------------------------------
-- Engine route (Forever, prototype 12.11.2026): the WowNav engine (Broesel33, NavNetwork.lua) as the way out when Sku has NO route.
--
-- Rules:
--   * Sku's own routes keep absolute priority and stay unchanged. This file never touches a Sku waypoint, link or route.
--   * The engine is only offered for targets that Sku cannot reach (the list entry "Engine-Ziele").
--   * Forever gives no player height. The height comes from a table of Sku waypoints with their floor (Engine_Heights_*.lua);
--     without a clear height there is NO route (better none than the wrong floor).
-- Data (addon SkuPacks): Engine_NavNetwork.lua, Engine_Index.lua, Engine_Data_<zone>.lua, Engine_Heights_<zone>.lua,
-- Engine_Targets_<zone>.lua. Without them Sku.Engine:Available() is false and nothing here has any effect.
---------------------------------------------------------------------------------------------------------------------------------------
local MODULE_NAME = "SkuNav"
local L = Sku.L

local Engine = {}
SkuNav.Engine = Engine

local HEIGHT_RADIUS = 12      -- yd: Sku waypoints this close to the player tell the floor
local HEIGHT_CELL = 20
local TARGET_SKU_RADIUS = 30  -- yd: a Sku waypoint this close to a target that Sku can reach = Sku has a route there
local ZONE_ID = 84            -- prototype: Stormwind City

local tReady, tIndexLoaded, tGrid
local tLastZ

local function tNet()
	return _G.WowVisionNavigationNavNetwork
end

local function tLog(...)
	if dprint then dprint("engineRoute", ...) end
end

-- engine and data present on this client?
function Engine:Available()
	if not Sku.isForever then return false end
	local N = tNet()
	if not (N and N.LoadIndex and N.Bind and N.Route) then return false end
	if not (type(_G.WVN7Index) == "table" and type(_G.SkuEngineHeights) == "table" and type(_G.SkuEngineTargets) == "table") then return false end
	if not tIndexLoaded then
		tIndexLoaded = N.LoadIndex(_G.WVN7Index) and true or false
	end
	return tIndexLoaded
end

local function tBuildGrid()
	if tGrid then return tGrid end
	tGrid = {}
	for _, p in ipairs(_G.SkuEngineHeights[ZONE_ID] or {}) do
		local k = math.floor(p[1] / HEIGHT_CELL) * 65536 + math.floor(p[2] / HEIGHT_CELL)
		tGrid[k] = tGrid[k] or {}
		tGrid[k][#tGrid[k] + 1] = p
	end
	return tGrid
end

-- Is this world position in the zone of the prototype?
local function tInZone(x, y)
	local N = tNet()
	for _, id in ipairs(N.ZonesForPoint(x, y) or {}) do
		if id == ZONE_ID then return true end
	end
	return false
end

-- Is this world point in the zone the engine data covers?
function Engine:PointInZone(x, y)
	return self:Available() and type(x) == "number" and type(y) == "number" and tInZone(x, y)
end

-- Is the player in the zone the engine data covers?
function Engine:PlayerInZone()
	if not self:Available() then return false end
	local px, py = UnitPosition("player")
	return type(px) == "number" and type(py) == "number" and tInZone(px, py)
end

-- Height of the player's floor. Forever gives no height, so: the floors the map has at (x, y) (engine bands) are matched with the
-- floors of the Sku waypoints around (Engine_Heights): a band that no nearby Sku waypoint can stand on is out. Exactly one band
-- left = the floor. Several left: the one nearest to the last known height (within 6 yd). Nothing clear: nil (no route).
function Engine:PlayerHeight(x, y)
	local N = tNet()
	local bands = N.HeightBands(x, y) or {}
	if #bands == 0 then return nil end
	-- floors that count as one layer (bands at most 2 yd apart) are merged by the engine's own rule inside Bind; here: distinct bands
	local grid = tBuildGrid()
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
	if not tInZone(px, py) then return nil, "wrong_zone" end
	N.LoadZone(ZONE_ID)
	local pz, how = self:PlayerHeight(px, py)
	if not pz then return nil, "height_unknown" end
	local start, why = N.Bind(px, py, pz)
	if not start then return nil, why or "no_start" end
	-- target height: not known, so every floor of the map at the target is tried, the shortest route wins
	local best
	-- a target of the catalog (landing, boarding point on the ship, fishing spot, ...) has a node of its own at its coordinates
	-- (the dock model of the engine): the route ends exactly on it, no cell is needed there
	local zone = N.zones and N.zones[ZONE_ID] or N.LoadZone(ZONE_ID)
	for _, t in ipairs(_G.SkuEngineTargets and _G.SkuEngineTargets[ZONE_ID] or {}) do
		if zone and N.TargetNodeAt and math.abs(t[1] - aTx) < 0.5 and math.abs(t[2] - aTy) < 0.5 then
			local i = N.TargetNodeAt(zone, t[1], t[2], nil, 3)
			if i then
				local goal = N.NodeTargetBinding(zone, i, t[1], t[2], "target_node")
				local r = N.Route(start, goal)
				if r then best = r end
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

-- Positions of ALL named Sku waypoints (targets) of this zone, whatever area or route they belong to. A WV target counts as
-- "Sku has it" when one of these lies within TARGET_SKU_RADIUS: the engine only fills in where Sku offers nothing.
local namedCache, namedCacheTime
function Engine:SkuNamedPositions()
	if namedCache and namedCacheTime and GetTime() - namedCacheTime < 5 then return namedCache end
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
	namedCache, namedCacheTime = rPos, GetTime()
	return rPos
end

-- Targets of this zone that Sku cannot reach. aReachable = set of Sku waypoint names that Sku can reach from the player
-- (from the route list's own search); a target counts as reachable by Sku when such a waypoint lies near it.
function Engine:ListTargets(aReachable)
	local rList = {}
	if not self:Available() then return rList end
	local px, py = UnitPosition("player")
	if type(px) ~= "number" or not tInZone(px, py) then return rList end
	local tSkuNear = {}
	if aReachable then
		for tName in pairs(aReachable) do
			local tData = SkuNav:GetWaypointData2(tName)
			if tData and tData.worldX then
				tSkuNear[#tSkuNear + 1] = {tData.worldX, tData.worldY}
			end
		end
	end
	for _, w in ipairs(self:SkuNamedPositions()) do tSkuNear[#tSkuNear + 1] = w end
	for _, t in ipairs(_G.SkuEngineTargets[ZONE_ID] or {}) do
		local tSkuHasRoute = false
		for i = 1, #tSkuNear do
			local w = tSkuNear[i]
			if math.abs(w[1] - t[1]) <= TARGET_SKU_RADIUS and math.abs(w[2] - t[2]) <= TARGET_SKU_RADIUS
				and (w[1] - t[1]) ^ 2 + (w[2] - t[2]) ^ 2 <= TARGET_SKU_RADIUS ^ 2 then
				tSkuHasRoute = true
				break
			end
		end
		if not tSkuHasRoute then
			local name = (Sku.Loc == "deDE") and t[3] or t[4]
			rList[#rList + 1] = {x = t[1], y = t[2], name = name, kind = t[5], dist = math.floor(math.sqrt((t[1] - px) ^ 2 + (t[2] - py) ^ 2))}
		end
	end
	-- Sku's own targets that Sku cannot reach from this entry point (e.g. the harbor is an island of Sku's net): the engine
	-- walks there. Only when the caller gave the reachable set; a target Sku reaches is never added.
	if aReachable then
		for _, w in ipairs(self:SkuNamedPositions()) do
			if not aReachable[w[3]] then
				rList[#rList + 1] = {x = w[1], y = w[2], name = w[3], kind = "", dist = math.floor(math.sqrt((w[1] - px) ^ 2 + (w[2] - py) ^ 2))}
			end
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

-- Shift-F9 list (waypoints of the current map): targets of the zone that have NO Sku waypoint near (aSkuPositions = list of {x, y} of
-- every waypoint Sku offers on this map). Returns {key = list entry name, x, y, dist}. The entry is made a real (temporary)
-- waypoint only when it is picked (EnsureTempWaypoint), so Sku's data stays as it is.
Engine.pendingWaypoints = {}
function Engine:ListWaypointTargets(aSkuPositions)
	local rList = {}
	Engine.pendingWaypoints = {}
	if not self:PlayerInZone() then return rList end
	local px, py = UnitPosition("player")
	aSkuPositions = aSkuPositions or {}
	for _, w in ipairs(self:SkuNamedPositions()) do aSkuPositions[#aSkuPositions + 1] = w end
	for _, t in ipairs(_G.SkuEngineTargets[ZONE_ID] or {}) do
		local tHasSkuWp = false
		for i = 1, #aSkuPositions do
			local w = aSkuPositions[i]
			if math.abs(w[1] - t[1]) <= TARGET_SKU_RADIUS and math.abs(w[2] - t[2]) <= TARGET_SKU_RADIUS
				and (w[1] - t[1]) ^ 2 + (w[2] - t[2]) ^ 2 <= TARGET_SKU_RADIUS ^ 2 then
				tHasSkuWp = true
				break
			end
		end
		if not tHasSkuWp then
			local name = ((Sku.Loc == "deDE") and t[3] or t[4])..";"..t[5]..";Engine"
			local entry = {key = name, x = t[1], y = t[2], dist = math.sqrt((t[1] - px) ^ 2 + (t[2] - py) ^ 2)}
			rList[#rList + 1] = entry
			Engine.pendingWaypoints[name] = entry
		end
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
