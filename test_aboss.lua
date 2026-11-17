local M = dofile("tools/mock.lua")
local ok, event, flush, printed = M.ok, M.event, M.flush, M.printed

local now = 100
function GetTime() return now end
function time() return 1700000000 end
function date() return "16 Nov 20:00" end
local SECRET = {}
function issecretvalue(v) return v == SECRET end
local grouped, combat = false, false
function IsInGroup() return grouped end
function IsInRaid() return false end
function InCombatLockdown() return combat end
local chat = {}
function SendChatMessage(text, channel) chat[#chat + 1] = channel .. ":" .. text end
local sounds = 0
function PlaySound() sounds = sounds + 1 end
local countdowns = {}
C_PartyInfo = { DoCountdown = function(n) countdowns[#countdowns + 1] = n return true end }
bit = { band = function(a, b)
	local r, p = 0, 1
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then r = r + p end
		a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
	end
	return r
end }
Enum.EncounterTimelineEventState = { Active = 0, Paused = 1, Finished = 2, Canceled = 3 }
Enum.EncounterEventIconmask = { DeadlyEffect = 1, EnrageEffect = 2, BleedEffect = 4, MagicEffect = 8, TankRole = 128 }
local addonSent, prefixes = {}, {}
C_ChatInfo = {
	SendAddonMessage = function(prefix, text, channel) addonSent[#addonSent + 1] = prefix .. ":" .. text .. ":" .. channel end,
	RegisterAddonMessagePrefix = function(prefix) prefixes[prefix] = true end,
	SendChatMessage = function(text, channel) SendChatMessage(text, channel) end,
}
function UnitName() return "Anna" end
local states, infos = {}, {}
local timerUsed = 0
C_EncounterTimeline = {
	GetEventState = function(id) return states[id] end,
	GetEventList = function()
		local l = {}
		for id in pairs(infos) do l[#l + 1] = id end
		table.sort(l)
		return l
	end,
	GetEventInfo = function(id) return infos[id] end,
	GetEventTimeRemaining = function(id) return infos[id] and infos[id].left end,
	GetEventTimer = function() return { timer = true } end,
}
M.methods.SetTimerDuration = function() timerUsed = timerUsed + 1 end

M.load("ACore", "ACore")
local ns = M.load("ABoss", "ABoss")
event("PLAYER_LOGIN")
flush()

ok(ABossBars and ABossEmphasis and ABossMessages, "movable frames exist from login")
ok(#ACore.movers >= 3 and prefixes.ABoss, "movers and addon prefix registered")
local B = ns.Bars
local function tick(dt)
	now = now + dt
	B.Tick()
	ns.Messages.Tick()
end

ok(ns.Timeline.Available(), "timeline api seen")
ok(ns.Clock(75) == "1:15" and ns.Clock(3725) == "1:02:05", "clock")
ok(ns.Timers.Seconds("1:30") == 90 and ns.Timers.Seconds("2m") == 120 and ns.Timers.Seconds("45") == 45 and not ns.Timers.Seconds("x"), "seconds")

states[1] = 0
event("ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 1, source = 0, duration = 20, spellName = "Flame Breath", iconFileID = 135805, severity = 1 })
states[2] = 0
event("ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 2, source = 0, duration = 90, spellName = SECRET, iconFileID = SECRET, severity = 0, icons = 2 })
event("ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 3, source = 1, duration = 30, spellName = "Script" })
event("ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 4, source = 2, duration = 30, spellName = "Edit" })
ok(#B.active == 2 and B.Has("tl1") and B.Has("tl2") and not B.Has("tl3"), "timeline bars " .. #B.active)
ok(B.byId.tl1.color == 1 and B.byId.tl2.color == 2, "severity colours")
ok(B.byId.tl2.frame.left.__text == SECRET and B.byId.tl2.frame.icon:IsShown(), "secret name and icon passed to the widgets")
states[9] = 0
event("ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 9, source = 0, duration = 200, spellName = "Tank", severity = 1, icons = 128 })
ok(B.byId.tl9.color == 1 and not B.byId.tl9.frame.icon:IsShown(), "role icons keep the severity colour")
event("ENCOUNTER_TIMELINE_EVENT_REMOVED", 9)
ok(B.active[1].id == "tl1", "sorted by time left")
tick(5)
ok(math.abs(B.Remaining("tl1") - 15) < 0.01, "remaining")
states[1] = 1
event("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", 1)
tick(10)
ok(B.byId.tl1.paused and math.abs(B.Remaining("tl1") - 15) < 0.01, "paused holds")
states[1] = 0
event("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", 1)
tick(8)
ok(B.byId.tl1.emph and not B.byId.tl2.emph, "emphasised near the end")
tick(8)
ok(not B.Has("tl1"), "expired bar removed")
states[2] = 3
event("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", 2)
ok(not B.Has("tl2"), "cancelled")

states[5] = 0
event("ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 5, source = 0, duration = SECRET, spellName = SECRET, iconFileID = SECRET, severity = SECRET, icons = SECRET })
ok(B.Has("tl5") and B.byId.tl5.secret and timerUsed == 1, "secret duration uses the timer object")
tick(50)
ok(B.Has("tl5"), "secret bar waits for removal")
event("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", SECRET)
event("ENCOUNTER_TIMELINE_EVENT_REMOVED", SECRET)
event("ENCOUNTER_TIMELINE_EVENT_REMOVED", 5)
ok(#B.active == 0, "removed")
event("ENCOUNTER_TIMELINE_EVENT_ADDED", nil)
event("ENCOUNTER_TIMELINE_EVENT_ADDED", { source = 0 })

infos[7] = { id = 7, source = 0, duration = 40, spellName = "Late", left = 12 }
states[7] = 0
infos[8] = { id = 8, source = 0, duration = 40, spellName = "Held", left = 30 }
states[8] = 1
event("ENCOUNTER_START", 610, "Ragnaros", 9, 40)
ok(ns.History.Current() and ns.History.Current().name == "Ragnaros", "encounter started")
ok(B.Has("tl7") and math.abs(B.Remaining("tl7") - 12) < 0.01 and B.byId.tl8.paused, "sync on start")
infos = {}

local before = sounds
event("ENCOUNTER_WARNING", { text = SECRET, severity = 2, shouldShowWarning = true, shouldPlaySound = true })
ok(sounds == before + 1 and ABossMessages, "warning shown with sound")
local lastText
local oldSet = M.methods.SetText
M.methods.SetText = function(self, t) lastText = t oldSet(self, t) end
event("ENCOUNTER_WARNING", { text = "%s casts Fear on %s", casterName = "Boss", targetName = "Anna", severity = 1, shouldPlaySound = false })
ok(lastText == "Boss casts Fear on Anna", "warning text formatted " .. tostring(lastText))
event("ENCOUNTER_WARNING", { text = "Run away", severity = 1, shouldPlaySound = false })
ok(lastText == "Run away", "plain warning text")
event("ENCOUNTER_WARNING", { text = "50% left", severity = 1, shouldPlaySound = false })
ok(lastText == "50% left", "unformattable warning kept")
M.methods.SetText = oldSet
event("ENCOUNTER_WARNING", { text = "Quiet", severity = 0, shouldPlaySound = false })
ok(sounds == before + 1, "quiet warning")
event("ENCOUNTER_WARNING", { text = "Hidden", shouldShowWarning = false })
event("ENCOUNTER_WARNING", { text = "x", severity = SECRET, shouldShowWarning = SECRET, shouldPlaySound = SECRET })
event("ENCOUNTER_WARNING", nil)
ns.db.warnings = false
event("ENCOUNTER_WARNING", { text = "Off", severity = 1 })
ok(sounds == before + 2, "warnings can be turned off")
ns.db.warnings = true
tick(3)
tick(1)
tick(2)

tick(180)
local n = #printed
event("ENCOUNTER_END", 610, "Ragnaros", 9, 40, 1)
local rec = ns.db.history[610]
ok(rec and rec.kills == 1 and rec.wipes == 0 and rec.best and rec.best > 180, "kill recorded")
ok(#printed > n and printed[#printed]:find("defeated in"), "kill message")
ok(not B.Has("tl7") and not ns.History.Current(), "bars cleared at the end")
event("ENCOUNTER_START", 610, "Ragnaros", 9, 40)
tick(60)
event("ENCOUNTER_END", 610, "Ragnaros", 9, 40, 0)
ok(rec.wipes == 1 and printed[#printed]:find("Wipe on Ragnaros after 1:00"), "wipe recorded")
event("ENCOUNTER_START", 610, "Ragnaros", 9, 40)
tick(100)
event("ENCOUNTER_END", 610, "Ragnaros", 9, 40, 1)
ok(rec.kills == 2 and math.abs(rec.best - 100) < 0.01 and printed[#printed]:find("new best"), "best time")
event("ENCOUNTER_START", SECRET, SECRET)
event("ENCOUNTER_END", SECRET, SECRET, 0, 0, SECRET)
event("ENCOUNTER_END", 611, "Unknown", 1, 5, 1)
ok(ns.db.history[611].kills == 1 and not ns.db.history[611].best, "end without start")

SlashCmdList["ABOSSPULL"]("")
ok(B.Has("pull") and #countdowns == 0 and #chat == 0, "solo pull")
tick(6)
tick(1)
tick(1)
tick(1)
tick(1.5)
ok(not B.Has("pull"), "pull finished")
grouped = true
SlashCmdList["ABOSSPULL"]("8")
ok(B.Has("pull") and countdowns[1] == 8, "group pull uses the game countdown")
event("START_PLAYER_COUNTDOWN", "guid", 8, 8)
ok(math.abs(B.Remaining("pull") - 8) < 0.01, "own countdown not doubled")
SlashCmdList["ABOSSPULL"]("0")
ok(not B.Has("pull") and countdowns[#countdowns] == 0 and chat[#chat] == "PARTY:Pull cancelled", "pull cancel")
tick(5)
event("START_PLAYER_COUNTDOWN", "guid", 6, 10)
ok(B.Has("pull") and math.abs(B.Remaining("pull") - 6) < 0.01, "countdown from someone else")
event("CANCEL_PLAYER_COUNTDOWN")
ok(not B.Has("pull"), "countdown cancelled")
event("START_PLAYER_COUNTDOWN", "guid", SECRET, SECRET)
C_PartyInfo.DoCountdown = nil
SlashCmdList["ABOSSPULL"]("5")
ok(chat[#chat] == "PARTY:Pull in 5", "pull announced in chat")
SlashCmdList["ABOSSPULL"]("abc")
SlashCmdList["ABOSSPULL"]("0")

SlashCmdList["ABOSSBREAK"]("2")
ok(B.Has("break") and math.abs(B.Remaining("break") - 120) < 0.01 and chat[#chat] == "PARTY:Break for 2 min", "break")
tick(118)
ok(not B.byId["break"].emph, "break bar stays small")
tick(3)
ok(not B.Has("break") and chat[#chat] == "PARTY:Break is over", "break over")
SlashCmdList["ABOSSBREAK"]("")
SlashCmdList["ABOSSBREAK"]("0")
ok(not B.Has("break") and chat[#chat] == "PARTY:Break cancelled", "break cancel")
SlashCmdList["ABOSSBREAK"]("x")
ok(addonSent[1] == "ABoss:break 120:PARTY" and addonSent[#addonSent] == "ABoss:break 0:PARTY", "break shared with the group")
local shared, said = #addonSent, #chat
event("CHAT_MSG_ADDON", "ABoss", "break 90", "PARTY", "Bertil-Realm")
ok(B.Has("break") and math.abs(B.Remaining("break") - 90) < 0.01 and #addonSent == shared and #chat == said, "break received from the group")
event("CHAT_MSG_ADDON", "ABoss", "break 0", "PARTY", "Bertil-Realm")
ok(not B.Has("break"), "break cancel received")
event("CHAT_MSG_ADDON", "ABoss", "break 60", "PARTY", "Anna-Realm")
event("CHAT_MSG_ADDON", "Other", "break 60", "PARTY", "Bertil")
event("CHAT_MSG_ADDON", "ABoss", "break 60", "WHISPER", "Bertil")
event("CHAT_MSG_ADDON", "ABoss", "nonsense", "PARTY", "Bertil")
event("CHAT_MSG_ADDON", SECRET, SECRET, SECRET, SECRET)
ok(not B.Has("break"), "own, foreign and malformed messages ignored")
ns.db.sync = false
event("CHAT_MSG_ADDON", "ABoss", "break 60", "PARTY", "Bertil")
ok(not B.Has("break"), "sync can be turned off")
ns.db.sync = true
combat = true
local sent = #chat
SlashCmdList["ABOSSBREAK"]("1")
ok(#chat == sent, "no chat in combat")
combat = false
B.StopAll()

SlashCmdList["ABOSSBAR"]("1:30 Adds spawn")
SlashCmdList["ABOSSBAR"]("20")
SlashCmdList["ABOSSBAR"]("nope")
SlashCmdList["ABOSSBAR"]("")
ok(#B.active == 2 and B.active[1].text == "Timer" and B.active[2].text == "Adds spawn", "custom bars")
tick(95)
ok(#B.active == 0, "custom bars end")

event("READY_CHECK", "Leader", 30)
ok(B.Has("ready"), "ready check bar")
event("READY_CHECK_FINISHED")
ok(not B.Has("ready"), "ready check done")
ns.db.readycheck = false
event("READY_CHECK", "Leader", 30)
ok(not B.Has("ready"), "ready check off")

SlashCmdList["ABOSS"]("test")
flush()
ok(#B.active == 5, "test bars")
SlashCmdList["ABOSS"]("unlock")
ok(ABossBars and ABossEmphasis and not ns.db.locked and ABossBars.handle:IsShown(), "unlocked")
for _, f in ipairs({ ABossBars.handle, ABossEmphasis.handle, ABossMessages.handle }) do
	f.__scripts.OnDragStart(f)
	f.__scripts.OnDragStop(f)
end
ok(ns.db.normal.pos, "anchor position saved")
SlashCmdList["ABOSS"]("lock")
ok(ns.db.locked and not ABossBars.handle:IsShown(), "locked")
ns.db.grow = "UP"
B.Apply()
for _ = 1, 3 do
	for _, e in ipairs(ns.OptionEntries()) do
		if e.func then e.func() end
	end
end
SlashCmdList["ABOSS"]("")
SlashCmdList["ABOSS"]("reset")
ok(not ns.db.normal.pos, "reset")
SlashCmdList["ABOSS"]("stop")
ok(#B.active == 0, "stop")
ns.db.bars = true
ns.db.emphasize = true

if ABossHistory and ABossHistory:IsShown() then SlashCmdList["ABOSS"]("history") end
SlashCmdList["ABOSS"]("history")
local frame = ABossHistory
ok(frame and frame:IsShown() and #frame.list.data == 2, "history window")
for _, row in ipairs(frame.list.rows) do
	if row:IsShown() and row.data then row.__scripts.OnClick(row, "RightButton") end
end
ns.db.history[611] = nil
ns.History.Refresh()
ok(#frame.list.data == 1, "forget boss")
SlashCmdList["ABOSS"]("history")
ok(not frame:IsShown(), "history closes")

ns.db.bars = false
ok(B.Start("x", "x", 5) == nil, "bars off")
ns.db.bars = true
ok(B.Start("zero", "x", 0) == nil, "zero duration ignored")
for _, f in ipairs(M.frames) do
	local fn = f.__scripts.OnUpdate
	if fn then fn(f, 1) end
end
local listed
for _, a in ipairs(ACore.addons) do
	if a.name == "ABoss" then listed = a end
end
ok(listed and #listed.options() > 15, "registered with options")
listed.toggle()

print_real(string.format("ok: %d checks", M.checks()))
