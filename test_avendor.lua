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

local answer, accept = "", true
function StaticPopup_Show(name)
	local d = StaticPopupDialogs[name]
	if not accept or not d.OnAccept then return end
	local box = { GetText = function() return answer end, SetText = function() end, HighlightText = function() end }
	d.OnAccept({ GetEditBox = function() return box end })
end

local items = {
	{ id = 100, name = "Arrow", price = 10, stackCount = 200, numAvailable = -1, isUsable = true },
	{ id = 101, name = "Water", price = 25, stackCount = 1, numAvailable = -1, isUsable = true },
	{ id = 102, name = "Recipe", price = 1000, stackCount = 1, numAvailable = 1, isUsable = true },
	{ id = 103, name = "Axe", price = 5000, stackCount = 1, numAvailable = 2, isUsable = false },
}
local counts = { [100] = 2, [101] = 3 }
local gold = 1000000
local bought = {}
C_MerchantFrame = { GetItemInfo = function(i) return items[i] end }
function GetMerchantNumItems() return #items end
function GetMerchantItemID(i) return items[i] and items[i].id end
function GetMerchantItemMaxStack(i) return items[i].stackCount > 1 and 1 or 20 end
function BuyMerchantItem(i, n)
	local it = items[i]
	bought[#bought + 1] = { i, n }
	local units = n or it.stackCount
	counts[it.id] = (counts[it.id] or 0) + units
	gold = gold - it.price * units / it.stackCount
end
function GetMoney() return gold end
C_Item.GetItemCount = function(id) return counts[id] or 0 end
C_Item.GetItemInfoInstant = function(id) return id, "", "", "", 1, id == 102 and 9 or 4, 0 end
C_Item.GetItemInfo = function(id) return "Thing " .. id, "|Hitem:" .. id .. "|h[Thing " .. id .. "]|h" end
ITEM_SPELL_KNOWN = "Already known"
C_TooltipInfo = { GetMerchantItem = function(i) return { lines = { { leftText = "x" }, { leftText = i == 3 and "Already known" or "y" } } } end }
local repaired
function CanMerchantRepair() return true end
function GetRepairAllCost() return 500, true end
function RepairAllItems(guild) repaired = guild and "guild" or "own" end
function CanGuildBankRepair() return true end
function GetGuildBankWithdrawMoney() return -1 end
MERCHANT_ITEMS_PER_PAGE = 10
MerchantFrame = M.obj("Frame")
MerchantFrame.selectedTab = 1
function MerchantFrame_UpdateMerchantInfo() end
for slot = 1, 10 do
	local f = M.obj("Frame")
	f.ItemButton = M.obj("Button")
	f.ItemButton.__id = slot <= #items and slot or 0
	f.ItemButton.icon = M.obj("Texture")
	_G["MerchantItem" .. slot] = f
end

local bags = { [0] = {
	{ itemID = 500, hyperlink = "|Hitem:500|h[Epic]|h", quality = 4, stackCount = 1 },
	{ itemID = 501, hyperlink = "|Hitem:501|h[Junk]|h", quality = 0, stackCount = 1 },
	{ itemID = 502, hyperlink = "|Hitem:502|h[Kept]|h", quality = 1, stackCount = 1 },
	{ itemID = 503, hyperlink = "|Hitem:503|h[Wish]|h", quality = 2, stackCount = 1 },
} }
local buyback = {}
local sold = {}
C_Container = {
	GetContainerNumSlots = function(bag) return bag == 0 and 8 or 0 end,
	GetContainerItemInfo = function(bag, slot) return bags[bag] and bags[bag][slot] end,
	UseContainerItem = function(bag, slot)
		local it = bags[bag][slot]
		if it then
			bags[bag][slot] = nil
			buyback[#buyback + 1] = it
			sold[#sold + 1] = it.itemID
		end
	end,
}
function GetNumBuybackItems() return #buyback end
function GetBuybackItemLink(i) return buyback[i] and buyback[i].hyperlink end
local returned = 0
function BuybackItem(i)
	local it = table.remove(buyback, i)
	returned = returned + 1
	for slot = 1, 8 do
		if not bags[0][slot] then bags[0][slot] = it break end
	end
end
ALootDB = { lists = { { name = "Wishlist", items = { [503] = true } } } }

M.load("ACore", "ACore")
local ns = M.load("AVendor", "AVendor")
event("PLAYER_LOGIN")
ok(ns.db.repair == true, "repair on without ABag")

ns.chardb.restock[101] = 40
ns.chardb.restock[100] = 400
event("MERCHANT_SHOW")
flush()
ok(repaired == "own", "repaired")
ok(counts[101] == 40, "water restocked " .. counts[101])
ok(counts[100] == 402, "arrows restocked in batches " .. counts[100])
local found
for _, p in ipairs(printed) do if p:find("restocked") then found = true end end
ok(found, "restock summary")

counts[101] = 0
ns.db.restockCap = 500
local n = #bought
ns.Merchant.Restock(true)
ok(counts[101] == 20, "spending limit " .. counts[101])
ok(printed[#printed]:find("spending limit"), "limit message")
ns.db.restockCap = 0
ns.Merchant.Restock(true)
ok(counts[101] == 40, "no limit")
ns.Merchant.Restock(true)
ok(printed[#printed]:find("nothing to restock"), "nothing to restock")

ns.Merchant.Decorate()
MerchantFrame_UpdateMerchantInfo()
local b1 = MerchantItem1.ItemButton
ok(b1.__hooks and b1.__hooks.OnClick, "click hook")

M.mods.alt = true
local before = counts[101]
b1.__hooks.OnClick(MerchantItem2.ItemButton, "LeftButton")
ok(counts[101] == before + 20, "alt-click buys a stack")
answer = "60"
b1.__hooks.OnClick(MerchantItem2.ItemButton, "RightButton")
ok(ns.chardb.restock[101] == 60, "alt-right-click sets restock")
answer = "0"
b1.__hooks.OnClick(MerchantItem2.ItemButton, "RightButton")
ok(ns.chardb.restock[101] == nil, "zero removes")
M.mods.alt = false
M.mods.shift = true
answer = "7"
before = counts[101]
b1.__hooks.OnClick(MerchantItem2.ItemButton, "RightButton")
ok(counts[101] == before + 7, "shift-right-click buys an amount")
M.mods.shift = false
before = counts[103] or 0
ns.Merchant.Buy(4, 10)
ok((counts[103] or 0) == before + 2, "limited stock respected")
gold = 30
ns.Merchant.Buy(2, 20)
ok(gold >= 0, "never overspends " .. gold)
gold = 1000000
MerchantFrame.selectedTab = 2
ns.Merchant.Decorate()
b1.__hooks.OnClick(MerchantItem2.ItemButton, "LeftButton")
MerchantFrame.selectedTab = 1

ns.db.guildRepair = true
ns.Merchant.Repair()
ok(repaired == "guild", "guild repair")
ns.db.repair = false
repaired = nil
ns.Merchant.Repair()
ok(repaired == nil, "repair off")

ns.db.neverSell[502] = true
ns.Protect.Snap()
accept = false
C_Container.UseContainerItem(0, 2)
flush()
ok(#sold == 1 and returned == 0, "junk sells freely")
C_Container.UseContainerItem(0, 1)
flush()
ok(returned == 1 and bags[0][1] ~= nil or bags[0][2] ~= nil, "epic bought back")
ok(returned == 1, "buyback count " .. returned)
event("BAG_UPDATE_DELAYED")
flush()
local function slotOf(id)
	for slot = 1, 8 do
		if bags[0][slot] and bags[0][slot].itemID == id then return slot end
	end
end
C_Container.UseContainerItem(0, slotOf(502))
flush()
ok(returned == 2, "never-sell bought back")
event("BAG_UPDATE_DELAYED")
flush()
C_Container.UseContainerItem(0, slotOf(503))
flush()
ok(returned == 3, "wishlist bought back")
event("BAG_UPDATE_DELAYED")
flush()
accept = true
C_Container.UseContainerItem(0, slotOf(500))
flush()
ok(returned == 4 and not slotOf(500), "confirmed sale goes through")
AGear = { IsUpgrade = function() return true end }
ok(ns.Protect.Reason({ id = 900, quality = 1 }) == "is an upgrade for you", "upgrade check")
AGear = nil
ns.db.protect = false
ok(ns.Protect.Reason({ id = 901, quality = 4 }) == nil, "protection off")
ok(ns.Protect.Reason({ id = 502, quality = 1 }) ~= nil, "never-sell always asks")
ns.db.protect = true
ok(AVendor.IsProtected(502, nil, 1) and not AVendor.IsProtected(501, nil, 0), "protection check for other addons")

bags[0][6] = { itemID = 600, hyperlink = "|Hitem:600|h[Scrap]|h", quality = 1, stackCount = 5 }
bags[0][7] = { itemID = 600, hyperlink = "|Hitem:600|h[Scrap]|h", quality = 1, stackCount = 2 }
bags[0][8] = { itemID = 601, hyperlink = "|Hitem:601|h[Bound]|h", quality = 1, stackCount = 1, hasNoValue = true }
SlashCmdList["AVENDOR"]("sell 600")
SlashCmdList["AVENDOR"]("sell 601")
SlashCmdList["AVENDOR"]("sell")
ok(ns.db.alwaysSell[600], "slash sell")
event("MERCHANT_CLOSED")
local soldBefore, returnedBefore = #sold, returned
event("MERCHANT_SHOW")
flush()
ok(#sold - soldBefore == 2 and not slotOf(600) and slotOf(601), "always-sell list sold " .. (#sold - soldBefore))
ok(returned == returnedBefore, "listed sales are not bought back")
local listed
for _, p in ipairs(printed) do if p:find("sold 2 listed stacks") then listed = true end end
ok(listed, "listed sale summary")
SlashCmdList["AVENDOR"]("keep 600")
ok(ns.db.neverSell[600] and not ns.db.alwaysSell[600], "keep removes from always-sell")
ns.db.neverSell[600] = nil
ns.db.alwaysSell[601] = nil
local bundles = 0
for _, b in ipairs(bought) do if b[1] == 1 and b[2] ~= nil then bundles = bundles + 1 end end
ok(bundles == 0, "bundles are bought without a quantity")
event("MERCHANT_CLOSED")

SlashCmdList["AVENDOR"]("")
local frame = AVendorFrame
ok(frame and frame:IsShown(), "window shown")
ns.chardb.restock[100] = 400
ns:Fire("LISTS")
ok(#frame.list.data == 1 and frame.list.data[1].amount == 400, "restock rows")
answer = "101"
frame.addButton.__scripts.OnClick(frame.addButton, "LeftButton")
ok(ns.chardb.restock[101] == 101, "add item by id")
local function clickMenu(text)
	for _, f in ipairs(M.frames) do
		if f.entry and f.entry.text == text and f.entry.func then
			f.entry.func()
			return true
		end
	end
end
local row = frame.list.rows[1]
row.__scripts.OnClick(row, "LeftButton")
ok(clickMenu("Remove"), "row menu")
frame.neverTab.__scripts.OnClick(frame.neverTab, "LeftButton")
ok(#frame.list.data == 1 and frame.list.data[1].id == 502, "never-sell rows")
answer = "|Hitem:777|h[X]|h"
frame.addButton.__scripts.OnClick(frame.addButton, "LeftButton")
ok(ns.db.neverSell[777], "add never-sell by link")
row = frame.list.rows[1]
row.__scripts.OnClick(row, "LeftButton")
clickMenu("Remove")
ns.db.alwaysSell[650] = true
frame.sellTab.__scripts.OnClick(frame.sellTab, "LeftButton")
ok(#frame.list.data == 1 and frame.list.data[1].id == 650, "always-sell rows")
answer = "651"
frame.addButton.__scripts.OnClick(frame.addButton, "LeftButton")
ok(ns.db.alwaysSell[651], "add always-sell by id")
row = frame.list.rows[1]
row.__scripts.OnClick(row, "LeftButton")
clickMenu("Remove")
ok(not ns.db.alwaysSell[650], "always-sell row removed")
frame.restockTab.__scripts.OnClick(frame.restockTab, "LeftButton")
frame.nowButton.__scripts.OnClick(frame.nowButton, "LeftButton")
event("BAG_UPDATE_DELAYED")
flush()

for _, e in ipairs(ns.Options()) do
	if e.func then e.func() end
end
SlashCmdList["AVENDOR"]("keep 888")
ok(ns.db.neverSell[888], "slash keep")
SlashCmdList["AVENDOR"]("add |Hitem:889|h[Y]|h 15")
ok(ns.chardb.restock[889] == 15, "slash add")
SlashCmdList["AVENDOR"]("add nonsense")
SlashCmdList["AVENDOR"]("keep")
SlashCmdList["AVENDOR"]("restock")
SlashCmdList["AVENDOR"]("help")
SlashCmdList["AVENDOR"]("")
ok(not frame:IsShown(), "window toggles")

ABagDB = {}
ns.db.repair = nil
event("PLAYER_LOGIN")
ok(ns.db.repair == false, "repair defaults off with ABag")

print_real(string.format("ok: %d checks (avendor)", M.checks()))
