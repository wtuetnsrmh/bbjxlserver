local Tower = class("Tower", require("shared.ModelBase"))

function Tower:ctor(properties)
	Tower.super.ctor(self, properties)
end

Tower.schema = {
    key     	= {"string"}, 			-- redis key
    count 		= {"number", 3},		-- 次数
    carbonId 	= {"number", 40101},   	-- 副本ID
    failureCount	= {"number", 0},	-- 失败次数
    totalStarNum 	= {"number", 0},	-- 当前总星星(1-7)
    preTotalStarNum = {"number", 0},	-- 前一阶段的总星星(1-5)
    maxTotalStarNum = {"number", 0},	-- 排行榜上面的最大星星数
    curStarNum	= {"number", 0},   		-- 当前剩余星星
    hpModify	= {"number", 0},		-- hp修正
    atkModify	= {"number", 0},		-- atk修正
    defModify	= {"number", 0},		-- def修正
    modifyCarbonId = {"number", 0},		-- 正在修正的关卡
    awardCarbonId = {"number", 0},		-- 已奖励关卡
    sceneId1	= {"number", 0},		-- 难度1
    sceneId2	= {"number", 0},		-- 难度2
    sceneId3	= {"number", 0},		-- 难度3
    yuanbao 	= {"number", 0},		-- 刷塔获得元宝数目
    opendBoxNum = {"number", 0},		-- 开宝箱数目
    lastPlayTime= {"number", skynet.time()},-- 上一次时间
}

Tower.fields = {
	count = true, 
	carbonId = true, 
	totalStarNum = true, 
	preTotalStarNum = true, 
	maxTotalStarNum = true, 
	curStarNum = true, 
	hpModify = true, 
	atkModify = true, 
	defModify = true,
	modifyCarbonId = true,
	awardCarbonId = true,
	sceneId1 = true,
	sceneId2 = true,
	sceneId3 = true,
	lastPlayTime = true,
	opendBoxNum = true,
}

-- 根据时间充值
function Tower:reset()
	self:setProperty("count", 3)
	self:setProperty("carbonId", 40101)
	self:setProperty("totalStarNum", 0)
	self:setProperty("preTotalStarNum", 0)
	self:setProperty("maxTotalStarNum", 0)
	self:setProperty("curStarNum", 0)
	self:setProperty("hpModify", 0)
	self:setProperty("atkModify", 0)
	self:setProperty("defModify", 0)
	self:setProperty("modifyCarbonId", 0)
	self:setProperty("awardCarbonId", 0)
	self:setProperty("sceneId1", 0)
	self:setProperty("sceneId2", 0)
	self:setProperty("sceneId3", 0)
	self:setProperty("opendBoxNum", 0)
	return true
end

function Tower:pbData()
	return {
		count = self:getProperty("count"),
		carbonId = self:getProperty("carbonId"), 
		totalStarNum = self:getProperty("totalStarNum"), 
		preTotalStarNum = self:getProperty("preTotalStarNum"), 
		maxTotalStarNum = self:getProperty("maxTotalStarNum"), 
		curStarNum	= self:getProperty("curStarNum"),
		hpModify = self:getProperty("hpModify"), 
		atkModify = self:getProperty("atkModify"), 
		defModify = self:getProperty("defModify"),
		sceneId1 = self:getProperty("sceneId1"), 
		sceneId2 = self:getProperty("sceneId2"), 
		sceneId3 = self:getProperty("sceneId3"),
		opendBoxNum = self:getProperty("opendBoxNum"),
	}
end

return Tower