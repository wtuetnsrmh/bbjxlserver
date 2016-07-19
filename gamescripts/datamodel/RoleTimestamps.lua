-- 时间管理

local RoleTimestamps = class("RoleTimestamps", require("shared.ModelBase"))

function RoleTimestamps:ctor(properties)
	RoleTimestamps.super.ctor(self, properties)
end

RoleTimestamps.schema = {
    key     		= {"string"},       -- redis key

	lastPvpTime 	= {"number", 0},			-- 上次pvp时间，用于pvp 的冷却时间
	lastHealthTime 	= {"number", skynet.time()},	-- 上次恢复体力的时间
	lastShop1Time 	= {"number", 0},	-- 商店1刷新时间
	lastShop2Time 	= {"number", 0},	-- 商店2刷新时间
	lastShop3Time 	= {"number", 0},	-- 商店3刷新时间
	lastShop4Time 	= {"number", 0},	-- 商店4刷新时间
	lastShop5Time 	= {"number", 0},	-- pvp商店刷新时间
	lastShop6Time 	= {"number", 0},	-- 声望商店刷新时间
	lastShop7Time 	= {"number", 0},	-- 星魂商店刷新时间
	store1StartTime = {"number", 0},	-- 基础包抽卡起始时间
	store3StartTime = {"number", 0},	-- 武将包抽卡起始时间
	yuekaDeadline = {"number", 0}, 		-- 月卡到期时间
	specialStore2EndTime = {"number", 0}, --商店2到期时间
	specialStore3EndTime = {"number", 0}, --商店3到期时间
}

RoleTimestamps.fields = {
	lastPvpTime 	= true,
	lastHealthTime 	= true,
	lastShop1Time	= true,
	lastShop2Time	= true,
	lastShop3Time	= true,
	lastShop4Time	= true,
	lastShop5Time	= true,
	lastShop6Time	= true,
	lastShop7Time	= true,
	store1StartTime = true,
	store3StartTime = true,
	yuekaDeadline = true,
	specialStore2EndTime = true,
	specialStore3EndTime = true,
}

function RoleTimestamps:updateProperty(params)
	local newValue = params.newValue or 0

	self:setProperty(params.field, newValue)
	self.owner:notifyUpdateProperty(params.field, newValue)
end

function RoleTimestamps:getShopLeftTime(index)
	local field = string.format("lastShop%dTime", index)
	if self:getProperty(field) == 0 then
		return 0
	else
		return self:getProperty(field) - skynet.time()
	end
end

function RoleTimestamps:getStoreLeftTime(id)
	local startTime = self:getProperty("store" .. id .. "StartTime")
	if not startTime or startTime == 0 then
		return 0
	elseif startTime > 0 then
		local storeInfo = storeCsv:getStoreItemById(id)
		local leftTime = startTime + storeInfo.freeCd - skynet.time()
		if leftTime <= 0 then
			self:setProperty("store" .. id .. "StartTime", 0)
			return 0
		else
			return leftTime
		end
	end
end

function RoleTimestamps:pbData()
	return {
		{ key = "lastPvpTime", value = self:getProperty("lastPvpTime") },
		{ key = "store1LeftTime", value = self:getStoreLeftTime(1) },
		{ key = "store3LeftTime", value = self:getStoreLeftTime(3) },
		{ key = "store1StartTime", value = self:getProperty("store1StartTime") },
		{ key = "store3StartTime", value = self:getProperty("store3StartTime") },
		{ key = "lastHealthTime", value = self:getProperty("lastHealthTime") },
		{ key = "yuekaDeadline", value = self:getProperty("yuekaDeadline") },
		{ key = "specialStore2EndTime", value = self:getProperty("specialStore2EndTime") },
		{ key = "specialStore3EndTime", value = self:getProperty("specialStore3EndTime") },
	}
end

return RoleTimestamps