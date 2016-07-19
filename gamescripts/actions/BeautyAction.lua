-- 美人系统action类
-- by yangkun
-- 2014.2.19

local BeautyAction = {}

--道具使用
function BeautyAction.normalTrainRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local beauty = role.beauties[msg.param1]
	local itemId = tonumber(msg.param2)

	if role.items[itemId] and role.items[itemId]:getProperty("count") > 0 then
		local beautyTrainData = beautyTrainCsv:getBeautyTrainInfoByEvolutionAndLevel(beauty:getProperty("evolutionCount"), beauty:getProperty("level"))
		local itemData = itemCsv:getItemById(itemId)
		-- 宠幸暴击
		local allBeautyCritData = beautyCritCsv:getAllBeautyCritData()
		local beautyCritData = allBeautyCritData[randWeight(allBeautyCritData)]
		local expAdd = itemData.favor * beautyCritData.multiple
		beauty:addExp( expAdd )
		role:updateDailyTask(DailyTaskIdMap.BeautyTrain)
		-- 扣背包物品
		role:addItem({id = itemId, count = -1})

		local bin = pb.encode("BeautyTrain", {detail = beauty:pbData(), expAdd = expAdd, multiple = beautyCritData.multiple})
		SendPacket(actionCodes.BeautyNormalTrainResponse, bin)
	else
		role:sendSysErrMsg(SYS_ERR_BEAUTY_ITEM_NOT_EXIST)
		return 
	end	
end

-- 废弃
function BeautyAction.highTrainRequest(agent, data)
	local msg = pb.decode("SimpleEvent",data)
	local role = agent.role

	local beauty = role.beauties[msg.param1]
	local beautyTrainData = beautyTrainCsv:getBeautyTrainInfoByEvolutionAndLevel(beauty:getProperty("evolutionCount"), beauty:getProperty("level"))

	-- 扣元宝
	if not role:spendYuanbao( beautyTrainData.highYuanbao ) then
		role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
		return
	end

	-- 宠幸暴击
	local trainRandom = math.random()
	if trainRandom <= beautyTrainData.highCrit / 100 then
		beauty:addExp( beautyTrainData.normalExp * beautyTrainData.highCritMultiple )
	else
		beauty:addExp( beautyTrainData.normalExp * beautyTrainData.highExpMultiple)
	end

	local bin = pb.encode("BeautyDetail", beauty:pbData())
	SendPacket(actionCodes.BeautyHighTrainResponse, bin)
end

function BeautyAction.normalPotentialRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local beauty = role.beauties[msg.param1]
	beauty.PotentialFlag=true

	local beautyListData = beautyListCsv:getBeautyById(beauty:getProperty("beautyId"))
	local curLevel = beauty:getProperty("level") + ( beauty:getProperty("evolutionCount") - 1 ) * beautyListData.evolutionLevel
	local beautyPotentialData = beautyPotentialCsv:getBeautyPotentialByLevel(curLevel)

	-- 金币消耗 
	if not role:spendMoney(beautyPotentialData.moneyCost) then
		role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
		return
	end

	beauty.randomHp = beauty:getPotentialRandomHp(true)
	beauty.randomAtk = beauty:getPotentialRandomAtk(true)
	beauty.randomDef = beauty:getPotentialRandomDef(true)

	local bin = pb.encode("SimpleEvent", {roleId = msg.roleId, param1 = beauty.randomHp, param2 = beauty.randomAtk, param3 = beauty.randomDef})
	SendPacket(actionCodes.BeautyNormalPotentialResponse, bin)
end

function BeautyAction.highPotentialRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local beauty = role.beauties[msg.param1]
	beauty.PotentialFlag=true

	local beautyListData = beautyListCsv:getBeautyById(beauty:getProperty("beautyId"))
	local curLevel = beauty:getProperty("level") + ( beauty:getProperty("evolutionCount") - 1 ) * beautyListData.evolutionLevel
	local beautyPotentialData = beautyPotentialCsv:getBeautyPotentialByLevel(curLevel)

	-- 元宝消耗 
	if not role:spendYuanbao(beautyPotentialData.yuanbaoCost) then
		role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
		return
	end
	logger.info("r_out_yuanbao", role:logData({
		behavior = "o_yb_b_canwu",
		vipLevel = role:getProperty("vipLevel"),
		pm1 = beautyPotentialData.yuanbaoCost,
		pm2 = msg.param1,
	}))

	beauty.randomHp = beauty:getPotentialRandomHp(false)
	beauty.randomAtk = beauty:getPotentialRandomAtk(false)
	beauty.randomDef = beauty:getPotentialRandomDef(false)

	local bin = pb.encode("SimpleEvent", {roleId = msg.roleId, param1 = beauty.randomHp, param2 = beauty.randomAtk, param3 = beauty.randomDef})
	SendPacket(actionCodes.BeautyHighPotentialResponse, bin)
	
end

function BeautyAction.potentialSaveRequest(agent, data)
	local msg = pb.decode("SimpleEvent",data)
	local role = agent.role

	local beauty = role.beauties[msg.param1]
	
	if beauty.PotentialFlag then
		beauty:addPotentialHp(beauty.randomHp)
		beauty:addPotentialAtk(beauty.randomAtk)
		beauty:addPotentialDef(beauty.randomDef)

		beauty.PotentialFlag=false
	end
	

	local bin = pb.encode("BeautyDetail", beauty:pbData())
	SendPacket(actionCodes.BeautyPotentialSaveResponse, bin)
end

function BeautyAction.evolutionRequest(agent, data)
	local msg = pb.decode("SimpleEvent",data)
	local role = agent.role

	local beauty = role.beauties[msg.param1]

	local beautyData = beautyListCsv:getBeautyById(beauty:getProperty("beautyId"))
	if beauty:getProperty("evolutionCount") >= beautyData.evolutionMax + 1 then
		-- 满级
		return
	else
		local beautyEvolutionData = beautyEvolutionCsv:getBeautyEvolutionInfoByLevel(beauty:getProperty("evolutionCount"))
		
		-- 道具消耗
		local itemId = tonum(table.keys(beautyEvolutionData.needItem)[1])
		local itemData = itemCsv:getItemById(itemId)
		local itemNeedNum = tonum(table.values(beautyEvolutionData.needItem)[1])
		local itemCount = role.items[itemId] and role.items[itemId]:getProperty("count") or 0

		if itemCount < itemNeedNum then
			role:sendSysErrMsg(SYS_ERR_ITEM_NUM_NOT_ENOUGH)
			return	
		else
			role:addItem({ id = itemId, count = -itemNeedNum })
		end

		beauty:addEvolutionCount(1)
		beauty:setProperty("exp",0)
		beauty:setProperty("level",1)
	end

	local bin = pb.encode("BeautyDetail", beauty:pbData())
	SendPacket(actionCodes.BeautyEvolutionResponse, bin)
end

function BeautyAction.fightRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local beauty = role.beauties[msg.param1]

	-- 找出出战的beauty
	for _, fightBeauty in pairs(role.beauties) do
		if fightBeauty:getProperty("status") == fightBeauty.class.STATUS_FIGHT then
			fightBeauty:setProperty("status", fightBeauty.class.STATUS_REST)
		end
	end

	beauty:setProperty("status", beauty.class.STATUS_FIGHT)

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId, param1 = 1 } )
	SendPacket(actionCodes.BeautyFightResponse, bin)
end

function BeautyAction.restRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local beauty = role.beauties[msg.param1]

	beauty:setProperty("status", beauty.class.STATUS_REST)

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId, param1 = 1 } )
	SendPacket(actionCodes.BeautyRestResponse, bin)
end

function BeautyAction.employRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local newBid = msg.param1

	local role = agent.role

	local beautyListData = beautyListCsv:getBeautyById(newBid)

	-- 等级限制
	local level = role:getProperty("level")
	if level < beautyListData.activeLevel then return end

	-- 前提英雄是否已经招募
	local preBid = beautyListData.preBeautyId
	if preBid > 0 and not role.beauties[preBid] then return end

	-- 副本限制
	local cid = beautyListData.preChallengeId
	if cid > 0 and role.carbons[cid]:getProperty("status") ~= 1 then return end

	-- 消耗限制
	if beautyListData.employMoney[1] == "1" then
		if not role:spendMoney( tonum(beautyListData.employMoney[2]) ) then
			role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
			return
		end
	else
		if not role:spendYuanbao( tonum(beautyListData.employMoney[2]) ) then
			role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
			return
		end
		logger.info("r_out_yuanbao", role:logData({
			behavior = "o_yb_employ_b",
	 		vipLevel = role:getProperty("vipLevel"),
			pm1 = tonum(beautyListData.employMoney[2]),
			pm2 = newBid,
		}))
	end

	role:addBeauty(newBid)

	local bin = pb.encode("BeautyDetail", role.beauties[newBid]:pbData())
	SendPacket(actionCodes.BeautyEmployResponse, bin)

	--全服通告
	if worldNoticeCsv:isConditionFit(worldNoticeCsv.beauty, newBid) then
		local content = worldNoticeCsv:getDesc(worldNoticeCsv.beauty, {playerName = role:getProperty("name"), param1 = beautyListData.beautyName})
		sendWorldNotice(content)
	end
end

return BeautyAction