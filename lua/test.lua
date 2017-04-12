-- Copyright (C) Allen.L, CloudFlare Inc.
local lib = require("libglobal")
local json = require "cjson"

local appid = 1400094720
local adbarid = 3565232128
local key = ngx.crc32_short(appid .. adbarid)
ngx.say(key)
local time = ngx.time()
ngx.say(time)
local r_num = lib.getRandomseed(r_num)
ngx.say(r_num)
local num = appid+adbarid+key+time
ngx.say(num)
local token = ngx.md5(appid + adbarid + key + time)
ngx.say(token)
ngx.exit(ngx.OK)

