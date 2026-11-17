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

local lines = {
	{ "Professions", true },
	{ "Blacksmithing", false, 150, 225 },
	{ "Herbalism", false, 80, 150 },
	{ "Secondary Skills", true },
	{ "Cooking", false, 10, 75 },
	{ "First Aid", false, 80, 150 },
	{ "Fishing", false, 1, 75 },
	{ "Weapon Skills", true },
	{ "Swords", false, 300, 300 },
}
function GetNumSkillLines() return #lines end
function GetSkillLineInfo(i)
	local l = lines[i]
	return l[1], l[2], true, l[3], 0, 0, l[4]
end
local combat = false
function InCombatLockdown() return combat end
C_Spell.GetSpellName = function(id) if id == 2656 then return "Smelting" end if id > 1000 then return nil end return "Spell " .. id end
local templates = {}
local realCreate = CreateFrame
function CreateFrame(kind, name, parent, template)
	local f = realCreate(kind, name, parent)
	if template then
		templates[template] = (templates[template] or 0) + 1
		f.template = template
	end
	return f
end
M.methods.SetAttribute = function(self, k, v)
	self.attr = self.attr or {}
	self.attr[k] = v
end
local panelsHidden = 0
function HideUIPanel() panelsHidden = panelsHidden + 1 end
local placed = {}
local function track(f)
	f.SetPoint = function(_, ...) placed[f] = { ... } end
	f.SetAlpha = function(_, a) f.alpha = a end
	f.GetAlpha = function() return f.alpha or 1 end
	f.GetNumPoints = function() return 1 end
	f.GetPoint = function() return "TOPLEFT", UIParent, "TOPLEFT", 16, -116 end
	f.IsMouseEnabled = function() return true end
end

M.load("ACore", "ACore")
track(TradeSkillFrame)
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

local Tabs, wstate = ns.Tabs, ns.Window.State()
local function tabFor(key)
	for _, b in ipairs(Tabs.Buttons()) do
		if b:IsShown() and b.entry and b.entry.key == key then return b end
	end
end
local function kindsOf(list)
	local k = {}
	for _, d in ipairs(list.data) do k[d.kind] = (k[d.kind] or 0) + 1 end
	return k
end
ok(ns.db.replace == false and ns.db.blizzard == nil, "default no longer replaces the default window")
ok(ns.Window.buttons and #ns.Window.buttons == 2, "button added to the default profession frames")
SlashCmdList["APROFESSION"]("")
ok(frame:IsShown() and wstate.view == "overview" and frame.overviewList:IsShown() and not frame.left:IsShown(), "opens on the overview")
local entries = Tabs.Entries()
ok(#entries == 6 and entries[1].key == "overview" and entries[2].key == "Blacksmithing" and entries[3].key == "Herbalism" and entries[6].key == "Fishing", "tabs from skill lines " .. #entries)
ok(entries[2].rank == 150 and entries[2].max == 225 and entries[2].window and entries[2].spell == "Blacksmithing", "profession tab data")
ok(not entries[3].window and not entries[6].window and entries[3].spell == nil, "gathering tabs greyed")
ok(tabFor("overview") and tabFor("Cooking") and #Tabs.Buttons() == 6, "tab buttons built")
for _, b in ipairs(Tabs.Buttons()) do
	b.__scripts.OnEnter(b)
	b.__scripts.OnLeave(b)
end
local ov = kindsOf(frame.overviewList)
ok(ov.prof == 5 and ov.header == 3 and ov.info == 5, "overview cards " .. tostring(ov.prof))
SlashCmdList["APROFESSION"]("")

event("TRADE_SKILL_SHOW")
flush()
ok(ns.Trade.mode == "trade" and not frame:IsShown(), "opening a profession does not bring up our window")
ok(not ns.Trade.Concealed(TradeSkillFrame) and TradeSkillFrame.alpha == nil and placed[TradeSkillFrame] == nil, "default frame left alone")
event("TRADE_SKILL_CLOSE")
event("TRADE_SKILL_SHOW")
flush()
event("TRADE_SKILL_CLOSE")
event("TRADE_SKILL_SHOW")
flush()
ok(not frame:IsShown() and not ns.Trade.Concealed(TradeSkillFrame), "reopening the default window keeps working")
ok(ns.db.chars["Tester - Realm"].Blacksmithing.recipes[1][4] ~= nil, "recipes recorded in the background")

local bb = ns.Window.buttons[1]
bb.__scripts.OnEnter(bb)
bb.__scripts.OnLeave(bb)
bb.__scripts.OnClick(bb, "LeftButton")
ok(frame:IsShown() and wstate.view == "prof" and wstate.prof == "Blacksmithing" and #wstate.recipes == 4, "button opens the companion on the live profession")
ok(frame.createButton:IsShown() and tabFor("Blacksmithing").mark:IsShown() and tabFor("Blacksmithing").dot:IsShown(), "live tab marked")
local closedBefore = closed
frame.close.__scripts.OnClick(frame.close, "LeftButton")
ok(closed == closedBefore and ns.Trade.mode == "trade" and panelsHidden == 0, "closing the companion leaves the default window and session alone")
bb.__scripts.OnClick(bb, "LeftButton")
event("TRADE_SKILL_CLOSE")
ok(frame:IsShown() and ns.Trade.mode == nil, "companion stays when the default window closes")
ok(frame.recipeList.data[1].kind == "stored" and #frame.recipeList.data == 4 and not frame.createButton:IsShown(), "falls back to the recorded list")
ok(frame.detailList.data[1].text:find("Recorded"), "recorded list is marked")
local srow
for _, r in ipairs(frame.recipeList.rows) do
	if r:IsShown() and r.data and r.data.kind == "stored" and r.data.recipe.name == "Bronze Dagger" then srow = r end
end
srow.__scripts.OnEnter(srow)
srow.__scripts.OnClick(srow, "LeftButton")
ok(wstate.pick == "Bronze Dagger" and kindsOf(frame.detailList).reagent == 2, "recorded recipe shows reagents")

local tb = tabFor("Herbalism")
tb.__scripts.OnClick(tb, "LeftButton")
ok(wstate.prof == "Herbalism" and frame.recipeList.data[1].text:find("Gathering"), "gathering tab explains itself")
tb = tabFor("Cooking")
tb.__scripts.OnClick(tb, "LeftButton")
ok(wstate.prof == "Cooking" and tabFor("Cooking").mark:IsShown() and not tabFor("Herbalism").mark:IsShown(), "tab switch")
ok(frame.recipeList.data[1].text:find("Nothing recorded"), "unrecorded profession")
ok(next((Tabs.Casts())) == nil and not templates.SecureActionButtonTemplate, "no cast buttons in companion mode")
tb = tabFor("overview")
tb.__scripts.OnClick(tb, "LeftButton")
ok(wstate.view == "overview" and frame.overviewList:IsShown(), "overview tab")

ns.db.chars["Alt - Realm"] = { Tailoring = { rank = 100, max = 150, recipes = { { "Linen Cloak", 2570 } } } }
ns.Window.Refresh()
ov = kindsOf(frame.overviewList)
ok(ov.craft and ov.craft >= 1 and ov.alt == 1, "craftable now and other characters " .. tostring(ov.craft))
local sawCooldown, sawCounts, sawAlt
for _, d in ipairs(frame.overviewList.data) do
	if d.kind == "info" and d.text:find("Cooldown: Bronze Dagger") then sawCooldown = true end
	if d.kind == "info" and d.text:find("4 recipes") and d.text:find("craftable now") and d.text:find("2 give skill") then sawCounts = true end
	if d.kind == "note" and d.text == "Tailoring" and d.right:find("100 / 150") then sawAlt = true end
end
ok(sawCooldown and sawCounts and sawAlt, "overview counts, cooldown and alt rows")
local function orow(pred)
	for _, r in ipairs(frame.overviewList.rows) do
		if r:IsShown() and r.data and pred(r.data) then return r end
	end
end
for _, r in ipairs(frame.overviewList.rows) do
	if r:IsShown() and r.data then
		r.__scripts.OnEnter(r)
		r.__scripts.OnLeave(r)
	end
end
local card = orow(function(d) return d.kind == "prof" and d.entry.key == "First Aid" end)
card.__scripts.OnClick(card, "LeftButton")
ok(wstate.view == "prof" and wstate.prof == "First Aid", "card opens its tab")
ns.Window.Select("overview")
local quick = orow(function(d) return d.kind == "craft" end)
local quickName = quick.data.recipe.name
quick.__scripts.OnClick(quick, "LeftButton")
ok(wstate.prof == "Blacksmithing" and wstate.pick == quickName, "craftable row jumps to the recipe")
ns.Window.Select("overview")
frame.search.box:SetText("bronze")
frame.search.box.__scripts.OnTextChanged(frame.search.box)
flush()
ok(kindsOf(frame.overviewList).craft == 2, "overview search across recorded recipes")
frame.search.box:SetText("linen")
frame.search.box.__scripts.OnTextChanged(frame.search.box)
flush()
ok(frame.overviewList.data[#frame.overviewList.data].right:find("Alt"), "search finds other characters")
frame.search.box:SetText("")
frame.search.box.__scripts.OnTextChanged(frame.search.box)
flush()
ok(#ns.OptionEntries() >= 6, "option entries for the control panel")
SlashCmdList["APROFESSION"]("overview")
AProfession_ToggleBinding()
ok(not frame:IsShown(), "binding toggles")
ns.db.chars["Alt - Realm"] = nil

ns.db.replace = true

event("TRADE_SKILL_SHOW")
flush()
ok(ns.Trade.mode == "trade" and frame:IsShown(), "classic open")
ok(ns.Trade.Concealed(TradeSkillFrame) and TradeSkillFrame.alpha == 0 and placed[TradeSkillFrame][4] == -6000, "default frame moved away in replace mode")
local casts = Tabs.Casts()
local n = 0
for _ in pairs(casts) do n = n + 1 end
ok(n == 3 and templates.SecureActionButtonTemplate == 3, "cast buttons for professions with a window " .. n)
local function castFor(key)
	for _, o in pairs(casts) do
		if o.entry and o.entry.key == key then return o end
	end
end
ok(castFor("Cooking").attr.type == "spell" and castFor("Cooking").attr.spell == "Cooking" and castFor("Blacksmithing").attr.type == nil, "live tab does not recast")
ok(castFor("Herbalism") == nil and castFor("Cooking"):IsShown(), "no cast button on gathering tabs")
local co = castFor("Cooking")
co.__scripts.OnEnter(co)
co.__scripts.OnLeave(co)
co.__scripts.PostClick(co, "LeftButton", true)
ok(ns.Window.State().prof == "Blacksmithing", "key down does not switch")
co.__scripts.PostClick(co, "LeftButton", false)
ok(ns.Window.State().prof == "Cooking" and frame:IsShown(), "cast tab switches the view")
event("TRADE_SKILL_CLOSE")
ok(frame:IsShown() and not ns.Trade.Concealed(TradeSkillFrame), "window stays while switching professions")
ok(placed[TradeSkillFrame][1] == "TOPLEFT" and placed[TradeSkillFrame][4] == 16 and placed[TradeSkillFrame][5] == -116 and TradeSkillFrame.alpha == 1, "default frame restored where it was")
event("TRADE_SKILL_SHOW")
flush()
ok(ns.Window.State().prof == "Blacksmithing" and ns.Window.State().view == "prof", "follows the profession that opened")

combat = true
event("PLAYER_REGEN_DISABLED")
ok(not castFor("Cooking"):IsShown(), "cast buttons hidden when combat starts")
lines[#lines + 1] = { "Tailoring", false, 5, 75 }
table.insert(lines, 3, table.remove(lines))
ns.Window.Refresh()
ok(#Tabs.Buttons() == 7 and templates.SecureActionButtonTemplate == 3 and not castFor("Cooking"):IsShown(), "no secure work in combat")
local tt = tabFor("First Aid")
tt.__scripts.OnClick(tt, "LeftButton")
ok(ns.Window.State().prof == "First Aid", "tabs still switch the view in combat")
combat = false
event("PLAYER_REGEN_ENABLED")
ok(templates.SecureActionButtonTemplate > 3 and castFor("Cooking"):IsShown() and castFor("Tailoring"):IsShown(), "cast buttons return after combat")
table.remove(lines, 3)
tt = tabFor("Blacksmithing")
tt.__scripts.OnClick(tt, "LeftButton")
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
ok(panelsHidden == 1 and not ns.Trade.Concealed(TradeSkillFrame) and TradeSkillFrame.alpha == 1 and placed[TradeSkillFrame][4] == 16, "closing restores and hides the default frame")
ok(ns.Window.State().view == "overview" and ns.Window.State().prof == nil, "nothing remembered after closing")
local anyCast = false
for _, o in pairs(casts) do
	if o:IsShown() then anyCast = true end
end
ok(not anyCast, "cast buttons hidden with the window")
event("TRADE_SKILL_CLOSE")
ok(ns.Trade.mode == nil and not frame:IsShown(), "classic close")
SlashCmdList["APROFESSION"]("")
ok(frame:IsShown() and ns.Window.State().view == "overview", "reopens on the overview")
SlashCmdList["APROFESSION"]("")

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
combat = true
ok(ns.Trade.Craft(heavy, 1) == false and #modernCrafts == 1, "no crafting in combat")
combat = false
event("TRADE_SKILL_LIST_UPDATE")
event("BAG_UPDATE_DELAYED")
flush()

GetNumSkillLines, GetSkillLineInfo = nil, nil
function GetProfessions() return 1, nil, nil, 4, 5, 6 end
function GetProfessionInfo(i)
	if i == 1 then return "Tailoring", 136249, 200, 225, 0, 0, 197 end
	if i == 4 then return "Fishing", 136245, 30, 75, 0, 0, 356 end
	if i == 5 then return "Cooking", 133971, 60, 75, 0, 0, 185 end
	return "First Aid", 135966, 80, 150, 0, 0, 129
end
ns.Window.Refresh()
local modernTabs = Tabs.Entries()
local names = {}
for _, e in ipairs(modernTabs) do names[#names + 1] = e.key end
ok(table.concat(names, ",") == "overview,Blacksmithing,Enchanting,Tailoring,Cooking,First Aid,Fishing", "tabs from GetProfessions plus recorded ones: " .. table.concat(names, ","))
ok(modernTabs[4].icon == 136249 and modernTabs[4].rank == 200 and modernTabs[7].window == false, "modern profession data")
GetProfessions, GetProfessionInfo = nil, nil
C_SkillInfo = {
	GetNumSkillLines = function() return 2 end,
	GetSkillLineInfo = function(i)
		if i == 1 then return { name = "Professions", isHeader = true } end
		return { name = "Alchimie", skillID = 171, rank = 40, maxRank = 75 }
	end,
}
local found
for _, e in ipairs(Tabs.Entries()) do
	if e.id == 171 and e.name == "Alchimie" and e.rank == 40 and e.spell then found = true end
end
ok(found, "skill lines matched by id whatever the language")
C_SkillInfo = nil
local opened
C_TradeSkillUI.OpenTradeSkill = function(id) opened = id end
ok(Tabs.Direct({ id = 185 }) and opened == 185, "direct open when the client offers it")
combat = true
ok(Tabs.Direct({ id = 185 }) == false, "no direct open in combat")
combat = false
C_TradeSkillUI.OpenTradeSkill = nil

local hiddenBefore = panelsHidden
SlashCmdList["APROFESSION"]("replace")
ok(ns.db.replace == false and not ns.Trade.Concealed(ProfessionsFrame), "switching back to companion mode releases the default frame")
frame.close.__scripts.OnClick(frame.close, "LeftButton")
ok(ns.Trade.mode == "modern" and panelsHidden == hiddenBefore, "companion close leaves the session")
event("TRADE_SKILL_CLOSE")
event("TRADE_SKILL_SHOW")
flush()
ok(not frame:IsShown(), "stays hidden in default mode")
SlashCmdList["APROFESSION"]("blizzard")
ok(ns.db.replace == true, "old command still toggles")
event("TRADE_SKILL_CLOSE")
SlashCmdList["APROFESSION"]("reset")
SlashCmdList["APROFESSION"]("linen")
flush()
ok(frame:IsShown(), "search from slash")
ALoot.ProfessionRecipes = function() return { { spell = 1, item = 3490, skill = 110 }, { spell = 2, item = 7955, skill = 30 }, { spell = 3, item = 7956, skill = 125 } } end
ns.Window.Select("overview")
local sawMissing
for _, d in ipairs(frame.overviewList.data) do
	if d.kind == "info" and d.entry.key == "Blacksmithing" and d.text:find("2 missing") then sawMissing = true end
end
ok(sawMissing, "overview counts missing recipes from ALoot")
local sawProfit
for _, d in ipairs(frame.overviewList.data) do
	if d.kind == "header" and d.text:find("most profit") then sawProfit = true end
end
ok(sawProfit, "craftable list sorted by profit with AAuction")
ACoreMinimapButton.__scripts.OnClick(ACoreMinimapButton, "LeftButton")
SlashCmdList["ACORE"]("profession")
ACore.OpenPanel("AProfession")
ok(ACorePanel and ACorePanel:IsShown() and #ACorePanel.list.data >= 8, "options in the control panel")

ns.db.replace = false
C_TradeSkillUI.GetChildProfessionInfo = function() return { professionName = "", skillLevel = 0, maxSkillLevel = 0 } end
event("TRADE_SKILL_SHOW")
flush()
local n1, r1, m1, i1 = ns.Trade.Info()
ok(n1 == "First Aid" and r1 == 80 and m1 == 150 and i1 == 129, "empty child info falls back to the base profession")
C_TradeSkillUI.GetChildProfessionInfo = function() return { professionName = "Classic First Aid", parentProfessionName = "First Aid", parentProfessionID = 129, skillLevel = 90, maxSkillLevel = 150 } end
n1, r1 = ns.Trade.Info()
ok(n1 == "First Aid" and r1 == 90, "child rank with the base name")
C_TradeSkillUI.GetChildProfessionInfo = nil
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionID = 185, professionName = "", skillLevel = 0, maxSkillLevel = 0 } end
C_TradeSkillUI.GetProfessionInfoBySkillLineID = function(id)
	if id == 185 then return { professionName = "Cuisine", skillLevel = 60, maxSkillLevel = 75 } end
	return { professionName = "", skillLevel = 0, maxSkillLevel = 0 }
end
n1, r1, m1 = ns.Trade.Info()
ok(n1 == "Cuisine" and r1 == 60 and m1 == 75, "name and rank from the skill line when the window gives none")
C_TradeSkillUI.GetProfessionInfoBySkillLineID = nil
n1 = ns.Trade.Info()
ok(n1 == "Cooking", "known skill line id still names the profession")
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionName = "" } end
ok(ns.Trade.Info() == nil, "no name, no profession")
event("TRADE_SKILL_LIST_UPDATE")
flush()
ns.Store.Save("", 1, 2, { { name = "x", reagents = {} } })
ok(ns.db.chars[ns.charKey][""] == nil, "nothing stored under an empty name")
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionID = 129, professionName = "First Aid", skillLevel = 80, maxSkillLevel = 150 } end
event("TRADE_SKILL_CLOSE")

GetTradeSkillTools = function() return "Anvil", true, "Hammer", false end
event("TRADE_SKILL_SHOW")
flush()
ok(ns.Trade.mode == "modern", "still modern")
C_TradeSkillUI.GetAllRecipeIDs = nil
event("TRADE_SKILL_CLOSE")
event("TRADE_SKILL_SHOW")
flush()
local okTools
for _, r in ipairs(ns.Window.State().recipes) do
	if r.tools == "Anvil, Hammer" then okTools = true end
end
ok(ns.Trade.mode == "trade" and okTools, "all classic tools listed")
event("TRADE_SKILL_CLOSE")

C_SkillInfo = {
	GetNumSkillLines = function() return 1 end,
	GetSkillLineInfo = function() return { name = "Schneiderei", skillID = 197, rank = 12 } end,
}
C_TradeSkillUI.GetProfessionInfoBySkillLineID = function(id)
	if id == 197 then return { professionName = "Schneiderei", skillLevel = 12, maxSkillLevel = 75 } end
	if id == 202 then return { professionName = "Engineering", skillLevel = 5, maxSkillLevel = 75 } end
	return { professionName = "", skillLevel = 0, maxSkillLevel = 0 }
end
local tailor, engineer
for _, e in ipairs(Tabs.Entries()) do
	if e.id == 197 and e.rank == 12 and e.max == 75 then tailor = true end
	if e.id == 202 and e.rank == 5 then engineer = true end
end
ok(tailor and engineer, "skill maximum and extra professions from the trade skill line")
C_SkillInfo = nil
C_TradeSkillUI.GetProfessionInfoBySkillLineID = nil

ns.db.chars["Alt - Realm"] = { Alchemy = { rank = 300, max = 300, recipes = {}, cooldowns = { Transmute = clock + 7200 } } }
local sawCooldown
for _, d in ipairs(ns.Overview.Rows("")) do
	if d.kind == "note" and d.text == "Cooldown: Transmute" and d.right == "2h 0m" then sawCooldown = true end
end
ok(sawCooldown, "cooldowns of other characters in the overview")
ns.db.chars["Alt - Realm"] = nil

local openedNow
C_TradeSkillUI.OpenTradeSkill = function(id) openedNow = id end
ns.Window.Select("Blacksmithing")
local openRow
for _, d in ipairs(frame.detailList.data) do
	if d.kind == "open" then openRow = d end
end
ok(openRow and openRow.entry.id == 164, "recorded view offers to open the profession")
local drow = frame.detailList.rows[1]
drow.data = openRow
drow.__scripts.OnClick(drow, "LeftButton")
ok(openedNow == 164, "open row opens it")
C_TradeSkillUI.OpenTradeSkill = nil

print_real(string.format("ok: %d checks", M.checks()))
