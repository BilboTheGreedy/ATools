local M = dofile("tools/mock.lua")
local ok, event, flush, printed, mods = M.ok, M.event, M.flush, M.printed, M.mods

function CreateVector2D(x, y)
	return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end
function GetTime() return M.now or 0 end
function GetCVar() return "0" end
function IsIndoors() return false end

local player = { map = 1429, north = 0, west = 0, facing = 0, instance = 0 }
local SIZE = 1000
local names = { [1429] = "Elwynn Forest", [1436] = "Westfall", [1415] = "Eastern Kingdoms", [1411] = "Durotar" }
C_Map.GetMapInfo = function(map) return names[map] and { name = names[map], mapID = map } or nil end
C_Map.GetBestMapForUnit = function() return player.map end
C_Map.GetWorldPosFromMapPos = function(_, v)
	return 0, CreateVector2D((0.5 - v.y) * SIZE, (0.5 - v.x) * SIZE)
end
local opened
C_Map.OpenWorldMap = function(map) opened = map end
function UnitPosition() return player.north, player.west, 0, player.instance end
function GetPlayerFacing() return player.facing end

WorldMapFrame = CreateFrame("Frame", "WorldMapFrame")
WorldMapFrame.__map = 1429
function WorldMapFrame:GetMapID() return self.__map end
local sc = CreateFrame("Frame")
WorldMapFrame.ScrollContainer = sc
sc.Child = CreateFrame("Frame")
sc.Child.__w, sc.Child.__h = 1000, 600
function WorldMapFrame:GetCanvas() return sc.Child end
local cursor = { 0.3, 0.4 }
function sc:GetNormalizedCursorPosition() return cursor[1], cursor[2] end
function sc:HookScript(name, fn) self.__scripts[name] = fn end
Minimap.__w = 140
function Minimap:GetZoom() return 2 end

local function tickAll(dt)
	local list = {}
	for _, f in ipairs(M.frames) do list[#list + 1] = f end
	for _, f in ipairs(list) do
		local fn = f.__scripts.OnUpdate
		if fn then fn(f, dt or 1) end
	end
end
local function pins(parent)
	local n, star = 0, 0
	for _, f in ipairs(M.frames) do
		if f.point and f.__parent == parent and f:IsShown() then n = n + 1 end
	end
	return n
end

AWayCharDB = { list = { { 1436, 0.1, 0.1, "Saved" } }, active = 1 }
M.load("ACore", "ACore")
local ns = M.load("AWay", "AWay")
event("PLAYER_LOGIN")
ok(ns.db and ns.db.arrow and ns.db.arrive, "defaults")
ok(AWay.Count() == 1 and select(4, AWay.Get()) == "Saved", "saved waypoint restored")
AWay.Clear()
ok(AWay.Get() == nil and #ns.chardb.list == 0, "clear empties the saved list")

ok(AWay.Add(1429, 0.5, 0.3, "North") == 1, "add")
local wm, wx, wy, wt = AWay.Get()
ok(wm == 1429 and wx == 0.5 and wy == 0.3 and wt == "North", "get")
local dist, bearing = ns.Way.Vector()
ok(math.abs(dist - 200) < 0.01 and math.abs(bearing) < 0.001, "north distance " .. dist)
ok(math.abs(ns.Way.Angle()) < 0.001, "arrow straight ahead")
player.facing = math.pi / 2
ok(math.abs(ns.Way.Angle() + math.pi / 2) < 0.001, "arrow to the right when facing west")
player.facing = 0
ok(AWay.Add(1429, 30, 50) == 2, "second waypoint, percent input")
dist, bearing = ns.Way.Vector()
ok(math.abs(dist - 200) < 0.01 and math.abs(bearing - math.pi / 2) < 0.001, "newest is active, west bearing")
ok(select(4, AWay.Get()) == "Elwynn Forest 30.0, 50.0", "default title")
ok(AWay.Add(1429, 2000, 5) == false and AWay.Add(nil, 1, 1) == false, "bad waypoint rejected")
ok(AWay.Add(1429, 0.3, 0.5, "Renamed") == 2 and AWay.Count() == 2, "same spot is not duplicated")
ok(#AWay.List() == 2 and AWay.List()[2].active and AWay.List()[2].title == "Renamed" and not AWay.List()[1].active, "list")
ok(#ns.chardb.list == 2 and ns.chardb.active == 2, "saved per character")

M.now = 0
tickAll(1)
ok(AWayArrow and AWayArrow:IsShown(), "arrow shown")
ok(AWayArrow.dist.__text:find("200 yd") and AWayArrow.title.__text:find("2/2"), "arrow text " .. tostring(AWayArrow.dist.__text))
ok(pins(sc.Child) == 2, "world map pins " .. pins(sc.Child))
ok(pins(Minimap) == 1, "minimap shows the clamped active pin only " .. pins(Minimap))
WorldMapFrame.__map = 1436
tickAll(1)
ok(pins(sc.Child) == 0, "no pins on another map")
WorldMapFrame.__map = 1429
M.now = 1
player.west = 10
tickAll(1)
M.now = 2
player.west = 20
tickAll(1)
ok(AWayArrow.dist.__text:find("180 yd") and AWayArrow.dist.__text:find("0:18"), "eta " .. tostring(AWayArrow.dist.__text))
AWayArrow.__scripts.OnClick(AWayArrow, "RightButton")
AWayArrow.__scripts.OnDragStart(AWayArrow)
AWayArrow.__scripts.OnDragStop(AWayArrow)
for _, f in ipairs(M.frames) do
	if f.point and f:IsShown() then
		f.__scripts.OnEnter(f)
		f.__scripts.OnLeave(f)
	end
end

ok(AWay.Next() and select(4, AWay.Get()) == "North", "cycle to next")
mods.shift = true
AWayArrow.__scripts.OnClick(AWayArrow, "LeftButton")
mods.shift = false
ok(select(4, AWay.Get()) == "Renamed", "shift-click arrow cycles")

player.instance = 1
tickAll(1)
ok(not AWayArrow:IsShown(), "arrow hidden on another continent")
player.instance = 0
local realPos = UnitPosition
UnitPosition = function() return nil end
tickAll(1)
ok(not AWayArrow:IsShown(), "arrow hidden without a position")
UnitPosition = realPos

player.west = 196
tickAll(1)
ok(AWay.Count() == 1 and select(4, AWay.Get()) == "North", "arrival removes it and moves to the next")
ok(printed[#printed]:find("arrived"), "arrival message")
tickAll(1)
ok(AWayArrow:IsShown(), "arrow points at the next one")
player.west = 0
player.north = 198
tickAll(1)
ok(AWay.Get() == nil and not AWayArrow:IsShown() and #ns.chardb.list == 0, "last arrival clears everything")
player.north = 0

local pm, px, py, pt = ns.Way.Parse("45.2 61")
ok(pm == 1429 and math.abs(px - 0.452) < 1e-9 and py == 0.61 and pt == nil, "way x y")
pm, px, py, pt = ns.Way.Parse("45.2, 61.5 Old mine")
ok(pm == 1429 and math.abs(py - 0.615) < 1e-9 and pt == "Old mine", "way with comma and name")
pm, px, py, pt = ns.Way.Parse("Westfall 30 40 Farm")
ok(pm == 1436 and px == 0.3 and pt == "Farm", "way with zone")
pm, px, py, pt = ns.Way.Parse("Elwynn Forest 30 40")
ok(pm == 1429 and py == 0.4 and pt == nil, "way with a two word zone")
pm = ns.Way.Parse("west 10 10")
ok(pm == 1436, "partial zone name")
pm, px = ns.Way.Parse("Nowhere 30 40")
ok(pm == nil and px:find("unknown zone"), "way unknown zone")
ok(ns.Way.Parse("clear") == "clear" and ns.Way.Parse("") == nil and ns.Way.Parse("hello") == nil, "way clear and junk")
ok(ns.Way.Parse("300 20") == nil, "way out of range")
ok(ns.Way.Parse("list") == "list" and ns.Way.Parse("next") == "next" and select(2, ns.Way.Parse("remove 2")) == 2, "way commands")

SlashCmdList["AWAY"]("Westfall 30 40 Farm")
SlashCmdList["AWAY"]("45 55")
SlashCmdList["AWAY"]("10 20 Third")
ok(AWay.Count() == 3 and select(4, AWay.Get()) == "Third" and ns.chardb.list[1][1] == 1436, "slash way adds and saves")
local before = #printed
SlashCmdList["AWAY"]("list")
ok(#printed == before + 3 and printed[#printed]:find("> Third"), "way list")
SlashCmdList["AWAY"]("remove 1")
ok(AWay.Count() == 2 and select(4, AWay.Get()) == "Third", "remove keeps the active one")
SlashCmdList["AWAY"]("remove 9")
ok(printed[#printed]:find("no waypoint"), "remove out of range")
ok(AWay.Remove(2) and AWay.Count() == 1 and AWay.Get() ~= nil, "removing the active one picks another")
SlashCmdList["AWAY"]("next")
SlashCmdList["AWAY"]("junk")
SlashCmdList["AWAY"]("clear")
ok(AWay.Get() == nil and AWay.Next() == false, "way clear")
SlashCmdList["AWAY"]("list")

mods.ctrl = true
sc.__scripts.OnMouseUp(sc, "LeftButton")
mods.ctrl = false
wm, wx, wy = AWay.Get()
ok(wm == 1429 and wx == 0.3 and wy == 0.4, "ctrl-click on the map adds a waypoint")
sc.__scripts.OnMouseUp(sc, "LeftButton")
ok(AWay.Count() == 1, "plain click ignored")
AMap = {}
mods.ctrl = true
ok(ns.Way.MapClick("LeftButton") == false, "leaves ctrl-click to AMap when it is loaded")
mods.ctrl = false
AMap = nil

AWay.Add(1429, 0.6, 0.6, "B")
AWay.Add(1429, 0.7, 0.7, "C")
tickAll(1)
ok(pins(Minimap) >= 2, "nearby pins on the minimap " .. pins(Minimap))
for _, f in ipairs(M.frames) do
	if f.point and f.point.title == "B" and f:IsShown() then
		f.__scripts.OnClick(f, "LeftButton")
		break
	end
end
ok(select(4, AWay.Get()) == "B", "clicking a pin selects it")
for _, f in ipairs(M.frames) do
	if f.point and f.point.title == "C" and f:IsShown() then
		f.__scripts.OnClick(f, "RightButton")
		break
	end
end
ok(AWay.Count() == 2 and select(4, AWay.Get()) == "B", "right-clicking a pin removes it")
ns.db.single = true
ns:Fire("OPTIONS")
ok(AWay.Count() == 1 and select(4, AWay.Get()) == "B", "one waypoint only keeps the active one")
AWay.Add(1429, 0.2, 0.2, "Only")
ok(AWay.Count() == 1 and select(4, AWay.Get()) == "Only", "one waypoint only replaces")
ns.db.single = false
ns.db.mapPins = false
ns.db.miniPins = false
ns.db.arrow = false
ns:Fire("OPTIONS")
tickAll(1)
ok(pins(sc.Child) == 0 and pins(Minimap) == 0 and not AWayArrow:IsShown(), "pins and arrow can be turned off")
ns.db.mapPins, ns.db.miniPins, ns.db.arrow = true, true, true

SlashCmdList["AWAYOPT"]("unlock")
ok(ns.db.arrowDb.locked == false, "unlock")
SlashCmdList["AWAYOPT"]("lock")
ok(ns.db.arrowDb.locked == true, "lock")
SlashCmdList["AWAYOPT"]("reset")
SlashCmdList["AWAYOPT"]("")
local n = 0
for _, e in ipairs(ns.Options()) do
	if e.func then e.func() n = n + 1 end
end
ok(n >= 9, "options entries " .. n)
AWay.Add(1429, 0.5, 0.3, "Again")
SlashCmdList["AWAYOPT"]("clear")
ok(AWay.Get() == nil, "away clear")
ACoreMinimapButton.__scripts.OnClick(ACoreMinimapButton, "LeftButton")

local secret = {}
issecretvalue = function(v) return v == secret end
ok(ns.Num(secret) == nil and ns.Num(3) == 3, "secret numbers rejected")
AWay.Add(1429, 0.5, 0.3)
local realFacing = GetPlayerFacing
GetPlayerFacing = function() return secret end
ok(ns.Way.Angle() == nil, "secret facing gives no angle")
tickAll(1)
ok(not AWayArrow:IsShown(), "no arrow with a secret facing")
GetPlayerFacing = realFacing
UnitPosition = function() return secret, secret, 0, 0 end
ok(ns.Way.Vector() == nil, "secret position gives no vector")
tickAll(1)
flush()

print_real(string.format("ok: %d checks (away)", M.checks()))
