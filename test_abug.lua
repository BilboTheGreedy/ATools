local M = dofile("tools/mock.lua")
local ok, event = M.ok, M.event

local handler
function seterrorhandler(fn) handler = fn end
function debugstack() return "Interface/AddOns/ASwing/Swing.lua:10: in function <Interface/AddOns/ASwing/Swing.lua:5>" end
function debuglocals() return "x = 1" end
function date() return "2026-11-16 21:00:00" end
function GetTime() return 100 end
function GetBuildInfo() return "1.60.1", "70291", "", 16001 end
function InCombatLockdown() return false end
function GetRealZoneText() return "Elwynn Forest" end
M.methods.GetVerticalScrollRange = function() return 100 end
M.methods.GetVerticalScroll = function() return 0 end

ABugDB = { session = 3, errors = {
	{ kind = "error", msg = "old one", stack = "", locals = "", addon = "ALoot", count = 2, time = "t", last = "t", session = 3 },
	{ kind = "error", msg = "ancient", stack = "", locals = "", addon = "ALoot", count = 1, time = "t", last = "t", session = -20 },
} }

local chunkNs = {}
for _, f in ipairs({ "Core.lua", "Window.lua" }) do
	assert(loadfile("ABug/" .. f))("ABug", chunkNs)
end
ok(handler, "error handler installed")
handler("Interface/AddOns/ACore/Core.lua:5: early failure")
event("ADDON_LOADED", "ABug")
ok(ABugDB.session == 4 and #ABugDB.errors == 2, "keeps recent, drops ancient, keeps early " .. #ABugDB.errors)
ok(ABugDB.errors[2].addon == "ACore" and ABugDB.errors[2].session == 4, "early error kept")

M.load("ACore", "ACore")
event("PLAYER_LOGIN")
ok(#M.printed > 0 and M.printed[#M.printed]:find("while loading"), "login notice")

handler("Interface\\AddOns\\ASwing\\Swing.lua:222: attempt to index a nil value")
handler("Interface\\AddOns\\ASwing\\Swing.lua:222: attempt to index a nil value")
local e = ABugDB.errors[#ABugDB.errors]
ok(e.addon == "ASwing" and e.count == 2 and e.stack ~= "" and e.locals == "x = 1", "records and dedupes")
event("ADDON_ACTION_FORBIDDEN", "ASwing", "Frame:RegisterEvent()")
e = ABugDB.errors[#ABugDB.errors]
ok(e.kind == "forbidden" and e.addon == "ASwing" and e.msg:find("RegisterEvent"), "forbidden action")
event("ADDON_ACTION_BLOCKED", "ABars", "Button:Show()")
event("LUA_WARNING", 0, "something odd")
event("MACRO_ACTION_FORBIDDEN", "CastSpellByName()")
ok(ABug.Count() == 7 and ABug.Count(true) == 6, "counts " .. ABug.Count() .. " " .. ABug.Count(true))
ABug.Log("note", "hello")
ok(chunkNs.Text(e):find("Stack:"), "text")

SlashCmdList["ABUG"]("")
ok(ABugFrame and ABugFrame:IsShown(), "window")
for _, f in ipairs(M.frames) do
	if f.__parent and f.__scripts.OnClick and f.__kind == "Button" and (f.entry or f.label) and f ~= nil then
		local isClose = f.label and f.label.__text == "x"
		local isClear = f.label and f.label.__text == "Clear"
		if not isClose and not isClear and (f.entry or (f.label and (f.label.__text == "Show older" or f.label.__text == "This session" or f.label.__text == "Select text"))) then
			f.__scripts.OnClick(f)
		end
	end
end
for _, f in ipairs(M.frames) do
	if f.__scripts.OnMouseWheel then f.__scripts.OnMouseWheel(f, -1) f.__scripts.OnMouseWheel(f, 1) end
end
ok(pcall(SlashCmdList["ABUG"], "test") == false, "test command raises")
SlashCmdList["ABUG"]("quiet")
SlashCmdList["ABUG"]("quiet")
for i = 1, 320 do handler("Interface/AddOns/ATip/x.lua:" .. i .. ": boom") end
ok(#ABugDB.errors == 300, "capped " .. #ABugDB.errors)
SlashCmdList["ABUG"]("clear")
ok(ABug.Count() == 0, "clear")
ACoreMinimapButton.__scripts.OnClick(ACoreMinimapButton, "LeftButton")

print_real(string.format("ok: %d checks (abug)", M.checks()))
