local M = dofile("tools/mock.lua")
local ok, event, flush = M.ok, M.event, M.flush

local SECRET = {}
function issecretvalue(v) return v == SECRET end
local clock = 1000000
function time() return clock end
function GetTime() return 500 end
local me = { name = "Aldo", realm = "Stormrage", level = 42, xp = 3000, xpMax = 12000, rested = 6000, money = 1234567, zone = "Tanaris" }
function UnitName() return me.name end
function GetRealmName() return me.realm end
function UnitLevel() return me.level end
function UnitXP() return me.xp end
function UnitXPMax() return me.xpMax end
function GetXPExhaustion() return me.rested end
function GetMoney() return me.money end
function GetRealZoneText() return me.zone end
function UnitRace() return "Human", "Human", 1 end
function GetGuildInfo() return "Night Shift" end
function IsResting() return true end
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
local skills = {
	{ "Class Skills", true }, { "Defense", false, false, 200, 0, 0, 210 },
	{ "Professions", true }, { "Mining", false, false, 225, 0, 0, 300, true }, { "Blacksmithing", false, false, 150, 0, 0, 225, true },
	{ "Secondary Skills", true }, { "Cooking", false, false, 120, 0, 0, 150 }, { "Riding", false, false, 1, 0, 0, 1 },
	{ "Weapon Skills", true }, { "Swords", false, false, 205, 0, 0, 210 },
}
function GetNumSkillLines() return #skills end
function GetSkillLineInfo(i) return unpack(skills[i], 1, 8) end
function IsPlayerSpell(id) return id == 17187 end
C_Spell.GetSpellCooldown = function() return { startTime = 400, duration = 86400 } end
function GetInventoryItemLink(_, slot)
	if slot == 1 or slot == 16 then return "|cffa335ee|Hitem:" .. (16000 + slot) .. "|h[Thing " .. slot .. "]|h|r" end
end
C_Item.GetDetailedItemLevelInfo = function(link) return tonumber(link:match("item:(%d+)")) - 15950 end
C_Container = {
	GetContainerNumSlots = function(bag) return bag == -1 and 24 or 16 end,
	GetContainerNumFreeSlots = function(bag) return bag == -1 and 4 or 3 end,
}
C_Reputation = {
	GetNumFactions = function() return 4 end,
	GetFactionDataByIndex = function(i)
		if i == 1 then return { name = "Alliance", isHeader = true } end
		if i == 2 then return { name = "Stormwind", factionID = 72, reaction = 7, currentStanding = 30000, currentReactionThreshold = 21000, nextReactionThreshold = 42000 } end
		if i == 3 then return { name = "Ironforge", factionID = 47, reaction = 4, currentStanding = 0, currentReactionThreshold = 0, nextReactionThreshold = 3000 } end
		return { name = "Argent Dawn", factionID = 529, reaction = SECRET, currentStanding = 100, currentReactionThreshold = 0, nextReactionThreshold = 3000 }
	end,
}
function GetNumSavedInstances() return 2 end
function GetSavedInstanceInfo(i)
	if i == 1 then return "Molten Core", 11, 90000, 1, true, false, 0, true, 40, "40 Player" end
	return "Old One", 12, 0, 1, false
end
function UnitPVPRank() return 8 end
function GetPVPRankInfo() return "Knight", 4 end
local mailed = false
function HasNewMail() return true end
function GetInboxNumItems() mailed = true return 3, 5 end
local requested, quiet = 0, false
local chatEvents = { TIME_PLAYED_MSG = true }
function RequestTimePlayed() requested = requested + 1 quiet = not chatEvents.TIME_PLAYED_MSG end
function RequestRaidInfo() end
NUM_CHAT_WINDOWS = 2
ChatFrame1 = M.obj("Frame")
function ChatFrame1:IsEventRegistered(e) return chatEvents[e] end
function ChatFrame1:UnregisterEvent(e) chatEvents[e] = nil end
function ChatFrame1:RegisterEvent(e) chatEvents[e] = true end
function M.methods:AddLine(text) self.__lines = self.__lines or {} self.__lines[#self.__lines + 1] = text end
local confirmed
StaticPopup_Show = function(name) confirmed = StaticPopupDialogs[name] end

M.load("ACore", "ACore")
AAltsDB = { chars = { Stormrage = { Bankalt = { class = "MAGE", level = 5, money = 500000, faction = "Alliance", seen = clock - 200000, zone = "Ironforge" } },
	Other = { Hordie = { class = "SHAMAN", level = 60, money = 77, faction = "Horde", seen = clock - 3000, lockouts = { { name = "Zul'Gurub", reset = clock + 5000 } } } } } }
local ns = M.load("AAlts", "AAlts")
event("PLAYER_LOGIN")

local c = ns.db.chars.Stormrage.Aldo
ok(c and c.level == 42 and c.money == 1234567 and c.zone == "Tanaris" and c.guild == "Night Shift", "basics")
ok(c.class == "WARRIOR" and c.faction == "Alliance" and c.race == "Human", "identity")
ok(#c.profs == 3 and c.profs[1].main and c.profs[3].name == "Cooking", "professions " .. #c.profs)
ok(#c.cooldowns == 1 and c.cooldowns[1].ready == clock + 86300, "cooldown")
ok(c.gear[1] and c.gear[16] and c.ilvl == 58.5, "gear " .. tostring(c.ilvl))
ok(c.bagTotal == 80 and c.bagFree == 15, "bags")
ok(#c.reps == 2 and c.reps[1].name == "Stormwind" and c.reps[1].value == 9000 and c.reps[1].max == 21000, "reputations " .. #c.reps)
ok(#c.lockouts == 1 and c.lockouts[1].reset == clock + 90000, "lockouts")
ok(c.rank and c.rank.name == "Knight" and c.newMail, "rank and mail flag")

flush()
ok(requested == 1 and quiet, "played requested quietly")
event("TIME_PLAYED_MSG", 360000, 7200)
flush()
ok(c.played == 360000 and c.playedLevel == 7200 and chatEvents.TIME_PLAYED_MSG, "played stored, chat restored")

event("BANKFRAME_OPENED")
event("MAIL_INBOX_UPDATE")
me.money = 2000000
me.level = SECRET
event("PLAYER_MONEY")
for _, e in ipairs({ "PLAYER_XP_UPDATE", "SKILL_LINES_CHANGED", "TRADE_SKILL_UPDATE", "SPELL_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED",
	"BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "UPDATE_FACTION", "UPDATE_INSTANCE_INFO", "PLAYER_PVP_RANK_CHANGED", "UPDATE_PENDING_MAIL" }) do
	event(e)
end
flush()
ok(c.money == 2000000 and c.level == 42, "money updated, secret level ignored")
ok(c.bankTotal == 120 and c.bankFree == 22, "bank " .. tostring(c.bankTotal))
ok(mailed and c.mail == 5 and c.mailSeen == clock, "mail")
me.level = 42
event("BANKFRAME_CLOSED")
event("PLAYER_LOGOUT")

ok(#ns.All() == 3, "three characters")
ok(ns.Ago(clock - 30) == "now" and ns.Ago(clock - 7200) == "2 h ago" and ns.Ago(clock - 200000) == "2 d ago" and ns.Ago(nil) == "never", "ago")
ok(ns.Duration(90000) == "1 d 1 h" and ns.Duration(3700) == "1 h 1 min" and ns.Duration(0) == "0 min", "duration")

SlashCmdList["AALTS"]("")
local frame = AAltsFrame
ok(frame and frame:IsShown(), "window shown")
ok(#frame.list.data == 3 and frame.list.data[1].char.name == "Aldo", "overview rows")
ok(frame.totals.__text:find("Stormrage") and frame.totals.__text:find("All:"), "totals")
for _, b in ipairs(frame.sorters) do
	b.__scripts.OnClick(b, "LeftButton")
	ok(ns.db.sort == b.key, "sort " .. b.key)
	b.__scripts.OnClick(b, "LeftButton")
end
ns.db.sort, ns.db.desc = "money", true
ns.Window.Refresh()
ok(frame.list.data[1].char.name == "Aldo" and frame.list.data[3].char.name == "Hordie", "sorted by gold")
for i, row in ipairs(frame.list.rows) do
	if row:IsShown() and row.data and row.data.kind == "char" then
		row.__scripts.OnEnter(row)
		row.__scripts.OnLeave(row)
	end
end
for _, ch in ipairs(ns.All()) do
	ns.Window.ShowChar(ch)
	ok(frame.back:IsShown() and #frame.list.data > 3, "detail " .. ch.name)
	for _, row in ipairs(frame.list.rows) do
		if row:IsShown() and row.data then
			row.__scripts.OnEnter(row)
			M.mods.shift = true
			row.__scripts.OnClick(row, "LeftButton")
			M.mods.shift = false
		end
	end
	frame.back.__scripts.OnClick(frame.back)
end
local kinds = {}
ns.Window.ShowChar(c)
for _, d in ipairs(frame.list.data) do kinds[d.kind] = (kinds[d.kind] or 0) + 1 end
ok(kinds.gear == 2 and kinds.header >= 6 and kinds.pair >= 6, "detail kinds")
frame.back.__scripts.OnClick(frame.back)

local eb = frame.search.box
eb:SetText("item")
eb.__scripts.OnTextChanged(eb)
flush()
ok(frame.list.data[1].kind == "note" and frame.list.data[1].text:find("ABag"), "search without ABag")
ok(not ns.HasBags() and ns.Owners(5) == nil, "no bag source")

ABagDB = { chars = {
	["Aldo - Stormrage"] = { name = "Aldo", bags = { "8:5", "8:10", "junk", "10:1" }, bank = { "8:20" } },
	["Bankalt - Stormrage"] = { name = "Bankalt", bags = { "8:3" }, bank = { "10:40", "13:2" } },
	broken = 5,
} }
clock = clock + 60
ok(ns.HasBags(), "bag source")
local owners = ns.Owners(8)
ok(#owners == 2 and owners[1].bags == 15 and owners[1].bank == 20 and owners[2].bags == 3, "owners")
ok(ns.OwnerText(owners[1]) == "Aldo (15, 20 in bank)", "owner text")
ok(#ns.Owners(8, true) == 1 and ns.Owners(999) == nil, "skip current")
local found = ns.FindItems("item 1")
ok(#found == 2 and found[1].id == 10 and found[1].total == 41, "find items " .. #found)
ok(#ns.FindItems("8") == 1 and #ns.FindItems("") == 0, "find by id")
eb:SetText("item 1")
eb.__scripts.OnTextChanged(eb)
flush()
ok(frame.list.data[1].kind == "item", "item rows")
for _, row in ipairs(frame.list.rows) do
	if row:IsShown() and row.data then row.__scripts.OnEnter(row) end
end
eb:SetText("zzz")
eb.__scripts.OnTextChanged(eb)
flush()
ok(frame.list.data[1].kind == "note", "nothing found")
eb:SetText("")
eb.__scripts.OnTextChanged(eb)
flush()

ok(#M.tooltipCalls == 1, "tooltip hook")
GameTooltip.__lines = {}
M.tooltipCalls[1](GameTooltip, { id = 8 })
ok(#GameTooltip.__lines == 1 and GameTooltip.__lines[1] == "Also on: Bankalt (3)", "tooltip line " .. tostring(GameTooltip.__lines[1]))
M.tooltipCalls[1](GameTooltip, { id = 999 })
M.tooltipCalls[1](GameTooltip, { id = SECRET })
M.tooltipCalls[1](UIParent, { id = 8 })
ns.db.tooltip = false
M.tooltipCalls[1](GameTooltip, { id = 8 })
ok(#GameTooltip.__lines == 1, "tooltip off")

local row = frame.list.rows[1]
row.data = frame.list.data[3]
local victim = row.data.char.name
row.__scripts.OnClick(row, "RightButton")
ns.Delete(row.data.char)
ok(#ns.All() == 2, "deleted " .. victim)
ns.UI.Confirm("x", function() confirmed = "yes" end)
ok(confirmed, "confirm dialog")
for _, e in ipairs(ns.Options()) do
	if e.func then e.func() end
end
SlashCmdList["AALTS"]("scan")
SlashCmdList["AALTS"]("reset")
SlashCmdList["AALTS"]("thing")
flush()
AAlts_ToggleBinding()
AAlts_ToggleBinding()
ACoreMinimapButton.__scripts.OnClick(ACoreMinimapButton, "LeftButton")

print_real(string.format("ok: %d checks (aalts)", M.checks()))
