local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

local clock = 100
function GetTime() return clock end
local SECRET = { secret = true }
function issecretvalue(v) return type(v) == "table" and v.secret == true end

function M.methods:SetValue(v) self.__value = v end
function M.methods:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function M.methods:SetFormattedText(f, ...) self.__text = string.format(f, ...) end
function M.methods:SetStatusBarColor(r, g, b, a) self.__color = { r, g, b, a } end

local speeds = { main = 2, off = 1.5, ranged = 3, target = 2.4 }
local hasTarget = true
function UnitAttackSpeed(unit)
	if unit == "target" then return speeds.target end
	return speeds.main, speeds.off
end
function UnitRangedDamage() return speeds.ranged, 10, 20 end
function UnitGUID(unit) return unit == "player" and "P" or "T" end
function UnitExists(unit) return unit ~= "target" or hasTarget end
C_Spell.GetSpellName = function(id)
	local names = { [78] = "Heroic Strike", [11567] = "Heroic Strike", [75] = "Auto Shot", [5019] = "Shoot", [845] = "Cleave", [133] = "Fireball" }
	return names[id]
end
local logEntry
function CombatLogGetCurrentEventInfo() return unpack(logEntry, 1, 24) end

M.load("ACore", "ACore")
local ns = M.load("ASwing", "ASwing")
event("PLAYER_LOGIN")

ns.db.target = true
local frame = ASwingFrame
local ticker = frame.ticker
local sw = ns.swings
local function tick(dt)
	clock = clock + (dt or 0)
	ticker.__scripts.OnUpdate(ticker, dt or 0)
end
local function left(hand)
	local s = sw[hand]
	return s and (s.start + s.dur - clock)
end
local function near(a, b) return a and math.abs(a - b) < 0.001 end
local function log(...)
	logEntry = { ... }
	event("COMBAT_LOG_EVENT_UNFILTERED")
end
local function swing(src, dst, offhand)
	log(clock, "SWING_DAMAGE", false, src, "a", 0, 0, dst, "b", 0, 0, 50, 0, 1, 0, 0, 0, false, false, false, offhand)
end
local function miss(src, dst, kind, offhand)
	log(clock, "SWING_MISSED", false, src, "a", 0, 0, dst, "b", 0, 0, kind, offhand)
end

ok(frame and not frame:IsShown(), "hidden out of combat")

event("PLAYER_REGEN_DISABLED")
event("PLAYER_ENTER_COMBAT")
ok(sw.main and sw.off and sw.main.est, "estimated swings start with auto attack")
ok(frame:IsShown() and ns.bars.main:IsShown() and ns.bars.off:IsShown() and not ns.bars.ranged:IsShown(), "bars shown")
tick(0.5)
ok(near(ns.bars.main.__value, 0.5) and ns.bars.main.right.__text == "1.5", "bar progress")
tick(1.6)
ok(near(left("main"), 1.9) and sw.main.est, "free running main hand restarts " .. tostring(left("main")))
ok(near(left("off"), 0.9), "free running off hand restarts")

tick(0.6)
event("UNIT_COMBAT", "target", "WOUND", "", 40, 1)
ok(near(left("main"), 1.3), "hit far from expected time ignored")
tick(1.2)
event("UNIT_COMBAT", "target", "WOUND", "", 40, 1)
ok(near(left("main"), 2) and not sw.main.est, "hit near expiry resyncs main hand")
event("UNIT_COMBAT", "target", "WOUND", "", 40, 8)
event("UNIT_COMBAT", "target", "HEAL", "", 40, 1)
event("UNIT_COMBAT", "target", SECRET, "", SECRET, SECRET)
ok(near(left("main"), 2), "non melee and secret hits ignored")

tick(0.5)
event("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
ok(near(left("main"), 0.7), "parry haste cuts 40% " .. tostring(left("main")))
ok(sw.target and near(left("target"), 2.4), "target swing from incoming hit")
event("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
ok(near(left("main"), 0.4), "parry haste stops at 20% " .. tostring(left("main")))
event("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
ok(near(left("main"), 0.4), "no haste below 20%")

ns.Start("main", false)
tick(1)
speeds.main = 1
event("UNIT_ATTACK_SPEED", "player")
ok(near(left("main"), 0.5) and sw.main.dur == 1, "haste rescales remaining time")
speeds.main = 2
event("UNIT_ATTACK_SPEED", "player")
ok(near(left("main"), 1), "slow rescales remaining time")
event("UNIT_ATTACK_SPEED", "target")
event("UNIT_ATTACK_SPEED", "party1")

event("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 11567)
ok(near(left("main"), 2) and not sw.main.est, "heroic strike rank resets main hand")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "g", SECRET)
event("UNIT_SPELLCAST_SUCCEEDED", "target", "g", 78)

event("UNIT_SPELLCAST_START", "player", "c", 133)
ok(not sw.main and not sw.off, "casting clears melee swings")
tick(1.5)
ok(not sw.main, "no free running while casting")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "c", 133)
ok(near(left("main"), 2) and near(left("off"), 1.5), "swings resume after the cast")
event("UNIT_SPELLCAST_START", "player", "c", 133)
event("UNIT_SPELLCAST_INTERRUPTED", "player", "c", 133)
event("UNIT_SPELLCAST_STOP", "player", "c", 133)
ok(near(left("main"), 2), "swings resume after an interrupt")

swing("P", "T", false)
ok(ns.LogActive() and not sw.main.est and near(left("main"), 2), "combat log main hand")
tick(0.4)
swing("P", "T", true)
ok(near(left("off"), 1.5) and near(left("main"), 1.6), "combat log off hand")
miss("P", "T", "DODGE", false)
ok(near(left("main"), 2), "combat log miss resets")
tick(1)
miss("T", "P", "PARRY")
ok(near(left("main"), 0.2) or near(left("main"), 0.4), "combat log parry haste " .. tostring(left("main")))
ok(near(left("target"), 2.4), "combat log target swing")
swing("X", "Y", false)
log(clock, SECRET, false, SECRET, SECRET, 0, 0, SECRET, SECRET, 0, 0, SECRET)
log(clock, "SPELL_DAMAGE", false, "P", "a", 0, 0, "T", "b", 0, 0, 11567, "Heroic Strike", 1, 90)
ok(near(left("main"), 2), "combat log next melee spell")
local before = left("main")
event("UNIT_COMBAT", "target", "WOUND", "", 40, 1)
ok(left("main") == before, "hints ignored while the combat log works")
tick(2.5)
ok(sw.main and ns.bars.main:IsShown(), "bar waits for the log event")
tick(1.2)
ok(not sw.main, "bar clears when no swing follows")
ns.state.logSeen = 0

event("PLAYER_LEAVE_COMBAT")
ns.Start("main", true)
tick(2.1)
ok(not sw.main, "no restart when not attacking")

event("START_AUTOREPEAT_SPELL")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "s", 75)
ok(near(left("ranged"), 3) and ns.bars.ranged:IsShown(), "auto shot starts ranged bar")
tick(1.5)
speeds.ranged = 1.5
event("UNIT_RANGEDDAMAGE", "player")
ok(near(left("ranged"), 0.75), "ranged haste rescales")
speeds.ranged = 3
event("UNIT_SPELLCAST_SUCCEEDED", "player", "s", 5019)
ok(near(left("ranged"), 3), "wand shot")
event("PLAYER_EQUIPMENT_CHANGED")
ok(sw.ranged.est, "equipment change restarts ranged")
tick(3.1)
ok(not sw.ranged, "ranged bar clears")
event("STOP_AUTOREPEAT_SPELL")

hasTarget = false
ns.Stop("target")
event("UNIT_COMBAT", "player", "WOUND", "", 30, 1)
ok(not sw.target, "no target swing without a target")
hasTarget = true
ns.db.target = false
event("UNIT_COMBAT", "player", "WOUND", "", 30, 1)
ok(not sw.target, "target bar off")
ns.db.target = true
event("UNIT_COMBAT", "player", "WOUND", "", 30, 1)
ok(sw.target, "target bar on")
event("PLAYER_TARGET_CHANGED")
ok(not sw.target, "target change clears target swing")

local real = speeds.main
speeds.main = SECRET
ns.Start("main", false)
ok(not sw.main, "secret attack speed is not used")
speeds.main = 0
ns.Start("main", false)
ok(not sw.main, "zero speed ignored")
speeds.main = real
speeds.off = nil
event("PLAYER_ENTER_COMBAT")
ok(sw.main and not sw.off, "no off hand bar without an off hand")
event("PLAYER_LEAVE_COMBAT")
tick(3)

event("PLAYER_REGEN_ENABLED")
ns.Start("main", false)
ok(not frame:IsShown(), "hidden out of combat with a running swing")
ns.db.hideOOC = false
ns.Apply()
ok(frame:IsShown(), "shown out of combat when asked")
ns.db.hideOOC = true
tick(3)
ok(not frame:IsShown(), "hidden when idle")

SlashCmdList["ASWING"]("unlock")
ok(frame:IsShown() and ns.bars.main:IsShown() and ns.bars.target:IsShown(), "unlock shows placeholders")
frame.__scripts.OnDragStart(frame)
frame.__scripts.OnDragStop(frame)
ok(ns.db.pos, "position saved")
SlashCmdList["ASWING"]("lock")
ok(not frame:IsShown(), "lock hides")
SlashCmdList["ASWING"]("test")
ok(frame:IsShown() and sw.main and sw.ranged, "test swings")
tick(1)
tick(3.5)
ok(not frame:IsShown() and not ns.Active(), "test ends")
SlashCmdList["ASWING"]("reset")
ok(ns.db.pos == nil, "reset")
ns.db.main = false
ns.db.time = false
ns.db.height = 6
ns.Apply()
ns.Start("main", false)
ok(not sw.main, "disabled hand never starts")
event("PLAYER_REGEN_DISABLED")
ns.Start("off", false)
speeds.off = 1.5
ns.Start("off", false)
tick(0.5)
ok(ns.bars.off.right.__text == "" and ns.bars.off.left.__text == "", "compact bar without text")
SlashCmdList["ASWING"]("")
for _, a in ipairs(ACore.addons) do if a.name == "ASwing" then a.toggle() end end
flush()

print_real(string.format("ok: %d checks (aswing)", M.checks()))
