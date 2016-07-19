local skynet = require "skynet"

local max_client = 64

skynet.start(function()
	print("Server start")
	skynet.newservice("console")
	skynet.newservice("debug_console", 8001)

	local watchdog = skynet.newservice("server/watchdog", 10)
	skynet.call(watchdog, "lua", "start", {
		port = 9898,
		maxclient = max_client,

		redishost = "127.0.0.1",
		-- redishost = "115.29.193.94",
		redisport = 6379,
		redisdb = 0,

		mysqlhost = "127.0.0.1",
		mysqlport = 3306,
		mysqlbase = "logs",
		mysqluser = "root",
		mysqlpwd  = "123456" 
	})
	
	-- ngxin处理
	skynet.newservice("server/ngx_http", 5657)

	skynet.exit()
end)
