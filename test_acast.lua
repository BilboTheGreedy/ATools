local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

local clock = 100
function GetTime() return clock end
function GetNetStats() return 0, 0, 40, 60 end
local SECRET = { secret = true }
function issecretvalue(v) return type(v) == "table" and v.secret == true end

function M.methods:SetValue(v) self.__value = v end
function M.methods:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function M.methods:SetAlpha(a) self.__alpha = a end
function M.methods:SetFormattedText(f, ...) self.__text = string.format(f, ...) end
function M.methods:SetTimerDuration(d, i, dir) self.__timer = { d, i, dir } end
function M.methods:SetStatusBarColor(r, g, b) self.__color = { r, g, b } end
function M.methods:SetTexture(t) self.__tex = t end
function M.methods:UnregisterAllEvents() self.__unregistered = true end
function M.methods:HookScript(name, fn) self.__hooks = self.__hooks or {} self.__hooks[name] = fn end

local casts, channels = {}, {}
function UnitCastingInfo(unit)
	local c = casts[unit]
	if not c then return nil end
	return c.name, c.name, c.icon or 1, c.s, c.e, false, c.id, c.shield, c.spell or 1
end
function UnitChannelInfo(unit)
	local c = channels[unit]
	if not c then return nil end
	return c.name, c.name, c.icon or 1, c.s, c.e, false, c.shield, c.spell or 1
end
function UnitCastingDuration() return { kind = "cast" } end
function UnitChannelDuration() return { kind = "channel" } end

PlayerCastingBarFrame = M.obj("Frame")
TargetFrameSpellBar = M.obj("Frame")

M.load("ACore", "ACore")
local ns = M.load("ACast", "ACast")
event("PLAYER_LOGIN")
event("PLAYER_ENTERING_WORLD")

local p, t = ACastPlayerBar, ACastTargetBar
ok(p and t, "bars created")
ok(not p:IsShown() and not t:IsShown(), "hidden when idle")
ok(PlayerCastingBarFrame.__unregistered and not PlayerCastingBarFrame:IsShown(), "default bar hidden")
PlayerCastingBarFrame.__shown = true
PlayerCastingBarFrame.__hooks.OnShow(PlayerCastingBarFrame)
ok(not PlayerCastingBarFrame:IsShown(), "default bar stays hidden")

local function tick(b, dt)
	clock = clock + (dt or 0)
	b.__scripts.OnUpdate(b, dt or 0)
end

event("UNIT_SPELLCAST_SENT", "player", "Target", "c1", 133)
clock = clock + 0.1
casts.player = { name = "Fireball", s = clock * 1000, e = (clock + 3) * 1000, id = "c1" }
event("UNIT_SPELLCAST_START", "player", "c1", 133)
ok(p:IsShown() and p.mode == "cast", "cast started")
ok(p.bar.left.__text == "Fireball", "cast name")
ok(math.abs(p.bar.__max - 3) < 0.001, "cast range")
ok(p.lag:IsShown() and math.abs(p.lagValue - 0.1) < 0.001, "latency zone from sent time")
tick(p, 1)
ok(math.abs(p.bar.__value - 1) < 0.001, "cast progress " .. tostring(p.bar.__value))
ok(p.bar.right.__text == "2.0 / 3.0", "time text " .. tostring(p.bar.right.__text))

casts.player.e = casts.player.e + 500
event("UNIT_SPELLCAST_DELAYED", "player", "c1", 133)
ok(math.abs(p.bar.__max - 3.5) < 0.001, "pushback extends the bar")
ok(math.abs(p.lagValue - 0.1) < 0.001, "pushback keeps latency")

event("UNIT_SPELLCAST_FAILED", "player", "other", 5)
ok(p.mode == "cast", "unrelated failure ignored")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "c1", 133)
casts.player = nil
event("UNIT_SPELLCAST_STOP", "player", "c1", 133)
ok(p.fade and not p.mode, "fades after success")
ok(p.bar.__color[2] > 0.8 and p.bar.__color[1] < 0.5, "success colour")
tick(p, 0.1)
ok(p.__alpha and p.__alpha < 1, "fading alpha")
tick(p, 1)
ok(not p:IsShown(), "hidden after fade")

casts.player = { name = "Frostbolt", s = clock * 1000, e = (clock + 2.5) * 1000, id = "c2" }
event("UNIT_SPELLCAST_START", "player", "c2", 116)
tick(p, 0.5)
casts.player = nil
event("UNIT_SPELLCAST_INTERRUPTED", "player", "c2", 116)
ok(p.bar.left.__text == "Interrupted" and p.fade, "interrupted flash")
ok(p.bar.__color[1] > 0.8 and p.bar.__color[2] < 0.3, "fail colour")
event("UNIT_SPELLCAST_STOP", "player", "c2", 116)
ok(p.bar.left.__text == "Interrupted", "stop after interrupt keeps flash")
tick(p, 2)
ok(not p:IsShown(), "hidden after interrupt")

casts.player = { name = "Heal", s = clock * 1000, e = (clock + 2) * 1000, id = "c3" }
event("UNIT_SPELLCAST_START", "player", "c3", 2054)
casts.player = nil
event("UNIT_SPELLCAST_STOP", "player", "c3", 2054)
event("UNIT_SPELLCAST_INTERRUPTED", "player", "c3", 2054)
ok(p.bar.left.__text == "Interrupted", "interrupt after stop still flashes")
tick(p, 2)

casts.player = { name = "Smite", s = clock * 1000, e = (clock + 2) * 1000, id = "c4" }
event("UNIT_SPELLCAST_START", "player", "c4", 585)
casts.player = nil
event("UNIT_SPELLCAST_FAILED", "player", "c4", 585)
ok(p.bar.left.__text == "Failed" and p.fade, "failed flash")
tick(p, 2)
event("UNIT_SPELLCAST_FAILED", "player", "c9", 585)
ok(not p:IsShown(), "failure while idle ignored")

channels.player = { name = "Arcane Missiles", s = clock * 1000, e = (clock + 5) * 1000 }
event("UNIT_SPELLCAST_CHANNEL_START", "player", nil, 5143)
ok(p.mode == "channel", "channel started")
tick(p, 1)
ok(math.abs(p.bar.__value - 4) < 0.001, "channel drains " .. tostring(p.bar.__value))
channels.player.e = channels.player.e - 1000
event("UNIT_SPELLCAST_CHANNEL_UPDATE", "player", nil, 5143)
ok(math.abs(p.bar.__max - 4) < 0.001, "channel pushback")
tick(p, 0.5)
ok(math.abs(p.bar.__value - 2.5) < 0.001, "channel after pushback")
channels.player = nil
event("UNIT_SPELLCAST_CHANNEL_STOP", "player", nil, 5143)
ok(p.fade, "channel stop fades")
tick(p, 1)
ok(not p:IsShown(), "channel hidden")

channels.player = { name = "Drain Life", s = clock * 1000, e = (clock + 1) * 1000 }
event("UNIT_SPELLCAST_CHANNEL_START", "player", nil, 689)
channels.player = nil
tick(p, 1.2)
ok(p.fade, "channel ends on its own")
tick(p, 1)

casts.player = { name = "Hearthstone", s = clock * 1000, e = (clock + 1) * 1000, id = "c5" }
event("UNIT_SPELLCAST_START", "player", "c5", 8690)
casts.player = nil
tick(p, 1.7)
ok(p.fade, "cast without stop event times out")
tick(p, 1)

casts.target = { name = "Shadow Bolt", s = clock * 1000, e = (clock + 3) * 1000, id = "t1", shield = true }
event("PLAYER_TARGET_CHANGED")
ok(t:IsShown() and t.mode == "cast", "target cast picked up on target change")
ok(t.bar.__color[1] < 0.7 and t.bar.__color[3] > 0.6, "shielded colour")
ok(not t.lag:IsShown(), "no latency zone on target")
casts.target.shield = false
event("UNIT_SPELLCAST_INTERRUPTIBLE", "target")
ok(t.bar.__color[1] == 1, "interruptible colour")
casts.target = nil
event("PLAYER_TARGET_CHANGED")
ok(not t:IsShown(), "target bar hidden without cast")

casts.target = { name = SECRET, icon = SECRET, s = SECRET, e = SECRET, id = SECRET, shield = SECRET, spell = SECRET }
event("UNIT_SPELLCAST_START", "target", SECRET, SECRET)
ok(t:IsShown() and t.secret, "secret cast shown")
ok(t.bar.__timer and t.bar.__timer[1].kind == "cast" and t.bar.__timer[3] == 0, "secret cast uses duration object")
ok(t.bar.left.__text == SECRET, "secret name passed through")
tick(t, 0.2)
ok(t.mode == "cast", "secret cast keeps running")
event("UNIT_SPELLCAST_SUCCEEDED", "target", SECRET, SECRET)
event("UNIT_SPELLCAST_FAILED", "target", SECRET, SECRET)
ok(t.mode == "cast", "secret failure ignored")
event("UNIT_SPELLCAST_INTERRUPTED", "target", SECRET, SECRET)
ok(t.fade and t.bar.left.__text == "Interrupted", "secret interrupt")
tick(t, 2)
casts.target = { name = SECRET, s = SECRET, e = SECRET, id = SECRET, shield = SECRET }
event("UNIT_SPELLCAST_START", "target", SECRET, SECRET)
casts.target = nil
tick(t, 0.2)
ok(t.fade, "secret cast ends when polling finds nothing")
tick(t, 1)
channels.target = { name = SECRET, s = SECRET, e = SECRET, shield = SECRET }
event("UNIT_SPELLCAST_CHANNEL_START", "target", SECRET, SECRET)
ok(t.bar.__timer[1].kind == "channel" and t.bar.__timer[3] == 1, "secret channel drains")
channels.target = nil
event("UNIT_SPELLCAST_CHANNEL_STOP", "target", SECRET, SECRET)
tick(t, 1)
ok(not t:IsShown(), "secret channel hidden")

event("UNIT_SPELLCAST_START", "party1", "x", 1)
event("UNIT_SPELLCAST_STOP", "nameplate3", "x", 1)

SlashCmdList["ACAST"]("unlock")
ok(p:IsShown() and t:IsShown() and p.bar.left.__text == "Player cast bar", "unlock shows placeholders")
p.__scripts.OnDragStart(p)
p.__scripts.OnDragStop(p)
ok(ns.db.player.pos, "position saved")
SlashCmdList["ACAST"]("test")
ok(p.test and t.test and t.mode == "channel", "test casts")
casts.player = { name = "Real", s = clock * 1000, e = (clock + 1) * 1000, id = "r" }
event("UNIT_SPELLCAST_START", "player", "r", 1)
ok(p.bar.left.__text == "Test cast", "test not replaced by events")
casts.player = nil
tick(p, 1)
tick(t, 0)
tick(p, 2.5)
tick(t, 0)
ok(p.fade and t.fade, "test finishes")
tick(p, 1)
tick(t, 0)
ok(p:IsShown() and p.bar.left.__text == "Player cast bar", "placeholder returns while unlocked")
SlashCmdList["ACAST"]("lock")
ok(not p:IsShown() and not t:IsShown(), "lock hides idle bars")
SlashCmdList["ACAST"]("reset")
ok(ns.db.player.pos == nil, "reset")

SlashCmdList["ACAST"]("")
ns.db.target.show = false
ns.Apply()
casts.target = { name = "Bolt", s = clock * 1000, e = (clock + 3) * 1000, id = "t2" }
event("UNIT_SPELLCAST_START", "target", "t2", 1)
ok(not t:IsShown(), "disabled target bar stays hidden")
ns.db.time = false
ns.db.latency = false
ns.db.icon = false
ns.Apply()
casts.player = { name = "Bolt", s = clock * 1000, e = (clock + 3) * 1000, id = "p9" }
event("UNIT_SPELLCAST_START", "player", "p9", 1)
tick(p, 1)
ok(p.bar.right.__text == "" and not p.lag:IsShown(), "time and latency off")
for _, a in ipairs(ACore.addons) do if a.name == "ACast" then a.toggle() end end
flush()

print_real(string.format("ok: %d checks (acast)", M.checks()))
