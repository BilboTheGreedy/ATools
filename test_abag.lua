local M = dofile("tools/mock.lua")
local ok, event, flush, printed = M.ok, M.event, M.flush, M.printed

local ITEMS = {
	[100] = { "Epic Sword", 4, 60, "Weapon", "Sword", "INVTYPE_WEAPON", 5000, 2, 2 },
	[101] = { "Green Helm", 2, 30, "Armor", "Plate", "INVTYPE_HEAD", 800, 4, 2 },
	[200] = { "Healing Potion", 1, 20, "Consumable", "Potion", "", 25, 0, 0 },
	[300] = { "Copper Ore", 1, 10, "Trade Goods", "Metal & Stone", "", 5, 7, 0 },
	[400] = { "Quest Thing", 1, 1, "Quest", "Quest", "", 0, 12, 0 },
	[500] = { "Broken Fang", 0, 1, "Miscellaneous", "Junk", "", 30, 15, 0 },
	[501] = { "Ruined Pelt", 0, 1, "Miscellaneous", "Junk", "", 12, 15, 0 },
	[600] = { "Hearthstone", 1, 1, "Miscellaneous", "Other", "", 0, 15, 0 },
}

C_Item.GetItemInfo = function(key)
	local id = type(key) == "number" and key or tonumber(tostring(key):match("item:(%d+)"))
	local d = ITEMS[id]
	if not d then return nil end
	return d[1], "|Hitem:" .. id .. "|h[" .. d[1] .. "]|h", d[2], d[3], 1, d[4], d[5], 20, d[6], 134400, d[7], d[8], 0, d[9]
end
C_Item.GetItemInfoInstant = function(id)
	local d = ITEMS[id]
	if not d then return nil end
	return id, d[4], d[5], d[6], 134400, d[8], 0
end
C_Item.GetDetailedItemLevelInfo = function(link)
	local id = tonumber(tostring(link):match("item:(%d+)"))
	return ITEMS[id] and ITEMS[id][3]
end

local bags = {
	[0] = { size = 16, items = { [1] = { 600, 1 }, [2] = { 500, 3 }, [3] = { 300, 20 }, [5] = { 100, 1 }, [9] = { 200, 5 } } },
	[1] = { size = 8, items = { [1] = { 501, 1 }, [2] = { 101, 1 }, [4] = { 400, 1 }, [8] = { 300, 7 } } },
	[2] = { size = 0, items = {} },
	[3] = { size = 0, items = {} },
	[4] = { size = 6, family = 4, items = {} },
	[-1] = { size = 24, items = { [1] = { 300, 20 }, [3] = { 100, 1 } } },
	[5] = { size = 10, items = { [2] = { 200, 2 } } },
	[-2] = { size = 4, items = {} },
}
KEYRING_CONTAINER = -2
BANK_CONTAINER = -1
NUM_BAG_SLOTS = 4
NUM_BANKBAGSLOTS = 6

local combat = false
function InCombatLockdown() return combat end
local money = 123456
function GetMoney() return money end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
time = os.time
local merchant = false
local cursor
local sortCalls, used, repaired = 0, 0, 0
function ClearCursor() cursor = nil end
function CanMerchantRepair() return true end
function GetRepairAllCost() return 500, true end
function RepairAllItems() repaired = repaired + 1 money = money - 500 end
function GetNumBankSlots() return 1, false end
function GetBankSlotCost() return 1000 end
function PurchaseSlot() end
function GetInventoryItemTexture() return 134400 end
RAID_CLASS_COLORS = { WARRIOR = { r = 1, g = 0.5, b = 0.2 } }

C_Container = {
	GetContainerNumSlots = function(bag) return bags[bag] and bags[bag].size or 0 end,
	GetContainerNumFreeSlots = function(bag)
		local b = bags[bag]
		if not b then return 0, 0 end
		local n = 0
		for i = 1, b.size do if not b.items[i] then n = n + 1 end end
		return n, b.family or 0
	end,
	GetContainerItemInfo = function(bag, slot)
		local it = bags[bag] and bags[bag].items[slot]
		if not it then return nil end
		local d = ITEMS[it[1]]
		return {
			iconFileID = 134400, stackCount = it[2], isLocked = false, quality = d[2],
			hyperlink = "|Hitem:" .. it[1] .. "|h[" .. d[1] .. "]|h", hasNoValue = d[7] == 0, itemID = it[1], isBound = false,
		}
	end,
	GetContainerItemCooldown = function() return 0, 0, 1 end,
	UseContainerItem = function(bag, slot)
		used = used + 1
		if merchant then bags[bag].items[slot] = nil end
	end,
	PickupContainerItem = function(bag, slot)
		local b = bags[bag]
		if cursor then
			local held = cursor.bag.items[cursor.slot]
			cursor.bag.items[cursor.slot] = b.items[slot]
			b.items[slot] = held
			cursor = nil
		elseif b.items[slot] then
			cursor = { bag = b, slot = slot }
		end
	end,
	ContainerIDToInventoryID = function(bag) return 19 + bag end,
	SortBags = function() sortCalls = sortCalls + 1 end,
	SortBankBags = function() sortCalls = sortCalls + 1 end,
}

local templated = 0
local realCreate = CreateFrame
function CreateFrame(kind, name, parent, template)
	if template == "ContainerFrameItemButtonTemplate" then templated = templated + 1 end
	return realCreate(kind, name, parent, template)
end
M.methods.IsProtected = function() return false end
M.methods.SetAlpha = function(self, a) self.__alpha = a end
M.methods.GetAlpha = function(self) return self.__alpha or 1 end
M.methods.SetID = function(self, id) self.__id = id end
M.methods.GetID = function(self) return self.__id end

M.load("ACore", "ACore")
local ns = M.load("ABag", "ABag")
event("PLAYER_LOGIN")
ok(ns.db and ns.knownReady, "ready")
ok(ns.db.chars["Tester - Realm"] and #ns.db.chars["Tester - Realm"].bags == 9, "bags cached at login")

local function shownButtons(kind)
	local n = 0
	local c = ns[kind == "bank" and "Bank" or "Bags"].Container()
	for _, list in pairs(c.buttons) do
		for _, b in pairs(list) do if b:IsShown() then n = n + 1 end end
	end
	return n
end

SlashCmdList["ABAG"]("")
flush()
ok(ABagFrame and ABagFrame:IsShown(), "window shown")
ok(shownButtons("bags") == 30, "plain grid shows every slot " .. shownButtons("bags"))
ok(templated == 30, "item buttons use the template " .. templated)
local c = ns.Bags.Container()
ok(c.buttons[0][5].item and c.buttons[0][5].item.id == 100, "button holds its item")
ok(c.buttons[0][5].__id == 5 and c.bagFrames[1].__id == 1, "slot and bag ids set")
ok(c.free:GetText():find("16 / 24 free") and c.free:GetText():find("Soul 6"), "free text " .. c.free:GetText())

local scan = ns.Scan("bags")
local byId = {}
for _, e in ipairs(scan) do if e.id then byId[e.id] = e end end
ok(byId[500].junk and byId[500].category == "Junk", "junk detected")
ok(not byId[600].junk and byId[600].category == "Other", "no value item is not junk")
ok(byId[100].category == "Equipment" and byId[200].category == "Consumables", "categories")
ok(byId[300].category == "Trade goods" and byId[400].category == "Quest", "more categories")
ok(ns.Matches(byId[100], "epic") and not ns.Matches(byId[101], "epic"), "quality search")
ok(ns.Matches(byId[100], "boe") and not ns.Matches(byId[200], "boe"), "boe search")
ok(ns.Matches(byId[500], "junk") and ns.Matches(byId[101], "plate helm"), "junk and type search")
ok(not ns.Matches({ bag = 0, slot = 4 }, "sword"), "empty slot never matches")

ns.Bags.SetSearch("junk")
c.search.box.__scripts.OnTextChanged(c.search.box)
flush()
ok(c.buttons[0][2]:GetAlpha() == 1 and c.buttons[0][5]:GetAlpha() == 0.2, "search dims other items")
ns.Bags.SetSearch("")
c.search.box.__scripts.OnTextChanged(c.search.box)
flush()
ok(c.buttons[0][5]:GetAlpha() == 1, "search cleared")

c.viewButton.__scripts.OnClick(c.viewButton, "LeftButton")
flush()
ok(ns.db.categories, "category view on")
local heads = 0
for _, h in ipairs(c.headers) do if h:IsShown() then heads = heads + 1 end end
ok(heads == 7, "category headers " .. heads)
ok(shownButtons("bags") == 9 + 2, "category view collapses empty slots " .. shownButtons("bags"))
ok(c.buttons[0][4].countText:GetText() == "15", "free count on the empty slot " .. tostring(c.buttons[0][4].countText:GetText()))
c.viewButton.__scripts.OnClick(c.viewButton, "LeftButton")
flush()
ok(shownButtons("bags") == 30, "back to plain grid")

ns.db.bagbar = true
ns.db.keyring = true
ns:Fire("LAYOUT")
ok(shownButtons("bags") == 34 and c.bagButtons[1]:IsShown(), "keyring and bag bar")
for _, b in ipairs(c.bagButtons) do
	b.__scripts.OnEnter(b)
	b.__scripts.OnClick(b, "LeftButton")
	b.__scripts.OnLeave(b)
end
ns.db.bagbar = false
ns.db.keyring = false
ns:Fire("LAYOUT")
ok(shownButtons("bags") == 30, "keyring hidden again")

c.sortButton.__scripts.OnClick(c.sortButton, "LeftButton")
ok(sortCalls == 1, "client sort used")
C_Container.SortBags = nil
c.sortButton.__scripts.OnClick(c.sortButton, "LeftButton")
flush()
local order = {}
for _, e in ipairs(ns.Scan("bags")) do
	if e.family == 0 then order[#order + 1] = e.id or 0 end
end
ok(order[1] == 100 and order[2] == 101 and order[3] == 200, "own sorter orders items " .. table.concat(order, ","))
ok(order[#order] == 0 and order[10] == 0, "empty slots at the end")
local sorted = true
local items = {}
for _, e in ipairs(ns.Scan("bags")) do if e.id and e.family == 0 then items[#items + 1] = e end end
for i = 2, #items do if ns.Before(items[i], items[i - 1]) then sorted = false end end
ok(sorted and #items == 9, "sorted and nothing lost")

bags[0].items[16] = { 500, 2 }
event("BAG_UPDATE_DELAYED")
flush()
ok(c.buttons[0][16].glow:IsShown() == false, "known item does not glow")
ITEMS[700] = { "New Ring", 3, 40, "Armor", "Miscellaneous", "INVTYPE_FINGER", 900, 4, 1 }
bags[0].items[15] = { 700, 1 }
event("BAG_UPDATE_DELAYED")
flush()
ok(c.buttons[0][15].glow:IsShown(), "new item glows")
c.buttons[0][15].__scripts.OnEnter = nil

ALootDB = { lists = { { name = "x", items = { [700] = true } } } }
ns.RefreshAll()
ok(c.buttons[0][15].star:IsShown() and not c.buttons[0][1].star:IsShown(), "wishlist star")
ok(c.buttons[0][15].ilvl:IsShown(), "item level shown")

AAuction = { GetPrice = function(id) return id * 10, id * 9 end }
c.money.__scripts.OnEnter(c.money)
c.money.__scripts.OnLeave(c.money)
ok(c.money.text:GetText():find("12g"), "money shown")

ns.Bags.Hide()
ok(not ABagFrame:IsShown(), "hidden")
ToggleAllBags()
ok(ABagFrame:IsShown(), "ToggleAllBags opens")
ok(CloseAllBags() == true and not ABagFrame:IsShown(), "CloseAllBags closes")
OpenAllBags()
ok(ABagFrame:IsShown(), "OpenAllBags opens")
ToggleBackpack()
ok(not ABagFrame:IsShown(), "ToggleBackpack closes")

merchant = true
event("MERCHANT_SHOW")
flush()
ok(ABagFrame:IsShown() and c.sellButton:IsShown(), "opens at vendor with sell button")
ok(repaired == 0, "no repair unless enabled")
local before = used
c.sellButton.__scripts.OnClick(c.sellButton, "LeftButton")
flush()
ok(used - before == 3, "junk sold " .. (used - before))
local line
for _, p in ipairs(printed) do if p:find("Sold 3 junk") then line = p end end
ok(line and line:find("1s") and line:find("62c"), "sale summary " .. tostring(line))
ok(#ns.JunkList() == 0, "no junk left")
merchant = false
event("MERCHANT_CLOSED")
flush()
ok(not ABagFrame:IsShown(), "closes after vendor")

ns.db.autoSell = true
ns.db.autoRepair = true
bags[0].items[14] = { 501, 4 }
merchant = true
event("MERCHANT_SHOW")
flush()
ok(repaired == 1 and money == 122956, "auto repair")
ok(#ns.JunkList() == 0, "auto sell")
ns.Bags.Hide()
merchant = false
event("MERCHANT_CLOSED")
ns.db.autoSell = false
ns.db.autoRepair = false
SlashCmdList["ABAG"]("junk")

event("BANKFRAME_OPENED")
flush()
ok(ABagBankFrame and ABagBankFrame:IsShown() and ABagFrame:IsShown(), "bank and bags open")
ok(shownButtons("bank") == 34, "bank slots " .. shownButtons("bank"))
local bank = ns.Bank.Container()
ok(bank.buyButton:IsShown(), "buy slot offered")
bank.buyButton.__scripts.OnClick(bank.buyButton, "LeftButton")
bank.sortButton.__scripts.OnClick(bank.sortButton, "LeftButton")
ok(sortCalls == 2, "bank sort")
bank.buttons[-1][1].__scripts.OnEnter = nil
ok(#ns.db.chars["Tester - Realm"].bank == 3, "bank cached")
event("BANKFRAME_CLOSED")
flush()
ok(not ABagBankFrame:IsShown() and not ABagFrame:IsShown(), "bank closed")
ok(#ns.db.chars["Tester - Realm"].bank == 3, "bank cache kept after closing")

ns.db.chars["Alt - Realm"] = { name = "Alt", class = "WARRIOR", money = 50000, bags = { "100:1", "300:20", "300:5" } }
ns.View.Show("Alt - Realm", "bags")
ok(ABagViewFrame:IsShown() and ABagViewFrame.title:GetText() == "Alt - Bags", "stored view")
ns.View.Show("Tester - Realm", "bank")
ok(ABagViewFrame.title:GetText() == "Tester - Bank", "stored bank view")
ns.View.Show("Nobody", "bags")
SlashCmdList["ABAG"]("bank")
ns.Bags.Show()
c.charsButton.__scripts.OnClick(c.charsButton, "LeftButton")
c.money.__scripts.OnEnter(c.money)

local made = templated
combat = true
bags[2] = { size = 12, items = { [1] = { 200, 1 } } }
bags[0].items[13] = { 300, 1 }
event("BAG_UPDATE_DELAYED")
flush()
ok(templated == made, "no buttons created in combat")
ok(c.buttons[0][13].item and c.buttons[0][13].item.id == 300, "existing buttons still update in combat")
ok(not c.buttons[2], "new bag waits for combat to end")
ns.Sort("bags")
combat = false
event("PLAYER_REGEN_ENABLED")
flush()
ok(templated == made + 12 and c.buttons[2][1]:IsShown(), "layout runs after combat")
ok(shownButtons("bags") == 42, "all slots shown after combat " .. shownButtons("bags"))

M.methods.IsProtected = function() return true end
ns.Bags.Hide()
ok(not ABagFrame:IsShown(), "hide out of combat")
combat = true
ns.Bags.Show()
ok(not ABagFrame:IsShown(), "protected window waits in combat")
combat = false
event("PLAYER_REGEN_ENABLED")
ok(ABagFrame:IsShown(), "shown after combat")
M.methods.IsProtected = function() return false end

local optionsButton
event("ITEM_LOCK_CHANGED")
event("BAG_UPDATE_COOLDOWN")
event("PLAYER_MONEY")
event("GET_ITEM_INFO_RECEIVED", 100, true)
event("MAIL_SHOW") event("MAIL_CLOSED")
event("AUCTION_HOUSE_SHOW") event("AUCTION_HOUSE_CLOSED")
event("TRADE_SHOW") event("TRADE_CLOSED")
flush()
ns.db.columns = 14
ns.db.size = 30
ns:Fire("LAYOUT")
SlashCmdList["ABAG"]("sort")
SlashCmdList["ABAG"]("reset")
SlashCmdList["ABAG"]("potion")
flush()
ok(ns.query == "potion", "slash search")
ABag_ToggleBinding()
ABag_ToggleBinding()
ok(#ACore.addons >= 1, "registered with the launcher")

print_real(string.format("ok: %d checks, %d item buttons", M.checks(), templated))
