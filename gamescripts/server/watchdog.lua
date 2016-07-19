local skynet = require "skynet"
local sharedata = require "sharedata"
local struct = require "struct"
local redisproxy = require "redisproxy"
local socket = require "socket"
local pb = require("protobuf")
local pbParser = require("parser")
local netpack = require "netpack"
local datacenter = require("datacenter")
local snax = require "snax"
local agent_ctrl = require("server/agent_ctrl")
local xxtea = require "xxtea"
local mc = require "multicast"

require "constants"
require "ProtocolCode"
require "shared.init"
require "utils.init"
require "protos.init"

local CMD = {}
local SOCKET = {}
local redisd, logd

local pool_size = tonumber(...)

-- 检查agent状态的定时间隔
local CHECK_AGENT_STATUS_INTERVAL 	= 60 * 100 

function SOCKET.open(fd, addr)
	skynet.call(gate_serv, "lua", "accept" , fd)
	agent_ctrl:socket_open(fd, addr)
end

function SOCKET.close(fd)
	print("socket close", fd)
	agent_ctrl:socket_close(fd)
end

function SOCKET.error(fd, msg)
	print("socket error",fd, msg)
	agent_ctrl:socket_error(fd)
end

function SOCKET.data(fd, msg)
	local cmd = struct.unpack("H", string.sub(msg, 1, 2))
	if cmd == actionCodes.RoleQueryLogin then
		local data = pb.decode("RoleQueryLogin", xxtea.decrypt(string.sub(msg, 3), XXTEA_KEY))
		-- TODO: 先检测uid的合法性
		agent_ctrl:query_agent(fd, data.uid)	
 	end
end

local use_logd = tonumber(skynet.getenv "logd")

function CMD.start(conf)
	skynet.call(gate_serv, "lua", "open" , conf)
	skynet.call(redisd, "lua", "open", conf)
	if use_logd == 1 then
		skynet.call(logd, "lua", "open", conf)
	end
end

-- @desc: agent状态定时检测
local check_agent_status
check_agent_status = function ()
	agent_ctrl:check_agent_status()
	skynet.timeout(CHECK_AGENT_STATUS_INTERVAL, check_agent_status)
end

-- 创建world以及guild channel 用于广播
--[[
从数据库获取公会id集合，为每个公会创建一个channel，并存储在datacenter
datacenter.set("MC_G_CHANNEL", guild_id, chan.channel)
]]
local create_mutilcast = function ()
	local chan_w = mc:new()
	datacenter.set("MC_W_CHANNEL", chan_w.channel)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "socket" then
			local f = SOCKET[subcmd]
			f(...)
			-- socket api don't need return
		else
			local f = assert(CMD[cmd])
			skynet.ret(skynet.pack(f(subcmd, ...)))
		end
	end)
	skynet.register "watchdog"

	-- load all csv data
	local allCsvData = {}
	require("csv.CsvLoader").loadCsv(allCsvData)
	sharedata.new("csvdb", allCsvData)

	agent_ctrl:new(pool_size)
	print(string.format("launch %d agent at the beginning", pool_size))

	-- 数据库服务
	redisd = skynet.newservice("server/redisd")

	-- 日志处理器
	if use_logd == 1 then
		logd = skynet.newservice("server/logsqld")
	end

	-- 网关服务
	gate_serv = skynet.newservice("gate")

	-- 日志服务
	local logger = skynet.newservice("server/loggerd")

	local protoFiles = {"common", "role", "hero", "pvp", "carbon", "store", "gift", "friend", }
	pbParser.register(protoFiles)

	print("csv load complete...")

	-- 全局工具函数
	skynet.newservice("server/gfunctions")

	-- 全局定时器
	skynet.newservice("server/gtimer")

	-- 开启agent状态检测定时器
	check_agent_status()

	-- 创建广播服务
	create_mutilcast()
end)
