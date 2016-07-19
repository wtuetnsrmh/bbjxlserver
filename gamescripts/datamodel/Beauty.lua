-- 美人系统美人
-- by yangkun
-- 2014.2.18

-- 美人类
local Beauty = class("Beauty", require("shared.ModelBase"))

function Beauty:ctor(properties)
	Beauty.super.ctor(self,properties)
	require("shared.EventProtocol").extend(self)
end

Beauty.schema = {
	key = {"string"},			-- redis key
	beautyId = {"number"},		-- beauty 配表中id
	level = {"number",1},
	exp = {"number",0},			-- 经验
	evolutionCount = {"number",1},
	status = {"number",2}, 		-- 当前状态，未招募,休息,出战
	potentialHp = {"number", 0}, 	-- 参悟血
	potentialAtk = {"number", 0},	-- 参悟攻击
	potentialDef = {"number", 0},  -- 参悟防御
	delete = {"number",0}			-- 是否删除
}

Beauty.fields = {
	beautyId = true,
	level = true,
	exp = true,
	evolutionCount = true,
	status = true,
	potentialHp = true,
	potentialAtk = true,
	potentialDef = true,
	delete = true
}

Beauty.STATUS_INACTIVE = 0 		-- 未激活
Beauty.STATUS_NON_EMPLOY = 1 	-- 未招募
Beauty.STATUS_REST = 2 			-- 休息
Beauty.STATUS_FIGHT = 3     	-- 战斗

-- 给美人加经验
function Beauty:addExp(deltaValue)
	local currentExp = self:getProperty("exp")
	local beautyData = beautyListCsv:getBeautyById(self:getProperty("beautyId"))
	local currentBeautyData = beautyTrainCsv:getBeautyTrainInfoByEvolutionAndLevel(self:getProperty("evolutionCount"), self:getProperty("level"))
	local upLevelExp = currentBeautyData.upgradeExp

	local nowExp = currentExp + deltaValue
	while nowExp > upLevelExp do
        if self:getProperty("level") == beautyData.evolutionLevel then
			-- 需要突破才能升级,剩余经验浪费
			nowExp = upLevelExp
			break
		end

        nowExp = nowExp - upLevelExp
        self:upLevel(1)
        self:setProperty("exp", 0)

        currentBeautyData = beautyTrainCsv:getBeautyTrainInfoByEvolutionAndLevel(self:getProperty("evolutionCount"), self:getProperty("level"))
        upLevelExp = currentBeautyData.upgradeExp
    end
    self:setProperty("exp", nowExp)
end

-- 给美人升级
function Beauty:upLevel(deltaValue)
	local origLevel = self:getProperty("level")
	local beautyData = beautyListCsv:getBeautyById(self:getProperty("beautyId"))

	if origLevel + deltaValue > beautyData.evolutionLevel then
		-- 需要突破才能升级
	else
		self:setProperty("level", origLevel + deltaValue)
	end
end

-- 增加进阶数
function Beauty:addEvolutionCount(deltaValue)
	local origCount = self:getProperty("evolutionCount")
	self:setProperty("evolutionCount", origCount + deltaValue)
end

function Beauty:addPotentialHp(deltaValue)
	local beautyData = beautyListCsv:getBeautyById(self:getProperty("beautyId"))
	local curLevel = (self:getProperty("evolutionCount") - 1) * beautyData.evolutionLevel + self:getProperty("level")
	local curHp = beautyData.hpGrow * (curLevel - 1) + beautyData.hpInit
	local potentialHpMax = curHp * beautyData.potential / 100

	local curPotentialHp = self:getProperty("potentialHp")
	if curPotentialHp + deltaValue >= potentialHpMax then
		self:setProperty("potentialHp", potentialHpMax)
	elseif curPotentialHp + deltaValue <= 0 then
		self:setProperty("potentialHp", 0)
	else
		self:setProperty("potentialHp", curPotentialHp + deltaValue)
	end
end

function Beauty:getPotentialRandomHp(normal)
	local beautyData = beautyListCsv:getBeautyById(self:getProperty("beautyId"))
	local curLevel = (self:getProperty("evolutionCount") - 1) * beautyData.evolutionLevel + self:getProperty("level")
	local curHp = beautyData.hpGrow * (curLevel - 1) + beautyData.hpInit
	local potentialHpMax = curHp * beautyData.potential / 100

	local curPotentialHp = self:getProperty("potentialHp")

	local max = 10
	local min = -10
	local ret
	local ratio = normal and 1/3 or 3/5 
	if curPotentialHp < 10 then
		ret = math.random(0,max)
	else
		local tempRatio = math.random()
		if tempRatio < ratio then
			ret = math.random(0,max)
		else
			ret = math.random(min,0)
		end
	end

	if ret >= 0 and ret + curPotentialHp > potentialHpMax then
		ret = potentialHpMax - curPotentialHp
	end

	return math.floor(ret)

end

function Beauty:addPotentialAtk(deltaValue)
	local beautyData = beautyListCsv:getBeautyById(self:getProperty("beautyId"))
	local curLevel = (self:getProperty("evolutionCount") - 1) * beautyData.evolutionLevel + self:getProperty("level")
	local curAtk = beautyData.atkGrow * (curLevel - 1) + beautyData.atkInit
	local potentialAtkMax = curAtk * beautyData.potential / 100

	local curPotentialAtk = self:getProperty("potentialAtk")
	if curPotentialAtk + deltaValue >= potentialAtkMax then
		self:setProperty("potentialAtk", potentialAtkMax)
	elseif curPotentialAtk + deltaValue <= 0 then
		self:setProperty("potentialAtk", 0)
	else
		self:setProperty("potentialAtk", curPotentialAtk + deltaValue)
	end
end

function Beauty:getPotentialRandomAtk(normal)
	local beautyData = beautyListCsv:getBeautyById(self:getProperty("beautyId"))
	local curLevel = (self:getProperty("evolutionCount") - 1) * beautyData.evolutionLevel + self:getProperty("level")
	local curAtk = beautyData.atkGrow * (curLevel - 1) + beautyData.atkInit
	local potentialAtkMax = curAtk * beautyData.potential / 100

	local curPotentialAtk = self:getProperty("potentialAtk")

	local max = 10
	local min = -10
	local ret
	local ratio = normal and 1/3 or 3/5 
	if curPotentialAtk < 10 then
		ret = math.random(0,max)
	else
		local tempRatio = math.random()
		if tempRatio < ratio then
			ret = math.random(0,max)
		else
			ret = math.random(min,0)
		end
	end

	if ret >= 0 and ret + curPotentialAtk > potentialAtkMax then
		ret = potentialAtkMax - curPotentialAtk
	end

	return math.floor(ret)

end

function Beauty:addPotentialDef(deltaValue)
	local beautyData = beautyListCsv:getBeautyById(self:getProperty("beautyId"))
	local curLevel = (self:getProperty("evolutionCount") - 1) * beautyData.evolutionLevel + self:getProperty("level")
	local curDef = beautyData.defGrow * (curLevel - 1) + beautyData.defInit
	local potentialDefMax = curDef * beautyData.potential / 100

	local curPotentialDef = self:getProperty("potentialDef")
	if curPotentialDef + deltaValue >= potentialDefMax then
		self:setProperty("potentialDef", potentialDefMax)
	elseif curPotentialDef + deltaValue <= 0 then
		self:setProperty("potentialDef", 0)
	else
		self:setProperty("potentialDef", curPotentialDef + deltaValue)
	end
end

function Beauty:getPotentialRandomDef(normal)
	local beautyData = beautyListCsv:getBeautyById(self:getProperty("beautyId"))
	local curLevel = (self:getProperty("evolutionCount") - 1) * beautyData.evolutionLevel + self:getProperty("level")
	local curDef = beautyData.defGrow * (curLevel - 1) + beautyData.defInit
	local potentialDefMax = curDef * beautyData.potential / 100

	local curPotentialDef = self:getProperty("potentialDef")

	local max = 10
	local min = -10
	local ret
	local ratio = normal and 1/3 or 3/5 
	if curPotentialDef < 10 then
		ret = math.random(0,max)
	else
		local tempRatio = math.random()
		if tempRatio < ratio then
			ret = math.random(0,max)
		else
			ret = math.random(min,0)
		end
	end

	if ret >= 0 and ret + curPotentialDef > potentialDefMax then
		ret = potentialDefMax - curPotentialDef
	end

	return math.floor(ret)

end

-- 更改美人状态
-- 0 未招募
-- 1 休息
-- 2 出战
function Beauty:changeBeautyStatus(status)
	local origStatus = self:getProperty("status")

	if origStatus ~= status then
		self:setProperty("status", status)
	end
end

-- 删除美人记录
function Beauty:delete()
	self:setProperty("delete", 1)
	redisproxy.srem(string.format("role:%d:beautyIds", self.owner:getProperty("id")), self:getProperty("beautyId"))
end

function Beauty:pbData()
	return {
		beautyId = self:getProperty("beautyId"),
		level = self:getProperty("level"),
		exp = self:getProperty("exp"),
		evolutionCount = self:getProperty("evolutionCount"),
		status = self:getProperty("status"),
		potentialHp = self:getProperty("potentialHp"),
		potentialAtk = self:getProperty("potentialAtk"),
		potentialDef = self:getProperty("potentialDef")
	}
end

return Beauty