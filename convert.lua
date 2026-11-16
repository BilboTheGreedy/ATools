local SRC = arg[1]
local OUT = arg[2]
assert(SRC and OUT, "usage: lua5.1 convert.lua <source addon dir> <output data dir>")

local real = {}
for k, v in pairs(_G) do real[k] = v end

local mockmt = {}
local function mock(name)
	return setmetatable({ __mock = name or "?" }, mockmt)
end
local function ismock(v)
	return type(v) == "table" and getmetatable(v) == mockmt
end
mockmt.__index = function(t, k) return mock(rawget(t, "__mock") .. "." .. tostring(k)) end
mockmt.__call = function(t) return mock(rawget(t, "__mock") .. "()") end
mockmt.__concat = function(a, b)
	if ismock(a) then a = "" end
	if ismock(b) then b = "" end
	return a .. b
end
mockmt.__len = function() return 0 end
mockmt.__add = function() return 0 end
mockmt.__sub = function() return 0 end
mockmt.__mul = function() return 0 end
mockmt.__div = function() return 0 end
mockmt.__lt = function() return false end
mockmt.__le = function() return false end
mockmt.__tostring = function() return "" end

local function fallback(tbl, name)
	return setmetatable(tbl, {
		__index = function(_, k) return mock(name .. "." .. tostring(k)) end,
	})
end

local function locale()
	return setmetatable({}, { __index = function(_, k) return k end })
end

local captured = {}
local currentFile
local reg = { diffs = {}, contents = {}, ttypes = {} }
local modules = {}
local moduleOrder = {}

local AtlasLoot = {
	RETAIL_VERSION_NUM = 99,
	CLASSIC_VERSION_NUM = 1,
	BC_VERSION_NUM = 2,
	WRATH_VERSION_NUM = 3,
	CURRENT_VERSION_NUM = 1,
	IS_CLASSIC = true,
	Locales = locale(),
	IngameLocales = locale(),
	Data = {},
	DIFFICULTY = {},
}
fallback(AtlasLoot.Data, "AtlasLoot.Data")

function AtlasLoot:GetGameVersion() return 1 end
function AtlasLoot:GameVersion_EQ(v, a, b) if 1 == v then return a or true end return b end
function AtlasLoot:GameVersion_NE(v, a, b) if 1 ~= v then return a or true end return b end
function AtlasLoot:GameVersion_GT(v, a, b) if 1 > v then return a or true end return b end
function AtlasLoot:GameVersion_LT(v, a, b) if 1 < v then return a or true end return b end
function AtlasLoot:GameVersion_GE(v, a, b) if 1 >= v then return a or true end return b end
function AtlasLoot:GameVersion_LE(v, a, b) if 1 <= v then return a or true end return b end
function AtlasLoot.ReturnForGameVersion(classic) return classic end
function AtlasLoot:AddInitFunc() end
function AtlasLoot:GetColoredClassNames() return {} end

function AtlasLoot:GetGameVersionDataTable()
	local use = {}
	local list = captured[currentFile] or {}
	captured[currentFile] = list
	list[#list + 1] = use
	local dataTable = setmetatable({}, {
		__newindex = function(_, _, v)
			for k2, v2 in pairs(v) do use[k2] = v2 end
		end,
	})
	return use, dataTable
end

local Proto = {}
function Proto:AddDifficulty(dif, uniqueName)
	local m = self.__name
	reg.diffs[m] = reg.diffs[m] or {}
	local id = "D" .. (#reg.diffs[m] + 1)
	local short = uniqueName
	if dif == "NORMAL" then dif, short = "Normal", "n" end
	if dif == "20RAID" then dif, short = "20 Player", "r20" end
	if dif == "40RAID" then dif, short = "40 Player", "r40" end
	reg.diffs[m][#reg.diffs[m] + 1] = { id = id, name = dif, short = short or id }
	reg.diffs[m][id] = reg.diffs[m][#reg.diffs[m]]
	return id
end
function Proto:AddContentType(typ)
	local m = self.__name
	reg.contents[m] = reg.contents[m] or {}
	local id = "C" .. (#reg.contents[m] + 1)
	reg.contents[m][#reg.contents[m] + 1] = { id = id, name = typ }
	reg.contents[m][id] = reg.contents[m][#reg.contents[m]]
	return id
end
function Proto:AddItemTableType(a, b)
	local m = self.__name
	reg.ttypes[m] = reg.ttypes[m] or {}
	reg.ttypes[m].n = (reg.ttypes[m].n or 0) + 1
	local id = "T" .. reg.ttypes[m].n
	reg.ttypes[m][id] = { a, b }
	return id
end
function Proto:AddExtraItemTableType(typ)
	return "X" .. typ
end

AtlasLoot.ItemDB = {
	Add = function(_, addonName)
		local name = addonName:gsub("^AtlasLootJournal_", "")
		if modules[name] then return modules[name] end
		local store = { __name = name, __order = {}, __items = {} }
		local obj = setmetatable(store, {
			__index = function(_, k)
				if Proto[k] then return Proto[k] end
				return rawget(store, "__items")[k]
			end,
			__newindex = function(_, k, v)
				local items = rawget(store, "__items")
				if items[k] == nil then
					local order = rawget(store, "__order")
					order[#order + 1] = k
				end
				items[k] = v
			end,
		})
		modules[name] = obj
		moduleOrder[#moduleOrder + 1] = name
		return obj
	end,
}

local droprates = {}
AtlasLoot.Data.Droprate = {
	AddData = function(_, d)
		for k, v in pairs(d) do droprates[k] = v end
	end,
}

AtlasLoot.Data.Requirements = fallback({
	GetPvPRankName = function(rank, faction)
		return "$PVP_RANK_" .. (rank + 4) .. "_" .. (faction == "Horde" and 0 or 1)
	end,
	GetPvPRankIcon = function(rank)
		return "rank:" .. rank
	end,
}, "Requirements")

AtlasLoot.Data.ContentPhase = fallback({
	GetActivePhase = function() return 6 end,
}, "ContentPhase")

fallback(AtlasLoot, "AtlasLoot")

local env = {}
for k, v in pairs(real) do env[k] = v end
env._G = env
env.AtlasLootJournal = AtlasLoot
env.format = string.format
env.strsub = string.sub
env.strlower = string.lower
env.tinsert = table.insert
env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
env.getfenv = function() return env end
env.UnitFactionGroup = function() return "Alliance" end
env.FACTION_ALLIANCE = "Alliance"
env.FACTION_HORDE = "Horde"
env.C_Map = fallback({
	GetAreaInfo = function(id) return "@area:" .. id .. "@" end,
}, "C_Map")
env.RAID_CLASS_COLORS = setmetatable({}, {
	__index = function(_, k) return { colorStr = "ffffffff", r = 1, g = 1, b = 1 } end,
})
env.GetFactionInfoByID = function(id) return "@faction:" .. id .. "@" end
env.C_Seasons = { GetActiveSeason = function() return 0 end }
setmetatable(env, {
	__index = function(_, k)
		if type(k) == "string" and k:match("^[A-Z][A-Z0-9_]+$") then
			return "$" .. k
		end
		return mock(tostring(k))
	end,
})

local ALPrivate = fallback({
	CLASS_ICON_PATH_ITEM_DB = setmetatable({}, { __index = function(_, k) return "class:" .. k end }),
}, "ALPrivate")

local function run(rel)
	currentFile = rel
	local f, err = loadfile(SRC .. "/" .. rel)
	if not f then error(err) end
	setfenv(f, env)
	local ok, e = pcall(f, "AtlasLootJournal", ALPrivate)
	if not ok then
		io.stderr:write("warn: " .. rel .. ": " .. tostring(e) .. "\n")
	end
end

local files = {
	"Data/Token.lua",
	"Data/Profession.lua",
	"Data/Recipe.lua",
	"Data/ItemSet.lua",
	"Data/VendorPrice.lua",
	"Modules/DungeonsAndRaids/data.lua",
	"Modules/DungeonsAndRaids/droprate.lua",
	"Modules/Crafting/private.lua",
	"Modules/Crafting/data.lua",
	"Modules/Factions/data.lua",
	"Modules/PvP/private.lua",
	"Modules/PvP/data.lua",
	"Modules/Collections/private.lua",
	"Modules/Collections/data.lua",
}
for _, f in ipairs(files) do run(f) end

local leaks = {}
local function clean(v, path)
	if ismock(v) then
		leaks[#leaks + 1] = path .. " = " .. rawget(v, "__mock")
		return nil
	end
	if type(v) == "function" then return nil end
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do
		if not ismock(k) then
			out[k] = clean(x, path .. "." .. tostring(k))
		end
	end
	return out
end

local function isIdent(s)
	return type(s) == "string" and s:match("^[%a_][%w_]*$") and not ({
		["and"] = 1, ["break"] = 1, ["do"] = 1, ["else"] = 1, ["elseif"] = 1, ["end"] = 1,
		["false"] = 1, ["for"] = 1, ["function"] = 1, ["if"] = 1, ["in"] = 1, ["local"] = 1,
		["nil"] = 1, ["not"] = 1, ["or"] = 1, ["repeat"] = 1, ["return"] = 1, ["then"] = 1,
		["true"] = 1, ["until"] = 1, ["while"] = 1,
	})[s]
end

local function ser(v, buf, depth)
	local t = type(v)
	if t == "number" then
		if v == math.floor(v) then buf[#buf + 1] = string.format("%d", v)
		else buf[#buf + 1] = string.format("%.14g", v) end
	elseif t == "string" then
		buf[#buf + 1] = string.format("%q", v):gsub("\\\n", "\\n")
	elseif t == "boolean" then
		buf[#buf + 1] = tostring(v)
	elseif t == "table" then
		buf[#buf + 1] = "{"
		local n = 0
		while v[n + 1] ~= nil do n = n + 1 end
		local first = true
		for i = 1, n do
			if not first then buf[#buf + 1] = "," end
			first = false
			ser(v[i], buf, depth + 1)
		end
		local keys = {}
		for k in pairs(v) do
			if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
				keys[#keys + 1] = k
			end
		end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		for _, k in ipairs(keys) do
			if not first then buf[#buf + 1] = "," end
			first = false
			if isIdent(k) then
				buf[#buf + 1] = k .. "="
			else
				buf[#buf + 1] = "["
				ser(k, buf, depth + 1)
				buf[#buf + 1] = "]="
			end
			ser(v[k], buf, depth + 1)
		end
		buf[#buf + 1] = "}"
		if depth <= 2 then buf[#buf + 1] = "\n" end
	else
		buf[#buf + 1] = "nil"
	end
end

local function write(name, field, value)
	local buf = { "local _, ns = ...\nns.raw." .. field .. " = " }
	ser(value, buf, 0)
	buf[#buf + 1] = "\n"
	local f = assert(io.open(OUT .. "/" .. name, "w"))
	f:write(table.concat(buf))
	f:close()
end

local EXTRA = { XQuest = "quest", XPrice = "price", XSet = "set" }

local itemIds = {}
local function noteItems(o, ttype)
	if ttype == "Profession" or ttype == "Set" or ttype == "Dummy" then return end
	if type(o[2]) == "number" and type(o[3]) ~= "string" then itemIds[o[2]] = true end
	if type(o[3]) == "number" then itemIds[o[3]] = true end
	if type(o.alliance) == "number" then itemIds[o.alliance] = true end
	if type(o.horde) == "number" then itemIds[o.horde] = true end
end

local function convertEntries(list, path, ttype)
	local out = {}
	for i, e in ipairs(list) do
		local o = {}
		local maxn = 0
		for k, v in pairs(e) do
			if type(k) == "number" then
				if k > maxn then maxn = k end
			end
		end
		for n = 1, maxn do
			local v = e[n]
			if v == nil or ismock(v) then v = false end
			o[n] = v
		end
		while #o > 0 and o[#o] == false do o[#o] = nil end
		for k, v in pairs(e) do
			if type(k) == "string" then
				if EXTRA[k] then
					o[EXTRA[k]] = clean(v, path)
				elseif k == "$ATLASLOOTJOURNAL_IT_AMOUNT1" then
					o.amount = clean(v, path)
				elseif k == "$ATLASLOOTJOURNAL_IT_AMOUNT2" then
					o.amount2 = clean(v, path)
				elseif k == "$ATLASLOOTJOURNAL_IT_ALLIANCE" then
					o.alliance = clean(v, path)
				elseif k == "$ATLASLOOTJOURNAL_IT_HORDE" then
					o.horde = clean(v, path)
				elseif k ~= "GetItemsFromDiff" then
					o[k] = clean(v, path)
				end
			end
		end
		noteItems(o, ttype)
		out[#out + 1] = o
	end
	return out
end

local function resolveDiff(boss, diffId, seen)
	local list = boss[diffId]
	if type(list) ~= "table" then return nil end
	seen = seen or {}
	if seen[diffId] then return list end
	seen[diffId] = true
	local from = list.GetItemsFromDiff
	if not from then return list end
	local base = resolveDiff(boss, from, seen) or {}
	local bypos = {}
	local order = {}
	for _, e in ipairs(base) do
		if type(e) == "table" and e[1] then
			bypos[e[1]] = e
			order[#order + 1] = e[1]
		end
	end
	for _, e in ipairs(list) do
		if type(e) == "table" and e[1] then
			if bypos[e[1]] == nil then order[#order + 1] = e[1] end
			if e[2] == nil then
				bypos[e[1]] = false
			else
				bypos[e[1]] = e
			end
		end
	end
	local merged = {}
	table.sort(order)
	for _, pos in ipairs(order) do
		if bypos[pos] then merged[#merged + 1] = bypos[pos] end
	end
	return merged
end

local BOSS_FIELDS = {
	name = "name", npcID = "npc", Level = "level", ExtraList = "extra", ObjectID = "object",
	ContentPhase = "phase", FactionID = "faction", TableType = "ttype", specialType = "special",
	IgnoreAsSource = "nosource", DisplayIDs = "display", englishName = "ename", CoinTexture = "coin",
	nameFormat = "nameformat", MapID = "map",
}
local INST_FIELDS = {
	name = "name", MapID = "map", InstanceID = "inst", FactionID = "faction", ContentPhase = "phase",
	LevelRange = "level", TableType = "ttype", AtlasMapID = "atlas", SubAreaIDs = "subareas",
}

local out = {}
for _, mname in ipairs(moduleOrder) do
	local m = modules[mname]
	local diffs = reg.diffs[mname] or {}
	local list = {}
	for _, key in ipairs(rawget(m, "__order")) do
		local src = rawget(m, "__items")[key]
		if type(src) == "table" and type(src.items) == "table" then
			local inst = { key = key, bosses = {} }
			for k, v in pairs(INST_FIELDS) do
				if src[k] ~= nil then inst[v] = clean(src[k], mname .. "." .. key .. "." .. k) end
			end
			local ct = reg.contents[mname] and reg.contents[mname][src.ContentType]
			inst.cat = ct and ct.name or "Other"
			if inst.ttype then
				local tt = reg.ttypes[mname][inst.ttype]
				inst.ttype = tt and tt[1] or nil
			end
			local used = {}
			local usedOrder = {}
			for bi, b in ipairs(src.items) do
				local boss = {}
				for k, v in pairs(BOSS_FIELDS) do
					if b[k] ~= nil then boss[v] = clean(b[k], mname .. "." .. key .. "." .. bi .. "." .. k) end
				end
				if boss.ttype then
					local tt = reg.ttypes[mname][boss.ttype]
					boss.ttype = tt and tt[1] or nil
				end
				if boss.display then
					local d = boss.display[1]
					boss.display = type(d) == "table" and d[1] or nil
				end
				boss.loot = {}
				for _, d in ipairs(diffs) do
					local resolved = resolveDiff(b, d.id)
					if resolved then
						boss.loot[d.short] = convertEntries(resolved, mname .. "." .. key .. "." .. bi, boss.ttype or inst.ttype or "Item")
						if not used[d.short] then
							used[d.short] = true
							usedOrder[#usedOrder + 1] = { d.short, d.name }
						end
					end
				end
				inst.bosses[#inst.bosses + 1] = boss
			end
			inst.diffs = usedOrder
			list[#list + 1] = inst
		end
	end
	out[mname] = list
end

for mname, list in pairs(out) do
	write("Loot_" .. mname .. ".lua", "loot." .. mname, list)
end

local function cap(file, n)
	return clean((captured[file] or {})[n] or {}, file)
end

write("Tokens.lua", "tokens", cap("Data/Token.lua", 1))
write("Professions.lua", "professions", cap("Data/Profession.lua", 1))
write("Recipes.lua", "recipes", cap("Data/Recipe.lua", 1))
write("Sets.lua", "sets", cap("Data/ItemSet.lua", 1))
write("Droprates.lua", "droprates", clean(droprates, "droprates"))

local names = {}
local spells = {}
local function scan(rel, target)
	for line in io.lines(SRC .. "/" .. rel) do
		local id, name = line:match("^%s*{%s*%d+,%s*(%d+)[^%-]*}?,?%s*%-%-%s*(.+)$")
		if not id then
			id, name = line:match("^%s*%[(%d+)%]%s*=.-%-%-%s*(.+)$")
		end
		if id and name then
			name = name:gsub("^{FOREVER}%s*", ""):gsub("%s+$", "")
			if #name > 1 and #name < 80 and not name:find("^[%d%s]*$") then
				target[tonumber(id)] = name
			end
		end
	end
end
scan("Modules/DungeonsAndRaids/data.lua", names)
scan("Modules/Factions/data.lua", names)
scan("Modules/PvP/data.lua", names)
scan("Modules/Collections/data.lua", names)
scan("Data/Recipe.lua", names)
scan("Data/Token.lua", names)
scan("Modules/Crafting/data.lua", spells)
local tokens = cap("Data/Token.lua", 1)
for k, v in pairs(tokens) do
	itemIds[k] = true
	if type(v) == "number" then itemIds[v] = true end
	if type(v) == "table" then
		for _, x in ipairs(v) do
			if type(x) == "number" and x > 0 then itemIds[x] = true end
			if type(x) == "table" and type(x[1]) == "number" then itemIds[x[1]] = true end
		end
	end
end
for k in pairs(cap("Data/Recipe.lua", 1)) do itemIds[k] = true end
for k in pairs(names) do
	if not itemIds[k] then names[k] = nil end
end
local setnames = {}
for line in io.lines(SRC .. "/Data/ItemSet.lua") do
	local id, name = line:match("^%s*%[(%d+)%]%s*=%s*{%s*{.-%-%-%s*(.+)$")
	if id then setnames[tonumber(id)] = (name:gsub("%s+$", "")) end
end
write("SetNames.lua", "setnames", setnames)
write("Names.lua", "names", names)
write("SpellNames.lua", "spellnames", spells)

local count = 0
for _ in pairs(names) do count = count + 1 end
io.stderr:write("item names: " .. count .. "\n")
for mname, list in pairs(out) do
	local b, e = 0, 0
	for _, inst in ipairs(list) do
		for _, boss in ipairs(inst.bosses) do
			b = b + 1
			for _, l in pairs(boss.loot) do e = e + #l end
		end
	end
	io.stderr:write(string.format("%s: %d groups, %d sections, %d entries\n", mname, #list, b, e))
end
io.stderr:write("mock leaks: " .. #leaks .. "\n")
for i = 1, #leaks do io.stderr:write("  " .. leaks[i] .. "\n") end
