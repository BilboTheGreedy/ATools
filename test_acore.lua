local M = dofile("tools/mock.lua")
local ok, event = M.ok, M.event

local reloads = 0
function ReloadUI() reloads = reloads + 1 end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
local combat = false
function InCombatLockdown() return combat end
local prompts, confirms = {}, {}
M.methods.GetCenter = function(self) return self.__cx or 400, self.__cy or 300 end

M.load("ACore", "ACore")
local A = ACore
A.UI.Prompt = function(_, _, fn) prompts[#prompts + 1] = fn end
A.UI.Confirm = function(_, fn) confirms[#confirms + 1] = fn end

TestDB = { old = 5, bar = { scale = 1.5 } }
local ns = A.New("Test", {}, { db = "TestDB", profile = true, defaults = { old = 1, fresh = 2, bar = { scale = 1 } } })
local plain = A.New("Plain", {}, { db = "PlainDB", defaults = { a = 1 } })
DataDB = { look = 2, chars = { Bob = 1 } }
local data = A.New("Data", {}, { db = "DataDB", profile = true, shared = { "chars", "last" }, defaults = { look = 1, chars = {}, last = "none" } })
event("ADDON_LOADED", "Test")
event("ADDON_LOADED", "Plain")
event("ADDON_LOADED", "Data")
ok(DataDB.chars.Bob == 1 and data.db.chars == DataDB.chars and rawget(data.db, "chars") == nil, "shared data stays at the top level")
data.db.last = "x"
data.db.chars.Ann = 2
ok(DataDB.last == "x" and DataDB.chars.Ann == 2 and data.db.look == 2 and DataDB.look == nil, "shared writes go to the top level")
event("PLAYER_LOGIN")
ok(TestDB.profiles and TestDB.profiles.Default == ns.db, "profile table")
ok(ns.db.old == 5 and ns.db.fresh == 2 and ns.db.bar.scale == 1.5, "old settings migrated into Default")
ok(PlainDB.a == 1 and plain.db == PlainDB, "plain addon untouched")
ok(A.Profile() == "Default" and #A.Profiles() == 1, "default profile")

ok(A.NewProfile("Raid", "Default") and reloads == 1, "new profile reloads")
ok(A.Profile() == "Raid" and not A.NewProfile("Raid") and not A.NewProfile("  "), "profile selected, duplicates refused")
local t = A.ProfileTable("TestDB")
ok(t ~= TestDB.profiles.Default and t.old == 5 and t.bar.scale == 1.5 and t.bar ~= TestDB.profiles.Default.bar, "copied from Default")
t.old = 9
A.ResetProfile("Raid")
t = A.ProfileTable("TestDB")
ok(t.old == nil and reloads == 2, "reset wipes the profile")
ok(A.SetProfile("Default") and A.Profile() == "Default" and not A.SetProfile("Nope"), "switch")
A.SetProfile("Raid")
ok(A.DeleteProfile("Raid") and A.Profile() == "Default" and not A.DeleteProfile("Default"), "delete")
A.ProfileTable("TestDB")
ok(TestDB.profiles.Raid == nil and #A.Profiles() == 1, "deleted profile removed from addon data")

M.methods.GetName = function(self) return self.__name end
local f = CreateFrame("Frame", "ATestBar", UIParent)
f.__name = "ATestBar"
f.__w, f.__h = 200, 20
local moved = 0
A.UI.Movable(f, ns.db.bar, function() moved = moved + 1 end)
local w = A.UI.Window("ATestWindow", "T", 300, 200, {})
ok(#A.movers >= 1 and A.movers[#A.movers].frame == f and A.movers[#A.movers].label == "ATest Bar", "mover registered, windows are not: " .. A.movers[#A.movers].label)
local m = A.movers[#A.movers]

combat = true
ok(A.LayoutMode(true) == false and not A.LayoutActive(), "no layout mode in combat")
combat = false
ok(A.LayoutMode(true) and A.LayoutActive() and m.handle and m.handle:IsShown(), "layout mode shows handles")
local h = m.handle
h.__cx, h.__cy = 613, 207
h.__scripts.OnDragStart(h)
h.__scripts.OnDragStop(h)
ok(ns.db.bar.pos[1] == "CENTER" and ns.db.bar.pos[2] == "BOTTOMLEFT", "drag saves position")
ok(math.abs(ns.db.bar.pos[3] * ns.db.bar.scale - 616) < 0.01 and math.abs(ns.db.bar.pos[4] * ns.db.bar.scale - 208) < 0.01 and moved == 1, "snapped to grid")
h.__scripts.OnMouseWheel(h, 1)
ok(math.abs(ns.db.bar.scale - 1.55) < 0.001, "wheel resizes " .. ns.db.bar.scale)
h.__scripts.OnMouseWheel(h, -1)
h.__scripts.OnClick(h, "RightButton")
A.ScaleMover(m, 9)
ok(ns.db.bar.scale == 3, "scale clamped")
A.ResetMover(m)
ok(ns.db.bar.pos == nil and ns.db.bar.scale == 1, "reset mover")
for _, name in ipairs({ "grid", "snap" }) do
	local b = ACoreLayoutBar[name]
	b.__scripts.OnClick(b)
	b.__scripts.OnClick(b)
end
event("PLAYER_REGEN_DISABLED")
ok(not A.LayoutActive() and not h:IsShown(), "combat locks frames")

local toggled = 0
A.Register({ name = "Test", title = "Test", slash = "/test", desc = "testing", toggle = function() toggled = toggled + 1 end, options = function()
	return { { text = "Things", title = true }, A.UI.Check(ns.db, "fresh", "A setting") }
end })
A.Register({ name = "Plain", slash = "/plain" })
SlashCmdList["ACORE"]("")
local panel = ACorePanel
ok(panel and panel:IsShown() and #panel.list.data > 8, "panel opens")
local function click(text)
	for _, d in ipairs(panel.list.data) do
		if d.text and d.text:find(text, 1, true) and d.func then
			panel.list.rows[1].data = d
			panel.list.rows[1].__scripts.OnClick(panel.list.rows[1])
			return true
		end
	end
	return false
end
ok(click("New profile copied"), "new profile row")
prompts[#prompts]("Healer")
ok(A.Profile() == "Healer", "panel creates profile")
SlashCmdList["ACORE"]("")
SlashCmdList["ACORE"]("")
ok(click("Reset Healer") and click("Delete Healer") and click("New empty profile"), "profile rows")
confirms[#confirms]()
ok(A.Profile() == "Default", "panel deletes profile")
ok(click("Minimap button") and click("Minimap button"), "minimap row")
for _, d in ipairs(panel.navList.data) do
	panel.navList.rows[1].data = d
	panel.navList.rows[1].__scripts.OnClick(panel.navList.rows[1])
	for i, r in ipairs(panel.list.data) do
		local row = panel.list.rows[i]
		if row then
			row.data = r
			if not (r.text and (r.text:find("Open ") or r.text:find("Unlock"))) then row.__scripts.OnClick(row) end
		end
	end
end
ok(ns.db.fresh == false or ns.db.fresh == true, "addon option toggled from the panel")
A.OpenPanel("Test")
ok(click("Open Test") and toggled == 1 and not panel:IsShown(), "open addon from panel")
A.OpenPanel("general")
ok(click("Unlock frames") and A.LayoutActive() and not panel:IsShown(), "unlock from panel")
SlashCmdList["ACORE"]("lock")
SlashCmdList["ACORE"]("move")
SlashCmdList["ACORE"]("lock")
ok(not A.LayoutActive(), "slash lock")
SlashCmdList["ACORE"]("test")
ok(toggled == 2, "slash opens addon by name")
ACoreMinimapButton.__scripts.OnClick(ACoreMinimapButton, "LeftButton")

A.SetButton("Test", false)
A.SetButton("Plain", false)
ok(not A.HasButton("Test") and not (TestMinimapButton and TestMinimapButton:IsShown()), "own button off")
A.SetButton("Test", true)
ok(A.HasButton("Test") and TestMinimapButton and TestMinimapButton:IsShown(), "own minimap button")
TestMinimapButton.__scripts.OnClick(TestMinimapButton, "LeftButton")
ok(toggled == 3, "own button opens the addon")
TestMinimapButton.__scripts.OnClick(TestMinimapButton, "RightButton")
TestMinimapButton.__scripts.OnEnter(TestMinimapButton)
TestMinimapButton.__scripts.OnDragStart(TestMinimapButton)
TestMinimapButton.__scripts.OnUpdate(TestMinimapButton)
TestMinimapButton.__scripts.OnDragStop(TestMinimapButton)
A.SetButton("Plain", true)
ok(ACoreDB.buttons.Plain.angle ~= ACoreDB.buttons.Test.angle, "buttons spread out")
A.OpenPanel("Test")
ok(click("Own minimap button") and not A.HasButton("Test") and not TestMinimapButton:IsShown(), "panel hides the button")
A.OpenPanel("general")
A.SetMinimap(false)
ok(not ACoreMinimapButton:IsShown(), "main button can hide while own buttons stay")
A.SetMinimap(true)

print_real(string.format("ok: %d checks (acore)", M.checks()))
