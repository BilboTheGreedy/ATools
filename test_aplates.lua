local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
function issecretvalue(v) return v == SECRET end

local combat = false
function InCombatLockdown() return combat end
local now = 100
function GetTime() return now end
function GetQuestGreenRange() return 8 end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }

local units = {
	nameplate1 = { name = "Defias Thug", level = 12, hp = 300, max = 400, reaction = 2, class = "elite", threat = 3, raid = 8 },
	nameplate2 = { name = "Jaina", level = 60, hp = 900, max = 1000, reaction = 5, player = "MAGE" },
	nameplate3 = { name = SECRET, level = -1, hp = SECRET, max = SECRET, reaction = 4, class = "worldboss", tapped = true },
	nameplate4 = { name = "Rabbit", level = 1, hp = 5, max = 5, reaction = 4, class = "rare", threat = 1 },
}
local target = "nameplate1"
function UnitExists(u) return u == "target" or units[u] ~= nil end
function UnitName(u) return units[u] and units[u].name end
function UnitLevel(u) if u == "player" then return 20 end return units[u] and units[u].level end
function UnitHealth(u) return units[u].hp end
function UnitHealthMax(u) return units[u].max end
function UnitReaction(u) return units[u] and units[u].reaction end
function UnitIsPlayer(u) return units[u] and units[u].player ~= nil end
function UnitClass(u) if units[u] and units[u].player then return "Mage", units[u].player end return "Warrior", "WARRIOR" end
function UnitClassification(u) return units[u] and units[u].class or "normal" end
function UnitIsTapDenied(u) return units[u] and units[u].tapped end
function UnitThreatSituation(_, u) return units[u] and units[u].threat end
function UnitIsUnit(a, b) return b == "target" and a == target end
function GetRaidTargetIndex(u) return units[u] and units[u].raid end
local raidSet = 0
function SetRaidTargetIconTexture() raidSet = raidSet + 1 end

local casts = {}
function UnitCastingInfo(u)
	local c = casts[u]
	if c and not c.channel then return c.name, c.name, 1, c.s, c.e, false, 1, c.shield, 1 end
end
function UnitChannelInfo(u)
	local c = casts[u]
	if c and c.channel then return c.name, c.name, 1, c.s, c.e, false, c.shield, 1 end
end
function UnitCastingDuration() return { secret = true } end
function UnitChannelDuration() return { secret = true } end

local auras = {
	nameplate1 = {
		["HARMFUL|PLAYER"] = { { icon = 1, applications = 3, duration = 10, expirationTime = 105, auraInstanceID = 11 } },
		HARMFUL = {
			{ icon = 1, applications = 3, duration = 10, expirationTime = 105, auraInstanceID = 11 },
			{ icon = 2, applications = 0, duration = 0, expirationTime = 0, auraInstanceID = 12 },
			{ icon = SECRET, applications = SECRET, duration = SECRET, expirationTime = SECRET, auraInstanceID = 13 },
		},
	},
}
C_UnitAuras = {
	GetAuraDataByIndex = function(u, i, filter) return auras[u] and auras[u][filter] and auras[u][filter][i] end,
	GetAuraDuration = function() return { secret = true } end,
}

local cvars = { nameplateShowEnemies = "1", nameplateShowFriends = "0", nameplateShowAll = "0", nameplateMotion = "0" }
C_CVar = {
	GetCVar = function(n) return cvars[n] end,
	SetCVar = function(n, v) cvars[n] = v end,
}
local click = { enemy = false, friendly = false }
local frames = {}
C_NamePlate = {
	GetNamePlateForUnit = function(u) return frames[u] end,
	GetNamePlates = function()
		local out = {}
		for _, f in pairs(frames) do out[#out + 1] = f end
		return out
	end,
	SetNamePlateEnemyClickThrough = function(v) click.enemy = v end,
	SetNamePlateFriendlyClickThrough = function(v) click.friendly = v end,
	GetNamePlateEnemyClickThrough = function() return click.enemy end,
	GetNamePlateFriendlyClickThrough = function() return click.friendly end,
}

local values = {}
M.methods.SetValue = function(self, v) values[self] = v end
M.methods.SetMinMaxValues = function(self, a, b)
	if b == nil then error("bad max") end
end
M.methods.GetFont = function() return "Fonts\\FRIZQT__.TTF", 10, "" end
M.methods.SetAlpha = function(self, a) self.__alpha = a end
M.methods.SetScale = function(self, s) self.__scale = s end
M.methods.SetColorTexture = function() end
M.methods.SetStatusBarColor = function(self, r, g, b) self.__color = { r, g, b } end
M.methods.SetFormattedText = function(self, fmt, ...) self.__text = string.format(fmt, ...) end
local realSetText = M.methods.SetText
M.methods.SetText = function(self, t)
	if t == SECRET then self.__text = "<secret>" return end
	realSetText(self, t)
end
M.methods.SetTimerDuration = function(self, d) self.__timer = d end
M.methods.SetCooldown = function(self, s, d) self.__cd = { s, d } end
M.methods.SetCooldownFromDurationObject = function(self, o) self.__cdobj = o end

M.load("ACore", "ACore")
local ns = M.load("APlates", "APlates")
event("PLAYER_LOGIN")
flush()
ok(ns.db and ns.db.enabled, "db ready")

for unit in pairs(units) do
	local plate = M.obj("Frame")
	plate.UnitFrame = M.obj("Frame")
	plate.namePlateUnitToken = unit
	frames[unit] = plate
	event("NAME_PLATE_UNIT_ADDED", unit)
end
event("NAME_PLATE_UNIT_ADDED", SECRET)
event("NAME_PLATE_UNIT_ADDED", "nameplate9")

local p1, p2, p3, p4 = ns.plates.nameplate1, ns.plates.nameplate2, ns.plates.nameplate3, ns.plates.nameplate4
ok(p1 and p2 and p3 and p4, "plates created")
ok(frames.nameplate1.UnitFrame.__alpha == 0, "default art hidden")
ok(p1.name.__text == "Defias Thug", "name")
ok(p1.level.__text == "12+", "level and elite mark " .. tostring(p1.level.__text))
ok(p3.name.__text == "<secret>", "secret name passed through")
ok(p3.level.__text == "??B", "boss level " .. tostring(p3.level.__text))
ok(values[p1.health] == 300, "health value")
ok(values[p3.health] == SECRET, "secret health passed through")
ok(p1.health.right.__text == "75%", "health percent " .. tostring(p1.health.right.__text))
ok(p3.health.right.__text == "", "no percent on secret health")
ok(p1.health.__color[1] == 1 and p1.health.__color[2] == 0.45, "tanking colour")
ok(p2.health.__color[3] == 0.92, "class colour")
ok(p3.health.__color[1] == 0.5, "tapped colour")
ok(p4.health.__color[2] == 0.75, "pulling threat colour")
ok(p1.glow[1]:IsShown() and not p2.glow[1]:IsShown(), "target highlight")
ok(p1.__scale > p2.__scale, "target larger")
ok(p1.raid:IsShown() and raidSet == 1 and not p2.raid:IsShown(), "raid icon")
ok(p1.auras[1]:IsShown() and p1.auras[2]:IsShown() and p1.auras[3]:IsShown() and not p1.auras[4], "debuffs deduplicated")
ok(p1.auras[1].count.__text == 3 and p1.auras[1].cd.__cd[1] == 95, "debuff count and timer")
ok(p1.auras[3].cd.__cdobj, "secret debuff uses duration object")
ok(not p1.quest:IsShown(), "no quest marker without AQuest")

casts.nameplate1 = { name = "Fireball", s = 99000, e = 102000 }
event("UNIT_SPELLCAST_START", "nameplate1")
ok(p1.cast:IsShown() and p1.cast.left.__text == "Fireball", "cast shown")
ok(math.abs(values[p1.cast] - 1) < 0.001, "cast progress")
now = 101
p1.cast.__scripts.OnUpdate(p1.cast, 1)
ok(math.abs(values[p1.cast] - 2) < 0.001, "cast advances")
now = 103
p1.cast.__scripts.OnUpdate(p1.cast, 1)
ok(not p1.cast:IsShown(), "cast ends")
casts.nameplate1 = { name = "Drain", s = 103000, e = 106000, channel = true, shield = true }
event("UNIT_SPELLCAST_CHANNEL_START", "nameplate1")
ok(p1.cast:IsShown() and math.abs(values[p1.cast] - 3) < 0.001, "channel drains")
ok(p1.cast.shield.__alpha == 1, "shielded overlay")
casts.nameplate1 = { name = SECRET, s = SECRET, e = SECRET }
event("UNIT_SPELLCAST_START", "nameplate1")
ok(p1.cast:IsShown() and p1.cast.__timer and p1.cast.left.__text == "<secret>", "secret cast uses timer")
casts.nameplate1 = nil
event("UNIT_SPELLCAST_STOP", "nameplate1")
ok(not p1.cast:IsShown(), "cast stop")

units.nameplate1.hp = 100
event("UNIT_HEALTH", "nameplate1")
ok(values[p1.health] == 100 and p1.health.right.__text == "25%", "health update")
UnitHealthPercent = function(u) return units[u].hp == SECRET and 50 or units[u].hp / units[u].max * 100 end
CurveConstants = { ScaleTo100 = 1 }
event("UNIT_HEALTH", "nameplate3")
ok(p3.health.right.__text == "50%", "percent helper on secret health")
event("UNIT_MAXHEALTH", "nameplate1")
event("UNIT_NAME_UPDATE", "nameplate1")
event("UNIT_LEVEL", "nameplate1")
event("UNIT_FACTION", "nameplate1")
event("UNIT_AURA", "nameplate1")
event("UNIT_AURA", SECRET)
event("UNIT_THREAT_LIST_UPDATE", "nameplate4")
units.nameplate1.threat = nil
event("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
ok(p1.health.__color[1] == 0.85, "hostile colour without threat")
target = "nameplate4"
event("PLAYER_TARGET_CHANGED")
ok(p4.glow[1]:IsShown() and not p1.glow[1]:IsShown(), "target moved")
units.nameplate1.raid = nil
event("RAID_TARGET_UPDATE")
ok(not p1.raid:IsShown(), "raid icon cleared")

AQuest = { IsQuestUnit = function(u) return u == "nameplate1" end }
event("QUEST_LOG_UPDATE")
flush()
ok(p1.quest:IsShown() and not p4.quest:IsShown(), "quest marker with AQuest")

ns.db.friendlyNames = true
ns:Fire("OPTIONS")
ok(not p2.health:IsShown() and p1.health:IsShown(), "friendly name only")
ns.db.ownOnly = true
ns:Fire("OPTIONS")
ok(p1.auras[1]:IsShown() and not p1.auras[2]:IsShown(), "own debuffs only")
ns.db.debuffs = false
ns.db.castbar = false
ns.db.healthText = false
ns.db.level = false
ns.db.classColor = false
ns.db.threat = false
ns.db.raidIcon = false
ns:Fire("OPTIONS")
ok(not p1.auras[1]:IsShown() and p1.health.right.__text == "" and p1.level.__text == "+", "features off")

local entries = ns.Entries()
ok(#entries > 30, "options entries " .. #entries)
combat = true
local before = cvars.nameplateMotion
for _, e in ipairs(ns.Entries()) do
	if e.func and e.text == "Stack plates instead of overlapping" then e.func() end
	if e.func and e.text == "Click through enemy plates" then e.func() end
end
ok(cvars.nameplateMotion == before and click.enemy == false, "protected changes wait in combat")
combat = false
event("PLAYER_REGEN_ENABLED")
ok(cvars.nameplateMotion == "1" and click.enemy == true, "deferred changes applied")
for _, e in ipairs(ns.Entries()) do
	if e.func then e.func() end
end
SlashCmdList["APLATES"]("reset")
p2 = ns.plates.nameplate2

event("NAME_PLATE_UNIT_REMOVED", "nameplate2")
ok(not ns.plates.nameplate2 and not p2:IsShown(), "plate removed")
event("NAME_PLATE_UNIT_REMOVED", "nameplate2")
event("NAME_PLATE_UNIT_ADDED", "nameplate2")
ok(ns.plates.nameplate2 == p2, "plate frame reused")

SlashCmdList["APLATES"]("off")
ok(not ns.db.enabled and frames.nameplate1.UnitFrame.__alpha == 1 and not ns.plates.nameplate1, "off restores default")
SlashCmdList["APLATES"]("on")
ok(ns.plates.nameplate1 and frames.nameplate1.UnitFrame.__alpha == 0, "on again")
SlashCmdList["APLATES"]("reset")
ok(ns.db.width == 120 and ns.db.debuffs, "reset")
SlashCmdList["APLATES"]("")
ok(ACorePanel and ACorePanel:IsShown() and #ACorePanel.list.data > 30, "options open in the ACore panel")
SlashCmdList["ACORE"]("plates")
local registered
for _, a in ipairs(ACore.addons) do
	if a.name == "APlates" then registered = a end
end
ok(registered and type(registered.options) == "function" and #registered.options() > 30, "options registered with ACore")

local function texts()
	local t = {}
	for _, e in ipairs(ns.Entries()) do t[e.text] = e end
	return t
end
ok(texts()["Show friendly plates"] and texts()["Stack plates instead of overlapping"], "cvar entries when the cvars exist")
ok(not texts()["Personal resource bar"] and not texts()["Plate distance: 60"], "no entries for missing cvars")
cvars.nameplateShowFriends, cvars.nameplateMotion = nil, nil
cvars.nameplateShowFriendlyPlayers = "0"
cvars.nameplateMaxDistance = "60"
ok(not texts()["Stack plates instead of overlapping"], "stacking entry gone without the cvar")
texts()["Show friendly plates"].func()
ok(cvars.nameplateShowFriendlyPlayers == "1", "friendly plates fall back to the newer cvar")
texts()["Plate distance: 60"].func()
ok(cvars.nameplateMaxDistance == "20", "distance cycles")
C_NamePlate.SetNamePlateEnemyClickThrough = nil
ok(not texts()["Click through enemy plates"] and texts()["Click through friendly plates"], "click through only when supported")

ns.db.tank = true
units.nameplate1.threat = 3
event("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
ok(p1.health.__color[3] == 1, "tank colour while holding aggro")
ns.db.tank = false
ns.db.fade = true
event("PLAYER_TARGET_CHANGED")
ok(p1.__alpha == 0.55 and ns.plates.nameplate4.__alpha == 1, "other plates fade")
ns.db.fade = false

local logs = {}
ABug = { Log = function(kind, msg) logs[#logs + 1] = kind .. " " .. msg end }
local function shownAuras(f)
	local n = 0
	for _, a in ipairs(f.auras) do
		if a:IsShown() then n = n + 1 end
	end
	return n
end
local mineOnly = { icon = 5, applications = 1, duration = 10, expirationTime = 105, auraInstanceID = 21, isFromPlayerOrPlayerPet = true }
local theirs = { icon = 6, applications = 1, duration = 10, expirationTime = 105, auraInstanceID = 22, isFromPlayerOrPlayerPet = false }
auras.nameplate1 = { HARMFUL = { theirs, mineOnly } }
ns.db.ownOnly = true
event("UNIT_AURA", "nameplate1")
ok(shownAuras(p1) == 1, "own debuffs found through the plain filter when the player filter gives nothing")
ns.db.ownOnly = false
event("UNIT_AURA", "nameplate1")
ok(shownAuras(p1) == 2, "all debuffs without duplicates " .. shownAuras(p1))

auras.nameplate1 = { HARMFUL = { { icon = SECRET, applications = SECRET, duration = SECRET, expirationTime = SECRET, auraInstanceID = SECRET, isFromPlayerOrPlayerPet = SECRET, sourceUnit = SECRET } } }
event("UNIT_AURA", "nameplate1")
ok(shownAuras(p1) == 1, "secret debuff still shown")

local function logged(pat)
	for _, l in ipairs(logs) do
		if l:find(pat) then return l end
	end
end
local byIndex = C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = function() error("index is broken") end
event("UNIT_AURA", "nameplate1")
ok(shownAuras(p1) == 0 and logged("caught APlates: GetAuraDataByIndex HARMFUL: .*index is broken"), "failure logged")
local count = #logs
event("UNIT_AURA", "nameplate1")
ok(#logs == count, "logged once")
C_UnitAuras.GetUnitAuras = function(u, filter) if u == "nameplate1" and filter == "HARMFUL" then return { theirs, mineOnly } end end
event("UNIT_AURA", "nameplate1")
ok(shownAuras(p1) == 2, "GetUnitAuras fallback")
issecrettable = function(t) return t == theirs end
event("UNIT_AURA", "nameplate1")
ok(shownAuras(p1) == 1, "secret aura tables skipped")
issecrettable = nil
C_UnitAuras.GetUnitAuras = nil
C_UnitAuras.GetAuraSlots = function(u, filter) if u == "nameplate1" and filter == "HARMFUL" then return nil, 7, 8 end end
C_UnitAuras.GetAuraDataBySlot = function(_, slot) return slot == 7 and theirs or mineOnly end
event("UNIT_AURA", "nameplate1")
ok(shownAuras(p1) == 2, "slot fallback")
C_UnitAuras.GetAuraSlots = nil
AuraUtil = { ForEachAura = function(u, filter, _, fn)
	if u == "nameplate1" and filter == "HARMFUL" then
		fn(theirs)
		fn(mineOnly)
	end
end }
event("UNIT_AURA", "nameplate1")
ok(shownAuras(p1) == 2, "ForEachAura fallback")
AuraUtil = nil
UnitDebuff = function(u, i, filter)
	if u ~= "nameplate1" or i > 2 then return nil end
	if filter:find("PLAYER") then
		if i == 1 then return "Rend", 9, 0, nil, 10, 105, "player" end
		return nil
	end
	if i == 1 then return "Rend", 9, 0, nil, 10, 105, "player" end
	return "Curse", 10, 0, "Curse", 10, 105, "party1"
end
event("UNIT_AURA", "nameplate1")
ok(shownAuras(p1) == 2, "UnitDebuff fallback without duplicates " .. shownAuras(p1))
local lines = ns.AuraReport("nameplate1")
ok(#lines == 11 and lines[3]:find("GetAuraDataByIndex: error") and lines[6]:find("UnitAura: 2"), "aura report " .. tostring(lines[3]))
SlashCmdList["APLATES"]("auras")
UnitDebuff = nil
C_UnitAuras.GetAuraDataByIndex = byIndex
ABug = nil

print_real(string.format("ok: %d checks (aplates)", M.checks()))
