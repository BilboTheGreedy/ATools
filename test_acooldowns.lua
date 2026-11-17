local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

local now = 1000
function GetTime() return now end
local secrets = {}
local function secret()
	local s = {}
	secrets[s] = true
	return s
end
function issecretvalue(v) return secrets[v] or false end

local book = {
	{ spellID = 100, base = 180000, name = "Recklessness" },
	{ spellID = 101, base = 6000, name = "Mortal Strike" },
	{ spellID = 102, base = 300000, name = "Retaliation" },
	{ spellID = 103, base = 600000, name = "Passive", isPassive = true },
	{ spellID = 104, base = 60000, name = "Bloodrage" },
	{ spellID = 105, base = 60000, name = "Bloodrage" },
}
local byId = {}
for _, s in ipairs(book) do byId[s.spellID] = s end
byId[900] = { name = "Forced", base = 0 }
Enum.SpellBookSpellBank = { Player = 0 }
C_SpellBook = {
	GetNumSpellBookSkillLines = function() return 2 end,
	GetSpellBookSkillLineInfo = function(i)
		if i == 1 then return { itemIndexOffset = 0, numSpellBookItems = 3 } end
		return { itemIndexOffset = 3, numSpellBookItems = 3 }
	end,
	GetSpellBookItemInfo = function(slot) return book[slot] end,
}
function GetSpellBaseCooldown(id) return byId[id] and byId[id].base or 0 end
local cds = {}
local objects = 0
C_Spell.GetSpellName = function(id) return byId[id] and byId[id].name end
C_Spell.GetSpellCooldown = function(id) return cds[id] or { startTime = 0, duration = 0 } end
C_Spell.GetSpellCooldownDuration = function() objects = objects + 1 return { object = true } end
local objectSets = 0
M.methods.SetCooldownFromDurationObject = function() objectSets = objectSets + 1 end
local trinkets = { [13] = 5001, [14] = 5002 }
function GetInventoryItemID(_, slot) return trinkets[slot] end
C_Item.GetItemSpell = function(id) if id == 5001 or id == 7000 then return "Use" end end
local slotCd = { [13] = { 0, 0 } }
function GetInventoryItemCooldown(_, slot)
	local c = slotCd[slot] or { 0, 0 }
	return c[1], c[2], 1
end
local itemCd = {}
C_Container = { GetItemCooldown = function(id)
	local c = itemCd[id] or { 0, 0 }
	return c[1], c[2], 1
end }
local cursor
function GetCursorInfo() if cursor then return unpack(cursor) end end
function ClearCursor() cursor = nil end
local grouped, raid = false, false
function IsInGroup() return grouped end
function IsInRaid() return raid end
local sent = {}
function SendChatMessage(text, channel) sent[#sent + 1] = { text, channel } end
local sounds = 0
function PlaySound() sounds = sounds + 1 end

M.load("ACore", "ACore")
local ns = M.load("ACooldowns", "ACooldowns")
event("PLAYER_LOGIN")
flush()

local function names()
	local t = {}
	for _, e in ipairs(ns.list) do t[e.name] = e end
	return t
end
local n = names()
ok(n.Recklessness and n.Retaliation and n.Bloodrage, "long cooldowns tracked")
ok(not n["Mortal Strike"] and not n.Passive, "short and passive skipped")
ok(n.Bloodrage.id == 105, "highest rank kept")
ok(ns.byKey["i:5001"] and not ns.byKey["i:5002"], "only on-use trinket")
ok(#ns.list == 4, "list size " .. #ns.list)
ok(ACooldownsFrame, "frame built")
ok(#ns.Visible() == 4, "all visible")

local function icons()
	local out = {}
	for _, f in ipairs(M.frames) do
		if f.entry and f.tex and f.time and f.__shown then out[#out + 1] = f end
	end
	return out
end
ok(#icons() == 4, "icons shown " .. #icons())

cds[100] = { startTime = 995, duration = 180 }
cds[102] = { startTime = 999.5, duration = 1.5 }
slotCd[13] = { 990, 120 }
event("SPELL_UPDATE_COOLDOWN")
event("BAG_UPDATE_COOLDOWN")
flush()
ok(ns.Left(n.Recklessness) == 175, "cooldown left")
ok(ns.Left(n.Retaliation) == 0 and n.Retaliation.ready, "global cooldown ignored")
ok(ns.Left(ns.byKey["i:5001"]) == 110, "trinket cooldown")
ns.db.show = "cooling"
ns:Fire("OPTIONS")
ok(#ns.Visible() == 2, "cooling filter")
ns.db.show = "ready"
ns:Fire("OPTIONS")
ok(#ns.Visible() == 2, "ready filter")
ns.db.show = "all"
ns:Fire("OPTIONS")
ok(ns.TimeText(175) == "3m" and ns.TimeText(45) == "45" and ns.TimeText(4.26) == "4.3" and ns.TimeText(7200) == "2h", "time text")

for _, f in ipairs(icons()) do
	f.__scripts.OnEnter(f)
	f.__scripts.OnLeave(f)
end
local reck
for _, f in ipairs(icons()) do
	if f.entry == n.Recklessness then reck = f end
end
ok(reck.time.__text == "3m", "icon time text")
M.mods.shift = true
reck.__scripts.OnClick(reck, "LeftButton")
ok(#sent == 0 and M.printed[#M.printed]:find("Recklessness ready in 3m"), "announce solo prints")
grouped = true
reck.__scripts.OnClick(reck, "LeftButton")
ok(sent[1] and sent[1][2] == "PARTY" and sent[1][1]:find("ready in"), "announce party")
raid = true
local text, channel = ns.Announce(n.Bloodrage)
ok(text == "Bloodrage is ready" and channel == "RAID", "announce ready raid")
M.mods.shift = false
grouped, raid = false, false

cds[100] = { startTime = 995, duration = 1.5 }
event("SPELL_UPDATE_COOLDOWN")
flush()
ok(ns.Left(n.Recklessness) == 175, "global cooldown does not replace a running cooldown")
cds[100] = { startTime = 995, duration = 180 }
ns.db.sound = true
now = 1176
ACooldownsFrame.__scripts.OnUpdate(ACooldownsFrame, 0.2)
ok(n.Recklessness.ready and n.Recklessness.pulse == 1176 and sounds == 2, "ready pulse and sound")
now = 1176.3
ACooldownsFrame.__scripts.OnUpdate(ACooldownsFrame, 0.2)
now = 1177
ACooldownsFrame.__scripts.OnUpdate(ACooldownsFrame, 0.2)
ok(n.Recklessness.pulse == nil, "pulse ends")
cds[100] = nil
event("SPELL_UPDATE_COOLDOWN")
flush()

ns.db.bars = true
ns:Fire("OPTIONS")
local barCount = 0
for _, f in ipairs(M.frames) do
	if f.entry and f.right and f.__shown then barCount = barCount + 1 end
end
ok(barCount == 4, "bars shown " .. barCount)
ACooldownsFrame.__scripts.OnUpdate(ACooldownsFrame, 0.2)
ns.db.vertical = true
ns.db.bars = false
ns:Fire("OPTIONS")

cds[102] = { startTime = secret(), duration = secret() }
event("SPELL_UPDATE_COOLDOWN")
flush()
ok(n.Retaliation.secret and n.Retaliation.object and objects >= 1 and objectSets >= 1, "secret cooldown uses duration object")
ok(ns.Left(n.Retaliation) == 0, "secret has no readable time")
ns.db.show = "cooling"
ok(#ns.Visible() >= 1, "secret stays visible")
ns.db.show = "all"
ns.Announce(n.Retaliation)
ns.db.bars = true
ns:Fire("OPTIONS")
ACooldownsFrame.__scripts.OnUpdate(ACooldownsFrame, 0.2)
ns.db.bars = false
ns:Fire("OPTIONS")
ACooldownsFrame.__scripts.OnUpdate(ACooldownsFrame, 0.2)
cds[102] = nil

cds[100] = { startTime = secret(), duration = secret(), isActive = true, isOnGCD = false }
event("SPELL_UPDATE_COOLDOWN")
flush()
ok(n.Recklessness.secret and n.Recklessness.ready == false, "secret cooldown known to be running")
local function visible(e)
	for _, v in ipairs(ns.Visible()) do
		if v == e then return true end
	end
	return false
end
ns.db.show = "ready"
ok(not visible(n.Recklessness), "running secret cooldown not in the ready list")
ns.db.show = "cooling"
ok(visible(n.Recklessness), "running secret cooldown in the cooling list")
ns.db.show = "all"
ok(ns.Announce(n.Recklessness) == "Recklessness is on cooldown", "announce secret state")
ns.db.bars = true
ns:Fire("OPTIONS")
ACooldownsFrame.__scripts.OnUpdate(ACooldownsFrame, 0.2)
ns.db.bars = false
ns:Fire("OPTIONS")
cds[100] = { startTime = secret(), duration = secret(), isActive = true, isOnGCD = true }
event("SPELL_UPDATE_COOLDOWN")
flush()
ok(n.Recklessness.ready == true, "global cooldown ignored while secret")
ACooldownsFrame.__scripts.OnUpdate(ACooldownsFrame, 0.2)
ok(n.Recklessness.pulse == now, "secret cooldown pulses when ready")
ok(ns.Announce(n.Recklessness) == "Recklessness is ready", "announce secret ready")
cds[100] = nil
event("SPELL_UPDATE_COOLDOWN")
flush()

ns.db.combatOnly = true
ns:Fire("OPTIONS")
ok(not ACooldownsFrame:IsShown(), "hidden out of combat")
event("PLAYER_REGEN_DISABLED")
ok(ACooldownsFrame:IsShown(), "shown in combat")
event("PLAYER_REGEN_ENABLED")
ns.db.combatOnly = false
ns:Fire("OPTIONS")
ok(ACooldownsFrame:IsShown(), "shown again")

SlashCmdList["ACOOLDOWNS"]("add 7000")
ok(ns.byKey["i:7000"] and ns.chardb.items[7000], "add item by id")
itemCd[7000] = { 1170, 60 }
event("BAG_UPDATE_COOLDOWN")
flush()
ok(ns.Left(ns.byKey["i:7000"]) == 53, "item cooldown")
SlashCmdList["ACOOLDOWNS"]("add |cffffffff|Hitem:7001::::|h[Thing]|h|r")
ok(ns.chardb.items[7001], "add item by link")
SlashCmdList["ACOOLDOWNS"]("spell 900")
ok(ns.byKey["s:Forced"], "forced spell")
SlashCmdList["ACOOLDOWNS"]("remove 7001")
SlashCmdList["ACOOLDOWNS"]("remove 900")
ok(not ns.chardb.items[7001] and not ns.byKey["s:Forced"], "remove")
SlashCmdList["ACOOLDOWNS"]("add")
cursor = { "item", 7002 }
local h = ACooldownsFrame.handle
h.__scripts.OnReceiveDrag(h)
ok(ns.chardb.items[7002] and cursor == nil, "drop item")
cursor = { "spell", 1, "spell", 101 }
h.__scripts.OnClick(h, "LeftButton")
ok(ns.chardb.spells[101] and ns.byKey["s:Mortal Strike"], "drop spell")
h.__scripts.OnClick(h, "RightButton")
h.__scripts.OnDragStart(h)
h.__scripts.OnDragStop(h)

local target
for _, f in ipairs(icons()) do
	if f.entry and f.entry.name == "Bloodrage" then target = f end
end
target.__scripts.OnClick(target, "RightButton")
ns.chardb.hidden["s:Bloodrage"] = "Bloodrage"
ns.Rescan()
ok(not ns.byKey["s:Bloodrage"], "hidden spell")
local restored = false
for _, e in ipairs(ns.Options()) do
	if e.text == "Bloodrage" and e.func then e.func() restored = true end
end
ok(restored and ns.byKey["s:Bloodrage"], "unhide from menu")

SlashCmdList["ACOOLDOWNS"]("unlock")
ok(ACooldownsFrame.handle:IsShown(), "unlock")
SlashCmdList["ACOOLDOWNS"]("lock")
ok(not ACooldownsFrame.handle:IsShown(), "lock")
SlashCmdList["ACOOLDOWNS"]("reset")
SlashCmdList["ACOOLDOWNS"]("")
for _, e in ipairs(ns.Options()) do
	if e.func then e.func() end
end
flush()
event("PLAYER_ENTERING_WORLD")
event("SPELLS_CHANGED")
event("PLAYER_EQUIPMENT_CHANGED")
flush()
for _, a in ipairs(ACore.addons) do
	if a.name == "ACooldowns" then a.toggle() end
end

C_SpellBook = nil
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo() return "General", 1, 0, 2 end
function GetSpellBookItemInfo(slot) return "SPELL", book[slot].spellID end
C_Spell.GetSpellCooldown = nil
function GetSpellCooldown() return 1170, 100, 1 end
ns.chardb.spells = {}
ns.db.minimum = 30
ns.chardb.hidden = {}
ns.Rescan()
ok(ns.byKey["s:Recklessness"] and ns.Left(ns.byKey["s:Recklessness"]) == 93, "legacy spellbook and cooldown api")

print_real(string.format("ok: %d checks (acooldowns)", M.checks()))
