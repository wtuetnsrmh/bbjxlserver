require("constants")
require("shared.init")
require("utils.init")

skynet = require "skynet"
redisproxy = require("redisproxy")

skynet.start(function()
	local redisd = skynet.newservice("server/redisd")
	skynet.call(redisd, "lua", "open", redisParam)

	print("start")

	for line in io.lines("tools/libaoma.txt") do
		redisproxy:hset("giftCodes", string.trim(line), 0)
	end

	print("over")
end)
