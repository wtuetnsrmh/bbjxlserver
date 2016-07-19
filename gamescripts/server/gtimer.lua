local skynet = require "skynet"
local redisproxy = require "redisproxy"
local sharedata = require "sharedata"

require "shared.init"
require "utils.init"

local PointDataMark = {}

local function check_update()
	local time = skynet.time()
	local date = os.date("*t", time)
	local timeStr = string.format("%02d", date.hour) .. string.format("%02d", date.min)
	local dataStr = date.year .. string.format("%02d", date.month) .. string.format("%02d", date.day)
	PointDataMark[dataStr] = PointDataMark[dataStr] or {}

	local point09 = "0900"
	if timeStr == point09 and not PointDataMark[dataStr][point09] then
		PointDataMark[dataStr][point09] = true

		notifyClients(pushCsv:getMsgById(6))
	end

	local point12 = "1200"
	if timeStr == point12 and not PointDataMark[dataStr][point12] then
		PointDataMark[dataStr][point12] = true

		-- 鸡腿午餐
		notifyClients(pushCsv:getMsgById(1))

		notifyClients(pushCsv:getMsgById(7))
	end

	local point18 = "1800"
	if timeStr == point18 and not PointDataMark[dataStr][point18] then
		PointDataMark[dataStr][point18] = true

		-- 鸡腿晚餐
		notifyClients(pushCsv:getMsgById(2))
		
		notifyClients(pushCsv:getMsgById(8))
	end

	local point21 = "2100"
	if timeStr == point21 and not PointDataMark[dataStr][point21] then
		PointDataMark[dataStr][point21] = true

		notifyClients(pushCsv:getMsgById(9))
	end
end

local handle_timeout
handle_timeout = function ()
	check_update()
	skynet.timeout(100, handle_timeout)
end

skynet.start(function()
	-- csv
	local allCsvData = sharedata.query("csvdb")
	require("csv.CsvLoader").bindCsvData(allCsvData)

	handle_timeout()
end)
