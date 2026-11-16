local M = dofile("tools/mock.lua")
local ok, event, flush, printed, mods = M.ok, M.event, M.flush, M.printed, M.mods

local combat = false
function InCombatLockdown() return combat end
function hooksecurefunc(t, name, fn)
	local old = t[name]
	t[name] = function(...)
		old(...)
		fn(...)
	end
end
function CreateVector2D(x, y)
	return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end
function GetTime() return M.now or 0 end
function GetCVar() return "0" end
function IsIndoors() return false end
function UnitExists(unit) return unit == "party1" or unit == "party2" end
function UnitIsUnit() return false end
function UnitName(unit) return "Name " .. unit end
function UnitLevel() return 15 end
function GetNumGroupMembers() return 3 end
function IsInRaid() return false end
function IsInGroup() return true end
function GetUnitSpeed() return M.speed or 0 end
function GetMinimapZoneText() return "Goldshire" end
local sent = {}
function SendChatMessage(text, channel) sent[#sent + 1] = channel .. ":" .. text end
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
Enum.UIMapType = { Continent = 2, Zone = 3 }

local player = { map = 1429, x = 0.5, y = 0.5, north = 0, west = 0, facing = 0, instance = 0 }
local SIZE = 1000
local names = { [1429] = "Elwynn Forest", [1436] = "Westfall", [1415] = "Eastern Kingdoms", [1414] = "Kalimdor", [1411] = "Durotar" }
C_Map.GetMapInfo = function(map) return names[map] and { name = names[map], mapID = map } or nil end
C_Map.GetBestMapForUnit = function() return player.map end
C_Map.GetPlayerMapPosition = function(map, unit)
	if map ~= player.map then return nil end
	if unit == "player" then return CreateVector2D(player.x, player.y) end
	if unit == "party1" then return CreateVector2D(0.25, 0.75) end
	return nil
end
C_Map.GetWorldPosFromMapPos = function(map, v)
	return 0, CreateVector2D((0.5 - v.y) * SIZE, (0.5 - v.x) * SIZE)
end
C_Map.GetMapChildrenInfo = function(parent, kind)
	if kind == 2 then return { { name = "Eastern Kingdoms", mapID = 1415 }, { name = "Kalimdor", mapID = 1414 } } end
	if parent == 1415 then return { { name = "Westfall", mapID = 1436 }, { name = "Elwynn Forest", mapID = 1429 } } end
	return { { name = "Durotar", mapID = 1411 } }
end
C_Map.OpenWorldMap = function(map) WorldMapFrame.__map = map end
function UnitPosition() return player.north, player.west, 0, player.instance end
function GetPlayerFacing() return player.facing end

WorldMapFrame = CreateFrame("Frame", "WorldMapFrame")
WorldMapFrame.__map = 1429
function WorldMapFrame:GetMapID() return self.__map end
function WorldMapFrame:SetMapID(map) self.__map = map self:OnMapChanged() end
function WorldMapFrame:OnMapChanged() end
function WorldMapFrame:GetScale() return self.__scale or 1 end
function WorldMapFrame:SetScale(s) self.__scale = s end
function WorldMapFrame:SetPoint(...) self.__point = { ... } end
function WorldMapFrame:SetAlpha(a) self.__alpha = a end
function WorldMapFrame:HookScript(name, fn) self.__scripts[name] = fn end
function WorldMapFrame:IsMouseOver() return false end
WorldMapFrame.BlackoutFrame = CreateFrame("Frame")
local sc = CreateFrame("Frame")
WorldMapFrame.ScrollContainer = sc
sc.Child = CreateFrame("Frame")
sc.Child.__w, sc.Child.__h = 1000, 600
function WorldMapFrame:GetCanvas() return sc.Child end
local cursor = { 0.3, 0.4 }
function sc:GetNormalizedCursorPosition() return cursor[1], cursor[2] end
function sc:IsMouseOver() return cursor[1] ~= nil end
function sc:HookScript(name, fn) self.__scripts[name] = fn end
function sc:CreateZoomLevels() self.zoomLevels = { { scale = 0.5, layerIndex = 1 }, { scale = 1, layerIndex = 1 } } end
local pans = {}
function sc:SetPanTarget(x, y) pans[#pans + 1] = { x, y } end
sc:CreateZoomLevels()

Minimap.__w = 140
Minimap.__zoom = 2
function Minimap:GetZoom() return self.__zoom end
function Minimap:SetZoom(z) self.__zoom = z end
function Minimap:GetZoomLevels() return 6 end
function Minimap:SetMaskTexture(t) self.__mask = t end
function Minimap:HookScript(name, fn) self.__scripts[name] = fn end
MinimapCluster = CreateFrame("Frame", "MinimapCluster")
function MinimapCluster:SetScale(s) self.__scale = s end
function MinimapCluster:SetPoint(...) self.__point = { ... } end
MinimapZoomIn = CreateFrame("Button", "MinimapZoomIn")
MinimapZoomOut = CreateFrame("Button", "MinimapZoomOut")
function MinimapZoomIn:HookScript(name, fn) self.__scripts[name] = fn end
MiniMapWorldMapButton = CreateFrame("Button", "MiniMapWorldMapButton")
GameTimeFrame = CreateFrame("Button", "GameTimeFrame")
MinimapBorder = CreateFrame("Frame", "MinimapBorder")

local function tick(frames, dt)
	for _, f in ipairs(frames) do
		local fn = f.__scripts.OnUpdate
		if fn then fn(f, dt or 1) end
	end
end
local function tickAll(dt)
	local list = {}
	for _, f in ipairs(M.frames) do list[#list + 1] = f end
	tick(list, dt)
end

M.load("ACore", "ACore")
local ns = M.load("AMap", "AMap")
event("PLAYER_LOGIN")
ok(ns.db and ns.db.map.window, "defaults")
ok(AMapBar, "map bar built")

ok(sc.zoomLevels.amap and #sc.zoomLevels == 5, "zoom levels extended " .. #sc.zoomLevels)
ok(sc.zoomLevels[5].scale > 4, "deepest zoom scale " .. sc.zoomLevels[5].scale)
sc:CreateZoomLevels()
ok(#sc.zoomLevels == 5, "zoom re-extended after rebuild")
ok(ns.Map.ExtendZoom() == false, "zoom not extended twice")
ns.db.map.zoom = false
sc.zoomLevels = { { scale = 1, layerIndex = 1 } }
ok(ns.Map.ExtendZoom() == false and #sc.zoomLevels == 1, "zoom option off")
ns.db.map.zoom = true

WorldMapFrame.__scripts.OnShow(WorldMapFrame)
ok(WorldMapFrame.__scale == 0.75 and ns.db.map.scale == 0.75, "fullscreen map shrunk to a window")
ok(ns.Map.SetScale(5) == 1.5 and ns.Map.SetScale(0.1) == 0.4, "scale clamped")
ns.Map.SetScale(0.8)

tickAll(1)
ok(AMapBar.coords.__text:find("Player 50.0, 50.0") and AMapBar.coords.__text:find("Cursor 30.0, 40.0"), "coords " .. tostring(AMapBar.coords.__text))
ok(AMapBar.title.__text == "Elwynn Forest", "title")
ok(AMapBar.info.__text == "1-10  Alliance", "zone info " .. tostring(AMapBar.info.__text))
cursor[1] = nil
tickAll(1)
ok(not AMapBar.coords.__text:find("Cursor"), "no cursor coords off the map")
cursor[1] = 0.3
ok(#ns.Map.GroupUnits() == 2, "party units")

M.speed = 7
tickAll(1)
ok(WorldMapFrame.__alpha == 0.45, "fades while moving")
M.speed = 0
tickAll(1)
ok(WorldMapFrame.__alpha == 1, "opaque when standing")

local x, y = ns.UnitPos(1429, "player")
ok(x == 0.5 and y == 0.5, "unit pos")
ok(ns.UnitPos(1436, "player") == nil, "no pos on another map")
ok(ns.Num(nil) == nil and ns.Num("a") == nil and ns.Num(3) == 3, "num guard")

AMapBar.follow.__scripts.OnClick(AMapBar.follow, "LeftButton")
ok(ns.db.map.follow and #pans > 0, "follow pans to player")
WorldMapFrame.__map = 1436
tickAll(1)
ok(WorldMapFrame.__map == 1429, "follow returns to the player map")
AMapBar.zones.__scripts.OnClick(AMapBar.zones, "LeftButton")
ns.Map.Go(1436)
ok(WorldMapFrame.__map == 1436 and not ns.db.map.follow, "jump turns follow off")
ok(AMapBar.info.__text == "10-20  Alliance", "westfall info")
ns.Map.Go(1429)
AMapBar.options.__scripts.OnClick(AMapBar.options, "LeftButton")

ok(AMap.SetWaypoint(1429, 0.5, 0.3, "North") == true, "set waypoint")
local wm, wx, wy, wt = AMap.GetWaypoint()
ok(wm == 1429 and wx == 0.5 and wy == 0.3 and wt == "North", "get waypoint")
local dist, bearing = ns.Way.Vector()
ok(math.abs(dist - 200) < 0.01 and math.abs(bearing) < 0.001, "north waypoint distance " .. dist)
local angle = ns.Way.Angle()
ok(math.abs(angle) < 0.001, "arrow straight ahead")
player.facing = math.pi / 2
angle = ns.Way.Angle()
ok(math.abs(angle + math.pi / 2) < 0.001, "arrow to the right when facing west")
player.facing = 0
AMap.SetWaypoint(1429, 30, 50)
dist, bearing = ns.Way.Vector()
ok(math.abs(dist - 200) < 0.01 and math.abs(bearing - math.pi / 2) < 0.001, "west waypoint bearing, percent input")
ok(select(4, AMap.GetWaypoint()) == "Elwynn Forest 30.0, 50.0", "default title")
ok(AMap.SetWaypoint(1429, 2000, 5) == false and AMap.SetWaypoint(nil, 1, 1) == false, "bad waypoint rejected")

M.now = 0
tickAll(1)
ok(AMapArrow and AMapArrow:IsShown(), "arrow shown")
ok(AMapArrow.dist.__text:find("200 yd"), "arrow distance text " .. tostring(AMapArrow.dist.__text))
M.now = 1
player.west = 10
tickAll(1)
M.now = 2
player.west = 20
tickAll(1)
ok(AMapArrow.dist.__text:find("180 yd") and AMapArrow.dist.__text:find("0:18"), "eta " .. tostring(AMapArrow.dist.__text))
AMapArrow.__scripts.OnClick(AMapArrow, "RightButton")
AMapArrow.__scripts.OnDragStart(AMapArrow)
AMapArrow.__scripts.OnDragStop(AMapArrow)

player.instance = 1
tickAll(1)
ok(not AMapArrow:IsShown(), "arrow hidden on another continent")
player.instance = 0
local realPos = UnitPosition
UnitPosition = function() return nil end
tickAll(1)
ok(not AMapArrow:IsShown(), "arrow hidden without a position")
UnitPosition = realPos

player.west = 196
tickAll(1)
ok(AMap.GetWaypoint() == nil and not AMapArrow:IsShown(), "cleared on arrival")
ok(printed[#printed]:find("arrived"), "arrival message")
ok(ns.db.way.saved == nil, "saved waypoint cleared")
player.west = 0

local pm, px, py, pt = ns.Way.Parse("45.2 61")
ok(pm == 1429 and math.abs(px - 0.452) < 1e-9 and py == 0.61 and pt == nil, "way x y")
pm, px, py, pt = ns.Way.Parse("45.2, 61.5 Old mine")
ok(pm == 1429 and math.abs(py - 0.615) < 1e-9 and pt == "Old mine", "way with comma and name")
pm, px, py, pt = ns.Way.Parse("Westfall 30 40 Farm")
ok(pm == 1436 and px == 0.3 and pt == "Farm", "way with zone")
pm, px = ns.Way.Parse("Nowhere 30 40")
ok(pm == nil and px:find("unknown zone"), "way unknown zone")
ok(ns.Way.Parse("clear") == "clear" and ns.Way.Parse("") == nil and ns.Way.Parse("hello") == nil, "way clear and junk")
ok(ns.Way.Parse("300 20") == nil, "way out of range")
SlashCmdList["AMAPWAY"]("Westfall 30 40 Farm")
ok(select(4, AMap.GetWaypoint()) == "Farm" and ns.db.way.saved[1] == 1436, "slash way sets and saves")
tickAll(1)
SlashCmdList["AMAPWAY"]("junk")
SlashCmdList["AMAPWAY"]("clear")
ok(AMap.GetWaypoint() == nil, "slash way clear")

mods.ctrl = true
ok(ns.Map.Click("LeftButton") == true, "ctrl-click handled")
mods.ctrl = false
wm, wx, wy = AMap.GetWaypoint()
ok(wm == 1429 and wx == 0.3 and wy == 0.4, "ctrl-click waypoint at cursor")
sc.__scripts.OnMouseUp(sc, "RightButton")
ns.db.map.send = true
mods.alt = true
ok(ns.Map.Click("LeftButton") == true and sent[1] == "PARTY:Elwynn Forest 30.0, 40.0", "alt-click tells party " .. tostring(sent[1]))
mods.alt = false
ok(ns.Map.Click("LeftButton") == false, "plain click ignored")
AMap.ClearWaypoint()

ok(ns.Mini.Zoom(1) == 3 and Minimap.__zoom == 3, "minimap zoom in")
Minimap.__zoom = 5
ok(ns.Mini.Zoom(1) == 5, "minimap zoom clamped high")
Minimap.__zoom = 0
ok(ns.Mini.Zoom(-1) == 0, "minimap zoom clamped low")
Minimap.__scripts.OnMouseWheel(Minimap, 1)
ok(Minimap.__zoom == 1, "wheel zooms")
ns.db.minimap.wheel = false
Minimap.__scripts.OnMouseWheel(Minimap, 1)
ok(Minimap.__zoom == 1, "wheel option off")
ok(not MinimapZoomIn:IsShown() and not MiniMapWorldMapButton:IsShown() and GameTimeFrame:IsShown(), "clutter hidden by default")
MinimapZoomIn.__shown = true
MinimapZoomIn.__scripts.OnShow(MinimapZoomIn)
ok(not MinimapZoomIn:IsShown(), "hidden button stays hidden")
ns.db.minimap.hideZoom = false
ns.db.minimap.square = true
ns.db.minimap.zone = true
ns:Fire("OPTIONS")
ok(MinimapZoomIn:IsShown(), "zoom buttons restored")
ok(Minimap.__mask == "Interface\\Buttons\\WHITE8X8" and GetMinimapShape() == "SQUARE" and not MinimapBorder:IsShown(), "square minimap")
tickAll(1)
ok(AMapMinimapInfo.coords.__text == "50.0, 50.0" and AMapMinimapInfo.zone.__text == "Goldshire", "minimap info text")
ns.db.minimap.square = false
ns:Fire("OPTIONS")
ok(Minimap.__mask == "Textures\\MinimapMask" and GetMinimapShape() == "ROUND" and MinimapBorder:IsShown(), "round minimap restored")

combat = true
ns.db.minimap.scale = 1.2
ns:Fire("OPTIONS")
ok(MinimapCluster.__scale ~= 1.2 and ns.Queued() > 0, "minimap scale deferred in combat")
local before = WorldMapFrame.__scale
ns.Map.SetScale(1.1)
ok(WorldMapFrame.__scale == before, "map scale deferred in combat")
combat = false
event("PLAYER_REGEN_ENABLED")
ok(MinimapCluster.__scale == 1.2 and WorldMapFrame.__scale == 1.1 and ns.Queued() == 0, "deferred work applied after combat")

SlashCmdList["AMAP"]("unlock")
ok(ns.db.minimap.locked == false and ns.db.way.arrowDb.locked == false, "unlock")
SlashCmdList["AMAP"]("lock")
ok(ns.db.minimap.locked == true, "lock")
AMap.SetWaypoint(1429, 0.2, 0.2)
SlashCmdList["AMAP"]("clear")
ok(AMap.GetWaypoint() == nil, "amap clear")
SlashCmdList["AMAP"]("reset")
ok(ns.db.map.pos == nil and ns.db.minimap.scale == 1, "reset")
SlashCmdList["AMAP"]("")
local n = 0
for _, e in ipairs(ns.Options()) do
	if e.func then e.func() n = n + 1 end
end
ok(n > 20, "options entries " .. n)
event("PLAYER_ENTERING_WORLD")
tickAll(1)
flush()

local secret = {}
issecretvalue = function(v) return v == secret end
ok(ns.Num(secret) == nil, "secret numbers rejected")
local realFacing = GetPlayerFacing
GetPlayerFacing = function() return secret end
AMap.SetWaypoint(1429, 0.5, 0.3)
ok(ns.Way.Angle() == nil, "secret facing gives no angle")
tickAll(1)
GetPlayerFacing = realFacing
C_Map.GetPlayerMapPosition = function() return { x = secret, y = secret } end
ok(ns.UnitPos(1429, "player") == nil, "secret position ignored")
tickAll(1)

print_real(string.format("ok: %d checks", M.checks()))
