local M = {}
local objmt = {}
local function obj(kind)
	return setmetatable({ __kind = kind, __scripts = {}, __shown = true }, objmt)
end
local methods = {}
function methods:SetScript(name, fn) self.__scripts[name] = fn end
function methods:GetScript(name) return self.__scripts[name] end
function methods:HookScript() end
function methods:Show() self.__shown = true local f = self.__scripts.OnShow if f then f(self) end end
function methods:Hide() self.__shown = false local f = self.__scripts.OnHide if f then f(self) end end
function methods:SetShown(v) self.__shown = v and true or false end
function methods:IsShown() return self.__shown end
function methods:GetHeight() return self.__h or 560 end
function methods:GetWidth() return self.__w or 200 end
function methods:SetHeight(h) self.__h = h end
function methods:SetWidth(w) self.__w = w end
function methods:SetSize(w, h) self.__w, self.__h = w, h end
function methods:GetStringWidth() return 60 end
function methods:GetEffectiveScale() return 1 end
function methods:GetCenter() return 0, 0 end
function methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function methods:SetText(t) self.__text = t end
function methods:GetText() return self.__text or "" end
function methods:CreateTexture() return obj("Texture") end
function methods:CreateFontString() return obj("FontString") end
function methods:GetParent() return self.__parent end
function methods:GetItem() return nil end
objmt.__index = function(_, k)
	if methods[k] then return methods[k] end
	if type(k) ~= "string" or k:sub(1, 2) == "__" or k:match("^%l") then return nil end
	return function() end
end

M.frames = {}
M.obj = obj
M.methods = methods
function CreateFrame(kind, name, parent)
	local f = obj(kind)
	M.frames[#M.frames + 1] = f
	f.__parent = parent
	if name then _G[name] = f end
	return f
end

UIParent = obj("Frame")
Minimap = obj("Frame")
GameTooltip = obj("GameTooltip")
ItemRefTooltip = obj("GameTooltip")
UISpecialFrames = {}
SlashCmdList = {}
StaticPopupDialogs = {}
function StaticPopup_Show() end
function GetCursorPosition() return 0, 0 end
M.mods = { shift = false, ctrl = false, alt = false }
function IsShiftKeyDown() return M.mods.shift end
function IsControlKeyDown() return M.mods.ctrl end
function IsAltKeyDown() return M.mods.alt end
function UnitFactionGroup() return "Alliance" end
function UnitClass() return "Warrior", "WARRIOR" end
function IsInInstance() return true end
function GetInstanceInfo() return "Deadmines", "party", 1, "Normal", 5, 0, false, 36 end
function ChatEdit_InsertLink() return true end
function DressUpItemLink() end
function SetPortraitTextureFromCreatureDisplayID() end
function PlaySound() end
SOUNDKIT = {}
FACTION_STANDING_LABEL8 = "Exalted"
FACTION_STANDING_LABEL7 = "Revered"
INVTYPE_HEAD = "Head"
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
local printed = {}
M.printed = printed
print_real = print
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
function M.flush()
	local guard = 0
	while #timers > 0 and guard < 5000 do
		guard = guard + 1
		local fn = table.remove(timers, 1)
		fn()
	end
end

M.requests = 0
C_Item = {
	GetItemInfo = function(id)
		if id % 3 == 0 then M.requests = M.requests + 1 return nil end
		local classID = id % 2 == 0 and 4 or 2
		return "Item " .. id, "|cffffffff|Hitem:" .. id .. "|h[Item " .. id .. "]|h|r", id % 5, 60, 55, "Armor", "Plate", 1,
			"INVTYPE_HEAD", 134400, 1, classID, id % 5
	end,
	GetItemInfoInstant = function(id) return id, "Armor", "Plate", "INVTYPE_HEAD", 134400, id % 2 == 0 and 4 or 2, id % 5 end,
	GetItemIconByID = function() return 134400 end,
	GetItemCount = function(id) return id % 7 end,
	IsEquippedItem = function(id) return id % 11 == 0 end,
	RequestLoadItemDataByID = function() end,
	GetItemSetInfo = function(id) return "Set name " .. id end,
}
C_Spell = { GetSpellName = function(id) return "Spell " .. id end, GetSpellTexture = function() return 1 end }
C_Map = { GetAreaInfo = function(id) if id % 4 == 0 then return nil end return "Area " .. id end }
C_Reputation = { GetFactionDataByID = function(id) return { name = "Faction " .. id, reaction = 6 } end }
Enum = { TooltipDataType = { Item = 0 } }
local tooltipCalls = {}
M.tooltipCalls = tooltipCalls
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipCalls[#tooltipCalls + 1] = fn end }

function M.load(dir, name)
	local ns = {}
	for line in io.lines(dir .. "/" .. name .. ".toc") do
		line = line:gsub("\r", "")
		if line ~= "" and not line:find("^#") then
			local chunk = assert(loadfile(dir .. "/" .. line:gsub("\\", "/")))
			chunk(name, ns)
		end
	end
	M.event("ADDON_LOADED", name)
	return ns
end

function M.event(name, ...)
	local i = 1
	while M.frames[i] do
		local f = M.frames[i]
		local fn = f.__scripts.OnEvent
		if fn then fn(f, name, ...) end
		i = i + 1
	end
end

local checks = 0
function M.ok(cond, msg)
	checks = checks + 1
	if not cond then error("FAILED: " .. tostring(msg), 2) end
end
function M.checks() return checks end

return M
