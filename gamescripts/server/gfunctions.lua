require "shared.init"
local skynet = require "skynet"
local utf8 = require "utf8.c"
local crab = require "crab.c"
require "constants"

local mode, id = ...

if mode == "sub" then

	local CMD = {}
	function CMD.check_words(name)
		if not name then return false end
		local texts = {}
		assert(utf8.toutf32(string.trim(name), texts), "non utf8 words detected:", texts)

		crab.filter(texts)
		local output = utf8.toutf8(texts)

		local pos = string.find(output, "%*")

		return pos == nil
	end
	skynet.start(function()
		skynet.dispatch("lua", function(_,_, command, ...)
			local f = CMD[command]
			skynet.ret(skynet.pack(f(...)))
		end)

		skynet.register(string.format("G_FUNCTIONS%d", id))
	end)

else

	skynet.start(function()
		local words = {}
		for line in io.lines("res/illegal_words.txt") do
			if line then
				local t = {}
				assert(utf8.toutf32(string.trim(line), t), "non utf8 words detected:"..line)
				table.insert(words, t)
			end
		end
		crab.open(words)
		for i = 0, G_SERV_COUNT - 1 do
			skynet.newservice(SERVICE_NAME, "sub", i)
		end
	end)

end
