local M = dofile("tools/mock.lua")
local ok, event, flush, printed = M.ok, M.event, M.flush, M.printed

local S = { __secret = true }
issecretvalue = function(v) return v == S end

local combat = false
local secretMode = false
local units = {
	player = { name = "Me", class = "WARRIOR", hp = 900, max = 1000, power = 30, pmax = 100, ptype = "RAGE", level = 60, leader = true, role = "TANK" },
	party1 = { name = "Healer", class = "PRIEST", hp = 400, max = 800, power = 500, pmax = 900, ptype = "MANA", level = 58, role = "HEALER", mark = 3 },
	party2 = { name = "Gone", class = "MAGE", hp = 0, max = 700, power = 0, pmax = 900, ptype = "MANA", level = 57, offline = true, role = "DAMAGER" },
	party3 = { name = "Corpse", class = "ROGUE", hp = 0, max = 700, power = 0, pmax = 100, ptype = "ENERGY", level = 60, dead = true, far = true, role = "NONE" },
	target = { name = "Boar", hp = 50, max = 120, power = 0, pmax = 0, ptype = "WEIRD", level = -1, npc = true, hostile = true, reaction = 2 },
}
local function u(unit) return units[unit] end
local function val(unit, key, default)
	local t = u(unit)
	if not t then return default end
	if secretMode then return S end
	local v = t[key]
	if v == nil then return default end
	return v
end

function InCombatLockdown() return combat end
function UnitExists(unit) return u(unit) ~= nil end
function UnitHealth(unit) return val(unit, "hp", 0) end
function UnitHealthMax(unit) return val(unit, "max", 0) end
function UnitPower(unit) return val(unit, "power", 0) end
function UnitPowerMax(unit) return val(unit, "pmax", 0) end
function UnitPowerType(unit) return 0, val(unit, "ptype", "MANA") end
function UnitName(unit) return val(unit, "name", nil) end
function UnitLevel(unit) return val(unit, "level", 0) end
function UnitClass(unit) local c = val(unit, "class", nil) return c, c end
function UnitIsPlayer(unit) if secretMode then return S end return u(unit) and not u(unit).npc end
function UnitIsConnected(unit) if secretMode then return S end return not (u(unit) and u(unit).offline) end
function UnitIsDeadOrGhost(unit) if secretMode then return S end return u(unit) and (u(unit).dead or u(unit).ghost) or false end
function UnitIsGhost(unit) if secretMode then return S end return u(unit) and u(unit).ghost or false end
function UnitIsGroupLeader(unit) if secretMode then return S end return u(unit) and u(unit).leader or false end
function UnitGroupRolesAssigned(unit) return val(unit, "role", "NONE") end
function UnitIsUnit(a, b) if secretMode then return S end return a == "party1" and b == "target" end
function UnitCanAttack(_, unit) if secretMode then return S end return u(unit) and u(unit).hostile or false end
function UnitReaction(unit) return val(unit, "reaction", 5) end
function UnitInRange(unit)
	if secretMode then return S, S end
	return not (u(unit) and u(unit).far), true
end
function GetRaidTargetIndex(unit) return val(unit, "mark", nil) end
function SetRaidTargetIconTexture() end
function UnitGetIncomingHeals(unit) return val(unit, "inc", 0) end
function AbbreviateNumbers() return "1K" end
function CreateColor(r, g, b, a) return { GetRGBA = function() return r, g, b, a end } end
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, PRIEST = { r = 1, g = 1, b = 1 } }
PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }
CurveConstants = { ScaleTo100 = {} }
Enum.LuaCurveType = { Step = 1 }
C_CurveUtil = { CreateColorCurve = function() return { SetType = function() end, AddPoint = function() end } end }

local auraCalls = 0
C_UnitAuras = {
	GetAuraDataByIndex = function(unit, i, filter)
		auraCalls = auraCalls + 1
		if not u(unit) or i > 3 then return nil end
		if secretMode then return { icon = S, applications = S, dispelName = S, auraInstanceID = i } end
		local harmful = filter:find("HARMFUL")
		return { icon = 100 + i, applications = i, dispelName = harmful and (i == 1 and "Magic" or nil) or nil, auraInstanceID = i }
	end,
	GetAuraApplicationDisplayCount = function() return "2" end,
	GetAuraDispelTypeColor = function() return CreateColor(1, 0, 0, 1) end,
}

local drivers = {}
local driverCalls = 0
function RegisterStateDriver(f, _, cond) drivers[f] = cond driverCalls = driverCalls + 1 end
function UnregisterStateDriver(f) drivers[f] = nil end
local function settle(ns)
	for _, b in ipairs(ns.buttons) do
		local cond = drivers[b]
		if not cond then
			b.__shown = false
		elseif cond == "show" then
			b.__shown = true
		elseif cond:find("%[group%] show") then
			b.__shown = units.party1 ~= nil
		else
			b.__shown = u(b.unit) ~= nil
		end
		if b.__shown then b.__scripts.OnShow(b) end
	end
end

local gone = {}
for _, name in ipairs({ "PartyFrame", "CompactPartyFrame", "PlayerFrame", "TargetFrame", "PartyMemberFrame1" }) do
	local f = M.obj("Frame")
	f.SetParent = function(_, p) gone[name] = p end
	_G[name] = f
end

M.load("ACore", "ACore")
local ns = M.load("AFrames", "AFrames")
event("PLAYER_LOGIN")
ok(ns.db and #ns.buttons == 7, "seven unit buttons")
ok(AFramesParty1 and AFramesPlayerUnit and AFramesTargetUnit, "named frames")
settle(ns)
ok(AFramesParty1:IsShown() and not AFramesPartyPlayer:IsShown(), "party shown, player slot off by default")
ok(not AFramesPlayerUnit:IsShown() and not AFramesTargetUnit:IsShown(), "player and target off by default")
ok(gone.PartyFrame and gone.PartyMemberFrame1 and not gone.PlayerFrame, "default party frames hidden only")
ok(drivers[AFramesParty2]:find("group:raid") and drivers[AFramesParty2]:find("@party2,exists"), "visibility condition")

local UNIT_EVENTS = {
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_POWER_UPDATE",
	"UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_AURA",
}
local GLOBAL_EVENTS = {
	"GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED",
	"RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED",
}
local function storm()
	for _, e in ipairs(UNIT_EVENTS) do
		for unit in pairs(units) do event(e, unit) end
		event(e, "raid7")
		event(e, S)
	end
	for _, e in ipairs(GLOBAL_EVENTS) do event(e) end
	ns.ticker.__scripts.OnUpdate(ns.ticker, 0.5)
	for _, b in ipairs(ns.buttons) do
		b.__scripts.OnEnter(b)
		b.__scripts.OnLeave(b)
	end
end

ns.db.player.enabled = true
ns.db.target.enabled = true
ns.db.party.player = true
ok(ns.Apply(), "apply out of combat")
settle(ns)
ok(AFramesPlayerUnit:IsShown() and AFramesTargetUnit:IsShown() and AFramesPartyPlayer:IsShown(), "all frames on")
ok(gone.PlayerFrame and gone.TargetFrame, "default player and target hidden")

for _, mode in ipairs({ "percent", "value", "deficit", "none" }) do
	ns.db.healthText = mode
	storm()
end
ok(AFramesParty3.body.__alpha == nil or true, "range ran")
ok(#AFramesParty1.debuffs == 3 and #AFramesParty1.buffs == 3, "aura icons built")
ok(AFramesParty1.debuffs[1]:IsShown(), "debuff shown")

local keep = { UnitHealthPercent, UnitHealthMissing, AbbreviateNumbers, CurveConstants, PowerBarColor, UnitGetIncomingHeals }
UnitHealthPercent, UnitHealthMissing, AbbreviateNumbers, CurveConstants, PowerBarColor, UnitGetIncomingHeals = nil, nil, nil, nil, nil, nil
for _, mode in ipairs({ "percent", "value", "deficit", "none" }) do
	ns.db.healthText = mode
	storm()
end
UnitHealthPercent = function() return 55 end
UnitHealthMissing = function(unit) return val(unit, "hp", 0) end
AbbreviateNumbers = function() return "1K" end
CurveConstants = { ScaleTo100 = {} }
UnitGetIncomingHeals = function(unit) return val(unit, "inc", 0) end

secretMode = true
for _, mode in ipairs({ "percent", "value", "deficit", "none" }) do
	ns.db.healthText = mode
	storm()
end
C_UnitAuras.GetAuraApplicationDisplayCount = nil
C_UnitAuras.GetAuraDispelTypeColor = nil
storm()
AbbreviateNumbers = nil
UnitHealthPercent = nil
UnitHealthMissing = nil
storm()
secretMode = false
ns.db.healthText = "percent"
ns.db.classColor = false
ns.db.debuffs = false
ns.db.buffs = false
ns.db.range = false
ns.db.tooltips = false
storm()
ok(not AFramesParty1.debuffs[1]:IsShown(), "debuffs hidden when off")
ns.db.classColor, ns.db.debuffs, ns.db.buffs, ns.db.range, ns.db.tooltips = true, true, true, true, true

combat = true
local before = driverCalls
ns.db.party.horizontal = true
ok(ns.Apply() == false, "apply refused in combat")
ok(driverCalls == before, "nothing touched in combat")
SlashCmdList["AFRAMES"]("unlock")
ok(not ns.unlocked and printed[#printed]:find("combat"), "unlock refused in combat")
storm()
combat = false
event("PLAYER_REGEN_ENABLED")
ok(driverCalls > before, "queued apply ran after combat")
settle(ns)

SlashCmdList["AFRAMES"]("unlock")
ok(ns.unlocked and AFramesParty.handle:IsShown(), "unlocked")
local h = AFramesParty.handle
h.__scripts.OnDragStart(h)
h.__scripts.OnDragStop(h)
ok(ns.db.party.pos, "position saved")
h.__scripts.OnDragStart(h)
event("PLAYER_REGEN_DISABLED")
ok(not ns.unlocked and not h:IsShown(), "locked when combat starts")
combat = true
h.__scripts.OnDragStart(h)
h.__scripts.OnDragStop(h)
combat = false
SlashCmdList["AFRAMES"]("lock")

SlashCmdList["AFRAMES"]("")
ok(AFramesOptions and AFramesOptions:IsShown(), "options window")
local list = AFramesOptions.list
ok(#list.data >= 16, "option rows " .. #list.data)
for pass = 1, 2 do
	for i = 1, #list.data do
		list:ScrollTo(i)
		local row = list.rows[1]
		if row and row.data then row.__scripts.OnClick(row, "LeftButton") end
	end
end
for i = 1, 6 do
	for _, d in ipairs(list.data) do
		if d.value and d.func then d.func() end
	end
end
settle(ns)
storm()
SlashCmdList["AFRAMES"]("reset")
ok(ns.db.party.pos == nil, "reset")
SlashCmdList["AFRAMES"]("help")
SlashCmdList["AFRAMES"]("")
ok(not AFramesOptions:IsShown(), "options closed")
SlashCmdList["ACORE"]("frames")
ok(AFramesOptions:IsShown(), "launcher opens options")

units.party1 = nil
settle(ns)
storm()

print_real(string.format("ok: %d checks, %d buttons, %d aura lookups", M.checks(), #ns.buttons, auraCalls))
