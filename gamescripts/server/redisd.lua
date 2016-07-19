local skynet = require "skynet"
local redis = require "redis"

local db

local command = {}

function command.open(conf)
	db = redis.connect({
		host = conf.redishost,
		port = conf.redisport,
		db = conf.redisdb or 0,
		auth = conf.auth,
	})

	-- 字段预留
	local roleGenerator = db:hget("autoincrement_set", "role")
	if not roleGenerator then
		db:hset("autoincrement_set", "role", 10000)
	end

	local server_start = db:hget("autoincrement_set", "server_start")
	if not server_start then
		local curTime = math.floor(skynet.time())
		db:hset("autoincrement_set", "server_start", os.date("%Y%m%d", curTime))
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		if cmd == "open" then
			local f = command[string.lower(cmd)]
			skynet.ret(skynet.pack(f(...)))
		else
			skynet.ret(skynet.pack(db[string.lower(cmd)](db, ...)))
		end
	end)
	skynet.register "REDIS"	
end)