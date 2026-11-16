local M = dofile("tools/mock.lua")
local ok, event, flush, printed = M.ok, M.event, M.flush, M.printed

local clock = 100
function GetTime() return clock end
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }

local secretMode = false
local secrets = setmetatable({}, { __mode = "k" })
local function S(v)
	if not secretMode then return v end
	local t = {}
	secrets[t] = true
	return t
end
function issecretvalue(v) return secrets[v] == true end
function AbbreviateNumbers(v)
	if secrets[v] then return S("x") end
	return tostring(v)
end

local sent = {}
C_ChatInfo = { SendChatMessage = function(msg, channel) sent[#sent + 1] = channel .. ": " .. msg end }

Enum.DamageMeterType = {
	DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5,
	Dispels = 6, DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10,
}
Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }

local available = true
local resets = 0
local calls = {}
C_DamageMeter = {
	IsDamageMeterAvailable = function()
		if available then return true end
		return false, "disabled in settings"
	end,
	GetSessionDurationSeconds = function(st) return S(st == 0 and 300 or 83) end,
	GetCombatSessionFromType = function(st, t)
		calls[t] = (calls[t] or 0) + 1
		local scale = st == 0 and 10 or 1
		local sources = {}
		local names = { "Anna", "Bertil", "Cecilia" }
		for i, name in ipairs(names) do
			sources[i] = {
				name = S(name), sourceGUID = S("Player-" .. i), classFilename = i == 2 and "MAGE" or "WARRIOR",
				isLocalPlayer = i == 1, totalAmount = S((4 - i) * 1000 * scale + t), amountPerSecond = S((4 - i) * 12.5),
				deathTimeSeconds = t == 9 and S(i * 20) or nil, deathRecapID = t == 9 and i or nil,
			}
		end
		if t == 6 then sources = {} end
		return { combatSources = sources, maxAmount = S(3000 * scale + t), totalAmount = S(6000 * scale), durationSeconds = S(83) }
	end,
	GetCombatSessionSourceFromType = function(st, t, guid)
		return {
			maxAmount = S(700), totalAmount = S(1000),
			combatSpells = {
				{ spellID = S(133), totalAmount = S(700), amountPerSecond = S(7) },
				{ spellID = S(116), totalAmount = S(300), amountPerSecond = S(3), creatureName = "Water Elemental" },
			},
		}
	end,
	ResetAllCombatSessions = function() resets = resets + 1 end,
}

M.load("ACore", "ACore")
local ns = M.load("AMeter", "AMeter")
event("PLAYER_LOGIN")
flush()

local frame = AMeterFrame
ok(frame and frame:IsShown(), "window shown at login")
ok(ns.Data.Source() == "game meter", "uses the game meter")

local function rows()
	return frame.list.data
end

local function bars()
	local out = {}
	for _, bar in ipairs(frame.list.rows) do
		if bar:IsShown() and bar.data then out[#out + 1] = bar end
	end
	return out
end

local function hover()
	for _, bar in ipairs(bars()) do
		bar.__scripts.OnEnter(bar)
		bar.__scripts.OnLeave(bar)
	end
end

local function menuClickAll()
	local seen = {}
	local guard = 0
	local progress = true
	while progress and guard < 200 do
		progress = false
		for _, f in ipairs(M.frames) do
			local e = rawget(f, "entry")
			if e and f:IsShown() and not seen[e] and f.__scripts.OnClick then
				seen[e] = true
				guard = guard + 1
				f.__scripts.OnClick(f, "LeftButton")
				progress = true
			end
		end
	end
	return guard
end

local function walk(tag)
	for _, seg in ipairs(ns.SEGMENTS) do
		for _, m in ipairs(ns.MODES) do
			ns.db.segment = seg.key
			ns.db.mode = m.key
			ns:Fire("VIEW_CHANGED")
			ok(#rows() >= 1, tag .. " rows " .. m.key)
			hover()
			local first = bars()[1]
			first.__scripts.OnMouseUp(first, "LeftButton")
			hover()
			local again = bars()[1]
			again.__scripts.OnMouseUp(again, "LeftButton")
			ok(#rows() >= 1, tag .. " back from detail " .. m.key)
		end
	end
end

ns.db.mode = "damage"
ns.db.segment = "current"
ns:Fire("VIEW_CHANGED")
local r = rows()
ok(#r == 3 and r[1].name == "Anna" and r[1].me and r[1].value == 3000, "damage rows sorted")
ok(frame.list.rows[1].right.__text == "3000 (37.5)" or frame.list.rows[1].right.__text:find("%("), "damage text " .. tostring(frame.list.rows[1].right.__text))

ns.db.mode = "dps"
ns:Fire("VIEW_CHANGED")
ok(rows()[1].value == 37.5, "dps uses rate")

ns.db.mode = "dispels"
ns:Fire("VIEW_CHANGED")
ok(rows()[1].kind == "note", "empty mode shows a note")

ns.db.mode = "deaths"
ns:Fire("VIEW_CHANGED")
ok(rows()[1].name == "Anna" and frame.list.rows[1].right.__text == "0:20", "deaths in time order")

ns.db.mode = "damage"
ns:Fire("VIEW_CHANGED")
local first = bars()[1]
first.__scripts.OnMouseUp(first, "LeftButton")
ok(#rows() == 2 and rows()[1].spell == 133, "spell breakdown")
ok(frame.list.rows[2].left.__text:find("Water Elemental"), "pet shown on spell")
frame.titleButton.__scripts.OnClick(frame.titleButton, "LeftButton")
ok(#rows() == 3, "title click leaves detail")

walk("native")

ns.db.mode = "damage"
ns.db.segment = "current"
ns:Fire("VIEW_CHANGED")
frame.titleButton.__scripts.OnClick(frame.titleButton, "LeftButton")
ok(menuClickAll() > 5, "mode menu entries")
frame.titleButton.__scripts.OnClick(frame.titleButton, "RightButton")
local clicked = menuClickAll()
ok(clicked > 10, "gear menu entries " .. clicked)
ok(resets >= 1, "reset reaches the game meter")
ok(#sent >= 4 and sent[1]:find("^SAY: AMeter: "), "report sent " .. #sent)
ok(not frame:IsShown() and ns.db.shown == false, "hide from menu")
SlashCmdList["AMETER"]("")
ok(frame:IsShown(), "slash shows again")
frame.segButton.__scripts.OnClick(frame.segButton, "LeftButton")
frame.segButton.__scripts.OnClick(frame.segButton, "LeftButton")
frame.__scripts.OnUpdate(frame, 1.5)

secretMode = true
ns.db.rows = 8
walk("secret")
ns.db.mode = "damage"
ns:Fire("VIEW_CHANGED")
ok(#rows() == 3 and issecretvalue(rows()[1].value), "secret values pass through")
local before = #sent
frame.titleButton.__scripts.OnClick(frame.titleButton, "RightButton")
menuClickAll()
ok(#sent == before, "no report while values are hidden")
ok(printed[#printed]:find("hidden") or printed[#printed - 1]:find("hidden") or printed[#printed - 2]:find("hidden") or printed[#printed - 3]:find("hidden"), "report refusal printed")
SlashCmdList["AMETER"]("")
secretMode = false

available = false
ns:Fire("VIEW_CHANGED")
ok(rows()[1].kind == "note" and rows()[1].text:find("disabled in settings"), "unavailable note")
available = true

SlashCmdList["AMETER"]("healing")
ok(ns.db.mode == "healing", "slash mode")
SlashCmdList["AMETER"]("reset")
SlashCmdList["AMETER"]("lock")
SlashCmdList["AMETER"]("lock")
SlashCmdList["AMETER"]("pos")
SlashCmdList["AMETER"]("nonsense")
AMeter_ToggleBinding()
AMeter_ToggleBinding()
local resetsBefore = resets
ns.db.autoreset = true
event("PLAYER_ENTERING_WORLD")
ok(resets == resetsBefore + 1, "auto reset on entering an instance")
event("PLAYER_ENTERING_WORLD")
ok(resets == resetsBefore + 1, "no second reset in the same instance")
event("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 1)
event("DAMAGE_METER_CURRENT_SESSION_UPDATED")
event("DAMAGE_METER_RESET")
flush()

C_DamageMeter = nil
AMeterDB = nil
local units = {
	player = { "Player-1", "Anna", "WARRIOR" },
	pet = { "Pet-9", "Wolf" },
	party1 = { "Player-2", "Bertil", "MAGE" },
}
function UnitExists(u) return units[u] ~= nil end
function UnitGUID(u) return units[u] and units[u][1] end
function UnitName(u) return units[u] and units[u][2] end
function UnitClass(u) return "x", units[u] and units[u][3] or "WARRIOR" end
function UnitIsUnit(a, b) return a == b end
function IsInRaid() return false end
function GetNumGroupMembers() return 2 end
local logEvent
function CombatLogGetCurrentEventInfo() return unpack(logEvent, 1, 20) end
local function log(...)
	logEvent = { ... }
	event("COMBAT_LOG_EVENT_UNFILTERED")
end

local ns2 = M.load("AMeter", "AMeter")
event("PLAYER_LOGIN")
flush()
frame = AMeterFrame
ns = ns2
ok(ns.Data.Source() == "combat log", "falls back to the combat log")
event("PLAYER_REGEN_DISABLED")
log(1, "SWING_DAMAGE", false, "Player-1", "Anna", 0, 0, "Mob-1", "Boar", 0, 0, 100)
log(1, "SPELL_DAMAGE", false, "Player-2", "Bertil", 0, 0, "Mob-1", "Boar", 0, 0, 133, "Fireball", 4, 400)
log(1, "SPELL_PERIODIC_DAMAGE", false, "Pet-9", "Wolf", 0, 0, "Mob-1", "Boar", 0, 0, 17253, "Bite", 1, 50)
log(1, "SWING_DAMAGE", false, "Mob-1", "Boar", 0, 0, "Player-1", "Anna", 0, 0, 30)
log(1, "ENVIRONMENTAL_DAMAGE", false, nil, nil, 0, 0, "Player-1", "Anna", 0, 0, "Falling", 20)
log(1, "SPELL_HEAL", false, "Player-2", "Bertil", 0, 0, "Player-1", "Anna", 0, 0, 2050, "Heal", 2, 90, 40)
log(1, "SPELL_INTERRUPT", false, "Player-1", "Anna", 0, 0, "Mob-1", "Boar", 0, 0, 6552, "Pummel", 1, 133, "Fireball")
log(1, "SPELL_DISPEL", false, "Player-2", "Bertil", 0, 0, "Player-1", "Anna", 0, 0, 475, "Remove Curse", 1, 980, "Agony")
log(1, "UNIT_DIED", false, nil, nil, 0, 0, "Player-2", "Bertil", 0, 0)
log(1, "SWING_DAMAGE", false, "Mob-2", "Stranger", 0, 0, "Mob-1", "Boar", 0, 0, 999)
clock = 110
event("PLAYER_REGEN_ENABLED")
flush()

local function session(mode, seg)
	return ns.Data.Session(seg or "current", ns.Mode(mode))
end
local d = session("damage")
ok(#d.rows == 2 and d.rows[1].name == "Bertil" and d.rows[1].total == 400, "log damage")
ok(d.rows[2].name == "Anna" and d.rows[2].total == 150, "pet damage merged into owner")
ok(d.duration == 10 and session("dps").rows[1].value == 40, "log dps")
ok(session("healing").rows[1].total == 50, "overheal removed")
ok(session("taken").rows[1].total == 50, "damage taken")
ok(session("interrupts").rows[1].total == 1 and session("dispels").rows[1].name == "Bertil", "interrupts and dispels")
ok(session("deaths").rows[1].name == "Bertil", "deaths")
local sp = ns.Data.Spells("current", ns.Mode("damage"), d.rows[2])
ok(#sp.rows == 2 and sp.rows[1].total == 100 and sp.rows[2].pet == "Wolf", "log spell breakdown")
walk("log")
event("PLAYER_REGEN_DISABLED")
ok(#session("damage").rows == 0 and #session("damage", "overall").rows == 2, "new fight keeps overall")
event("PLAYER_REGEN_ENABLED")
SlashCmdList["AMETER"]("reset")
ok(#session("damage", "overall").rows == 0, "log reset")
flush()

print_real(string.format("ok: %d checks", M.checks()))
