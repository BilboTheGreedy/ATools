local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

local SECRET = {}
function issecretvalue(v) return v == SECRET end

function M.methods:HookScript(name, fn)
	self.__hooks = self.__hooks or {}
	self.__hooks[name] = fn
end
function M.methods:SetAttribute(k, v) self.__attr = self.__attr or {} self.__attr[k] = v end
function M.methods:GetAttribute(k) return self.__attr and self.__attr[k] end
function M.methods:GetFrameLevel() return 1 end
function M.methods:SetAlpha(a) self.__alpha = a end

local hooks = {}
function hooksecurefunc(name, fn) hooks[name] = fn end
function SetItemRef() end
function FCF_OpenTemporaryWindow() end
local filters = {}
ChatFrameUtil = { AddMessageEventFilter = function(ev, fn) filters[ev] = fn end, SendTell = function(name) M.tell = name end }
local sent = {}
C_ChatInfo = { SendChatMessage = function(msg, kind, _, target) sent[#sent + 1] = { msg, kind, target } end }
local invited
C_PartyInfo = { InviteUnit = function(name) invited = name end }
C_FriendList = {
	GetNumWhoResults = function() return 1 end,
	GetWhoInfo = function() return { fullName = "Whoguy-Realm", level = 33 } end,
}
ChatTypeInfo = {}
for _, k in ipairs({ "SAY", "YELL", "PARTY", "RAID", "GUILD", "OFFICER", "WHISPER", "CHANNEL", "CHANNEL1", "EMOTE" }) do ChatTypeInfo[k] = {} end
local colored = {}
function SetChatColorNameByClass(kind, on) colored[kind] = on end
local cvars = {}
function SetCVar(k, v) cvars[k] = v end
local now = 100
function GetTime() return now end
local sounds = 0
function PlaySound() sounds = sounds + 1 end
SOUNDKIT = { TELL_MESSAGE = 3081, RAID_WARNING = 8959 }
local combat = false
function InCombatLockdown() return combat end
function UnitName(u)
	if u == "player" then return "Daniel" end
	if u == "target" then return "Targetguy" end
	if u == "party1" then return "Partyguy" end
	return nil
end
function GetUnitName(u) return UnitName(u) end
function UnitExists(u) return UnitName(u) ~= nil end
function UnitIsPlayer() return true end
function UnitLevel(u) return u == "party1" and 42 or 60 end
function GetNumGroupMembers() return 1 end
function IsInRaid() return false end
function IsInGroup() return true end
function IsInGuild() return true end
function GetNumGuildMembers() return 2 end
function GetGuildRosterInfo(i) return i == 1 and "Guildie-Realm" or "Other", "", 0, 20 + i end
function ChatEdit_GetActiveWindow() return nil end

NUM_CHAT_WINDOWS = 3
local frames = {}
for i = 1, 3 do
	local f = M.obj("ScrollingMessageFrame")
	local name = "ChatFrame" .. i
	f.GetName = function() return name end
	f.messages = {}
	f.AddMessage = function(self, text) self.messages[#self.messages + 1] = text end
	f.GetNumMessages = function(self) return #self.messages end
	f.GetMessageInfo = function(self, n) return self.messages[n] end
	f.GetMaxLines = function() return 128 end
	f.SetMaxLines = function(self, n) self.max = n end
	f.SetFading = function(self, v) self.fading = v end
	f.SetTimeVisible = function(self, v) self.visible = v end
	f.ScrollToTop = function(self) self.scrolled = "top" end
	f.ScrollToBottom = function(self) self.scrolled = "bottom" end
	f.PageUp = function(self) self.scrolled = "pageup" end
	f.PageDown = function(self) self.scrolled = "pagedown" end
	_G[name] = f
	frames[i] = f
	local eb = M.obj("EditBox")
	eb.GetName = function() return name .. "EditBox" end
	eb.SetAltArrowKeyMode = function(self, v) self.alt = v end
	eb.SetHistoryLines = function(self, n) self.history = n end
	_G[name .. "EditBox"] = eb
	_G[name .. "Tab"] = M.obj("Button")
	_G[name .. "ButtonFrame"] = M.obj("Frame")
end
COMBATLOG = frames[2]
function IsCombatLog(f) return f == frames[2] end
SELECTED_CHAT_FRAME = frames[1]
ChatFrameMenuButton = M.obj("Button")
ChatFrameChannelButton = M.obj("Button")

M.load("ACore", "ACore")
local ns = M.load("AChat", "AChat")
event("PLAYER_LOGIN")
flush()

ok(ns.db and ns.playerName == "Daniel", "login")
ok(filters.CHAT_MSG_SAY and filters.CHAT_MSG_WHISPER and filters.CHAT_MSG_CHANNEL, "filters registered")
ok(colored.SAY == true and ChatTypeInfo.WHISPER.sticky == 1, "class colours and sticky")
ok(cvars.showTimestamps == "%H:%M " and cvars.whisperMode == "inline", "cvars")
ok(frames[1].fading == true and frames[1].visible == 120 and frames[1].max == 500, "fade and lines")
ok(frames[2].fading == nil, "combat log untouched")
ok(ChatFrame1EditBox.alt == false and ChatFrame1EditBox.history == 100, "edit box")
ok(not ChatFrameMenuButton:IsShown() and not ChatFrame1ButtonFrame:IsShown(), "buttons hidden")
ChatFrameMenuButton.__shown = true
ChatFrameMenuButton.__hooks.OnShow(ChatFrameMenuButton)
ok(not ChatFrameMenuButton:IsShown(), "button stays hidden")

ok(ns.levels.Partyguy == 42 and ns.levels.Guildie == 21 and ns.levels.Daniel == 60, "level cache")
event("WHO_LIST_UPDATE")
event("PLAYER_TARGET_CHANGED")
event("UPDATE_MOUSEOVER_UNIT")
event("GROUP_ROSTER_UPDATE")
event("GUILD_ROSTER_UPDATE")
event("PLAYER_LEVEL_UP", 61)
flush()
ok(ns.levels.Whoguy == 33 and ns.levels.Targetguy == 60 and ns.levels.Daniel == 61, "who and target levels")

local f1 = frames[1]
f1:AddMessage("|Hchannel:GUILD|h[Guild]|h |Hplayer:Guildie-Realm:12:GUILD|h[Guildie]|h: hello")
ok(f1.messages[1] == "|Hchannel:GUILD|h[G]|h |Hplayer:Guildie-Realm:12:GUILD|h[21:Guildie]|h: hello", "short guild " .. f1.messages[1])
f1:AddMessage("|Hchannel:CHANNEL:2|h[2. Trade - City]|h |Hplayer:Nobody:13:CHANNEL:2|h[Nobody]|h: wts")
ok(f1.messages[2] == "|Hchannel:CHANNEL:2|h[2]|h |Hplayer:Nobody:13:CHANNEL:2|h[Nobody]|h: wts", "short numbered " .. f1.messages[2])
f1:AddMessage("|Hchannel:PARTY|h[Party Leader]|h x")
ok(f1.messages[3] == "|Hchannel:PARTY|h[PL]|h x", "party leader " .. f1.messages[3])
f1:AddMessage("|Hchannel:WEIRD|h[Weird]|h x")
ok(f1.messages[4] == "|Hchannel:WEIRD|h[Weird]|h x", "unknown channel kept")
f1:AddMessage(SECRET)
ok(f1.messages[5] == SECRET, "secret text untouched")
f1:AddMessage(nil)
f1:AddMessage(12)
frames[2]:AddMessage("|Hchannel:GUILD|h[Guild]|h x")
ok(frames[2].messages[1] == "|Hchannel:GUILD|h[Guild]|h x", "combat log not wrapped")

local function run(ev, msg, sender, line)
	return filters[ev](f1, ev, msg, sender, "", "", "", "", 0, 0, "", 0, line, "Player-1-0001")
end
local drop, out = run("CHAT_MSG_SAY", "see https://example.com/a?b=1, and www.test.org.", "Bob-Realm", 1)
ok(drop == false and out:find("|Haddon:achat:https://example.com/a?b=1|h[https://example.com/a?b=1]|h|r,", 1, true), "url " .. tostring(out))
ok(out:find("|Haddon:achat:www.test.org|h", 1, true) and out:sub(-1) == ".", "www url")
local d2, o2 = run("CHAT_MSG_SAY", "see https://example.com/a?b=1, and www.test.org.", "Bob-Realm", 1)
ok(d2 == false and o2 == out, "same line cached for second frame")
local d3 = run("CHAT_MSG_SAY", "see https://example.com/a?b=1, and www.test.org.", "Bob-Realm", 2)
ok(d3 == true, "repeat dropped")
now = now + 30
local d4 = run("CHAT_MSG_SAY", "see https://example.com/a?b=1, and www.test.org.", "Bob-Realm", 3)
ok(d4 == false, "repeat allowed after window")
local d5, o5 = run("CHAT_MSG_GUILD", "no links here. really", "Bob-Realm", 4)
ok(d5 == false and o5 == nil, "plain message untouched")
local d6 = run("CHAT_MSG_GUILD", "same", "Bob-Realm", 5)
local d7 = run("CHAT_MSG_GUILD", "same", "Bob-Realm", 6)
ok(d6 == false and d7 == false, "guild is not spam filtered")
local d8, o8 = run("CHAT_MSG_SAY", "item |cff0070dd|Hitem:1234|h[Thing.com]|h|r here", "Al", 7)
ok(d8 == false and o8 == nil, "item links left alone")
ok(run("CHAT_MSG_SAY", SECRET, "Bob", 8) == false, "secret message untouched")
ok(run("CHAT_MSG_SAY", "hi", SECRET, 9) == false, "secret sender untouched")

sounds = 0
local _, o9 = run("CHAT_MSG_GUILD", "hey DANIEL come here", "Bob-Realm", 10)
ok(o9 == "hey |cffffd100DANIEL|r come here" and sounds == 1, "name highlight " .. tostring(o9))
ns.AddKeyword("LFM")
ns.AddKeyword("lfm")
ok(#ns.db.keywords == 1, "keyword added once")
local _, o10 = run("CHAT_MSG_CHANNEL", "Lfm strat need tank", "Carl", 11)
ok(o10 == "|cffffd100Lfm|r strat need tank", "keyword highlight " .. tostring(o10))
local _, o11 = run("CHAT_MSG_GUILD", "daniel is me", "Daniel-Realm", 12)
ok(o11 == nil, "own messages not highlighted")
sounds = 0
run("CHAT_MSG_WHISPER", "psst", "Bob-Realm", 13)
ok(sounds == 1, "whisper sound")
ns.RemoveKeyword("lfm")
ok(#ns.db.keywords == 0, "keyword removed")
ns.SetKeywords("a.b, Tank ,  ")
ok(#ns.db.keywords == 2 and ns.db.keywords[2] == "tank", "keywords set")
local _, o12 = run("CHAT_MSG_CHANNEL", "need a.b now, axb no", "Carl", 14)
ok(o12 == "need |cffffd100a.b|r now, axb no", "keyword with punctuation " .. tostring(o12))
for i = 1, 700 do run("CHAT_MSG_SAY", "msg " .. i, "Flood", 100 + i) end

ok(ns.Plain("|cffff0000|Hitem:1|h[Sword]|h|r |TInterface\\x:0|t a||b") == "[Sword]  a|b", "plain text")
f1.messages = { "|cff00ff00one|r", SECRET, "two" }
local n = ns.ShowCopy(f1)
ok(n == 2 and AChatCopy:IsShown() and AChatCopy.box:GetText() == "one\ntwo", "copy window")
flush()
AChatCopy.scroll.__scripts.OnMouseWheel(AChatCopy.scroll, 1)
AChatCopy.scroll.__scripts.OnMouseDown(AChatCopy.scroll)
AChatCopy.box.__scripts.OnEscapePressed(AChatCopy.box)

local prompts = 0
StaticPopup_Show = function() prompts = prompts + 1 end
hooks.SetItemRef("addon:achat:https://example.com", "x", "LeftButton")
ok(prompts == 1, "url popup")
hooks.SetItemRef("player:Bob-Realm:1:SAY", "x", "LeftButton")
ok(invited == nil, "no invite without alt")
M.mods.alt = true
hooks.SetItemRef("player:Bob-Realm:1:SAY", "x", "LeftButton")
M.mods.alt = false
ok(invited == "Bob-Realm", "alt invite")
hooks.SetItemRef(SECRET, "x", "LeftButton")
hooks.FCF_OpenTemporaryWindow()

M.mods.shift = true
f1.__hooks.OnMouseWheel(f1, 1)
ok(f1.scrolled == "top", "shift wheel up")
f1.__hooks.OnMouseWheel(f1, -1)
ok(f1.scrolled == "bottom", "shift wheel down")
M.mods.shift = false
M.mods.ctrl = true
f1.__hooks.OnMouseWheel(f1, 1)
ok(f1.scrolled == "pageup", "ctrl wheel")
f1.__hooks.OnMouseWheel(f1, -1)
M.mods.ctrl = false
f1.__hooks.OnMouseWheel(f1, 1)

local tips = 0
local oldOwner = M.methods.SetOwner
M.methods.SetOwner = function() tips = tips + 1 end
f1.__hooks.OnHyperlinkEnter(f1, "item:1234")
f1.__hooks.OnHyperlinkLeave(f1)
f1.__hooks.OnHyperlinkEnter(f1, "player:Bob")
f1.__hooks.OnHyperlinkEnter(f1, SECRET)
f1.__hooks.OnHyperlinkLeave(f1)
M.methods.SetOwner = oldOwner
ok(tips == 1, "hover tooltip only for item links")

local eb = ChatFrame1EditBox
eb:SetAttribute("chatType", "SAY")
eb.__hooks.OnTabPressed(eb)
ok(eb:GetAttribute("chatType") == "PARTY", "tab cycles to party")
eb.__hooks.OnTabPressed(eb)
ok(eb:GetAttribute("chatType") == "GUILD", "tab skips raid " .. tostring(eb:GetAttribute("chatType")))
M.mods.shift = true
eb.__hooks.OnTabPressed(eb)
M.mods.shift = false
ok(eb:GetAttribute("chatType") == "PARTY", "shift tab goes back")
eb:SetText("/w bob")
eb.__hooks.OnTabPressed(eb)
ok(eb:GetAttribute("chatType") == "PARTY", "tab ignored with text")
eb:SetText("")
eb:SetAttribute("chatType", "WHISPER")
eb.__hooks.OnTabPressed(eb)
ok(eb:GetAttribute("chatType") == "WHISPER", "tab ignored in whisper")

SlashCmdList["ACHATTT"]("hello there")
ok(sent[1] and sent[1][2] == "WHISPER" and sent[1][3] == "Targetguy", "tell target")
SlashCmdList["ACHATTT"]("")
ok(M.tell == "Targetguy", "tell target opens whisper")
local cleared
f1.Clear = function() cleared = true end
SlashCmdList["ACHATCLEAR"]()
ok(cleared, "clear")

local copy
for _, f in ipairs(M.frames) do
	if f.__parent == f1 and f.__scripts.OnClick and f.label then copy = f end
end
ok(copy, "copy button exists")
copy.__scripts.OnEnter(copy)
copy.__scripts.OnLeave(copy)
copy.__scripts.OnClick(copy, "LeftButton")
copy.__scripts.OnClick(copy, "RightButton")

local function walk(depth)
	local seen = 0
	local entries = {}
	local oldMenu = ACore.UI.Menu
	ACore.UI.Menu = function(_, e) entries = e end
	ns.OpenOptions()
	local top = entries
	for _, e in ipairs(top) do
		if e.func and e.text ~= "Copy this chat window" then
			e.func()
			seen = seen + 1
			if entries ~= top then
				local sub = entries
				for _, s in ipairs(sub) do
					if s.func then s.func() seen = seen + 1 end
				end
				entries = top
			end
		end
	end
	ACore.UI.Menu = oldMenu
	return seen
end
ok(walk() > 40, "options walked")
flush()

combat = true
ns.db.hideButtons = true
ns:Fire("OPTIONS")
ok(ns.pendingButtons, "button change deferred in combat")
combat = false
event("PLAYER_REGEN_ENABLED")
ok(not ns.pendingButtons, "applied after combat")

ns.db.editTop = true
ns.db.shorten = false
ns.db.levels = false
ns:Fire("OPTIONS")
f1.messages = {}
f1:AddMessage("|Hchannel:GUILD|h[Guild]|h x")
ok(f1.messages[1] == "|Hchannel:GUILD|h[Guild]|h x", "formatting off")
ns.db.editTop = false
ns:Fire("OPTIONS")

SlashCmdList["ACHAT"]("")
SlashCmdList["ACHAT"]("copy")
SlashCmdList["ACHAT"]("add raid")
SlashCmdList["ACHAT"]("keywords")
SlashCmdList["ACHAT"]("remove raid")
SlashCmdList["ACORE"]("chat")

print_real(string.format("ok: %d checks", M.checks()))
