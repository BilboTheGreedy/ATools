local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

local now = 1000
function GetTime() return now end
local combat = false
function InCombatLockdown() return combat end
local secrets = {}
local function secret()
	local s = {}
	secrets[s] = true
	return s
end
function issecretvalue(v) return secrets[v] or false end

local helpful = {
	{ name = "Battle Shout", icon = 1, applications = 0, duration = 120, expirationTime = 1100, spellId = 6673, auraInstanceID = 1 },
	{ name = "Mount", icon = 2, applications = 0, duration = 0, expirationTime = 0, spellId = 5, auraInstanceID = 2 },
	{ name = "Stacks", icon = 3, applications = 4, duration = 30, expirationTime = 1004, spellId = 6, auraInstanceID = 3 },
}
local harmful = {
	{ name = "Poisoned", icon = 4, applications = 2, duration = 12, expirationTime = 1008, dispelName = "Poison", spellId = 7, auraInstanceID = 4 },
	{ name = "Bleed", icon = 5, applications = 0, duration = 12, expirationTime = 1009, spellId = 8, auraInstanceID = 5 },
}
local durationCalls, objectSets, cancelled, enchantCancelled = 0, 0, nil, nil
C_UnitAuras = {
	GetAuraDataByIndex = function(_, i, filter)
		local l = filter == "HELPFUL" and helpful or harmful
		return l[i]
	end,
	GetAuraDuration = function() durationCalls = durationCalls + 1 return { duration = true } end,
	GetAuraApplicationDisplayCount = function() return "3" end,
}
M.methods.SetCooldownFromDurationObject = function() objectSets = objectSets + 1 end
local enchant = { true, 600000, 0, 1, false, 0, 0, 0 }
function GetWeaponEnchantInfo() return unpack(enchant) end
function GetInventoryItemTexture() return 99 end
function GetInventoryItemID() return 1234 end
function CancelUnitBuff(_, index) cancelled = index end
function CancelItemTempEnchantment(slot) enchantCancelled = slot end
function UnitIsDeadOrGhost() return false end
local names = { [6673] = "Battle Shout", [19705] = "Well Fed" }
C_Spell.GetSpellName = function(id) return names[id] or ("Spell " .. id) end
C_SpellBook = { IsSpellKnownOrInSpellBook = function() return true end }
BuffFrame = M.obj("Frame")
local reparented = 0
function BuffFrame:SetParent() reparented = reparented + 1 end

M.load("ACore", "ACore")
local ns = M.load("ABuffs", "ABuffs")
event("PLAYER_LOGIN")
flush()

ok(reparented == 1, "blizzard frame hidden")
local g = ns.groups
ok(g.buffs.shown == 3 and g.debuffs.shown == 2 and g.enchants.shown == 1, "group counts")
ok(g.buffs.icons[1].aura.name == "Mount", "permanent first")
ok(g.buffs.icons[2].aura.name == "Battle Shout" and g.buffs.icons[3].aura.name == "Stacks", "sorted by time left")
ok(g.buffs.icons[3].count.__text == 4, "stack count")
ok(g.buffs.icons[2].time.__text == "2m", "timer text " .. tostring(g.buffs.icons[2].time.__text))
ok(g.buffs.icons[3].time.__text == "4", "seconds text")
ok(ns.TimeText(7200) == "2h" and ns.TimeText(59) == "59", "time format")

for _, grp in pairs(g) do
	for i = 1, grp.shown do
		local f = grp.icons[i]
		f.__scripts.OnEnter(f)
		f.__scripts.OnLeave(f)
	end
end
local shout = g.buffs.icons[2]
shout.__scripts.OnClick(shout, "LeftButton")
ok(cancelled == nil, "left click does not cancel")
shout.__scripts.OnClick(shout, "RightButton")
ok(cancelled == 1, "right click cancels")
local ench = g.enchants.icons[1]
ench.__scripts.OnClick(ench, "RightButton")
ok(enchantCancelled == 1, "enchant cancel")
combat = true
cancelled = nil
shout.__scripts.OnClick(shout, "RightButton")
ok(cancelled == nil, "no cancel in combat")
combat = false

for _, f in ipairs(M.frames) do
	local fn = f.__scripts.OnUpdate
	if fn then fn(f, 0.2) fn(f, 1) end
end
now = 1002
for _, f in ipairs(M.frames) do
	local fn = f.__scripts.OnUpdate
	if fn then fn(f, 0.2) end
end
ok(g.buffs.icons[3].time.__text == "2", "tick updates")

local missing = ns.Missing()
local keys = {}
for _, m in ipairs(missing) do keys[m.entry.key] = true end
ok(not keys.shout and keys.food and not keys.stone, "reminders: shout present, food missing, weapon enchanted")
table.remove(helpful, 1)
enchant[1] = false
event("UNIT_AURA", "player")
flush()
keys = {}
for _, m in ipairs(ns.Missing()) do keys[m.entry.key] = true end
ok(keys.shout and keys.stone, "reminders: shout and stone missing")
ok(g.reminders.shown == 3, "reminder icons " .. g.reminders.shown)
local r = g.reminders.icons[1]
r.__scripts.OnEnter(r)
r.__scripts.OnLeave(r)
r.__scripts.OnClick(r, "RightButton")
flush()
ok(g.reminders.shown == 2, "reminder dismissed")

combat = true
event("PLAYER_REGEN_DISABLED")
flush()
ok(#ns.Missing() == 0 and g.reminders.shown == 0, "no reminders in combat")
helpful[1] = { name = secret(), icon = secret(), applications = secret(), duration = secret(), expirationTime = secret(), spellId = secret(), auraInstanceID = 9 }
harmful[1] = { name = secret(), icon = secret(), applications = secret(), duration = secret(), expirationTime = secret(), dispelName = secret(), spellId = secret(), auraInstanceID = 10 }
event("UNIT_AURA", "player")
event("UNIT_AURA", "target")
flush()
ok(g.buffs.shown == 2 and g.buffs.icons[1].aura.secret, "secret aura kept in game order")
ok(durationCalls >= 2 and objectSets >= 2, "secret auras use duration objects")
ok(g.buffs.icons[1].count.__text == "3", "secret stack text")
for _, f in ipairs(M.frames) do
	local fn = f.__scripts.OnUpdate
	if fn then fn(f, 0.2) end
end
for i = 1, g.buffs.shown do
	local f = g.buffs.icons[i]
	f.__scripts.OnEnter(f)
end

ns.db.hideBlizzard = false
ns.db.hideBlizzard = true
ns.HideBlizzard()
ok(reparented == 2 or reparented == 1, "hide deferred in combat")
local before = reparented
combat = false
event("PLAYER_REGEN_ENABLED")
flush()
ok(reparented == before + 1, "hide applied after combat")

SlashCmdList["ABUFFS"]("unlock")
ok(g.buffs.handle:IsShown() and not ns.db.groups.buffs.locked, "unlocked")
local h = g.buffs.handle
h.__scripts.OnDragStart(h)
h.__scripts.OnDragStop(h)
h.__scripts.OnClick(h, "RightButton")
ok(ns.db.groups.buffs.pos, "position saved")
SlashCmdList["ABUFFS"]("lock")
ok(not g.buffs.handle:IsShown(), "locked")
SlashCmdList["ABUFFS"]("reset")
ok(ns.db.groups.buffs.pos == nil, "reset")
SlashCmdList["ABUFFS"]("")
for _, e in ipairs(ns.Options()) do
	if e.func then e.func() end
end
flush()
ns.db.growLeft = false
ns.db.sort = false
ns:Fire("OPTIONS")
event("UNIT_INVENTORY_CHANGED", "player")
event("PLAYER_ENTERING_WORLD")
event("PLAYER_EQUIPMENT_CHANGED")
event("SPELLS_CHANGED")
flush()
for _, class in ipairs({ "WARRIOR", "DRUID", "MAGE", "PRIEST", "WARLOCK", "PALADIN", "HUNTER", "SHAMAN", "ROGUE" }) do
	ns.playerClass = class
	ns.db.off = {}
	ok(#ns.ReminderList() >= 2, "list " .. class)
	ns.Missing()
	ns.RefreshReminders()
	ns.ReminderEntries()
end
C_UnitAuras.GetAuraDataByIndex = nil
C_UnitAuras = nil
function UnitAura(_, i, filter)
	if filter == "HELPFUL" and i == 1 then return "Old", 1, 2, nil, 10, now + 5, nil, nil, nil, 77 end
end
ns.Refresh()
ok(g.buffs.shown == 1 and g.buffs.icons[1].aura.name == "Old", "legacy aura api")
for _, a in ipairs(ACore.addons) do
	if a.name == "ABuffs" then a.toggle() end
end

print_real(string.format("ok: %d checks (abuffs)", M.checks()))
