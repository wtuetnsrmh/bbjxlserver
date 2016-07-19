-- 日常数据

local RoleDaily = class("RoleDaily", require("shared.ModelBase"))

function RoleDaily:ctor(properties)
	RoleDaily.super.ctor(self, properties)
end

RoleDaily.schema = {
    key     			= {"string"},       -- redis key
    legendBattleLimit   = {"number", 0},  -- 传奇副本次数
    refreshLegendLimit  = {"number", globalCsv:getFieldValue("refreshLegendLimit")}, -- 刷新传奇副本次数
    legendBuyCount		= {"number", 0},	-- 传奇副本购买次数
    healthBuyCount 		= {"number", 0},	-- 体力购买次数
    pvpCount 			= {"number", 0},	-- pvp次数
    pvpBuyCount 		= {"number", 0},	-- pvp购买次数
    todayLastLoginTime	= {"number", 0},	-- 今天最后一次登录时间
    moneybuytimes	    = {"number", 0},	-- 今天购买银币次数
    eatChickenCountAM	= {"number", 0},	-- 当日登录礼包是否已经领取
    eatChickenCountPM	= {"number", 0},	-- 当日登录礼包是否已经领取
    moneyBattleCount	= {"number", 0},
    moneyBattleCD   	= {"number", 0},
    expBattleCount	    = {"number", 0},
    expBattleCD   	    = {"number", 0},
    firstLogin 			= {"number", 1},	-- 是否是今天第一次登陆

    -- 每日任务
    commonCarbonCount	= {"number", 0},
    specialCarbonCount	= {"number", 0},
    heroIntensifyCount	= {"number", 0},
    pvpBattleCount		= {"number", 0},
    techLevelUpCount	= {"number", 0},
    beautyTrainCount	= {"number", 0},
    towerBattleCount	= {"number", 0},
    heroStarCount		= {"number", 0},
    legendBattleCount	= {"number", 0},
    zhaoCaiCount 		= {"number", 0},
    yuekaCount 			= {"number", 1},
    drawCardCount 		= {"number", 0},
    trainCarbonCount 	= {"number", 0},
    expeditionCount 	= {"number", 0},

    -- 商城抽卡免费次数
    card1DrawFreeCount	= {"number", 0},
    card3DrawFreeCount	= {"number", 0},

    --扫荡次数
    sweepCount 			= {"number", 0},
    --装备强化次数
    equipIntensifyCount = {"number", 0},

    -- 商店刷新
    shop1RefreshCount	= {"number", 0},
    shop2RefreshCount	= {"number", 0},
    shop3RefreshCount	= {"number", 0},
    shop4RefreshCount	= {"number", 0},
    shop5RefreshCount	= {"number", 0},
    shop6RefreshCount	= {"number", 0},
    shop7RefreshCount	= {"number", 0},

    -- 特殊商店开启
    specialStore2Opened = {"number", 0},
    specialStore3Opened = {"number", 0},

	-- 远征挑战次数
    expeditionResetCount 	= {"number", 0}, 

    --阵营试炼
    qunBattleCount		= {"number", 0},
    qunBattleCD   		= {"number", 0},
    weiBattleCount	    = {"number", 0},
    weiBattleCD   	    = {"number", 0},
    shuBattleCount		= {"number", 0},
    shuBattleCD   		= {"number", 0},
    wuBattleCount	    = {"number", 0},
    wuBattleCD   	    = {"number", 0},
    beautyBattleCount	= {"number", 0},
    beautyBattleCD   	= {"number", 0},

    -- 聊天次数
    worldChatCount		= {"number", 0},
}

RoleDaily.fields = {
 	moneybuytimes	  = true,
	legendBattleLimit = true, 
	refreshLegendLimit = true,
	legendBuyCount = true,
	healthBuyCount = true,
	pvpCount = true,
	pvpBuyCount = true,
	eatChickenCountAM = true,
	eatChickenCountPM = true,
	moneyBattleCount = true,
	moneyBattleCD = true,
	expBattleCount = true,
	expBattleCD = true,
	firstLogin = true,

	-- 每日任务
	commonCarbonCount = true,
	specialCarbonCount = true,
	heroIntensifyCount = true,
	pvpBattleCount = true,
	techLevelUpCount = true,
	beautyTrainCount = true,
	towerBattleCount = true,
	heroStarCount = true,
	legendBattleCount = true,
	zhaoCaiCount = true,
	yuekaCount = true,
	drawCardCount = true,
    trainCarbonCount = true,
    expeditionCount = true,

	-- 商城抽卡
	card1DrawFreeCount = true,
	card3DrawFreeCount = true,

	sweepCount = true,

	equipIntensifyCount = true,

	shop1RefreshCount = true,
	shop2RefreshCount = true,
	shop3RefreshCount = true,
	shop4RefreshCount = true,
	shop5RefreshCount = true,
	shop6RefreshCount = true,
	shop7RefreshCount = true,

	specialStore2Opened = true,
	specialStore3Opened = true,

	expeditionResetCount = true,


    --阵营试炼
    qunBattleCount		= true,
    qunBattleCD   		= true,
    weiBattleCount	    = true,
    weiBattleCD   	    = true,
    shuBattleCount		= true,
    shuBattleCD   		= true,
    wuBattleCount	    = true,
    wuBattleCD   	    = true,
    beautyBattleCount	= true,
    beautyBattleCD   	= true,

    worldChatCount		= true,
}

function RoleDaily:updateProperty(params)
	local deltaValue = params.deltaValue or 1

	self:setProperty(params.field, self:getProperty(params.field) + deltaValue)
	self.owner:notifyUpdateProperty(params.field, self:getProperty(params.field))
end

function RoleDaily:refreshDailyData(owner)
	for field, schema in pairs(self.class.schema) do
		if field ~= "key" then
			local typ, def = unpack(schema)
			self:setProperty(field, def)
		end
	end

	-- 特殊处理
	owner = owner or self.owner
	if owner then
		self:setProperty("legendBattleLimit", owner:getLegendBattleLimit())
		self:setProperty("pvpCount", owner:getPvpCountLimit())
	end
end

function RoleDaily:pbData()
	return {
		{ key = "legendBattleLimit", value = self:getProperty("legendBattleLimit") },
		{ key = "refreshLegendLimit", value = self:getProperty("refreshLegendLimit") }, 
		{ key = "legendBuyCount", value = self:getProperty("legendBuyCount") },
		{ key = "healthBuyCount", value = self:getProperty("healthBuyCount") },
		{ key = "pvpCount", value = self:getProperty("pvpCount") },
		{ key = "pvpBuyCount", value = self:getProperty("pvpBuyCount") },

		{ key = "commonCarbonCount", value = self:getProperty("commonCarbonCount") },
		{ key = "specialCarbonCount", value = self:getProperty("specialCarbonCount") },
		{ key = "heroIntensifyCount", value = self:getProperty("heroIntensifyCount") },
		{ key = "pvpBattleCount", value = self:getProperty("pvpBattleCount") },
		{ key = "techLevelUpCount", value = self:getProperty("techLevelUpCount") },
		{ key = "beautyTrainCount", value = self:getProperty("beautyTrainCount") },
		{ key = "towerBattleCount", value = self:getProperty("towerBattleCount") },
		{ key = "heroStarCount", value = self:getProperty("heroStarCount") },
		{ key = "legendBattleCount", value = self:getProperty("legendBattleCount") },
		{ key = "zhaoCaiCount", value = self:getProperty("zhaoCaiCount") },
		{ key = "yuekaCount", value = self:getProperty("yuekaCount") },
		{ key = "drawCardCount", value = self:getProperty("drawCardCount") },
		{ key = "trainCarbonCount", value = self:getProperty("trainCarbonCount") },
		{ key = "expeditionCount", value = self:getProperty("expeditionCount") },
		
		{ key = "moneybuytimes", value = self:getProperty("moneybuytimes") },
		{ key = "eatChickenCountAM", value = self:getProperty("eatChickenCountAM") },
		{ key = "eatChickenCountPM", value = self:getProperty("eatChickenCountPM") },
		{ key = "moneyBattleCD", value = self:getProperty("moneyBattleCD") },
		{ key = "moneyBattleCount", value = self:getProperty("moneyBattleCount") },
		{ key = "expBattleCD", value = self:getProperty("expBattleCD") },
		{ key = "expBattleCount", value = self:getProperty("expBattleCount") },

		{ key = "card1DrawFreeCount", value = self:getProperty("card1DrawFreeCount") },
		{ key = "card3DrawFreeCount", value = self:getProperty("card3DrawFreeCount") },

		{ key = "sweepCount", value = self:getProperty("sweepCount") },

		{ key = "equipIntensifyCount", value = self:getProperty("equipIntensifyCount") },

		{ key = "shop1RefreshCount", value = self:getProperty("shop1RefreshCount")},
		{ key = "shop2RefreshCount", value = self:getProperty("shop2RefreshCount")},
		{ key = "shop3RefreshCount", value = self:getProperty("shop3RefreshCount")},
		{ key = "shop4RefreshCount", value = self:getProperty("shop4RefreshCount")},
		{ key = "shop5RefreshCount", value = self:getProperty("shop5RefreshCount")},
		{ key = "shop6RefreshCount", value = self:getProperty("shop6RefreshCount")},
		{ key = "shop7RefreshCount", value = self:getProperty("shop7RefreshCount")},

		{ key = "expeditionResetCount", value = self:getProperty("expeditionResetCount")},

		{ key = "qunBattleCount", value = self:getProperty("qunBattleCount")},
		{ key = "qunBattleCD", value = self:getProperty("qunBattleCD")},
		{ key = "weiBattleCount", value = self:getProperty("weiBattleCount")},
		{ key = "weiBattleCD", value = self:getProperty("weiBattleCD")},
		{ key = "shuBattleCount", value = self:getProperty("shuBattleCount")},
		{ key = "shuBattleCD", value = self:getProperty("shuBattleCD")},
		{ key = "wuBattleCount", value = self:getProperty("wuBattleCount")},
		{ key = "wuBattleCD", value = self:getProperty("wuBattleCD")},
		{ key = "beautyBattleCount", value = self:getProperty("beautyBattleCount")},
		{ key = "beautyBattleCD", value = self:getProperty("beautyBattleCD")},

		{ key = "worldChatCount", value = self:getProperty("worldChatCount")},
	}
end

return RoleDaily