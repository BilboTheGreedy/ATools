local dbDir, questieDir, outDir = arg[1], arg[2], arg[3]
local Q = dofile("tools/qdb.lua")
local lib = Q.load(dbDir, "QuestieDB_Forever.toc")
local Quest, Npc, Item, Object = lib.Quest, lib.Npc, lib.Item, lib.Object

local zone = lib.Support.Get("ZoneDB")
local function chunk(name)
	local s = zone.private[name]
	if type(s) == "table" then return s end
	if not s then return {} end
	return assert(loadstring(s))()
end
local areaToMap = chunk("areaIdToUiMapId")
for k, v in pairs(chunk("areaIdToUiMapIdOverride")) do areaToMap[k] = v end
local dungeons = chunk("dungeons")

local blacklist, npcBlacklist = {}, {}
do
	local modules = {}
	local function module(name)
		if not modules[name] then modules[name] = {} end
		return modules[name]
	end
	local big = setmetatable({}, { __index = function() return 99 end })
	module("ContentPhases").activePhases = big
	local e = module("Expansions")
	e.Era, e.Classic, e.Tbc, e.Wotlk, e.Cata, e.MoP, e.Current = 1, 1, 2, 3, 4, 5, 1
	QuestieLoader = {
		ImportModule = function(_, name) return module(name) end,
		CreateModule = function(_, name) return module(name) end,
	}
	Questie = setmetatable({}, { __index = function() return false end })
	local function load(file, name)
		local f = loadfile(questieDir .. "/Database/Corrections/" .. file)
		if not f then return {} end
		local ok = pcall(f)
		if not ok then return {} end
		local ok2, t = pcall(function() return module(name):Load() end)
		return ok2 and t or {}
	end
	blacklist = load("QuestieQuestBlacklist.lua", "QuestieQuestBlacklist")
	npcBlacklist = load("QuestieNPCBlacklist.lua", "QuestieNPCBlacklist")
end

local function quote(s)
	return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "") .. '"'
end

local function clean(s)
	return (tostring(s or ""):gsub("[|\n\r]", " "))
end

local function round(v) return math.floor(v * 10 + 0.5) end

local CELL = 40
local function thin(points)
	if #points <= 6 then return points end
	local cells, order = {}, {}
	for _, p in ipairs(points) do
		local key = math.floor(p[1] / CELL) * 1000 + math.floor(p[2] / CELL)
		local c = cells[key]
		if not c then
			c = { 0, 0, 0 }
			cells[key] = c
			order[#order + 1] = key
		end
		c[1], c[2], c[3] = c[1] + p[1], c[2] + p[2], c[3] + 1
	end
	local out = {}
	for _, key in ipairs(order) do
		local c = cells[key]
		out[#out + 1] = { math.floor(c[1] / c[3] + 0.5), math.floor(c[2] / c[3] + 0.5) }
	end
	return out
end

local mapsUsed = {}
local function spawnString(spawns, maps)
	if type(spawns) ~= "table" then return "" end
	local byMap, order = {}, {}
	local function add(map, x, y, inside)
		if not map or map == 0 or type(x) ~= "number" or type(y) ~= "number" then return end
		if x < 0 or y < 0 then return end
		local key = map .. (inside and "!" or ":")
		if not byMap[key] then
			byMap[key] = {}
			order[#order + 1] = key
		end
		table.insert(byMap[key], { round(x), round(y) })
		mapsUsed[map] = true
		if maps then maps[map] = true end
	end
	local areas = {}
	for area in pairs(spawns) do areas[#areas + 1] = area end
	table.sort(areas)
	for _, area in ipairs(areas) do
		local list = spawns[area]
		local d = dungeons[area]
		if d and type(d[3]) == "table" then
			for _, e in ipairs(d[3]) do
				add(areaToMap[e[1]], e[2], e[3], true)
			end
		elseif type(list) == "table" then
			for _, p in ipairs(list) do
				if type(p) == "table" then add(areaToMap[area], p[1], p[2]) end
			end
		end
	end
	local parts = {}
	for _, key in ipairs(order) do
		local pts = byMap[key]
		if key:sub(-1) == "!" then
			local seen, uniq = {}, {}
			for _, p in ipairs(pts) do
				local k = p[1] * 10000 + p[2]
				if not seen[k] then seen[k] = true uniq[#uniq + 1] = p end
			end
			pts = uniq
		else
			pts = thin(pts)
		end
		local flat = {}
		for _, p in ipairs(pts) do flat[#flat + 1] = p[1] .. "," .. p[2] end
		parts[#parts + 1] = key .. table.concat(flat, ",")
	end
	return table.concat(parts, ";")
end

local function ids(t)
	if type(t) ~= "table" then return nil end
	local out = {}
	for _, v in ipairs(t) do
		if type(v) == "number" and v ~= 0 then out[#out + 1] = v end
	end
	if #out == 0 then return nil end
	return out
end

local function lit(v)
	if type(v) == "table" then
		local parts = {}
		local n = #v
		for i = 1, n do parts[#parts + 1] = lit(v[i]) end
		local keys = {}
		for k in pairs(v) do
			if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then keys[#keys + 1] = k end
		end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, k in ipairs(keys) do
			if type(k) == "number" then
				parts[#parts + 1] = "[" .. k .. "]=" .. lit(v[k])
			else
				parts[#parts + 1] = k .. "=" .. lit(v[k])
			end
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif type(v) == "string" then
		return quote(v)
	end
	return tostring(v)
end

local needNpc, needObj, needItem = {}, {}, {}
local quests, questIds = {}, {}
local hidden = 0

for _, id in ipairs(Quest.GetAllIds()) do
	local name = Quest.Get(id, "name")
	local bl = blacklist[id]
	if bl == true then
		hidden = hidden + 1
	elseif type(name) == "string" and name ~= "" then
		local q = { n = name }
		q.l = Quest.Get(id, "questLevel")
		q.m = Quest.Get(id, "requiredLevel")
		local maxLevel = Quest.Get(id, "requiredMaxLevel")
		if maxLevel and maxLevel > 0 then q.x = maxLevel end
		local races = (Quest.Get(id, "requiredRaces") or 0) % 256
		if races ~= 0 and races ~= 255 then q.r = races end
		local classes = Quest.Get(id, "requiredClasses") or 0
		if classes ~= 0 then q.c = classes % 2048 end
		q.z = Quest.Get(id, "zoneOrSort")
		local special = Quest.Get(id, "specialFlags") or 0
		if special % 2 == 1 then q.rep = 1 end
		if bl then q.h = 1 end
		local sb = Quest.Get(id, "startedBy") or {}
		q.s1, q.s2, q.s3 = ids(sb[1]), ids(sb[2]), ids(sb[3])
		local fb = Quest.Get(id, "finishedBy") or {}
		q.e1, q.e2 = ids(fb[1]), ids(fb[2])
		local obj = Quest.Get(id, "objectives") or {}
		local function objIds(list)
			if type(list) ~= "table" then return nil end
			local out = {}
			for _, o in ipairs(list) do
				if type(o) == "table" and type(o[1]) == "number" then out[#out + 1] = o[1] end
			end
			return #out > 0 and out or nil
		end
		q.oc, q.oo, q.oi = objIds(obj[1]), objIds(obj[2]), objIds(obj[3])
		if type(obj[5]) == "table" then
			local kc = {}
			for _, o in ipairs(obj[5]) do
				if type(o) == "table" and type(o[1]) == "table" then
					local group = {}
					for _, npc in ipairs(o[1]) do
						if type(npc) == "number" then group[#group + 1] = npc end
					end
					if #group > 0 then kc[#kc + 1] = group end
				end
			end
			if #kc > 0 then q.ok = kc end
		end
		local trig = Quest.Get(id, "triggerEnd")
		if type(trig) == "table" and type(trig[2]) == "table" then
			local s = spawnString(trig[2])
			if s ~= "" then q.te = s end
		end
		local extra = Quest.Get(id, "extraObjectives")
		if type(extra) == "table" then
			local list = {}
			for _, e in ipairs(extra) do
				if type(e) == "table" and type(e[1]) == "table" then
					local s = spawnString(e[1])
					if s ~= "" then list[#list + 1] = s end
				end
			end
			if #list > 0 then q.eo = list end
		end
		local src = Quest.Get(id, "sourceItemId")
		if src and src ~= 0 then q.si = src end
		q.rs = ids(Quest.Get(id, "requiredSourceItems"))
		q.pg = ids(Quest.Get(id, "preQuestGroup"))
		q.ps = ids(Quest.Get(id, "preQuestSingle"))
		q.ex = ids(Quest.Get(id, "exclusiveTo"))
		local nx = Quest.Get(id, "nextQuestInChain")
		if nx and nx ~= 0 then q.nx = nx end
		local pq = Quest.Get(id, "parentQuest")
		if pq and pq ~= 0 then q.pq = pq end
		local sk = Quest.Get(id, "requiredSkill")
		if type(sk) == "table" and sk[1] and sk[1] ~= 0 then q.sk = { sk[1], sk[2] or 0 } end
		local minRep = Quest.Get(id, "requiredMinRep")
		if type(minRep) == "table" and minRep[1] and minRep[1] ~= 0 then q.rr = { minRep[1], minRep[2] or 0 } end
		local maxRep = Quest.Get(id, "requiredMaxRep")
		if type(maxRep) == "table" and maxRep[1] and maxRep[1] ~= 0 then q.rx = { maxRep[1], maxRep[2] or 0 } end
		local text = Quest.Get(id, "objectivesText")
		if type(text) == "table" and #text > 0 then q.t = table.concat(text, " ") end

		for _, l in ipairs({ q.s1 or {}, q.e1 or {}, q.oc or {} }) do
			for _, n in ipairs(l) do needNpc[n] = true end
		end
		for _, group in ipairs(q.ok or {}) do
			for _, n in ipairs(group) do needNpc[n] = true end
		end
		for _, l in ipairs({ q.s2 or {}, q.e2 or {}, q.oo or {} }) do
			for _, n in ipairs(l) do needObj[n] = true end
		end
		for _, l in ipairs({ q.s3 or {}, q.oi or {}, q.rs or {} }) do
			for _, n in ipairs(l) do needItem[n] = true end
		end
		if q.si then needItem[q.si] = true end
		quests[id] = q
		questIds[#questIds + 1] = id
	end
end
table.sort(questIds)

local items, itemIds = {}, {}
for id in pairs(needItem) do
	local name = Item.Get(id, "name")
	if name then
		local it = {
			name = name,
			npcs = ids(Item.Get(id, "npcDrops")) or {},
			objs = ids(Item.Get(id, "objectDrops")) or {},
			items = ids(Item.Get(id, "itemDrops")) or {},
			vendors = ids(Item.Get(id, "vendors")) or {},
		}
		for _, n in ipairs(it.npcs) do needNpc[n] = true end
		for _, n in ipairs(it.vendors) do needNpc[n] = true end
		for _, n in ipairs(it.objs) do needObj[n] = true end
		items[id] = it
		itemIds[#itemIds + 1] = id
	end
end
table.sort(itemIds)

local npcMaps, objMaps = {}, {}
local function header(f, name)
	f:write("local _, ns = ...\nns.raw." .. name .. " = {\n")
end

local f = assert(io.open(outDir .. "/Npcs.lua", "w"))
header(f, "npcs")
local npcCount = 0
local npcIds = {}
for id in pairs(needNpc) do npcIds[#npcIds + 1] = id end
table.sort(npcIds)
for _, id in ipairs(npcIds) do
	local name = Npc.Get(id, "name")
	if name then
		local maps = {}
		local spawns = npcBlacklist[id] == true and "" or spawnString(Npc.Get(id, "spawns"), maps)
		npcMaps[id] = maps
		f:write("[", id, "]=", quote(table.concat({
			clean(name), Npc.Get(id, "minLevel") or 0, Npc.Get(id, "maxLevel") or 0,
			Npc.Get(id, "friendlyToFaction") or "", spawns,
		}, "|")), ",\n")
		npcCount = npcCount + 1
	end
end
f:write("}\n")
f:close()

f = assert(io.open(outDir .. "/Objects.lua", "w"))
header(f, "objects")
local objCount = 0
local objIdList = {}
for id in pairs(needObj) do objIdList[#objIdList + 1] = id end
table.sort(objIdList)
for _, id in ipairs(objIdList) do
	local name = Object.Get(id, "name")
	if name then
		local maps = {}
		local spawns = spawnString(Object.Get(id, "spawns"), maps)
		objMaps[id] = maps
		f:write("[", id, "]=", quote(clean(name) .. "|" .. spawns), ",\n")
		objCount = objCount + 1
	end
end
f:write("}\n")
f:close()

f = assert(io.open(outDir .. "/Items.lua", "w"))
header(f, "items")
for _, id in ipairs(itemIds) do
	local it = items[id]
	f:write("[", id, "]=", quote(table.concat({
		clean(it.name), table.concat(it.npcs, ","), table.concat(it.objs, ","),
		table.concat(it.items, ","), table.concat(it.vendors, ","),
	}, "|")), ",\n")
end
f:write("}\n")
f:close()

local starts, ends, byZone = {}, {}, {}
local STARTER_SOURCES = 10
local function index(target, id, npcs, objs, starters)
	local maps = {}
	for _, item in ipairs(starters or {}) do
		local it = items[item]
		if it and #it.npcs + #it.objs <= STARTER_SOURCES then
			for _, n in ipairs(it.npcs) do
				for m in pairs(npcMaps[n] or {}) do maps[m] = true end
			end
			for _, o in ipairs(it.objs) do
				for m in pairs(objMaps[o] or {}) do maps[m] = true end
			end
		end
	end
	for _, n in ipairs(npcs or {}) do
		for m in pairs(npcMaps[n] or {}) do maps[m] = true end
	end
	for _, o in ipairs(objs or {}) do
		for m in pairs(objMaps[o] or {}) do maps[m] = true end
	end
	for m in pairs(maps) do
		target[m] = target[m] or {}
		table.insert(target[m], id)
	end
end

f = assert(io.open(outDir .. "/Quests.lua", "w"))
header(f, "quests")
for _, id in ipairs(questIds) do
	local q = quests[id]
	f:write("[", id, "]=", quote(lit(q)), ",\n")
	if not q.h then index(starts, id, q.s1, q.s2, q.s3) end
	index(ends, id, q.e1, q.e2)
	if q.z then
		byZone[q.z] = byZone[q.z] or {}
		table.insert(byZone[q.z], id)
	end
end
f:write("}\n")
f:close()

f = assert(io.open(outDir .. "/Index.lua", "w"))
f:write("local _, ns = ...\n")
local function writeIndex(name, t)
	f:write("ns.raw." .. name .. " = {\n")
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		f:write("[", k, "]=\"", table.concat(t[k], ","), "\",\n")
	end
	f:write("}\n")
end
writeIndex("starts", starts)
writeIndex("ends", ends)
writeIndex("zonequests", byZone)
f:write("ns.raw.areamaps = {\n")
local areas = {}
for area, map in pairs(areaToMap) do
	if type(area) == "number" and type(map) == "number" and map ~= 0 then areas[#areas + 1] = area end
end
table.sort(areas)
for _, area in ipairs(areas) do f:write("[", area, "]=", areaToMap[area], ",") end
f:write("\n}\n")
f:close()

print(string.format("quests %d (hidden %d), npcs %d, objects %d, items %d", #questIds, hidden, npcCount, objCount, #itemIds))
