package.cpath = "luaclib/?.so"
package.path = "gamescripts/?.lua"

local socket = require "clientsocket"
local struct = require "struct"
local pb = require "protobuf"
local xxtea = require "xxtea"

require "ProtocolCode"
require "protos.init"
require "constants"

-- global var
-- 接收终端参数 , 默认客户端为1个
host, port, cli_num = ...
host = host or "127.0.0.1"
port = tonumber(port or 9898)
cli_num = tonumber(cli_num or 1)

-- local var
local clients = {
	uids = {},
	types = {},
	names = {},
	fds = {},
	dispatchs = {},
}

local fd2i = {}

local born_heros = { 28, 176, 53, 50, }

local dead_cli = {}

-- listen interface
local listen = {
	contains = {},
}
function listen:addListener(eventName, listener)
	if self.contains[eventName] == nil then
		self.contains[eventName] = listener
	end
end

function listen:removeListener(eventName, listener)
	if self.contains[eventName] ~= nil then
		self.contains[eventName] = nil
	end
end

function listen:dispatchEvent(event)
	if self.contains[event.name] ~= nil then
		listener = self.contains[event.name]	
		listener(event)
	end
end

local function sendData(fd, actionCode, bin)
	if #bin > 0 then bin = xxtea.encrypt(bin, XXTEA_KEY) end
	local head = struct.pack("H", actionCode)
	socket.send(fd, head .. bin)
end

-- 1: 注册协议文件
local function registerPbFile()
	local protoFiles = { "common", "role", }
	local parser = require "parser"
	parser.register(protoFiles)
end
registerPbFile()

-- 2: 定义消息派发
for i = 1, cli_num do 
	clients.types[i] = i % 4 + 1
	clients.names[i] = string.format("xiefan%d", i)
	clients.dispatchs[i] = function ()
		local result = {}
		fd = clients.fds[i] 
		local status, last
		status, last = socket.recv(fd, last, result)
		if status then
			for _, msg in ipairs(result) do
				local event = {}
				event.name = struct.unpack("H", string.sub(msg, 1, 2))
				event.data = xxtea.decrypt(string.sub(msg, 3), XXTEA_KEY)
				event.target = fd
				listen:dispatchEvent(event)
			end
		end
	end
end

-- 3: 设置监听,这里跟原来的处理不一致，当玩家存在的时候，直接进行验证
listen:addListener(actionCodes.RoleQueryResponse, function (event)
	local index = fd2i[event.target]
	local msg = pb.decode("RoleQueryResponse", event.data)
	if msg.ret == "RET_NOT_EXIST" then 
		print(string.format("--RoleQueryResponse-- role xiefan%d not exist", index))
		local i = math.random(1, 4)
		local bin = pb.encode("RoleCreate", { 
			uid = clients.uids[index], 
			name = clients.names[index], 
			heroType = born_heros[i], 
			uname = clients.names[index], 
			packageName = "dangge",
			deviceId = clients.uids[index],
		})
		sendData(clients.fds[index], actionCodes.RoleCreate, bin)
	elseif msg.ret == "RET_HAS_EXISTED" then
		print(string.format("--RoleQueryResponse-- role xiefan%d has existed", index))
		local bin = pb.encode("RoleLoginData", { name = clients.names[index] })
		sendData(clients.fds[index], actionCodes.RoleLoginRequest, bin)
	elseif msg.ret == "INNER_ERROR" then
		print(string.format("--RoleQueryResponse-- role xiefan%d touch INNER_ERROR", index))
		socket.close(event.target)
		clients.fds[index] = socket.connect(host, port)
		table.insert(dead_cli, index)
	end
end)
listen:addListener(actionCodes.RoleCreateResponse, function (event)
	local index = fd2i[event.target]
	local msg = pb.decode("RoleCreateResponse", event.data)
	if msg.result == "DB_ERROR" then
		print(string.format("--RoleCreateResponse-- role xiefan%d exists, then login", index))
	else
		print(string.format("--RoleCreateResponse-- role xiefan%d create success, then login", index))
	end
	local bin = pb.encode("RoleLoginData", { name = clients.names[index] })
	sendData(clients.fds[index], actionCodes.RoleLoginRequest, bin)
	print(string.format("xiefan%d try to login request", index))	
end)
listen:addListener(actionCodes.RoleLoginResponse, function (event)
	local index = fd2i[event.target]
	local msg = pb.decode("RoleLoginResponse", event.data)
	if msg.result == "SUCCESS" then
		print(string.format("--RoleLoginResponse-- xiefan%d success", index))
	elseif msg.result == "NOT_EXIST" then
		print(string.format("--RoleLoginResponse-- xiefan%d not_exist", index))
	elseif msg.result == "HAS_LOGIN" then		
		print(string.format("--RoleLoginResponse-- xiefan%d has_login", index))
	elseif msg.result == "DB_ERROR" then	
		print(string.format("--RoleLoginResponse-- xiefan%d db_error", index))
	end
	socket.close(event.target)
	clients.fds[index] = socket.connect(host, port)
	table.insert(dead_cli, index)
end)

-- 4: 客户端连接服务器
-- 获取uid
for uid in io.lines("t.log") do
	table.insert(clients.uids, tonumber(uid))
end

for i = 1, cli_num do
	clients.fds[i] = socket.connect(host, port)
	-- 建立fd <-> i 的索引
	fd2i[clients.fds[i]] = i
	print(string.format("%d try to connect server", i))
end

local function sleep(n)
   os.execute("sleep " .. n)
end
sleep(1)

-- 5: 发起登录请求
local function login(index)
	local bin = pb.encode("RoleQueryLogin", { uid = tostring(clients.uids[index]) })
	sendData(clients.fds[index], actionCodes.RoleQueryLogin, bin)
	print(string.format("name%d, try to query login request", index))	
end
for i = 1, cli_num do 
	login(i)
end

-- 6: 消息循环
local function loop()
	while true do
		for i = 1, cli_num do
			clients.dispatchs[i]()
		end
		for _, v in ipairs(dead_cli) do
			login(v)
		end
		dead_cli = {}
		socket.usleep(100)
	end
end
loop()
