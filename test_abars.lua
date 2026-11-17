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

local clock = 50
function GetTime() return clock end
local cursor
function GetCursorInfo() return cursor end
C_ActionBar = {
	GetOverrideBarIndex = function() return 18 end,
	GetVehicleBarIndex = function() return 16 end,
	GetTempShapeshiftBarIndex = function() return 17 end,
}
local petPicked
function PickupPetAction(i) petPicked = i end
function GetActionInfo(slot) if slot == 1 then return "spell", 777 end end
local parents = setmetatable({}, { __mode = "k" })
local baseParent = M.methods.SetParent
function M.methods:SetParent(parent)
	parents[self] = parent
	return baseParent(self, parent)
end
function M.methods:GetParent() return parents[self] or self.__parent end
function M.methods:GetFont() return "Fonts\\FRIZQT__.TTF", 10, "" end
local fonts = setmetatable({}, { __mode = "k" })
function M.methods:SetFont(_, size) fonts[self] = size end
MicroMenuContainer = M.obj("Frame")
BagsBar = M.obj("Frame")
MainMenuBar = M.obj("Frame")
MultiBarBottomLeft = M.obj("Frame")
StanceBar = M.obj("Frame")
PetActionBar = M.obj("Frame")
for i = 1, 12 do _G["ActionButton" .. i] = M.obj("Button") end

M.load("ACore", "ACore")
ABarsDB = { profiles = {
	["Other - Realm"] = { locked = true, hideBlizzard = false, bars = { bar1 = { count = 6, cols = 3, size = 44, enabled = true, default = { "TOP", "TOP", 1, 1 } } } },
} }
local ns = M.load("ABars", "ABars")
event("PLAYER_LOGIN")
flush()

ok(ns.p and ns.p.bars.bar1.count == 12 and ns.charKey == "Default", "profile created")
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
ok(ns.p.bars.bar1.default[1] == "BOTTOM", "stale default position replaced")
ok(ns.p.hideBlizzard == nil and ns.p.blizzard.main == false and ns.p.blizzard.pet == false, "old hide flag migrated")
ok(ABarsDB.profiles["Default"] == ns.p and ABarsDB.profiles["Other - Realm"].bars.bar1 ~= ns.p.bars.bar1, "profiles stay separate")
ok(ns.bars.bar1.count == 6 and not ABarsBar1Button7.active, "copied layout applied")
ns.ResetProfile()
ok(ns.p.bars.bar1.count == 12 and ABarsBar1Button12.active, "reset profile")

for _, cmd in ipairs({ "", "unlock", "lock", "bind", "bind", "reset", "help", "move", "lock" }) do
	SlashCmdList["ABARS"](cmd)
end
ok(ns.p.locked and not ns.bindMode, "slash commands")
ok(drivers[ABarsBar1].page:find("^%[overridebar%]18;%[vehicleui%]%[possessbar%]16;%[shapeshift%]17;"), "override paging " .. drivers[ABarsBar1].page)
ok(b1:GetAttribute("checkselfcast") == true, "self cast attribute")

autocast = nil
pet2.__scripts.PostClick(pet2, "RightButton", true)
ok(autocast == nil, "autocast not toggled on key down")
pet2.__scripts.PostClick(pet2, "RightButton", false)
ok(autocast == 2, "autocast toggled on release")
pet2.__scripts.OnDragStart(pet2)
ok(petPicked == nil, "pet drag needs the modifier")
pet2.__scripts.OnReceiveDrag(pet2)
ok(petPicked == 2, "pet drop")

placed = nil
cursor = "spell"
local b8 = ABarsBar1Button8
b8.__scripts.PreClick(b8, "LeftButton", true)
ok(b8:GetAttribute("type") == "empty", "click with a held spell does not use the button")
b8.__scripts.PostClick(b8, "LeftButton", true)
ok(placed == 8 and b8:GetAttribute("type") == "action", "click drops the held spell")
placed = nil
b8.__scripts.PreClick(b8, "LeftButton", false)
ok(b8:GetAttribute("type") == "empty", "release after a drop is swallowed")
b8.__scripts.PostClick(b8, "LeftButton", false)
ok(placed == nil and b8:GetAttribute("type") == "action", "release after a drop does not place again")
b8.__scripts.OnReceiveDrag(b8)
ok(placed == nil, "release after a click drop is not a second drop")
clock = clock + 1
b8.__scripts.OnReceiveDrag(b8)
ok(placed == 8, "later drag drop still places")
placed = nil
b8.__scripts.PreClick(b8, "LeftButton", true)
b8.__scripts.PostClick(b8, "LeftButton", true)
ok(placed == 8, "drop on press")
placed = nil
b8.__scripts.OnReceiveDrag(b8)
ok(placed == nil, "release before the click ends is not a second drop")
b8.__scripts.PreClick(b8, "LeftButton", false)
b8.__scripts.PostClick(b8, "LeftButton", false)
clock = clock + 1
cursor = nil
b8.__scripts.PreClick(b8, "LeftButton", true)
ok(b8:GetAttribute("type") == "action", "normal click keeps the action type")
b8.__scripts.PostClick(b8, "LeftButton", true)
over[b8] = true
M.mods.shift = true
b8.__scripts.PreClick(b8, "LeftButton", true)
ok(b8:GetAttribute("useOnKeyDown") == false, "pickup key press does not cast on mouse down")
b8.__scripts.PostClick(b8, "LeftButton", true)
ok(b8:GetAttribute("useOnKeyDown") == false, "still held until release")
picked = nil
b8.__scripts.OnDragStart(b8)
ok(picked == 8 and b8:GetAttribute("useOnKeyDown") == nil, "drag restores key down casting")
b8.__scripts.PreClick(b8, "Keybind", true)
ok(b8:GetAttribute("useOnKeyDown") == nil, "key presses keep casting on key down")
b8.__scripts.PostClick(b8, "Keybind", true)
b8.__scripts.PreClick(b8, "LeftButton", true)
b8.__scripts.PostClick(b8, "LeftButton", true)
b8.__scripts.PreClick(b8, "LeftButton", false)
b8.__scripts.PostClick(b8, "LeftButton", false)
ok(b8:GetAttribute("useOnKeyDown") == nil, "release restores key down casting")
M.mods.shift = false
over[b8] = nil
flush()

actions[9] = { texture = SECRET, usable = true }
ns.Button.UpdateAll("action")
ok(ABarsBar1Button9.has, "secret texture counts as an action")
actions[9] = nil

local durations = 0
function M.methods:SetCooldownFromDurationObject(d) if d == "dur" then durations = durations + 1 end end
C_ActionBar.GetActionCooldownDuration = function() return "dur" end
C_ActionBar.GetActionDisplayCount = function(slot) if slot == 3 then return "7" end return SECRET end
ns.Button.UpdateAll("action")
ok(durations > 0, "cooldowns use duration objects")
ok(ABarsBar1Button3.count:GetText() == "7" and b1.count:GetText() == SECRET, "display count passed through")
C_ActionBar.GetActionCooldownDuration = nil
C_ActionBar.GetActionDisplayCount = nil
ns.Button.UpdateAll("action")

event("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 777)
ok(b1.lit and not ABarsBar1Button2.lit, "proc highlight")
event("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", SECRET)
event("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 777)
ok(not b1.lit, "proc highlight ends")

ns.p.textSize = 14
ns.p.bars.bar3.clickThrough = true
ns.LayoutAll()
ok(fonts[b1.hotkey] == 14, "text size applied")
ns.p.textSize = 0
ns.LayoutAll()
ok(fonts[b1.hotkey] == 10, "text size back to default")

local mover
for _, m in ipairs(ACore.movers) do
	if m.frame == ABarsBar2 then mover = m end
end
ok(mover and mover.db == ns.p.bars.bar2 and mover.label == "ABars Bar 2", "bar registered with layout mode")
ok(rawget(ABarsBar2, "Restore"), "bar restores from layout mode")
ok(ns.SetLocked(false), "unlock before layout mode")
ok(ACore.LayoutMode(true) and ns.p.locked and not ns.handles.bar2:IsShown(), "layout mode replaces the drag handles")
ACore.ScaleMover(mover, 1.5)
ok(ns.p.bars.bar2.scale == 1.5 and ns.p.bars.bar2.pos[1] == "CENTER", "layout mode resizes the bar")
ACore.ResetMover(mover)
ok(ns.p.bars.bar2.pos == nil and ns.p.bars.bar2.scale == 1, "layout mode reset")
ok(ns.SetLocked(false) and not ACore.LayoutActive(), "unlocking leaves layout mode")
ns.SetLocked(true)

ok(parents[MainMenuBar] == ABarsHidden and parents[PetActionBar] == ABarsHidden, "default bars parked")
ok(parents[MicroMenuContainer] ~= ABarsHidden and parents[BagsBar] ~= ABarsHidden, "micro menu and bags left alone")
ns.p.blizzard.micro = true
ns.p.blizzard.bags = true
ns.HideBlizzard()
ok(parents[MicroMenuContainer] == ABarsHidden and parents[BagsBar] == ABarsHidden, "micro menu and bags hidden")
ns.p.blizzard.micro = false
ns.p.blizzard.main = false
local okHide, reload = ns.HideBlizzard()
ok(okHide and reload and parents[MicroMenuContainer] ~= ABarsHidden and parents[MainMenuBar] == ABarsHidden, "micro menu comes back, main bar needs a reload")
ns.BlizzardMenu()

local registered
for _, a in ipairs(ACore.addons) do
	if a.name == "ABars" then registered = a end
end
local opts = registered.options()
ok(type(opts) == "table" and #opts > 15 and opts[1].title, "panel options " .. #opts)

ACoreMinimapButton.__scripts.OnClick(ACoreMinimapButton, "LeftButton")
ok(protected == 0, "no protected calls in combat at end")

print_real(string.format("ok: %d checks, %d buttons, %d menus", M.checks(), #ns.buttons, menus))
