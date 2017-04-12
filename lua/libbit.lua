-- Copyright (C) Allen.L, CloudFlare Inc.

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 155)
_M._VERSION = '0.01'
_M.data32 = {}

for i=1,32 do  
    _M.data32[i]=2^(32-i)
end  
  
local function d2b(arg)
	if not arg then
		arg = 0
	end
	
    local tr={}  
    for i=1,32 do  
        if arg >= _M.data32[i] then  
			tr[i]=1  
			arg=arg-_M.data32[i]  
        else  
			tr[i]=0  
        end  
    end
    return tr  
end
  
local function b2d(arg)  
    local   nr=0  
    for i=1,32 do  
        if arg[i] ==1 then  
        nr=nr+2^(32-i)  
        end  
    end  
    return  nr  
end
  
function _M._xor(a,b)  
    local   op1=d2b(a)  
    local   op2=d2b(b)  
    local   r={}  
  
    for i=1,32 do  
        if op1[i]==op2[i] then  
            r[i]=0  
        else  
            r[i]=1  
        end  
    end  
    return b2d(r)  
end
  
function _M._and(a,b)  
    local   op1=d2b(a)  
    local   op2=d2b(b)  
    local   r={}  
      
    for i=1,32 do  
        if op1[i]==1 and op2[i]==1  then  
            r[i]=1  
        else  
            r[i]=0  
        end  
    end  
    return b2d(r)  
      
end
  
function _M._or(a,b)  
    local op1=d2b(a)  
    local op2=d2b(b)  
    local r={}  
      
    for i=1,32 do  
        if  op1[i]==1 or   op2[i]==1   then  
            r[i]=1  
        else  
            r[i]=0  
        end  
    end  
    return b2d(r)  
end
  
function _M._not(a) 
    local op1=d2b(a)  
    local r={}  
  
    for i=1,32 do  
        if  op1[i]==1   then  
            r[i]=0  
        else  
            r[i]=1  
        end  
    end  
    return b2d(r)  
end
  
function _M._rshift(a,n)  
    local op1=d2b(a)  
    local r=d2b(0)  
      
    if n < 32 and n > 0 then  
        for i=1,n do  
            for i=31,1,-1 do  
                op1[i+1]=op1[i]  
            end  
            op1[1]=0  
        end  
    r=op1  
    end  
    return b2d(r)  
end
  
function _M._lshift(a,n)  
    local op1=d2b(a)  
    local r= d2b(0)  
      
    if n < 32 and n > 0 then  
        for i=1,n   do  
            for i=1,31 do  
                op1[i]=op1[i+1]  
            end  
            op1[32]=0  
        end  
    r=op1  
    end  
    return b2d(r)  
end

function _M.test()
	return '14545'
end

return _M
