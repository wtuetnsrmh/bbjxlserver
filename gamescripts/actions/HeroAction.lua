local HeroAction = {}

function HeroAction.intensify(agent, data)
	local msg = pb.decode("HeroActionData", data)

	local role = agent.role

	-- 判断主将存在
	local mainHero = role.heros[msg.mainHeroId]
	if mainHero == nil then
		role:sendSysErrMsg(SYS_ERR_HERO_MAIN_HERO_ERROR)
		return
	end

	local unitData = unitCsv:getUnitByType(mainHero:getProperty("type"))
	if  mainHero:getProperty("level") == role:getProperty("level")  and mainHero:getProperty("exp") == mainHero:getLevelTotalExp() then
		role:sendSysErrMsg(SYS_ERR_HERO_MAIN_LEVEL_LIMIT)
		return	--已满级
	end

	-- 素材卡
	local gainExp, spendMoney = 0, 0
	for index = 1, #msg.otherHeroIds do
		local fodderHero = role.heros[msg.otherHeroIds[index]]
		if fodderHero == nil then
			-- 一般不会进
			role:sendSysErrMsg(SYS_ERR_HERO_EVOLUTION_FODDER_ERROR)
			return
		end
		gainExp = gainExp + fodderHero:getWorshipExp()
	end
	spendMoney = gainExp * globalCsv:getFieldValue("intensifyGoldNum")

	if not role:spendMoney(spendMoney) then
		role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
		return	-- 金币不够
	end

	-- 删除武将卡
	for index = 1, #msg.otherHeroIds do
		local fodderHero = role.heros[msg.otherHeroIds[index]]
		logger.info("r_out_hero", role:logData({
			behavior = "o_hr_lvl_up",
			pm1 = 1,
			pm2 = fodderHero:getProperty("type"),
		}))
		if fodderHero ~= nil then
			fodderHero:delete()
			role.heros[msg.otherHeroIds[index]] = nil
		end
	end

	local oldLevel = mainHero:getProperty("level")
	-- 主将升级
	mainHero:addExp(gainExp)
	mainHero:save()

	local intensifyResponse = {
		result = 0,
		exp = gainExp,
	}

	local newLvl = mainHero:getProperty("level")
	if newLvl ~= oldLevel then
		local logdata = mainHero:logData({
			["level"] = newLvl
			})
		logger.info("h_levelup", logdata)
	end

	-- 更新每日任务统计
	role:updateDailyTask(DailyTaskIdMap.HeroIntensify)	

	local bin = pb.encode("HeroActionResponse", intensifyResponse)
    SendPacket(actionCodes.HeroIntensifyResponse, bin)
end

function HeroAction.evolution(agent, data)
	local msg = pb.decode("HeroActionData", data)

	local role = agent.role
	local mainHeroId = msg.mainHeroId
	-- 判断进化武将存在
	local evolutionHero = role.heros[msg.mainHeroId]
	if not evolutionHero or table.nums(evolutionHero.battleSoul) < 6 then
		return
	end

	local evolutionType = evolutionHero:getProperty("type")
	local curEvolCount = evolutionHero:getProperty("evolutionCount")
	local unitData = unitCsv:getUnitByType(evolutionType)
	local evolutionData = evolutionModifyCsv:getEvolutionByEvolution(curEvolCount + 1)
	if curEvolCount >= evolutionModifyCsv:getEvolMaxCount() then
		role:sendSysErrMsg(SYS_ERR_HERO_MAIN_EVOLUTION_CNT_LIMIT)
		return	--该卡不能进化
	end

	evolutionHero.battleSoul = {}
	evolutionHero:updateBattleSoul()

	-- 武将的进化次数加1
	evolutionHero:addEvolutionCount(1)

	-- 武将开启新的被动技能
	local evolutionCount = evolutionHero:getProperty("evolutionCount")
	for passiveIndex = 1, 3 do
		if evolutionCount >= globalCsv:getFieldValue("passiveSkillLevel" .. passiveIndex) then
			local passiveSkillId = evolutionHero.unitData["passiveSkill" .. passiveIndex]
			if not evolutionHero.skillLevels[tostring(passiveSkillId + 10000)] then
				evolutionHero.skillLevels[tostring(passiveSkillId + 10000)] = 1
			end
		end
	end
	evolutionHero:updateSkillLevels()

	local evolutionResponse = {
		result = 0,
		heros = {  
			{ id = msg.mainHeroId, evolutionCount = evolutionHero:getProperty("evolutionCount") }
		},
		items = items,
	}

	local bin = pb.encode("HeroActionResponse", evolutionResponse)
    SendPacket(actionCodes.HeroEvolutionResponse, bin)

    --全服通告
    local curEvolCount = evolutionHero:getProperty("evolutionCount")
	if worldNoticeCsv:isConditionFit(worldNoticeCsv.evolution, curEvolCount) then 
		local content = worldNoticeCsv:getDesc(worldNoticeCsv.evolution, {playerName = role:getProperty("name"), param1 = unitData.name, param2 = unitCsv:getEvolRichDesc(curEvolCount)})
		sendWorldNotice(content)
	end
end

function HeroAction.choose(agent, data)
 	local msg = pb.decode("HeroChooseRequest", data)

	local role = agent.role
	local slot = tostring(msg.slot)

	-- 上阵武将以前的槽位
	local changed_slot
	for slot, data in pairs(role.slots) do
		if msg.heroId ~= 0 and data.heroId == msg.heroId then
			changed_slot = slot
			break
		end
	end

	--技能顺序重置
	if not changed_slot then
		local originHeroId = role.slots[slot] and tonum(role.slots[slot].heroId) or 0
		local skillSlot = table.keyOfItem(role.skillOrder, originHeroId)
		if not skillSlot then
			for index = 1, 5 do
				local heroId = tonum(role.skillOrder[index])
				if heroId == 0 then
					skillSlot = index
					break
				end
			end
		end
		if skillSlot then
			role.skillOrder[skillSlot] = msg.heroId ~= 0 and msg.heroId or nil
		end
		role:updateSkillOrder()
	end

	-- 设置原先武将信息
	if role.slots[slot] and role.slots[slot].heroId and role.slots[slot].heroId > 0 then
		local originHeroId = role.slots[slot].heroId
		if changed_slot then
			-- 交换
			role.slots[changed_slot].heroId = originHeroId
			--副将交换
			local temp = role.slots[changed_slot].assistants
			role.slots[changed_slot].assistants = role.slots[slot].assistants
			role.slots[slot].assistants = temp
			--武器交换
			temp = role.slots[changed_slot].equips
			role.slots[changed_slot].equips = role.slots[slot].equips
			role.slots[slot].equips = temp

		else
			-- 更新阵型
			for pos = 1, 6 do
				if role.pveFormation[pos] and role.pveFormation[pos] == originHeroId then
					role.pveFormation[pos] = nil
					break
				end
			end
			-- 闲置武将
			role.heros[originHeroId]:setProperty("choose", 0)
			role.heros[originHeroId]:notifyUpdateProperty("choose", 0)
			role.chooseHeroIds[originHeroId] = nil
			role.slots[slot].heroId = 0

			--清除副将
			if role.slots[slot].assistants then
				for _,heroId in pairs(role.slots[slot].assistants) do
					role.heros[heroId]:updateMasterHero(0)
				end
				role.slots[slot].assistants = nil
			end
		end
	end

	if msg.heroId > 0 then
		local key = table.keyOfItem(role.partners, msg.heroId)
		if key then
			--小伙伴
			role.partners[key] = nil
			role:updatePartners()
		end
		role.heros[msg.heroId]:setProperty("choose", 1)
		role.heros[msg.heroId]:notifyUpdateProperty("choose", 1)
		role.chooseHeroIds[msg.heroId] = true

		role.slots[slot] = role.slots[slot] or {}
		role.slots[slot].heroId = msg.heroId

		if msg.slot == 1 then
			role:setProperty("mainHeroId", msg.heroId)
			role:notifyUpdateProperty("mainHeroId", msg.heroId)
		end

		-- 新上阵
		if not changed_slot then
			local chosenHeroTypes = {}
			local emptyPos
			for pos = 1, 6 do
				if role.pveFormation[pos] then
					local hero = role.heros[role.pveFormation[pos]]
					if hero then
						chosenHeroTypes[hero:getProperty("type")] = true
					end
				end

				local cjson = require("cjson")
				if not role.pveFormation[pos] or role.pveFormation[pos] == cjson.null  then
					if not emptyPos then emptyPos = pos end
				end
			end

			local beChooseHero = role.heros[msg.heroId]
			if beChooseHero and chosenHeroTypes[beChooseHero:getProperty("type")] then
				role:sendSysErrMsg(SYS_ERR_CHOOSE_SAME_TYPE_HERO)
				return
			end 

			if emptyPos then
				role.pveFormation[emptyPos] = msg.heroId
			end
		end

	elseif msg.heroId == 0 then -- 下阵
		-- 更新阵型
		for pos = 1, 6 do
			if role.pveFormation[pos] and role.pveFormation[pos] == role.slots[slot].heroId then
				role.pveFormation[pos] = nil
				break
			end
		end
	end

	role:updateSlots()
	role:updateChooseHeroIds()
	role:updatePveFormation()

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
    SendPacket(actionCodes.HeroChooseResponse, bin)

    --更新新手引导
    if role:getProperty("guideStep") == 5 then
		role:setProperty("guideStep", 6)
	elseif role:getProperty("guideStep") == 6 then
		role:setProperty("guideStep", 7)
	elseif role:getProperty("guideStep") == 17 then
		role:setProperty("guideStep", 18)
	end

end

function HeroAction.sellHeros( agent, data )
	local msg = pb.decode("HeroActionData", data)

	local role = agent.role

	local totalMoney = 0
	for index = 1, #msg.otherHeroIds do
		local sellHero = role.heros[msg.otherHeroIds[index]]
		if sellHero ~= nil then
			totalMoney = totalMoney + sellHero:getSellMoney()
		end
	end

	for index = 1, #msg.otherHeroIds do
		local sellHero = role.heros[msg.otherHeroIds[index]]
		logger.info("r_out_hero", role:logData({
			behavior = "o_hr_sell",
			pm1 = 1,
			pm2 = sellHero:getProperty("type"),
		}))		
		if sellHero ~= nil then
			sellHero:delete()
		end
		role.heros[msg.otherHeroIds[index]] = nil
	end

	role:gainMoney(totalMoney)

	local sellResponse = {
		result = 0,
		money = totalMoney,
	}

	local bin = pb.encode("HeroActionResponse", sellResponse)
    SendPacket(actionCodes.HeroSellResponse, bin)
end

function HeroAction.changeAssistantRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local assistantHero = role.heros[msg.param3]
	if not assistantHero then return end

	-- 已经作为副将
	if assistantHero:getProperty("master") > 0 then
		return
	end

	if not role.slots[tostring(msg.param1)].assistants then
		role.slots[tostring(msg.param1)].assistants = {}
	end

	local originHeroId = role.slots[tostring(msg.param1)].assistants[tostring(msg.param2)]
	if originHeroId and originHeroId > 0 then
		role.heros[originHeroId]:updateMasterHero(0)
	end

	local currentHeroId = msg.param3
	role.slots[tostring(msg.param1)].assistants[tostring(msg.param2)] = currentHeroId
	role.heros[currentHeroId]:updateMasterHero(1)
	role:updateSlots()

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId , param1 = originHeroId})
	SendPacket(actionCodes.HeroAssistantChangeResponse, bin)
end

function HeroAction.cancelAssistantRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local assistantHero = role.heros[msg.param3]
	if not assistantHero then return end

	-- 副将的主将不对，或者属性位置不对
	if assistantHero:getProperty("master") == 0 
		or role.slots[tostring(msg.param1)].assistants[tostring(msg.param2)] ~= msg.param3 then
		return
	end

	role.slots[tostring(msg.param1)].assistants[tostring(msg.param2)] = nil
	role:updateSlots()
	assistantHero:updateMasterHero(0)

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
	SendPacket(actionCodes.HeroAssistantCancelResponse, bin)
end

function HeroAction.allRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local heroTypes = redisproxy:smembers(string.format("role:%d:heroTypes", role:getProperty("id")))
	local result = {}
	for index,heroType in ipairs(heroTypes) do
		local unitData = unitCsv:getUnitByType(tonum(heroType))
		if unitData.heroOpen > 0 then
			table.insert(result, tonum(heroType))
		end
	end

	local bin = pb.encode("HeroAllResponse", { types = result })
	SendPacket(actionCodes.HeroAllResponse, bin)
end

function HeroAction.skillLevelUpRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local hero = role.heros[msg.param1]
	if not hero then return end

	local items, money, openLevel

	local skillLevel = hero.skillLevels[tostring(msg.param2)] or 1

	if msg.param2 < 10000 then
		-- 主动技能
		local skillLevelData = skillLevelCsv:getDataByLevel(msg.param2, skillLevel + 1)
		items = skillLevelData.items or {}
		money = skillLevelData.money or 0
		openLevel = skillLevelData.openLevel
	else
		-- 被动技能
		local passiveSkillId = msg.param2 - 10000
		local skillLevelData = skillPassiveLevelCsv:getDataByLevel(passiveSkillId, skillLevel + 1)
		items = skillLevelData.items or {}
		money = skillLevelData.money or 0
		openLevel = skillLevelData.openLevel
	end

	for _, itemData in ipairs(items) do
		local itemId = tonum(itemData[1])
		local itemCount = role.items[itemId] and role.items[itemId]:getProperty("count") or 0
		if itemCount < tonum(itemData[2]) then
			role:sendSysErrMsg(SYS_ERR_ITEM_NUM_NOT_ENOUGH)	
			return
		end
	end

	-- 检查金钱
	if not role:checkMoney(money) then
		role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
		return
	end

	-- 检查武将等级
	if hero:getProperty("level") < openLevel then
		role:sendSysErrMsg(SYS_ERR_HERO_LEVEL_NOT_ENOUGH)
		return
	end

	for _, itemData in ipairs(items) do
		role:addItem({id = tonum(itemData[1]), count = -tonum(itemData[2])})
	end
	role:spendMoney(money)

	hero.skillLevels[tostring(msg.param2)] = skillLevel + 1
	hero:updateSkillLevels()

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
	SendPacket(actionCodes.HeroSkillLevelUpResponse, bin)
end

function HeroAction.heroWakeLevelUpRequest(agent, data)
	local msg = pb.decode("HeroActionData", data)

	local role = agent.role
	local mainHeroId = msg.mainHeroId

	-- 判断进化武将存在
	local wakeHero = role.heros[mainHeroId]
	if not wakeHero then return end

	local heroType = wakeHero:getProperty("type")
	local curWakeLevel = wakeHero:getProperty("wakeLevel")
	local unitData = unitCsv:getUnitByType(heroType)
	local wakeCsvData = heroWakeCsv:getByHeroStar(unitData.stars)

	if curWakeLevel >= wakeCsvData.wakeLevelMax then
		return
	end


	-- 检查碎片
	local fragmentId = math.floor(heroType + 2000)
	local fragmentNum = role.fragments[fragmentId]
	local costFragNum = wakeCsvData.costHeroFragment[curWakeLevel + 1]
	if costFragNum > fragmentNum then
		return
	end

	-- 检查金钱
	local needMoney = wakeCsvData.costMoney[curWakeLevel + 1]
	if not role:checkMoney(needMoney) then
		role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
		return
	end

	--扣除碎片和金钱
	if costFragNum == fragmentNum then
		role.fragments[fragmentId] = nil
		redisproxy:hdel(string.format("role:%d:fragments", msg.roleId), tostring(fragmentId))
	else
		role.fragments[fragmentId] = fragmentNum - costFragNum
		redisproxy:hset(string.format("role:%d:fragments", msg.roleId), fragmentId, role.fragments[fragmentId])
	end
	role:spendMoney(needMoney)
	
	-- 武将的觉醒加1
	wakeHero:updateWakeLevel()

	-- logger.info("r_out_fragment", role:logData({
	-- 	behavior = "o_fg_wake",
	-- 	pm1 = costFragNum,
	-- 	pm2 = fragmentId,
	-- 	pm3 = wakeHero:getProperty("wakeLevel"),
	-- }))

	local wakeResponse = {
		result = 0,
		heros = {  
			{ id = msg.mainHeroId, wakeLevel = wakeHero:getProperty("wakeLevel")}
		},
	}

	local bin = pb.encode("HeroActionResponse", wakeResponse)
    SendPacket(actionCodes.HeroWakeLevelUpResponse, bin)
end

function HeroAction.heroDecomposeRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	local mainHeroId = msg.param1
	local hero = role.heros[mainHeroId]
	if not hero then return end

	local heroType = hero:getProperty("type")
	local wakeLevel = hero:getProperty("wakeLevel")
	local unitData = unitCsv:getUnitByType(heroType)
	local fragmentNum = tonum(unitData.decompose[tostring(wakeLevel)])
	
	local gainMoney = hero:getSellMoney(true)
	--删除英雄
	logger.info("r_out_hero", role:logData({
		behavior = "o_hr_decompose",
		pm1 = 1, 
		pm2 = hero:getProperty("type"),
	}))
	hero:delete()
	role.heros[mainHeroId] = nil
	--增加碎片
	local fragmentId = math.floor(heroType + 2000)
	if role.fragments[fragmentId] then 
		role.fragments[fragmentId] = role.fragments[fragmentId] + fragmentNum
	else
		role.fragments[fragmentId] = fragmentNum
	end
	redisproxy:hset(string.format("role:%d:fragments", msg.roleId), fragmentId, role.fragments[fragmentId])
	-- logger.info("r_in_fragment", role:logData({
	-- 	behavior = "i_fg_resolve",
	-- 	pm1 = fragmentNum,
	-- 	pm2 = fragmentId,
	-- 	pm3 = 0,
	-- }))
	--增加钱
	role:gainMoney(gainMoney)

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
	SendPacket(actionCodes.HeroDecomposeResponse, bin)
end

function HeroAction.heroStarUpRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	local heroId = msg.param1

	-- 判断武将存在
	local hero = role.heros[heroId]
	if not hero or hero:isStarMax() then return end

	local heroType = hero:getProperty("type")
	local unitData = unitCsv:getUnitByType(heroType)
	local nextStar = hero:getProperty("star") + 1


	-- 检查碎片
	local fragmentId = math.floor(heroType + 2000)
	local fragmentNum = role.fragments[fragmentId]
	local costFragNum = globalCsv:getFieldValue("starUpFragment")[nextStar]
	if costFragNum > fragmentNum then
		return
	end

	-- 检查金钱
	local needMoney = globalCsv:getFieldValue("starUpCost")[nextStar]
	if not role:checkMoney(needMoney) then
		role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
		return
	end

	--扣除碎片和金钱
	role:addFragments({{fragmentId = fragmentId, num = -costFragNum}})
	
	role:spendMoney(needMoney)
	
	-- 武将的星级加1
	hero:updateStar()

	logger.info("r_out_fragment", role:logData({
		behavior = "o_fg_star_up",
		pm1 = costFragNum,
		pm2 = fragmentId,
		pm3 = nextStar,
	}))


	local bin = pb.encode("SimpleEvent", {roleId = role:getProperty("id")})
    SendPacket(actionCodes.HeroStarUpRequest, bin)

    --全服通告
	if worldNoticeCsv:isConditionFit(worldNoticeCsv.starUp, nextStar) then
		local content = worldNoticeCsv:getDesc(worldNoticeCsv.starUp, {playerName = role:getProperty("name"), param1 = unitData.name, param2 = nextStar})
		sendWorldNotice(content)
	end
end

function HeroAction.heroPartnerRequest(agent, data)
 	local msg = pb.decode("HeroChooseRequest", data)

	local role = agent.role
	local slot = msg.slot

	local key = table.keyOfItem(role.partners, msg.heroId)
	if key then
		role.partners[key] = nil
	end
	role.partners[slot] = msg.heroId
	role:updatePartners()

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
    SendPacket(actionCodes.HeroPartnerRequest, bin)
end

function HeroAction.inlayBattleSoul(agent, data)
 	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	local slot = msg.param1
	local hero = role.heros[tonum(msg.param2)]

	if not hero then return end

	local resources = hero.unitData["evolMaterial" .. (hero:getProperty("evolutionCount") + 1)]
	if not resources then return end

	local inlaySlots = {}
	local function inlay(itemId, soulSlot)
		soulSlot = tostring(soulSlot)
		local item = role.items[itemId]
		if hero.battleSoul[soulSlot] or not item or item:getProperty("count") <= 0 then
			return
		end

		local csvData = battleSoulCsv:getDataById(itemId - battleSoulCsv.toItemIndex)
		if not csvData or csvData.requireLevel > hero:getProperty("level") then
			return
		end

		role:addItem({id = itemId, count = -1})

		hero.battleSoul[soulSlot] = 1
		table.insert(inlaySlots, tonum(soulSlot))
	end

	if slot == 0 then
		for index, itemId in ipairs(resources) do
			inlay(itemId, index)
		end
	else
		inlay(resources[slot], slot)
	end

	hero:updateBattleSoul()

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId, param5 = json.encode(inlaySlots) })
    SendPacket(actionCodes.HeroBattleSoulRequest, bin)

    --新手引导
    if role:getProperty("guideStep") == 11 then
		role:setProperty("guideStep", 13)
	end
end

return HeroAction