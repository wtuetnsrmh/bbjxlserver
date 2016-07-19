local Hero = class("Hero", require("shared.ModelBase"))
local HeroPlugin = require("logical.HeroPlugin")
HeroPlugin.bind(Hero)


function Hero:ctor(properties)
	Hero.super.ctor(self, properties)
	require("shared.EventProtocol").extend(self)

    self.skillLevels = {}
    self.battleSoul = {}
end

Hero.schema = {
    key     = {"string"},       -- redis key
    id 		= {"number"},      	-- id 存储用户 ID
    type    = {"number", 0},    -- 武将ID，即类型
    level   = {"number", 1},    -- 等级
    exp		= {"number", 0},	-- 经验
    choose  = {"number", 0},    -- 选中状态
    createTime = {"number", skynet.time()}, -- 获得时间
    evolutionCount = {"number", 0},
    master = {"number", 0},     -- 主将ID
    skillLevelJson = {"string", "{}"}, -- 技能等级
    delete = { "number", 0},   -- 是否删除
    wakeLevel = {"number", 0}, --觉醒等级
    star = {"number", 1},       --星级
    battleSoulJson = {"string", ""}, --战魂标记
}   

Hero.fields = {
	id = true, 
    type = true, 
    level = true, 
    exp = true,
    choose = true,
    createTime = true,
    evolutionCount = true,
    master = true,
    skillLevelJson = true,
    delete = true,
    wakeLevel = true,
    star = true,
    battleSoulJson = true,
}

-- 增加武将的经验值, 达到升级要求后升级
-- @param deltaValue 增加的经验
function Hero:addExp(deltaValue)
    local unitInfo = unitCsv:getUnitByType(self:getProperty("type"))
    local currentExp = self:getProperty("exp")
    local upLevelExp = self:getLevelTotalExp()

    local nowExp = currentExp + deltaValue
    local levelup = 0
    while nowExp > upLevelExp do

        if self:getProperty("level") + levelup == self.owner:getProperty("level") then
            nowExp = nowExp > upLevelExp and upLevelExp or nowExp
            break
        end

        nowExp = nowExp - upLevelExp
        levelup = levelup + 1
        self:setProperty("exp", 0)

        upLevelExp = self:getLevelExp(self:getProperty("level") + levelup)
    end
    self:setProperty("exp", nowExp)
    self:notifyUpdateProperty("exp", self:getProperty("exp"), currentExp)
    if levelup > 0 then
        self:upLevel(levelup)
    end
end

-- 给武将升级
-- @param 升级值
function Hero:upLevel( deltaValue )
    local unitInfo = unitCsv:getUnitByType(self:getProperty("type"))
    local origLevel = self:getProperty("level")
    if origLevel + deltaValue > self.owner:getProperty("level") then
        -- 达到升级上限
        return
    end

    self:setProperty("level", origLevel + deltaValue)

    self:notifyUpdateProperty("level", self:getProperty("level"), origLevel)
end

-- 给武将升级
-- @param 升级值
function Hero:upSkillLevel( deltaValue )
    local origLevel = self:getProperty("skillLevel")
    if origLevel + deltaValue > 4 then
        -- 达到升级上限
        return
    end

    self:setProperty("skillLevel", origLevel + deltaValue)
    self:notifyUpdateProperty("skillLevel", self:getProperty("skillLevel"), origLevel)
end

function Hero:addEvolutionCount(deltaValue)
    local origCount = self:getProperty("evolutionCount")
    self:setProperty("evolutionCount", origCount + deltaValue)
end

function Hero:updateSkillLevels()
    local skillLevelJson = json.encode(self.skillLevels)

    self:setProperty("skillLevelJson", skillLevelJson)
    self:notifyUpdateProperty("skillLevelJson", skillLevelJson)
end

function Hero:updateBattleSoul()
    local battleSoulJson = json.encode(self.battleSoul)

    self:setProperty("battleSoulJson", battleSoulJson)
    self:notifyUpdateProperty("battleSoulJson", battleSoulJson)
end

function Hero:updateMasterHero(newMaster)
    self:setProperty("master", newMaster)
    self:notifyUpdateProperty("master", newMaster)
end

function Hero:updateWakeLevel()
    local originLevel = self:getProperty("wakeLevel")
    self:setProperty("wakeLevel", originLevel + 1)
end

function Hero:updateStar(deltaValue)
    deltaValue = deltaValue or 1
    local originLevel = self:getProperty("star")
    self:setProperty("star", math.min(originLevel + deltaValue, HERO_MAX_STAR))
    self:notifyUpdateProperty("star", self:getProperty("star"))
end

-- 通知client, 武将数据的变动
-- @param 更新域
-- @param 新值
-- @param 旧值
function Hero:notifyUpdateProperty(field, newValue, oldValue)
    local updateData = {
        id = self:getProperty("id"),
        key = field,
        newValue = newValue and newValue .. "" or "",
        oldValue = oldValue and oldValue .. "" or "",
    }

    local bin = pb.encode("HeroUpdateProperty", updateData)
    SendPacket(actionCodes.HeroUpdateProperty, bin)
end

function Hero:isStarMax()
    return self:getProperty("star") >= HERO_MAX_STAR
end

-- 删除武将记录
function Hero:delete()
    self:setProperty("delete", 1)
    redisproxy:srem(string.format("role:%d:heroIds", self.owner:getProperty("id")), self:getProperty("id"))
end

function Hero:onInit()
    self.unitData = unitCsv:getUnitByType(self:getProperty("type"))
end

function Hero:pbData()
    return {
        id = self:getProperty("id"), 
        type = self:getProperty("type"), 
        level = self:getProperty("level"), 
        exp = self:getProperty("exp"),
        choose = self:getProperty("choose"),
        createTime = self:getProperty("createTime"),
        evolutionCount = self:getProperty("evolutionCount"),
        master = self:getProperty("master"),
        skillLevelJson = self:getProperty("skillLevelJson"),
        wakeLevel = self:getProperty("wakeLevel"),
        star = self:getProperty("star"),
        battleSoulJson = self:getProperty("battleSoulJson"),
    }
end

function Hero:logData(params)
    params = params or {}
    local data = {}

    for field, val in pairs(params) do 
        local lfield = "h_"..field
        if field == "pm1" or field == "pm2" or field == "pm3" then
            data[field] = val
        elseif field == "behavior" and logBehaviors[val] then
            data[field] = logBehaviors[val]
        elseif self.class.schema[field] and logFields[lfield] then
            local tp, _ = unpack(self.class.schema[field])
            if tp == "number" then val = tonumber(val) end
            data[lfield] = val
        end
    end
    
    data.r_id = self.owner:getProperty("id")
    data.r_name = self.owner:getProperty("name")
    data.u_id = self.owner:getProperty("uid")
    data.p_id = tonumber(string.sub(data.u_id, -2, -1))
    data.h_id = self:getProperty("id")
    data.tstamp = skynet.time()
    return data
end

function Hero:getBattleValue(isBase)
    local attrs = isBase and Hero.sGetBaseAttrValues(self.owner:getProperty("id"), self:getProperty("id")) or Hero.sGetTotalAttrValues(self.owner:getProperty("id"), self:getProperty("id"))
    local passiveSkillCount, passiveSkillLevelSum = 0, 0
    for skillId, level in pairs(self.skillLevels) do
        if tonum(skillId) > 10000 then
            passiveSkillCount = passiveSkillCount + 1
            passiveSkillLevelSum = passiveSkillLevelSum + level
        end
    end
    local value = (attrs.hp * globalCsv:getFieldValue("hpFactor") + attrs.atk * globalCsv:getFieldValue("atkFactor") + attrs.def * globalCsv:getFieldValue("defFactor"))
        * (globalCsv:getFieldValue("activeSkillFactor") + globalCsv:getFieldValue("activeSkillGrowth") * self.skillLevels[tostring(self.unitData.talentSkillId)]
            + globalCsv:getFieldValue("passiveSkillFactor") * passiveSkillCount + globalCsv:getFieldValue("passiveSkillGrowth") * passiveSkillLevelSum
            + attrs.hit * globalCsv:getFieldValue("hitFactor") + attrs.miss * globalCsv:getFieldValue("missFactor") + attrs.ignoreParry * globalCsv:getFieldValue("ignoreParryFactor")
            + attrs.crit * (attrs.critHurt/100 + 1) * globalCsv:getFieldValue("critFactor") + attrs.resist * globalCsv:getFieldValue("resistFactor"))

    return value
end

return Hero

