local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

local items = {
	[100] = { name = "Old Helm", loc = "INVTYPE_HEAD", class = 4, sub = 4, ilvl = 40, stats = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 8, RESISTANCE0_NAME = 300 } },
	[101] = { name = "Lionheart Helm", loc = "INVTYPE_HEAD", class = 4, sub = 4, ilvl = 66, stats = { ITEM_MOD_STRENGTH_SHORT = 18, RESISTANCE0_NAME = 565 }, lines = { "Equip: Improves your chance to get a critical strike by 2%.", "Equip: Improves your chance to hit by 2%." } },
	[102] = { name = "Cloth Hat", loc = "INVTYPE_HEAD", class = 4, sub = 1, ilvl = 60, stats = { ITEM_MOD_INTELLECT_SHORT = 20 }, lines = { "Equip: Increases damage and healing done by magical spells and effects by up to 30." } },
	[110] = { name = "Ring A", loc = "INVTYPE_FINGER", class = 4, sub = 0, ilvl = 50, stats = { ITEM_MOD_STRENGTH_SHORT = 5 } },
	[111] = { name = "Ring B", loc = "INVTYPE_FINGER", class = 4, sub = 0, ilvl = 55, stats = { ITEM_MOD_STRENGTH_SHORT = 12 } },
	[112] = { name = "Ring C", loc = "INVTYPE_FINGER", class = 4, sub = 0, ilvl = 60, stats = { ITEM_MOD_STRENGTH_SHORT = 9 }, lines = { "Equip: +20 Attack Power." } },
	[120] = { name = "Big Axe", loc = "INVTYPE_2HWEAPON", class = 2, sub = 1, ilvl = 60, stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 60, ITEM_MOD_STRENGTH_SHORT = 20 }, lines = { "Two-Hand", "Speed 3,60" } },
	[121] = { name = "Sword", loc = "INVTYPE_WEAPON", class = 2, sub = 7, ilvl = 55, stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 40 }, lines = { "Speed 2.40", "(40.0 damage per second)" } },
	[122] = { name = "Dagger", loc = "INVTYPE_WEAPON", class = 2, sub = 15, ilvl = 50, stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 30 } },
	[123] = { name = "Shield", loc = "INVTYPE_SHIELD", class = 4, sub = 6, ilvl = 58, stats = { RESISTANCE0_NAME = 2000 }, lines = { "Equip: Increases the block value of your shield by 20.", "Equip: Increased Defense +7." } },
	[124] = { name = "Wand", loc = "INVTYPE_RANGEDRIGHT", class = 2, sub = 19, ilvl = 58, stats = {} },
	[130] = { name = "Shadow Robe", loc = "INVTYPE_ROBE", class = 4, sub = 1, ilvl = 60, stats = {}, lines = { "Equip: Increases damage done by Shadow spells and effects by up to 40.", "Equip: Restores 6 mana per 5 sec.", "Equip: Increases healing done by spells and effects by up to 33.", "Equip: Improves your chance to hit with spells by 1%.", "Equip: Improves your chance to get a critical strike with spells by 1%.", "Equip: +30 Attack Power in Cat, Bear, and Dire Bear forms only.", "Equip: +14 ranged Attack Power." } },
	[140] = { name = "Potion", loc = "", class = 0, sub = 1, ilvl = 1, stats = {} },
	[150] = { name = "Late Helm", loc = "INVTYPE_HEAD", class = 4, sub = 4, ilvl = 70, stats = { ITEM_MOD_STRENGTH_SHORT = 40 }, late = true },
}
local equipped = { [1] = 100, [11] = 110, [12] = 111, [16] = 121 }
local requests = 0

local function idOf(v)
	if type(v) == "number" then return v end
	return tonumber(tostring(v):match("item:(%d+)"))
end
C_Item.GetItemInfo = function(v)
	local id = idOf(v)
	local it = items[id]
	if not it or it.late then return nil end
	return it.name, "|cffffffff|Hitem:" .. id .. "::::::::60:::::|h[" .. it.name .. "]|h|r", 3, it.ilvl, 55, "Armor", "x", 1, it.loc, 134400, 1, it.class, it.sub
end
C_Item.GetItemInfoInstant = function(v)
	local id = idOf(v)
	local it = items[id]
	if not it then return nil end
	return id, "Armor", "x", it.loc, 134400, it.class, it.sub
end
C_Item.GetItemStats = function(v)
	local it = items[idOf(v)]
	return it and it.stats
end
C_Item.RequestLoadItemDataByID = function() requests = requests + 1 end
C_TooltipInfo = {
	GetHyperlink = function(link)
		local it = items[idOf(link)]
		local lines = {}
		for _, l in ipairs(it and it.lines or {}) do lines[#lines + 1] = { leftText = l } end
		return { lines = lines }
	end,
}
function GetInventoryItemLink(_, slot)
	local id = equipped[slot]
	if not id then return nil end
	return "|cffffffff|Hitem:" .. id .. "::::::::60:::::|h[" .. items[id].name .. "]|h|r"
end

local opened, wished
ALoot = {
	AllItems = function()
		local out = {}
		for id in pairs(items) do out[#out + 1] = id end
		for i = 1000, 1200 do out[#out + 1] = i end
		table.sort(out)
		return out
	end,
	SourceText = function(id)
		if id == 112 then return "Crafted: Blacksmithing" end
		if id == 120 then return "Ragnaros - Molten Core", "raid" end
		return "Boss - Deadmines"
	end,
	Open = function(id) opened = id end,
	WishToggle = function(id) wished = id end,
}

M.load("ACore", "ACore")
local ns = M.load("AGear", "AGear")
event("PLAYER_LOGIN")
flush()

ok(ns.ActiveSet().key == "WARRIOR_FURY", "default set for class")
local s = ns.Stats(101)
ok(s.str == 18 and s.crit == 2 and s.hit == 2 and s.armor == 565, "api stats and equip lines")
local r = ns.Stats(130)
ok(r.shadow == 40 and r.mp5 == 6 and r.heal == 33 and r.spellhit == 1 and r.spellcrit == 1 and r.feralap == 30 and r.rap == 14 and not r.ap and not r.hit, "tooltip patterns")
ok(ns.Stats(120).speed == 3.6 and ns.Stats(121).speed == 2.4 and ns.Stats(121).dps == 40, "speed and dps")
ok(ns.Stats(123).blockvalue == 20 and ns.Stats(123).def == 7, "shield stats")
ok(ns.Stats(112).ap == 20, "attack power line")
ok(math.abs(ns.Score(101) - (18 + 20 + 28 + 565 * 0.005)) < 0.001, "score " .. ns.Score(101))
ok(AGear.Score(140) == nil and AGear.Score(99999) == nil, "no score for non gear")
ok(AGear.Score("|Hitem:101::::|h[x]|h") == ns.Score(101), "score by link")

local score, delta, slot, _, usable = ns.Compare(101)
ok(delta > 0 and slot == 1 and usable, "helm upgrade")
ok(AGear.IsUpgrade(101) == true and AGear.IsUpgrade(100) == false, "is upgrade")
local _, d2, _, _, u2 = ns.Compare(102)
ok(u2 == true and d2 < 0, "cloth usable by warrior but worse")
ns.playerClass = "MAGE"
local _, d3, _, _, u3 = ns.Compare(101)
ok(u3 == false and d3 == nil, "plate unusable by mage")
ok(ns.Usable(ns.ItemInfo(124)) and not ns.Usable(ns.ItemInfo(123)) and not ns.Usable(ns.ItemInfo(120)), "mage weapon rules")
ns.playerClass = "WARRIOR"
local _, dr, sr = ns.Compare(112)
ok(sr == 11 and math.abs(dr - (ns.Score(112) - ns.Score(110))) < 0.001, "ring replaces the weaker ring")
local _, same = ns.Compare(111)
ok(same == 0, "ring already worn is not an upgrade " .. tostring(same))
local _, d2h = ns.Compare(120)
ok(math.abs(d2h - (ns.Score(120) - ns.Score(121))) < 0.001, "two hand vs main plus off")
local _, dd, sd = ns.Compare(122)
ok(sd == 17 and dd == ns.Score(122), "dual wield fills empty off hand")
equipped[16] = 120
local _, doff, soff = ns.Compare(123)
ok(doff == nil and soff == 17, "off hand not comparable with two hander")
local _, d1h, s1h = ns.Compare(121)
ok(s1h == 16 and d1h < 0, "one hand vs two hander")
equipped[16] = 121
event("PLAYER_EQUIPMENT_CHANGED", 16)
flush()
ns.playerClass = "PALADIN"
local _, _, sp = ns.Compare(122)
ok(not ns.Usable(ns.ItemInfo(122)), "paladin cannot use daggers")
ns.playerClass = "WARRIOR"

ok(ns.Score(150) == nil and requests == 1 and ns.pending == 1, "uncached item requested")
ns.Score(150)
ok(requests == 1, "requested once")

local lines = {}
local old = M.methods.AddDoubleLine
M.methods.AddDoubleLine = function(_, l, rr) lines[#lines + 1] = l .. " | " .. rr end
ok(#M.tooltipCalls >= 1, "tooltip hook")
local call = M.tooltipCalls[#M.tooltipCalls]
call(GameTooltip, { id = 101 })
call(GameTooltip, { id = 100 })
call(GameTooltip, { id = 140 })
call(GameTooltip, { id = 123 })
ns.playerClass = "MAGE"
call(GameTooltip, { id = 101 })
ns.playerClass = "WARRIOR"
ok(#lines == 4 and lines[1]:find("+", 1, true) and lines[1]:find("vs Head") and lines[2]:find("same") and lines[4]:find("not usable"), "tooltip lines " .. table.concat(lines, " / "))
ns.db.tooltip = false
call(GameTooltip, { id = 101 })
ok(#lines == 4, "tooltip off")
ns.db.tooltip = true
M.methods.AddDoubleLine = old

SlashCmdList["AGEAR"]("")
local frame = AGearFrame
ok(frame and frame:IsShown(), "window shown")
ok(#frame.list.data == 18 and frame.list.data[2].kind == "slot", "character rows")
local weak = 0
for _, row in ipairs(frame.list.data) do
	if row.weak then weak = weak + 1 end
end
ok(weak >= 1, "weak slots flagged " .. weak)
for _, row in ipairs(frame.list.rows) do
	if row:IsShown() and row.data then
		row.__scripts.OnEnter(row)
		row.__scripts.OnLeave(row)
		row.__scripts.OnClick(row, "LeftButton")
	end
end

frame.tabs[2].__scripts.OnClick(frame.tabs[2], "LeftButton")
ok(ns.Upgrades.running and frame.list.data[1].text:find("Scoring"), "batching in progress")
ok(ns.Upgrades.progress == 40, "one batch per tick " .. ns.Upgrades.progress)
flush()
ok(not ns.Upgrades.running and ns.Upgrades.missing == 1, "scan finished, missing " .. ns.Upgrades.missing)
local ups = ns.Upgrades.Rows()
ok(#ups >= 4 and ups[1].delta >= ups[2].delta, "upgrades ranked " .. #ups)
local kinds = {}
for _, u in ipairs(ups) do
	kinds[u.id] = u.type
	ok(u.id ~= 100 and u.id ~= 102 and u.id ~= 140, "only real upgrades")
end
ok(kinds[112] == "craft" and kinds[120] == "raid" and kinds[101] == "dungeon", "source kinds")
ok(#ns.Upgrades.Rows({ group = "Ring" }) == 1 and #ns.Upgrades.Rows({ type = "raid" }) == 1 and #ns.Upgrades.Rows({ level = 50 }) == 0, "filters")
for _, row in ipairs(frame.list.rows) do
	if row:IsShown() and row.data and row.data.kind == "upgrade" then
		row.__scripts.OnEnter(row)
		row.__scripts.OnClick(row, "LeftButton")
		M.mods.shift = true
		row.__scripts.OnClick(row, "LeftButton")
		M.mods.shift = false
		break
	end
end
ok(opened and wished == opened, "open and wishlist through ALoot")
for _, name in ipairs({ "slotButton", "typeButton", "levelButton", "setButton" }) do
	frame[name].__scripts.OnClick(frame[name], "LeftButton")
end

items[150].late = nil
event("GET_ITEM_INFO_RECEIVED", 150, true)
flush()
local late
for _, u in ipairs(ns.Upgrades.Rows()) do
	if u.id == 150 then late = true end
end
ok(ns.pending == 0 and ns.Upgrades.missing == 0 and late, "late item filled in")

frame.tabs[3].__scripts.OnClick(frame.tabs[3], "LeftButton")
ok(#frame.list.data == #ns.STATS + 1, "weight rows")
local before = ns.Score(101)
local strRow
for _, row in ipairs(frame.list.rows) do
	if row.data and row.data.stat == "str" then strRow = row end
end
strRow.plus.__scripts.OnClick(strRow.plus, "LeftButton")
ok(ns.Edited() and math.abs(ns.Weights().str - 1.1) < 0.001, "plus button " .. ns.Weights().str)
ok(ns.Score(101) > before, "score follows weights")
strRow.minus.__scripts.OnClick(strRow.minus, "LeftButton")
strRow.value.__scripts.OnClick(strRow.value, "LeftButton")
ns.SetWeight("crit", 20)
ns.SetWeight("armor", 0)
ok(ns.Weights().crit == 20 and ns.Weights().armor == nil, "typed weights")
frame.resetButton.__scripts.OnClick(frame.resetButton, "LeftButton")
ok(not ns.Edited() and math.abs(ns.Score(101) - before) < 0.001, "reset")
ns.SetActive("CUSTOM")
ok(ns.Score(101) == 0, "custom set starts empty")
ns.SetWeight("str", 2)
ok(ns.Score(101) == 36, "custom weights")
ns.SetActive("WARRIOR_PROT")
ok(ns.chardb.set == "WARRIOR_PROT" and ns.Score(123) > ns.Score(121), "prot values the shield")
ns.SetActive("nope")
ok(ns.chardb.set == "WARRIOR_PROT", "unknown set ignored")
flush()
for _, set in ipairs(ns.SETS) do
	for stat in pairs(set.w) do ok(ns.STATNAME[stat], set.key .. " " .. stat) end
end

ALoot = nil
ns.Upgrades.rows = {}
frame.tabs[2].__scripts.OnClick(frame.tabs[2], "LeftButton")
ok(frame.list.data[1].text:find("needs ALoot"), "works without ALoot")
SlashCmdList["AGEAR"]("tooltip")
SlashCmdList["AGEAR"]("tooltip")
SlashCmdList["AGEAR"]("reset")
SlashCmdList["AGEAR"]("weights")
SlashCmdList["AGEAR"]("character")
event("UNIT_INVENTORY_CHANGED", "player")
flush()
AGear_ToggleBinding()
AGear_ToggleBinding()
SlashCmdList["ACORE"]("gear")

local function link(id) return "|cffffffff|Hitem:" .. id .. "::::::::60:::::|h[" .. items[id].name .. "]|h|r" end
local R = ns.Rewards
local v = R.Verdict(link(101))
ok(v and v.kind == "up" and v.delta > 0 and v.slot, "verdict upgrade " .. tostring(v and v.text))
ok(R.Verdict(link(100)).kind == "same", "verdict same")
ok(R.Verdict(link(140)) == nil and R.Verdict(nil) == nil, "verdict ignores non-gear")
local worse = R.Verdict(link(110))
ok(worse and (worse.kind == "down" or worse.kind == "same"), "verdict ring " .. worse.kind)

local choices = { 101, 102, 140 }
function GetNumQuestChoices() return #choices end
function GetNumQuestRewards() return 1 end
function GetQuestItemLink(kind, i)
	if kind == "choice" then return link(choices[i]) end
	return link(111)
end
QuestInfoRewardsFrame = { RewardButtons = {} }
for i = 1, 4 do
	local b = CreateFrame("Button")
	b.type = i <= 3 and "choice" or "reward"
	b.id = i <= 3 and i or 1
	QuestInfoRewardsFrame.RewardButtons[i] = b
end
M.methods.GetID = function(self) return self.id end
local before = #M.printed
event("QUEST_COMPLETE")
flush()
local list, best = R.Quest()
ok(best == 1 and list[1].verdict.kind == "up" and list[3].verdict == nil, "best quest reward")
local b1, b3 = R.badges[QuestInfoRewardsFrame.RewardButtons[1]], R.badges[QuestInfoRewardsFrame.RewardButtons[3]]
ok(b1 and b1:IsShown() and b1.best:IsShown() and b1.text.__text:sub(1, 1) == "+", "badge on the best choice")
ok(R.badges[QuestInfoRewardsFrame.RewardButtons[2]].text.__text ~= nil and b3 and R.badges[QuestInfoRewardsFrame.RewardButtons[4]], "badges on other buttons")
local said
for i = before + 1, #M.printed do
	if M.printed[i]:find("best reward") then said = true end
end
ok(said, "best reward announced")
event("QUEST_DETAIL")
event("QUEST_ITEM_UPDATE")
flush()

function GetLootRollItemLink(id) return id == 7 and link(101) or (id == 8 and link(110)) or nil end
GroupLootFrame1 = CreateFrame("Frame")
GroupLootFrame1.rollID = 7
before = #M.printed
event("START_LOOT_ROLL", 7)
flush()
ok(R.labels[GroupLootFrame1] and R.labels[GroupLootFrame1].__text:find("upgrade"), "roll frame label")
said = false
for i = before + 1, #M.printed do
	if M.printed[i]:find("upgrade") then said = true end
end
ok(said, "roll upgrade announced once")
ok(R.Roll(99) == nil, "unknown roll ignored")
ns.db.rolls = false
ok(R.Roll(7) == nil, "rolls option off")
ns.db.rewards = false
ok(R.Quest() == nil, "rewards option off")
for _, e in ipairs(R.Options()) do
	if e.func then e.func() e.func() end
end
ok(ns.db.rolls == false and ns.db.rewards == false, "options toggle back")
ns.db.rolls, ns.db.rewards = nil, nil

print_real(string.format("ok: %d checks, %d sets", M.checks(), #ns.SETS))
