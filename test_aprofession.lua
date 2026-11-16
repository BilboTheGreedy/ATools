local M = dofile("tools/mock.lua")
local ok, event, flush, printed = M.ok, M.event, M.flush, M.printed

function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
local clock = 1000
function time() return clock end
function InCombatLockdown() return false end
C_Item.GetItemCount = function(id, bank) return (id % 7) + (bank and 3 or 0) end
C_Item.GetItemInfoInstant = function(id) return id, "Armor", "Plate", id % 2 == 0 and "INVTYPE_HEAD" or "", 134400, 4, 4 end

local skills = {
	{ "Materials", "header" },
	{ "Bronze Bar", "optimal", 4, item = 2841, made = 2, reagents = { { 2840, "Copper Bar", 1 }, { 3576, "Tin Bar", 1 } } },
	{ "Daggers", "header" },
	{ "Bronze Dagger", "medium", 1, item = 3490, reagents = { { 2841, "Bronze Bar", 6 }, { 3470, "Rough Grinding Stone", 1 } }, tools = "Anvil", cooldown = 3600 },
	{ "Copper Dagger", "trivial", 0, item = 7166, reagents = { { 2840, "Copper Bar", 6 } } },
	{ "Odd Thing", "easy", 2, item = 9999, reagents = {} },
}
local crafted = {}
local function link(id, name) return "|cffffffff|Hitem:" .. id .. "::::|h[" .. name .. "]|h|r" end
function GetTradeSkillLine() return "Blacksmithing", 150, 225 end
function GetNumTradeSkills() return #skills end
function GetTradeSkillInfo(i) local s = skills[i] return s[1], s[2], s[3], true end
function GetTradeSkillIcon() return 134400 end
function GetTradeSkillItemLink(i) return skills[i].item and link(skills[i].item, skills[i][1]) end
function GetTradeSkillNumMade(i) return skills[i].made or 1 end
function GetTradeSkillNumReagents(i) return #(skills[i].reagents or {}) end
function GetTradeSkillReagentInfo(i, j) local r = skills[i].reagents[j] return r[2], 134400, r[3], 5 end
function GetTradeSkillReagentItemLink(i, j) local r = skills[i].reagents[j] return link(r[1], r[2]) end
function GetTradeSkillTools(i) return skills[i].tools end
function GetTradeSkillCooldown(i) return skills[i].cooldown end
function DoTradeSkill(i, n) crafted[#crafted + 1] = { i, n } end
local closed = 0
function CloseTradeSkill() closed = closed + 1 end
TradeSkillFrame = M.obj("Frame")
CraftFrame = M.obj("Frame")
function GetCraftDisplaySkillLine() return "Enchanting", 60, 75 end
function GetNumCrafts() return 2 end
function GetCraftInfo(i) return i == 1 and "Enchant Bracer" or "Runed Copper Rod", "", i == 1 and "optimal" or "easy", i end
function GetCraftIcon() return 134400 end
function GetCraftItemLink(i) return i == 2 and link(6218, "Runed Copper Rod") or nil end
function GetCraftNumReagents() return 1 end
function GetCraftReagentInfo() return "Strange Dust", 134400, 2, 9 end
function GetCraftReagentItemLink() return link(10940, "Strange Dust") end
function GetCraftSpellFocus() return "Runed Copper Rod" end
function DoCraft(i) crafted[#crafted + 1] = { "craft", i } end
function CloseCraft() closed = closed + 1 end

M.load("ACore", "ACore")
local ns = M.load("AProfession", "AProfession")
event("PLAYER_LOGIN")
flush()
ok(ns.db and ns.charKey == "Tester - Realm", "ready")

SlashCmdList["APROFESSION"]("")
local frame = AProfessionFrame
ok(frame and frame:IsShown(), "window opens without a profession")
ok(frame.detailList.data[1].kind == "note", "idle note")
SlashCmdList["APROFESSION"]("")
ok(not frame:IsShown(), "toggle closes")

event("TRADE_SKILL_SHOW")
flush()
ok(ns.Trade.mode == "trade" and frame:IsShown(), "classic open")
local state = ns.Window.State()
ok(#state.recipes == 4, "classic recipes " .. #state.recipes)
local dagger = state.byKey["Bronze Dagger"]
ok(dagger and dagger.item == 3490 and dagger.difficulty == 1 and #dagger.reagents == 2 and dagger.tools == "Anvil", "classic recipe fields")
ok(dagger.reagents[1].item == 2841 and dagger.reagents[1].need == 6, "classic reagents")
ok(state.byKey["Bronze Bar"].can == math.min(2840 % 7, 3576 % 7), "craftable count")
ok(state.byKey["Bronze Bar"].canBank >= state.byKey["Bronze Bar"].can, "bank count")
local headers, recipes = 0, 0
for _, r in ipairs(frame.recipeList.data) do
	if r.kind == "header" then headers = headers + 1 else recipes = recipes + 1 end
end
ok(headers == 2 and recipes == 4, "category rows")

local function clickRows(list, button)
	for _, row in ipairs(list.rows) do
		if row:IsShown() and row.data then
			row.__scripts.OnEnter(row)
			row.__scripts.OnLeave(row)
			row.__scripts.OnClick(row, button or "LeftButton")
		end
	end
end
local function find(list, pred)
	for _, row in ipairs(list.rows) do
		if row:IsShown() and row.data and pred(row.data) then return row end
	end
end

local row = find(frame.recipeList, function(d) return d.kind == "recipe" and d.recipe.name == "Bronze Dagger" end)
row.__scripts.OnClick(row, "LeftButton")
ok(state.selected == "Bronze Dagger", "select")
local kinds = {}
for _, d in ipairs(frame.detailList.data) do kinds[d.kind] = (kinds[d.kind] or 0) + 1 end
ok(kinds.title == 1 and kinds.reagent == 5, "detail rows with raw materials " .. tostring(kinds.reagent))
local raw
for _, d in ipairs(frame.detailList.data) do
	if d.kind == "reagent" and d.reagent.item == 2840 and not d.sub then raw = d end
end
ok(raw and raw.need == 3, "raw copper for one dagger " .. tostring(raw and raw.need))
frame.amount.box:SetText("4")
frame.amount.box.__scripts.OnTextChanged(frame.amount.box)
ok(state.amount == 4, "amount")
for _, d in ipairs(frame.detailList.data) do
	if d.kind == "reagent" and d.reagent.item == 2840 and not d.sub then raw = d end
end
ok(raw.need == 12, "raw copper for four " .. raw.need)
frame.createButton.__scripts.OnClick(frame.createButton, "LeftButton")
ok(crafted[#crafted][1] == 4 and crafted[#crafted][2] == 4, "create n")
frame.queueButton.__scripts.OnClick(frame.queueButton, "LeftButton")
row = find(frame.recipeList, function(d) return d.kind == "recipe" and d.recipe.name == "Copper Dagger" end)
row.__scripts.OnClick(row, "RightButton")
ok(#state.queue == 2 and frame.nextButton:IsShown(), "queue")
frame.nextButton.__scripts.OnClick(frame.nextButton, "LeftButton")
ok(#state.queue == 1 and crafted[#crafted][1] == 4, "next in queue")
row = find(frame.detailList, function(d) return d.kind == "queue" end)
row.__scripts.OnClick(row, "LeftButton")
ok(#state.queue == 0, "queue remove")
frame.queueButton.__scripts.OnClick(frame.queueButton, "LeftButton")
frame.clearButton.__scripts.OnClick(frame.clearButton, "LeftButton")
ok(#state.queue == 0, "queue clear")

row = find(frame.detailList, function(d) return d.kind == "reagent" and d.sub end)
row.__scripts.OnEnter(row)
row.__scripts.OnClick(row, "LeftButton")
ok(state.selected == "Bronze Bar", "reagent jumps to its recipe")
frame.allButton.__scripts.OnClick(frame.allButton, "LeftButton")
ok(crafted[#crafted][1] == 2 and crafted[#crafted][2] == state.byKey["Bronze Bar"].can, "create all")

row = find(frame.recipeList, function(d) return d.kind == "recipe" and d.recipe.name == "Copper Dagger" end)
row.star.__scripts.OnClick(row.star)
ok(ns.chardb.favourites["Copper Dagger"] and frame.recipeList.data[1].text == "Favourites", "favourite pinned")
row = find(frame.recipeList, function(d) return d.kind == "header" and d.text == "Daggers" end)
row.__scripts.OnClick(row, "LeftButton")
ok(ns.chardb.collapsed["Daggers"], "collapse")
row = find(frame.recipeList, function(d) return d.kind == "header" and d.text == "Daggers" end)
row.__scripts.OnClick(row, "LeftButton")

local eb = frame.search.box
eb:SetText("tin")
eb.__scripts.OnTextChanged(eb)
flush()
ok(frame.count == 1, "search by reagent " .. tostring(frame.count))
eb:SetText("")
eb.__scripts.OnTextChanged(eb)
flush()
ns.db.hideGrey = true
ns.Window.Refresh()
ok(frame.count == 3, "hide grey")
ns.db.hideGrey = false
ns.db.skillUp = true
ns.Window.Refresh()
ok(frame.count == 2, "skill up filter")
ns.db.skillUp = false
ns.db.haveMats = true
ns.Window.Refresh()
local n = 0
for _, r in ipairs(state.recipes) do if r.can > 0 then n = n + 1 end end
ok(frame.count == n, "have materials filter")
ns.db.haveMats = false
state.slot = "Head"
ns.Window.Refresh()
ok(frame.count >= 1 and frame.count < 4, "slot filter")
state.slot = nil
ns.db.sort = "name"
ns.Window.Refresh()
ok(frame.recipeList.data[1].recipe.name == "Bronze Bar", "sort by name")
ns.db.sort = "default"
frame.filterButton.__scripts.OnClick(frame.filterButton, "LeftButton")
frame.optionsButton.__scripts.OnClick(frame.optionsButton, "LeftButton")

frame.missingButton.__scripts.OnClick(frame.missingButton, "LeftButton")
ok(frame.recipeList.data[1].kind == "note", "missing without ALoot")
local opened
ALoot = {
	ProfessionRecipes = function()
		return {
			{ spell = 1, item = 3490, skill = 110, source = "Trainer" },
			{ spell = 2, item = 7955, skill = 30, source = "Vendor: Somebody" },
			{ spell = 3, item = 7956, skill = 125, source = "Drop" },
		}
	end,
	Open = function(id) opened = id end,
}
state.missing = nil
ns.Window.Refresh()
ok(#frame.recipeList.data == 2 and frame.recipeList.data[1].missing.skill == 30, "missing from ALoot, known removed")
clickRows(frame.recipeList)
ok(opened ~= nil, "missing row opens ALoot")
frame.missingButton.__scripts.OnClick(frame.missingButton, "LeftButton")

AAuction = { GetPrice = function(id) if id == 3470 then return nil end return id * 10, id * 9 end }
event("TRADE_SKILL_UPDATE")
flush()
local cost, value, profit, unpriced = ns.Store.Costs(state.byKey["Bronze Bar"])
ok(cost == (2840 + 3576) * 10 and value == 2841 * 10 * 2 and profit == value - cost and unpriced == 0, "costs")
local _, _, p2, u2 = ns.Store.Costs(state.byKey["Bronze Dagger"])
ok(p2 == nil and u2 == 1, "unpriced reagent gives no profit")
ns.db.sort = "profit"
ns.Window.Refresh()
ok(frame.recipeList.data[1].kind == "recipe" and frame.recipeList.data[1].recipe.profit ~= nil, "sort by profit")
ns.db.sort = "default"
state.selected = "Bronze Bar"
ns.Window.Refresh()
local costs = 0
for _, d in ipairs(frame.detailList.data) do
	if d.kind == "header" and d.text == "Costs per craft" then costs = costs + 1 end
end
ok(costs == 1, "cost section")
clickRows(frame.recipeList)
clickRows(frame.detailList)
M.mods.shift = true
clickRows(frame.recipeList)
clickRows(frame.detailList)
M.mods.shift = false

ok(ns.db.chars["Tester - Realm"].Blacksmithing.rank == 150, "stored profession")
ok(#ns.Store.Find("bronze") == 2 and #ns.Store.Find("3490") == 1, "who lookup")
local before = #printed
SlashCmdList["APROFESSION"]("who bronze dagger")
ok(#printed == before + 1 and printed[#printed]:find("Tester"), "who prints")
SlashCmdList["APROFESSION"]("who")
SlashCmdList["APROFESSION"]("who nothinglikethis")
local cds = ns.Store.Cooldowns()
ok(#cds == 1 and cds[1].name == "Bronze Dagger" and cds[1].left == 3600, "cooldown stored")
clock = clock + 4000
before = #printed
ns.Store.Remind(false)
ok(#printed == before + 1 and printed[#printed]:find("is ready"), "cooldown reminder")
SlashCmdList["APROFESSION"]("cd")

local before = closed
frame.close.__scripts.OnClick(frame.close, "LeftButton")
ok(closed == before + 1, "closing the window closes the profession")
event("TRADE_SKILL_CLOSE")
ok(ns.Trade.mode == nil and not frame:IsShown(), "classic close")

event("CRAFT_SHOW")
flush()
ok(ns.Trade.mode == "craft" and #state.recipes == 2, "craft mode")
ok(state.byKey["Enchant Bracer"].reagents[1].item == 10940 and state.byKey["Enchant Bracer"].tools == "Runed Copper Rod", "craft recipe")
state.selected = "Enchant Bracer"
frame.createButton.__scripts.OnClick(frame.createButton, "LeftButton")
ok(crafted[#crafted][1] == "craft" and crafted[#crafted][2] == 1, "do craft")
event("CRAFT_UPDATE")
flush()
event("CRAFT_CLOSE")
ok(ns.Trade.mode == nil, "craft close")

local recipes = {
	[101] = { recipeID = 101, name = "Linen Bandage", icon = 1, learned = true, relativeDifficulty = 3, categoryID = 5 },
	[102] = { recipeID = 102, name = "Heavy Linen Bandage", icon = 1, learned = true, relativeDifficulty = 0, categoryID = 5 },
	[103] = { recipeID = 103, name = "Wool Bandage", icon = 1, learned = false, relativeDifficulty = 0, categoryID = 6 },
}
local schem = {
	[101] = { quantityMin = 1, outputItemID = 1251, reagentSlotSchematics = { { reagentType = 1, quantityRequired = 1, reagents = { { itemID = 2589 } } } } },
	[102] = { quantityMin = 1, outputItemID = 2581, reagentSlotSchematics = {
		{ reagentType = 1, quantityRequired = 2, reagents = { { itemID = 2589 } } },
		{ reagentType = 0, quantityRequired = 1, reagents = { { itemID = 1 } } },
	} },
}
local modernCrafts = {}
ProfessionsFrame = M.obj("Frame")
C_TradeSkillUI = {
	GetAllRecipeIDs = function() return { 101, 102, 103 } end,
	GetRecipeInfo = function(id) return recipes[id] end,
	GetRecipeSchematic = function(id) return schem[id] end,
	GetCategoryInfo = function(id) return { name = "Category " .. id } end,
	GetBaseProfessionInfo = function() return { professionID = 129, professionName = "First Aid", skillLevel = 80, maxSkillLevel = 150 } end,
	GetRecipeCooldown = function(id) if id == 102 then return 120 end return nil end,
	GetRecipeRequirements = function() return { { name = "Loom", met = true } } end,
	GetRecipeItemLink = function(id) return link(schem[id].outputItemID, recipes[id].name) end,
	CraftRecipe = function(id, n) modernCrafts[#modernCrafts + 1] = { id, n } end,
	CloseTradeSkill = function() closed = closed + 1 end,
}
event("TRADE_SKILL_SHOW")
flush()
ok(ns.Trade.mode == "modern" and frame:IsShown(), "modern open")
ok(#state.recipes == 2 and #state.unknown == 1, "modern recipes")
local heavy = state.byKey[102]
ok(heavy.item == 2581 and #heavy.reagents == 1 and heavy.reagents[1].need == 2 and heavy.cooldown == 120 and heavy.tools == "Loom" and heavy.category == "Category 5", "modern recipe fields")
local pname, prank, pmax, pid = ns.Trade.Info()
ok(pname == "First Aid" and prank == 80 and pmax == 150 and pid == 129, "modern profession info")
state.selected = 102
state.amount = 3
ns.Window.Refresh()
frame.createButton.__scripts.OnClick(frame.createButton, "LeftButton")
ok(modernCrafts[1][1] == 102 and modernCrafts[1][2] == 3, "modern craft")
frame.missingButton.__scripts.OnClick(frame.missingButton, "LeftButton")
local wool
for _, d in ipairs(frame.recipeList.data) do
	if d.kind == "missing" and d.missing.name == "Wool Bandage" then wool = true end
end
ok(wool, "modern unlearned recipes listed as missing")
frame.missingButton.__scripts.OnClick(frame.missingButton, "LeftButton")
function InCombatLockdown() return true end
ok(ns.Trade.Craft(heavy, 1) == false and #modernCrafts == 1, "no crafting in combat")
function InCombatLockdown() return false end
event("TRADE_SKILL_LIST_UPDATE")
event("BAG_UPDATE_DELAYED")
flush()

SlashCmdList["APROFESSION"]("blizzard")
ok(ns.db.blizzard == true, "fallback to default window")
event("TRADE_SKILL_CLOSE")
event("TRADE_SKILL_SHOW")
flush()
ok(not frame:IsShown(), "stays hidden in default mode")
SlashCmdList["APROFESSION"]("blizzard")
event("TRADE_SKILL_CLOSE")
SlashCmdList["APROFESSION"]("reset")
SlashCmdList["APROFESSION"]("linen")
flush()
ok(frame:IsShown(), "search from slash")
ACoreMinimapButton.__scripts.OnClick(ACoreMinimapButton, "LeftButton")
SlashCmdList["ACORE"]("profession")

print_real(string.format("ok: %d checks", M.checks()))
