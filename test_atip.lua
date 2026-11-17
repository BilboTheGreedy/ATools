local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

function M.methods:HookScript(name, fn)
	self.__hooks = self.__hooks or {}
	self.__hooks[name] = self.__hooks[name] or {}
	table.insert(self.__hooks[name], fn)
end
local function hook(frame, name, ...)
	for _, fn in ipairs(frame.__hooks and frame.__hooks[name] or {}) do fn(frame, ...) end
end

local secure = {}
function hooksecurefunc(a, b, c)
	if type(a) == "string" then secure[a] = b else secure[b] = c end
end
local health = { 1500, 3000 }
function UnitHealth() return health[1] end
function UnitHealthMax() return health[2] end
local auras = {}
C_UnitAuras = {
	GetAuraDataByIndex = function(unit, index, filter) return auras[filter .. index] end,
	GetAuraDataByAuraInstanceID = function(unit, id) return auras[id] end,
}
function SharedTooltip_SetBackdropStyle() end
function GameTooltip_SetDefaultAnchor() end
local post = {}
Enum = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) post[kind] = fn end }
LEVEL = "Level"
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }

local SECRET = {}
function issecretvalue(v) return v == SECRET end

local units = {}
local function field(name)
	return function(unit, ...)
		local u = units[unit]
		if not u then return nil end
		local v = u[name]
		if type(v) == "function" then return v(unit, ...) end
		if type(v) == "table" and v.multi then return unpack(v) end
		return v
	end
end
UnitExists = field("exists")
UnitIsPlayer = field("player")
UnitClass = field("class")
UnitRace = field("race")
UnitLevel = field("level")
UnitName = field("name")
UnitReaction = field("reaction")
UnitClassification = field("classification")
UnitIsTapDenied = field("tapped")
GetGuildInfo = field("guild")
UnitIsUnit = function(a, b) return units[a] and units[a].same == b end
GetCreatureDifficultyColor = function() return { r = 1, g = 1, b = 0 } end
local combat = false
function InCombatLockdown() return combat end
TooltipUtil = {
	GetDisplayedUnit = function(tip) return "name", tip.__unit end,
	GetDisplayedItem = function(tip) return "name", tip.__link end,
}

local function makeTip(name)
	local tip = M.obj("GameTooltip")
	_G[name] = tip
	tip.NineSlice = M.obj("Frame")
	tip.GetName = function() return name end
	tip.__lines = {}
	tip.__added = {}
	tip.NumLines = function(self) return #self.__lines end
	tip.AddLine = function(self, text) self.__added[#self.__added + 1] = text end
	tip.SetOwner = function(self, parent, how) self.__anchor = how end
	function tip:set(lines)
		self.__lines = lines
		self.__added = {}
		for i, text in ipairs(lines) do
			local line = M.obj("FontString")
			line.__text = text
			line.SetTextColor = function(l, r, g, b) l.__color = { r, g, b } end
			_G[name .. "TextLeft" .. i] = line
		end
	end
	return tip
end
makeTip("GameTooltip")
makeTip("ItemRefTooltip")
makeTip("ShoppingTooltip1")
GameTooltipStatusBar = M.obj("StatusBar")
GameTooltipStatusBar.SetStatusBarColor = function(self, r, g, b) self.__color = { r, g, b } end

C_Item.GetItemInfo = function(what)
	if what == 5 then return nil end
	return "Thing", "link", 4, 66, 60, "Armor", "Plate", 1, "INVTYPE_HEAD", 1
end

M.load("ACore", "ACore")
local ns = M.load("ATip", "ATip")
event("PLAYER_LOGIN")
ok(ns.db and ns.db.style, "db ready")
ok(ns.tips[GameTooltip] and ns.tips[ItemRefTooltip], "tips styled")
ok(post[0] and post[1] and post[2], "post calls registered")
ok(secure.SharedTooltip_SetBackdropStyle and secure.GameTooltip_SetDefaultAnchor, "secure hooks")
secure.SharedTooltip_SetBackdropStyle(GameTooltip)
hook(GameTooltip, "OnShow")
hook(GameTooltip, "OnTooltipCleared")

units.mouseover = {
	exists = true, player = true, class = { multi = true, "Mage", "MAGE" }, race = "Gnome", level = 42,
	name = "Fizz", guild = "Tinkers", reaction = 5,
}
units.player = { exists = true, guild = "Tinkers", name = "Me" }
units.mouseovertarget = { exists = true, player = false, name = "Boar", reaction = 2 }
GameTooltip.__unit = "mouseover"
GameTooltip:set({ "Fizz", "Tinkers", "Level 42 Gnome Mage (Player)" })
post[2](GameTooltip)
ok(GameTooltipTextLeft1.__color[1] == 0.25, "class coloured name")
ok(GameTooltipTextLeft2.__text == "<Tinkers>" and GameTooltipTextLeft2.__color[1] == 0.4, "own guild line")
ok(GameTooltipTextLeft3.__text:find("Gnome") and GameTooltipTextLeft3.__text:find("Mage|r"), "level line " .. GameTooltipTextLeft3.__text)
ok(GameTooltip.__added[1] and GameTooltip.__added[1]:find("Boar"), "target line")
ok(GameTooltipStatusBar.__color[1] == 0.25, "bar colour")
ok(ns.hpText == nil, "health text off by default")
ns.db.healthText = true
ns.HealthText("mouseover")
ok(ns.hpText and ns.hpText.__text == "1500 / 3000  50%", "health text " .. tostring(ns.hpText and ns.hpText.__text))
ns.db.healthText = false
ns.HealthText("mouseover")
ok(ns.hpText.__text == "", "health text off")
ns.db.healthText = true

units.player.guild = "Other"
units.mouseovertarget.same = "player"
units.mouseover.level = -1
GameTooltip:set({ "Fizz", "Tinkers", "Level ?? Gnome Mage (Player)" })
post[2](GameTooltip)
ok(GameTooltipTextLeft2.__color[1] == 0.3, "other guild colour")
ok(GameTooltip.__added[1]:find("You"), "targeting you")
ok(GameTooltipTextLeft3.__text:find("??", 1, true), "unknown level")

units.mouseovertarget = { exists = true, player = true, name = "Pal", class = { multi = true, "Mage", "MAGE" } }
units.mouseover.guild = nil
GameTooltip:set({ "Fizz", "Level 42 Gnome Mage (Player)" })
post[2](GameTooltip)
ok(GameTooltip.__added[1]:find("Pal"), "player target")

for _, reaction in ipairs({ 2, 4, 6 }) do
	units.mouseover = { exists = true, player = false, name = "Wolf", level = 20, reaction = reaction, classification = "elite" }
	units.mouseovertarget = nil
	GameTooltip:set({ "Wolf", "Level 20 Beast" })
	post[2](GameTooltip)
	ok(GameTooltipTextLeft2.__text:find("Elite"), "elite tag")
	ok(GameTooltipTextLeft1.__color, "npc colour " .. reaction)
end
units.mouseover.tapped = true
units.mouseover.reaction = nil
GameTooltip:set({ "Wolf", "Level 20 Beast" })
post[2](GameTooltip)
ok(GameTooltipTextLeft1.__color[1] == 0.55, "tapped colour")
units.mouseover.tapped = false
GameTooltip:set({ "Wolf", "Level 20 Beast" })
post[2](GameTooltip)

units.mouseover = { exists = true, player = SECRET, name = SECRET, level = SECRET, reaction = SECRET, class = SECRET, guild = SECRET }
units.mouseovertarget = { exists = true, name = SECRET }
GameTooltip:set({ SECRET, SECRET })
post[2](GameTooltip)
ok(#GameTooltip.__added == 0, "secret values are left alone")
ok(GameTooltipTextLeft2 and GameTooltipTextLeft2.__text == SECRET, "secret level line untouched")
health[1] = SECRET
local formatted
function ns.hpText:SetFormattedText(fmt, a, b) formatted = { fmt, a, b } end
ns.HealthText("mouseover")
ok(formatted and formatted[2] == SECRET and formatted[3] == 3000, "secret health goes straight to the text")
health[1] = 1500
ns.HealthText(nil)
ok(ns.hpText.__text == "", "no unit, no health text")

GameTooltip.__unit = nil
units.mouseover = nil
post[2](GameTooltip)
GameTooltip.__unit = SECRET
post[2](GameTooltip)
post[2](M.obj("GameTooltip"))

units.mouseover = { exists = true, player = true, class = { multi = true, "Mage", "MAGE" }, name = "Fizz", level = 10 }
GameTooltip.__unit = "mouseover"
hook(GameTooltipStatusBar, "OnValueChanged")
units.mouseover = { exists = true, player = false, reaction = 2 }
hook(GameTooltipStatusBar, "OnValueChanged")
ok(GameTooltipStatusBar.__color[1] == 0.9, "bar follows reaction")
units.mouseover = { exists = true, player = false, name = "Wolf", level = SECRET, reaction = 2 }
GameTooltip:set({ "Wolf", "Level 20 Beast" })
post[2](GameTooltip)
ok(GameTooltipTextLeft2.__text == "Level 20 Beast" and GameTooltipTextLeft2.__color == nil, "hidden level leaves the line alone")

combat = true
ns.db.combatHide = true
post[2](GameTooltip)
ok(not GameTooltip:IsShown(), "hidden in combat")
combat = false
ns.db.combatHide = false
GameTooltip:Show()

GameTooltip.__link = "|Hitem:18816::|h[Thing]|h"
ns.db.itemID = true
GameTooltip:set({ "Thing" })
post[0](GameTooltip, { id = 18816 })
ok(GameTooltip.__added[1] == "Item level 66" and GameTooltip.__added[2] == "Item ID 18816", "item lines")
GameTooltip:set({ "Thing" })
post[0](GameTooltip, { id = SECRET })
ok(GameTooltip.__added[2] == "Item ID 18816", "item id from link")
GameTooltip.__link = nil
GameTooltip:set({ "Thing" })
post[0](GameTooltip, {})
ok(#GameTooltip.__added == 0, "no item, no lines")
post[0](ItemRefTooltip, { id = 5 })
ok(ItemRefTooltip.__added[1] == "In bags 5" and ItemRefTooltip.__added[2] == "Item ID 5", "uncached item still shows count and id")
C_Item.GetItemCount = function(id, bank) return bank and 17 or 5 end
ItemRefTooltip:set({})
post[0](ItemRefTooltip, { id = 5 })
ok(ItemRefTooltip.__added[1] == "In bags 5, bank 12", "bank count " .. tostring(ItemRefTooltip.__added[1]))
C_Item.GetItemCount = function() return SECRET end
ItemRefTooltip:set({})
post[0](ItemRefTooltip, { id = 5 })
ok(ItemRefTooltip.__added[1] == "Item ID 5", "secret count skipped")
ns.db.itemCount = false
ns.db.itemID = false
ns.db.itemLevel = false
ItemRefTooltip:set({})
post[0](ItemRefTooltip, { id = 5 })
ok(#ItemRefTooltip.__added == 0, "item lines off")

GameTooltip:set({ "Spell" })
post[1](GameTooltip, { id = 133 })
ok(#GameTooltip.__added == 0, "spell id off")
ns.db.spellID = true
post[1](GameTooltip, { id = 133 })
ok(GameTooltip.__added[1] == "Spell ID 133", "spell id on")
post[1](GameTooltip, { id = SECRET })

ok(secure.SetUnitAura and secure.SetUnitBuffByAuraInstanceID, "aura hooks")
units.party1 = { exists = true, player = true, name = "Healer", class = { multi = true, "Mage", "MAGE" } }
auras.HELPFUL3 = { sourceUnit = "party1", spellId = 774 }
auras[77] = { sourceUnit = SECRET, spellId = SECRET }
GameTooltip:set({ "Renew" })
secure.SetUnitAura(GameTooltip, "player", 3, "HELPFUL")
ok(GameTooltip.__added[1]:find("From ") and GameTooltip.__added[1]:find("Healer") and GameTooltip.__added[2] == "Spell ID 774", "aura source " .. tostring(GameTooltip.__added[1]))
GameTooltip:set({ "Renew" })
secure.SetUnitBuff(GameTooltip, "player", 3)
ok(#GameTooltip.__added == 2, "buff by index")
GameTooltip:set({ "Renew" })
secure.SetUnitBuffByAuraInstanceID(GameTooltip, "player", 77)
secure.SetUnitDebuff(GameTooltip, "player", 9)
secure.SetUnitAura(GameTooltip, SECRET, SECRET, SECRET)
ok(#GameTooltip.__added == 0, "secret or missing aura adds nothing")
ns.db.auraSource = false
ns.db.spellID = false
secure.SetUnitAura(GameTooltip, "player", 3, "HELPFUL")
ok(#GameTooltip.__added == 0, "aura lines off")
ns.db.auraSource = true

secure.GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
ok(GameTooltip.__anchor == nil, "default anchor untouched")
ns.db.anchor = "cursor"
secure.GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
ok(GameTooltip.__anchor == "ANCHOR_CURSOR", "cursor anchor")
ns.db.anchor = "cursorRight"
secure.GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
ok(GameTooltip.__anchor == "ANCHOR_CURSOR_RIGHT", "cursor right anchor")
ns.db.anchor = "fixed"
secure.GameTooltip_SetDefaultAnchor(GameTooltip)
ok(GameTooltip.__anchor == "ANCHOR_NONE" and ATipAnchor, "fixed anchor")
ATipAnchor.__scripts.OnDragStart(ATipAnchor)
ATipAnchor.__scripts.OnDragStop(ATipAnchor)
ok(ns.db.mover.pos, "anchor position saved")

SlashCmdList["ATIP"]("anchor")
ok(ns.MoverShown(), "mover shown")
SlashCmdList["ATIP"]("")
SlashCmdList["ATIP"]("anchor")
ok(not ns.MoverShown(), "mover hidden")
SlashCmdList["ATIP"]("reset")
ok(ns.db.anchor == "default" and not ns.db.mover.pos, "reset")

ns.OpenOptions()
ns.OpenOptions(UIParent)
for _, key in ipairs({ "style", "healthBar" }) do
	ns.db[key] = false
	ns:Fire("CHANGED")
	ns.db[key] = true
	ns:Fire("CHANGED")
end
ns.db.style = false
ns.SetBorder(GameTooltip, 1, 1, 1)
ns.db.style = true
local found
for _, a in ipairs(ACore.addons) do if a.name == "ATip" then found = a end end
ok(found and type(found.options) == "function", "registered with the launcher")
local n = 0
for _, e in ipairs(found.options()) do
	if e.func then e.func() n = n + 1 end
end
ok(n >= 25, "control panel options " .. n)
found.toggle()
flush()

print_real(string.format("ok: %d checks", M.checks()))
