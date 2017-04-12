-- Copyright (C) Allen.L, CloudFlare Inc.

local xbit = require("libbit")

local _M = {_VERSION='0.01'}

function _M.uncode(str)
	local str = str or ''
	str = str:gsub('+', ' ')
	return (str:gsub("%%(%x%x)", function(c)
			return string.char(tonumber(c, 16))
	end))	
end

function _M.decodeUrl(str)
	local str = str or ''
	str = str:gsub('+', ' ')
	return (str:gsub("%%(%x%x)", function(c)
			return string.char(tonumber(c, 16))
	end))
end

function _M.encodeUrl(str)
	local str = str or ''
	return (str:gsub("([^A-Za-z0-9%_%.%-%~])", function(v)
			return string.upper(string.format("%%%02x", string.byte(v)))
	end))
end

function _M.urlDomain(str)
	local str = str or ''
	local s = string.find(str, '//')
	local e = nil
	if(s) then
		e = string.find(str, '/', s+2)
	end
	if(not s or not e) then
		return ''
	end
	
	return string.sub(str, s+2, e-1)
end

function _M.split(s, delim)
    if type(delim) ~= "string" or string.len(delim) <= 0 then
        return
    end

    local start = 1
    local t = {}
    while true do
    local pos = string.find (s, delim, start, true) -- plain find
        if not pos then
          break
        end

        table.insert (t, string.sub (s, start, pos - 1))
        start = pos + string.len (delim)
    end
    table.insert (t, string.sub (s, start))

    return t
end

local buf64 = {143, 15, 175, 47, 207, 79, 239, 111, 142, 14, 174, 46, 206, 78, 238, 110, 141, 13, 173, 45, 205, 77, 237, 109, 140, 12, 172, 44,
		204, 76, 236, 108, 139, 11, 171, 43, 203, 75, 235, 107, 138, 10, 170, 42, 202, 74, 234, 106, 137, 9, 169, 41, 201, 73, 233, 105, 136, 8, 168,
		40, 200, 72, 232, 104, 135, 7, 167, 39, 199, 71, 231, 103, 134, 6, 166, 38, 198, 70, 230, 102, 133, 5, 165, 37, 197, 69, 229, 101, 132, 4,
		164, 36, 196, 68, 228, 100, 131, 3, 163, 35, 195, 67, 227, 99, 130, 2, 162, 34, 194, 66, 226, 98, 129, 1, 161, 33, 193, 65, 225, 97, 128, 0,
		160, 32, 192, 64, 224, 96, 127, 63, 255, 95, 159, 223, 191, 31, 126, 62, 254, 94, 158, 222, 190, 30, 125, 61, 253, 93, 157, 221, 189, 29, 124,
		60, 252, 92, 156, 220, 188, 28, 123, 59, 251, 91, 155, 219, 187, 27, 122, 58, 250, 90, 154, 218, 186, 26, 121, 57, 249, 89, 153, 217, 185, 25,
		120, 56, 248, 88, 152, 216, 184, 24, 119, 55, 247, 87, 151, 215, 183, 23, 118, 54, 246, 86, 150, 214, 182, 22, 117, 53, 245, 85, 149, 213,
		181, 21, 116, 52, 244, 84, 148, 212, 180, 20, 115, 51, 243, 83, 147, 211, 179, 19, 114, 50, 242, 82, 146, 210, 178, 18, 113, 49, 241, 81, 145,
		209, 177, 17, 112, 48, 240, 80, 144, 208, 176, 16}

--reffer urldecode
function _M.urlDeEncrypt(seed, encodeUrl)

	if(not encodeUrl or string.len(encodeUrl) <= 0) then
		return nil
	end
	
	local url = {}
	
	local tmp = {}
	for i=1, #encodeUrl do
		table.insert(tmp, string.sub(encodeUrl, i, i))
	end

	local seed_part = { xbit._and(seed, 0xff),  xbit._and(xbit._rshift(seed, 8), 0xff), xbit._and(xbit._rshift(seed, 16), 0xff), xbit._and(xbit._rshift(seed, 24), 0xff) }
	local i, j = 1, 1
	local code, ch = 0, 0
	
	while(tmp[i * 2 - 1] and tmp[i * 2]) do
		if(string.byte(tmp[i * 2 - 1]) >= 65 and  string.byte(tmp[i * 2 - 1]) <= 70) then
			code = string.byte(tmp[i * 2 - 1]) - 55
		elseif(string.byte(tmp[i * 2 - 1]) >= 48 and  string.byte(tmp[i * 2 -1]) <= 57) then
			code = string.byte(tmp[i * 2 - 1]) - 48
		end
		
		code = xbit._lshift(code, 4);
		
		if(string.byte(tmp[i * 2]) >= 65 and  string.byte(tmp[i * 2]) <= 70) then
			code = xbit._or(code, string.byte(tmp[i * 2]) - 55);
		elseif(string.byte(tmp[i * 2]) >= 48 and  string.byte(tmp[i * 2]) <= 57) then
			code = xbit._or(code, string.byte(tmp[i * 2]) - 48)
		end
		
		ch = buf64[code + 1];
		ch = xbit._xor(ch, seed_part[j])
		
		url[i] = string.char(ch)
		
		j = j % 4 + 1
		i = i + 1
	end
	
	seed_part = nil
	tmp = nil
	
	return table.concat(url)
end

--获取浏览器信息（11）
function _M.getBrowser(agent)
	--淘宝
	if(string.find(agent,'taobrowser')) then
		return 1101
	end
	
	--猎豹
	if(string.find(agent,'lbbrowser')) then
		return 1102
	end	
	
	--QQ
	if(string.find(agent,'qqbrowser')) then
		return 1103
	end	
	
	--360
	if(string.find(agent,'360se')) then
		return 1104
	end

	--搜狗
	if(string.find(agent,'metasr')) then
		return 1105
	end	
	
	--firefox
	if(string.find(agent,'firefox')) then
		return 1106
	end
	
	--chrome
	if(string.find(agent,'chrome')) then
		return 1107
	end
	
	--safari
	if(string.find(agent,'safari') and not string.find(agent,'chrome')) then
		return 1108
	end		
	
	--腾讯
	if(string.find(agent,'tencenttraveler') or string.find(agent,'qqbrowser')) then
		return 1109
	end	
	
	--the world
	if(string.find(agent,'the world')) then
		return 1110
	end
	
	--Maxthon
	if(string.find(agent,'maxthon')) then
		return 1111
	end	
	
	--Opera
	if(string.find(agent,'opera')) then
		return 1112
	end
	
	--UC
	if(string.find(agent,'ucweb')) then
		return 1113
	end
	
	--百度
	if(string.find(agent,'bidubrowser') or string.find(agent,'flyflow')) then
		return 1114
	end
	
	--IE
	if(string.find(agent,'msie')) then
		return 1115
	end

	--微信
	if(string.find(agent,'micromessenger')) then
		return 1116
	end
	
	return 0										
end

--获取OS(10)
function _M.getOS(agent)
	--Android
	if(string.find(agent,'android')) then
		return 1007
	end
	
	--Windows
	if(string.find(agent,'windows')) then
		return 1001
	end
	
	--Unix
	if(string.find(agent,'unix')) then
		return 1002
	end
	
	--Linux
	if(string.find(agent,'linux')) then
		return 1003
	end
	
	--FreeBSD
	if(string.find(agent,'freebsd')) then
		return 1004
	end
	
	--IOS
	if(string.find(agent,'mac os')) then
		return 1005
	end
	
	--Solaris
	if(string.find(agent,'sunos')) then
		return 1006
	end	
	
	--SymbianOS
	if(string.find(agent,'symbianos')) then
		return 1008
	end
	
	return 0						
end

--获取设备(9)
function _M.getDevice(agent)
	--iPhone
	if(string.find(agent,'iphone')) then
		return 902
	end
	
	--iPad
	if(string.find(agent,'ipad')) then
		return 903
	end
	
	--iPod
	if(string.find(agent,'ipod')) then
		return 904
	end	
	
	--Android
	if(string.find(agent,'android')) then
		return 905
	end	
	
	--Windows Phone
	if(string.find(agent,'windows phone')) then
		return 906
	end
	
	--Nokia
	if(string.find(agent,'symbianos')) then
		return 907
	end
	
	--PC
	return 901				
end

--随机数
function _M.getRandomseed(r)
	local n = 1
	local m = 100000
	math.randomseed(tostring(os.time()):reverse():sub(1, 7))
	for i = 1,15 do
		r = math.random(n,m)
	end

	return tonumber(r)
end

--table 序列化
function _M.serialize(obj)  
    local lua = ""  
    local t = type(obj)  
    if t == "number" then  
        lua = lua .. obj  
    elseif t == "boolean" then  
        lua = lua .. tostring(obj)  
    elseif t == "string" then  
        lua = lua .. string.format("%q", obj)  
    elseif t == "table" then  
        lua = lua .. "{\n"  
    for k, v in pairs(obj) do  
        lua = lua .. "[" .. _M.serialize(k) .. "]=" .. _M.serialize(v) .. ",\n"  
    end  
    local metatable = getmetatable(obj)  
        if metatable ~= nil and type(metatable.__index) == "table" then  
        for k, v in pairs(metatable.__index) do  
            lua = lua .. "[" .. _M.serialize(k) .. "]=" .. _M.serialize(v) .. ",\n"  
        end  
    end  
        lua = lua .. "}"  
    elseif t == "nil" then  
        return nil  
    else  
        error("can not serialize a " .. t .. " type.")  
    end  
    return lua  
end 

--table 反序列化
function _M.unserialize(lua)  
    local t = type(lua)  
    if t == "nil" or lua == "" then  
        return nil  
    elseif t == "number" or t == "string" or t == "boolean" then  
        lua = tostring(lua)  
    else  
        error("can not unserialize a " .. t .. " type.")  
    end  
    lua = "return " .. lua  
    local func = loadstring(lua)  
    if func == nil then  
        return nil  
    end  
    return func()  
end  

return _M
