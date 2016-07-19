local EquipAction = {}

function EquipAction.intensify(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local equipId = msg.param1
	local equip = role.equips[equipId]
	if not equip then return end
	local flag = msg.param2

	local weightArray = string.toNumMap(globalCsv:getFieldValue("EquipIntensifyCrit"))
	local vipData = vipCsv:getDataByLevel(role:getProperty("vipLevel"))
	local critWeight = {}
	for levelup = 1, vipData.equipIntensify do
		table.insert(critWeight, { levelup = levelup, weight = weightArray[levelup] })
	end

	local function getLevelUp()
		local index = randWeight(critWeight)
		if index then return critWeight[index].levelup end

		return 1
	end

	local crit = {}
	local oldLevel = equip:getProperty("level")
	local count = 0
	if flag == 1 then 
		--强化
		local costInfo = equipLevelCostCsv:getDataByLevel( oldLevel + 1 )
		if not costInfo then return end
		local spendMoney = costInfo.cost[equip.csvData.star]
		if not role:spendMoney(spendMoney) then
			role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
		else
			local thisLevelUp = getLevelUp()
			table.insert(crit, thisLevelUp)
			equip:upLevel(thisLevelUp)
		end
		count = 1
	else
		--自动强化
		local levelup = 0
		local spendMoney = 0
		local maxLevel = role:getProperty("level") * 2
		while count < flag and oldLevel + levelup < maxLevel do
			local costInfo = equipLevelCostCsv:getDataByLevel( oldLevel + levelup + 1 )
			if not costInfo then break end
			spendMoney = spendMoney + costInfo.cost[equip.csvData.star]
			if not role:checkMoney(spendMoney) then
				spendMoney = spendMoney - costInfo.cost[equip.csvData.star]
				role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
				break	-- 金币不够
			end
			local thisLevelUp = getLevelUp()
			table.insert(crit, thisLevelUp)
			levelup = levelup + thisLevelUp
			count = count + 1
		end
		role:spendMoney(spendMoney)
		equip:upLevel(levelup)
	end
	if oldLevel ~= equip:getProperty("level") then
		role:updateDailyTask(DailyTaskIdMap.equipIntensify, nil, {deltaCount = count})
	end
	local bin = pb.encode("EquipLevelUpData", { level = equip:getProperty("level"), count = count, crit = crit })
    SendPacket(actionCodes.EquipIntensifyResponse, bin)
end

function EquipAction.choose(agent, data)
 	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role
	if msg.param1 == 0 then return end
	local slot = tostring(msg.param1)
	role.slots[slot] = role.slots[slot] or {}
	role.slots[slot].equips = role.slots[slot].equips or {}
	local newEquipId, equipSlot = msg.param2, msg.param3
	local oldEquipId = role.slots[slot].equips[equipSlot]
	
	if newEquipId == 0 then
		--卸下	
		role.slots[slot].equips[equipSlot] = nil
		
	else
		--更换
		local newEquip = role.equips[newEquipId]
		local originSlot = newEquip:getSlot()
		if originSlot ~= 0 then
			role.slots[tostring(originSlot)].equips[equipSlot] = nil
		end
		
		role.slots[slot].equips[equipSlot] = newEquipId
	end
	role:updateSlots()

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
    SendPacket(actionCodes.EquipChooseResponse, bin)
end

function EquipAction.sell( agent, data )
	local msg = pb.decode("EquipActionData", data)
	local role = agent.role

	local sellMoney = 0
	for _, equipId in ipairs(msg.equipIds) do
		local equip = role.equips[equipId]

		if equip then
			local itemData = itemCsv:getItemById(equip:getProperty("type") + Equip2ItemIndex.ItemTypeIndex)
			local sellData = equipLevelCostCsv:getDataByLevel(equip:getProperty("level"))
			if itemData then
				sellMoney = sellMoney + itemData.sellMoney + (sellData.sellMoney[equip.csvData.star] or 0)
			end
			redisproxy:srem(string.format("role:%d:equipIds", role:getProperty("id")), equip:getProperty("id"))
			redisproxy:del(string.format("equip:%d:%d", role:getProperty("id"), equip:getProperty("id")))
		end	
		role.equips[equipId] = nil
		logger.info("r_out_equip", role:logData({
			behavior = "o_eq_sell",
			pm1 = 1, 
			pm2 = equipId,
		}))
	end
	role:gainMoney(sellMoney)

	local bin = pb.encode("EquipActionData", { money = sellMoney })
    SendPacket(actionCodes.EquipSellResponse, bin)
	
end

function EquipAction.fragmentCompose(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local fragmentId = msg.param1
	local num = role.equipFragments[fragmentId]
	if not num then return end
	local csvData = equipCsv:getDataByType(fragmentId - Equip2ItemIndex.FragmentTypeIndex)
	if not csvData or num < csvData.composeNum then return end

	if num == csvData.composeNum then
		role.equipFragments[fragmentId] = nil
		redisproxy:hdel(string.format("role:%d:equipFragments", role:getProperty("id")), tostring(fragmentId))
	else
		role.equipFragments[fragmentId] = num - csvData.composeNum
		redisproxy:hset(string.format("role:%d:equipFragments", role:getProperty("id")), tostring(fragmentId), role.equipFragments[fragmentId])
	end
	role:addEquip({id = fragmentId - Equip2ItemIndex.FragmentTypeIndex})

	local bin = pb.encode("SimpleEvent", { param1 = fragmentId })
	SendPacket(actionCodes.EquipFragmentComposeResponse, bin)
end

function EquipAction.evolution( agent, data )
	local msg = pb.decode("EquipEvolData", data)
	local role = agent.role

	local evolEquip = role.equips[msg.equipId]
	if not evolEquip then return end
	--数据计算
	local addExp, costMoney, returnMoney = 0, 0, 0
	for _, equipId in ipairs(msg.materialEquipIds) do
		local equip = role.equips[equipId]

		if equip then
			local offerExp = equip:getOfferExp()
			addExp = addExp + offerExp
			costMoney = costMoney + offerExp * globalCsv:getFieldValue("equipEvolPerCost")
			returnMoney = returnMoney + equip:getLevelReturnMoney()
		end	
	end

	for _, fragmentId in ipairs(msg.materialFragmentIds) do
		local csvData = equipCsv:getDataByType(fragmentId - Equip2ItemIndex.FragmentTypeIndex)
		local offerExp = csvData.offerExp / csvData.composeNum * tonum(role.equipFragments[fragmentId])
		addExp = addExp + offerExp
		costMoney = costMoney + offerExp * globalCsv:getFieldValue("equipEvolPerCost")
	end

	--检查银币消耗
	if not role:spendMoney(costMoney - returnMoney) then
		role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
		return
	end

	--删掉装备
	for _, equipId in ipairs(msg.materialEquipIds) do
		local equip = role.equips[equipId]

		if equip then
			redisproxy:srem(string.format("role:%d:equipIds", role:getProperty("id")), equip:getProperty("id"))
			redisproxy:del(string.format("equip:%d:%d", role:getProperty("id"), equip:getProperty("id")))
		end	
		role.equips[equipId] = nil
		logger.info("r_out_equip", role:logData({
			behavior = "o_eq_evol",
			pm1 = 1, 
			pm2 = equipId,
		}))
	end
	--删掉碎片
	for _, fragmentId in ipairs(msg.materialFragmentIds) do
		role.equipFragments[fragmentId] = nil
		redisproxy:hdel(string.format("role:%d:equipFragments", role:getProperty("id")), tostring(fragmentId))
		-- TODO:evol消耗装备碎片log
	end

	evolEquip:addEvolExp(addExp)

	local bin = pb.encode("SimpleEvent", { })
    SendPacket(actionCodes.EquipEvolRequest, bin)
	
end

return EquipAction