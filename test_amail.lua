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

function GetInboxInvoiceInfo(i) return mails[i] and mails[i].money > 0 and "seller" or nil end
c.gold.__scripts.OnClick(c.gold, "LeftButton")
flush()
GetInboxInvoiceInfo = nil
ok(taken == 1700 and looted == 0, "gold only " .. taken)
ok(printed[#printed]:find("from auctions"), "auction income in the summary " .. printed[#printed])
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

ok(ns.db.reskin == false, "default window option toggles off")
local closed = 0
function CloseMail()
	closed = closed + 1
	MailFrame.__shown = false
end
function GetMoney() return 100000 end
function GetInboxText(i) return mails[i] and ("Body of " .. mails[i].subject) or nil end
function GetInboxItem(i, a)
	local m = mails[i]
	if not m or a > m.items then return nil end
	return "Thing " .. a, 2589, 134400, 3, 2, true
end
function GetInboxItemLink(i, a) return "|Hitem:2589|h[Thing " .. a .. "]|h" end
local tookSlots = {}
function TakeInboxItem(i, a)
	tookSlots[#tookSlots + 1] = a
	mails[i].items = mails[i].items - 1
	looted = looted + 1
	tidy(i)
end
local deleted
function DeleteInboxItem(i) deleted = table.remove(mails, i).subject end
function InboxItemCanDelete(i) return mails[i].items == 0 and mails[i].money == 0 end
function ClickSendMailItemButton(index, clear)
	if clear then
		if index and attached[index] then attached[index] = nil end
	elseif cursor then
		local at = index or (#attached + 1)
		attached[at] = cursor
		bag[cursor] = nil
		cursor = nil
	end
end
function GetSendMailItem(i)
	if not attached[i] then return nil end
	return "Sent thing " .. i, 2589, 134400, 20, 1
end
function GetSendMailPrice()
	local n = 0
	for _ in pairs(attached) do n = n + 1 end
	return 30 + n * 30
end
local moneySet, codSet
function SetSendMailMoney(c) moneySet = c end
function SetSendMailCOD(c) codSet = c end
function SendMail(to, subject, body)
	local n = 0
	for _ in pairs(attached) do n = n + 1 end
	sent[#sent + 1] = { to = to, subject = subject, body = body, n = n, money = moneySet, cod = codSet }
	attached = {}
	ns.Send.Remember(to, subject)
end

ns.db.reskin = true
ns.db.skipCod, ns.db.skipGm, ns.db.tint, ns.db.autocomplete, ns.db.keepSubject, ns.db.quick = true, true, true, true, true, true
reset()
fill()
attached = {}
taken, looted, free = 0, 0, 10
MailFrame.__shown = true
event("MAIL_SHOW")
flush()
local W = ns.Window
local frame = AMailFrame
ok(frame and frame:IsShown() and W.Active(), "reskinned window opens")
ok(MailFrame:IsShown(), "default frame stays open underneath")
ok(#frame.mailList.data == 6 and frame.mailList.data[5].h.subject == "Sold", "mail list " .. #frame.mailList.data)
ok(frame.summary:GetText():find("6 mails"), "summary in window")
ok(W.NameBox() == nil, "inbox tab uses no send boxes")
for _, row in ipairs(frame.mailList.rows) do
	if row:IsShown() and row.data then
		row.__scripts.OnEnter(row)
		row.__scripts.OnLeave(row)
	end
end
local function rowFor(subject)
	for _, row in ipairs(frame.mailList.rows) do
		if row:IsShown() and row.data and row.data.h.subject == subject then return row end
	end
end
local d = frame.detail
ok(d.title:GetText():find("Pick a mail"), "empty detail")
local r = rowFor("Stuff")
r.__scripts.OnClick(r, "LeftButton")
ok(d.title:GetText() == "Stuff" and d.body:GetText() == "Body of Stuff", "detail shows the mail")
ok(d.items[1]:IsShown() and d.items[2]:IsShown() and not d.items[3]:IsShown(), "attachment buttons")
ok(d.take:IsShown() and d.back:IsShown(), "take and return offered")
d.items[1].__scripts.OnEnter(d.items[1])
d.items[1].__scripts.OnLeave(d.items[1])
d.clip.__scripts.OnMouseWheel(d.clip, -1)
d.items[2].__scripts.OnClick(d.items[2], "LeftButton")
ok(looted == 1 and tookSlots[1] == 2, "click takes one attachment")
event("MAIL_INBOX_UPDATE")
flush()
ok(d.items[1]:IsShown() and not d.items[2]:IsShown(), "detail follows the inbox")
d.take.__scripts.OnClick(d.take, "LeftButton")
flush()
ok(looted == 2, "take all " .. looted)
event("MAIL_INBOX_UPDATE")
flush()
ok(#frame.mailList.data == 5 and d.title:GetText():find("Pick a mail"), "emptied mail leaves the list")

accept = true
r = rowFor("COD")
r.__scripts.OnClick(r, "LeftButton")
ok(d.money:GetText():find("Cash on delivery") and d.take.label:GetText() == "Pay and take", "cod detail")
d.take.__scripts.OnClick(d.take, "LeftButton")
ok(looted == 3, "cod taken after confirm")
event("MAIL_INBOX_UPDATE")
flush()

reset()
event("MAIL_INBOX_UPDATE")
flush()
r = rowFor("Stuff")
r.__scripts.OnClick(r, "LeftButton")
returnedMail = nil
d.back.__scripts.OnClick(d.back, "LeftButton")
ok(returnedMail == "Stuff" and #frame.mailList.data == 5, "return button")

r = rowFor("Sold")
r.__scripts.OnClick(r, "LeftButton")
accept = false
deleted = nil
d.delete.__scripts.OnClick(d.delete, "LeftButton")
ok(deleted == nil, "delete with contents waits for confirm")
accept = true
d.delete.__scripts.OnClick(d.delete, "LeftButton")
ok(deleted == "Sold", "delete after confirm")
r = rowFor("Letter")
r.__scripts.OnClick(r, "LeftButton")
accept = false
d.delete.__scripts.OnClick(d.delete, "LeftButton")
ok(deleted == "Letter", "plain letter deletes at once")
accept = true

reset()
taken, looted = 0, 0
event("MAIL_INBOX_UPDATE")
flush()
M.mods.shift = true
r = rowFor("Sold")
r.__scripts.OnClick(r, "LeftButton")
flush()
ok(taken == 1200 and looted == 1, "shift-click row takes everything")
M.mods.shift = false
M.mods.ctrl = true
reset()
event("MAIL_INBOX_UPDATE")
flush()
returnedMail = nil
r = rowFor("Stuff")
r.__scripts.OnClick(r, "LeftButton")
ok(returnedMail == "Stuff", "ctrl-click row returns")
M.mods.ctrl = false

reset()
taken, looted = 0, 0
frame.goldOnly.__scripts.OnClick(frame.goldOnly, "LeftButton")
flush()
ok(taken == 1700, "gold only from the window " .. taken)
reset()
frame.openAll.__scripts.OnClick(frame.openAll, "LeftButton")
ok(frame.openAll.label:GetText() == "Stop", "open all shows stop")
flush()
ok(not ns.Inbox.Running() and frame.openAll.label:GetText() == "Open all", "open all from the window")

reset()
event("MAIL_INBOX_UPDATE")
flush()
r = rowFor("Stuff")
r.__scripts.OnClick(r, "LeftButton")
d.reply.__scripts.OnClick(d.reply, "LeftButton")
ok(W.NameBox() == frame.name.box and frame.name.box:GetText() == "Alt" and frame.subject.box:GetText() == "RE: Stuff", "reply fills the send tab")
ok(tabClicked == 2 and frame.sendPane:IsShown() and not frame.inboxPane:IsShown(), "send tab")

sent = {}
frame.name.box:SetText("")
frame.send.__scripts.OnClick(frame.send, "LeftButton")
ok(#sent == 0 and printed[#printed]:find("recipient"), "send needs a recipient")
frame.name.box:SetText("alc")
frame.name.box.__scripts.OnTextChanged(frame.name.box)
ok(frame.name.box:GetText() == "Alchemist", "autocomplete in the window")
frame.name.box:SetText("al")
frame.name.box.__scripts.OnTextChanged(frame.name.box)
ok(frame.name.box:GetText() == "al", "backspace not completed in the window")
frame.to.__scripts.OnClick(frame.to, "LeftButton")
ok(clickMenu("Altbank") and frame.name.box:GetText() == "Altbank", "recipient menu fills the window")
frame.subject.box:SetText("")
frame.send.__scripts.OnClick(frame.send, "LeftButton")
ok(#sent == 0 and printed[#printed]:find("subject"), "send needs a subject")

fill()
cursor = 1
frame.slots[1].__scripts.OnClick(frame.slots[1], "LeftButton")
cursor = 2
frame.slots[3].__scripts.OnReceiveDrag(frame.slots[3])
ok(frame.slots[1].entry and frame.slots[3].entry and not frame.slots[2].entry, "attachment slots")
ok(frame.postage:GetText():find("2 / 12"), "postage line " .. frame.postage:GetText())
frame.slots[1].__scripts.OnEnter(frame.slots[1])
frame.slots[2].__scripts.OnEnter(frame.slots[2])
frame.slots[1].__scripts.OnLeave(frame.slots[1])
frame.slots[3].__scripts.OnClick(frame.slots[3], "RightButton")
ok(not frame.slots[3].entry, "right-click removes an attachment")
cursor = 4
ClickSendMailItemButton()
event("MAIL_SEND_INFO_UPDATE")
ok(frame.slots[2].entry, "bag right-click attachments show up")

frame.gold.box:SetText("2")
frame.silver.box:SetText("5")
frame.copper.box:SetText("7")
frame.bodyBox:SetText("hello")
moneySet, codSet = nil, nil
frame.send.__scripts.OnClick(frame.send, "LeftButton")
ok(#sent == 1 and sent[1].to == "Altbank" and sent[1].n == 2 and sent[1].money == 20507 and sent[1].body == "hello", "send with attachments and money")
ok(sent[1].subject == "Sent thing 1", "subject defaults to the first item")
ok(sent[1].cod == 0, "money send clears cod")
event("MAIL_SEND_SUCCESS")
flush()
ok(frame.name.box:GetText() == "" and frame.bodyBox:GetText() == "" and frame.gold.box:GetText() == "", "fields clear after sending")
ok(ns.chardb.lastTo == "Altbank", "window send is remembered")

frame.name.box:SetText("Altbank")
frame.subject.box:SetText("Pay me")
frame.gold.box:SetText("1")
frame.mode.__scripts.OnClick(frame.mode, "LeftButton")
frame.send.__scripts.OnClick(frame.send, "LeftButton")
ok(#sent == 1 and printed[#printed]:find("needs an attached item"), "cod needs an item")
cursor = 5
frame.slots[1].__scripts.OnClick(frame.slots[1], "LeftButton")
moneySet, codSet = nil, nil
frame.send.__scripts.OnClick(frame.send, "LeftButton")
ok(#sent == 2 and sent[2].cod == 10000 and sent[2].money == 0, "cod send clears money")
event("MAIL_SEND_SUCCESS")
flush()
function GetMoney() return 10 end
frame.name.box:SetText("Altbank")
frame.subject.box:SetText("Too poor")
frame.gold.box:SetText("5")
frame.send.__scripts.OnClick(frame.send, "LeftButton")
ok(#sent == 2 and printed[#printed]:find("not enough money"), "money check")
function GetMoney() return 100000 end
cursor = 6
frame.slots[2].__scripts.OnClick(frame.slots[2], "LeftButton")
frame.clear.__scripts.OnClick(frame.clear, "LeftButton")
ok(not frame.slots[2].entry and frame.name.box:GetText() == "", "clear button")

fill()
sent = {}
frame.name.box:SetText("Altbank")
frame.all.__scripts.OnClick(frame.all, "LeftButton")
ok(clickMenu("Cloth") and #sent == 1 and sent[1].to == "Altbank" and sent[1].n == 12, "send all from the window")
event("MAIL_SEND_SUCCESS")
flush()
event("MAIL_SEND_SUCCESS")
flush()
ok(#sent == 2, "send all finishes")

fill()
sent = {}
ns.chardb.lastTo = "Altbank"
frame.tabInbox.__scripts.OnClick(frame.tabInbox, "LeftButton")
ok(tabClicked == 1 and frame.inboxPane:IsShown() and W.NameBox() == nil, "back to inbox")
M.mods.alt = true
HandleModifiedItemClick("link", { GetBagAndSlot = function() return 0, 15 end })
M.mods.alt = false
ok(#sent == 1 and frame.sendPane:IsShown(), "quick send switches the window to send")
event("MAIL_SEND_SUCCESS")
flush()
local realGet = GetSendMailItem
function GetSendMailItem(i) if i == 1 then return "Draft thing", 1, 134400, 1, 1 end end
fill()
M.mods.alt = true
HandleModifiedItemClick("link", { GetBagAndSlot = function() return 0, 15 end })
M.mods.alt = false
ok(#sent == 1 and printed[#printed]:find("mail you are writing"), "quick send only attaches to a started mail")
GetSendMailItem = realGet
local cleared = 0
SendMailNameEditBox.HasFocus = function() return true end
SendMailNameEditBox.ClearFocus = function() cleared = cleared + 1 end
frame.tabSend.__scripts.OnClick(frame.tabSend, "LeftButton")
ok(cleared == 1, "hidden default box does not keep the keyboard")
SendMailNameEditBox.HasFocus = nil

frame.options.__scripts.OnClick(frame.options, "LeftButton")
ok(clickMenu("Use the default mailbox window"), "default window option")
ok(not frame:IsShown() and closed == 0 and MailFrame:IsShown(), "option hands back the default window")
ok(clickMenu("Use the default mailbox window") and frame:IsShown(), "option brings the reskin back")
for _, f in ipairs(M.frames) do
	if f == frame and f.__scripts.OnUpdate then f.__scripts.OnUpdate(f, 1) end
end

local restored = 0
local realPoint = MailFrame.SetPoint
MailFrame.SetPoint = function(_, point) if point == "TOPLEFT" then restored = restored + 1 end end
frame.close.__scripts.OnClick(frame.close, "LeftButton")
ok(closed == 1 and not frame:IsShown(), "closing the window closes the mailbox")
ok(restored == 0, "default window stays hidden until the mailbox closes")
event("MAIL_CLOSED")
ok(restored == 1, "default window restored after closing")
MailFrame.SetPoint = realPoint
MailFrame.__shown = true
event("MAIL_SHOW")
flush()
ok(frame:IsShown() and frame.inboxPane:IsShown(), "reopens on the inbox")
MailFrame.__shown = false
event("MAIL_CLOSED")
ok(not frame:IsShown() and closed == 1, "mailbox closing hides the window")
ns.db.reskin = false
MailFrame.__shown = true
event("MAIL_SHOW")
ok(not frame:IsShown(), "stays away when turned off")

print_real(string.format("ok: %d checks (amail)", M.checks()))
