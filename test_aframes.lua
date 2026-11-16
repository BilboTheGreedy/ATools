local M = dofile("tools/mock.lua")
local ok, event, flush, printed = M.ok, M.event, M.flush, M.printed

local S = { __secret = true }
issecretvalue = function(v) return v == S end

local combat = false
local secretMode = false
local inRaid = false
local units = {
	player = { name = "Me", class = "WARRIOR", hp = 900, max = 1000, power = 30, pmax = 100, ptype = "RAGE", level = 60, leader = true, role = "TANK" },
	party1 = { name = "Healer", class = "PRIEST", hp = 400, max = 800, power = 500, pmax = 900, ptype = "MANA", level = 58, role = "HEALER", mark = 3 },
	party2 = { name = "Gone", class = "MAGE", hp = 0, max = 700, power = 0, pmax = 900, ptype = "MANA", level = 57, offline = true, role = "DAMAGER" },
	party3 = { name = "Corpse", class = "ROGUE", hp = 0, max = 700, power = 0, pmax = 100, ptype = "ENERGY", level = 60, dead = true, far = true, role = "NONE" },
	target = { name = "Boar", hp = 50, max = 120, power = 0, pmax = 0, ptype = "WEIRD", level = -1, npc = true, hostile = true, reaction = 2, kind = "elite", cast = { "Charge", 1000, 3000 } },
	targettarget = { name = "Me", class = "WARRIOR", hp = 900, max = 1000, power = 30, pmax = 100, ptype = "RAGE", level = 60 },
	pet = { name = "Cat", hp = 300, max = 400, power = 80, pmax = 100, ptype = "FOCUS", level = 59, npc = true },
	focus = { name = "Sheep", hp = 10, max = 100, power = 0, pmax = 0, ptype = "MANA", level = 61, npc = true, hostile = true, reaction = 2, tapped = true, kind = "rare", channel = { "Drain", 2000, 9000 } },
	partypet1 = { name = "Imp", hp = 50, max = 100, power = 5, pmax = 10, ptype = "MANA", level = 58, npc = true },
}
for i = 1, 12 do
	units["raid" .. i] = {
		name = "Raider" .. i, class = i % 2 == 0 and "PRIEST" or "WARRIOR", hp = 100 * i, max = 1200, power = 10, pmax = 100,
		ptype = "MANA", level = 60, ready = ({ "ready", "notready", "waiting" })[i % 3 + 1], dead = i == 5, far = i == 6,
	}
end
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
function UnitIsTapDenied(unit) if secretMode then return S end return u(unit) and u(unit).tapped or false end
function UnitClassification(unit) return val(unit, "kind", "normal") end
function GetPetHappiness() if secretMode then return S end return 2 end
local combo = 3
function GetComboPoints() if secretMode then return S end return combo end
local clock = 1.5
function GetTime() return clock end
function UnitCastingInfo(unit)
	local c = u(unit) and u(unit).cast
	if not c then return nil end
	if secretMode then return S, S, S, S, S, S, S, S end
	return c[1], c[1], 136, c[2], c[3], false, 1, false
end
function UnitChannelInfo(unit)
	local c = u(unit) and u(unit).channel
	if not c then return nil end
	if secretMode then return S, S, S, S, S, S, S end
	return c[1], c[1], 136, c[2], c[3], false, true
end
local portraits = 0
function SetPortraitTexture() portraits = portraits + 1 end
function IsResting() return true end
local fighting = false
function UnitAffectingCombat() if secretMode then return S end return fighting end
function UnitIsPVP() if secretMode then return S end return true end
function GetReadyCheckStatus(unit) return val(unit, "ready", nil) end
function GetRaidRosterInfo(i)
	if not units["raid" .. i] then return nil end
	return "Raider" .. i, 0, i <= 6 and 2 or 4
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
		if secretMode then return { icon = S, applications = S, dispelName = S, auraInstanceID = i, isFromPlayerOrPlayerPet = S, duration = S, expirationTime = S } end
		local harmful = filter:find("HARMFUL")
		return {
			icon = 100 + i, applications = i, dispelName = harmful and (i == 1 and "Magic" or nil) or nil, auraInstanceID = i,
			isFromPlayerOrPlayerPet = i == 2, duration = 30, expirationTime = 40,
		}
	end,
	GetAuraApplicationDisplayCount = function() return "2" end,
	GetAuraDispelTypeColor = function() return CreateColor(1, 0, 0, 1) end,
}

local drivers = {}
local driverCalls = 0
function RegisterStateDriver(f, _, cond) drivers[f] = cond driverCalls = driverCalls + 1 end
function UnregisterStateDriver(f) drivers[f] = nil end
local function test(cond)
	if cond == "group:raid" then return inRaid end
	if cond == "group:party" or cond == "group" then return inRaid or units.party1 ~= nil end
	local unit = cond:match("^@(%w+),exists$")
	if unit then return u(unit) ~= nil and (inRaid or not unit:find("^raid")) end
	error("unknown condition " .. cond)
end
local function eval(cond)
	for clause in (cond .. ";"):gmatch("%s*(.-)%s*;") do
		local c, action = clause:match("^%[(.-)%]%s*(%a+)$")
		if not c then return clause == "show" end
		if test(c) then return action == "show" end
	end
	return false
end
local function settle(ns)
	for _, b in ipairs(ns.buttons) do
		local cond = drivers[b]
		b.__shown = cond ~= nil and eval(cond)
		if b.__shown then b.__scripts.OnShow(b) end
	end
end

local gone = {}
local BLIZZ = {
	"PartyFrame", "CompactPartyFrame", "PlayerFrame", "TargetFrame", "PartyMemberFrame1", "PetFrame", "ComboFrame",
	"CompactRaidFrameManager", "CompactRaidFrameContainer", "FocusFrame",
}
for _, name in ipairs(BLIZZ) do
	local f = M.obj("Frame")
	f.__parent = UIParent
	f.SetParent = function(self, p)
		gone[name] = p ~= UIParent
		self.__parent = p
	end
	_G[name] = f
end
M.methods.GetName = function(self) return self.__name end
local cf = CreateFrame
CreateFrame = function(kind, name, ...)
	local f = cf(kind, name, ...)
	f.__name = name
	return f
end

AFramesDB = {
	player = { enabled = false }, target = { enabled = false },
	party = { enabled = true, pos = { "CENTER", "CENTER", 1, 2 } }, healthText = "value",
}

M.load("ACore", "ACore")
local ns = M.load("AFrames", "AFrames")
event("PLAYER_LOGIN")
local U = ns.db.units
ok(AFramesDB.profiles and AFramesDB.profiles.Default == ns.db and ns.db.healthText == "value", "old settings moved into the profile")
ok(U.player.on and U.target.on and U.tot.on and U.pet.on and U.focus.on and U.party.on and U.raid.on, "new defaults apply despite old saved off values")
ok(#ns.buttons == 5 + 5 + 4 + 40 + 5, "unit buttons " .. #ns.buttons)
ok(AFramesPlayerUnit and AFramesTargetUnit and AFramesTargetTargetUnit and AFramesPetUnit and AFramesFocusUnit and AFramesParty4 and AFramesPartyPet1 and AFramesRaid40 and AFramesRaidParty0, "named frames")
settle(ns)
ok(AFramesPlayerUnit:IsShown() and AFramesTargetUnit:IsShown() and AFramesTargetTargetUnit:IsShown() and AFramesPetUnit:IsShown() and AFramesFocusUnit:IsShown(), "single frames shown")
ok(AFramesParty1:IsShown() and not AFramesPartyPlayer:IsShown() and not AFramesPartyPet1:IsShown(), "party shown, my slot and pets off by default")
ok(not AFramesRaid1:IsShown() and not AFramesRaidParty1:IsShown(), "raid frames hidden outside a raid")
ok(gone.PartyFrame and gone.PartyMemberFrame1 and gone.PlayerFrame and gone.TargetFrame and gone.FocusFrame and gone.PetFrame and gone.CompactRaidFrameManager, "default frames hidden")
ok(drivers[AFramesParty2]:find("group:raid") and drivers[AFramesParty2]:find("@party2,exists"), "visibility condition")
ok(drivers[AFramesRaid7] == "[@raid7,exists] show; hide", "raid visibility condition")
ok(AFramesPlayerUnit.__w == 220 and AFramesPlayerUnit.__h == 46 and AFramesTargetTargetUnit.__w == 110 and AFramesRaid3.__w == 74, "sizes from settings")

local labels = {}
for _, m in ipairs(ACore.movers) do labels[m.label] = m end
for _, name in ipairs({ "Player", "Target", "Target of target", "Pet", "Focus", "Party", "Raid" }) do
	ok(labels["AFrames " .. name], "mover registered: " .. name)
end

local UNIT_EVENTS = {
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_POWER_UPDATE",
	"UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_AURA", "UNIT_FACTION",
	"UNIT_CLASSIFICATION_CHANGED", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}
local GLOBAL_EVENTS = {
	"GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED",
	"RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET", "UNIT_HAPPINESS",
	"READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "PLAYER_UPDATE_RESTING", "UNIT_COMBO_POINTS",
}
local function storm()
	for _, e in ipairs(UNIT_EVENTS) do
		for unit in pairs(units) do event(e, unit) end
		event(e, "raid39")
		event(e, S)
	end
	for _, e in ipairs(GLOBAL_EVENTS) do event(e) end
	ns.ticker.__scripts.OnUpdate(ns.ticker, 0.5)
	for _, b in ipairs(ns.buttons) do
		b.__scripts.OnEnter(b)
		b.__scripts.OnLeave(b)
	end
	local cast = AFramesTargetUnit.cast
	cast.__scripts.OnUpdate(cast, 0.1)
end

for _, mode in ipairs({ "percent", "value", "deficit", "none" }) do
	ns.db.healthText = mode
	storm()
end
ok(#AFramesParty1.debuffs == 3 and #AFramesParty1.buffs == 3, "aura icons built")
ok(AFramesParty1.debuffs[1]:IsShown(), "debuff shown")
ok(#AFramesTargetUnit.debuffs == 3 and AFramesTargetUnit.debuffs[2].size == 26 and AFramesTargetUnit.debuffs[1].size == 20, "target auras, own debuffs larger")
ok(#AFramesTargetTargetUnit.debuffs == 0 and #AFramesPetUnit.debuffs == 0, "small frames have no auras")
ok(AFramesTargetUnit.level.__text == "??+", "elite tag on the target " .. tostring(AFramesTargetUnit.level.__text))
ok(AFramesFocusUnit.level.__text == "61R", "rare tag on focus " .. tostring(AFramesFocusUnit.level.__text))
ok(AFramesPetUnit.nameColor and AFramesPetUnit.nameColor[1] == 1, "pet happiness colour")
ok(AFramesTargetUnit.cast:IsShown() and AFramesTargetUnit.cast.active and AFramesTargetUnit.cast.left.__text == "Charge", "target cast bar")
ok(AFramesTargetUnit.auraOffset == 18, "auras move below the cast bar")
clock = 3.5
AFramesTargetUnit.cast.__scripts.OnUpdate(AFramesTargetUnit.cast, 0.1)
ok(not AFramesTargetUnit.cast:IsShown(), "cast bar ends")
clock = 1.5
ok(not AFramesTargetUnit.combo:IsShown(), "no combo points for a warrior")
ns.playerClass = "ROGUE"
event("UNIT_COMBO_POINTS")
ok(AFramesTargetUnit.combo:IsShown(), "combo points for a rogue")
combo = 0
event("UNIT_POWER_UPDATE", "player")
ok(not AFramesTargetUnit.combo:IsShown(), "combo bar hides at zero")
combo = 3
ok(AFramesPlayerUnit.rest:IsShown() and AFramesPlayerUnit.pvp:IsShown() and not AFramesPlayerUnit.fight:IsShown(), "resting and pvp marks")
fighting = true
event("PLAYER_REGEN_DISABLED")
ok(AFramesPlayerUnit.fight:IsShown() and not AFramesPlayerUnit.rest:IsShown(), "combat mark")
fighting = false
event("PLAYER_REGEN_ENABLED")
ok(not AFramesPlayerUnit.portrait:IsShown() and portraits == 0, "portraits off by default")
U.player.portrait, U.target.portrait = true, true
storm()
ok(AFramesPlayerUnit.portrait:IsShown() and AFramesTargetUnit.portrait:IsShown() and portraits > 0, "portraits")
ACastDB = {}
event("UNIT_SPELLCAST_START", "target")
ok(not AFramesTargetUnit.cast:IsShown(), "no cast bar when ACast is loaded")
ACastDB = nil
event("UNIT_SPELLCAST_START", "target")
ok(AFramesTargetUnit.cast:IsShown(), "cast bar back")

inRaid = true
event("GROUP_ROSTER_UPDATE")
settle(ns)
storm()
ok(AFramesRaid1:IsShown() and AFramesRaid12:IsShown() and not AFramesRaid13:IsShown(), "raid frames shown in a raid")
ok(not AFramesParty1:IsShown(), "party frames hidden in a raid")
ok(AFramesRaid5.ready:IsShown() and AFramesRaid5.health.right.__text == "Dead", "ready check icon and dead text")
ok(AFramesRaid1.dispel and #AFramesRaid1.debuffs == 2, "raid debuff highlight and icons")
ok(AFramesRaid1.health.right.__text == "", "no health text on raid frames")
U.party.raid = true
ns.Apply()
settle(ns)
ok(AFramesParty1:IsShown(), "party kept in a raid when asked")
U.party.raid = false
inRaid = false
U.raid.forParty = true
ns.Apply()
settle(ns)
ok(AFramesRaidParty0:IsShown() and AFramesRaidParty1:IsShown() and not AFramesParty1:IsShown() and not AFramesRaid1:IsShown(), "raid grid used for the party")
ok(gone.PartyFrame, "default party still hidden with the grid")
U.raid.forParty = false
U.party.pets, U.party.player = true, true
ns.Apply()
settle(ns)
ok(AFramesPartyPet1:IsShown() and not AFramesPartyPet2:IsShown() and AFramesPartyPlayer:IsShown(), "party pets and my slot")

local keep = { UnitHealthPercent, UnitHealthMissing, AbbreviateNumbers, CurveConstants, PowerBarColor, UnitGetIncomingHeals }
UnitHealthPercent, UnitHealthMissing, AbbreviateNumbers, CurveConstants, PowerBarColor, UnitGetIncomingHeals = nil, nil, nil, nil, nil, nil
local savedCombo, savedDiff = GetComboPoints, GetQuestDifficultyColor
GetComboPoints = nil
GetQuestDifficultyColor = function() return { r = 1, g = 1, b = 0 } end
for _, mode in ipairs({ "percent", "value", "deficit", "none" }) do
	ns.db.healthText = mode
	storm()
end
GetComboPoints = savedCombo
GetQuestDifficultyColor = savedDiff
UnitHealthPercent = function() return 55 end
UnitHealthMissing = function(unit) return val(unit, "hp", 0) end
AbbreviateNumbers = function() return "1K" end
CurveConstants = { ScaleTo100 = {} }
UnitGetIncomingHeals = function(unit) return val(unit, "inc", 0) end

inRaid = true
settle(ns)
secretMode = true
for _, mode in ipairs({ "percent", "value", "deficit", "none" }) do
	ns.db.healthText = mode
	storm()
end
ok(AFramesTargetUnit.cast:IsShown() and AFramesTargetUnit.cast.active == nil, "secret cast shows without a timer")
C_UnitAuras.GetAuraApplicationDisplayCount = nil
C_UnitAuras.GetAuraDispelTypeColor = nil
storm()
AbbreviateNumbers = nil
UnitHealthPercent = nil
UnitHealthMissing = nil
storm()
secretMode = false
inRaid = false
settle(ns)
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
U.party.horizontal = true
ok(ns.Apply() == false, "apply refused in combat")
event("GROUP_ROSTER_UPDATE")
ok(driverCalls == before, "nothing touched in combat")
SlashCmdList["AFRAMES"]("unlock")
ok(not ACore.LayoutActive() and printed[#printed]:find("combat"), "unlock refused in combat")
storm()
combat = false
event("PLAYER_REGEN_ENABLED")
ok(driverCalls > before, "queued apply ran after combat")
settle(ns)

U.pet.on = false
ns.Apply()
SlashCmdList["AFRAMES"]("unlock")
ok(ACore.LayoutActive(), "unlock opens the ACore layout mode")
local pm, petm = labels["AFrames Player"], labels["AFrames Pet"]
ok(pm.handle and pm.handle:IsShown() and not (petm.handle and petm.handle:IsShown()), "handles only for enabled frames")
local h = pm.handle
h.__scripts.OnDragStart(h)
h.__scripts.OnDragStop(h)
ok(U.player.pos and U.player.pos[1] == "CENTER", "position saved through ACore")
h.__scripts.OnMouseWheel(h, 1)
ok(math.abs(U.player.scale - 1.05) < 0.001, "mouse wheel resizes")
event("PLAYER_REGEN_DISABLED")
ok(not ACore.LayoutActive(), "locked when combat starts")
SlashCmdList["AFRAMES"]("move")
SlashCmdList["AFRAMES"]("lock")
ok(not ACore.LayoutActive(), "lock")
U.pet.on = true

local entries = ns.Options()
ok(#entries >= 40, "option entries " .. #entries)
local seen = {}
for _, e in ipairs(entries) do seen[e.text] = e end
ok(seen["Player"] and seen["Target of target"] and seen["Focus"] and seen["Raid"] and seen["Use the raid grid for a party"] and seen["Player width: 220"], "options cover every frame")
seen["Player width: 220"].func()
ok(U.player.w == 240 and AFramesPlayerUnit.__w == 240, "width option applies")
seen["Health text: percent"].func()
ok(ns.db.healthText == "value", "health text cycles")
for pass = 1, 2 do
	for _, e in ipairs(ns.Options()) do
		if e.func and e.text ~= "Move and resize frames" then e.func() end
	end
	settle(ns)
	storm()
end
ok(U.player.on and U.raid.on and ns.db.hideBlizzard, "options toggle back")
U.player.on, U.target.on, U.raid.on = false, false, false
ns.Apply()
settle(ns)
ok(not AFramesPlayerUnit:IsShown() and not AFramesTargetUnit:IsShown(), "frames can be turned off")
ok(gone.PlayerFrame == false and gone.TargetFrame == false and gone.CompactRaidFrameManager == false and gone.PartyFrame, "default frames come back when ours are off")
ns.db.hideBlizzard = false
ns.Apply()
ok(gone.PartyFrame == false and not ns.BlizzardHidden(), "everything restored")
ns.db.hideBlizzard = true
U.player.on, U.target.on, U.raid.on = true, true, true
ns.Apply()
settle(ns)

FocusFrame = nil
ok(not ns.HasFocus(), "focus support check")
local n = 0
for _, e in ipairs(ns.Options()) do
	if e.text == "Focus" then n = n + 1 end
end
ok(n == 0, "no focus option without focus support")
FocusFrame = M.obj("Frame")

SlashCmdList["AFRAMES"]("")
ok(ACorePanel and ACorePanel:IsShown() and #ACorePanel.list.data > 40, "options open in the ACore panel")
SlashCmdList["AFRAMES"]("reset")
ok(U.player.pos == nil and U.player.scale == 1, "reset")
SlashCmdList["AFRAMES"]("help")
ACorePanel:Hide()
SlashCmdList["ACORE"]("frames")
ok(ACorePanel:IsShown(), "launcher opens options")

units.party1 = nil
settle(ns)
storm()

print_real(string.format("ok: %d checks, %d buttons, %d aura lookups", M.checks(), #ns.buttons, auraCalls))
