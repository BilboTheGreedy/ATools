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

SlashCmdList["AAUCTION"]("")
flush()
local frame = AAuctionFrame
ok(frame and frame:IsShown(), "window shown")
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

print_real(string.format("ok: %d checks", M.checks()))
