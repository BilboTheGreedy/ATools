local Q = {}

local b64 = {}
do
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #chars do b64[chars:byte(i)] = i - 1 end
end

function Q.base64(s)
	local out, n = {}, 0
	local acc, bits = 0, 0
	for i = 1, #s do
		local v = b64[s:byte(i)]
		if v then
			acc = acc * 64 + v
			bits = bits + 6
			if bits >= 8 then
				bits = bits - 8
				local p = 2 ^ bits
				local byte = math.floor(acc / p)
				acc = acc - byte * p
				n = n + 1
				out[n] = string.char(byte)
			end
		end
	end
	return table.concat(out)
end

function Q.cbor(s)
	local pos = 1
	local read
	local function uint(info)
		if info < 24 then return info end
		local len = info == 24 and 1 or info == 25 and 2 or info == 26 and 4 or 8
		local v = 0
		for i = 0, len - 1 do v = v * 256 + s:byte(pos + i) end
		pos = pos + len
		return v
	end
	local function float(len)
		local b = { s:byte(pos, pos + len - 1) }
		pos = pos + len
		if len == 2 then
			local sign = b[1] >= 128 and -1 or 1
			local exp = math.floor(b[1] / 4) % 32
			local frac = (b[1] % 4) * 256 + b[2]
			if exp == 0 then return sign * frac * 2 ^ -24 end
			if exp == 31 then return frac == 0 and sign * math.huge or 0 / 0 end
			return sign * (1 + frac / 1024) * 2 ^ (exp - 15)
		elseif len == 4 then
			local sign = b[1] >= 128 and -1 or 1
			local exp = (b[1] % 128) * 2 + math.floor(b[2] / 128)
			local frac = ((b[2] % 128) * 256 + b[3]) * 256 + b[4]
			if exp == 0 then return sign * frac * 2 ^ -149 end
			return sign * (1 + frac / 2 ^ 23) * 2 ^ (exp - 127)
		else
			local sign = b[1] >= 128 and -1 or 1
			local exp = (b[1] % 128) * 16 + math.floor(b[2] / 16)
			local frac = b[2] % 16
			for i = 3, 8 do frac = frac * 256 + b[i] end
			if exp == 0 then return sign * frac * 2 ^ -1074 end
			return sign * (1 + frac / 2 ^ 52) * 2 ^ (exp - 1023)
		end
	end
	function read()
		local byte = s:byte(pos)
		pos = pos + 1
		local major, info = math.floor(byte / 32), byte % 32
		if major == 0 then return uint(info) end
		if major == 1 then return -1 - uint(info) end
		if major == 2 or major == 3 then
			local len = uint(info)
			local v = s:sub(pos, pos + len - 1)
			pos = pos + len
			return v
		end
		if major == 4 then
			local len = uint(info)
			local t = {}
			for i = 1, len do t[i] = read() end
			return t
		end
		if major == 5 then
			local len = uint(info)
			local t = {}
			for _ = 1, len do
				local k = read()
				t[k] = read()
			end
			return t
		end
		if major == 6 then
			uint(info)
			return read()
		end
		if info == 20 then return false end
		if info == 21 then return true end
		if info == 22 or info == 23 then return nil end
		if info == 25 then return float(2) end
		if info == 26 then return float(4) end
		if info == 27 then return float(8) end
		return nil
	end
	return read()
end

function Q.inflate(bytes)
	local tmp = os.tmpname()
	local f = io.open(tmp, "wb")
	f:write(bytes)
	f:close()
	local p = io.popen("python3 -c \"import sys,zlib\nd=open(sys.argv[1],'rb').read()\nfor w in (15,-15,31):\n    try:\n        sys.stdout.buffer.write(zlib.decompress(d,w)); break\n    except Exception: pass\" " .. tmp, "r")
	local out = p:read("*a")
	p:close()
	os.remove(tmp)
	return out
end

function Q.load(dir, tocName)
	local meta, files = {}, {}
	for line in io.lines(dir .. "/" .. tocName) do
		line = line:gsub("\r", "")
		local k, v = line:match("^## ([^:]+): (.*)$")
		if k then
			meta[k] = v
		elseif line ~= "" and line:sub(1, 1) ~= "#" then
			files[#files + 1] = line:gsub("\\", "/")
		end
	end
	Q.meta = meta
	local function get(_, key) return meta[key] end
	C_AddOns = { GetAddOnMetadata = get, IsAddOnLoaded = function() return true end }
	GetAddOnMetadata = get
	C_EncodingUtil = {
		DecodeBase64 = Q.base64,
		DeserializeCBOR = Q.cbor,
		DecompressString = Q.inflate,
	}
	GetLocale = function() return "enUS" end
	GetBuildInfo = function() return "1.60.1", "70291", "", 16001 end
	WOW_PROJECT_ID = 2
	WOW_PROJECT_CLASSIC = 2
	wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
	table.wipe = wipe
	strsplit = function(sep, str)
		local out = {}
		for part in (str .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
		return unpack(out)
	end
	tinsert, tremove, tContains = table.insert, table.remove, function(t, v)
		for _, x in pairs(t) do if x == v then return true end end
		return false
	end
	format, strlen, strsub, strfind, strmatch, gsub, strlower, strupper, strbyte, strchar =
		string.format, string.len, string.sub, string.find, string.match, string.gsub, string.lower, string.upper, string.byte, string.char
	floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs
	debugprofilestop = function() return os.clock() * 1000 end
	GetTime = os.clock
	UnitFactionGroup = function() return Q.faction or "Alliance" end
	UnitClassBase = function() return "WARRIOR", 1 end
	UnitClass = function() return "Warrior", "WARRIOR", 1 end
	UnitRace = function() return "Human", "Human", 1 end
	UnitLevel = function() return 60 end
	CreateFrame = function()
		return setmetatable({}, { __index = function() return function() end end })
	end
	C_Timer = { After = function(_, fn) fn() end, NewTicker = function() return {} end }
	local lib = {}
	for _, f in ipairs(files) do
		local chunk = assert(loadfile(dir .. "/" .. f))
		chunk("QuestieDB", lib)
	end
	return lib
end

return Q
