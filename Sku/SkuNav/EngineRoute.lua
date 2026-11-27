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
-- The list comes from the DATA (SkuEngineGroups in SkuPacks/Engine_Index.lua, written by the build from navpack/groups.json): a new group
-- or a changed zone list needs no change of this file. The built-in list is only the fallback for an Engine_Index.lua without that table.
local GROUPS_FALLBACK = {
	{key = 84, zones = {84, 37, 52, 49, 1431}, addon = "SkuEngineEK"},   -- Stormwind City, Elwynn Forest, Westfall, Redridge Mountains, Duskwood
	{key = 87, zones = {87, 27, 1432, 1437}, addon = "SkuEngineZW"},   -- Ironforge, Dun Morogh, Loch Modan, Wetlands
	{key = 1457, zones = {1457, 57}, addon = "SkuEngineKD"},   -- Darnassus, Teldrassil
}
-- resolved on every use, not at file load: SkuPacks (Engine_Index.lua) may be loaded after this file
local function tGroups()
	local t = _G.SkuEngineGroups
	return (type(t) == "table" and #t > 0) and t or GROUPS_FALLBACK
end

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
-- [Unload, 15.11.2026] Only the zones of the PLAYER's group stay decoded: the decoded copy is ~85 % of a zone's memory and is rebuilt from the
-- raw data in well under a second (raw tables stay, they cannot be reloaded). Zones of other groups are dropped here, when the player's
-- group is loaded (never in combat). Memory stays at one group instead of growing with every group visited in a session.
local tGroupSeen = {}
local function tUnloadOtherGroups(aGroup)
	local N = tNet()
	if not (N.zones and N.decoded) then return end
	local tKeep = {}
	for _, z in ipairs(aGroup.zones) do tKeep[z] = true end
	-- [Forever, 20.11.2026] Hysteresis: a group used in the last 90 s stays decoded. Travelling along a border (flight, ship, riding) flips the
	-- player's group back and forth; unloading and decoding the zones again at every flip made every list/route build take seconds.
	local tNow = GetTime and GetTime() or 0
	tGroupSeen[aGroup.key] = tNow
	for _, g in ipairs(tGroups()) do
		if g ~= aGroup and tGroupSeen[g.key] and tNow - tGroupSeen[g.key] < 90 then
			for _, z in ipairs(g.zones) do tKeep[z] = true end
		end
	end
	-- [Forever, 20.11.2026] The zones whose box holds the player's position stay too: the engine loads them itself when it asks for the floors at
	-- the position (HeightBands), also zones of a NEIGHBOUR group where the boxes overlap. Dropping them here made the next call load and
	-- decode them again, every second, for as long as the player stood on such a border (seconds per call, "script ran too long").
	local tPx, tPy = UnitPosition("player")
	if type(tPx) == "number" and type(tPy) == "number" and N.ZonesForPoint then
		for _, z in ipairs(N.ZonesForPoint(tPx, tPy) or {}) do tKeep[z] = true end
	end
	local tDropped
	for z in pairs(N.zones) do
		if not tKeep[z] then tDropped = tDropped or {} tDropped[#tDropped + 1] = z end
	end
	if not tDropped then return end
	for _, z in ipairs(tDropped) do N.zones[z] = nil N.decoded[z] = nil end
	local tActions = 0
	for _, zone in pairs(N.zones) do tActions = tActions + #(zone.actions or {}) end
	N.actionCount = tActions
	N.generation = N.generation + 1
	if N.DiscardVirtual then N.DiscardVirtual() end
	tLog("unloaded zones", table.concat(tDropped, ","))
end

local function tLoadGroup(aGroup)
	local N = tNet()
	if not (InCombatLockdown and InCombatLockdown()) then tUnloadOtherGroups(aGroup) end
	for _, z in ipairs(aGroup.zones) do
		if not (N.zones and N.zones[z]) then N.LoadZone(z) end
	end
end

-- [Zone choice, 15.11.2026] The zone boxes of the index are rectangles: they overlap at the borders of neighbouring zones (Searing Gorge /
-- Dun Morogh) and, across continents, share world coordinates. So (1) the player's continent (4th value of UnitPosition = native map id)
-- limits the zones to that continent (if that leaves nothing, the limit is dropped: the value may be unreliable on a client) and
-- (2) of several zones the one the point lies DEEPEST in (distance to the box edge relative to the box size) comes first.
-- aNoSort: only the membership of the zones matters (no depth order); aMap: the player's native map id already read by the caller
-- (false = none), so that a loop over many points does not ask UnitPosition for every point.
local function tZonesAt(x, y, aNoSort, aMap)
	local N = tNet()
	local tMap = aMap
	if tMap == nil then
		local _, _, _, tM = UnitPosition("player")
		tMap = tM
	end
	N.activeMapId = type(tMap) == "number" and tMap or nil
	local rZones = N.ZonesForPoint(x, y) or {}
	if #rZones == 0 and N.activeMapId ~= nil then
		N.activeMapId = nil
		rZones = N.ZonesForPoint(x, y) or {}
	end
	if #rZones > 1 and N.index and not aNoSort then
		local function tDepth(id)
			local tBest = -1e9
			for _, box in pairs((N.index[id] and N.index[id].worldBoxes) or {}) do
				if x >= box.xmin and x <= box.xmax and y >= box.ymin and y <= box.ymax then
					local tMargin = math.min(x - box.xmin, box.xmax - x, y - box.ymin, box.ymax - y)
					local tSize = math.sqrt((box.xmax - box.xmin) * (box.ymax - box.ymin))
					if tMargin / tSize > tBest then tBest = tMargin / tSize end
				end
			end
			return tBest
		end
		local tD = {}
		for _, id in ipairs(rZones) do tD[id] = tDepth(id) end
		table.sort(rZones, function(a, b) if tD[a] ~= tD[b] then return tD[a] > tD[b] end return a < b end)
	end
	return rZones
end

-- The group (with data) the world position lies in, or nil.
local function tGroupAt(x, y)
	local N = tNet()
	for _, id in ipairs(tZonesAt(x, y)) do
		for _, g in ipairs(tGroups()) do
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

-- The group a world point lies in WITHOUT loading its data addon (a point in another group must not make us load that group's big
-- addon: only the player's own group is loaded).
local function tGroupOf(x, y)
	local N = tNet()
	for _, id in ipairs(tZonesAt(x, y)) do
		for _, g in ipairs(tGroups()) do
			for _, z in ipairs(g.zones) do
				if id == z then return g end
			end
		end
	end
	return nil
end

-- does ANY zone whose box holds the point belong to the group? (a target in an overlap of two boxes belongs to the player's group if
-- one of its candidate zones does)
local function tInGroup(aGroup, x, y, aMap)
	for _, id in ipairs(tZonesAt(x, y, true, aMap)) do
		for _, z in ipairs(aGroup.zones) do
			if id == z then return true end
		end
	end
	return false
end

-- [WV area inside a group, 16.11.2026] A group flagged wv is WV-only everywhere; a group with a wvbox {xmin, ymin, xmax, ymax} (world
-- yards) is WV-only only inside that box (Dalaran Crater inside the old-world group NB: Sku has no network there, the rest of the group
-- stays as it was). Every wv decision for a point goes through this function.
local function tWvAt(aGroup, x, y)
	if aGroup and aGroup.wv then return true end
	if type(x) ~= "number" or type(y) ~= "number" then return false end
	-- the box is looked up over ALL groups: its zone boxes overlap the neighbours' (Silverpine, Hillsbrad), so the group a point
	-- resolves to need not be the group that owns the wvbox
	for _, g in ipairs(tGroups()) do
		local b = g.wvbox
		if b and x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4] then return true end
	end
	return false
end

-- same group as the player (the engine only routes inside one group)
local function tInZone(x, y)
	local px, py = UnitPosition("player")
	if type(px) ~= "number" or type(py) ~= "number" then return false end
	local tG = tGroupOf(px, py)
	return tG ~= nil and tInGroup(tG, x, y) and tDataReady(tG)
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

-- Height of the last engine route at the player's position (x, y): the z of the route point nearest in the plane, when it lies within
-- 8 yd and no other route point of a different height (more than 4 yd) lies about as near (a spiral: ambiguous again). nil otherwise.
function Engine:RouteHeightAt(x, y)
	local tLast = self.lastRoute
	if not (tLast and tLast.pts and tLast.zs) then return nil end
	local tBestD, tBestZ
	for i, p in ipairs(tLast.pts) do
		local z = tLast.zs[i]
		if z then
			local d = math.sqrt((p[1] - x) ^ 2 + (p[2] - y) ^ 2)
			if not tBestD or d < tBestD then tBestD, tBestZ = d, z end
		end
	end
	if not tBestD or tBestD > 8 then return nil end
	for i, p in ipairs(tLast.pts) do
		local z = tLast.zs[i]
		if z and math.abs(z - tBestZ) > 4 and math.sqrt((p[1] - x) ^ 2 + (p[2] - y) ^ 2) <= tBestD + 3 then return nil end
	end
	return tBestZ
end

-- Is the player in a group flagged wv (new Forever areas where the engine takes everything from WV and Sku has no network)?
function Engine:PlayerInWvGroup()
	if not self:Available() then return false end
	local px, py = UnitPosition("player")
	if type(px) ~= "number" or type(py) ~= "number" then return false end
	local tGroup = tGroupAt(px, py)
	return tGroup and tWvAt(tGroup, px, py) or false
end

-- Can the engine route from where the player stands to (x, y), i.e. do both lie in the same engine group?
function Engine:SameGroup(x, y)
	if not self:Available() then return false end
	local px, py = UnitPosition("player")
	if type(px) ~= "number" or type(py) ~= "number" or type(x) ~= "number" then return false end
	local tGroup = tPlayerGroupAt(px, py)
	return (tGroup ~= nil and tInGroup(tGroup, x, y)) and true or false
end

-- Is the player in a zone the engine data covers?
function Engine:PlayerInZone()
	if not self:Available() then return false end
	local px, py = UnitPosition("player")
	return type(px) == "number" and type(py) == "number" and tPlayerGroupAt(px, py) ~= nil
end

-- [Buried terrain, Forever 27.11.2026] The map data of Stormwind also holds the terrain UNDER the city model (about 57-61 yd,
-- below the streets). Nobody can walk there, but it counted as a floor: the player was put under the city and sent on long detours.
-- Such a floor is dropped when a floor at least `above` yd higher lies at the same point. Alone it stays (terrain outside the walls).
-- `keep` are boxes {x1, x2, y1, y2} where a low floor under a higher one is real (the way down to the harbour).
local BURIED_TERRAIN = {
	{ zone = 84, box = {-9140, -8330, 260, 1160}, zMin = 56.5, zMax = 61, above = 15, keep = { {-8560, -8440, 960, 1060} } },
}
local function tInBox(x, y, b)
	return x >= b[1] and x <= b[2] and y >= b[3] and y <= b[4]
end
local function tFloorBands(N, x, y)
	local bands = N.HeightBands(x, y) or {}
	if #bands < 2 then return bands end
	for _, tRule in ipairs(BURIED_TERRAIN) do
		local tOn = N.zones and N.zones[tRule.zone] and tInBox(x, y, tRule.box)
		for _, tKeep in ipairs(tRule.keep) do
			if tInBox(x, y, tKeep) then tOn = false end
		end
		if tOn then
			local tOut = {}
			for _, band in ipairs(bands) do
				local tBuried = false
				if band.zMin >= tRule.zMin and band.zMax <= tRule.zMax then
					for _, other in ipairs(bands) do
						if other.zMin >= band.zMax + tRule.above then tBuried = true break end
					end
				end
				if not tBuried then tOut[#tOut + 1] = band end
			end
			bands = tOut
		end
	end
	return bands
end
Engine.FloorBands = function(_, x, y) return tFloorBands(tNet(), x, y) end

-- Height of the player's floor. Forever gives no height, so: the floors the map has at (x, y) (engine bands) are matched with the
-- floors of the Sku waypoints around (Engine_Heights): a band that no nearby Sku waypoint can stand on is out. Exactly one band
-- left = the floor. Several left: the one nearest to the last known height (within 6 yd). Nothing clear: nil (no route).
function Engine:PlayerHeight(x, y, aGroup)
	local N = tNet()
	aGroup = aGroup or tGroupAt(x, y)
	if not aGroup then return nil end
	tLoadGroup(aGroup)
	local bands = tFloorBands(N, x, y)
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
	-- [Floor fallback, Forever 13.11.2026] no band fits the heights of the Sku waypoints around (their heights do not match the map there,
	-- e.g. at the Hall of Thanes): then ALL floors of the map at this point are possible and the floor question is asked, instead of
	-- "height unknown" without any choice.
	if #left == 0 then
		for _, band in ipairs(bands) do left[#left + 1] = (band.zMin + band.zMax) / 2 end
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
	-- [WV-only areas, 16.11.2026] as WV does (ReadMe, "Bind the start"): where the height is unknown and floors are stacked, the RUNNING
	-- ROUTE decides first (the player stands on the floor of the point of the last route nearest to him), then the last known height,
	-- then the floor question. Only for groups flagged wv (elsewhere the last known height, which follows the player along
	-- an engine route, see Engine:TrackHeight).
	if #layers > 1 and tWvAt(aGroup, x, y) then
		local tRz = self:RouteHeightAt(x, y)
		if tRz then
			local best, bd
			for _, z in ipairs(layers) do
				local dz = math.abs(z - tRz)
				if not bd or dz < bd then best, bd = z, dz end
			end
			if bd <= 6 then
				tLastZ = best
				return best, "route"
			end
		end
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
	if #layers > 1 then return nil, "ambiguous", layers end
	return nil
end

-- Do two engine routes start the same way? The positions along the first TRUNK_LEN yards of both are compared point by point
-- (nearest point of the other route within TRUNK_TOL yd).
local TRUNK_LEN, TRUNK_TOL = 40, 3
local function tRoutesAgree(N, aR1, aR2)
	local function tPoints(r)
		local out, acc, lx, ly = {}, 0, nil, nil
		for _, id in ipairs(r.path) do
			local x, y = N.Position(id)
			if x and y then
				if lx then acc = acc + math.sqrt((x - lx) ^ 2 + (y - ly) ^ 2) end
				out[#out + 1] = {x, y, acc}
				lx, ly = x, y
				if acc >= TRUNK_LEN then break end
			end
		end
		return out
	end
	local p1, p2 = tPoints(aR1), tPoints(aR2)
	for _, a in ipairs(p1) do
		local ok = false
		for _, b in ipairs(p2) do
			if (a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 <= TRUNK_TOL ^ 2 then ok = true break end
		end
		if not ok then return false end
	end
	return true
end

-- The floors the player could stand on right now, lowest first, when the height is unclear (several floors at the position and none
-- decided by the last known height); otherwise nil. The target lists use it to offer the floor question after the target pick.
function Engine:FloorChoices()
	if not self:Available() then return nil end
	local px, py = UnitPosition("player")
	if type(px) ~= "number" or type(py) ~= "number" then return nil end
	local tGroup = tPlayerGroupAt(px, py)
	if not tGroup then return nil end
	local _, _, tLayers = self:PlayerHeight(px, py, tGroup)
	return tLayers
end

-- [Entry points, Forever 13.11.2026] The engine entry points of the route lists: the nearest named engine targets (the catalog targets
-- that Sku does not cover, the same ones the target lists offer: dungeon entrances, landings, quest givers, ...), at most aMax, one per
-- name. As the entry points of Sku are the nearest waypoints. Returns {{x, y, name, kind, dist}, ...}, nearest first. (The engine
-- routes from where the player stands; the entry point only names the place and carries the floor question.)
function Engine:EntryPoints(aMax)
	-- [Quest book speed, 15.11.2026] ~65 ms per call and called again for every step through the quest menu: kept for 10 s while the
	-- player stands on the same spot (the result only depends on the position).
	local px, py = UnitPosition("player")
	local tC = self.entryPointsCache
	-- [Forever, 27.11.2026] at a new NPC the engine takes over there are no Sku entry points: then these stand for them,
	-- so they are the NEAREST targets, those Sku knows included (else only far crates and wreckage were left, Menethil)
	local tSpot = (SkuNav.AtEngineOnlySpot and SkuNav:AtEngineOnlySpot()) or false
	if tC and tC.x == px and tC.y == py and tC.max == aMax and tC.spot == tSpot and (GetTime() - tC.time) < 10 then
		return tC.list
	end
	local rList, tSeen = {}, {}
	for _, t in ipairs(self:ListTargets(tSpot and {} or nil)) do
		local tKey = string.lower(t.name)
		-- at the spot a unit comes twice (catalog "Name (Role)" and Sku "Name;Role;..."): once is enough
		if tSpot then tKey = string.match(tKey, "^[^;]*"):gsub("%s*%(.*$", "") end
		if not tSeen[tKey] then
			tSeen[tKey] = true
			rList[#rList + 1] = t
			if #rList >= aMax then break end
		end
	end
	if type(px) == "number" and type(py) == "number" then
		self.entryPointsCache = {x = px, y = py, max = aMax, spot = tSpot, time = GetTime(), list = rList}
	end
	return rList
end

-- [Target floor, 15.11.2026] The catalog target a route goal stands for. Its node carries the floor of the NPC. A goal from a Sku
-- waypoint (quest book "Annahme", route lists) has no height and its position differs a little from the catalog (map percent, rounding),
-- so the exact match (0.5 yd) failed and the route went to the nearest of ALL floors at (x, y): a tower with 7 floors (Tower of Azora)
-- ended on the wrong floor. Now: the exact match first; else the nearest catalog target of the SAME NAME within SNAP_YD.
-- [Special targets, 15.11.2026] Targets the catalog does not have (no NPC, no node of the engine): {x, y, nameDe, nameEn, kindDe, kindEn,
-- nil, z}. They are added to the catalog of their group. The 8th field is the height of the floor the target lies on: the route ends on
-- that floor (without it the shortest of all floors at (x, y) wins, which is the wrong one where floors lie on top of each other).
local EXTRA_TARGETS = {}   -- empty: the only entry (warlock summoning circle, Stormwind) was tried in the game on 15.11.2026 and taken out again
local tExtrasDone = {}
-- [WV-only areas, 16.11.2026] WV asks for the floor of a TARGET that has no fixed node of its own and lies over several walkable floors
-- (ReadMe, targets, field l). Here the question is the target list itself: such a target is offered once per floor, "<name>, floor n of N"
-- ("<name>, Ebene n von N"), with the height of the floor as 8th field (the route ends on that floor). Only for groups flagged wv.
-- [Multi-node targets, 16.11.2026] A target can have SEVERAL fixed nodes at its coordinates (one per floor, e.g. Constable Aonda in Zephras:
-- 814.9 and 826.7). WV (TargetResolver, levels) asks which one; the engine used to take only the lowest. This lists them, lowest first:
-- { {zone, i, z}, ... } (public API only: one TargetNodeAt per height band of the point).
local function tNodesAt(aGroup, x, y)
	local N = tNet()
	local rList, tSeen = {}, {}
	if not (N and N.TargetNodeAt and N.HeightBands) then return rList end
	local tMids = {}
	for _, b in ipairs(N.HeightBands(x, y) or {}) do tMids[#tMids + 1] = (b.zMin + b.zMax) / 2 end
	for _, z in ipairs(aGroup.zones) do
		local zone = N.zones and N.zones[z]
		if zone then
			for _, m in ipairs(tMids) do
				local i = N.TargetNodeAt(zone, x, y, m, 3)
				if i and not tSeen[z .. ":" .. i] then
					tSeen[z .. ":" .. i] = true
					rList[#rList + 1] = {zone = zone, i = i, z = zone.z[i]}
				end
			end
		end
	end
	table.sort(rList, function(a, b) return a.z < b.z end)
	return rList
end

local function tExpandTargetFloors(aGroup, aList)
	local N = tNet()
	local rNew, tSplit = {}, 0
	for _, t in ipairs(aList) do
		local tDone = false
		if not t[8] and tWvAt(aGroup, t[1], t[2]) then
			local tHasNode = false
			for _, z in ipairs(aGroup.zones) do
				local zone = N.zones and N.zones[z]
				if zone and N.TargetNodeAt and N.TargetNodeAt(zone, t[1], t[2], nil, 3) then tHasNode = true break end
			end
			local tNodes = tHasNode and tNodesAt(aGroup, t[1], t[2]) or {}
			if #tNodes > 1 then
				-- several fixed nodes: one entry per node, the node's height as 8th field (Route ends on that node)
				for i, n in ipairs(tNodes) do
					rNew[#rNew + 1] = {t[1], t[2], t[3]..", Ebene "..i.." von "..#tNodes, t[4]..", floor "..i.." of "..#tNodes, t[5], t[6], t[7], n.z}
				end
				tDone, tSplit = true, tSplit + 1
			elseif not tHasNode then
				local tMids = {}
				for _, b in ipairs(N.HeightBands(t[1], t[2]) or {}) do tMids[#tMids + 1] = (b.zMin + b.zMax) / 2 end
				table.sort(tMids)
				local tLayers = {}
				for _, z in ipairs(tMids) do
					if #tLayers > 0 and z - tLayers[#tLayers] <= 2 then tLayers[#tLayers] = (tLayers[#tLayers] + z) / 2 else tLayers[#tLayers + 1] = z end
				end
				if #tLayers > 1 then
					for i, z in ipairs(tLayers) do
						rNew[#rNew + 1] = {t[1], t[2], t[3]..", Ebene "..i.." von "..#tLayers, t[4]..", floor "..i.." of "..#tLayers, t[5], t[6], t[7], z}
					end
					tDone, tSplit = true, tSplit + 1
				end
			end
		end
		if not tDone then rNew[#rNew + 1] = t end
	end
	if tSplit > 0 then
		for i = #aList, 1, -1 do aList[i] = nil end
		for i, t in ipairs(rNew) do aList[i] = t end
	end
	tLog("targetFloors", "split", tSplit)
end

local function tEnsureExtras(aGroup)
	local tList = _G.SkuEngineTargets and _G.SkuEngineTargets[aGroup.key]
	if not tList or tExtrasDone[tList] then return end
	tExtrasDone[tList] = true
	for _, t in ipairs(EXTRA_TARGETS[aGroup.key] or {}) do tList[#tList + 1] = t end
	if aGroup.wv or aGroup.wvbox then tExpandTargetFloors(aGroup, tList) end
end

local SNAP_YD = 10
local function tSnapNorm(aName)
	local r = string.lower(aName)
	r = string.gsub(r, "[%(%)]", " ")
	r = string.gsub(r, "%s+", " ")
	return (string.gsub(string.gsub(r, "^ ", ""), " $", ""))
end
local function tCatalogTargetFor(aGroup, aTx, aTy, aName)
	tEnsureExtras(aGroup)
	local tList = _G.SkuEngineTargets and _G.SkuEngineTargets[aGroup.key] or {}
	local tFirstMatch
	for _, t in ipairs(tList) do
		if math.abs(t[1] - aTx) < 0.5 and math.abs(t[2] - aTy) < 0.5 then
			if not tWvAt(aGroup, t[1], t[2]) then return t end
			-- wv groups: one target may stand once per floor at the same (x, y): the entry of the picked name decides
			tFirstMatch = tFirstMatch or t
			if type(aName) == "string" then
				local tPick = string.match(string.match(aName, "([^#]*)$") or aName, "^([^;]*)")
				if tPick and (tSnapNorm(tPick) == tSnapNorm(t[3]) or tSnapNorm(tPick) == tSnapNorm(t[4])) then return t end
			end
		end
	end
	if tFirstMatch then return tFirstMatch end
	if type(aName) ~= "string" then return nil end
	local tFirst = string.match(string.match(aName, "([^#]*)$") or aName, "^([^;]*)")
	if not tFirst or tFirst == "" then return nil end
	local tKey = tSnapNorm(tFirst)
	local tBest, tBestD
	for _, t in ipairs(tList) do
		local d = (t[1] - aTx) ^ 2 + (t[2] - aTy) ^ 2
		if d <= SNAP_YD ^ 2 and (not tBestD or d < tBestD) then
			for _, tCat in ipairs({t[3], t[4]}) do
				local tBase = string.match(tCat, "^(.-)%s*%(")
				if tSnapNorm(tCat) == tKey or (tBase and tSnapNorm(tBase) == tKey) then
					tBest, tBestD = t, d
					break
				end
			end
		end
	end
	return tBest
end

-- Engine route from the player's position to a target (x, y). Returns a list of world points {{x, y}, ...} or nil, reason.
-- aName (optional): the name of the target (Sku waypoint name or catalog name), to find its catalog target when the position is a bit off.
-- Heights of the fixed nodes at a point when it has SEVERAL (WV areas only, the target stands on more than one floor), else nil.
function Engine:TargetFloors(aX, aY)
	local px, py = UnitPosition("player")
	if type(px) ~= "number" or type(py) ~= "number" then return nil end
	local tGroup = tPlayerGroupAt(px, py)
	if not tGroup or not tWvAt(tGroup, aX, aY) then return nil end
	tLoadGroup(tGroup)
	local tList = tNodesAt(tGroup, aX, aY)
	if #tList < 2 then return nil end
	local rZ = {}
	for i, n in ipairs(tList) do rZ[i] = n.z end
	return rZ
end

-- [Safe routes, Forever 26.11.2026] WowNav's "safe routes" (NavNetwork SetSafety): a route may be up to SAFE_PERCENT longer than the
-- shortest one to pass fewer yards near the places where monsters usually stand (SkuEngineDanger, Engine_Danger_<group>.lua).
-- Only in the new areas (group wv / inside a wvbox), only out of combat (several searches per route = more script time) and only
-- with the setting SkuNav.engineSafeRoutes on. Everywhere else the engine plans exactly as before.
local SAFE_PERCENT = 50
local function tDangerSource(aZoneId)
	local tRows = _G.SkuEngineDanger and _G.SkuEngineDanger[aZoneId]
	if not tRows then return nil end
	local tList = {}
	for i = 1, #tRows do
		local r = tRows[i]
		tList[i] = {x = r[1], y = r[2], z = r[3] or nil, name = r[4]}
	end
	return tRows, tList
end
local function tSafeWanted(aGroup, aPx, aPy, aTx, aTy)
	if SkuSettings:Sub("SkuNav").engineSafeRoutes == false then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	return tWvAt(aGroup, aPx, aPy) or tWvAt(aGroup, aTx, aTy)
end

-- [Safe routes, Forever 26.11.2026] The first safe route of an area had to prepare the monster data of its zones (BuildDanger), a wait
-- of seconds. That is done in the background after the zones of the player's group are loaded: about 3 ms per frame, never in combat.
local tDangerBusy
local function tPrepareDanger(aGroup)
	local N = tNet()
	if tDangerBusy == aGroup.key or not N.PrepareDanger or not C_Timer then return end
	if SkuSettings:Sub("SkuNav").engineSafeRoutes == false then return end
	local tZones = {}
	for _, z in ipairs(aGroup.zones) do
		if _G.SkuEngineDanger and _G.SkuEngineDanger[z] and N.zones and N.zones[z] and not N.zones[z].danger then tZones[#tZones + 1] = N.zones[z] end
	end
	if #tZones == 0 then return end
	N.DangerSource = tDangerSource
	local tStart = 0
	local function tPause()
		if debugprofilestop() - tStart > 3 then coroutine.yield() end
	end
	local co = coroutine.create(function()
		for _, zone in ipairs(tZones) do N.PrepareDanger(zone, tPause) end
	end)
	tDangerBusy = aGroup.key
	local function tStep()
		if InCombatLockdown and InCombatLockdown() then C_Timer.After(1, tStep) return end
		tStart = debugprofilestop()
		local ok, err = coroutine.resume(co)
		if ok and coroutine.status(co) ~= "dead" then C_Timer.After(0, tStep) return end
		tDangerBusy = nil
		tLog("safe route", ok and "monster data prepared" or "prepare error", ok and aGroup.key or tostring(err), #tZones)
	end
	C_Timer.After(0, tStep)
end
Engine.PrepareDanger = function(_, aGroup) tPrepareDanger(aGroup) end

-- [Stair repair, Forever 26.11.2026] Some links of the network climb a narrow stair in one long straight line. Walking with
-- "turn to waypoint" (a rest error of up to 3 degrees stays) then ends beside the stair top, wedged in a corner. The network has
-- nodes along those stairs: they are put back into the route as intermediate points. Matched by coordinates and heights, so a
-- new data build that no longer has such a segment leaves the route untouched.
--   top    = the upper end of the long segment
--   chain  = nodes of the stair, from the bottom to the top (each neighbours linked in the network); the last one is always used
--   offAxis = how far (yd) the lower end of the segment may lie beside the line from the first chain node to the top
local STAIR_REPAIRS = {
	-- Stormwind, Trade District, way up to the flight master (Dungar Longdrink)
	{ top = {-8850.9, 525.8, 106.3}, chain = { {-8835.5, 542.6, 97.4}, {-8843.2, 532.2, 102.9}, {-8847.7, 527.0, 106.2} }, offAxis = 4 },
}
local function tStairBottom(aRepair, aPoint, aZ)
	local tTop, tFirst = aRepair.top, aRepair.chain[1]
	if aZ > tTop[3] - 1.5 then return false end
	-- on the stair side of the top (not past it), close to the axis of the stair
	local ax, ay = tFirst[1] - tTop[1], tFirst[2] - tTop[2]
	local tLen = math.sqrt(ax * ax + ay * ay)
	local px, py = aPoint[1] - tTop[1], aPoint[2] - tTop[2]
	local tAlong = (px * ax + py * ay) / tLen
	return tAlong > 3 and tAlong < 60 and math.abs(px * ay - py * ax) / tLen <= aRepair.offAxis
end
local function tRepairStairs(aPts, aZs)
	for _, tRepair in ipairs(STAIR_REPAIRS) do
		local tTop = tRepair.top
		local function tIsTop(i)
			return aZs[i] and math.abs(aZs[i] - tTop[3]) <= 1.5 and (aPts[i][1] - tTop[1]) ^ 2 + (aPts[i][2] - tTop[2]) ^ 2 <= 4 ^ 2
		end
		local i = 1
		while i < #aPts do
			local tUp = tIsTop(i + 1) and aZs[i] and tStairBottom(tRepair, aPts[i], aZs[i])
			local tDown = not tUp and tIsTop(i) and aZs[i + 1] and tStairBottom(tRepair, aPts[i + 1], aZs[i + 1])
			if tUp or tDown then
				local tLow, tHigh = tUp and i or i + 1, tUp and i + 1 or i
				local tAdd = {}
				for n, c in ipairs(tRepair.chain) do
					-- only the nodes above the lower end, and none that nearly coincides with an end of the segment
					if (n == #tRepair.chain or c[3] > aZs[tLow] + 0.8)
						and (c[1] - aPts[tLow][1]) ^ 2 + (c[2] - aPts[tLow][2]) ^ 2 >= 4
						and (c[1] - aPts[tHigh][1]) ^ 2 + (c[2] - aPts[tHigh][2]) ^ 2 >= 4 then
						tAdd[#tAdd + 1] = c
					end
				end
				for n = 1, #tAdd do
					local c = tUp and tAdd[n] or tAdd[#tAdd - n + 1]
					table.insert(aPts, i + n, {c[1], c[2]})
					table.insert(aZs, i + n, c[3])
				end
				if #tAdd > 0 then tLog("stair repair", tUp and "up" or "down", "points added", #tAdd) end
				i = i + #tAdd
			end
			i = i + 1
		end
	end
end
Engine.RepairStairs = function(_, aPts, aZs) tRepairStairs(aPts, aZs) end

-- [Walk-in portals, Forever 27.11.2026] After WoW_NavigationData 5a1290b (WowVision route.lua, Route.triggerPoint): a portal the
-- player walks into is a link of the route, but its start node may lie outside the portal's trigger (Rut'theran to Darnassus:
-- 11 yd from the centre of the 10 yd trigger). The route then goes on to the activation point of the data inside the trigger.
local function tInVolume(v, x, y, z)
	if type(v) ~= "table" or type(v.x) ~= "number" or type(v.y) ~= "number" or type(v.z) ~= "number" then return false end
	local dx, dy, dz = x - v.x, y - v.y, z - v.z
	if v.type == "sphere" or (v.type == nil and type(v.radius) == "number") then
		return type(v.radius) == "number" and v.radius > 0 and dx * dx + dy * dy + dz * dz <= v.radius * v.radius
	end
	if v.half_x and v.half_y and v.half_z and v.yaw_radians then
		local c, s = math.cos(v.yaw_radians), math.sin(v.yaw_radians)
		return math.abs(c * dx + s * dy) <= v.half_x and math.abs(-s * dx + c * dy) <= v.half_y and math.abs(dz) <= v.half_z
	end
	return false
end
-- Sku counts a point as reached 1 yd before it, and the activation point lies only 0.4 yd inside the trigger. So a round
-- trigger's point is moved towards its centre, to half the radius at most: the player is inside before the point is reached.
local function tDeeper(v, c)
	local x, y = c.x, c.y
	local dx, dy = x - v.x, y - v.y
	local d = math.sqrt(dx * dx + dy * dy)
	if type(v.radius) == "number" and d > v.radius * 0.5 then
		local f = v.radius * 0.5 / d
		x, y = v.x + dx * f, v.y + dy * f
	end
	return {x = x, y = y, z = c.z}
end
-- The activation point of the walk-in portal that leads from node aFrom to node aTo, or nil.
local function tPortalPoint(N, aFrom, aTo)
	for _, zone in pairs(N.zones or {}) do
		local tActions = zone.actionsFrom and zone.actionsFrom[aFrom - zone.base]
		for _, action in ipairs(tActions or {}) do
			if action.toNode == aTo and type(action.activation) == "table" and action.activation.mode == "walk_into_volume" then
				local px, py = N.Position(aFrom)
				local tTol = (N.TARGET_XY_TOLERANCE or 0.05) + 0.001
				for _, c in ipairs(zone.captures or {}) do
					if c.activationMode == "walk_into_trigger" and c.facilityRole == "entrance"
						and type(c.activationPreX) == "number" and type(c.activationPreY) == "number"
						and math.abs(c.activationPreX - px) <= tTol and math.abs(c.activationPreY - py) <= tTol
						and type(c.x) == "number" and type(c.y) == "number" and type(c.z) == "number"
						and tInVolume(action.sourceVolume, c.x, c.y, c.z) then
						return tDeeper(action.sourceVolume, c)
					end
				end
			end
		end
	end
end

function Engine:Route(aTx, aTy, aFloorZ, aName, aTargetZ)
	self.lastSafeDetour = nil
	if not self:Available() then return nil, "unavailable" end
	local N = tNet()
	local px, py = UnitPosition("player")
	if type(px) ~= "number" or type(py) ~= "number" then return nil, "no_position" end
	local tGroup = tPlayerGroupAt(px, py)
	if not tGroup then return nil, "wrong_zone" end
	if not tInGroup(tGroup, aTx, aTy) then return nil, "wrong_zone" end
	tLoadGroup(tGroup)
	-- safety is set for every call: off while the floor of the player is worked out (height question, "same start" rule)
	local tSafe = N.SetSafety and tSafeWanted(tGroup, px, py, aTx, aTy)
	local tPoints
	local function tSetSafe(aOn, aStartZ)
		if not N.SetSafety then return end
		N.DangerSource = tDangerSource
		N.SetSafety(aOn and SAFE_PERCENT or 0)
		tPoints = aOn and {{x = px, y = py, z = aStartZ}, {x = aTx, y = aTy}} or nil
	end
	local function tSearch(aStart, aGoal)
		return N.Route(aStart, aGoal, nil, nil, nil, nil, tPoints)
	end
	tSetSafe(false)
	local pz, how, tLayers
	if aFloorZ then
		-- the player named the floor (floor question after the target pick): that height counts, and it is remembered as the last known one
		pz, how = aFloorZ, "chosen"
		tLastZ = aFloorZ
	else
		pz, how, tLayers = self:PlayerHeight(px, py, tGroup)
	end
	if not pz and not tLayers then return nil, "height_unknown" end
	-- the best route from a bound start to the target (every floor of the map at the target is tried, the shortest wins)
	local tCat = tCatalogTargetFor(tGroup, aTx, aTy, aName)
	local function tBestFrom(start)
		local best
		-- a target of the catalog (landing, boarding point on the ship, fishing spot, ...) has a node of its own at its coordinates
		-- (the dock model of the engine): the route ends exactly on it, no cell is needed there
		if tCat then
			local t = tCat
			local tMulti = tWvAt(tGroup, t[1], t[2]) and tNodesAt(tGroup, t[1], t[2]) or {}
			if #tMulti > 1 then
				-- several nodes (floors) at the target, WV areas only: the floor of the picked entry decides (8th field, within 6 yd);
				-- a goal without a picked floor (quest book name) takes the shortest route of all nodes
				local tPick
				local tTz = aTargetZ or t[8]
				if tTz then
					for _, n in ipairs(tMulti) do
						if math.abs(n.z - tTz) <= 6 and (not tPick or math.abs(n.z - tTz) < math.abs(tPick.z - tTz)) then tPick = n end
					end
				end
				for _, n in ipairs(tPick and {tPick} or tMulti) do
					local goal = N.NodeTargetBinding(n.zone, n.i, t[1], t[2], "target_node")
					local r = tSearch(start, goal)
					if r and (not best or r.length < best.length) then best = r end
				end
			else
				for _, z in ipairs(tGroup.zones) do
					local zone = N.zones and N.zones[z]
					local i = zone and N.TargetNodeAt and N.TargetNodeAt(zone, t[1], t[2], nil, 3)
					if i then
						local goal = N.NodeTargetBinding(zone, i, t[1], t[2], "target_node")
						local r = tSearch(start, goal)
						if r and (not best or r.length < best.length) then best = r end
						break
					end
				end
			end
		end
		local tBands = not best and tFloorBands(N, aTx, aTy) or {}
		if tCat and tCat[8] and #tBands > 1 then
			-- special target with its own floor: only the floor of that height (within 6 yd)
			local tOne, tOneD
			for _, band in ipairs(tBands) do
				local d = math.abs((band.zMin + band.zMax) / 2 - tCat[8])
				if not tOneD or d < tOneD then tOne, tOneD = band, d end
			end
			if tOne and tOneD <= 6 then tBands = {tOne} end
		end
		for _, band in ipairs(tBands) do
			local tz = (band.zMin + band.zMax) / 2
			local goal = N.Bind(aTx, aTy, tz)
			if goal then
				local r = tSearch(start, goal)
				if r and (not best or r.length < best.length) then best = r end
			end
		end
		return best
	end
	local best
	if pz then
		local start, why = N.Bind(px, py, pz)
		if not start then return nil, why or "no_start" end
		tSetSafe(tSafe, pz)
		best = tBestFrom(start)
	else
		-- the floor of the player is not clear. Like the WowVision resolver: a question only where there is a choice. Every floor
		-- the player could stand on is tried as the start; if the target can be reached from ONE of them, the route goes from
		-- that one (no choice); from several: the floor stays unclear (a wrong floor could send the player the wrong way).
		local tAll = {}
		for _, z in ipairs(tLayers) do
			local start = N.Bind(px, py, z)
			local r = start and tBestFrom(start)
			if r then tAll[#tAll + 1] = {r = r, z = z} end
		end
		if #tAll == 0 then return nil, "no_route" end
		if #tAll > 1 then
			-- several floors reach the target: it does not matter which one the player stands on when the routes from all of them
			-- start the same way (the first TRUNK_LEN yards of the path agree within TRUNK_TOL yd); otherwise the floor stays unclear
			local tFirst = tAll[1]
			for i = 2, #tAll do
				if not tRoutesAgree(N, tFirst.r, tAll[i].r) then return nil, "height_unknown" end
			end
			table.sort(tAll, function(a, b) return a.r.length < b.r.length end)
		end
		best, pz = tAll[1].r, tAll[1].z
		how = #tAll == 1 and "only floor" or "same start"
		if tSafe then
			-- the floor is decided (with the shortest routes), now the safer route from that floor
			tSetSafe(true, pz)
			local start = N.Bind(px, py, pz)
			best = start and tBestFrom(start) or best
		end
	end
	tSetSafe(false)
	if not best then return nil, "no_route" end
	if best.pass == "s" and best.lengthA then
		self.lastSafeDetour = best.length - best.lengthA
		tLog("safe route", "detour", math.floor(self.lastSafeDetour), "near monsters", math.floor(best.danger or 0), "shortest", math.floor(best.dangerA or 0))
	end
	local pts, zs = {}, {}
	for tIndex, id in ipairs(best.path) do
		local x, y, z = N.Position(id)
		if x and y then
			local last = pts[#pts]
			if not last or math.sqrt((last[1] - x) ^ 2 + (last[2] - y) ^ 2) >= 2 then
				pts[#pts + 1] = {x, y}
				zs[#pts] = z   -- height of the point (kept apart: Sku reads only x, y of the points)
			end
			local tNext = best.path[tIndex + 1]
			local tPortal = tNext and tPortalPoint(N, id, tNext)
			if tPortal then
				pts[#pts + 1] = {tPortal.x, tPortal.y}
				zs[#pts] = tPortal.z
				tLog("portal point", math.floor(tPortal.x), math.floor(tPortal.y))
			end
		end
	end
	tRepairStairs(pts, zs)
	tLog("route", "length", math.floor(best.length), "points", #pts, "height", pz, how)
	return pts, nil, best.length, zs
end

-- Positions of ALL named Sku waypoints (targets) of the engine zones, whatever area or route they belong to. A WV target counts as
-- "Sku has it" when one of these lies within TARGET_SKU_RADIUS: the engine only fills in where Sku offers nothing.
local namedCache, namedCacheTime, namedCacheGroup
local namedVersion = 0   -- counts the changes of Sku waypoints: a list collected in the background is only kept if none happened meanwhile
local namedWarming = false
local namedRetries = 0
local namedHooked = false
-- the cached list is dropped as soon as a (non-temporary, non-quick) waypoint is created or deleted, so it is never out of date
local function tNamedDirty(self, aName, ...)
	if type(aName) == "string" then
		local tLow = string.lower(aName)
		if string.find(tLow, "^schnellwegpunkt") or string.find(tLow, "^quick waypoint") then return end
	end
	namedCache = nil
	namedVersion = namedVersion + 1
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
-- Placeholder NPCs of the capital cities (class trainer / vendor "pedestal" markers with 1 hit point, [DND]): they cannot be spoken
-- to, so they are never offered as an engine target. Skus own lists are left as they are.
local GHOST_NPCS = {26007, 26075, 26258, 26307, 26309, 26324, 26325, 26326, 26327, 26328, 26329, 26330, 26331, 26332, 26724, 26738, 26739,
	26740, 26741, 26742, 26743, 26744, 26745, 26747, 26748, 26749, 26751, 26752, 26753, 26754, 26755, 26756, 26757, 26758, 26759,
	26760, 26765}
local tGhostNames
local function tIsGhostName(aWaypointName)
	if not tGhostNames then
		tGhostNames = {}
		local tData = SkuDB and SkuDB.NpcData and SkuDB.NpcData.Data
		local tNames = SkuDB and SkuDB.NpcData and SkuDB.NpcData.Names and SkuDB.NpcData.Names[Sku.Loc]
		if not tData then tGhostNames = nil return false end
		for _, id in ipairs(GHOST_NPCS) do
			local tRow = tData[id]
			if tRow and tRow[1] then tGhostNames[string.lower(tRow[1])] = true end
			local tLoc = tNames and tNames[id]
			if type(tLoc) == "table" and tLoc[1] then tGhostNames[string.lower(tLoc[1])] = true end
		end
	end
	local tFirst = string.match(aWaypointName, "^([^;]*);")
	return tFirst ~= nil and tGhostNames[string.lower(tFirst)] == true
end

-- one waypoint name: does it count (not an "auto" waypoint, not a quick waypoint, not an engine entry, not a placeholder NPC) and does it lie
-- in the player's group? Then its position is added. Shared by the direct and the background collection so both give the same list.
local function tNamedConsider(aName, aList, aAutoLen, aGroup, aMap)
	local tLow = string.lower(aName)
	if string.sub(aName, 1, aAutoLen) ~= L["auto"].." " and string.sub(aName, -7) ~= ";Engine"
		and not string.find(tLow, "^schnellwegpunkt") and not string.find(tLow, "^quick waypoint") and not tIsGhostName(aName) then
		local tD = SkuNav:GetWaypointData2(aName)
		if tD and tD.worldX and tInGroup(aGroup, tD.worldX, tD.worldY, aMap) then
			aList[#aList + 1] = {tD.worldX, tD.worldY, aName}
		end
	end
end

-- the player's group (without loading anything) and map id, resolved ONCE for the whole collection: the loop runs over ~50,000 Sku
-- waypoints, asking UnitPosition and searching the zones for each one took seconds on the client (15.11.2026)
local function tNamedContext()
	local tPx, tPy, _, tPMap = UnitPosition("player")
	if type(tPx) ~= "number" or type(tPy) ~= "number" then return nil end
	local tPG = tGroupOf(tPx, tPy)
	if not tPG then return nil end
	return tPG, tPMap or false
end

-- [21.11.2026] No expiry any more. The list was dropped after 600 s and the next call collected it in ONE piece (1687 ms, 15704 entries,
-- log 14:48:28 "Cache abgelaufen" = the hang in the game). Now it stays valid until a Sku waypoint is created/deleted (tNamedDirty) or the
-- group changes, and after 600 s it is only REFRESHED in the background (WarmNamedPositions(true), ~3 ms per frame) while the old list
-- keeps being served. WowVision works the same way: nothing that searches runs longer than a frame's budget.
local NAMED_REFRESH_S = 600
local function tNamedCacheValid(aGroup)
	return namedCache and namedCacheTime and namedCacheGroup == aGroup.key
end

function Engine:SkuNamedPositions()
	tHookNamed()
	local tPG, tPMap = tNamedContext()
	if tPG and tNamedCacheValid(tPG) then
		if GetTime() - namedCacheTime > NAMED_REFRESH_S and not namedWarming then
			namedRetries = 0
			C_Timer.After(0, function() Engine:WarmNamedPositions(true) end)   -- background refresh, the old list is served meanwhile
		end
		return namedCache
	end
	local rPos = {}
	local tList, tState, tInit = SkuNav:ListWaypoints2(false)
	if not tList then return rPos end
	if not (tPG and tDataReady(tPG)) then return rPos end
	local tAutoLen = string.len(L["auto"]) + 1
	for _, v in tList, tState, tInit do
		tNamedConsider(v, rPos, tAutoLen, tPG, tPMap)
	end
	-- an empty result means Sku's waypoint cache is not ready yet: do not keep it
	if #rPos > 0 then namedCache, namedCacheTime, namedCacheGroup = rPos, GetTime(), tPG.key end
	return rPos
end

-- The same collection in the background: a few milliseconds per frame instead of one hang of seconds (used by the warm-up after login /
-- zone change). The result is dropped if the group changed, a Sku waypoint was created or deleted, or a direct call filled the cache meanwhile.
function Engine:WarmNamedPositions(aRefresh)
	tHookNamed()
	if namedWarming then return end
	local tPG, tPMap = tNamedContext()
	if not tPG or (tNamedCacheValid(tPG) and not aRefresh) then return end
	if InCombatLockdown and InCombatLockdown() then return end
	if not tDataReady(tPG) then return end
	local tList, tState, tInit = SkuNav:ListWaypoints2(false)
	if not tList then return end
	local tNames = {}
	for _, v in tList, tState, tInit do tNames[#tNames + 1] = v end
	local tAutoLen = string.len(L["auto"]) + 1
	local tVersion, tI, tN, rPos = namedVersion, 1, #tNames, {}
	namedWarming = true
	local function tStep()
		if namedVersion ~= tVersion then   -- a waypoint changed (Sku is still building its own): the list is out of date, try again later (3 times)
			namedWarming = false
			if namedRetries < 3 then namedRetries = namedRetries + 1 C_Timer.After(5, function() Engine:WarmNamedPositions() end) end
			return
		end
		if InCombatLockdown and InCombatLockdown() then C_Timer.After(1, tStep) return end   -- wait, nothing is done in combat
		local tNowG = tNamedContext()
		if not tNowG or tNowG.key ~= tPG.key then namedWarming = false return end   -- the player left the group
		local tStart = debugprofilestop and debugprofilestop() or 0
		while tI <= tN do
			tNamedConsider(tNames[tI], rPos, tAutoLen, tPG, tPMap)
			tI = tI + 1
			if debugprofilestop and tI % 64 == 0 and debugprofilestop() - tStart > 3 then break end   -- ~3 ms per frame
		end
		if tI <= tN then C_Timer.After(0, tStep) return end
		namedWarming = false
		if #rPos > 0 and (aRefresh or not tNamedCacheValid(tPG)) then namedCache, namedCacheTime, namedCacheGroup = rPos, GetTime(), tPG.key end
		tLog("named positions collected", #rPos, aRefresh and "refresh" or "warm")
	end
	C_Timer.After(0, tStep)
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

-- RULE (13.11.2026): the radius test must not hide the targets that matter most. Sku makes a waypoint of EVERY object (braziers,
-- banners ...), so some waypoint nearly always lies within TARGET_SKU_RADIUS.
--   * kinds Sku's own data does not have at all (dungeon entrances, public transport = landings, ships, trams): always offered.
--   * quest giver targets (kind "Questgeber...") and targets that are the goal of a quest (7th field = 1: monsters, objects, kill credits;
--     set by navpack/mark_questtargets.py): hidden only by a Sku waypoint of the SAME name within the radius (a true duplicate).
local ALWAYS_OFFER_KINDS = {Dungeoneingang = true, Verkehr = true, Sonderziel = true}

-- Names are compared without brackets and case: the catalog says "Thor (Greifenmeister)", Sku's own waypoint says "Thor Greifenmeister"
-- (14.11.2026: the Gryphon Master stood twice in the lists).
local function tNormName(aName)
	local r = string.lower(aName)
	r = string.gsub(r, "[%(%)]", " ")
	r = string.gsub(r, "%s+", " ")
	return (string.gsub(r, "^ ", ""):gsub(" $", ""))
end

local namedByNameFor, namedByName
local function tNamedByName(aNamed)
	if namedByNameFor ~= aNamed then
		namedByNameFor, namedByName = aNamed, {}
		for i = 1, #aNamed do
			local w = aNamed[i]
			local tFirst = string.match(w[3], "^([^;]*)")
			if tFirst then
				local k = tNormName(tFirst)
				local c = namedByName[k]
				if not c then c = {} namedByName[k] = c end
				c[#c + 1] = w
			end
		end
	end
	return namedByName
end

local function tSameNameNear(aByName, t)
	for _, tName in ipairs({t[3], t[4]}) do
		local tBase = string.match(tName, "^(.-)%s*%(")
		for _, tKey in ipairs({tNormName(tName), tBase and tNormName(tBase) or false}) do
		local c = tKey and aByName[tKey]
		if c then
			for i = 1, #c do
				local w = c[i]
				if (w[1] - t[1]) ^ 2 + (w[2] - t[2]) ^ 2 <= TARGET_SKU_RADIUS ^ 2 then return true end
			end
		end
		end
	end
	return false
end

-- [Multi-floor NPCs, 15.11.2026] An NPC (quest giver, trainer, vendor ...) that stands where the map has several floors (Tower of Azora:
-- the enchanting trainer is on the top floor) is ALSO offered as an engine target when Sku has a waypoint for it: Sku's way to its
-- waypoint (no height) can end on the wrong floor, the engine way ends on the NPC's own floor. Only in the target lists (aReachable given).
local NON_NPC_KINDS = {Sonderziel = true, Kreatur = true, Objekt = true, Kraut = true, Erzvorkommen = true, Angelplatz = true, Portal = true}
local tMultiFloorCache = setmetatable({}, {__mode = "k"})
local function tMultiFloor(t)
	local c = tMultiFloorCache[t]
	if c == nil then
		local tBands = tNet().HeightBands(t[1], t[2]) or {}
		local tMids = {}
		for _, b in ipairs(tBands) do tMids[#tMids + 1] = (b.zMin + b.zMax) / 2 end
		table.sort(tMids)
		local tLayers = 0
		for i, z in ipairs(tMids) do
			if i == 1 or z - tMids[i - 1] > 2 then tLayers = tLayers + 1 end
		end
		c = tLayers > 1
		tMultiFloorCache[t] = c
	end
	return c
end

local function tTargetsWithoutSku(aGroup, aGrid, px, py, aMaxDist, aNamed, aMultiFloor)
	local rBest, rOrder = {}, {}
	tEnsureExtras(aGroup)
	for _, t in ipairs(_G.SkuEngineTargets[aGroup.key] or {}) do
		local tShow
		if tWvAt(aGroup, t[1], t[2]) or ALWAYS_OFFER_KINDS[t[5]] then
			-- [WV-only areas, 16.11.2026] a group flagged wv (new Forever areas where Sku has no routes of its own: the data pack's spawns
			-- there hang on no network) takes EVERY target from WV: no radius test against Sku waypoints.
			tShow = true
		elseif aNamed and (t[7] == 1 or string.sub(t[5], 1, 10) == "Questgeber") then
			tShow = not tSameNameNear(tNamedByName(aNamed), t)
		else
			tShow = not tNearGrid(aGrid, t[1], t[2])
		end
		if not tShow and aMultiFloor and not NON_NPC_KINDS[t[5]] and tMultiFloor(t) then tShow = true end
		if tShow then
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

-- [Forever, 27.11.2026] a new NPC the engine takes over: when its catalog target stands in the list already, its
-- hidden Sku waypoint is not offered a second time
local function tOfferedByCatalog(aList, w)
	if not (SkuNav.IsEngineOnlyWp and SkuNav:IsEngineOnlyWp(w[3])) then return false end
	local tKey = tNormName(string.match(w[3], "^([^;]*)"))
	for _, t in ipairs(aList) do
		if (t.x - w[1]) ^ 2 + (t.y - w[2]) ^ 2 <= 25
			and (tNormName(t.name) == tKey or tNormName(string.match(t.name, "^(.-)%s*%(") or t.name) == tKey) then
			return true
		end
	end
	return false
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
	for _, t in ipairs(tTargetsWithoutSku(tGroup, tPosGrid({tSkuNear, tNamed}), px, py, tMaxDist, tNamed, aReachable ~= nil)) do
		t.dist = math.floor(t.dist)
		rList[#rList + 1] = t
	end
	-- Sku's own targets that Sku cannot reach from this entry point (e.g. the harbor is an island of Sku's net): the engine
	-- walks there. Only when the caller gave the reachable set; a target Sku reaches is never added.
	-- Sku names every spawn of a unit by its own waypoint ("Name;Role;Area;3;75.6;9.6"): of the spawns of one name only the nearest
	-- one is offered (as with the catalog targets above), otherwise the list holds thousands of entries.
	if aReachable and not tGroup.wv then   -- not in WV-only areas: the engine targets above already cover every spawn there
		local tBest, tOrder = {}, {}
		for _, w in ipairs(tNamed) do
			local d = (w[1] - px) ^ 2 + (w[2] - py) ^ 2
			if not aReachable[w[3]] and not (tMaxDist and d > tMaxDist ^ 2) and not tWvAt(tGroup, w[1], w[2])
				and not tOfferedByCatalog(rList, w) then
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
-- [Back, Forever 15.11.2026] "Reverse route" (Ctrl-Shift-Z) of Sku walks the waypoints of the route backwards. The way points of an
-- engine route are temporary waypoints ("Einheiten;Route;n"); they are deleted when the route ends, so Sku's reverse data points at
-- nothing and the key stays silent. The engine therefore keeps the points of its last route and, when Sku's reverse data is gone,
-- walks them back as a new engine route (the points reversed, from the one nearest to the player).
local tReverseHooked = false
local function tHookReverse()
	if tReverseHooked or type(SkuNav.StartReverseRtFollow) ~= "function" then return end
	tReverseHooked = true
	local tOrig = SkuNav.StartReverseRtFollow
	SkuNav.StartReverseRtFollow = function(self, ...)
		local tRev = SkuNav.ReverseRt and SkuNav.ReverseRt.meta
		local tSkuOk = tRev and tRev.metapathFollowingStart and SkuNav:GetWaypointData2(tRev.metapathFollowingStart)
		if not tSkuOk and Engine.lastRoute and Engine:ReverseFollow() then return end
		return tOrig(self, ...)
	end
end

-- the last engine route backwards, from the point nearest to the player (a tie goes to the later point). Returns true when started.
function Engine:ReverseFollow()
	local tLast = self.lastRoute
	local px, py = UnitPosition("player")
	if not tLast or type(px) ~= "number" or type(py) ~= "number" then return false end
	local tBest, tBestD
	for i, p in ipairs(tLast.pts) do
		local d = (p[1] - px) ^ 2 + (p[2] - py) ^ 2
		if not tBestD or d <= tBestD then tBest, tBestD = i, d end
	end
	if not tBest or tBestD > 40 ^ 2 then return false end
	local rev, revZ = {}, {}
	for i = tBest, 1, -1 do rev[#rev + 1] = {tLast.pts[i][1], tLast.pts[i][2]}; revZ[#rev] = tLast.zs and tLast.zs[i] end
	if #rev < 2 then return false end
	tLog("reverse", "points", #rev)
	SkuNav.RouteFollowOnAction({name = "Engine"}, {engineTarget = {points = rev, zs = revZ, x = rev[#rev][1], y = rev[#rev][2], name = "Engine"}}, "Engine")
	return true
end

-- [Height along the route, Forever 27.11.2026] As WowVision (HeightAnchor): while an engine route is followed, the height
-- advances with the player along the current leg and is kept as the last known one after the route ends (arrival, or
-- walking it only partly). So the next route or entry list starts on the right floor, wherever in the game. Without a
-- route there is nothing to follow (the game gives no height).
local TRACK_MAX_YD = 15
local tTrackedRoute, tTrackTicker
function Engine:TrackHeight()
	local tLast = self.lastRoute
	if not (tLast and tLast.pts and tLast.zs) then return end
	local px, py = UnitPosition("player")
	if type(px) ~= "number" or type(py) ~= "number" then return end
	local function tDist(p) return math.sqrt((p[1] - px) ^ 2 + (p[2] - py) ^ 2) end
	if SkuNav.IsFollowingEngineRoute and SkuNav:IsFollowingEngineRoute() then
		local n = SkuSettings:Sub("SkuNav").metapathFollowingCurrentWp
		local b, bz = n and tLast.pts[n], n and tLast.zs[n]
		if not (b and bz) then return end
		tTrackedRoute = tLast
		local a, az = tLast.pts[n - 1], tLast.zs[n - 1]
		if not (a and az) then
			if tDist(b) <= 5 then tLastZ = bz end   -- first leg: the start height of the route counts until the first point
			return
		end
		-- distance to the leg: a player who left the route keeps the last height
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local l2 = dx * dx + dy * dy
		local t = l2 > 0.0001 and math.max(0, math.min(1, ((px - a[1]) * dx + (py - a[2]) * dy) / l2)) or 1
		if math.sqrt((a[1] + t * dx - px) ^ 2 + (a[2] + t * dy - py) ^ 2) > TRACK_MAX_YD then return end
		local da, db = tDist(a), tDist(b)
		tLastZ = (da + db > 0) and (az + (bz - az) * da / (da + db)) or bz
	elseif tTrackedRoute == tLast then
		tTrackedRoute = nil
		local e, ez = tLast.pts[#tLast.pts], tLast.zs[#tLast.pts]
		if e and ez and tDist(e) <= 8 then tLastZ = ez end   -- arrived
	end
end

local function tStartTracking()
	if not tTrackTicker and C_Timer and C_Timer.NewTicker then
		tTrackTicker = C_Timer.NewTicker(0.5, function() Engine:TrackHeight() end)
	end
end

function Engine:PrepareFollow(aTarget)
	local pts, why, tZs
	if aTarget.points then
		pts = {}   -- the way back: the points are given (reversed route), nothing to compute
		for i, p in ipairs(aTarget.points) do pts[i] = {p[1], p[2]} end
		tZs = aTarget.zs
	else
		local _
		pts, why, _, tZs = self:Route(aTarget.x, aTarget.y, aTarget.floorZ, aTarget.name, aTarget.targetZ)
	end
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
	if not aTarget.points then
		pts[#pts + 1] = {aTarget.x, aTarget.y}
		if tZs then tZs[#pts] = tZs[#pts - 1] end   -- the target stands on the floor of the last route node
	end
	-- kept for "reverse route" (see above); the heights of the points are kept too (floor of the running route, PlayerHeight)
	local tKeep = {}
	for i, p in ipairs(pts) do tKeep[i] = {p[1], p[2]} end
	self.lastRoute = {pts = tKeep, zs = tZs}
	tHookReverse()
	tStartTracking()
	if not aTarget.points and self.lastSafeDetour and self.lastSafeDetour >= 1 then
		local tDetour = math.floor(self.lastSafeDetour + 0.5)
		SkuOptions.Voice:OutputStringBTtts((Sku.Loc == "deDE") and ("Sichere Route, " .. tDetour .. " Meter Umweg")
			or ("Safe route, " .. tDetour .. " yards longer"), false, true, 0.3, true)
	end
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
	local tNamedAll = self:SkuNamedPositions()
	for _, t in ipairs(tTargetsWithoutSku(tGroup, tPosGrid({aSkuPositions, tNamedAll}), px, py, nil, tNamedAll)) do
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
	C_Timer.After(#tGroup.zones * 0.5 + 1, function() Engine:PrepareDanger(tGroup) end)
	-- the names of Sku's waypoints take ~0.4 s to collect: do it now, not when the first list is opened (kept 10 minutes)
	C_Timer.After(#tGroup.zones * 0.5 + 6, function()
		namedRetries = 0
		Engine:WarmNamedPositions()
	end)
end

if Sku.isForever and CreateFrame and C_Timer then
	local tPreloadFrame = CreateFrame("Frame")
	tPreloadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	tPreloadFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	tPreloadFrame:SetScript("OnEvent", function()
		C_Timer.After(8, function()
			if not Engine.__revisionLogged then
				-- shadow number of the engine (data + code), never spoken: only in the debug log, see navpack/engine-staende/README.md
				Engine.__revisionLogged = true
				dprint("engine revision", tostring(_G.SkuEngineRevision or "?"))
			end
			Engine:Preload()
		end)
	end)
end

-- [Forever, 20.11.2026] Warm-up also when the player's group changes WITHOUT a zone event (zone boxes of neighbouring groups overlap; flights,
-- ships and riding along a border cross them silently). ZONE_CHANGED_NEW_AREA alone left the new group cold until the first list was opened
-- (loading and decoding the zones: a second or more). Checked every 3 s with the cheap box test (no addon is loaded for the check); the
-- warm-up itself is Engine:Preload (idempotent: loaded zones, grid and name cache are kept). Not in combat. Memory stays at the player's group
-- (plus a group used in the last 90 s, see tUnloadOtherGroups).
if Sku.isForever and C_Timer and C_Timer.NewTicker then
	local tLastKey
	C_Timer.NewTicker(3, function()
		if InCombatLockdown and InCombatLockdown() then return end
		if not Engine:Available() then return end
		local px, py = UnitPosition("player")
		if type(px) ~= "number" or type(py) ~= "number" then return end
		local tG = tGroupOf(px, py)
		local tKey = tG and tG.key or nil
		if tKey == tLastKey then return end
		tLastKey = tKey
		if tKey then C_Timer.After(1, function() Engine:Preload() end) end
	end)
end
