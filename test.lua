local M = dofile("tools/mock.lua")
local ok, event, flush, printed, tooltipCalls, mods = M.ok, M.event, M.flush, M.printed, M.tooltipCalls, M.mods

M.load("ACore", "ACore")
local ns = M.load("ALoot", "ALoot")
event("PLAYER_LOGIN")
assert(ns.db, "db not ready")
ok(ACoreMinimapButton, "launcher button")
ACoreMinimapButton.__scripts.OnClick(ACoreMinimapButton, "LeftButton")
ACoreMinimapButton.__scripts.OnEnter(ACoreMinimapButton)
SlashCmdList["ACORE"]("")
SlashCmdList["ACORE"]("loot")
SlashCmdList["ACORE"]("loot")


SlashCmdList["ALOOT"]("")
flush()
local frame = ALootFrame
ok(frame and frame:IsShown(), "frame shown")

local totalGroups, totalSections, totalRows = 0, 0, 0
local kinds = {}
for _, mod in ipairs(ns.MODULES) do
	for _, cat in ipairs(ns.Categories(mod.key)) do
		for _, g in ipairs(cat.groups) do
			totalGroups = totalGroups + 1
			ok(type(g.name) == "string" and g.name ~= "", "group name " .. g.id)
			ns.UI.Go(g, nil)
			for _, d in ipairs(g.diffs) do
				local rows = ns.GroupRows(g, nil, d[1], { class = "ALL", slot = "ALL" })
				for _, r in ipairs(rows) do
					kinds[r.kind] = (kinds[r.kind] or 0) + 1
					totalRows = totalRows + 1
				end
			end
			for i = 1, #g.sections do
				totalSections = totalSections + 1
				ns.UI.Go(g, i)
				for _, row in ipairs(frame.lootList.rows) do
					if row:IsShown() and row.data then
						row.__scripts.OnEnter(row)
						row.__scripts.OnLeave(row)
					end
				end
			end
		end
	end
end
ok(totalGroups > 90, "groups " .. totalGroups)
ok(kinds.item > 3000, "items")
ok(kinds.spell > 1500, "spells")
ok(kinds.set > 100, "sets")

local auto = ns.GroupByInstance(36)
ok(auto and auto.key == "TheDeadmines", "instance lookup")

local function clickAll(button)
	local n = 0
	for i = 1, #frame.lootList.rows do
		local row = frame.lootList.rows[i]
		if row and row:IsShown() and row.data then
			local kind = row.data.kind
			row.__scripts.OnClick(row, button or "LeftButton")
			n = n + 1
			local back = frame.back
			if back:IsShown() then
				for _, r2 in ipairs(frame.lootList.rows) do
					if r2:IsShown() and r2.data then r2.__scripts.OnEnter(r2) end
				end
				back.__scripts.OnClick(back, "LeftButton")
			end
			if kind == "goto" or kind == "boss" then break end
		end
	end
	return n
end

for _, id in ipairs({ "DungeonsAndRaids:MoltenCore", "Crafting:Alchemy", "Collections:TierSets", "Factions:ArgentDawn", "PvP:AlteracValley", "DungeonsAndRaids:TheDrownedCity" }) do
	local g = ns.Group(id)
	ok(g, "group " .. id)
	ns.UI.Go(g, nil)
	ok(clickAll("LeftButton") > 0, "left clicks " .. id)
	ns.UI.Go(g, 1)
	clickAll("RightButton")
	mods.shift = true clickAll("LeftButton") mods.shift = false
	mods.ctrl = true clickAll("LeftButton") mods.ctrl = false
end

local mc = ns.Group("DungeonsAndRaids:MoltenCore")
ns.UI.Go(mc, 2)
local before = ns.Wish.Count()
mods.alt = true
local toggled = 0
for _, row in ipairs(frame.lootList.rows) do
	if row:IsShown() and row.data and row.data.kind == "item" then
		row.__scripts.OnClick(row, "LeftButton")
		toggled = toggled + 1
		if toggled >= 3 then break end
	end
end
mods.alt = false
ok(ns.Wish.Count() == before + 3, "wishlist add")
ok(ns.Wish.CountIn(mc) >= 3, "wishlist count in group")
for _, row in ipairs(frame.lootList.rows) do
	if row:IsShown() and row.data and row.data.kind == "item" then
		row.star.__scripts.OnClick(row.star)
		row.star.__scripts.OnEnter(row.star)
		break
	end
end
ok(ns.Wish.Count() == before + 2, "star toggle")

frame.wishButton.__scripts.OnClick(frame.wishButton, "LeftButton")
ok(#frame.lootList.data >= 3, "wishlist view rows")
frame.wishButton.__scripts.OnClick(frame.wishButton, "RightButton")
ns.Wish.New("Second")
ok(#ns.Wish.Lists() == 2, "new list")
ns.Wish.Rename("Renamed")
ns.Wish.Delete()
ok(#ns.Wish.Lists() == 1, "delete list")
frame.wishButton.__scripts.OnClick(frame.wishButton, "LeftButton")

local wished
for id in pairs(ns.Wish.Active().items) do wished = id break end
event("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:" .. wished .. "::::|h[Thing]|h|r.")
ok(#printed > 0 and printed[#printed]:find("wishlist item looted"), "loot alert")

local eb = frame.search.box
eb:SetText("item 1")
eb.__scripts.OnTextChanged(eb)
flush()
ok(#frame.lootList.data > 5, "search results " .. #frame.lootList.data)
local res, total = ns.Search("ragnaros")
ok(#res > 0 and res[2] and res[2].kind == "goto", "boss search")
local res2 = ns.Search("perdition")
local hit
for _, r in ipairs(res2) do if r.kind == "item" and r.id == 18816 then hit = true end end
ok(hit, "bundled name search finds Perdition's Blade")
clickAll("LeftButton")
eb:SetText("")
eb.__scripts.OnTextChanged(eb)
flush()

local everything, n = ns.Search("", nil, true)
ok(n > 4000 and #everything == n, "all loot lists everything " .. n)
local plate, np = ns.Search("", { class = "ALL", slot = "ALL", armor = 4 }, true)
local bad
for _, r in ipairs(plate) do
	local k = ns.ItemKind(r.id)
	if r.kind ~= "item" or k.classID ~= 4 or k.subclassID ~= 4 then bad = true end
end
ok(np > 0 and np < n and not bad, "armor filter keeps only plate " .. np)
local sets = ns.Search("set name 2")
local gotSet
for _, r in ipairs(sets) do if r.kind == "set" then gotSet = true end end
ok(gotSet, "search finds sets")
frame.allButton.__scripts.OnClick(frame.allButton, "LeftButton")
ok(#frame.lootList.data > 4000, "all loot view " .. #frame.lootList.data)
frame.armorButton.__scripts.OnClick(frame.armorButton, "LeftButton")
eb:SetText("item 1")
eb.__scripts.OnTextChanged(eb)
flush()
eb:SetText("")
eb.__scripts.OnTextChanged(eb)
flush()
ok(#frame.lootList.data > 4000, "back to all loot after clearing search")
frame.allButton.__scripts.OnClick(frame.allButton, "LeftButton")
flush()

local src = ns.Sources(18816)
ok(src and src[1].group.key == "MoltenCore", "source of 18816")
ok(ns.SourceText(18816):find("Ragnaros"), "source text")

for _, class in ipairs(ns.CLASSES) do
	ns.db.classFilter = class
	ns.UI.Go(mc, nil)
end
ns.db.classFilter = "MINE"
ns.UI.Go(mc, nil)
ns.db.classFilter = "ALL"

for _, name in ipairs({ "classButton", "slotButton", "listButton" }) do
	local b = frame[name]
	b.__scripts.OnClick(b, "LeftButton")
end

ok(#tooltipCalls == 1, "tooltip hook registered")
tooltipCalls[1](GameTooltip, { id = 18816 })
tooltipCalls[1](GameTooltip, { id = wished })

local list = frame.lootList
list.__scripts.OnMouseWheel(list, -1)
list.__scripts.OnMouseWheel(list, 1)
list.__scripts.OnSizeChanged(list)

event("GET_ITEM_INFO_RECEIVED", 18816, true)
event("BAG_UPDATE_DELAYED")
flush()

SlashCmdList["ALOOT"]("minimap")
SlashCmdList["ALOOT"]("minimap")
SlashCmdList["ALOOT"]("reset")
SlashCmdList["ALOOT"]("thunderfury")
flush()
ALoot_OnCompartmentClick()
ALoot_ToggleBinding()

ok(#ALoot.AllItems() > 4000, "api items")
ok(ALoot.SourceText(18816):find("Ragnaros"), "api source text")
ok(#ALoot.Sources(18816) > 0 and ALoot.Sources(18816)[1].place, "api sources")
local alch = ALoot.ProfessionRecipes("Alchemy")
ok(#alch > 50 and alch[1].spell and alch[1].source, "api recipes " .. #alch)
ok(#ALoot.ProfessionRecipes(197) > 50 and #ALoot.ProfessionRecipes("First Aid") > 5, "api recipes by skill")
ALoot.WishToggle(18816)
ok(ALoot.OnWishlist(18816), "api wishlist")
ALoot.WishToggle(18816)
ALoot.Open(18816)
ALoot.Open(1)

local entries = ns.Options()
ok(#entries > 8, "options entries")
local registered
for _, a in ipairs(ACore.addons) do
	if a.name == "ALoot" then registered = a end
end
ok(registered and #registered.options() == #entries, "options registered with the control panel")
for _, e in ipairs(entries) do
	if e.func then e.func() e.func() end
end
ok(type(frame.Restore) == "function" and type(frame.StartDrag) == "function", "window is movable through ACore")

ns.db.needed = false
ns.UI.Go(mc, nil)
local allRows = ns.GroupRows(mc, nil, "n", { class = "ALL", slot = "ALL" })
local neededRows = ns.GroupRows(mc, nil, "n", { class = "ALL", slot = "ALL", needed = true })
local function items(rows)
	local n = 0
	for _, r in ipairs(rows) do if r.kind == "item" then n = n + 1 end end
	return n
end
ok(items(neededRows) > 0 and items(neededRows) < items(allRows), "needed filter " .. items(neededRows) .. " of " .. items(allRows))
for _, r in ipairs(neededRows) do
	if r.kind == "item" then
		ok(not ns.Owned(r.id), "needed row is not owned")
		local k = ns.ItemKind(r.id)
		ok(not k or ns.Usable(k, ns.playerClass), "needed row is usable")
	end
end
frame.neededButton.__scripts.OnClick(frame.neededButton, "LeftButton")
ok(ns.db.needed and items(frame.lootList.data) == items(neededRows), "needed button")
frame.neededButton.__scripts.OnClick(frame.neededButton, "LeftButton")

local compared = 0
function GameTooltip_ShowCompareItem() compared = compared + 1 end
mods.shift = true
for _, row in ipairs(frame.lootList.rows) do
	if row:IsShown() and row.data and row.data.kind == "item" then
		row.__scripts.OnEnter(row)
		GameTooltip:Show()
		event("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
		row.__scripts.OnLeave(row)
		break
	end
end
mods.shift = false
ok(compared == 2, "compare on shift " .. compared)

local n0 = #printed
event("CHAT_MSG_LOOT", "You receive loot: |cnIQ4:|Hitem:" .. wished .. "::::|h[Thing]|h|r.")
ok(#printed == n0 + 1 and printed[#printed]:find("|cnIQ4:|Hitem:", 1, true), "loot alert keeps a modern link")

print_real(string.format("ok: %d checks, %d groups, %d sections, %d rows, %d item requests", M.checks(), totalGroups, totalSections, totalRows, M.requests))
for k, v in pairs(kinds) do print_real("  " .. k, v) end
