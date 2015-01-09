local skynet = require "skynet"
require "shared.functions"
require "logconstant"

local function data2String(type, msg)
	local tempstr = logActions[type].field
	local newstr, _ = string.gsub(tempstr, "[%w_]+", msg)
	return "[" .. logActions[type].code .. "]" .. newstr
end

local use_syslog = tonumber(skynet.getenv "syslog")
local use_logd = tonumber(skynet.getenv "logd")

local logger = {}

function logger.info(type, msg)
	if use_logd == 1 then 
		pcall(skynet.send, "LOGD", "lua", "log", type, msg)
	end
	if use_syslog == 0 then return end
	pcall(skynet.send, "LOGGER", "lua", "info", data2String(type, msg))
end

function logger.debug(type, msg)
	if use_syslog == 0 then return end

	pcall(skynet.send, "LOGGER", "lua", "debug", data2String(type, msg))
end

function logger.notice(msg)
	if use_syslog == 0 then return end

	pcall(skynet.send, "LOGGER", "lua", "notice", msg)
end

function logger.warning(msg)
	if use_syslog == 0 then return end

	pcall(skynet.send, "LOGGER", "lua", "warning", msg)
end

function logger.error(msg)
	if use_syslog == 0 then return end

	pcall(skynet.send, "LOGGER", "lua", "error", msg)
end

function logger.alert(msg)
	if use_syslog == 0 then return end
	
	pcall(skynet.send, "LOGGER", "lua", "alert", msg)
end

return logger