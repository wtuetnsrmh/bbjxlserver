local json = require("shared.json")

DefaultRoleValues = {
	-- 职业数据
	professionData = {
		[1] = {1, 0, 0, 0, 0},
		[3] = {1, 0, 0, 0, 0},
		[4] = {1, 0, 0, 0, 0},
		[5] = {1, 0, 0, 0, 0},
	},
	-- 战场次数
	pvpCount = 10,
}

local Role = class("Role", require("shared.ModelBase"))
local RolePlugin = require("logical.RolePlugin")
RolePlugin.bind(Role)

function Role:ctor(properties)
	Role.super.ctor(self, properties)
	require("shared.EventProtocol").extend(self)

	self.maps = {}
	self.carbons = {}
	self.mapCarbons = {}	-- 地图ID和副本ID映射
	self.heros = {}
	self.chooseHeroIds = {}
	self.beauties = {}
	self.items = {}
	self.equips = {}
	self.levelGifts = {}
	self.serverGifts = {}
	self.slots = {}		-- 点将卡槽信息 { [1] = { heroId = heroId, assistants = {}, equips = {} }}
	self.firstRecharge = {}
	self.partners = {}
	self.rechargeGifts = {}
	self.skillOrder = {}
	self.fund = {}

	self.towerData = nil

	self.fragments = {}
	self.equipFragments = {}
	self.professionBonuses = {}
	self.legendShopItems = {}
	self.chooseHeroIds = {}
	self.pvpShopItems = {}
	self.towerShopItems = {}
	self.dailyData = nil
	self.timestamps = nil
end

Role.schema = {
	key     = {"string"},       -- redis key
	id 		= {"number"},      	-- id 存储用户 ID
	uid 	= {"string", ""},		-- 代理生成的唯一ID
	session = {"number", 0},	-- 用户sessionid
	name 	= {"string", ""},   -- 存储用户名
	uname 	= {"string", ""},	-- 账号名
	level	= {"number", 1},   	-- 玩家等级
	exp		= {"number", 0},	-- 玩家经验
	health	= {"number", 50},	-- 玩家体力值
	money	= {"number", 0},	-- 玩家金币
	yuanbao	= {"number", 0},	-- 玩家元宝
	pvpStatus	= {"number", 0},	-- 玩家状态(0:空闲, 1:PVP战斗)
	pvpRank	= {"number", 0},	-- 玩家当前的PVP排名
	pvpBestRank = {"number", 0},	-- 历史最高pvp排名
	lastLoginTime = {"number", 0},	-- 上次登录的时间
	pveFormationJson = {"string", ""},
	yzFormationJson = {"string", ""},
	mainHeroId = {"number", 0},
	friendValue = {"number", 0},
	heroSoulNum = {"number", 0},
	lingpaiNum = {"number", 2},
	professionData = {"string", json.encode(DefaultRoleValues.professionData) },
	starSoulNum = {"number", 10},
	starPoint = {"number", 100},
	rechargeRMB = {"number", 0},
	vipLevel = {"number", 0},
	sweepCarbonId = {"number", 0},		-- 扫荡副本id
	sweepCount = {"number", 0},			-- 扫荡副本的次数
	sweepResult = {"string", ""},		-- 扫荡结果的二进制表示
	chooseHeroIds = {"string", "{}"}, 	-- 已选将的武将ID
	guideStep = {"number", 1},			-- 新手引导
	zhangongNum = {"number", 0},
	reputation = {"number", 0},

	levelGiftsJson = {"string", ""}, 	-- 等级礼包领取状态
	serverGiftsJson = {"string", ""},	-- 开服礼包领取状态
	fundJson = {"string", ""},	-- 基金领取状态
	loginDays = {"number", 0},		-- 登陆天数
	slotsJson = {"string", ""},
	partnersJson = {"string", ""},		-- 小伙伴
	skillOrderJson = {"string", ""},	-- 技能释放顺序

	createtime = {"number", skynet.time()},  -- 创建时间
	delete = {"number", 0},   			-- 是否删除

	status = {"number", 0},
	canSweep = {"number", 1},			-- 是否可以扫荡

	bagHeroBuyCount = {"number", 0},	-- 武将背包购买次数
	activedGuide = {"string", ""},
	nextResetDailyTime = {"number", 0}, -- 下次重置日常数据时间
	yzLevel = {"number", 1}, 			-- 远征关卡
	pre1 = {"number", 0},				-- 远征上次通关关卡
	pre2 = {"number", 0},				-- 远征上上次通关关卡

	-- 商店数据
	shop1ItemsJson	= {"string", ""},
	shop2ItemsJson	= {"string", ""},
	shop3ItemsJson	= {"string", ""},
	shop4ItemsJson	= {"string", ""},
	shop5ItemsJson = {"string", ""},	-- pvp商店物品ID
	shop6ItemsJson	= {"string", ""},
	shop7ItemsJson	= {"string", ""},

	--首充
	firstRechargeJson = {"string", ""},
	firstRechargeAwardState = {"number", 0},--首充礼包领取状态 0：不可领 1：可领 2：已领取

	rechargeGiftsJson = {"string", ""}, 	-- 累充领取状态

	battleSpeed = {"number", 1},

	enterFlag 	= {"number", 0}, 		-- 进入战斗时的标记
	silent = {"number", 0},				-- 是否禁言

	godHeroCount = {"number", 0},

	legendCardonIdIndex = {"number", 0},    -- 
	renameCount = {"number", 0},
	specialBattleCnt = {"number", 0},
}

Role.fields = {
	id = true,
	uid = true,
	name = true, 
	uname = true,
	level = true, 
	exp = true, 
	health = true,
	money = true, 
	yuanbao = true,
	pvpStatus = true,
	pvpRank = true,
	pvpBestRank = true,
	lastLoginTime = true,
	createtime = true,
	delete = true,
	pveFormationJson = true,
	yzFormationJson = true,
	mainHeroId = true,
	friendValue = true,
	heroSoulNum = true,
	lingpaiNum = true,
	professionData = true,
	starSoulNum = true,
	starPoint = true,
	rechargeRMB = true,
	vipLevel = true,
	sweepCarbonId = true,
	sweepCount = true,
	sweepResult = true,
	zhangongNum = true,
	reputation = true,
	chooseHeroIds = true,
	guideStep = true,
	levelGiftsJson = true,
	serverGiftsJson = true,
	fundJson = true,
	loginDays = true,
	slotsJson = true,
	partnersJson = true,
	skillOrderJson = true,
	canSweep = true,
	bagHeroBuyCount = true,
	activedGuide = true,
	nextResetDailyTime = true,
	yzLevel = true,
	pre1 = true,
	pre2 = true,

	shop1ItemsJson = true,
	shop2ItemsJson = true,
	shop3ItemsJson = true,
	shop4ItemsJson = true,
	shop5ItemsJson = true,
	shop6ItemsJson = true,
	shop7ItemsJson = true,

	firstRechargeJson = true,
	firstRechargeAwardState = true,
	rechargeGiftsJson = true,
	battleSpeed = true,
	enterFlag 	= true,
	silent = true,
	godHeroCount = true,
	legendCardonIdIndex = true,
	renameCount = true,
	specialBattleCnt = true,
}

function Role:costHealth(deltaPoint)
	local origHealth = self:getProperty("health")
	if tonum(origHealth) < tonum(deltaPoint) then return false end

	--如果当前体力超过上限，重新计时
	local healthLimit = self:getHealthLimit()
	if origHealth >= healthLimit and origHealth - deltaPoint < healthLimit then
		self.timestamps:updateProperty({field = "lastHealthTime", newValue = skynet.time()})
	end

	local currentHealth = origHealth - deltaPoint
	self:setProperty("health", currentHealth);

	--通知客户端
	self:notifyUpdateProperty("health", currentHealth, origHealth)

	return true
end

function Role:checkHealthFinalLimit(sendError)
	local healthFinalLimit = globalCsv:getFieldValue("healthFinalLimit")
	local origHealth = self:getProperty("health")
	if origHealth >= healthFinalLimit then
		if sendError then
			self:sendSysErrMsg(SYS_ERR_FINAL_HEALTH_FULL)
		end
		return false
	end
	return true
end

-- 恢复玩家体力
-- @param deltaPoint	体力值
-- @param params 	是否通知客户端
-- @return health
function Role:recoverHealth(deltaPoint, params)
	params = params or {}
	if not self:checkHealthFinalLimit(params.sendError) then return 0 end

	local checkLimit = params.checkLimit == nil and true or params.checkLimit

	local origHealth = self:getProperty("health")
	local currentHealth = origHealth + deltaPoint

	currentHealth = (checkLimit and currentHealth > self:getHealthLimit()) and math.max(self:getHealthLimit(), origHealth) or currentHealth
	local real_recover = currentHealth - origHealth

	self:setProperty("health", currentHealth)
	if params.time then
		self.timestamps:updateProperty({field = "lastHealthTime", newValue = skynet.time()})
	end

	--通知客户端
	if params.notify then 
		self:notifyUpdateProperty("health", currentHealth, origHealth) 
	end

	return real_recover
end

-- 增加玩家经验，需要判断是否升级
function Role:addExp(deltaPoint)
	local csvData = roleInfoCsv:getDataByLevel(self:getProperty("level") + 1)
	if csvData == nil then return end
	
	local oldExp = self:getProperty("exp")
	local nowExp = oldExp + deltaPoint
	while nowExp >= csvData.upLevelExp do
		if not self:upLevel(1) then
			-- 达到满级
			nowExp = csvData.upLevelExp
			break
		else
			nowExp = nowExp - csvData.upLevelExp
		end

		csvData = roleInfoCsv:getDataByLevel(self:getProperty("level") + 1)
	end

	self:setProperty("exp", nowExp)
	-- 通知客户端
	self:notifyUpdateProperty("exp", self:getProperty("exp"), oldExp)
end

-- 提高玩家等级
function Role:upLevel(deltaLevel)
	local origLevel = self:getProperty("level")
	-- 已达到满级
	if origLevel == globalCsv:getFieldValue("levelUpLimit") then
		return false
	end

	self:setProperty("level", origLevel + deltaLevel)
	self:notifyUpdateProperty("level", self:getProperty("level"), origLevel)

	local time = skynet.time()
	local revTime = 3000000000 - time
	local scores = (origLevel + deltaLevel)..'.'..revTime
	redisproxy:zadd("levelRank", tonumber(scores), tostring(self:getProperty("id")))
	redisproxy:zremrangebyrank("levelRank", 0, -101)
	
	local real_val = self:recoverHealth(globalCsv:getFieldValue("healthByUpLevel"), { notify = true })
	if real_val > 0 then
		logger.info("r_in_health", self:logData({
			behavior = "i_hl_lvl_up",
			pm1 = real_val,
			pm2 = origLevel + deltaLevel,
		}))		
	end

	--全服通告
	local curLevel = self:getProperty("level")
	if origLevel < curLevel and worldNoticeCsv:isConditionFit(worldNoticeCsv.level, curLevel) then
		local content = worldNoticeCsv:getDesc(worldNoticeCsv.level, {playerName = self:getProperty("name"), param1 = curLevel})
		sendWorldNotice(content)
	end

	return true
end

-- 通知client, 玩家数据的变动 {}
function Role:notifyUpdateProperty(field, newValue, oldValue)
	local updateData = {
		key = field,
		newValue = newValue and newValue .. "" or "",
		oldValue = oldValue and oldValue .. "" or "",
	}

	local bin = pb.encode("RoleUpdateProperty", updateData)
	SendPacket(actionCodes.RoleUpdateProperty, bin)
end

function Role:notifyUpdateProperties(modify_tab)
	for _, v in pairs(modify_tab) do
		v.newValue = v.newValue and v.newValue .. "" or ""
		v.oldValue = v.oldValue and v.oldValue .. "" or ""
	end
	local bin = pb.encode("RoleUpdateProperties", { tab = modify_tab })
	SendPacket(actionCodes.RoleUpdateProperties, bin)
end

function Role:gainMoney(deltaValue, params)
	params = params or {}
	local deltaValue = deltaValue and deltaValue or tonum(params.num)
	local currentMoney = self:getProperty("money")
	self:setProperty("money", currentMoney + deltaValue, true)

	if not params.notNotifyClient then
		self:notifyUpdateProperty("money", self:getProperty("money"), currentMoney)
	end
end

function Role:spendMoney(deltaValue, params)
	local currentMoney = self:getProperty("money")
	if currentMoney < deltaValue then
		return false
	end

	self:setProperty("money", currentMoney - deltaValue)
	self:notifyUpdateProperty("money", self:getProperty("money"), currentMoney)

	return true
end

function Role:checkMoney(deltaValue)
	local currentMoney = self:getProperty("money")
	if currentMoney < deltaValue then
		return false
	end

	return true
end

-- 获得元宝
function Role:gainYuanbao(deltaValue, params)
	params = params or {}
	local deltaValue = deltaValue and deltaValue or tonum(params.num)

	if deltaValue == 0 then return true end
	local currentYuanbao = self:getProperty("yuanbao")
	self:setProperty("yuanbao", currentYuanbao + deltaValue, true)
	if not params.notNotifyClient then
		self:notifyUpdateProperty("yuanbao", self:getProperty("yuanbao"), currentYuanbao)
	end 
end

-- 更新玩家的当前已用pvp次数
function Role:setPvpCount(pvpCnt)
	self.dailyData:setProperty("pvpCount", pvpCnt)
	self:notifyUpdateProperty("pvpCount", pvpCnt)
end

-- 消费元宝
function Role:spendYuanbao(deltaValue)
	local currentYuanbao = self:getProperty("yuanbao")
	if currentYuanbao < deltaValue then
		return false
	end

	self:setProperty("yuanbao", currentYuanbao - deltaValue)
	self:notifyUpdateProperty("yuanbao", currentYuanbao - deltaValue, currentYuanbao)
	return true
end

function Role:checkYuanbao(deltaValue)
	local currentYuanbao = self:getProperty("yuanbao")
	if currentYuanbao < deltaValue then
		return false
	end

	return true
end

function Role:addFriendValue(deltaValue)
	if deltaValue == 0 then return true end

	local currentValue = self:getProperty("friendValue")
	self:setProperty("friendValue", currentValue + deltaValue)
	self:notifyUpdateProperty("friendValue", currentValue + deltaValue, currentValue)
	return true
end

function Role:addLingpaiNum(deltaValue, params)
	params = params or {}
	if deltaValue == 0 then return true end

	local currentValue = self:getProperty("lingpaiNum")
	self:setProperty("lingpaiNum", currentValue + deltaValue)
	if not params.notNotifyClient then
		self:notifyUpdateProperty("lingpaiNum", currentValue + deltaValue, currentValue)
	end
	return true
end

function Role:addHeroSoulNum(deltaValue, params)
	params = params or {}
	if deltaValue == 0 then return true end

	local currentValue = self:getProperty("heroSoulNum")
	self:setProperty("heroSoulNum", currentValue + deltaValue)
	if not params.notNotifyClient then
		self:notifyUpdateProperty("heroSoulNum", currentValue + deltaValue, currentValue)
	end
	return true
end

function Role:addZhangongNum(deltaValue, params)
	params = params or {}
	if deltaValue == 0 then return true end

	local currentValue = self:getProperty("zhangongNum")
	self:setProperty("zhangongNum", currentValue + deltaValue)
	if not params.notNotifyClient then
		self:notifyUpdateProperty("zhangongNum", currentValue + deltaValue, currentValue)
	end
	return true
end

function Role:addReputation(deltaValue, params)
	params = params or {}
	if deltaValue == 0 then return true end

	local currentValue = self:getProperty("reputation")
	self:setProperty("reputation", currentValue + deltaValue)
	if not params.notNotifyClient then
		self:notifyUpdateProperty("reputation", currentValue + deltaValue, currentValue)
	end
	return true
end

function Role:changeVipLevel(vipLevel)
	local preVipData = vipCsv:getDataByLevel(vipLevel - 1)
	local vipData = vipCsv:getDataByLevel(vipLevel)

	-- 战场次数
	local prePvpCount = self.dailyData:getProperty("pvpCount")
	self.dailyData:updateProperty({ field = "pvpCount", deltaValue = vipData.pvpCount - (preVipData and preVipData.pvpCount or 0) })

	-- 传奇副本次数
	local preLegendBattleLimit = self.dailyData:getProperty("legendBattleLimit")
	self.dailyData:updateProperty({ field = "legendBattleLimit", deltaValue = vipData.legendCount - (preVipData and preVipData.legendCount or 0) })

	local originVipLevel = self:getProperty("vipLevel")
	self:setProperty("vipLevel", vipLevel)
	self:notifyUpdateProperty("vipLevel", vipLevel)

	--全服通告
	if originVipLevel < vipLevel and worldNoticeCsv:isConditionFit(worldNoticeCsv.vip, vipLevel) then
		local content = worldNoticeCsv:getDesc(worldNoticeCsv.vip, {playerName = self:getProperty("name"), param1 = vipLevel})
		sendWorldNotice(content)
	end
	return true
end

function Role:addRechargeRMB(rechargeRMB, yuanbao)
	--更新首充奖品领取状态
	if self:getProperty("firstRechargeAwardState") == 0 then
		self:updataFirstRechargeAwardState(1)
	end

	local currentValue = self:getProperty("rechargeRMB")
	local allRechargeRMB = currentValue + rechargeRMB

	self:setProperty("rechargeRMB", allRechargeRMB)

	self:notifyUpdateProperty("rechargeRMB", allRechargeRMB, currentValue)

	local origVipLevel = self:getProperty("vipLevel")
	local vipLevel = vipCsv:getLevelByCurMoney(allRechargeRMB)

	if origVipLevel ~= vipLevel then
		self:changeVipLevel(vipLevel)
	end

	self:gainYuanbao(yuanbao)

	return allRechargeRMB
end

function Role:addStarSoulNum(deltaValue, params)
	params = params or {}
	if deltaValue == 0 then return true end

	local currentValue = self:getProperty("starSoulNum")
	self:setProperty("starSoulNum", currentValue + deltaValue)
	if not params.notNotifyClient then
		self:notifyUpdateProperty("starSoulNum", currentValue + deltaValue, currentValue)
	end
	return true
end

function Role:setStarPoint(starPoint)
	self:setProperty("starPoint", starPoint)
	self:notifyUpdateProperty("starPoint", starPoint)
	return true
end

--更新首充领奖状态
function Role:updataFirstRechargeAwardState(state)
	self:setProperty("firstRechargeAwardState", state)
	self:notifyUpdateProperty("firstRechargeAwardState", state)
end

function Role:updateProfessionData()
	local jsonValue = json.encode(self.professionBonuses)

	self:setProperty("professionData", jsonValue)
	self:notifyUpdateProperty("professionData", jsonValue)
	return true
end

function Role:updateChooseHeroIds()
	local heroIds = table.keys(self.chooseHeroIds)
	self:setProperty("chooseHeroIds", json.encode(heroIds))
end

-- 武将上限
function Role:getBagHeroLimit()
	return math.huge
end

-- VIP修改的属性
-- 体力上限
function Role:getHealthLimit()
	local roleData = roleInfoCsv:getDataByLevel(self:getProperty("level"))
	local healthLimit = roleData and roleData.healthLimit or 50

	local vipData = vipCsv:getDataByLevel(self:getProperty("vipLevel"))
	if not vipData then return healthLimit end
	return healthLimit + vipData.healthLimit
end

-- 体力购买次数上限
function Role:getHealthBuyCount()
	local vipData = vipCsv:getDataByLevel(self:getProperty("vipLevel"))
	if not vipData then return 0 end

	return vipData.healthBuyCount
end

-- 战场次数上限
function Role:getPvpCountLimit()
	local pvpCount = globalCsv:getFieldValue("pvpCount")

	local vipData = vipCsv:getDataByLevel(self:getProperty("vipLevel"))
	if not vipData then return pvpCount end

	return pvpCount + vipData.pvpCount
end

-- 战场购买次数上限
function Role:getPvpBuyLimit()
	local pvpBuyCount = globalCsv:getFieldValue("pvpBuyLimit")

	local vipData = vipCsv:getDataByLevel(self:getProperty("vipLevel"))
	if not vipData then return pvpBuyCount end

	return pvpBuyCount + vipData.pvpBuyCount
end

-- 传奇副本挑战次数上限
function Role:getLegendBattleLimit()
	local battleCount = globalCsv:getFieldValue("legendBattleLimit")

	local vipData = vipCsv:getDataByLevel(self:getProperty("vipLevel"))
	if not vipData then return battleCount end

	return battleCount + vipData.legendCount
end

-- 传奇副本购买次数上限
function Role:getLegendBuyLimit()
	local buyCount = globalCsv:getFieldValue("legendBuyLimit")

	local vipData = vipCsv:getDataByLevel(self:getProperty("vipLevel"))
	if not vipData then return buyCount end

	return buyCount + vipData.legendBuyCount
end

-- 获取名将下一个副本
function Role:getNextLegendCardonIdIndex()
	local curIndex = self:getProperty("legendCardonIdIndex")
	local nextIndex = (curIndex + 1) > 3 and 1 or (curIndex + 1)
	self:setProperty("legendCardonIdIndex",nextIndex)
end

function Role:getFriendCntLimit()
	local roleData = roleInfoCsv:getDataByLevel(self:getProperty("level"))

	local vipData = vipCsv:getDataByLevel(self:getProperty("vipLevel"))
	if not vipData then return roleData.friendLimit end

	return roleData.friendLimit + vipData.friendCount
end

function Role:updateSlots()
	local slotsJson = json.encode(self.slots)
	
	self:setProperty("slotsJson", slotsJson)
	self:notifyUpdateProperty("slotsJson", slotsJson)
end

function Role:updatePartners()
	local partnersJson = json.encode(self.partners)
	
	self:setProperty("partnersJson", partnersJson)
	self:notifyUpdateProperty("partnersJson", partnersJson)
end

function Role:updateSkillOrder()
	local skillOrderJson = json.encode(self.skillOrder)
	
	self:setProperty("skillOrderJson", skillOrderJson)
	self:notifyUpdateProperty("skillOrderJson", skillOrderJson)
end

function Role:updatePveFormation()
	local pveFormationJson = json.encode(self.pveFormation)
	
	self:setProperty("pveFormationJson", pveFormationJson)
	self:notifyUpdateProperty("pveFormationJson", pveFormationJson)
end

function Role:updateFirstRecharge()
	local firstRechargeJson = json.encode(self.firstRecharge)
	
	self:setProperty("firstRechargeJson", firstRechargeJson)
	self:notifyUpdateProperty("firstRechargeJson", firstRechargeJson)
end

function Role:getStoreDailyCount(id)
	local dailyKey = string.format("storedaily:%d", self:getProperty("id"))
	local todayBuyCount = redisproxy:hget(dailyKey, id)
	if not todayBuyCount then
		return 0
	else
		return tonum(todayBuyCount)
	end	
end

function Role:setSweepCount(sweepCount)
	if self:getProperty("sweepCount") ~= sweepCount then
		self:setProperty("sweepCount", sweepCount)
		self:notifyUpdateProperty("sweepCount", sweepCount)
	end
end

function Role:setCanSweep(canSweep)
	if self:getProperty("canSweep") ~= canSweep then
		self:setProperty("canSweep", canSweep)
		self:notifyUpdateProperty("canSweep", canSweep)
	end
end

function Role:getBattleValue()
	local Hero = require "datamodel.Hero"
	local value = 0
	local roleId = self:getProperty("id")
	for slot, data in pairs(self.slots) do
		if tonum(data.heroId) == 0 then goto continue end
		local hero = self.heros[data.heroId]
		if not hero then
			hero = self:loadHero(data.heroId)
		end
		value = value + hero:getBattleValue(roleId)	
		::continue::
	end
	return value
end

function Role:getBestCombForce()
	local heroforce = {}
	for _, v in pairs(self.heros) do
		table.insert(heroforce, v:getBattleValue(true))
	end
	table.sort(heroforce, function (a, b) return a > b end)
	local sum = 0
	for i = 1, #heroforce do
		if i > 5 then break end
		sum = sum + heroforce[i]
	end
	return sum
end

function Role:addHeroExp(exp)
	for slot, data in pairs(self.slots) do
		local hero = self.heros[data.heroId]
		if hero then
			hero:addExp(exp)
		end
	end
end

function Role:getTowerData()
	if not self.towerData then
		local towerDataKey = string.format("role:%d:towerData", self:getProperty("id"))
		self.towerData = require("datamodel.Tower").new({ key = towerDataKey })
		self.towerData:load()
	end
	return self.towerData
end

local ispm = {pm1 = true, pm2 = true, pm3 = true}
function Role:logData(params)
	params = params or {}
	local data = {}
	if params['d_id'] then
		data.d_id = params['d_id']
		params['d_id'] = nil
	end
	for field, val in pairs(params) do 
		local lfield = "r_"..field
		if self.class.schema[field] and logFields[lfield] then
			local tp, _ = unpack(self.class.schema[field])
			if tp == "number" then val = tonumber(val) end
			data[lfield] = val
		elseif field == "behavior" and logBehaviors[val] then
			data[field] = tonumber(logBehaviors[val])
		elseif ispm[field] then
			data[field] = tonumber(val)
		elseif field == "str1" then
			data[field] = tostring(val)
		end
	end
	-- user common field
	data.u_id = self:getProperty("uid")
	data.p_id = tonumber(string.sub(data.u_id, -2, -1))
	data.r_id = self:getProperty("id")
	data.r_name = self:getProperty("name")
	data.tstamp = tonumber(params['tstamp'] or skynet.time())
	if data.pm1 then
		data.pm2 = data.pm2 or 0
		data.pm3 = data.pm3 or 0
	end
	return data	
end

function Role:addYueka()
	local yuekaDeadline = self.timestamps:getProperty("yuekaDeadline")
	local nowTime = skynet.time()
	local nowDate = os.date("*t", nowTime)
	local yuekaDays = 30
	local secOneDay = 24 * 3600
	--从0点开始算起
	if nowTime >= yuekaDeadline then
		yuekaDeadline = os.time({year = nowDate.year, month = nowDate.month, day = nowDate.day, hour = 0, min = 0, sec = 0}) + (yuekaDays - 1) * secOneDay
	else
		yuekaDeadline = yuekaDeadline + yuekaDays * secOneDay
	end
	self.timestamps:updateProperty({field = "yuekaDeadline", newValue = yuekaDeadline})
end

function Role:pbData()
	return {
		id = self:getProperty("id"),
		name = self:getProperty("name"),
		level = self:getProperty("level"),
		exp = self:getProperty("exp"),
		health = self:getProperty("health"),
		money = self:getProperty("money"),
		yuanbao = self:getProperty("yuanbao"),
		lastLoginTime = self:getProperty("lastLoginTime"),
		pveFormationJson = self:getProperty("pveFormationJson"),
		yzFormationJson = self:getProperty("yzFormationJson"),
		mainHeroId = self:getProperty("mainHeroId"),
		mainHeroType = self.mainHeroType,
		friendValue = self:getProperty("friendValue"),
		heroSoulNum = self:getProperty("heroSoulNum"),
		lingpaiNum = self:getProperty("lingpaiNum"),
		professionData = self:getProperty("professionData"),
		starSoulNum = self:getProperty("starSoulNum"),
		starPoint = self:getProperty("starPoint"),
		rechargeRMB = self:getProperty("rechargeRMB"),
		vipLevel = self:getProperty("vipLevel"),
		sweepCarbonId = self:getProperty("sweepCarbonId"),
		sweepCount = self:getProperty("sweepCount"),
		sweepResult = self:getProperty("sweepResult"),
		guideStep = self:getProperty("guideStep"),
		zhangongNum = self:getProperty("zhangongNum"),
		reputation = self:getProperty("reputation"),
		
		levelGiftsJson = self:getProperty("levelGiftsJson"),
		serverGiftsJson = self:getProperty("serverGiftsJson"),
		fundJson = self:getProperty("fundJson"),
		loginDays = self:getProperty("loginDays"),
		slotsJson = self:getProperty("slotsJson"),
		partnersJson = self:getProperty("partnersJson"),
		skillOrderJson = self:getProperty("skillOrderJson"),
		store2DailyCount = self:getStoreDailyCount(2),
		store3DailyCount = self:getStoreDailyCount(3),
		canSweep = self:getProperty("canSweep"),
		bagHeroBuyCount = self:getProperty("bagHeroBuyCount"),
		activedGuide = self:getProperty("activedGuide"),
		firstRechargeJson = self:getProperty("firstRechargeJson"),
		firstRechargeAwardState = self:getProperty("firstRechargeAwardState"),
		rechargeGiftsJson = self:getProperty("rechargeGiftsJson"),
		battleSpeed = self:getProperty("battleSpeed"),
		legendCardonIdIndex = self:getProperty("legendCardonIdIndex"),
		renameCount = self:getProperty("renameCount"),
	}
end

return Role