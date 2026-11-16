local M = dofile("tools/mock.lua")
local ok, event, flush, printed = M.ok, M.event, M.flush, M.printed

function M.methods:HookScript(name, fn)
	self.__hooks = self.__hooks or {}
	self.__hooks[name] = fn
end
function M.methods:GetID() return self.__id end

function hooksecurefunc(a, b, c)
	local t, name, fn = _G, a, b
	if type(a) == "table" then t, name, fn = a, b, c end
	local orig = t[name]
	t[name] = function(...)
		local r = { orig(...) }
		fn(...)
		return unpack(r)
	end
end

local accept = true
function StaticPopup_Show(name)
	local d = StaticPopupDialogs[name]
	if accept and d.OnAccept then d.OnAccept({}) end
end

function UnitName() return "Mainchar" end
function GetRealmName() return "Testrealm" end

local mails
local function reset()
	mails = {
		{ sender = "Bank", subject = "Gold", money = 500, cod = 0, days = 20, items = 0 },
		{ sender = "Alt", subject = "Stuff", money = 0, cod = 0, days = 10, items = 2 },
		{ sender = "Trader", subject = "COD", money = 0, cod = 900, days = 2, items = 1 },
		{ sender = "GM", subject = "Notice", money = 50, cod = 0, days = 30, items = 0, gm = true },
		{ sender = "Auction", subject = "Sold", money = 1200, cod = 0, days = 29, items = 1 },
		{ sender = "Friend", subject = "Letter", money = 0, cod = 0, days = 1.5, items = 0 },
	}
end
reset()
local free = 10
local taken, looted, returnedMail = 0, 0, nil
function GetInboxNumItems() return #mails end
function GetInboxHeaderInfo(i)
	local m = mails[i]
	if not m then return nil end
	return nil, nil, m.sender, m.subject, m.money, m.cod, m.days, m.items > 0 and m.items or nil, false, m.returned, false, true, m.gm
end
local function tidy(i)
	local m = mails[i]
	if m and m.money == 0 and m.items == 0 and not m.text then table.remove(mails, i) end
end
function TakeInboxMoney(i)
	taken = taken + mails[i].money
	mails[i].money = 0
	tidy(i)
end
function AutoLootMailItem(i)
	looted = looted + mails[i].items
	free = free - mails[i].items
	mails[i].items = 0
	tidy(i)
end
function ReturnInboxItem(i) returnedMail = table.remove(mails, i).subject end
function InboxItemCanDelete(i) return mails[i].items == 0 and mails[i].money == 0 end
function CheckInbox() end
C_Container = {
	GetContainerNumFreeSlots = function(bag) return bag == 0 and free or 0 end,
	GetContainerNumSlots = function(bag) return bag == 0 and 20 or 0 end,
}
local bag = {}
local function fill()
	bag = {}
	for slot = 1, 14 do bag[slot] = { itemID = 2589, hyperlink = "|Hitem:2589|h[Linen Cloth]|h", quality = 1, stackCount = 20 } end
	bag[15] = { itemID = 3000, hyperlink = "|Hitem:3000|h[Green Sword]|h", quality = 2, stackCount = 1 }
	bag[16] = { itemID = 3001, hyperlink = "|Hitem:3001|h[Bound Thing]|h", quality = 2, stackCount = 1, isBound = true }
	bag[17] = { itemID = 3002, hyperlink = "|Hitem:3002|h[Green Helm]|h", quality = 2, stackCount = 1 }
end
fill()
C_Container.GetContainerItemInfo = function(b, slot) return b == 0 and bag[slot] or nil end
local cursor
C_Container.PickupContainerItem = function(b, slot) cursor = slot end
local attached = {}
function ClickSendMailItemButton()
	if cursor then
		attached[#attached + 1] = cursor
		bag[cursor] = nil
		cursor = nil
	end
end
local sent = {}
function SendMail(to, subject, body)
	sent[#sent + 1] = { to = to, subject = subject, n = #attached }
	attached = {}
end
function ClearCursor() cursor = nil end
ATTACHMENTS_MAX_SEND = 12
INBOXITEMS_TO_DISPLAY = 7
C_Item.GetItemInfo = function(id)
	if id == 2589 then return "Linen Cloth", "", 1, 5, 0, "Trade Goods", "Cloth", 20, "", 1, 1, 7, 5 end
	return "Gear " .. id, "", 2, 20, 15, "Armor", "Mail", 1, "INVTYPE_HEAD", 1, 1, 4, 3
end
function HandleModifiedItemClick() return false end
local tabClicked
function MailFrameTab_OnClick(_, n) tabClicked = n end
function InboxFrame_Update() end

MailFrame = M.obj("Frame")
InboxFrame = M.obj("Frame")
InboxFrame.pageNum = 1
SendMailFrame = M.obj("Frame")
SendMailFrame.__shown = false
OpenMailFrame = M.obj("Frame")
SendMailNameEditBox = M.obj("EditBox")
SendMailSubjectEditBox = M.obj("EditBox")
for slot = 1, 7 do
	_G["MailItem" .. slot .. "Button"] = M.obj("Button")
	_G["MailItem" .. slot .. "Subject"] = M.obj("FontString")
end

M.load("ACore", "ACore")
local ns = M.load("AMail", "AMail")
event("PLAYER_LOGIN")
ok(ns.db.chars.Testrealm.Alliance.Mainchar, "character recorded")
ns.db.chars.Testrealm.Alliance.Altbank = true
ns.db.chars.Testrealm.Alliance.Alchemist = true
ns.db.chars.Testrealm.Horde = { Hordie = true }
ok(#ns.Alts() == 2 and ns.Alts()[1] == "Alchemist", "alts exclude self and other faction")

event("MAIL_SHOW")
flush()
local c = ns.controls
ok(c and c.open and c.gold, "inbox buttons")
local count, gold, items, soonest = ns.Inbox.Summary()
ok(count == 6 and gold == 1750 and items == 4 and soonest == 1.5, "summary " .. gold)
ok(c.summary:GetText():find("6 mails") and c.summary:GetText():find("expires"), "summary text")
InboxFrame_Update()

c.gold.__scripts.OnClick(c.gold, "LeftButton")
flush()
ok(taken == 1700 and looted == 0, "gold only " .. taken)
ok(#mails == 5, "empty gold mail removed " .. #mails)
ok(printed[#printed]:find("collected"), "gold summary")

reset()
taken, looted, free = 0, 0, 10
c.open.__scripts.OnClick(c.open, "LeftButton")
ok(ns.Inbox.Running(), "running")
event("MAIL_INBOX_UPDATE")
flush()
ok(not ns.Inbox.Running(), "finished")
ok(taken == 1700 and looted == 3, "open all " .. taken .. " " .. looted)
ok(#mails == 3 and mails[1].subject == "COD" and mails[2].gm and mails[3].subject == "Letter", "cod, gm and letters stay")
ok(printed[#printed]:find("2 skipped"), "skipped count: " .. printed[#printed])

reset()
taken, looted, free = 0, 0, 0
ns.Inbox.OpenAll(false)
flush()
ok(looted == 0 and printed[#printed]:find("bags are full"), "bags full stops")
free = 10

reset()
ns.db.skipCod = false
ns.db.skipGm = false
taken, looted = 0, 0
ns.Inbox.OpenAll(false)
flush()
ok(taken == 1750 and looted == 4, "nothing skipped when turned off")
ns.db.skipCod = true
ns.db.skipGm = true

reset()
ns.Inbox.OpenAll(false)
ns.Inbox.OpenAll(false)
ok(not ns.Inbox.Running() and printed[#printed]:find("stopped"), "second press stops")
flush()
reset()
ns.Inbox.OpenAll(false)
event("UI_ERROR_MESSAGE", 1, nil)
ERR_INV_FULL = "Inventory is full."
event("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
ok(not ns.Inbox.Running(), "error stops")
flush()
reset()
ns.Inbox.OpenAll(false)
MailFrame.__shown = false
event("MAIL_CLOSED")
ok(not ns.Inbox.Running(), "closing stops")
flush()
ns.Inbox.OpenAll(false)
ok(printed[#printed]:find("open a mailbox"), "needs mailbox")
MailFrame.__shown = true
mails = {}
ns.Inbox.OpenAll(true)
ok(printed[#printed]:find("no gold"), "nothing to collect")

reset()
taken, looted = 0, 0
local b = MailItem5Button
M.mods.shift = true
b.__hooks.OnClick(b)
flush()
ok(taken == 1200 and looted == 1, "shift-click takes everything")
reset()
MailItem3Button.__hooks.OnClick(MailItem3Button)
ok(printed[#printed]:find("cash on delivery"), "shift-click refuses cod")
M.mods.shift = false
M.mods.ctrl = true
MailItem2Button.__hooks.OnClick(MailItem2Button)
ok(returnedMail == "Stuff", "ctrl-click returns")
MailItem5Button.__hooks.OnClick(MailItem5Button)
ok(printed[#printed]:find("cannot be returned"), "letter cannot be returned")
M.mods.ctrl = false
b.__hooks.OnEnter(b)
MailItem7Button.__hooks.OnClick(MailItem7Button)

local s = ns.sendControls
ok(s and s.to and s.all, "send buttons")
ok(ns.Send.Complete("al") == "Alchemist" and ns.Send.Complete("zz") == nil and ns.Send.Complete("") == nil, "complete")
SendMailNameEditBox:SetText("alt")
SendMailNameEditBox.__hooks.OnTextChanged(SendMailNameEditBox, true)
ok(SendMailNameEditBox:GetText() == "Altbank", "autocomplete fills " .. SendMailNameEditBox:GetText())
SendMailNameEditBox:SetText("al")
SendMailNameEditBox.__hooks.OnTextChanged(SendMailNameEditBox, true)
ok(SendMailNameEditBox:GetText() == "al", "backspace is not completed")
ns.db.autocomplete = false
SendMailNameEditBox:SetText("alc")
SendMailNameEditBox.__hooks.OnTextChanged(SendMailNameEditBox, true)
ok(SendMailNameEditBox:GetText() == "alc", "autocomplete off")
ns.db.autocomplete = true

SendMail("Buddy", "Hello there", "")
ok(ns.chardb.lastTo == "Buddy" and ns.db.recent[1] == "Buddy" and ns.db.lastSubject == "Hello there", "remembered")
SendMail("Other", "x", "")
SendMail("buddy", "y", "")
ok(#ns.db.recent == 2 and ns.db.recent[1] == "buddy", "recent deduplicated")
for i = 1, 14 do SendMail("Name" .. i, "s", "") end
ok(#ns.db.recent == 10, "recent capped")
SendMailSubjectEditBox:SetText("")
SendMailFrame.__hooks.OnShow(SendMailFrame)
ok(SendMailSubjectEditBox:GetText() == "s", "subject restored")

s.to.__scripts.OnClick(s.to, "LeftButton")
local function clickMenu(prefix)
	for _, f in ipairs(M.frames) do
		if f.entry and f.entry.func and f.entry.text:sub(1, #prefix) == prefix then
			f.entry.func()
			return true
		end
	end
end
ok(clickMenu("Altbank") and SendMailNameEditBox:GetText() == "Altbank", "recipient menu")

local groups = ns.Send.Groups()
ok(#groups == 2 and groups[1].label == "Cloth" and #groups[1].stacks == 14 and #groups[2].stacks == 2, "groups skip bound items")
sent = {}
s.all.__scripts.OnClick(s.all, "LeftButton")
ok(clickMenu("Cloth"), "send all menu")
ok(#sent == 1 and sent[1].n == 12 and sent[1].to == "Altbank", "first mail has 12 stacks")
event("MAIL_SEND_SUCCESS")
flush()
ok(#sent == 2 and sent[2].n == 2, "second mail has the rest")
event("MAIL_SEND_SUCCESS")
flush()
ok(printed[#printed]:find("14 stacks") and printed[#printed]:find("2 mails"), "batch summary")
ok(ns.db.lastSubject == "s", "batch does not overwrite subject")

fill()
sent = {}
ns.Send.All(ns.Send.Groups()[1], "Altbank")
event("MAIL_FAILED")
flush()
ok(#sent == 1 and printed[#printed]:find("failed"), "failure stops the batch")
ns.Send.All(ns.Send.Groups()[1], "")
ok(printed[#printed]:find("recipient"), "needs recipient")
accept = false
s.all.__scripts.OnClick(s.all, "LeftButton")
clickMenu("Uncommon")

fill()
sent = {}
ns.chardb.lastTo = "Altbank"
M.mods.alt = true
HandleModifiedItemClick("link", { GetBagAndSlot = function() return 0, 15 end })
ok(#sent == 1 and sent[1].to == "Altbank" and sent[1].subject == "Green Sword" and tabClicked == 2, "quick send")
event("MAIL_SEND_SUCCESS")
HandleModifiedItemClick("link", { GetBagAndSlot = function() return 0, 16 end })
ok(#sent == 1, "bound item not sent")
ns.chardb.lastTo = nil
HandleModifiedItemClick("link", { GetBagAndSlot = function() return 0, 17 end })
ok(#sent == 1 and printed[#printed]:find("attached"), "attach only without recipient")
ns.db.quick = false
ok(ns.Send.Quick(0, 1) == false, "quick off")
M.mods.alt = false
HandleModifiedItemClick("link", { GetBagAndSlot = function() return 0, 1 end })

for _, e in ipairs(ns.Options()) do
	if e.func then e.func() end
end
ok(#ns.db.recent == 0, "recent forgotten")
mails = {}
reset()
SlashCmdList["AMAIL"]("gold")
flush()
SlashCmdList["AMAIL"]("open")
SlashCmdList["AMAIL"]("stop")
flush()
SlashCmdList["AMAIL"]("")
SlashCmdList["AMAIL"]("what")
ok(printed[#printed]:find("/amail"), "slash help")
c.options.__scripts.OnClick(c.options, "LeftButton")
ns:Fire("OPTIONS")

print_real(string.format("ok: %d checks (amail)", M.checks()))
