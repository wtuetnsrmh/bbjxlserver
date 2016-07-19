local FieldNameMap = {
	["skillDetectInterval"] = { name = "技能检测时间间隔", type = "number"},
	["skillCDTime"] = { name = "技能CD", type = "number" },
	["angryCD"] = { name = "怒气CD", type = "number" },
	["killEnemyAnger"] = { name = "击杀怒气", type = "number" },
	["defenseFactor"] = { name = "防御系数", type = "number" },
	["pauseBattle"] = { name = "暂停战斗", type = "number" },
	["initAngerValue"] = { name = "初始怒气", type = "number" },
	["inheritAnger"] = { name = "继承怒气", type = "number" },
	["k1"] = { name = "k1", type = "number" },
	["k2"] = { name = "k2", type = "number" },
	["k3"] = { name = "k3", type = "number" },

	-- 被动技能相关
	["passiveSkillLevel1"] = { name = "进化等级激活被动技能1", type = "number"},
	["passiveSkillLevel2"] = { name = "进化等级激活被动技能2", type = "number"},
	["passiveSkillLevel3"] = { name = "进化等级激活被动技能3", type = "number"},

	["friendAwardPoint"] = { name = "好友奖励友情值", type = "number" },
	["strangeAwardPoint"] = { name = "路人奖励友情值", type = "number" },
	["friendAssistCdTime"] = { name = "好友助战时间间隔", type = "number" },
	["strangeAssistCdTime"] = { name = "路人助战时间间隔", type = "number" },
	["strangeLevelLowDelta"] = { name = "路人等级差下限", type = "number" },
	["strangeLevelUpDelta"] = { name = "路人等级差上限", type = "number" },
	["levelDeltaChange"] = { name = "等级差范围扩大", type = "number" },

	["refreshLegendLimit"] = { name = "传奇副本免费刷新次数", type = "number" },
	["legendBattleLimit"] = { name = "传奇副本挑战次数", type = "number", },
	["legendBuyLimit"] = { name = "传奇副本购买次数上限", type = "number", },

	-- 武将二级属性范围
	["critFloor"] = { name = "暴击率下限", type = "number" },
	["critCeil"] = { name = "暴击率上限", type = "number" },
	["parryFloor"] = { name = "格挡率下限", type = "number" },
	["parryCeil"] = { name = "格挡率上限", type = "number" },
	["missFloor"] = { name = "闪避率下限", type = "number" },
	["missCeil"] = { name = "闪避率上限", type = "number" },

	["washTechNeedYuanbao"] = { name = "科技洗点消耗元宝数", type = "number" },

	["upSkillLevelMoney"] = { name = "技能升级金币", type = "map" },
	
	["pvpCount"] = { name = "每日战场初始次数", type = "number" },
	["pvpBuyLimit"] = { name = "每日战场初始购买次数上限", type = "number" },
	-- pvp战斗结果奖励
	["pvpWinAwardYanzhiNum"] = { name = "PVP胜利奖励", type = "number" },
	["pvpLostAwardYanzhiNum"] = { name = "PVP失败奖励", type = "number" },

	["beautyHpFactor"]= { name = "美人品德系数", type = "number"},
	["beautyAtkFactor"] = { name = "美人才艺系数", type = "number"},
	["beautyDefFactor"] = { name = "美人美色系数", type = "number"},
	["sweepTime"] = { name = "单次扫荡CD", type = "number"},
	["autoSkillCdTime"] = { name = "自动战斗检测CD", type = "number"},

	["intensifyGoldNum"] = { name = "强化金币经验比值", type = "number"},
	["healthByUpLevel"] = { name = "升级体力回复量", type = "number" },
	["phaseRecoverHp"] = { name = "关卡阶段回复血量", type = "number" },

	["battleMoveFirst"] = { name = "可移动优先", type = "number" },
	["damagedFloor"] = { name = "受击失血下限", type = "number" },
	["battleMaxTime"] = { name = "战斗最大时长", type = "number"},
	["moneyBattleTimes"] = { name = "金钱副本次数", type = "number" },
	["moneyBattleCD"] = { name = "特殊副本CD", type = "number"},
	["expBattleTimes"] = { name = "经验副本次数", type = "number"},
	["moneyOpenDate"] = { name = "金钱副本开放", type = "time"},
	["expOpenDate"] = { name = "经验副本开放", type = "time"},

	["bagHeroBuyLimit"] = { name = "武将包购买次数上限", type = "number"},
	["priceOfHardChallenge"] = { name = "精英购买挑战次数价格", type = "string"},
	["zhaoCaiCrit"] = { name = "招财暴击", type = "string"},

	["levelUpLimit"] = { name = "等级上限", type = "number" },
	["EquipIntensifyCrit"] = { name = "装备强化暴击", type = "string"},

	["store2condition"] = {name = "商店2刷新副本条件", type = "time"},
	["store3condition"] = {name = "商店3刷新副本条件", type = "time"},

	["healthFinalLimit"] = {name = "体力最终上限", type = "number"},

	["limitLevel"] = {name = "出塞等级条件", type = "number"},
	["limitStar"] = {name = "出塞星级条件", type = "number"},

	["moneyPerExp"] = {name = "武将出售经验单价", type = "number"},

	["hpFactor"] = {name = "生命价值", type = "number"},
	["atkFactor"] = {name = "攻击价值", type = "number"},
	["defFactor"] = {name = "防御价值", type = "number"},
	["activeSkillFactor"] = {name = "必杀技实力系数", type = "number"},
	["activeSkillGrowth"] = {name = "必杀技实力成长系数", type = "number"},
	["passiveSkillFactor"] = {name = "被动技实力系数", type = "number"},
	["passiveSkillGrowth"] = {name = "被动技实力成长系数", type = "number"},
	["hitFactor"] = {name = "命中价值", type = "number"},
	["missFactor"] = {name = "闪避价值", type = "number"},
	["ignoreParryFactor"] = {name = "破击价值", type = "number"},
	["critFactor"] = {name = "暴击价值", type = "number"},
	["resistFactor"] = {name = "抵抗价值", type = "number"},

	["healthToExp"] = {name = "体力经验比", type = "number"},

	["starFactor"] = {name = "武将升星实力系数", type = "array"},
	["starUpFragment"] = {name = "武将升星碎片量", type = "array"},
	["fragmentToSoul"] = {name = "武将碎片将魂比", type = "number"},
	["starUpCost"] = {name = "武将升星价格", type = "array"},
	["decomposeFragNum"] = {name = "武将分解碎片量", type = "array"},

	["equipEvolPerCost"] = {name = "装备进化单价", type = "number"},
	["equipEvolFactor"] = {name = "装备进化实力系数", type = "array"},

	["firstRechargeAward"] = {name = "首充奖励", type = "array"},
	
	["fundCost"] = {name = "基金购买", type = "number"},
	["fundLevel"] = {name = "基金购买等级", type = "number"},
	
	["towerOpenBoxPrice"] = {name = "爬塔开箱价格", type = "string"},
	["worldChatLimit"] = {name = "世界聊天次数限制", type = "number"},
	["chatLevelLimit"] = {name = "聊天等级限制", type = "number"},
	["pvpUpEmailId"] = {name = "战场晋升邮件id", type = "number"},
	["godHeroCost"] = {name = "神将价格", type = "number"},
}

local GlobalCsvData = {
	m_data = {},
}

function GlobalCsvData:load(fileName)
	local csvData = CsvLoader.load(fileName)
	self.m_data = {}

	for index = 1, #csvData do
		self.m_data[csvData[index]["name"]] = csvData[index]["value"]
	end
end

-- 返回给定的域的值
-- @param field 	变量名, 对应于FieldNameMap中的key
-- @return 返回该域对应的值
function GlobalCsvData:getFieldValue(field)
	if FieldNameMap[field] == nil then return "" end

	local value = self.m_data[FieldNameMap[field].name]
	if FieldNameMap[field].type == "number" then value = tonum(value) end
	if FieldNameMap[field].type == "time" then value = string.split(tostring(value), "=")end
	if FieldNameMap[field].type  == "array" then value = string.toNumMap(tostring(value), " ") end
	return value
end

function GlobalCsvData:getComposeFragmentNum(star)
	local data = self:getFieldValue("starUpFragment")
	local num = 0
	for index = 1, star do
		num = num + tonum(data[index])
	end
	return num
end

return GlobalCsvData