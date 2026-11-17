local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

local log = {
	{ questID = 62, title = "The Fargodeep Mine", level = 7 },
	{ isHeader = true, title = "Elwynn Forest" },
	{ questID = 176, title = "WANTED: \"Hogger\"", level = 11 },
	{ questID = 7, title = "Kobold Camp Cleanup", level = 2 },
}
local objectives = {
	[62] = { { text = "Scout through the Fargodeep Mine", type = "event", finished = false } },
	[176] = { { text = "Huge Gnoll Claw: 0/1", type = "item", finished = false, numFulfilled = 0, numRequired = 1 } },
	[7] = { { text = "Kobold Vermin slain: 10/10", type = "monster", finished = true, numFulfilled = 10, numRequired = 10 } },
}
local done = { [783] = true }
C_QuestLog = {
	GetNumQuestLogEntries = function() return #log end,
	GetInfo = function(i) return log[i] end,
	GetQuestObjectives = function(id) return objectives[id] end,
	IsQuestFlaggedCompleted = function(id) return done[id] or false end,
	IsComplete = function(id) return id == 7 end,
}
C_Map.GetBestMapForUnit = function() return 1429 end
C_Map.GetMapInfo = function(id) return { name = "Map " .. id } end
local opened
C_Map.OpenWorldMap = function(id) opened = id end
C_Map.GetWorldPosFromMapPos = function(_, v) return 0, { x = 1000 - v.y * 1000, y = 1000 - v.x * 1000 } end
function CreateVector2D(x, y) return { x = x, y = y } end
function UnitPosition() return 800, 700, 0, 0 end
function UnitLevel() return 8 end
function UnitRace() return "Human", "Human", 1 end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function GetQuestGreenRange() return 5 end
function GetCVar() return "1" end
function GetPlayerFacing() return 1 end
function strsplit(sep, s)
	local out = {}
	for part in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
	return unpack(out)
end
Enum.TooltipDataType.Unit = 2
WorldMapFrame = M.obj("Frame")
local canvas = M.obj("Frame")
canvas.__w, canvas.__h = 1000, 660
function WorldMapFrame:GetCanvas() return canvas end
function WorldMapFrame:GetMapID() return 1429 end

M.load("ACore", "ACore")
local ns = M.load("AQuest", "AQuest")
event("PLAYER_LOGIN")
flush()

local q = ns.Quest(176)
ok(q and q.n == 'WANTED: "Hogger"' and q.oi[1] == 1931, "quest parse")
ok(ns.Npc(197).name == "Marshal McBride" and ns.Npc(197).spawns[1429], "npc parse")
ok(ns.Item(1931).name == "Huge Gnoll Claw" and #ns.Item(1931).npcs > 0, "item parse")
local bad = 0
local count = 0
for id in pairs(ns.raw.quests) do
	count = count + 1
	if not ns.Quest(id) then bad = bad + 1 end
end
ok(bad == 0 and count > 5000, "all quests parse " .. count)
for id in pairs(ns.raw.npcs) do ok(ns.Npc(id).name, "npc " .. id) end
for id in pairs(ns.raw.objects) do ok(ns.Object(id).name, "object " .. id) end
for id in pairs(ns.raw.items) do ok(ns.Item(id).name, "item " .. id) end

ok(ns.Log.count == 3 and ns.Log.quests[7].complete and not ns.Log.quests[176].complete, "log scan")
ok(ns.Unavailable(ns.Quest(176)) == "In your quest log", "in log")
ok(ns.Unavailable(ns.Quest(783)) == "Completed", "completed")
ok(ns.Unavailable(ns.Quest(2)) ~= nil, "horde quest hidden from human")
ok(ns.Unavailable(ns.Quest(15)) == "Requires: Kobold Camp Cleanup", "prerequisite")
local open = 0
for _, id in ipairs(ns.Index("starts", 1429)) do
	if ns.Shown(ns.Quest(id)) then open = open + 1 end
end
ok(open > 3, "available quests " .. open)

local pins = ns.Pins.Build(1429)
local kinds = {}
for _, p in ipairs(pins) do
	kinds[p.kind] = (kinds[p.kind] or 0) + 1
	ok(p.x >= 0 and p.x <= 1 and p.y >= 0 and p.y <= 1 and #p.lines > 0, "pin in range")
end
ok(kinds.available and kinds.turnin and kinds.turnin_wait and kinds.loot, "pin kinds")
ok(#pins > 10 and #pins < 400, "pin count " .. #pins)

local maps, total = 0, 0
for map in pairs(ns.raw.starts) do
	maps = maps + 1
	total = total + #ns.Pins.Build(map)
end
ok(maps > 40, "maps with quests " .. maps)

WorldMapFrame.__scripts = WorldMapFrame.__scripts or {}
ns.Pins.RefreshWorld(true)
local shown = 0
for _, f in ipairs(M.frames) do
	if f.pin and f.__shown and f.__scripts.OnEnter then
		shown = shown + 1
		f.__scripts.OnEnter(f)
		f.__scripts.OnLeave(f)
		if shown == 1 then f.__scripts.OnClick(f) end
	end
end
ok(shown > 10, "world pins shown " .. shown)
for _, f in ipairs(M.frames) do
	local fn = f.__scripts.OnUpdate
	if fn then fn(f, 1) end
end
ns.Pins.RefreshMini()

local mob
for npc in pairs(ns.Log.npcs) do mob = npc break end
ok(AQuest.IsQuestMob(mob) and #AQuest.QuestsFor(mob) > 0 and not AQuest.IsQuestMob(1), "api quest mob")
ok(AQuest.InLog(176), "api in log")
function UnitGUID() return "Creature-0-1-2-3-" .. mob .. "-0000" end
ok(AQuest.IsQuestUnit("target"), "api quest unit")
ok(AQuestTracker and AQuestTracker:IsShown(), "tracker shown")
ok(not ns.Tracker.Tracked(176) and not ns.Tracker.Tracked(7), "nothing tracked by default")
local watch = {}
C_QuestLog.GetQuestWatchType = function(id) return watch[id] end
C_QuestLog.AddQuestWatch = function(id) watch[id] = 0 end
C_QuestLog.RemoveQuestWatch = function(id) watch[id] = nil end
watch[62] = 0
ok(ns.Tracker.Tracked(62), "follows the game's watch list")
ns.Tracker.SetTracked(176, true)
ok(ns.Tracker.Tracked(176) and watch[176], "track")
ns.Tracker.SetTracked(176, false)
ok(not ns.Tracker.Tracked(176) and not watch[176], "untrack")
ns.Tracker.SetTracked(176, true)
event("QUEST_WATCH_LIST_CHANGED")
ns.Tracker.ShowOnMap(176)
ok(opened == 1429, "show on map " .. tostring(opened))
for _, f in ipairs(M.frames) do
	if f.quest and f.__scripts.OnClick then
		f.__scripts.OnClick(f, "RightButton")
		f.__scripts.OnClick(f, "LeftButton")
		break
	end
end

ok(#M.tooltipCalls >= 1, "tooltip hook")
local lines = 0
local tip = GameTooltip
local oldAdd = M.methods.AddLine
M.methods.AddLine = function() lines = lines + 1 end
for npc in pairs(ns.Log.npcs) do
	M.tooltipCalls[#M.tooltipCalls](tip, { guid = "Creature-0-1-2-3-" .. npc .. "-0000" })
	break
end
M.methods.AddLine = oldAdd
ok(lines >= 1, "tooltip lines " .. lines)

SlashCmdList["AQUEST"]("")
SlashCmdList["AQUEST"]("")
ns.Journal.Show()
local frame = AQuestJournal
ok(frame and frame:IsShown(), "journal shown")
while frame.back:IsShown() do frame.back.__scripts.OnClick(frame.back) end
ok(#frame.questList.data == 3, "journal log rows " .. #frame.questList.data)
local zonesSeen = 0
for _, z in ipairs(frame.zoneList.data) do
	local row = frame.zoneList.rows[1]
	row.data = z
	row.__scripts.OnClick(row)
	zonesSeen = zonesSeen + 1
	for _, r in ipairs(frame.questList.rows) do
		if r:IsShown() and r.data then r.__scripts.OnClick(r, "LeftButton") break end
	end
	for _, r in ipairs(frame.questList.rows) do
		if r:IsShown() and r.data then r.__scripts.OnClick(r, "LeftButton") end
	end
	frame.back.__scripts.OnClick(frame.back)
end
ok(zonesSeen > 60, "zones " .. zonesSeen)
for id in pairs(ns.raw.quests) do
	if id % 7 == 0 then ns.Journal.ShowQuest(id) end
end
SlashCmdList["AQUEST"]("hogger")
flush()
local eb = frame.search.box
eb:SetText("hogger")
eb.__scripts.OnTextChanged(eb)
flush()
ok(#frame.questList.data >= 1 and frame.questList.data[1].kind == "quest", "search")
ok(#ns.SearchQuests("176") >= 1, "search by id")
eb:SetText("")
eb.__scripts.OnTextChanged(eb)
flush()

objectives[176][1].finished = true
objectives[176][1].text = "Huge Gnoll Claw: 1/1"
event("QUEST_LOG_UPDATE")
flush()
ok(ns.Log.quests[176].objectives[1].done, "objective progress")
table.remove(log, 3)
event("QUEST_TURNED_IN", 176)
flush()
ok(not ns.Log.quests[176] and ns.Done(176), "turned in")
event("PLAYER_LEVEL_UP", 9)
event("ZONE_CHANGED_NEW_AREA")
flush()
for _, key in ipairs({ "available", "trivial", "repeatable", "objectives", "turnins", "minimap", "tracker" }) do
	ns.db[key] = not ns.db[key]
	ns:Fire("OPTIONS")
	ns.Pins.Build(1429)
end
for _, e in ipairs(ns.Options()) do
	if e.func then e.func() end
end
SlashCmdList["AQUEST"]("tracker")
SlashCmdList["AQUEST"]("reset")
AQuest_ToggleBinding()
ACoreMinimapButton.__scripts.OnClick(ACoreMinimapButton, "LeftButton")

for _, key in ipairs({ "available", "objectives", "turnins", "minimap", "tracker" }) do ns.db[key] = true end
ns.db.trivial = true
ns:Fire("OPTIONS")

local fired = 0
ns:Listen("LOG_CHANGED", function() fired = fired + 1 end)
event("PLAYER_LEVEL_UP", 9)
event("QUEST_LOG_UPDATE")
flush()
ok(fired == 1, "level up scan survives a later plain rescan " .. fired)

C_Item.GetItemCount = function() return 0 end
ns:Fire("OPTIONS")
local collector
for _, p in ipairs(ns.Pins.Build(1429)) do
	for _, l in ipairs(p.lines) do
		if l.quest == 123 and l.kind == "available" then collector = l.text end
	end
end
ok(collector and collector:find("Drops: "), "item started quest pin")
ok(ns.StarterPlace(ns.Quest(123)):find("item from"), "item starter place")

local kc
for id in pairs(ns.raw.quests) do
	local q = ns.Quest(id)
	if q.ok then kc = q break end
end
ok(kc and type(kc.ok[1]) == "table" and type(kc.ok[1][1]) == "number", "kill credit groups")

local entry = { objectives = {
	{ text = "Kobolde get\195\182tet: 3/10", type = "monster", done = false },
	{ text = "Zweiter: 1/1", type = "monster", done = true },
	{ text = "Kiste: 0/1", type = "item", done = false },
} }
ok(ns.ObjectiveFor(entry, "Kobold Vermin", "monster", 2) == entry.objectives[2], "objective by type and order")
ok(ns.ObjectiveFor(entry, "Kiste", "monster", 1) == entry.objectives[3], "objective by name")
ok(ns.ObjectiveFor(entry, "Nothing", "object", 1) == nil, "objective missing")

ns.playerLevel = 30
C_SkillInfo = {
	GetNumSkillLines = function() return 2 end,
	GetSkillLineInfo = function(i) return i == 1 and { isHeader = true, name = "Professions" } or { skillID = 185, rank = 20, name = "Cooking" } end,
}
event("SKILL_LINES_CHANGED")
ok(ns.Unavailable(ns.Quest(90)) == "Needs skill 50", "skill rank requirement")
ok(ns.Unavailable(ns.Quest(769)) ~= nil, "profession requirement")
C_SkillInfo = nil
event("SKILL_LINES_CHANGED")
flush()
ns.playerLevel = 9

ns.Tracker.SetTracked(62, true)
ok(ns.Tracker.Tracked(62), "tracked before the game drops it")
watch[62] = nil
event("QUEST_WATCH_LIST_CHANGED", 62, false)
flush()
ok(not ns.Tracker.Tracked(62), "follows removal from the watch list")
watch[62] = 0
event("QUEST_WATCH_LIST_CHANGED", 62, true)
flush()
ok(ns.Tracker.Tracked(62), "follows additions to the watch list")

local n, w, cont = ns.Pins.World(1429, 0.25, 0.75)
ok(math.abs(n - 250) < 0.001 and math.abs(w - 750) < 0.001, "world position from map rect")

local ways = {}
AWay = {
	Add = function(map, x, y, title) ways[#ways + 1] = { map = map, x = x, y = y, title = title } return #ways end,
	List = function() return ways end,
	Remove = function(i) table.remove(ways, i) return true end,
}
C_Map.GetPlayerMapPosition = function() return { x = 0.4, y = 0.6 } end
local map, x, y = ns.Pins.Nearest(62)
ok(map == 1429 and x and y, "nearest objective")
local best
for _, p in ipairs(ns.Pins.QuestPoints(62, 1429)) do
	local d = (p.x - 0.4) ^ 2 + (p.y - 0.6) ^ 2
	if not best or d < best then best = d end
end
ok(math.abs(((x - 0.4) ^ 2 + (y - 0.6) ^ 2) - best) < 1e-9, "nearest is the closest point")
ok(ns.NearestWaypoint(62) and #ways == 1 and ways[1].title:find("Fargodeep"), "waypoint to nearest")
C_Map.GetPlayerMapPosition = function() return { x = 0.9, y = 0.1 } end
ns.NearestWaypoint(62)
ns.NearestWaypoint(7)
ok(#ways == 1, "waypoints do not pile up " .. #ways)
ok(ns.Pins.Nearest(2) ~= nil, "nearest for a quest outside the log")

local passed, combat = 0, true
function InCombatLockdown() return combat end
M.methods.SetPassThroughButtons = function() passed = passed + 1 end
ns.db.pinSize = 1
ns.Pins.RefreshWorld(true)
local worldPins = 0
for _, f in ipairs(M.frames) do
	if f.pin and f.__shown and f.map then worldPins = worldPins + 1 end
end
M.mods.shift = true
for _, f in ipairs(M.frames) do
	if f.pin and f.__shown and f.map then f.__scripts.OnClick(f) break end
end
M.mods.shift = false
ok(#ways == 1 and ways[1].map == 1429, "shift-click pin sets a waypoint")
local before = passed
local poolBefore = #M.frames
function UnitPosition() return 500, 500, 0, 0 end
ns.db.minimap = true
ns:Fire("OPTIONS")
ns.Pins.RefreshMini()
ok(#M.frames > poolBefore, "minimap pins created in combat " .. (#M.frames - poolBefore))
ok(passed == before, "no pass through call in combat")
combat = false
event("PLAYER_REGEN_ENABLED")
ok(passed >= before + (#M.frames - poolBefore), "pass through after combat")
M.tooltipCalls[#M.tooltipCalls - 1](GameTooltip, { id = 1931 })
AWay = nil

print_real(string.format("ok: %d checks, %d quests, %d pins over %d maps", M.checks(), count, total, maps))
