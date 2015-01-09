local skynet = require "skynet"
local cjson = require "cjson"
local md5 = require("md5")
local httpc = require("http.httpc")

require "socket"

function sleep(sec)
    socket.select(nil, nil, sec)
end

-- 查找上限
-- [10, 20, 30, 40] 查找15, 返回指向10的元素
function lowerBoundSeach(data, searchKey)
	-- 先排序
	local lastKey = nil
	local keys = table.keys(data)
	table.sort(keys)
	for _, key in ipairs(keys) do
		if key > searchKey then
			break
		end
		lastKey = key
	end

	return lastKey and data[lastKey] or nil
end

-- 初始化
function randomInit(seed)
	seed = seed or os.time()
	math.randomseed(tonumber(tostring(seed):reverse():sub(1,6)))
end

-- 随机浮点数
function randomFloat(lower, greater)
    return lower + math.random()  * (greater - lower);
end

function randomInt(lower, greater, callback)
	if type(callback) == "function" then callback() end

	local ret = math.random(lower, greater)
	return ret
end

-- 根据权重值从数据集合里面随机出
-- @param dataset	数据集合
-- @param field 	权重域
-- @param randSeed 	随机种子
function randWeight(dataset, field, randSeed)
	if not dataset then return nil end
	
	field = field or "weight"

	-- 计算权值总和
	local weightSum = 0
	for key, value in pairs(dataset) do
		weightSum = weightSum + tonumber(value[field])
	end

	local randWeight = randomFloat(0, weightSum)

	for key, value in pairs(dataset) do
		if randWeight > tonumber(value[field]) then
			randWeight = randWeight - tonumber(value[field])
		else
			return key
		end
	end

	return nil
end

-- YYYY/MM/DD-YYYY/MM/DD 转化成unixtime数组
-- @params 	dateStr 转化的时间字符串
function toDateArray(dateStr)
	if string.trim(dateStr) == "" then
		dateStr = "2014/01/01-2020/01/01"
	end
	local dateArray = string.split(dateStr, "-")

	local openDate = {}
	if #dateArray == 1 then
		local array = string.split(string.trim(dateArray[1]), "/")
		openDate[1] = os.time{ year=array[1], month=array[2], day=array[3], hour=0,min=0,sec=0}
		openDate[2] = os.time{ year=array[1], month=array[2], day=array[3], hour=23,min=59,sec=59}
	elseif #dateArray == 2 then
		local array = string.split(string.trim(dateArray[1]), "/")
		openDate[1] =  os.time{ year=array[1], month=array[2], day=array[3], hour=0,min=0,sec=0}
		local array = string.split(string.trim(dateArray[2]), "/")
		openDate[2] = os.time{ year=array[1], month=array[2], day=array[3], hour=0,min=0,sec=0}
	end

	return openDate
end

-- 将201402021800或者20140202的格式转化成unixtime
function toUnixtime(timeStr)
	local strLength = string.len(timeStr)
	if strLength ~= 8 and strLength ~= 10 then return end
	local year = string.sub(timeStr, 1, 4)
	local month = string.sub(timeStr, 5, 6)
	local day = string.sub(timeStr, 7, 8)
	local hour, minute = 0, 0
	if strLength == 10 then
		hour = string.sub(timeStr, 9, 10)
		minute = string.sub(timeStr, 11, 12)
	end
    return os.time{year=year, month=month, day=day, hour=hour, min=minute, sec=0}  
end

-- 判断时间点是不是当天
function isToday(curTimestamp)
	local curTm = os.date("*t", curTimestamp)
	local nowTm = os.date("*t", os.time())
	return curTm.year == nowTm.year and curTm.month == nowTm.month and curTm.day == nowTm.day
end

-- 到下一个时间点的秒数差和下一个时间点的unixtime
function diffTime(params)
	params = params or {}
	local currentTime = skynet.time()

	local curTm = os.date("*t", currentTime)
	local nextYear = params.year or curTm.year
	local nextMonth = params.month or curTm.month
	local nextDay = params.day or curTm.day + 1
	local nextHour = params.hour or 0
	local nextMinute = params.min or 0
	local nextSecond = params.sec or 0

	local nextUnixTime = os.time({ year = nextYear, month = nextMonth, day = nextDay, hour = nextHour, min = nextMinute, sec = nextSecond})
	return os.difftime(nextUnixTime, currentTime), nextUnixTime
end

-- 取今天特殊时刻时间戳
function specTime(pms)
	local tm = os.date("*t")
	local year = pms.year or tm.year
	local month = pms.month or tm.month
	local day = pms.day or tm.day
	local hour = pms.hour or 0
	local min = pms.min or 0
	local sec = pms.sec or 0
	return os.time({year = year, month = month, day = day, hour = hour, min = min, sec = sec})
end

function getSecond(timeStr)
	timeStr = timeStr or "0000"
	local hour = tonumber(string.sub(timeStr, 1, 2))
	local min  = tonumber(string.sub(timeStr, 3, 4))
	return hour * 3600 + min * 60
end

function table.contain(a, b, isKey)
	isKey = isKey or false
	if isKey then
		a = table.keys(a)
		b = table.keys(b)
	end
	local aContainb = true
	for key, value in pairs(b) do
		if not table.find(a, value) then
			aContainb = false
			break
		end
	end
	return aContainb
end

function urlencode(str)
   if (str) then
      str = string.gsub (str, "\n", "\r\n")
      str = string.gsub (str, "([^%w ])",
         function (c) return string.format ("%%%02X", string.byte(c)) end)
      str = string.gsub (str, " ", "+")
   end
   return str    
end

-- 推送通知
local serverid = skynet.getenv "serverid"
local secretKey = "467C2221D3A20FE69D23A33E8940C2C5"

-- 推送该服务器的所有用户
-- tag都是交集处理
function notifyClients(msg, otherTags)
	local tags = { serverid }
	for _, tag in ipairs(otherTags or {}) do
		table.insert(tags, tag)
	end

	local content = {
		["appid"] = "1000013239",
		["audience"] = {
			[otherTags and "tag_and" or "tag"] = tags,
		},
		-- ["audience"] = "all",
		["notification"] = {
			["alert"] = msg,
		},
		["options"] = {
     		["ttl"] = 60 * 120
   		}
	}

	local contentJson = cjson.encode(content)
	local header = {
		["content-type"] = "application/x-www-form-urlencoded",
		["X-MJPUSH-SIGNATURE"] = md5.sumhexa(urlencode(contentJson .. "&" .. secretKey))
	}

	local status, body = httpc.request("POST", "push.mjyun.com", "/api/push", {}, header, contentJson)
	if tonumber(status) ~= 200 then
		skynet.error(status, body)
	end
end