
local skynet = require "skynet"
local socket = require "socket"
local struct = require "struct"
local redisproxy = require "redisproxy"
local pb = require("protobuf")
local netpack = require "netpack"
local logger = require "logger"
local xxtea = require "xxtea"

require "constants"

-- agent过期时间 10分钟
local AGENT_EXPIRE_TIME				= 600

-- 每分钟补给agent_pool的个数
local FEED_COUNT					= 5

local agent_pool = {
	pool_size = 0,
	tb_recycle = {},
}

function agent_pool:ctor(pool_size)
	self.pool_size = pool_size
	for i = 1, pool_size do
		table.insert(self.tb_recycle, skynet.newservice("agent"))
	end
end

function agent_pool:pop()
	if #self.tb_recycle >= 1 then
		return table.remove(self.tb_recycle)
	else
		return false
	end
end

function agent_pool:push(agent_serv)
	if not agent_serv then
		return false
	end
	-- if #self.tb_recycle >= self.pool_size then
	-- 	return false
	-- end
	table.insert(self.tb_recycle, agent_serv)
	return true
end

function agent_pool:pool_size()
	return self.pool_size
end

function agent_pool:valid_pool_size()
	return #self.tb_recycle
end

--------------------recycle--------------------
local _M = {
	-- fd -> {expire, uid} 若expire==0,说明agent处于活动状态
	tb_fd2agent = {},
	-- uid -> {fd, agent}
	tb_id2agent = {},
	-- fd -> ip
	tb_fd2ip = {},
	nb_exit = 0,
}

function _M:new(pool_size)
	pool_size = pool_size or 10
	agent_pool:ctor(pool_size)
end

-- @desc: 获取agent
function _M:newserv_agent()
	local agent_serv = agent_pool:pop() 
	if not agent_serv then
		agent_serv = skynet.newservice("agent")
	end
	return agent_serv
end

-- @desc: agent退出
function _M:exit_agent(fd)
	if not self.tb_fd2agent[fd] then return end
	local uid = self.tb_fd2agent[fd].uid 
	local a = self.tb_id2agent[uid]
	if a then
		self.tb_id2agent[uid] = nil
		self.tb_fd2agent[fd] = nil
		skynet.send(a.agent, "lua", "exit")
		self.nb_exit = self.nb_exit + 1
	end
end

-- @desc: 客户端连入
function _M:socket_open(fd, addr)
	self.tb_fd2ip[fd] = addr
end

-- @desc: 网络关闭
function _M:socket_close(fd)
	self.tb_fd2ip[fd] = nil
	if not self.tb_fd2agent[fd] then
		return
	end
	self.tb_fd2agent[fd].expire = skynet.time() + AGENT_EXPIRE_TIME
	local uid = self.tb_fd2agent[fd].uid 
	skynet.call(self.tb_id2agent[uid].agent, "lua", "close")
end

-- @desc: 网络出错
function _M:socket_error(fd)
	self.tb_fd2ip[fd] = nil
	if not self.tb_fd2agent[fd] then
		return
	end
	local uid = self.tb_fd2agent[fd].uid 
	skynet.call(self.tb_id2agent[uid].agent, "lua", "close")
	self:exit_agent(fd)
end

local nexttime = 0

-- @desc: 检查agent状态
function _M:check_agent_status()
	local cli_num = 0
	local now = skynet.time()

	for fd, a in pairs(self.tb_fd2agent) do
		if a.expire == 0 then cli_num = cli_num + 1 end
		
		if a.expire ~= 0 and a.expire < now then
			self:exit_agent(fd)
		end
	end

	-- 每分钟补充FEED_COUNT个agent
	if self.nb_exit > FEED_COUNT then
		for i=1, FEED_COUNT do
			agent_pool:push(skynet.newservice("agent"))
		end
		self.nb_exit = self.nb_exit - FEED_COUNT
	end

	if now >= nexttime then
		nexttime = now + 600
		logger.info("s_num_user_on", {pm1=cli_num, pm2=0, pm3=0, tstamp=now,})

		-- 运营商日志
		local platform_logs = {}
		local serverId = skynet.getenv "serverid"
		table.insert(platform_logs, now)
		table.insert(platform_logs, cli_num)
		table.insert(platform_logs, cli_num)
		table.insert(platform_logs, 2045)
		table.insert(platform_logs, serverId)
		logger.error(table.concat(platform_logs, "\t"))
	end
end

local function query_agent_response(fd, response)
	local head = struct.pack("H", actionCodes.RoleQueryResponse)
	
	local bin = pb.encode("RoleQueryResponse", response)
	if #bin > 0 then bin = xxtea.encrypt(bin, XXTEA_KEY) end
	socket.write(fd, netpack.pack(head .. bin))
end

-- @desc: 
function _M:query_agent(fd, uid)
	local agentInfo = self.tb_id2agent[uid]
	local ip = self.tb_fd2ip[fd]
	if agentInfo then
		if agentInfo.fd == fd then
			skynet.error(skynet.time(), "double click query login", fd)
			return
		end
		-- fd改变
		-- 1. 若在线，踢下线
		if self.tb_fd2agent[agentInfo.fd].expire == 0 then
			local bin = pb.encode("SimpleEvent", {})
			local head = struct.pack("H", actionCodes.RoleKickDown)
			socket.write(agentInfo.fd, netpack.pack(head .. bin))
			skynet.call(gate_serv, "lua", "kick", agentInfo.fd)
		end
		-- 2. 通知 gate 建立新fd监听
		-- skynet.call(gate_serv, "lua", "accept", fd)
		-- 3. 通知 agent 重新建立fd索引
		local ok, ret = pcall(skynet.call, agentInfo.agent, "lua", "start", gate_serv, fd, ip)
		if not ok or not ret then 
			query_agent_response(fd, {ret = "INNER_ERROR"})
			return
		end

		-- 4. 删除old_fd索引
		self.tb_fd2agent[agentInfo.fd] = nil
		-- 5. 更新agentInfo
		agentInfo.fd = fd
	else
		-- agentInfo不存在
		-- 1. 创建tb_id2agent[uid]
		agentInfo = {
			fd = fd, 
			agent = self:newserv_agent()
		}
		-- 2. 通知 agent 建立fd索引
		local ok, ret = pcall(skynet.call, agentInfo.agent, "lua", "start", gate_serv, fd, ip)
		if not ok or not ret then 
			agent_pool:push(agentInfo.agent)
			query_agent_response(fd, {ret = "INNER_ERROR"})
			return
		end
	end
	-- 更新 tb_fd2agent 以及 tb_id2agent
	self.tb_fd2agent[fd] = {
		expire = 0,
		uid = uid
	}
	self.tb_id2agent[uid] = agentInfo

	local response = {}
	local user = redisproxy:get(string.format("uid:%s", uid))
	if user then
		response.ret = "RET_HAS_EXISTED"			
		response.name = user
	else
		response.ret = "RET_NOT_EXIST"
	end
	query_agent_response(fd, response)
end

return _M