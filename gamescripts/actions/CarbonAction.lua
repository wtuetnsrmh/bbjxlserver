local cjson = require "cjson"

local CarbonAction = {}

--特殊商店开启
local function openSpecialStore(role, carbonId)
	local vipInfo = vipCsv:getDataByLevel(role:getProperty("vipLevel"))
	for i = vipInfo.storeLevel+1, 3 do
		local openCondition = globalCsv:getFieldValue(string.format("store%dcondition", i))
		local timeKey = string.format("specialStore%dEndTime", i)
		local dailyKey = string.format("specialStore%dOpened", i)
		local nowTime = skynet.time()
		if role.timestamps:getProperty(timeKey) <= nowTime
		and role.dailyData:getProperty(dailyKey) == 0
		and role:getProperty("level") >= tonum(openCondition[1]) 
		and math.random(1, 10000) <= tonum(openCondition[2]) then
			role.timestamps:updateProperty({field = timeKey, newValue = nowTime + 3600})
			role.dailyData:setProperty(dailyKey, 1)
		end
	end
end

function CarbonAction.killBossRequest(agent, data)
	local msg = pb.decode("BattleEndResult", data)

	local role = agent.role

	if not role then return end

	if role:getProperty("enterFlag") ~= msg.carbonId then return end

	local carbon = role.carbons[msg.carbonId]
	if carbon == nil then return end

	local carbonData = mapBattleCsv:getCarbonById(msg.carbonId)
	if not carbonData then return end

	local dropItems = {}
	-- 掉落
	if carbon:getProperty("starNum") == 0 and table.nums(carbonData.firstPassAward) > 0 then
		for itemId, itemNum in pairs(carbonData.firstPassAward) do
			local itemInfo = itemCsv:getItemById(tonumber(itemId))
			table.insert(dropItems, { itemTypeId = itemInfo.type, itemId = itemInfo.itemId, num = tonumber(itemNum), })
		end
		dropItems = itemCsv:mergeItems(dropItems)
	else
		local dropItemFactory = require("logical.DropItemFactory")

		local specialBattleCnt
		if carbonData.type == 2 then
			specialBattleCnt = tonumber(role:getProperty("specialBattleCnt"))
		end

		local specialDropItems = dropItemFactory.specialDrop(msg.carbonId, specialBattleCnt)

		for _, item in ipairs(specialDropItems) do
			table.insert(dropItems, item)
		end
		dropItems = itemCsv:mergeItems(dropItems)
	end	

	local key = "TempCache:CarbonAward:"..role:getProperty("id")

	redisproxy:set(key, cjson.encode({carbonId = msg.carbonId, itemInfo = dropItems}))

	local killResult = { roleId = role:getProperty("id"), 
		carbonId = msg.carbonId, dropItems = dropItems }

	local bin = pb.encode("BattleEndResult", killResult)
	SendPacket(actionCodes.CarbonKillBossResponse, bin)

	local logdata = role:logData({
		behavior = "carbon_info",
		pm1 = msg.carbonId,
		pm2 = 1,
	})
	logger.info("r_carbon", logdata)
end

function CarbonAction.endGameRequest(agent, data)
	local msg = pb.decode("BattleEndResult", data)

	local role = agent.role

	if role:getProperty("enterFlag") ~= msg.carbonId then return end
	role:setProperty("enterFlag", 0)

	local carbon = role.carbons[msg.carbonId]
	if not carbon then return end

	local carbonData = mapBattleCsv:getCarbonById(msg.carbonId)
	if not carbonData then return end

	local key = "TempCache:CarbonAward:"..role:getProperty("id")
	
	local dropInfo = redisproxy:get(key)

	-- 是否缓存boss掉落
	if not dropInfo then return end

	dropInfo = cjson.decode(dropInfo)

	-- 副本id是否一致
	if msg.carbonId ~= dropInfo.carbonId then return end

	-- 将掉落缓存清空，避免重复领取
	redisproxy:del(key)

	-- 计算经验金钱
	local gainMoney, exp, heroExp = 0, 0, 0
	local dropItems = {}
	if msg.starNum > 0 then
		gainMoney = math.ceil(carbonData.passMoney * tonumber(carbonData.starMoneyBonus[tostring(msg.starNum)]) / 100)
		exp = (carbonData.consumeType == 1 and carbonData.consumeValue or 0) * globalCsv:getFieldValue("healthToExp")
		heroExp = math.ceil(carbonData.passExp * tonumber(carbonData.starExpBonus[tostring(msg.starNum)]) / 100)

		if carbonData.type == 2 then
			local specialBattleCnt = role:getProperty("specialBattleCnt")
			role:setProperty("specialBattleCnt", specialBattleCnt + 1)
		end
		
		if 0 == carbon:getProperty("starNum") then
			-- 首次击杀
			local time = skynet.time()
			local revTime = 3000000000 - time
			local score = msg.carbonId..'.'..revTime
			local rankNames = {
				[1] = "normalRank", [2] = "challengeRank", [3] = "hardRank",
			}
			redisproxy:zadd(rankNames[carbonData.type], tonumber(score), tostring(role:getProperty("id")))
			redisproxy:zremrangebyrank(rankNames[carbonData.type], 0, -101)
		end
		dropItems = dropInfo.itemInfo
	end

	for key, value in ipairs(dropItems) do
		-- 对类型为1的随机碎片箱做特殊处理
		local itemInfo = itemCsv:getItemById(tonum(value.itemId))
		if value.itemTypeId == ItemTypeId.Gift then
			local items = role:getGiftDrops(itemInfo.giftDropIds)
			for _, item in pairs(items) do
				item.itemId = item.itemId + 2000
			end
			dropItems[key] = nil
			table.insertTo(dropItems, items)
		else
			role:awardItemCsv(value.itemId, value)
			log_util.log_fb_drop(role, value.itemId, value.num, msg.carbonId)
		end
	end

	-- 战斗结束
	local endGameResponse = {
		roleId = msg.roleId,
		carbonId = msg.carbonId,
		starNum = msg.starNum,
		exp = heroExp,
		money = gainMoney,
		dropItems = dropItems,
		origExp = role:getProperty("exp"),
		origLevel = role:getProperty("level"),
	}

	-- 打开新的副本或者地图
	if msg.starNum <= 0 then
		-- 增加玩家经验和金钱
		role:addExp(exp)
		role:gainMoney(gainMoney)
		local bin = pb.encode("BattleEndResult", endGameResponse)
		SendPacket(actionCodes.CarbonEndGameResponse, bin)
		return 
	end

	--扣除体力 @remark必须在addExp前
	if carbonData.consumeType == 1 then
		role:costHealth(carbonData.consumeValue or 0, true)

		logger.info("r_out_health", role:logData({
			behavior = "o_hl_carbon",
			pm1 = tonumber(carbonData.consumeValue),
			pm2 = msg.carbonId,
		}))	
	end

	-- 增加玩家经验和金钱
	role:addExp(exp)
	role:gainMoney(gainMoney)	
	-- 增加英雄经验
	role:addHeroExp(heroExp)

	--次数增加
	local playCnt = carbon:getProperty("playCnt")
	carbon:setProperty("playCnt", playCnt + 1)
	carbon:setProperty("lastPlayTime", skynet.time())

	--开启特殊商店
	openSpecialStore(role, msg.carbonId)

	--全服通告
	if carbon:getProperty("starNum") == 0 and worldNoticeCsv:isConditionFit(worldNoticeCsv.carbon, msg.carbonId) then
		local typeNames = {"普通", "精英"}
		local carbonType = typeNames[carbonData.type]
		local mapInfo = mapInfoCsv:getMapById(math.floor(msg.carbonId / 100))
		local mapName = mapInfo.name
		local content = worldNoticeCsv:getDesc(worldNoticeCsv.carbon, {playerName = role:getProperty("name"), param1 = carbonType, param2 = mapName})
		sendWorldNotice(content)
	end

	if msg.starNum > carbon:getProperty("starNum") then
		carbon:setProperty("starNum", msg.starNum)
	end	
	carbon:setProperty("status", 1)
	
	local function addNewCarbon(carbon, mapInfo, carbonResponse)
		local data = { carbonId = carbon.carbonId, status = 0, starNum = 0}
		role:addCarbon(data)

		-- 同一类型
		local newMapInfo = mapInfoCsv:getMapById(math.floor(carbon.carbonId / 100))
		if mapInfo.type == newMapInfo.type then
			endGameResponse.openNewCarbon = carbon.carbonId
		end

		if mapInfo.mapId ~= newMapInfo.mapId then
			table.insert(carbonResponse.maps, role.maps[newMapInfo.mapId]:pbData())
		end
		table.insert(carbonResponse.carbons, role.carbons[carbon.carbonId]:pbData())
	end

	local function openNextCarbon(carbonId)
		local suffixCarbons = mapBattleCsv:getCarbonByPrev(carbonId)
		local carbonResponse = { carbons = {}, maps = {} }
		local mapInfo = mapInfoCsv:getMapById(math.floor(carbonId / 100))

		if mapInfo.type ~= 3 and (#suffixCarbons == 0 or math.floor(suffixCarbons[1].carbonId/100) ~= math.floor(carbonId / 100)) then
			--普通副本通关，需要开启对应的精英副本
			local challengeMapId = math.floor(carbonId / 100) + 100 - 1
			if role.mapCarbons[challengeMapId] then
				local carbonIds = table.keys(role.mapCarbons[challengeMapId])
				table.sort(carbonIds)
				local lastCarbonId = carbonIds[#carbonIds]
				local nextCarbons = mapBattleCsv:getCarbonByPrev(lastCarbonId)
				if #nextCarbons > 0 and math.floor(nextCarbons[1].carbonId/100) ~= math.floor(lastCarbonId/100) and role.carbons[lastCarbonId]:getProperty("starNum") > 0 then
					carbonResponse = openNextCarbon(lastCarbonId)
				end
			end
		end

		for index, carbon in ipairs(suffixCarbons) do
			if not role.carbons[carbon.carbonId] then
				local newMapId = math.floor(carbon.carbonId / 100)
				--精英副本需要判断下对应的普通副本是否已通关
				if newMapId ~= mapInfo.mapId and mapInfo.type ~= 1 then
					local nomarlMapId = newMapId - 100
					if role.mapCarbons[nomarlMapId] then
						local carbonIds = table.keys(role.mapCarbons[nomarlMapId])
						table.sort(carbonIds)
						local lastCarbonId = carbonIds[#carbonIds]
						local nextCarbons = mapBattleCsv:getCarbonByPrev(lastCarbonId)
						if role.carbons[lastCarbonId]:getProperty("starNum") > 0 and not (#nextCarbons > 0 and math.floor(nextCarbons[1].carbonId/100) == math.floor(lastCarbonId/100)) then
							addNewCarbon(carbon, mapInfo, carbonResponse)
						end
					end	
				else
					addNewCarbon(carbon, mapInfo, carbonResponse)
				end
			end
		end
		return carbonResponse
	end

	local carbonResponse = openNextCarbon(msg.carbonId)

	table.insert(carbonResponse.carbons, carbon:pbData())

	-- 更新每日任务
	local mapInfo = mapInfoCsv:getMapById(math.floor(msg.carbonId / 100))
	local mapTaskField = { [1] = DailyTaskIdMap.CommonCarbon, [2] = DailyTaskIdMap.SpecialCarbon, }
	role:updateDailyTask(mapTaskField[mapInfo.type])

	local bin = pb.encode("CarbonResponse", carbonResponse)
	SendPacket(actionCodes.CarbonLoadDataSet, bin)

	local bin = pb.encode("BattleEndResult", endGameResponse)
	SendPacket(actionCodes.CarbonEndGameResponse, bin)

	--更新新手引导
	local guideCsvData = guideCsv:getCarbonUpdateGuide(msg.carbonId)
	if tonum(endGameResponse.openNewCarbon) ~= 0 and guideCsvData then
		role:setProperty("guideStep", guideCsvData.updateStep)
	end

	local logdata = role:logData({
		behavior = "carbon_info",
		pm1 = msg.carbonId,
		pm2 = 2,
	})
	logger.info("r_carbon", logdata)
end

function CarbonAction.refreshLegendCarbon(agent, data)
	-- local msg = pb.decode("SimpleEvent", data)

	-- local role = agent.role

	-- local refreshLegendCnt = role.dailyData:getProperty("refreshLegendLimit")
	-- if refreshLegendCnt <= 0 then
	-- 	-- 花元宝
	-- 	local costYuanbao = functionCostCsv:getCostValue("legendRefreshCnt", math.abs(refreshLegendCnt))

	-- 	if not role:spendYuanbao(costYuanbao) then
	-- 		role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
	-- 		return	-- 元宝不够
	--  	end
	--  	local logdata = role:logData({
	--  		behavior = "o_yb_legend_fresh",
	--  		vipLevel = role:getProperty("vipLevel"),
	--  		pm1 = costYuanbao,
	--  		pm2 = 0,
	--  		pm3 = 0,
	--  	})
	--  	logger.info("r_out_yuanbao", logdata)
	-- end
	-- role.dailyData:updateProperty({ field = "refreshLegendLimit", deltaValue = -1 })

	-- local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
	-- SendPacket(actionCodes.LegendRefreshResponse, bin)
end

function CarbonAction.addLegendBattleCnt(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	-- 购买次数
	local legendBattleBuyCnt = role.dailyData:getProperty("legendBuyCount")
	if legendBattleBuyCnt >= role:getLegendBuyLimit() then
		role:sendSysErrMsg(SYS_ERR_LEGEND_BATTLE_BUY_LIMIT)
		return
	end

	local costYuanbao = functionCostCsv:getCostValue("legendBattleCnt", role.dailyData:getProperty("legendBuyCount"))

	if not role:spendYuanbao(costYuanbao) then
		role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
		return
	end
	local logdata = role:logData({
		behavior = "o_yb_legend_add",
		vipLevel = role:getProperty("vipLevel"),
		pm1 = 10,
		pm2 = 0,
		pm3 = 0,
	})
	logger.info("r_out_yuanbao", logdata)

	role.dailyData:updateProperty({field = "legendBuyCount", deltaValue = 1})

	-- 剩余挑战次数
	role.dailyData:updateProperty({field = "legendBattleLimit", deltaValue = 1})
end

function CarbonAction.legendEnterRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local legendBattleLimit = role.dailyData:getProperty("legendBattleLimit")
	if legendBattleLimit <= 0 then
		role:sendSysErrMsg(SYS_ERR_LEGEND_BATTLE_LIMIT)
		return
	end

	role:setProperty("enterFlag", 1)	
	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId, param1 = msg.param1, param2 = msg.param2 })
	SendPacket(actionCodes.LegendBattleEnterResponse, bin)
	
end

function CarbonAction.legendEndGameRequest(agent, data)
	local msg = pb.decode("BattleEndResult", data)

	local role = agent.role
	if role:getProperty("enterFlag") ~= 1 then return end
	role:setProperty("enterFlag", 0)

	local carbonData = legendBattleCsv:getCarbonById(msg.carbonId)
	if not carbonData then return end

	local dropItems = {}
	local gainMoney = 0
	if msg.starNum > 0 then
		for _, fragmentData in ipairs(carbonData.fragmentIds) do
			local fragmentId, probability = tonumber(fragmentData[1]), tonumber(fragmentData[2])

			if randomFloat(0, 100.0) <= probability then
				table.insert(dropItems, 
					{ itemTypeId = ItemTypeId.HeroFragment, itemId = fragmentId, num = tonum(msg.diffIndex) })
				-- 增加到玩家数据
				local fragmentsKey = string.format("role:%d:fragments", msg.roleId)
				redisproxy:hincrby(fragmentsKey, fragmentId, 1)
				role.fragments[fragmentId] = tonumber(redisproxy:hget(fragmentsKey, fragmentId))
			end
		end

		gainMoney = carbonData.money + role:getProperty("level") * msg.starNum
		role:gainMoney(gainMoney)

		--扣次数
		role.dailyData:updateProperty({field = "legendBattleLimit", deltaValue = - 1})
	end

	
	
	logger.info("r_legend", role:logData())

	-- 相同的累积
	local tempArray = {}
	for _, data in ipairs(dropItems) do
		tempArray[data.itemId] = tonum(tempArray[data.itemId]) + data.num
	end

	dropItems = {}
	for itemId, num in pairs(tempArray) do
		table.insert(dropItems, { itemTypeId = ItemTypeId.HeroFragment, itemId = itemId, num = num })
		logger.info("r_in_fragment", role:logData({
			behavior = "i_fg_lg_drop",
			pm1 = num,
			pm2 = itemId,
			pm3 = 0,
		}))
	end

	role:updateDailyTask(DailyTaskIdMap.LegendBattle)

	-- 战斗结束
	local endGameResponse = {
		roleId = msg.roleId, carbonId = msg.carbonId,
		starNum = msg.starNum, dropItems = dropItems,
		money = gainMoney,
	}

	local bin = pb.encode("BattleEndResult", endGameResponse)
	SendPacket(actionCodes.LegendBattleEndResponse, bin)
end

function CarbonAction.actDataRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	local actCarbonData = { towerData = {} }
	-- 刷塔数据
	local towerDataKey = string.format("role:%d:towerData", msg.roleId)
	local existTower = redisproxy:exists(towerDataKey)

	local firstActMap = mapInfoCsv:getMapById(401)
	-- if not existTower and firstActMap.openLevel <= role:getProperty("level") then
	if not existTower then
		role.towerData = require("datamodel.Tower").new({ key = towerDataKey })
		role.towerData:create()

		actCarbonData.towerData = { count = 3 }
	else
		if not role.towerData then
			role.towerData = require("datamodel.Tower").new({ key = towerDataKey })
			role.towerData:load()
		end

		-- 数据过期
		if skynet.time() >= role:getProperty("nextResetDailyTime") then
			role.towerData:reset()
		end
		actCarbonData.towerData = { count = role.towerData:getProperty("count") }
	end

	local bin = pb.encode("ActCarbonDataResponse", actCarbonData)
	SendPacket(actionCodes.CarbonActDataResponse, bin)
end

function CarbonAction.towerDataRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	-- 数据库肯定有了记录
	local towerDataKey = string.format("role:%d:towerData", role:getProperty("id"))

	local existTower = redisproxy:exists(towerDataKey)
	if not existTower then
		role.towerData = require("datamodel.Tower").new({ key = towerDataKey })
		role.towerData:create()
	elseif not role.towerData then
		role.towerData = require("datamodel.Tower").new({ key = towerDataKey })
		role.towerData:load()
	end

	role.towerData:setProperty("lastPlayTime", skynet.time())

	local bin = pb.encode("TowerData", role.towerData:pbData())
	SendPacket(actionCodes.TowerDataResponse, bin)
end

function CarbonAction.towerBattleBegin(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role
	if role.towerData:getProperty("count") <= 0 then
		role:sendSysErrMsg(SYS_ERR_TOWER_PLAY_COUNT_LIMIT)
		return
	end
	
	role:setProperty("enterFlag", 1)	
	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
	SendPacket(actionCodes.TowerBattleBegin, bin)
end

function CarbonAction.towerBattleEnd(agent, data)
	local msg = pb.decode("TowerEndData", data)

	local role = agent.role
	if role:getProperty("enterFlag") ~= 1 then return end
	role:setProperty("enterFlag", 0)

	local towerData = role:getTowerData()

	local towerDiffData = towerDiffCsv:getDiffData(msg.difficult)
	local winStarNum = msg.starNum * towerDiffData.starModify

	-- 如果胜利, 开启下一关(40101---40200)
	local carbonNum = msg.carbonId % 100
	local curTimestamp = skynet.time()

	-- 如果该关卡已经打过，不可能重新打过
	if msg.carbonId ~= towerData:getProperty("carbonId") then return end

	if msg.starNum > 0 then
		-- 增加星魂数目
		local towerBattleData = towerBattleCsv:getCarbonData(msg.carbonId)
		role:addStarSoulNum(towerBattleData.starSoulNum)
		logger.info("r_in_starsoul", role:logData({
			behavior = "i_ss_tower",
			pm1 = towerBattleData.starSoulNum,
			pm2 = msg.difficult,
			pm3 = carbonNum,
		}))
		-- 表示已经通关
		if carbonNum == 0 then
			towerData:setProperty("count", 0)
			towerData:setProperty("lastPlayTime", curTimestamp)
		else
			-- 开启下一副本
			local totalStarNum = towerData:getProperty("totalStarNum") + winStarNum
			local maxTotalStarNum = towerData:getProperty("maxTotalStarNum") < totalStarNum and totalStarNum or towerData:getProperty("maxTotalStarNum")
			-- 积累星星

			towerData:setProperty("carbonId", msg.carbonId + 1)
			towerData:setProperty("curStarNum", towerData:getProperty("curStarNum") + winStarNum)
			towerData:setProperty("totalStarNum", totalStarNum)
			towerData:setProperty("maxTotalStarNum", maxTotalStarNum)
		end

		-- 加入排行榜
		-- 当key不存在，或member不是key的成员时，
		-- ZINCRBY key increment member等同于ZADD key increment member。
		redisproxy:zincrby("towerrank", 1000 + winStarNum, tostring(msg.roleId))
		logger.info("r_tower", role:logData({
			pm1 = msg.carbonId + 1,
		}))
	else
		towerData:setProperty("count", towerData:getProperty("count") - 1)
		towerData:setProperty("lastPlayTime", curTimestamp)
	end

	role:updateDailyTask(DailyTaskIdMap.TowerBattle)

	local bin = pb.encode("TowerData", towerData:pbData())
	SendPacket(actionCodes.TowerDataResponse, bin)
end

-- 开宝箱请求
function CarbonAction.towerOpenAwardRequest(agent,data)
	local msg = pb.decode("TowerAwardData", data)
	local clientOpenNum = msg.towerData.opendBoxNum

	local role = agent.role
	local towerData = role:getTowerData()
	local opendBoxNum = towerData:getProperty("opendBoxNum")

	local errCode = 0
	if clientOpenNum ~= opendBoxNum then
		errCode = SYS_ERR_TOWER_ERR
	end

	local rediskey = string.format("TempCache:TowerAward:%d", role:getProperty("id"))
	local awardArr = json.decode(redisproxy:get(rediskey) or '[]')
	for _, itemData in pairs(msg.awardItems) do
		if not awardArr[tostring(itemData.itemId)] or awardArr[tostring(itemData.itemId)] ~= tonum(itemData.num) then
			errCode = SYS_ERR_TOWER_ERR
			break
		end
	end

	local drawAward = function ()
		for _, itemData in pairs(msg.awardItems) do
			role:awardItemCsv(tonum(itemData.itemId), { num = tonum(itemData.num) })
			awardArr[tostring(itemData.itemId)] = 0
			log_util.log_tower_award(role, tonum(itemData.itemId), tonum(itemData.num))		
		end
		redisproxy:set(rediskey, json.encode(awardArr))
		towerData:setProperty("opendBoxNum", towerData:getProperty("opendBoxNum") + 1)
	end

	local openPriceDic = string.tomap(globalCsv:getFieldValue("towerOpenBoxPrice"))
	if errCode == 0 then
		if opendBoxNum > 0 then

			local price = tonum(openPriceDic[tostring(opendBoxNum+1)])

			if not role:spendYuanbao(price) then
				errCode = SYS_ERR_YUANBAO_NOT_ENOUGH
			else
				logger.info("r_out_yuanbao", role:logData({
					behavior = "o_yb_tower_box",
					vipLevel = role:getProperty("vipLevel"),
					pm1 = price,
					pm2 = opendBoxNum + 1,
				}))
				drawAward()
			end
		else
			drawAward()
		end
	end

	local bin =  pb.encode("SimpleEvent", { param1 = errCode, param2 = towerData:getProperty("opendBoxNum") })
	SendPacket(actionCodes.TowerOpenAwardResponse, bin)

end

function CarbonAction.towerAwardGotRequest(agent, data)
	local msg = pb.decode("TowerEndData", data)

	local role = agent.role

	local towerData = role:getTowerData()
	if towerData:getProperty("awardCarbonId") == msg.carbonId then
		return
	end

	towerData:setProperty("awardCarbonId", msg.carbonId)

	local totalStarNum = towerData:getProperty("totalStarNum")
	local preTotalStarNum = towerData:getProperty("preTotalStarNum")

	local towerBattleData = towerBattleCsv:getCarbonData(msg.carbonId)
	local addMoneyValue = (totalStarNum - preTotalStarNum) * towerBattleData.moneyStarUnit
	local addYuanbaoValue = (towerBattleData.yuanbaoAward and towerBattleData.yuanbaoAwardStarNeed <= (totalStarNum - preTotalStarNum)) and towerBattleData.yuanbaoNum or 0

	role:gainMoney(addMoneyValue)
	role:gainYuanbao(addYuanbaoValue)
	logger.info("r_in_yuanbao", role:logData({
		behavior = "i_yb_tower",
		pm1 = addYuanbaoValue,
		pm2 = msg.carbonId,
		str1 = "0",
	}))
	
	towerData:setProperty("preTotalStarNum", totalStarNum)

	-- 重置开宝箱次数
	role.towerData:setProperty("opendBoxNum", 0)

	local towerAwardData = { towerData = {} }
	towerAwardData.towerData = role.towerData:pbData()
	local awardArr = {}
	towerAwardData.awardItems, awardArr = towerBattleCsv:getCarbonAwardData(msg.carbonId)
	local rediskey = string.format("TempCache:TowerAward:%d", role:getProperty("id"))
	redisproxy:set(rediskey, json.encode(awardArr))

	local bin = pb.encode("TowerAwardData", towerAwardData)
	SendPacket(actionCodes.TowerAwardGotResponse, bin)
end

function CarbonAction.towerAttrModifyRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	
	local towerData = role:getTowerData()

	if towerData:getProperty("modifyCarbonId") == msg.param3 then
		return
	end

	towerData:setProperty("modifyCarbonId", msg.param3)

	local attrNames = { [1] = "hp", [2] = "atk", [3] = "def" }
	local towerAttrModifyData = towerAttrCsv:getAttrModifyById(msg.param1)
	local newModifyValue = towerData:getProperty(attrNames[msg.param2] .. "Modify") + towerAttrModifyData[attrNames[msg.param2] .. "Modify"]
	local curStarNum = towerData:getProperty("curStarNum") - towerAttrModifyData[attrNames[msg.param2] .. "Star"]

	towerData:setProperty(attrNames[msg.param2] .. "Modify", newModifyValue)
	towerData:setProperty("curStarNum", curStarNum)

	local newTowerData = {}
	newTowerData[attrNames[msg.param2] .. "Modify"] = newModifyValue
	newTowerData.curStarNum = curStarNum

	local bin = pb.encode("TowerData", newTowerData)
	SendPacket(actionCodes.TowerAttrModifyResponse, bin)
end

function CarbonAction.towerRankRequest(agent, data)
	local towerRankData	= { rankDatas = {} }

	local rankScore = {}
	local redisResult = redisproxy:zrevrange("towerrank", 0, 49, "withscores")
    for i = 1, #redisResult, 2 do
    	table.insert(rankScore, { redisResult[i], tonumber(redisResult[i + 1])})
    	rankScore[redisResult[i]] = redisResult[i + 1] 
    end

	for index, data in ipairs(rankScore) do
		local roleId = tonumber(data[1])
		local carbonNum = math.floor(tonumber(data[2]) / 1000)
		local totalStarNum = tonumber(data[2]) % 1000

		local roleDbData = redisproxy:runScripts("loadRoleInfo", 1, roleId)
		local startIndex, interval = 7, 6
		local mainHeroType, mainHeroWakeLevel, mainHeroStar, mainHeroEvolutionCount
		for rindex = startIndex, startIndex+interval*5-1, interval do
			if not roleDbData[rindex] then break end

			if tonumber(roleDbData[rindex]) == tonumber(roleDbData[4]) then
				mainHeroType = tonum(roleDbData[rindex + 1])
				mainHeroWakeLevel = tonum(roleDbData[rindex + 3])
				mainHeroStar = tonum(roleDbData[rindex + 5])
				mainHeroEvolutionCount = tonum(roleDbData[rindex + 2])
				break
			end
		end

		table.insert(towerRankData.rankDatas, {
			roleId = roleId,
			name = roleDbData[1],
			level = tonum(roleDbData[2]),
			mainHeroType = mainHeroType,
			mainHeroWakeLevel = mainHeroWakeLevel,
			mainHeroStar = mainHeroStar,
			mainHeroEvolutionCount = mainHeroEvolutionCount,
			carbonNum = carbonNum,
			totalStarNum = totalStarNum,
			index = index,
		})
	end

	local bin = pb.encode("TowerRankData", towerRankData)
	SendPacket(actionCodes.TowerRankResponse, bin)
end

function CarbonAction.updateTowerData(agent, data)
	local msg = pb.decode("TowerData", data)

	local role = agent.role

	-- 数据库肯定有了记录
	local towerDataKey = string.format("role:%d:towerData", msg.roleId)
	if not role.towerData then
		role.towerData = require("datamodel.Tower").new({ key = towerDataKey })
		role.towerData:load()
	end

	local towerPbFields = { "count", "carbonId", "totalStarNum", "preTotalStarNum", 
		"maxTotalStarNum", "curStarNum", "hpModify", "atkModify", "defModify", "sceneId1",
		"sceneId2", "sceneId3", }
	for index, field in ipairs(towerPbFields) do
		role.towerData:setProperty(field, msg[field])
	end
end

function CarbonAction.chooseAssist(agent, data)
	local msg = pb.decode("AssistChooseAction", data)

	local role = agent.role

	local carbon = role.carbons[msg.carbonId]
	-- 尝试从数据库加载
	if carbon == nil then
		carbon = role:loadCarbon(msg.carbonId)
		if not carbon then
			role:sendSysErrMsg(SYS_ERR_CARBON_NOT_EXIST)
			return
		end
	end

	local lastPlayTime = carbon:getProperty("lastPlayTime")
	if lastPlayTime ~= 0 and skynet.time() < lastPlayTime + 5 then
		role:sendSysErrMsg(SYS_ERR_CLIENT_OPERATION)	
		return
	end

	local carbonData = mapBattleCsv:getCarbonById(msg.carbonId)
	if not carbonData then return end

	local result = 0

	-- 检查疲劳值
	local needHealth = carbonData.consumeType == 1 and carbonData.consumeValue or 0
	if role:getProperty("health") < needHealth then
		role:sendSysErrMsg(SYS_ERR_HEALTH_NOT_ENOUGH)
		return
	end

	local result = 0
	-- 检查挑战次数限制
	local playCnt = carbon:getProperty("playCnt")
	local lastPlayTime = carbon:getProperty("lastPlayTime", skynet.time())

	if isToday(lastPlayTime) then
		local originCount = carbon:getProperty("playCnt")
		if originCount >= carbonData.playCount then
			role:sendSysErrMsg(SYS_ERR_CARBON_PLAY_COUNT_LIMIT)
			return
		end
		
	else
		carbon:setProperty("playCnt", 0)
	end

	role:setProperty("enterFlag", msg.carbonId)

	local chooseAssistResponse = {
		roleId = msg.roleId,
		carbonId = msg.carbonId,
	}

	local bin = pb.encode("CarbonEnterAction", chooseAssistResponse)
	SendPacket(actionCodes.CarbonAssistChooseResponse, bin)	
end

-- 扫荡
function CarbonAction.sweepRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local carbonId = msg.param1
	local sweepCount = msg.param2

	local carbonData = mapBattleCsv:getCarbonById(carbonId)
	if not carbonData then return end

	local carbon = role.carbons[carbonId]

	local vipInfo = vipCsv:getDataByLevel(role:getProperty("vipLevel"))
	-- 扫荡剩余次数不够
	if vipInfo.sweepCount ~= 0 and vipInfo.sweepCount < role.dailyData:getProperty("sweepCount") + sweepCount then
		role:sendSysErrMsg(SYS_ERR_CARBON_SWEEP_COUNT_NOT_ENOUGH)
		return	
	end

	-- 不能多次扫荡
	if carbonData.type ~= 3 and vipInfo.multiSweep == 0 and sweepCount > 1 then
		return
	end

	local starNum = carbon:getProperty("starNum")
	if starNum < 3 then return end

	-- 检查挑战次数限制
	local lastPlayTime = carbon:getProperty("lastPlayTime", skynet.time())

	carbon:setProperty("lastPlayTime", skynet.time())
	if not isToday(lastPlayTime) then
		carbon:setProperty("playCnt", 0)
		carbon:setProperty("buyCnt", 0)
	end

	local originCount = carbon:getProperty("playCnt")
	if carbonData.type ~= 3 and originCount + sweepCount > carbonData.playCount then
		role:sendSysErrMsg(SYS_ERR_CARBON_PLAY_COUNT_LIMIT)
		return
	end
	carbon:setProperty("playCnt", originCount + sweepCount)

	-- 扣体力
	if not role:costHealth(carbonData.consumeValue * sweepCount) then return end
	logger.info("r_out_health", role:logData({
		behavior = "o_hl_carbon",
		pm1 = carbonData.consumeValue * sweepCount,
		pm2 = carbonId,
	}))

	local gainExp, gainMoney, heroExp  = 0, 0, 0
	local heroResponse = {}
	heroResponse.heros = {}

	-- 扫荡的奖励
	local ret = { result = {} }
	for index = 1, sweepCount do 
		local money = math.ceil(carbonData.passMoney * tonumber(carbonData.starMoneyBonus[tostring(starNum)]) / 100)
		local exp = carbonData.consumeValue * globalCsv:getFieldValue("healthToExp")
		gainMoney = gainMoney + money
		gainExp = gainExp + exp
		heroExp = heroExp + math.ceil(carbonData.passExp * tonumber(carbonData.starExpBonus[tostring(starNum)]) / 100)

		local specialBattleCnt
		if carbonData.type == 2 then
			specialBattleCnt = tonumber(role:getProperty("specialBattleCnt"))
		end
		
		-- 掉落
		local dropItems = {}
		local dropItemFactory = require("logical.DropItemFactory")
		local specialDropItems = dropItemFactory.specialDrop(carbonId, specialBattleCnt)

		for _, item in ipairs(specialDropItems) do
			table.insert(dropItems, item)
		end

		-- 增加掉落武将
		local dropItems = itemCsv:mergeItems(dropItems)
		for key, value in ipairs(dropItems) do
			-- 对类型为1的随机碎片箱做特殊处理
			local itemInfo = itemCsv:getItemById(tonum(value.itemId))
			if value.itemTypeId == ItemTypeId.Gift then
				local items = role:getGiftDrops(itemInfo.giftDropIds)
				for _, item in pairs(items) do
					item.itemId = item.itemId + 2000
				end
				dropItems[key] = nil
				table.insertTo(dropItems, items)
			elseif value.itemTypeId == ItemTypeId.Hero then
				local itemInfo = itemCsv:getItemById(tonum(value.itemId))
				for index = 1, (value.num or 1) do
					local newHeroId = role:addHero({ 
						type = itemInfo.heroType,
						level = value.level,
						evolutionCount = value.evolutionCount 
					})

					local newHero = role.heros[newHeroId]
					if newHero then
						table.insert(heroResponse.heros, newHero:pbData())
					end
				end
				
			else
				local params = {notNotifyClient = true}
				table.merge(params, value)
				role:awardItemCsv(value.itemId, params)
			end
		end

		local sweepOnce = {}
		sweepOnce.money = money
		sweepOnce.exp = exp
		sweepOnce.dropItems = dropItems

		table.insert(ret.result, sweepOnce)

		--开启特殊商店
		openSpecialStore(role, carbonId)

		if carbonData.type == 2 then
			local specialBattleCnt = role:getProperty("specialBattleCnt")
			role:setProperty("specialBattleCnt", specialBattleCnt + 1)
		end
	end
	-- 增加玩家经验和金钱
	role:addExp(gainExp)
	role:gainMoney(gainMoney)
	-- 增加英雄经验
	role:addHeroExp(heroExp)

	-- 将英雄信息发送给客户端
	if  #heroResponse.heros > 0 then	
		local bin = pb.encode("HeroResponse", heroResponse)
		SendPacket(actionCodes.HeroLoadDataSet, bin)
	end

	local mapInfo = mapInfoCsv:getMapById(math.floor(carbonId / 100))
	local mapTaskField = { [1] = DailyTaskIdMap.CommonCarbon, [2] = DailyTaskIdMap.SpecialCarbon }
	role:updateDailyTask(mapTaskField[mapInfo.type], false, { deltaCount = sweepCount })

	-- 副本扫荡信息更新
	local carbonResponse = { carbons = {}, maps = {} }
	table.insert(carbonResponse.carbons, role.carbons[carbonId]:pbData())

	local bin = pb.encode("CarbonResponse", carbonResponse)
	SendPacket(actionCodes.CarbonLoadDataSet, bin)

	-- 处理扫荡相关信息
	if vipInfo.sweepCount ~= 0 then
		role.dailyData:updateProperty({field = "sweepCount", deltaValue = sweepCount})
	end

	local bin1 = pb.encode("CarbonSweepResult", ret)
	SendPacket(actionCodes.CarbonSweepResponse, bin1)
end

function CarbonAction.openMapAwardRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local totalStarNum = 0
	for carbonId, _ in pairs(role.mapCarbons[msg.param1]) do
		totalStarNum = totalStarNum + role.carbons[carbonId]:getProperty("starNum")
	end

	if role.maps[msg.param1]:getProperty("award" .. msg.param2) ~= 0 then
		return
	end

	local techItemData = techItemCsv:getDataByMap(msg.param1)
	if totalStarNum < tonumber(techItemData.awardStarNums[tostring(msg.param2)]) then
		return
	end

	role.maps[msg.param1]:setProperty("award" .. msg.param2, 1)
	local awardItems = techItemData["award" .. msg.param2]
	for itemId, count in pairs(awardItems) do
		role:awardItemCsv(tonum(itemId), {num = tonum(count)})
		log_util.log_map_award(role, tonum(itemId), tonum(count))
	end

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
	SendPacket(actionCodes.CarbonOpenAwardResponse, bin)
end

function CarbonAction.carbonResetRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local carbon = role.carbons[msg.param1]
	if carbon == nil then return end

	local buyCnt = carbon:getProperty("buyCnt")
	local vipInfo = vipCsv:getDataByLevel(role:getProperty("vipLevel"))
	if vipInfo.challengeCount <= buyCnt then return end
	
	local priceTable = string.toTableArray(globalCsv:getFieldValue("priceOfHardChallenge"))
	local price
	for i=1, 3 do
		if buyCnt >= tonum(priceTable[i][1]) and buyCnt <= tonum(priceTable[i][2]) then
			price = tonum(priceTable[i][3])
			break
		end
	end	

	if not role:spendYuanbao(price) then
		role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
		return	-- 元宝不够
	end

	logger.info("r_out_yuanbao", role:logData({
		behavior = "o_yb_reset_carbon",
		vipLevel = role:getProperty("vipLevel"),
		pm1 = price,
		pm2 = msg.param1,
		pm3 = 0,
	}))

	carbon:setProperty("buyCnt", buyCnt + 1)
	carbon:setProperty("playCnt", 0)

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
	SendPacket(actionCodes.CarbonResetResponse, bin)
end


--银币副本: state ==  0.可以  1.日期 2.次数超限 3.cd时间未到 
function CarbonAction.moneyBattleEnterRequest(agent, data)

	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role
	local state = 0
	local needtime = 0
	local openDays = globalCsv:getFieldValue("moneyOpenDate")
	local onDay = false
	local day = os.date("*t").wday
	day = day == 1 and 7 or day - 1
	for i=1,#openDays do
		if tonumber(openDays[i]) == day then 
			onDay = true 
			break
		end
	end

	if onDay then
		local grecord = globalCsv:getFieldValue("moneyBattleTimes")
		if tonumber(role.dailyData:getProperty("moneyBattleCount")) < grecord then
			local time = tonumber(role.dailyData:getProperty("moneyBattleCD"))
			local curtime = skynet.time()
			needtime = time - curtime
			state = 0
		else
			state = 2
		end
	else
		state = 1
	end

	local bin = pb.encode("SimpleEvent", { param1 = state,param2 = needtime})
	SendPacket(actionCodes.MoneyBattleEnterRequest, bin)

end

--银币副本: state == 0.可以 4.体力不足 5.等级不足 6.刷新时间 7.次数限制
function CarbonAction.moneyBattleRequest(agent, data)
	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role
	local state = 0
	if msg.param1 and tonumber(msg.param1) > 0 and tonumber(msg.param1) < 5 then
		local record = moneyBattleCsv:getDataById(tonumber(msg.param1))
		if tonumber(record.health) > tonumber(role:getProperty("health")) then
			state = 4
		else
			if tonumber(role:getProperty("level")) < tonumber(record.level) then
				state = 5
			else
				local time = tonumber(role.dailyData:getProperty("moneyBattleCD"))
				local curtime = skynet.time()
				if time < curtime then
					local enterCount = globalCsv:getFieldValue("moneyBattleTimes")
					if tonumber(role.dailyData:getProperty("moneyBattleCount")) < enterCount then

					else
						state = 7
					end
				else
					state = 6
				end
			end
		end

		if state == 0 then
			role:setProperty("enterFlag", msg.param1)
		end

		local bin = pb.encode("SimpleEvent", { param1 = state, param2 = msg.param1 })
		SendPacket(actionCodes.MoneyBattleRequest, bin)
	else
		role:sendSysErrMsg(SYS_ERR_VIR_NOT_EXIST)--参数错误
	end

end
--银币副本结束：返回奖励银币数量 敌方死亡人数 * 奖励银币值 武将增加经验
function CarbonAction.moneyBattleEndRequest(agent, data)
	--关卡index  killCount
	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role

	local carbonId = tonumber(msg.param1)
	local count = tonumber(msg.param2)
	local stage = tonumber(msg.param3)

	local info = moneyBattleCsv:getDataById(carbonId)
	if not info then role:sendSysErrMsg(SYS_ERR_VIR_NOT_EXIST) end

	if role:getProperty("enterFlag") ~= carbonId then return end
	role:setProperty("enterFlag", 0)

	local roundNum = tonumber(info.maxround)
	if count > 6 * roundNum then
		role:sendSysErrMsg(SYS_ERR_VIR_NOT_EXIST)
	end

	--每日任务
	role:updateDailyTask(DailyTaskIdMap.TrainCarbon)

	--扣除体力
	role:costHealth(info.health)
	logger.info("r_out_health", role:logData({
		behavior = "o_hl_carbon",
		pm1 = info.health,
		pm2 = carbonId,
	}))		
	--增加经验
	role:addExp(info.health * globalCsv:getFieldValue("healthToExp"))
	-- 增加英雄经验
	role:addHeroExp(info.heroExp)	
					
	--增加次数
	role.dailyData:setProperty("moneyBattleCount",role.dailyData:getProperty("moneyBattleCount") + 1)
	role:notifyUpdateProperty("moneyBattleCount", role.dailyData:getProperty("moneyBattleCount"))

	local awardMoney = tonumber(info.killMoney) * count
	awardMoney = awardMoney + stage* info.passAward
	awardMoney = awardMoney + (stage - 1) * stage / 2 * info.passGrowth

	--设置cdtime：
	local CDTime = globalCsv:getFieldValue("moneyBattleCD") --分钟
	local time = skynet.time() + CDTime * 60 --test 60
	role.dailyData:setProperty("moneyBattleCD", time)
	--刷新银币；
	role:gainMoney(awardMoney)

	logger.info("r_trial_fb", role:logData({
		behavior = "trial_money",
		pm1 = carbonId,
		pm2 = awardMoney,
	}))

	--返回数据
	local bin = pb.encode("SimpleEvent", { param1 = awardMoney,param2=info.heroExp})
	SendPacket(actionCodes.MoneyBattleEndRequest, bin)
end

--经验副本-进入活动: state ==  0.可以  1.日期 
function CarbonAction.expBattleEnterRequest(agent, data)

	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role
	local state = 0
	local needtime = 0
	local openDays = globalCsv:getFieldValue("expOpenDate")
	local onDay = false
	local day = tonumber(os.date("*t").wday)
	day = day == 1 and 7 or day - 1
	for i=1,#openDays do
		if tonumber(openDays[i]) == day then onDay = true end
	end

	if onDay then
		local grecord = globalCsv:getFieldValue("expBattleTimes")
		if tonumber(role.dailyData:getProperty("expBattleCount")) < grecord then
			local time = tonumber(role.dailyData:getProperty("expBattleCD"))
			local curtime = skynet.time()
			needtime = time - curtime
			state = 0
		else
			state = 2
		end
	else
		state = 1
	end

	local bin = pb.encode("SimpleEvent", { param1 = state,param2 = needtime})
	SendPacket(actionCodes.ExpBattleEnterRequest, bin)
end


--经验副本-进入战场: state == 0.可以 4.等级不足 5.体力不足 6.次数 7.刷新时间 
function CarbonAction.expBattleRequest(agent, data)

	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role

	if msg.param1 and tonumber(msg.param1) > 0 and tonumber(msg.param1) < 5 then
		local state = 0
		local record = expBattleCsv:getDataById(tonumber(msg.param1))

		if tonumber(role:getProperty("level")) < tonumber(record.level) then
			state = 4
		else
			if tonumber(record.health) > tonumber(role:getProperty("health")) then
				state = 5
			else
				local enterCount = globalCsv:getFieldValue("expBattleTimes")
				if tonumber(role.dailyData:getProperty("expBattleCount")) < enterCount then
					
					local time = tonumber(role.dailyData:getProperty("expBattleCD"))
					local curtime = skynet.time()
					if time < curtime then
						state = 0
						role:setProperty("enterFlag", msg.param1)
					else
						state = 7
					end	
				else
					state = 6
				end
			end
		end
		local bin = pb.encode("SimpleEvent", { param1 = state,param2 = msg.param1})
		SendPacket(actionCodes.ExpBattleRequest, bin)
	else
		role:sendSysErrMsg(SYS_ERR_VIR_NOT_EXIST)--参数错误
	end
end

-- 经验副本结束：
function CarbonAction.expBattleEndRequest(agent, data)
	--关卡index  时间
	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role

	if role:getProperty("enterFlag") ~= msg.param1 then return end
	role:setProperty("enterFlag", 0)

	local index = tonumber(msg.param1)
	local second = tonumber(msg.param2)
	local isWin = (tonumber(msg.param3) > 0)
	if second > 99 then second = 99 end
	if index > 0 and index < 5 then
		local r = expBattleCsv:getDataById(index)
		local n1 = 0
		local n2 = 0

		if second >= 99 or isWin then
			n1 = 9
			n2 = table.nums(r.pass)
		else
			n1 = math.floor((second-1)/10 + 1)
		end

		--每日任务
		role:updateDailyTask(DailyTaskIdMap.TrainCarbon)

		--扣除体力
		role:costHealth(r.health)
		logger.info("r_out_health", role:logData({
			behavior = "o_hl_carbon",
			pm1 = tonumber(r.health),
			pm2 = msg.param1,
		}))	

		--增加经验
		role:addExp(r.health * globalCsv:getFieldValue("healthToExp"))
		-- 增加英雄经验
		role:addHeroExp(r.heroExp)

		--增加次数
		role.dailyData:setProperty("expBattleCount",role.dailyData:getProperty("expBattleCount") + 1)
		role:notifyUpdateProperty("expBattleCount", role.dailyData:getProperty("expBattleCount")) 

		--设置cdtime：
		local CDTime = tonumber(globalCsv:getFieldValue("moneyBattleCD")) --特殊副本都是统一的CDtime
		local time = skynet.time() + CDTime * 60 --test 60
		role.dailyData:setProperty("expBattleCD",time)

		--全哥让添加的一个特殊卡牌，且需注意此type非彼type；
		local awardItemResponse = { addHeroExp=r.heroExp,awardItems = {},awardOthers = {}}

		local iData1 = itemCsv:getItemById(tonumber(r.items[1].id))  --获取对应的奖励类型；
		local iData2 = itemCsv:getItemById(tonumber(r.pass[1].id))  --获取对应的奖励类型；
		local isPackage1 = (iData1.type == 1 or iData1.type == 19) or false
		local isPackage2 = (iData2.type == 1 or iData2.type == 19) or false
		local totalExp = 0
		--普通掉落
		if n1 and n1 > 0 then
			--{id num prob}
			local resultTable = expBattleCsv:dropItemByIDAndTimes(index,n1,"items")
			for _,v in pairs(resultTable) do
				role:awardItemCsv(v.id, { num = v.num})
				local iData1 = itemCsv:getItemById(tonumber(v.id))
				table.insert(awardItemResponse.awardItems, {
						id = v.id,
						itemTypeId = iData1.type,
						itemId = v.id,
						num = v.num,
					})
				totalExp = totalExp + itemCsv:getItemById(v.id).heroExp
			end
		end
		if n2 and n2 > 0 then		
			local resultTable = expBattleCsv:dropItemByIDAndTimes(index,n2,"pass")
			for _,v in pairs(resultTable) do
				role:awardItemCsv(v.id, { num = v.num})
				local iData1 = itemCsv:getItemById(tonumber(v.id))
				table.insert(awardItemResponse.awardItems, {
					id = v.id,
					itemTypeId = iData1.type,
					itemId = v.id,
					num = v.num,
				})
				totalExp = totalExp + itemCsv:getItemById(v.id).heroExp
			end
		end
		local logdata = role:logData({
			behavior = "trial_exp",
			pm1 = index,
			pm2 = totalExp,
		})
		logger.info("r_trial_fb", logdata)		
		local bin = pb.encode("ExpBattleEndResposeData",awardItemResponse)
		SendPacket(actionCodes.ExpBattleEndRequest, bin)
	else
		role:sendSysErrMsg(SYS_ERR_VIR_NOT_EXIST)--参数错误
	end
end

local map = {"qun", "wei", "shu", "wu", "beauty"}
function CarbonAction.trialBattleRequest(agent, data)
	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role
	
	local battleId = msg.param1

	local battleInfo = trialBattleCsv:getDataById(battleId)
	if not battleInfo then return end

	--检查等级
	if battleInfo.level > role:getProperty("level") then
		return
	end
	--检查日期
	if not trialBattleCsv:isOpen(battleId) then
		return
	end
	--检查体力
	if battleInfo.health > role:getProperty("health") then
		return
	end

	--检查次数
	local countKey = string.format("%sBattleCount", map[msg.param2])
	if role.dailyData:getProperty(countKey) > 2 then
		return
	end
	--检查冷却是否结束
	local timeKey = string.format("%sBattleCD", map[msg.param2])
	if role.dailyData:getProperty(timeKey) > skynet.time() then
		return
	end

	role:setProperty("enterFlag", battleId)

	local dropItems = {}
	for _, dropData in ipairs(battleInfo.dropDatas) do
		local itemId, num, probability, priority = tonumber(dropData[1]), tonumber(dropData[2]), tonumber(dropData[3]), tonumber(dropData[4])

		if randomFloat(0, 100.0) <= probability then
			local itemInfo = itemCsv:getItemById(itemId)
			table.insert(dropItems, 
				{ itemTypeId = itemInfo.type, itemId = itemId, num = num, priority = priority })		
		end
	end
	local key = "TempCache:CarbonAward:"..role:getProperty("id")

	redisproxy:set(key, cjson.encode({carbonId = battleId, itemInfo = dropItems}))

	local sendDropItems = {}
	for _, value in ipairs(dropItems) do
		if value.priority ~= 0 then
			value.priority = nil
			table.insert(sendDropItems, value)
		end
	end
	local killResult = { roleId = role:getProperty("id"), 
		carbonId = battleId, dropItems = sendDropItems }

	local bin = pb.encode("BattleEndResult", killResult)
	SendPacket(actionCodes.TrialBattleRequest, bin)
end

-- 经验副本结束：
local behavmap = {'trial_qun', 'trial_wei', 'trial_shu', 'trial_wu', 'trial_beauty',}
function CarbonAction.trialBattleEndRequest(agent, data)
	local msg  = pb.decode("BattleEndResult", data)
	
	local role = agent.role

	local battleId = msg.carbonId
	local index = tonum(string.sub(battleId, 1, 1)) 
	local battleInfo = trialBattleCsv:getDataById(battleId)
	if not battleInfo then return end

	if role:getProperty("enterFlag") ~= battleId then return end
	role:setProperty("enterFlag", 0)

	
	local key = "TempCache:CarbonAward:"..role:getProperty("id")
	
	local dropInfo = redisproxy:get(key)

	-- 是否缓存boss掉落
	if not dropInfo then return end

	dropInfo = cjson.decode(dropInfo)
	
	-- 副本id是否一致
	if msg.carbonId ~= dropInfo.carbonId then return end

	-- 将掉落缓存清空，避免重复领取
	redisproxy:del(key)
	local dropItems = {}
	local exp = 0
	if msg.starNum > 0 then
		--扣除体力
		role:costHealth(battleInfo.health)
		logger.info("r_out_health", role:logData({
			behavior = "o_hl_carbon",
			pm1 = tonumber(battleInfo.health),
			pm2 = battleId,
		}))	

		--增加经验
		exp = battleInfo.health * globalCsv:getFieldValue("healthToExp")
		role:addExp(exp)
		-- 增加上阵英雄经验
		for _,hero in pairs(msg.joinHeros) do
			local tempHero = role.heros[hero.id]
			if tempHero then
				tempHero:addExp(battleInfo.heroExp)
			end
		end
		--增加次数
		role.dailyData:updateProperty({field = string.format("%sBattleCount", map[index])})

		--设置cdtime：
		local timeKey = string.format("%sBattleCD", map[index])
		local CDTime = tonumber(globalCsv:getFieldValue("moneyBattleCD")) --特殊副本都是统一的CDtime
		local time = skynet.time() + CDTime * 60 --test 60
		role.dailyData:updateProperty({field = timeKey, deltaValue = time - role.dailyData:getProperty(timeKey)})

		--给奖励
		for key, value in ipairs(dropInfo.itemInfo) do
			-- 对类型为1的随机碎片箱做特殊处理
			local itemInfo = itemCsv:getItemById(tonum(value.itemId))
			if value.itemTypeId == ItemTypeId.Gift then
				local items = role:getGiftDrops(itemInfo.giftDropIds)
				for _, item in pairs(items) do
					item.itemId = item.itemId + 2000
				end
				dropInfo.itemInfo[key] = nil
				table.insertTo(dropInfo.itemInfo, items)
			else
				if value.priority ~= 0 then
					table.insert(dropItems, { itemTypeId = value.itemTypeId, itemId = value.itemId, num = value.num })
				end
				role:awardItemCsv(value.itemId, value)
				-- log_util.log_fb_drop(role, value.itemId, value.num, msg.carbonId)
			end
		end	
		logger.info("r_trial_fb", role:logData({
			behavior = behavmap[index],
			pm1 = msg.carbonId,
		}))

		role:updateDailyTask(DailyTaskIdMap.TrainCarbon)
	end

	-- 战斗结束
	local endGameResponse = {
		roleId = msg.roleId, carbonId = msg.carbonId,
		starNum = msg.starNum, dropItems = dropItems, exp = battleInfo.heroExp
	}

	local bin = pb.encode("BattleEndResult", endGameResponse)
	SendPacket(actionCodes.TrialBattleEndRequest, bin)
end

return CarbonAction