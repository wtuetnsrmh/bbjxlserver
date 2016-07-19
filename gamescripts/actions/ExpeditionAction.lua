local ExpeditionAction = {}

local function getFightList(roleId, level, response)
	response.fightList = response.fightList or {}
	if level > 15 then level = 15 end
	for i = 1, level do
		local fighterJson = redisproxy:hget(string.format("expedition:fightList:%d", roleId), i)
		if not fighterJson then 
			response.fightList = {}
			return
		end
		local fighter = json.decode(fighterJson) or {}
		fighter.id = i
		table.insert(response.fightList, fighter)
	end
end

-- 获取远征基本信息 OK
function ExpeditionAction.expeditionReq(agent, data)
	local role = agent.role
	local roleId = role:getProperty("id")
	local level = role:getProperty("yzLevel")
	local response = {}
	getFightList(roleId, level, response)
	
	local vipInfo = vipCsv:getDataByLevel(role:getProperty("vipLevel"))
	response.leftCnt = vipInfo.expeditionResetCount - role.dailyData:getProperty("expeditionResetCount")

	local drawKey = string.format("role:%d:yzaward", roleId)
	local json_draw = redisproxy:get(drawKey)
	local drawList = {}
	if not json_draw then
		for i=1,15 do
			drawList[i] = YzDrawType.CantDraw
		end
	else
		drawList = json.decode(json_draw)
	end
	response.drawStatus = drawList

	local bin = pb.encode("ExpeditionResponse", response)
	SendPacket(actionCodes.ExpeditionResponse, bin)
end

-- 开始远征并选择英雄
function ExpeditionAction.enterExpeditionReq(agent, data)
	local role = agent.role
	local roleId = role:getProperty("id")
	local msg = pb.decode("EnterExpeditionRequest", data)
	-- id 是否合法
	if msg.id ~= role:getProperty("yzLevel") then
		local bin = pb.encode("SimpleEvent", {param1 = SYS_ERR_YZ_OPER})
		SendPacket(actionCodes.EnterExpeditionResponse, bin)
		return
	end
	-- heroList
	if 0 == #msg.heroList then
		local bin = pb.encode("SimpleEvent", {param1 = SYS_ERR_YZ_HERO_LIST_NULL})
		SendPacket(actionCodes.EnterExpeditionResponse, bin)
		return
	end
	local json_join = redisproxy:get(string.format("expedition:joinedList:%d", roleId))
	local joinList = json_join and json.decode(json_join) or {}
	for _, heroId in ipairs(msg.heroList) do 
		-- 武将是否存在
		local hero = role.heros[heroId]
		if not hero then
			local bin = pb.encode("SimpleEvent", {param1 = SYS_ERR_YZ_OPER})
			SendPacket(actionCodes.EnterExpeditionResponse, bin)
			return
		end
		-- 等级和星级是否满足 
		local bLvl = hero:getProperty("level") < globalCsv:getFieldValue("limitLevel")
		local heroData = unitCsv:getUnitByType(hero:getProperty("type"))
		local bStar = heroData.stars < globalCsv:getFieldValue("limitStar")
		if bLvl or bStar then
			local bin = pb.encode("SimpleEvent", {param1 = SYS_ERR_YZ_OPER})
			SendPacket(actionCodes.EnterExpeditionResponse, bin)
			return
		end
		if not joinList[tostring(heroId)] then
			joinList[tostring(heroId)] = {heroId = heroId, blood = 100, isOn = 1}
		end
	end
	redisproxy:set(string.format("expedition:joinedList:%d", roleId), json.encode(joinList))
	redisproxy:set(string.format("expedition:temp:%d:%d", role:getProperty("id"), msg.id), json.encode(msg.heroList))
	local bin = pb.encode("SimpleEvent", {})
	SendPacket(actionCodes.EnterExpeditionResponse, bin)
end

-- 结束远征
function ExpeditionAction.endExpeditionReq(agent, data)
	local role = agent.role
	local roleId = role:getProperty("id")
	local msg = pb.decode("EndExpeditionRequest", data)
	local index = msg.id
	-- 1. 是否点击开始挑战
	local tempKey = string.format("expedition:temp:%d:%d", roleId, index)
	local json_hero = redisproxy:get(tempKey)
	if not json_hero then
		local bin = pb.encode("SimpleEvent", {param1 = SYS_ERR_YZ_OPER})
		SendPacket(actionCodes.EndExpeditionReponse, bin)
		return
	end

	-- 2. 关卡是否对应
	local other = msg.other
	if msg.id ~= other.id or msg.id ~= role:getProperty("yzLevel") then
		local bin = pb.encode("SimpleEvent", {param1 = SYS_ERR_YZ_OPER})
		SendPacket(actionCodes.EndExpeditionReponse, bin)
		return
	end

	local heroList = json.decode(json_hero)
	local joinList = json.decode(redisproxy:get(string.format("expedition:joinedList:%d", roleId)))

	local myself = msg.myself
	for _,v in pairs(myself.heroList) do
		-- 3. 检查是否跟之前缓存的英雄列表一致
		if not joinList[tostring(v.id)] then
			local bin = pb.encode("SimpleEvent", {param1 = SYS_ERR_YZ_OPER})
			SendPacket(actionCodes.EndExpeditionReponse, bin)
			return
		end
		if v.blood == 0 then
			joinList[tostring(v.id)] = {heroId = v.id, blood = v.blood, isOn = 2}
		else
			joinList[tostring(v.id)] = {heroId = v.id, blood = v.blood, isOn = 1}
		end
	end
	-- 4. 删除tempKey
	redisproxy:del(tempKey)

	-- 5. 修改敌方英雄状态以及怒气值
	local fighterJson = redisproxy:hget(string.format("expedition:fightList:%d", roleId), msg.id)
	local fightDtl = json.decode(fighterJson)
	local bwin = true
	for k, v in ipairs(other.heroList) do
		fightDtl.heroList[k] = v
		if v.blood ~= 0 then 
			bwin = false
		end
	end
	fightDtl.angryCD = other.angryCD

	redisproxy:set(string.format("expedition:joinedList:%d", roleId), json.encode(joinList))
	redisproxy:hset(string.format("expedition:fightList:%d", roleId), msg.id, json.encode(fightDtl))
	redisproxy:set(string.format("expedition:angryCD:%d", roleId), myself.angryCD)

	-- 6. 成功,奖励设置可领取,关卡加1
	if bwin then
		-- 设置状态为可领取
		local drawKey = string.format("role:%d:yzaward", roleId)
		local drawList = json.decode(redisproxy:get(drawKey))
		drawList[index] = YzDrawType.HasNotDraw
		redisproxy:set(drawKey, json.encode(drawList))
		role:setProperty("yzLevel", role:getProperty("yzLevel") + 1)
		role:updateDailyTask(DailyTaskIdMap.Expedition)
	end

	-- 7.增加上阵英雄经验
	local exp = forceMatchCsv:getAwardById(msg.id).exp
	for _,hero in pairs(msg.joinHeros) do
		local tempHero = role.heros[hero.id]
		if tempHero then
			tempHero:addExp(exp)
		end
	end

	local bin = pb.encode("SimpleEvent", {})
	SendPacket(actionCodes.EndExpeditionReponse, bin)
end

function ExpeditionAction.drawAward(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local index = tonumber(msg.param1)
	local role = agent.role

	-- 设置状态为已领取
	local drawKey = string.format("role:%d:yzaward", role:getProperty("id"))
	local drawList = json.decode(redisproxy:get(drawKey))

	if drawList[index] == YzDrawType.HasDraw then
		local bin = pb.encode("DrawExpeditionResponse", {errCode = SYS_ERR_YZ_HAS_DRAW})
		SendPacket(actionCodes.DrawExpeditionResponse, bin)
		return
	end
	if drawList[index] == YzDrawType.CantDraw then
		local bin = pb.encode("DrawExpeditionResponse", {errCode = SYS_ERR_YZ_OPER})
		SendPacket(actionCodes.DrawExpeditionResponse, bin)
		return
	end

	drawList[index] = YzDrawType.HasDraw
	redisproxy:set(drawKey, json.encode(drawList))

	-- 领取奖励
	local money, awardItems = forceMatchCsv:getAward(index, role:getProperty("level"))
	money=math.floor(money*(1+vipCsv:getDataByLevel(role:getProperty("vipLevel")).expeditionMoneyGrowth/100))

	local items = {}
	table.insert(items, { itemId = 601, num = money })
	
	local yzLevel = role:getProperty("yzLevel")
	for id, num in pairs(awardItems) do
		local itemInfo = itemCsv:getItemById(tonum(id))
		if itemInfo.type == ItemTypeId.RandomItemBox then
			local weightArrary = {}
			for _, data in pairs(itemInfo.randomIds) do
				weightArrary[#weightArrary + 1] = {
					itemId = tonumber(data[1]), weight = tonumber(data[2]), num = tonumber(data[3])
				}
			end
			local randomIndex = randWeight(weightArrary)
			if weightArrary[randomIndex] then
				local itemData = weightArrary[randomIndex]
				role:awardItemCsv(itemData.itemId, {num = itemData.num })
				log_util.log_expedition_award(role, itemData.itemId, itemData.num, yzLevel)
				table.insert(items, { itemId = itemData.itemId, num = itemData.num })
			end
		else
			if role.dailyData:getProperty("expeditionResetCount")>1 then
				if tonum(id)~=604 then
					role:awardItemCsv(id, {num = num })
					log_util.log_expedition_award(role, id, num, yzLevel)
					table.insert(items, { itemId = id, num = num })
				end
			else
				role:awardItemCsv(id, {num = num })
				log_util.log_expedition_award(role, id, num, yzLevel)
				table.insert(items, { itemId = id, num = num })
			end
		end
	end
	role:gainMoney(money)

	local bin = pb.encode("DrawExpeditionResponse", {items = items})
	SendPacket(actionCodes.DrawExpeditionResponse, bin)
end

function ExpeditionAction.joinReq(agent, data)
	local role = agent.role
	local roleId = role:getProperty("id")

	local response = {joinHeros={}}
	local json_join = redisproxy:get(string.format("expedition:joinedList:%d", roleId))
	local joinList = json_join and json.decode(json_join) or {}

	for _,v in pairs(joinList) do
		table.insert(response.joinHeros, v)
	end

	local angryCD = redisproxy:get(string.format("expedition:angryCD:%d", roleId))
	response.angryCD = angryCD or 0

	local bin = pb.encode("ExpeditionJoinResponse", response)
	SendPacket(actionCodes.ExpeditionJoinResponse, bin)
end

function ExpeditionAction.restartExpedition(agent, data)
	local role = agent.role
	local roleId = role:getProperty("id")
	local vipInfo = vipCsv:getDataByLevel(role:getProperty("vipLevel"))
	local leftCnt = vipInfo.expeditionResetCount - role.dailyData:getProperty("expeditionResetCount")

	-- 1. 检查远征次数
	if leftCnt <= 0 then
		local bin = pb.encode("ExpeditionResponse", {errCode = SYS_ERR_YZ_LEFT_COUNT})
		SendPacket(actionCodes.ExpeditionRestartRes, bin)
		return
	end

	-- 2. 刷新远征
	local response = {}
	local seed = tonumber(tostring(skynet.time()):reverse():sub(1,6))
	local maxForce = role:getBestCombForce()
	local confJson1 = json.encode(clone(forceMatchCsv:getMatchData()))
	local confJson2 = json.encode(clone(forceMatchUpdateCsv:getData()))
	local bsuccess = redisproxy:runScripts("RandomYzFighter", 5, 
		seed, roleId, maxForce, confJson1, confJson2)
	if not bsuccess then
		local bin = pb.encode("ExpeditionResponse", {errCode = SYS_ERR_UNKNOWN})
		SendPacket(actionCodes.ExpeditionRestartRes, bin)
		skynet.error("run RandomYzFighter script error")
		return
	end

	-- 3. 重置领取状态
	local drawList = {}
	for i=1,15 do
		drawList[i] = YzDrawType.CantDraw
	end
	redisproxy:set(string.format("role:%d:yzaward", roleId), json.encode(drawList))
	response.drawStatus = drawList

	-- 4. 重置挑战关卡
	local pre1, pre2
	pre2 = role:getProperty("pre1")
	pre1 = role:getProperty("yzLevel")
	role:setProperty("pre1", pre1)
	role:setProperty("pre2", pre2)
	role:setProperty("yzLevel", 1)
	-- 获取对手列表
	getFightList(roleId, 1, response)

	-- 5. 重置怒气值
	redisproxy:set(string.format("expedition:angryCD:%d", roleId), 0)

	-- 6. 重置参与英雄列表
	redisproxy:set(string.format("expedition:joinedList:%d", roleId), "[]")

	local vipInfo = vipCsv:getDataByLevel(role:getProperty("vipLevel"))

	-- 7. 扣除刷新次数
	role.dailyData:setProperty("expeditionResetCount", role.dailyData:getProperty("expeditionResetCount") + 1)
	response.leftCnt = vipInfo.expeditionResetCount - role.dailyData:getProperty("expeditionResetCount")

	local bin = pb.encode("ExpeditionResponse", response)
	SendPacket(actionCodes.ExpeditionRestartRes, bin)
end

function ExpeditionAction.updateFormationReq(agent, data)
	local role = agent.role
	local roleId = role:getProperty("id")
	local msg = pb.decode("UpdateYzFormationReq", data)
	role:setProperty("yzFormationJson", msg.yzFormationJson)
	local bin = pb.encode("SimpleEvent", {})
	SendPacket(actionCodes.UpdateYzFormationRes, bin)
end

return ExpeditionAction
