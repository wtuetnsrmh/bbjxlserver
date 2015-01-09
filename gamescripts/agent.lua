require "ProtocolCode"
require("shared.init")
require("protos.init")
require("utils.init")
require("constants")
require("SysErrCode")
require("logconstant")

local queue = require "skynet.queue"
local netpack = require "netpack"
local socket = require "socket"
local struct = require "struct"
local lfs = require "lfs"
local sharedata = require "sharedata"
local csvLoader = require "csv.CsvLoader"

redisproxy = require("redisproxy")
skynet = require "skynet"
pb = require("protobuf")
json = require("shared.json")
xxtea = require "xxtea"
datacenter = require("datacenter")
logger = require "logger"
log_util = require "server/log_util"
mcast_util = require "server/mcast_util"

local CMD = {}

local ROLE = {}

local actions = {}
local moduleModifyTimes = {}

local agentInfo = {}  -- { client_fd, role, gate_serv, open_timer}

local agent_util

local lock

--- {{{ 定时器相关
local handle_timeout
handle_timeout = function ()
	if not agentInfo.open_timer then return end

	if not agentInfo.role then
		skynet.timeout(100, handle_timeout)
		return
	end

	agent_util:update(agentInfo)
	skynet.timeout(100, handle_timeout)
end

function start_agent_timer()
	agentInfo.open_timer = true
	skynet.timeout(150, handle_timeout)
end

function cancel_agent_timer()
	agentInfo.open_timer = false
end
---- 定时器相关 }}}

function SendPacket(actionCode, bin, client_fd)
	if #bin > 0 then bin = xxtea.encrypt(bin, XXTEA_KEY) end

	local client_fd = client_fd or agentInfo.client_fd
	local head = struct.pack("H", actionCode)
	socket.write(client_fd, netpack.pack(head .. bin))
end

function sendWorldNotice(content)
	local bin = pb.encode("SimpleEvent", {param1 = skynet.time(), param5 = content})
	mcast_util:pub_world(actionCodes.RoleWorldNotice, bin)
end

local function normalizeActionName(actionName)
	actionName = string.gsub(actionName, "[^%a.]", "")
	actionName = string.gsub(actionName, "^[.]+", "")
	actionName = string.gsub(actionName, "[.]+$", "")

	local parts = string.split(actionName, ".")
	return parts[1], parts[2]
end

local function _require(moduleName)
	local fullModuleName = string.ucfirst(moduleName) .. "Action"
	local modificationTime = lfs.attributes(string.format("gamescripts/actions/%s.lua", fullModuleName), "modification")


	if not moduleModifyTimes[moduleName] or modificationTime > tonumber(moduleModifyTimes[moduleName]) then
		moduleModifyTimes[moduleName] = modificationTime

		package.loaded["actions." .. fullModuleName] = nil
		actions[moduleName] = nil
		
		local actionModule = require("actions." .. fullModuleName)
		actions[moduleName] = actionModule
	end
	return actions[moduleName]
end

gmSubAction = _require "GmSub"

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		local data = skynet.tostring(msg, sz)
		local cmd = struct.unpack("H", string.sub(data, 1, 2))
		return cmd, string.sub(data, 3)
	end,

	dispatch = function(session, address, cmd, data)
		lock(function()
			if cmd == actionCodes.HeartBeat then
				agent_util:heart_beat()
				return		
			end
			local actionName = actionModules[cmd]
			local actionModuleName, actionMethodName = normalizeActionName(actionName)

			local action = _require(actionModuleName)
			local method = action[actionMethodName]

			if type(method) ~= "function" then
				print("ERROR_SERVER_INVALID_ACTION", ERROR_SERVER_INVALID_ACTION, actionModuleName, actionMethodName)
			end

			if #data > 0 then data = xxtea.decrypt(data, XXTEA_KEY) end
			method(agentInfo, data)
		end)
	end
}

skynet.register_protocol {
	name = "role",
	id = 12,
	pack = skynet.pack,
	unpack = skynet.unpack,
	dispatch = function(session, address, submethod, ...)
		local result
		if not agentInfo.role then 
			result = "__OFFLINE__"
		else
			result = agentInfo.role[submethod](agentInfo.role, ...)
		end

		skynet.ret(skynet.pack(result))
	end,	
}

function CMD.start(gate, fd, ip)
	ignoreHeartbeat = false

	agentInfo.client_fd = fd
	agentInfo.gate_serv = gate
	agentInfo.ip = ip
	if agentInfo.role then
		agentInfo.role:setProperty("session", fd)
	end

	agent_util:reset()
	randomInit()

	local ok, _ = pcall(skynet.call, gate, "lua", "forward", fd)
	return ok
end

function CMD.close()
	local role = agentInfo.role
	if not role then return end
	cancel_agent_timer()

	mcast_util:usub_world()
	
	logger.info("r_logout", role:logData({
		vipLevel = role:getProperty("vipLevel"),
		level = role:getProperty("level"),
	}))
end

function CMD.exit()
	if agentInfo.role then 
		datacenter.set("agent", agentInfo.role:getProperty("id"), nil)
	end
	skynet.exit()	
end

local function route_gm_cmd(cmd, ...)
	local params = ...
	if type(params) ~= "table" or not agentInfo.role then
		return "指令失败"
	end
	if not gmSubAction[cmd] then
		return cmd.."命令不存在"
	end
	return gmSubAction[cmd](agentInfo.role, params)
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		if f then
			if command == "exit" then
				f(...)				
			else
				skynet.ret(skynet.pack(f(...)))
			end
		else
			skynet.ret(skynet.pack(route_gm_cmd(command, ...)))
		end
	end)

	lock = queue()

	local protoFiles = {"common", "role", "hero", "pvp", "carbon", "store", "gift", "friend", "equip", "expedition"}

	local pbParser = require("parser")
	pbParser.register(protoFiles)
	
	-- csv
	local allCsvData = sharedata.query("csvdb")
	csvLoader.bindCsvData(allCsvData)	

	agent_util = require "server/agent_util"
end)
