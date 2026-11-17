local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

local SECRET = {}
function issecretvalue(v) return v == SECRET end
local clock = 100
function GetTime() return clock end
local me = { level = 20, xp = 1000, xpMax = 10000, rested = 3000, money = 50000 }
function UnitLevel() return me.level end
function UnitXP() return me.xp end
function UnitXPMax() return me.xpMax end
function GetXPExhaustion() return me.rested end
function GetMoney() return me.money end
function GetMaxPlayerLevel() return 60 end
local factions = {
	{ name = "Stormwind", factionID = 72, reaction = 5, currentStanding = 4000, currentReactionThreshold = 3000, nextReactionThreshold = 9000, isWatched = true },
	{ name = "Argent Dawn", factionID = 529, reaction = 4, currentStanding = 500, currentReactionThreshold = 0, nextReactionThreshold = 3000 },
}
local watchedIndex = 1
C_Reputation = {
	GetWatchedFactionData = function() return factions[watchedIndex] end,
	GetNumFactions = function() return #factions end,
	GetFactionDataByIndex = function(i) return factions[i] end,
	SetWatchedFactionByID = function(id)
		for i, f in ipairs(factions) do
			f.isWatched = f.factionID == id
			if f.isWatched then watchedIndex = i end
		end
	end,
}
MainMenuExpBar = M.obj("Frame")
local alpha
function MainMenuExpBar:SetAlpha(a) alpha = a end
local expMouse = true
function MainMenuExpBar:IsMouseEnabled() return expMouse end
function MainMenuExpBar:EnableMouse(on) expMouse = on end
function hooksecurefunc(t, name, fn)
	local orig = t[name]
	t[name] = function(...)
		orig(...)
		fn(...)
	end
end
local chatText
function ChatEdit_InsertLink() return false end
function ChatFrame_OpenChat(text) chatText = text end
local bars = {}
function M.methods:SetMinMaxValues(lo, hi) self.__min, self.__max = lo, hi end
function M.methods:SetValue(v) self.__value = v end
local tip = {}
function M.methods:AddDoubleLine(l, r) tip[#tip + 1] = tostring(l) .. "=" .. tostring(r) end

M.load("ACore", "ACore")
local ns = M.load("AXP", "AXP")
event("PLAYER_LOGIN")
flush()

local T = ns.Track
local frame = AXPFrame
ok(frame and frame:IsShown() and frame.xp:IsShown() and frame.rep:IsShown(), "bars shown")
ok(frame.xp.__max == 10000 and frame.xp.__value == 1000, "xp values")
ok(frame.xp.rested:IsShown(), "rested overlay")
ok(frame.xp.left.__text:find("Level 20") and frame.xp.left.__text:find("10%%"), "xp text " .. frame.xp.left.__text)
ok(frame.xp.right.__text == "rested 30%", "rested text " .. frame.xp.right.__text)
ok(frame.rep.__max == 6000 and frame.rep.__value == 1000 and frame.rep.left.__text:find("Stormwind   Friendly   1000 / 6000"), "rep text " .. frame.rep.left.__text)
ok(ns.Time(3700) == "1h 1m" and ns.Time(90) == "1m" and ns.Time(5) == "5s" and ns.Time(nil) == "-" and ns.Time(math.huge) == "-" and ns.Time(400000) == "4d", "time format")

clock = clock + 1800
me.xp = 3000
event("PLAYER_XP_UPDATE")
event("CHAT_MSG_COMBAT_XP_GAIN", "Kobold dies, you gain 200 experience.")
event("CHAT_MSG_COMBAT_XP_GAIN", "Kobold dies, you gain 1,200 experience. (+600 Rested bonus)")
event("CHAT_MSG_COMBAT_XP_GAIN", SECRET)
event("QUEST_TURNED_IN", 5, 1400, 0)
event("QUEST_TURNED_IN", 6, SECRET, 0)
flush()
local s = T.Session()
ok(s.xp == 2000 and s.kills == 3, "session xp " .. s.xp)
ok(T.Rate() == 4000, "rate " .. T.Rate())
local e = T.Estimate()
ok(e.left == 7000 and e.seconds == 6300 and e.kills == 10 and e.quests == 5, "estimate " .. tostring(e.kills) .. " " .. tostring(e.quests))
ok(frame.xp.right.__text == "4000/h   1h 45m", "rate text " .. frame.xp.right.__text)

me.money = 80000
event("PLAYER_MONEY")
me.money = 70000
event("PLAYER_MONEY")
ok(s.earned == 30000 and s.spent == 10000, "money")

factions[1].currentStanding = 4600
event("UPDATE_FACTION")
flush()
local rep = T.Rep()
ok(rep.gained == 600 and rep.rate == 1200 and rep.left == 4400, "rep rate " .. rep.rate)
ok(frame.rep.right.__text:find("1200/h"), "rep rate text " .. frame.rep.right.__text)

event("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Argent Dawn increased by 25.")
flush()
ok(watchedIndex == 2 and frame.rep.left.__text:find("Argent Dawn"), "followed faction")
ns.db.autoRep = false
event("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Stormwind increased by 25.")
event("CHAT_MSG_COMBAT_FACTION_CHANGE", SECRET)
flush()
ok(watchedIndex == 2, "follow off")
ns.db.autoRep = true
factions[1].currentStanding = 4700
factions[2].currentStanding = 520
event("UPDATE_FACTION")
flush()
ok(watchedIndex == 1, "follows the biggest gain without chat text")
factions[2].currentStanding = 560
event("UPDATE_FACTION")
flush()
ok(watchedIndex == 2 and s.reps["Argent Dawn"].gained == 60, "unwatched gains counted " .. s.reps["Argent Dawn"].gained)
ns.db.autoRep = false
clock = clock + 10
event("CHAT_MSG_COMBAT_XP_GAIN", SECRET)
me.xp = 3300
event("PLAYER_XP_UPDATE")
ok(s.kills == 4 and #s.killXP == 3 and s.killXP[3] == 300, "unreadable kill uses xp diff")
clock = clock + 10
me.xp = 3500
event("PLAYER_XP_UPDATE")
event("CHAT_MSG_COMBAT_XP_GAIN", SECRET)
ok(s.kills == 5 and s.killXP[4] == 200, "xp diff before unreadable kill")
event("QUEST_TURNED_IN", 7, 0, 0)
me.xp = 4000
event("PLAYER_XP_UPDATE")
event("CHAT_MSG_COMBAT_XP_GAIN", SECRET)
ok(s.kills == 6 and #s.killXP == 4, "quest xp is not a kill")
clock = clock + 10
me.xp = 3000
s.xp, s.kills, s.killXP = 2000, 2, { 200, 1200 }
event("PLAYER_XP_UPDATE")
s.xp = 2000
flush()
M.mods.shift = true
frame.xp.__scripts.OnMouseUp(frame.xp, "LeftButton")
M.mods.shift = false
ok(chatText and chatText:find("Level 20: 3000 / 10.0k XP (30%), 7000 to go", 1, true) and chatText:find("Argent Dawn: 560 / 3000", 1, true), "share " .. tostring(chatText))

clock = clock + 600
me.level, me.xp, me.xpMax = 21, 500, 12000
event("PLAYER_LEVEL_UP", 21)
flush()
ok(s.levels == 1 and s.xp == 2000 + 7000 + 500, "level wrap " .. s.xp)
ok(AXPToast and AXPToast.title.__text == "Level 21 reached", "toast")
ok(M.printed[#M.printed]:find("Level 21 reached"), "toast print")
clock = clock + 900
me.level, me.xp, me.xpMax = 22, 0, 13000
event("PLAYER_LEVEL_UP", 22)
flush()
ok(AXPToast.detail.__text == "That level took 15m", "level time " .. AXPToast.detail.__text)

local bar = frame.xp
tip = {}
bar.__scripts.OnEnter(bar)
bar.__scripts.OnLeave(bar)
ok(#tip >= 9, "tooltip lines " .. #tip)
local summary = T.Summary()
ok(#summary == 6 and summary[3][2] == "2" and summary[4][2] == "2", "summary")
bar.__scripts.OnMouseUp(bar, "RightButton")
bar.__scripts.OnMouseUp(bar, "LeftButton")
bar.__scripts.OnDragStart(bar)
bar.__scripts.OnDragStop(bar)

for _, mode in ipairs({ "percent", "none", "full" }) do
	ns.db.text = mode
	ns:Fire("OPTIONS")
end
ns.db.text = "percent"
ns.Bars.Refresh()
ok(frame.xp.right.__text == "0%" and frame.rep.right.__text:find("%%"), "percent mode")
ns.db.text = "none"
ns.Bars.Refresh()
ok(frame.xp.left.__text == "" and frame.rep.left.__text == "", "no text")
ns.db.text = "full"

ns.db.hideDefault = true
ns:Fire("OPTIONS")
ok(alpha == 0 and expMouse == false, "blizzard hidden")
MainMenuExpBar:SetAlpha(1)
ok(alpha == 0, "stays hidden when shown again")
ns.db.hideDefault = false
ns:Fire("OPTIONS")
ok(alpha == 1 and expMouse == true, "blizzard restored")
MainMenuExpBar:SetAlpha(0.5)
ok(alpha == 0.5, "left alone when off")
ns.db.hover = true
ns.Bars.Refresh()
local shown = {}
function frame.xp.left:SetAlpha(a) shown[#shown + 1] = a end
frame.xp.__scripts.OnEnter(frame.xp)
frame.xp.__scripts.OnLeave(frame.xp)
ok(shown[1] == 1 and shown[2] == 0, "text on mouseover only")
ns.db.hover = false
ok(#frame.xp.ticks == 9, "ticks")
me.level = SECRET
ns.Bars.Refresh()
ok(frame.xp.left.__text:find("Level %?"), "unreadable level")
me.level = 22

me.xp = SECRET
event("PLAYER_XP_UPDATE")
flush()
ns.Bars.Refresh()
ok(frame.xp.__value == SECRET and frame.xp.right.__text == "", "secret xp passed through")
me.xp = 100

me.level = 60
ns.Bars.Refresh()
ok(not frame.xp:IsShown() and frame.rep:IsShown(), "max level hides xp")
watchedIndex = 3
ns.Bars.Refresh()
ok(not frame:IsShown(), "nothing to show")
watchedIndex = 1
me.level = 22
ns.db.xp = false
ns.db.rep = false
ns.Bars.Refresh()
ok(not frame:IsShown(), "both off")
ns.db.xp, ns.db.rep = true, true

C_Reputation.GetWatchedFactionData = nil
function GetWatchedFactionInfo() return "Ironforge", 6, 9000, 21000, 12000, 47 end
ns.Bars.Refresh()
ok(frame.rep.left.__text:find("Ironforge   Honored   3000 / 12000"), "legacy watched faction " .. frame.rep.left.__text)
C_Reputation.GetNumFactions = nil
function GetNumFactions() return 1 end
function GetFactionInfo() return "Ironforge", "", 6, 9000, 21000, 12000, false, true, false, false, false, false, false, 47 end
local set
function SetWatchedFactionIndex(i) set = i end
C_Reputation.SetWatchedFactionByID = nil
ns.db.autoRep = true
event("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Ironforge increased by 10.")
ok(set == 1, "legacy follow")

for _, f in ipairs(M.frames) do
	local fn = f.__scripts.OnUpdate
	if fn then fn(f, 6) end
end
for _, entry in ipairs(ns.Options()) do
	if entry.func then entry.func() end
end
for _, cmd in ipairs({ "", "lock", "unlock", "reset", "report", "share", "session", "help" }) do
	SlashCmdList["AXP"](cmd)
end
flush()
ok(T.Session().xp == 0 and T.Session().kills == 0, "session reset")
event("UPDATE_EXHAUSTION")
event("PLAYER_UPDATE_RESTING")
event("PLAYER_ENTERING_WORLD")
flush()
ACoreMinimapButton.__scripts.OnClick(ACoreMinimapButton, "LeftButton")

print_real(string.format("ok: %d checks (axp)", M.checks()))
