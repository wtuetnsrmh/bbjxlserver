skynet = require "skynet"
cjson = require "shared.json"
redisproxy = require "redisproxy"
netpack = require "netpack"
datacenter = require "datacenter"
sharedata = require "sharedata"
logger = require "logger"

local socket = require "socket"
local lfs = require "lfs"
require "shared.init"

local port = tonumber(...)
local actions = {}
local moduleModifyTimes = {}

local function _require(modName)
	local fullModName = "H"..string.ucfirst(modName) .. "Action"
	local modificationTime = lfs.attributes(string.format("gamescripts/https/%s.lua", fullModName), "modification")

	if not moduleModifyTimes[modName] or modificationTime > tonumber(moduleModifyTimes[modName]) then
		moduleModifyTimes[modName] = modificationTime

		package.loaded["https." .. fullModName] = nil
		actions[modName] = nil
		
		local actionModule = require("https." .. fullModName)
		actions[modName] = actionModule
	end
	return actions[modName]
end

local function process(request)
	local req = cjson.decode(request)
	local modName, funcName = string.match(req["handle"], "([%w_]+)%.([%w_]+)")
	local action = _require(modName)	
	if type(action[funcName]) ~= "function" then 
		return "handle form error"
	end
	return action[funcName](req)
end

local function main_loop(stdin, send)
	socket.lock(stdin)
	while true do
		local request = socket.readline(stdin, "$end$")
		if not request then
			break
		end

		local response = process(request)
		if response then send(response) end
	end
	socket.unlock(stdin)
end

skynet.register_protocol {
	name = "role",
	id = 12,
	pack = skynet.pack,
	unpack = skynet.unpack,
}

skynet.start(function()
	local listen_socket = socket.listen ("0.0.0.0", port)
	print("Start nginx proxy at port: ", port)

	local allCsvData = sharedata.query("csvdb")
	local function attachMethod(name)
		local csvData = allCsvData[name] or {}
		for key, value in pairs(csvData) do
			_G[name][key] = value
		end
	end

	_G["vipCsv"] = require("csv.VipCsv")
	attachMethod("vipCsv")

	_G["rechargeCsv"] = require("csv.ReChargeCsv")
	attachMethod("rechargeCsv")

	socket.start(listen_socket, function(id, addr)
		local function send(...)
			local t = { ... }
			socket.write(id, table.concat(t,"\t"))
			socket.write(id, "$end$")
		end
		socket.start(id)
		skynet.fork(main_loop, id, send)
	end)
end)
