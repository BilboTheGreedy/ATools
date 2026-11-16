local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

local SECRET = {}
function issecretvalue(v) return v == SECRET end
local combat = false
function InCombatLockdown() return combat end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end

local drivers = {}
function RegisterStateDriver(frame, state, cond)
	ok(not combat, "state driver registered in combat")
	drivers[frame] = drivers[frame] or {}
	drivers[frame][state] = cond
end
function UnregisterStateDriver(frame, state)
	if drivers[frame] then drivers[frame][state] = nil end
end

local protected = 0
local guarded = { SetPoint = true, SetSize = true, Show = true, Hide = true, SetAttribute = true, SetScale = true, SetParent = true, ClearAllPoints = true }
local attrs = setmetatable({}, { __mode = "k" })
for name in pairs(guarded) do
	local base = M.methods[name]
	M.methods[name] = function(self, ...)
		if combat and self.__secure then protected = protected + 1 end
		if name == "SetAttribute" then
			attrs[self] = attrs[self] or {}
			local k, v = ...
			attrs[self][k] = v
			local fn = self.__scripts.OnAttributeChanged
			if fn then fn(self, k, v) end
			return
		end
		if base then return base(self, ...) end
	end
end
function M.methods:GetAttribute(k) return attrs[self] and attrs[self][k] end
function M.methods:GetLeft() return 101 end
function M.methods:GetBottom() return 203 end
function M.methods:GetFrameLevel() return 1 end
local over = {}
function M.methods:IsMouseOver() return over[self] or false end
local realCreate = CreateFrame
function CreateFrame(kind, name, parent, template)
	local f = realCreate(kind, name, parent, template)
	if template and template:find("Secure") then
		ok(not combat, "secure frame created in combat")
		f.__secure = true
	end
	return f
end

local actions = {
	[1] = { texture = 1001, usable = true, range = true, text = "Macro name" },
	[2] = { texture = 1002, usable = false, mana = true },
	[3] = { texture = 1003, usable = true, range = false, count = 5, consumable = true },
	[4] = { texture = 1004, usable = SECRET, count = SECRET, consumable = true, range = SECRET },
	[5] = { texture = 1005, usable = false, equipped = true },
	[6] = { texture = 1006, usable = true, current = true, count = 2000, stackable = true },
	[73] = { texture = 1073, usable = true },
	[61] = { texture = 1061, usable = true },
}
local function field(name, default)
	return function(slot)
		local a = actions[slot]
		if not a then return default end
		if a[name] == nil then return default end
		return a[name]
	end
end
GetActionTexture = field("texture")
HasAction = function(slot) return actions[slot] ~= nil end
IsUsableAction = function(slot)
	local a = actions[slot]
	if not a then return false, false end
	return a.usable, a.mana or false
end
IsActionInRange = field("range")
GetActionCount = field("count", 0)
IsConsumableAction = field("consumable", false)
IsStackableAction = field("stackable", false)
GetActionText = field("text")
IsEquippedAction = field("equipped", false)
IsCurrentAction = field("current", false)
IsAutoRepeatAction = function() return false end
local cooldowns = 0
GetActionCooldown = function(slot)
	cooldowns = cooldowns + 1
	if slot == 4 then return SECRET, SECRET, 1 end
	return 10, 5, 1
end
local picked, placed
function PickupAction(slot) picked = slot end
function PlaceAction(slot) placed = slot end

function GetPetActionInfo(i)
	if i > 7 then return nil end
	return "Pet " .. i, i == 1 and "PET_ATTACK_TEXTURE" or 2000 + i, i == 1, i == 2, i == 4, i == 4
end
PET_ATTACK_TEXTURE = 2999
function GetPetActionCooldown() return 0, 0, 1 end
local autocast
function TogglePetAutocast(i) autocast = i end
local forms = 3
function GetNumShapeshiftForms() return forms end
function GetShapeshiftFormInfo(i)
	if i > forms then return nil end
	return 3000 + i, i == 2, i ~= 3, 4000 + i
end
function GetShapeshiftFormCooldown() return 0, 0, 1 end

local binds = { ACTIONBUTTON1 = { "1" }, ACTIONBUTTON2 = { "SHIFT-2", "BUTTON4" }, MULTIACTIONBAR1BUTTON1 = { "CTRL-NUMPAD1" } }
function GetBindingKey(cmd) return unpack(binds[cmd] or {}) end
function SetBinding(key, cmd)
	ok(not combat, "binding changed in combat")
	for _, list in pairs(binds) do
		for i = #list, 1, -1 do
			if list[i] == key then table.remove(list, i) end
		end
	end
	if cmd then
		binds[cmd] = binds[cmd] or {}
		table.insert(binds[cmd], key)
	end
	return true
end
local saved = 0
function SaveBindings() saved = saved + 1 end
function GetCurrentBindingSet() return 1 end
local overrides = {}
function ClearOverrideBindings() overrides = {} end
function SetOverrideBindingClick(_, _, key, name)
	ok(not combat, "override binding in combat")
	overrides[key] = name
end

MainMenuBar = M.obj("Frame")
MultiBarBottomLeft = M.obj("Frame")
StanceBar = M.obj("Frame")
PetActionBar = M.obj("Frame")
for i = 1, 12 do _G["ActionButton" .. i] = M.obj("Button") end

M.load("ACore", "ACore")
ABarsDB = { profiles = { ["Other - Realm"] = { locked = true, bars = { bar1 = { count = 6, cols = 3, size = 44, enabled = true } } } } }
local ns = M.load("ABars", "ABars")
event("PLAYER_LOGIN")
flush()

ok(ns.p and ns.p.bars.bar1.count == 12 and ns.charKey == "Tester - Realm", "profile created")
ok(#ns.barList == 8, "eight bars")
ok(#ns.buttons == 6 * 12 + 10 + 10, "button count " .. #ns.buttons)
local b1 = ABarsBar1Button1
ok(b1 and b1.slot == 1 and b1:GetAttribute("type") == "action" and b1:GetAttribute("action") == 1, "bar1 button attributes")
ok(ABarsBar2Button1.slot == 61 and ABarsBar6Button12.slot == 24, "bar offsets")
ok(ABarsPetButton3:GetAttribute("type") == "pet" and ABarsPetButton3:GetAttribute("action") == 3, "pet attributes")
ok(ABarsStanceButton2:GetAttribute("spell") == 4002, "stance spell")
ok(drivers[ABarsBar1].page and drivers[ABarsBar1].page:find("bonusbar:1"), "paging driver")
ok(drivers[ABarsBar1].visibility == "show", "bar1 visible")
ok(drivers[ABarsBar5].visibility == "hide", "bar5 disabled")
ok(drivers[ABarsPet].visibility == "[pet]show;hide", "pet visibility")
ok(ns.bars.stance.count == 3 and not ABarsStanceButton4.active, "stance count follows forms")
ok(ABarsHidden and ns.hiddenCount and ns.hiddenCount >= 3, "blizzard bars parked " .. tostring(ns.hiddenCount))

ok(b1.has and b1.hotkey:GetText() == "1", "hotkey text " .. tostring(b1.hotkey:GetText()))
ok(ABarsBar1Button2.hotkey:GetText() == "s2", "short hotkey")
ok(ns.ShortKey("CTRL-NUMPAD1") == "cN1" and ns.ShortKey("ALT-MOUSEWHEELUP") == "aWU" and ns.ShortKey(nil) == "", "key shortening")
ok(overrides["1"] == "ABarsBar1Button1" and overrides["BUTTON4"] == "ABarsBar1Button2" and overrides["CTRL-NUMPAD1"] == "ABarsBar2Button1", "override bindings")
ok(ABarsBar1Button3.count:GetText() == "5", "count text")
ok(ABarsBar1Button4.count:GetText() == SECRET, "secret count passed through")
ok(ABarsBar1Button6.count:GetText() == "*", "large count")
ok(not ABarsBar1Button7.has, "empty slot")
ns.p.macroNames = true
ns.Button.UpdateAll()
ok(b1.label:GetText() == "Macro ", "macro name")
ok(cooldowns > 0, "cooldowns read")

ns.Button.Create("ABarsExtra", UIParent, "action", 1).slot = nil
ns.buttons[#ns.buttons].active = true
ns.Button.Update(ns.buttons[#ns.buttons])
table.remove(ns.buttons)

b1.__scripts.OnAttributeChanged(b1, "action", 73)
ok(b1.slot == 73 and b1.has, "paging updates slot")
b1.__scripts.OnAttributeChanged(b1, "action", 1)
b1.__scripts.OnAttributeChanged(b1, "other", 5)
ok(b1.slot == 1, "slot restored")

b1.__scripts.OnEnter(b1)
ok(ns.hover == b1, "hover")
b1.__scripts.PreClick(b1, "LeftButton")
b1.__scripts.PostClick(b1, "LeftButton")
flush()
b1.__scripts.OnDragStart(b1)
ok(picked == nil, "drag needs shift")
M.mods.shift = true
b1.__scripts.OnDragStart(b1)
M.mods.shift = false
ok(picked == 1, "drag picks up")
ABarsBar1Button7.__scripts.OnReceiveDrag(ABarsBar1Button7)
ok(placed == 7, "drop places")
b1.__scripts.OnLeave(b1)
ok(ns.hover == nil, "hover cleared")
local pet2 = ABarsPetButton2
pet2.__scripts.OnEnter(pet2)
pet2.__scripts.PostClick(pet2, "RightButton")
ok(autocast == 2, "pet autocast toggle")
pet2.__scripts.OnLeave(pet2)
local st = ABarsStanceButton1
st.__scripts.OnEnter(st)
st.__scripts.OnLeave(st)

for _, name in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_USABLE", "SPELL_UPDATE_USABLE", "PLAYER_TARGET_CHANGED", "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "PET_BAR_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "PET_BAR_UPDATE", "PET_UI_UPDATE", "UNIT_PET", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE", "UPDATE_SHAPESHIFT_COOLDOWN", "UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD" }) do
	event(name, "player")
end
forms = 5
event("UPDATE_SHAPESHIFT_FORMS")
ok(ns.bars.stance.count == 5 and ABarsStanceButton5.active, "stance bar grows")

ns.p.bars.bar1.hideEmpty = true
ns.Button.UpdateAll()
ok(ABarsBar1Button7.alpha == 0 and b1.alpha == 1, "empty hidden")
event("ACTIONBAR_SHOWGRID")
ok(ABarsBar1Button7.alpha == 1, "grid shows empty")
event("ACTIONBAR_HIDEGRID")
ok(ABarsBar1Button7.alpha == 0, "grid hides empty")

local cfg = ns.p.bars.bar2
cfg.fade = true
ns.ticker.__scripts.OnUpdate(ns.ticker, 0.3)
ok(ns.bars.bar2.alpha == 0.35, "faded out of combat")
cfg.mouseover = true
ns.Fade(false)
ok(ns.bars.bar2.alpha == 0, "mouseover hidden")
over[ABarsBar2] = true
ns.Fade(false)
ok(ns.bars.bar2.alpha == 1, "mouseover shown")
cfg.mouseover = false

combat = true
event("PLAYER_REGEN_DISABLED")
ok(ns.bars.bar2.alpha == 1, "full alpha in combat")
ok(ns.SetLocked(false) == false and ns.p.locked, "no unlock in combat")
ok(ns.SetBindMode(true) == false and not ns.bindMode, "no bind mode in combat")
ok(ns.Bind(b1, "F") == false, "no binding in combat")
ns.p.bars.bar1.cols = 6
ns.p.bars.bar5.enabled = true
ok(ns.LayoutBar("bar1") == false, "layout deferred")
ok(ns.LayoutAll() == false, "layout all deferred")
forms = 2
event("UPDATE_SHAPESHIFT_FORMS")
ok(ns.bars.stance.count == 5, "stance layout waits for combat end")
b1.__scripts.OnDragStart(b1)
ns.ticker.__scripts.OnUpdate(ns.ticker, 0.3)
event("ACTIONBAR_SLOT_CHANGED")
event("ACTIONBAR_UPDATE_COOLDOWN")
ok(protected == 0, "no protected calls in combat: " .. protected)
combat = false
event("PLAYER_REGEN_ENABLED")
ok(drivers[ABarsBar5].visibility == "show" and ns.bars.stance.count == 2, "deferred layout applied")
ok(ns.bars.bar2.alpha == 0.35, "fades again after combat")

ok(ns.SetLocked(false) and not ns.p.locked, "unlock")
local h = ns.handles.bar1
ok(h and h:IsShown(), "handle shown")
h.__scripts.OnEnter(h)
h.__scripts.OnLeave(h)
h.__scripts.OnDragStart(h)
h.__scripts.OnDragStop(h)
local pos = ns.p.bars.bar1.pos
ok(pos and pos[3] == 104 and pos[4] == 200, "snapped position " .. tostring(pos and pos[3]) .. "," .. tostring(pos and pos[4]))
ns.p.snap = false
h.__scripts.OnDragStart(h)
h.__scripts.OnDragStop(h)
ok(ns.p.bars.bar1.pos[3] == 101, "unsnapped position")
h.__scripts.OnClick(h, "RightButton")
combat = true
event("PLAYER_REGEN_DISABLED")
ok(ns.p.locked and not h:IsShown(), "auto lock in combat")
combat = false
event("PLAYER_REGEN_ENABLED")

ok(ns.SetBindMode(true) and ns.bindMode and ABarsBindFrame:IsShown(), "bind mode")
local key = ABarsBindFrame.__scripts.OnKeyDown
key(ABarsBindFrame, "F")
ok(not binds.ACTIONBUTTON3, "no bind without hover")
local b3 = ABarsBar1Button3
b3.__scripts.OnEnter(b3)
key(ABarsBindFrame, "LSHIFT")
M.mods.shift = true
key(ABarsBindFrame, "F")
M.mods.shift = false
ok(binds.ACTIONBUTTON3 and binds.ACTIONBUTTON3[1] == "SHIFT-F" and overrides["SHIFT-F"] == "ABarsBar1Button3", "bound key")
ok(b3.hotkey:GetText() == "sF" and saved > 0, "bound hotkey text")
key(ABarsBindFrame, "1")
ok(not overrides["1"] or overrides["1"] == "ABarsBar1Button3", "key moved between buttons")
key(ABarsBindFrame, "BACKSPACE")
ok(#binds.ACTIONBUTTON3 == 0 and b3.hotkey:GetText() == "", "unbound")
b3.__scripts.OnLeave(b3)
local b6 = ABarsBar6Button1
b6.__scripts.OnEnter(b6)
key(ABarsBindFrame, "G")
ok(binds["CLICK ABarsBar6Button1:LeftButton"][1] == "G", "click binding for bar 6")
b6.__scripts.OnLeave(b6)
key(ABarsBindFrame, "ESCAPE")
ok(not ns.bindMode and not ABarsBindFrame:IsShown(), "escape leaves bind mode")
ns.SetBindMode(true)
combat = true
event("PLAYER_REGEN_DISABLED")
ok(not ns.bindMode, "combat leaves bind mode")
combat = false
event("PLAYER_REGEN_ENABLED")

local menus = 0
local realMenu = ACore.UI.Menu
local seen = {}
local function walk(entries, depth)
	menus = menus + 1
	if depth > 3 then return end
	for _, e in ipairs(entries) do
		if e.func and not e.text:find("Reset") and not e.text:find("^<") and not e.text:find("Keybind") and not e.text:find("nlock") and not e.text:find("Lock bars") then
			local captured
			ACore.UI.Menu = function(_, list) captured = list end
			e.func()
			ACore.UI.Menu = realMenu
			if captured then walk(captured, depth + 1) end
		end
	end
end
ACore.UI.Menu = function(_, list) walk(list, 0) end
ns.OpenOptions()
ACore.UI.Menu = realMenu
ok(menus > 40, "menus walked " .. menus)
ns.OpenOptions()
for _, def in ipairs(ns.BARS) do ns.BarMenu(def.key) end
ns.ProfileMenu()

ok(ns.CopyProfile("Nobody - Realm") == false and ns.CopyProfile(ns.charKey) == false, "copy rejects bad source")
ok(ns.CopyProfile("Other - Realm"), "copy profile")
ok(ns.p.bars.bar1.count == 6 and ns.p.bars.bar1.size == 44 and ns.p.bars.bar2.count == 12, "copied and filled")
ok(ABarsDB.profiles["Tester - Realm"] == ns.p and ABarsDB.profiles["Other - Realm"].bars.bar1 ~= ns.p.bars.bar1, "profiles stay separate")
ok(ns.bars.bar1.count == 6 and not ABarsBar1Button7.active, "copied layout applied")
ns.ResetProfile()
ok(ns.p.bars.bar1.count == 12 and ABarsBar1Button12.active, "reset profile")

for _, cmd in ipairs({ "", "unlock", "lock", "bind", "bind", "reset", "help", "move", "lock" }) do
	SlashCmdList["ABARS"](cmd)
end
ok(ns.p.locked and not ns.bindMode, "slash commands")
ACoreMinimapButton.__scripts.OnClick(ACoreMinimapButton, "LeftButton")
ok(protected == 0, "no protected calls in combat at end")

print_real(string.format("ok: %d checks, %d buttons, %d menus", M.checks(), #ns.buttons, menus))
