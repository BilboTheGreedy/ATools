local M = dofile("tools/mock.lua")
local ok, event, flush, printed = M.ok, M.event, M.flush, M.printed

local clock = 1000000
time = function() return clock end
GetServerTime = function() return clock end
GetRealmName = function() return "Testrealm" end
ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1 } }
AuctionHouseFrame = M.obj("Frame")

local auctions = {}
local replicated = 0
local late = {}
C_AuctionHouse = {
	ReplicateItems = function() replicated = replicated + 1 end,
	GetNumReplicateItems = function() return #auctions end,
	GetReplicateItemInfo = function(i)
		local a = auctions[i + 1]
		if not a then return nil end
		if late[i] and late[i] > 0 then
			late[i] = late[i] - 1
			return nil, nil, a[2], 1, true, 1, "", 0, 0, a[3], 0, nil, nil, nil, nil, 0, a[1], false
		end
		return "Thing " .. a[1], 1, a[2], 1, true, 1, "", 0, 0, a[3], 0, nil, nil, nil, nil, 0, a[1], true
	end,
	GetBrowseResults = function()
		return { { itemKey = { itemID = 777 }, minPrice = 5000, totalQuantity = 12 } }
	end,
}

local hooks = {}
function hooksecurefunc(name, fn) hooks[name] = fn end
function HandleModifiedItemClick() end

M.load("ACore", "ACore")
local ns = M.load("AAuction", "AAuction")
event("PLAYER_LOGIN")
ok(ns.db and ns.realmKey == "Testrealm-Alliance", "realm key")

ok(ns.Market({ { 100, 1 } }) == 100, "single market")
ok(ns.Market({ { 100, 10 }, { 200, 10 }, { 900, 10 } }) == 100, "lowest third")
ok(ns.Market({ { 100, 1 }, { 110, 1 }, { 120, 1 }, { 130, 1 }, { 5000, 20 } }) < 200, "outliers cut")
ok(ns.Market({}) == nil, "empty market")

ok(ns.StartScan() == false, "no scan with ah closed")
event("AUCTION_HOUSE_SHOW")
ok(ns.ahOpen, "ah open")

auctions = {
	{ 100, 20, 2000 },
	{ 100, 10, 1500 },
	{ 100, 1, 9000 },
	{ 200, 1, 50000 },
	{ 200, 1, 0 },
	{ 301, 5, 500 },
}
for i = 1, 1200 do auctions[#auctions + 1] = { 1000 + i % 40, 2, 400 + i } end
late[3] = 2
late[900] = 1

ok(ns.StartScan() == true, "scan started")
ok(replicated == 1 and ns.Scanning(), "replicate requested")
ok(ns.StartScan() == false, "no double scan")
event("REPLICATE_ITEM_LIST_UPDATE")
ok(ns.scan.state == "reading" and ns.scan.total == #auctions, "reading")
flush()
ok(ns.scan.state == "done", "scan done " .. tostring(ns.scan.state))
ok(ns.scan.missing == 0, "late records resolved")

local market, minBuyout, seen, at, qty = AAuction.GetPrice(100)
ok(market == 100 and minBuyout == 100 and seen == 1 and qty == 31, "price of 100: " .. tostring(market) .. " " .. tostring(minBuyout) .. " " .. tostring(qty))
ok(AAuction.GetPrice(200) == 50000, "bid only auctions ignored")
ok(AAuction.GetPrice(301) == 100, "stack split to unit")
ok(AAuction.GetPrice(999999) == nil, "unknown item")
ok(ns.Total() == 43, "total items " .. ns.Total())
ok(ns.Realm().scans == 1 and ns.Realm().last == clock, "scan recorded")
ok(ns.StartScan() == false and ns.CooldownLeft() > 0, "cooldown")

clock = clock + 1000
auctions = { { 100, 10, 4000 }, { 301, 1, 100 } }
late = {}
ok(ns.StartScan() == true, "second scan")
event("REPLICATE_ITEM_LIST_UPDATE")
flush()
local m2, b2, n2, _, q2 = ns.GetPrice(100)
ok(b2 == 400 and m2 == 190 and n2 == 2 and q2 == 10, "rolling value " .. m2 .. " " .. b2)
ok(ns.Trend(ns.Entry(100)) > 1, "trend up")
ok(ns.Average(ns.Entry(100)) == 250, "history average")
ok(select(5, ns.GetPrice(200)) == 0, "gone items have zero quantity")
ok(#ns.Entry(100).h == 2, "history kept")

clock = clock + 1000
ok(ns.StartScan() == true, "third scan")
auctions = {}
event("REPLICATE_ITEM_LIST_UPDATE")
ok(ns.scan.state == "waiting", "empty event ignored")
event("AUCTION_HOUSE_CLOSED")
ok(not ns.Scanning(), "scan stops when ah closes")
flush()
ok(ns.GetPrice(100) == 190, "aborted scan changes nothing")
event("AUCTION_HOUSE_SHOW")

event("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
flush()
ok(AAuction.GetPrice(777) == 5000, "browse results learned")
ns.db.passive = false
ns.Realm().items[777] = nil
event("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
ok(AAuction.GetPrice(777) == nil, "passive off")
ns.db.passive = true

local lines = {}
local tip = GameTooltip
tip.AddDoubleLine = function(_, l, r) lines[#lines + 1] = l .. " = " .. r end
tip.GetOwner = function() return { count = 5 } end
ok(#M.tooltipCalls == 1, "tooltip hook")
M.tooltipCalls[1](tip, { id = 100 })
ok(#lines == 3 and lines[1]:find("Market value") and lines[1]:find("x5"), "tooltip lines " .. #lines)
ok(lines[2]:find("Min buyout") and lines[3]:find("Vendor"), "tooltip order")
lines = {}
ns.db.stack = false
ns.db.vendor = false
M.tooltipCalls[1](tip, { id = 100 })
ok(#lines == 2 and not lines[1]:find("x5"), "no stack, no vendor")
lines = {}
M.tooltipCalls[1](tip, { id = 424242 })
ok(#lines == 0, "nothing for unknown items")
ns.db.tooltip = false
M.tooltipCalls[1](tip, { id = 100 })
ok(#lines == 0, "tooltip off")
ns.db.tooltip = true
ns.db.stack = true
ns.db.vendor = true

local frame = AAuctionFrame
ok(frame and frame:IsShown() and ns.UI.View() == "sell" and ns.UI.Docked(), "opens docked on the Sell view with the auction house")
event("AUCTION_HOUSE_CLOSED")
ok(not frame:IsShown() and not ns.UI.Docked(), "closes again with the auction house")
event("AUCTION_HOUSE_SHOW")
ns.UI.Show("prices")
flush()
ok(frame and frame:IsShown() and ns.UI.View() == "prices", "window shown")
ok(#frame.list.data == ns.Total(), "rows listed " .. #frame.list.data)
for _, key in ipairs({ "name", "qty", "min", "market", "trend", "age" }) do
	for _, desc in ipairs({ false, true }) do
		local rows = ns.Rows("", key, desc)
		ok(#rows == ns.Total(), "sort " .. key)
	end
end
local byMin = ns.Rows("", "min", true)
ok(byMin[1].e.b >= byMin[#byMin].e.b, "sorted by min buyout")
for _, b in ipairs(frame.heads) do
	b.__scripts.OnClick(b, "LeftButton")
	b.__scripts.OnClick(b, "LeftButton")
end
for _, row in ipairs(frame.list.rows) do
	if row:IsShown() and row.data then
		row.__scripts.OnEnter(row)
		M.mods.shift = true
		row.__scripts.OnClick(row, "LeftButton")
		M.mods.shift = false
		row.__scripts.OnLeave(row)
	end
end
local eb = frame.search.box
eb:SetText("item 1004")
eb.__scripts.OnTextChanged(eb)
flush()
ok(#frame.list.data == 1, "search narrows " .. #frame.list.data)
eb:SetText("")
eb.__scripts.OnTextChanged(eb)
flush()
frame.options.__scripts.OnClick(frame.options, "LeftButton")
clock = clock + 2000
frame.scanButton.__scripts.OnClick(frame.scanButton, "LeftButton")
ok(ns.Scanning(), "scan button starts")
frame.scanButton.__scripts.OnClick(frame.scanButton, "LeftButton")
ok(not ns.Scanning(), "scan button stops")

SlashCmdList["AAUCTION"]("thing")
SlashCmdList["AAUCTION"]("scan")
SlashCmdList["AAUCTION"]("stop")
SlashCmdList["AAUCTION"]("reset")
clock = clock + 40 * 86400
SlashCmdList["AAUCTION"]("purge 30")
ok(ns.Total() == 0, "purge removes old items")
SlashCmdList["AAUCTION"]("")
AAuction_ToggleBinding()
SlashCmdList["ACORE"]("auction")
flush()

local Sell, SellUI = ns.Sell, ns.SellUI
local info = {
	[2589] = { "Linen Cloth", 1, 7, 13 },
	[2590] = { "Rare Blade", 3, 2, 5000 },
	[2591] = { "Quest Thing", 1, 12, 0 },
	[2592] = { "Odd Rock", 1, 7, 40 },
	[2593] = { "Plain Sword", 2, 2, 800 },
	[2594] = { "Bound Ring", 2, 4, 100 },
	[2595] = { "Junk Bit", 0, 15, 9 },
}
local function link(id) return "|cffffffff|Hitem:" .. id .. "::::|h[" .. info[id][1] .. "]|h|r" end
C_Item.GetItemInfo = function(v)
	local id = type(v) == "number" and v or tonumber(tostring(v):match("item:(%d+)"))
	local it = info[id]
	if not it then return nil end
	return it[1], link(id), it[2], 10, 1, "x", "y", 20, "", 134400, it[4], it[3], 0
end
C_Item.GetItemInfoInstant = function(id)
	local it = info[id]
	if not it then return nil end
	return id, "x", "y", "", 134400, it[3], 0
end
local bags = {
	[0] = {
		{ id = 2589, n = 20 }, { id = 2589, n = 15 }, { id = 2590, n = 1 }, { id = 2591, n = 1 },
		{ id = 2592, n = 3 }, { id = 2593, n = 1 }, { id = 2593, n = 1 }, { id = 2594, n = 1, bound = true }, { id = 2595, n = 2 },
	},
}
C_Container = {
	GetContainerNumSlots = function(bag) return bags[bag] and 16 or 0 end,
	GetContainerItemInfo = function(bag, slot)
		local it = bags[bag] and bags[bag][slot]
		if not it then return nil end
		return { itemID = it.id, stackCount = it.n, hyperlink = link(it.id), quality = info[it.id][2], isBound = it.bound, isLocked = it.locked, iconFileID = 1 }
	end,
}
ItemLocation = {
	CreateFromBagAndSlot = function(_, bag, slot)
		return { bag = bag, slot = slot, GetBagAndSlot = function(self) return self.bag, self.slot end }
	end,
}
local function itemAt(loc) return bags[loc.bag][loc.slot] end
local posts, cancels, queries, sellQueries = {}, {}, {}, {}
local throttled, refuse = false, false
local AH = C_AuctionHouse
AH.IsSellItemValid = function(loc) return itemAt(loc).id ~= 2595 end
AH.GetItemCommodityStatus = function(loc) return itemAt(loc).id == 2589 and 2 or 1 end
AH.CalculateCommodityDeposit = function(_, _, qty) return qty * 2 end
AH.CalculateItemDeposit = function() return 30 end
AH.IsThrottledMessageSystemReady = function() return not throttled end
AH.MakeItemKey = function(id) return { itemID = id } end
AH.SendSearchQuery = function(key) queries[#queries + 1] = key.itemID end
AH.SendSellSearchQuery = function(key) sellQueries[#sellQueries + 1] = key.itemID end
AH.PostCommodity = function(loc, duration, qty, unit)
	if refuse then error("no") end
	posts[#posts + 1] = { kind = "commodity", id = itemAt(loc).id, duration = duration, qty = qty, price = unit }
end
AH.PostItem = function(loc, duration, qty, bid, buyout)
	if refuse then error("no") end
	posts[#posts + 1] = { kind = "item", id = itemAt(loc).id, slot = loc.slot, duration = duration, qty = qty, bid = bid, price = buyout }
end
local commodityResults, itemResults, ownedList = {}, {}, {}
AH.GetNumCommoditySearchResults = function() return #commodityResults end
AH.GetCommoditySearchResultInfo = function(_, i) return commodityResults[i] end
AH.GetNumItemSearchResults = function() return #itemResults end
AH.GetItemSearchResultInfo = function(_, i) return itemResults[i] end
AH.QueryOwnedAuctions = function() end
AH.GetNumOwnedAuctions = function() return #ownedList end
AH.GetOwnedAuctionInfo = function(i) return ownedList[i] end
AH.CanCancelAuction = function(id) return id ~= 99 end
AH.CancelAuction = function(id) cancels[#cancels + 1] = id end

ns.Sell.Modified = ns.Sell.Modified
event("AUCTION_HOUSE_CLOSED")
event("AUCTION_HOUSE_SHOW")
flush()
ok(Sell.Modern() and frame:IsShown() and ns.UI.View() == "sell", "sell view opens again")

local list = Sell.Items()
local by = {}
for _, e in ipairs(list) do by[e.id] = e end
ok(#list == 4 and by[2589] and by[2590] and by[2592] and by[2593], "sellable items listed " .. #list)
ok(not by[2591] and not by[2594] and not by[2595], "quest, bound and invalid items skipped")
ok(by[2589].count == 35 and by[2589].stacks == 2 and by[2589].commodity and not by[2593].commodity and by[2593].stacks == 2, "stacks merged")
ok(by[2592].price == 120 and by[2592].source == "vendor", "vendor fallback price " .. tostring(by[2592].price))
ok(Sell.NeedsConfirm(by[2592]) and Sell.NeedsConfirm(by[2590]), "no data and rare items need the Post button")

ok(Sell.Query(2589) and queries[1] == 2589 and not Sell.Query(2589), "commodity price query, not repeated")
commodityResults = {
	{ unitPrice = 90, quantity = 5, containsOwnerItem = true, numOwnerItems = 5 },
	{ unitPrice = 100, quantity = 40 },
	{ unitPrice = 140, quantity = 10 },
}
event("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
flush()
local price, source, low = Sell.Price(2589)
ok(low == 100 and price == 99 and source == "undercut" and Sell.own[2589] == 90, "undercut by a copper, own auctions ignored")
ns.db.sell.rule = "percent"
ns.db.sell.percent = 10
ok(Sell.Price(2589) == 90, "undercut by percent")
ns.db.sell.rule = "match"
ok(Sell.Price(2589) == 100, "match lowest")
ns.db.sell.rule = "copper"
Sell.lowest[2589] = 10
price, source = Sell.Price(2589)
ok(price == 15 and source == "floor", "never below vendor plus margin and the cut " .. price)
Sell.lowest[2589] = 100
ns.db.sell.prices[2589] = 250
ok(select(2, Sell.Price(2589)) == "kept" and Sell.Price(2589) == 250, "remembered price wins")
ns.db.sell.prices[2589] = nil
ns.Observe(2593, 30000, 4)
Sell.lowest[2593] = nil
ok(Sell.Price(2593) == 29999, "falls back to the last seen lowest")
ns.Realm().items[2593].q = 0
ok(Sell.Price(2593) == 30000 and select(2, Sell.Price(2593)) == "market", "then to market value")

throttled = true
ok(not Sell.Query(2593) and #sellQueries == 0, "query waits while throttled")
throttled = false
event("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
ok(sellQueries[1] == 2593, "queued query sent as an item sell search")
itemResults = { { buyoutAmount = 26000, quantity = 1 }, { buyoutAmount = 20000, quantity = 1, containsOwnerItem = true } }
event("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 2593 })
flush()
ok(Sell.lowest[2593] == 26000 and Sell.Price(2593) == 25999, "item search result")

SellUI.Refresh()
local sv = frame.sell
ok(#sv.list.data == 4, "sell rows")
local function row(id)
	for i, d in ipairs(sv.list.data) do
		if d.id == id then
			local r = sv.list.rows[1]
			r.data = d
			return r
		end
	end
end
local before = #printed
local r = row(2589)
r.__scripts.OnEnter(r)
r.__scripts.OnClick(r, "LeftButton")
ok(#posts == 1 and posts[1].kind == "commodity" and posts[1].qty == 35 and posts[1].price == 99 and posts[1].duration == 2, "one click posts the commodity")
event("AUCTION_HOUSE_AUCTION_CREATED")
ok(printed[#printed]:find("posted 35x Linen Cloth"), "post log")
r = row(2593)
r.__scripts.OnClick(r, "LeftButton")
ok(#posts == 2 and posts[2].kind == "item" and posts[2].slot == 6 and posts[2].qty == 1 and posts[2].price == 25999 and posts[2].bid == nil, "one click posts one stack")
bags[0][6] = nil
event("BAG_UPDATE_DELAYED")
flush()
r = row(2593)
r.__scripts.OnClick(r, "LeftButton")
ok(#posts == 3 and posts[3].slot == 7, "next click posts the next stack")

r = row(2590)
r.__scripts.OnClick(r, "LeftButton")
ok(#posts == 3 and SellUI.State() == 2590, "rare item is selected, not posted")
ok(sv.detail:IsShown() and sv.status.__text:find("press Post"), "detail shown with the reason")
sv.gold.box:SetText("12")
sv.silver.box:SetText("50")
sv.copper.box:SetText("0")
sv.gold.box.__scripts.OnTextChanged(sv.gold.box)
ok(select(2, SellUI.State()).price == 125000, "typed price")
sv.durations[3].__scripts.OnClick(sv.durations[3])
sv.bid.__scripts.OnClick(sv.bid)
ok(ns.db.sell.duration == 3 and ns.db.sell.bid == 95, "duration and bid choice")
sv.keep.__scripts.OnClick(sv.keep)
ok(ns.db.sell.prices[2590] == 125000, "remember price")
sv.post.__scripts.OnClick(sv.post)
ok(#posts == 4 and posts[4].id == 2590 and posts[4].price == 125000 and posts[4].duration == 3 and posts[4].bid == 118750, "Post button posts with details")
sv.keep.__scripts.OnClick(sv.keep)
ok(ns.db.sell.prices[2590] == nil, "forget price")
ns.db.sell.bid, ns.db.sell.duration = 100, 2

r = row(2589)
r.__scripts.OnClick(r, "RightButton")
ok(SellUI.State() == 2589 and sv.qty:IsShown(), "right-click selects a commodity")
sv.qty.box:SetText("10")
sv.qty.box.__scripts.OnTextChanged(sv.qty.box)
ok(sv.post.label.__text == "Post 10" and sv.lines.deposit.__text:find("20c"), "quantity and deposit " .. sv.lines.deposit.__text)
sv.post.__scripts.OnClick(sv.post)
ok(posts[#posts].qty == 10 and posts[#posts].kind == "commodity", "partial commodity post")
sv.qty.box:SetText("9999")
sv.qty.box.__scripts.OnTextChanged(sv.qty.box)
ok(Sell.Quantity(by[2589], 9999) == 35, "quantity capped")

ns.db.sell.threshold = 1000
ok(Sell.NeedsConfirm(Sell.Find(2589)), "safety limit")
ns.db.sell.threshold = 0
ok(not Sell.NeedsConfirm(Sell.Find(2589)), "no limit")
ns.db.sell.threshold = 500000

local n = #posts
throttled = true
ok(Sell.Click(Sell.Find(2589)) == "error" and #posts == n and printed[#printed]:find("busy"), "post refused while throttled")
throttled = false
refuse = true
ok(Sell.Click(Sell.Find(2589)) == "error" and printed[#printed]:find("refused"), "post error reported")
refuse = false
for _ = 1, #Sell.pending do event("AUCTION_HOUSE_AUCTION_CREATED") end
Sell.Click(Sell.Find(2589))
event("AUCTION_HOUSE_SHOW_ERROR", 5)
ok(printed[#printed]:find("could not post Linen Cloth"), "server error reported")

ok(hooks.HandleModifiedItemClick, "bag click hook")
n = #posts
M.mods.alt = true
hooks.HandleModifiedItemClick(link(2589), ItemLocation:CreateFromBagAndSlot(0, 2))
ok(#posts == n + 1 and posts[#posts].id == 2589, "alt-click posts")
hooks.HandleModifiedItemClick(link(2590), ItemLocation:CreateFromBagAndSlot(0, 3))
ok(#posts == n + 1 and printed[#printed]:find("not posted"), "alt-click keeps the safety rules")
ns.db.sell.alt = false
hooks.HandleModifiedItemClick(link(2589))
ok(#posts == n + 1, "alt-click option off")
ns.db.sell.alt = true
M.mods.alt = false
M.mods.shift = true
hooks.HandleModifiedItemClick(link(2592))
ok(SellUI.State() == 2592, "shift-click jumps to the item")
M.mods.shift = false
hooks.HandleModifiedItemClick(link(2589))
ok(#posts == n + 1, "plain click does nothing")

ownedList = {
	{ auctionID = 11, itemKey = { itemID = 2589 }, buyoutAmount = 150, quantity = 20, status = 0 },
	{ auctionID = 12, itemKey = { itemID = 2589 }, buyoutAmount = 95, quantity = 5, status = 0 },
	{ auctionID = 13, itemKey = { itemID = 2593 }, buyoutAmount = 40000, quantity = 1, status = 1 },
	{ auctionID = 99, itemKey = { itemID = 2593 }, buyoutAmount = 40000, quantity = 1, status = 0 },
}
event("OWNED_AUCTIONS_UPDATED")
flush()
local under = Sell.Undercut()
ok(#under == 2 and under[1].auction == 11 and under[1].low == 100, "undercut list " .. #under)
sv.underTab.__scripts.OnClick(sv.underTab)
ok(#sv.list.data == 2 and sv.underTab.label.__text == "Undercut (2)", "undercut view")
r = sv.list.rows[1]
r.data = sv.list.data[1]
r.__scripts.OnClick(r, "LeftButton")
ok(cancels[1] == 11 and #Sell.Undercut() == 1, "click cancels one auction")
r.data = Sell.Undercut()[1]
r.__scripts.OnClick(r, "LeftButton")
ok(#cancels == 1 and printed[#printed]:find("cannot be cancelled"), "uncancellable auction reported")
sv.bagsTab.__scripts.OnClick(sv.bagsTab)

local opts = ns.Options()
local checks, radios = 0, 0
for _, e in ipairs(opts) do
	if e.func and e.checked ~= nil then checks = checks + 1 end
end
ok(#opts > 25 and checks > 15, "options entries " .. #opts)
for _, e in ipairs(opts) do
	if e.text == "Match the lowest" then e.func() end
	if e.text == "200 gold per post" then e.func() end
	if e.text == "Open the Sell view with the auction house" then e.func() end
end
ok(ns.db.sell.rule == "match" and ns.db.sell.threshold == 2000000 and ns.db.sell.open == false, "options change settings")
frame.options.__scripts.OnClick(frame.options, "LeftButton")
event("AUCTION_HOUSE_CLOSED")
frame:Hide()
event("AUCTION_HOUSE_SHOW")
ok(not frame:IsShown(), "does not open with the auction house when turned off")
ok(Sell.Post(Sell.Find(2589)) == true, "post still works from code")
event("AUCTION_HOUSE_CLOSED")
ok(Sell.Post(by[2589]) == false and next(Sell.lowest) == nil, "no posting with the auction house closed")

local posted
C_AuctionHouse.PostItem = nil
function ClickAuctionSellItemButton() end
function ClearCursor() end
C_Container.PickupContainerItem = function() end
function PostAuction(bid, buyout, runTime, size, stacks) posted = { bid, buyout, runTime, size, stacks } end
event("AUCTION_HOUSE_SHOW")
ok(not Sell.Modern() and Sell.Classic(), "classic fallback chosen")
ok(Sell.Post(by[2589], { price = 50, qty = 20 }) and posted[2] == 1000 and posted[4] == 20 and posted[5] == 1, "classic post of one stack")
SlashCmdList["AAUCTION"]("sell")
ok(ns.UI.View() == "sell", "slash sell")
frame.pricesTab.__scripts.OnClick(frame.pricesTab)
frame.sellTab.__scripts.OnClick(frame.sellTab)
event("AUCTION_HOUSE_CLOSED")

local warn, confirmed = false, 0
C_AuctionHouse.PostItem = function(loc, duration, qty, bid, buyout)
	posts[#posts + 1] = { kind = "item", id = itemAt(loc).id, slot = loc.slot, duration = duration, qty = qty, bid = bid, price = buyout }
	return warn
end
C_AuctionHouse.ConfirmPostItem = function() confirmed = confirmed + 1 end
ns.db.sell.rule = "copper"
event("AUCTION_HOUSE_SHOW")
ok(Sell.Modern(), "modern posting again")

itemResults = { { buyoutAmount = 26000, quantity = 3 }, { buyoutAmount = 31000, quantity = 1 } }
event("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 2593 })
flush()
ok(Sell.lowest[2593] == 26000 and ns.Entry(2593).q == 4, "grouped item results keep the unit price")

ITEM_CONJURED = "Conjured Item"
info[2596] = { "Conjured Water", 1, 0, 0 }
bags[0][10] = { id = 2596, n = 5 }
C_TooltipInfo = {
	GetBagItem = function(bag, slot)
		local it = bags[bag][slot]
		local lines = { { leftText = info[it.id][1] } }
		if it.id == 2596 then lines[2] = { leftText = "Conjured Item" } end
		return { lines = lines }
	end,
}
ok(not Sell.Find(2596) and Sell.Find(2589), "conjured items are not listed")

n = #posts
M.mods.alt = true
hooks.HandleModifiedItemClick(link(2589))
ok(#posts == n, "alt-click on a link outside the bags posts nothing")
M.mods.alt = false

warn = true
local e = Sell.Find(2593)
ok(not Sell.NeedsConfirm(e), "plain item would post in one click")
ok(Sell.Click(e) == "confirm" and Sell.awaiting and confirmed == 0, "a client warning stops the one-click post")
ok(Sell.Click(e, { force = true }) == "posted" and confirmed == 1 and not Sell.awaiting, "pressing Post again confirms it")
warn = false

e.market = 100000
ok(Sell.NeedsConfirm(e), "far below market needs the Post button")

Sell.lowest[2589] = nil
ns.Observe(2589, 95, 5)
Sell.owned = { { id = 2589, unit = 95, qty = 5 } }
local p, src = Sell.Price(2589)
ok(p == 95 and src == "own", "does not undercut my own auction " .. tostring(p) .. " " .. tostring(src))
Sell.owned = {}
ok(Sell.Price(2589) == 94, "undercuts when it is not mine")

C_AuctionHouse.SupportsCopperValues = function() return false end
ok(Sell.Step() == 100, "silver steps when the client has no copper prices")
info[2597] = { "Ore", 1, 7, 140 }
bags[0][11] = { id = 2597, n = 1 }
Sell.lowest[2597] = 290
local sp, ss = Sell.Price(2597)
ok(sp == 200 and ss == "floor", "silver rounding keeps the vendor floor " .. tostring(sp))
Sell.lowest[2597] = 1250
ok(Sell.Price(2597) == 1100, "undercut by one silver step " .. Sell.Price(2597))
local ore = Sell.Find(2597)
ok(Sell.Post(ore, { price = 1150 }) == false, "copper price refused")
n = #posts
ok(Sell.Post(ore, { price = 1100, bid = 95 }) == true and posts[#posts].price == 1100 and posts[#posts].bid == 1000, "bid rounded to silver")
C_AuctionHouse.SupportsCopperValues = nil
bags[0][11] = nil

local browseQueries, moreCalls, full = 0, 0, false
local page = {}
C_AuctionHouse.SendBrowseQuery = function(q)
	ok(type(q) == "table" and q.searchString == "" and type(q.sorts) == "table", "browse query shape")
	browseQueries = browseQueries + 1
end
C_AuctionHouse.RequestMoreBrowseResults = function() moreCalls = moreCalls + 1 end
C_AuctionHouse.HasFullBrowseResults = function() return full end
C_AuctionHouse.GetBrowseResults = function() return page end
clock = clock + 2000
local scansBefore = ns.Realm().scans
ok(ns.ScanKind() == "replicate" and ns.StartScan() == true, "full scan asked first")
flush()
ok(browseQueries == 1 and not ns.Scanning() and ns.CooldownLeft() == 0, "no answer falls back to browsing and keeps the cooldown free")
ok(ns.StartScan("replicate") == true, "second try")
flush()
ok(ns.ScanKind() == "browse", "two silent full scans switch to browsing")
ok(ns.StartScan() == true and ns.scan.state == "browsing", "browse scan started")
page = {
	{ itemKey = { itemID = 5001 }, minPrice = 300, totalQuantity = 10 },
	{ itemKey = { itemID = 5002, itemLevel = 20 }, minPrice = 9000, totalQuantity = 1 },
}
event("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
ok(moreCalls == 1 and ns.Scanning(), "asks for the next page")
full = true
event("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", {
	{ itemKey = { itemID = 5002, itemLevel = 25 }, minPrice = 7000, totalQuantity = 2 },
	{ itemKey = { itemID = 5003 }, minPrice = 0, totalQuantity = 2 },
})
ok(ns.scan.state == "done" and ns.Realm().scans == scansBefore + 1, "browse scan finished")
ok(AAuction.GetPrice(5001) == 300 and select(2, AAuction.GetPrice(5002)) == 7000 and select(5, AAuction.GetPrice(5002)) == 3, "browse prices stored")
ok(AAuction.GetPrice(5003) == nil and select(5, ns.GetPrice(2589)) == 0, "unpriced rows skipped, unseen items emptied")
ns.RetryFullScan()
ok(ns.ScanKind() == "replicate", "fast scan can be tried again")
flush()

ns.Realm().items[9001] = { m = 1000, b = 500, q = 3, n = 3, t = clock }
ns.Realm().items[9002] = { m = 1000, b = 900, q = 3, n = 3, t = clock }
ns.Realm().items[9003] = { m = 1000, b = 100, q = 0, n = 3, t = clock }
local dealRows = ns.Rows("", "name", false, true)
ok(#dealRows == 1 and dealRows[1].id == 9001, "deals are items listed well below market")
SlashCmdList["AAUCTION"]("deals")
flush()
ok(ns.UI.View() == "prices" and #frame.list.data == 1, "deals view")
frame.dealsButton.__scripts.OnClick(frame.dealsButton)
ok(#frame.list.data > 1, "deals off again")
ok(#Sell.Durations() == 3, "duration names")
event("AUCTION_HOUSE_CLOSED")

print_real(string.format("ok: %d checks", M.checks()))
