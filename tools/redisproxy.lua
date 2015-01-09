local skynet = require "skynet"

local redisproxy = {}

setmetatable(redisproxy, { __index = function(t, k)
	local cmd = string.upper(k)
	local f = function (self, ...)
		local ok, result = pcall(skynet.call, "REDIS", "lua", cmd, ...)
		if ok then
			return result
		end	
	end
	t[k] = f
	return f
end})

function redisproxy:runScripts(name, ...)
	local RedisScripts = require("redis_scripts/RedisScripts")

	if not RedisScripts[name].sha1 then
		local content = io.readfile(RedisScripts[name].file)
		RedisScripts[name].sha1 = self:script("LOAD", content)
	end

	-- 不存在脚本(系统问题或者需要刷新脚本)
	local existScript = self:script("EXISTS", RedisScripts[name].sha1)
	if existScript[1] == 0 then
		local content = io.readfile(RedisScripts[name].file)
		RedisScripts[name].sha1 = self:script("LOAD", content)
	end

	return self:evalsha(RedisScripts[name].sha1, ...)
end

return redisproxy