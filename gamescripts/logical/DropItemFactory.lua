local DropItemFactory = {}

local specialProbability = {
	[0] = 100,
	[1] = 0,
	[2] = 0,
	[3] = 100,
	[4] = 0,
	[5] = 100,
	[6] = 0,
	[7] = 0,
	[8] = 100,
	[9] = 0,
}

-- @deprecated
-- 关卡普掉
-- @param carbonId	关卡ID
-- @param battleStarNum	战斗结果星级
function DropItemFactory.commonDrop(carbonId, battleStarNum)
	local result = {}

	local dropDatas = dropCsv:getDropData(carbonId)
	-- 没有普掉数据
	if not dropDatas or #dropDatas == 0 then return result end

	for _, dropData in ipairs(dropDatas) do

		local propability = dropData.commonDropProbability 
		for count = 1, dropData.commonDropTime do
			if randomFloat(0, 100.0) <= propability then

				-- 取出来的结构都是 { itemId=xxxx, weight = xxxx, }
				local itemWeightArray = unitCsv:getUnitWeightArray({ 
						starWeights = dropData.commonDropStarProbality,
					})
				
				local randIndex = randWeight(itemWeightArray)
				if randIndex then
					result[#result + 1] = {
						itemTypeId = ItemTypeId.Hero,
						itemId = itemWeightArray[randIndex].itemId,
						num = 1,
					}
				end
			end
		end
	end

	itemCsv:mergeItems(result)
	return result
end

-- 关卡特掉
-- @param carbonId	关卡ID
-- @param specialBattleCnt	精英副本次数
function DropItemFactory.specialDrop(carbonId, specialBattleCnt)
	local result = {}

	local dropDatas = dropCsv:getDropData(carbonId)
	-- 没有普掉数据
	if not dropDatas or #dropDatas == 0 then return result end

	for _, dropData in ipairs(dropDatas) do
		for _, drop in pairs(dropData.specialDrop) do
			local index = #result + 1
			local itemInfo = itemCsv:getItemById(tonum(drop[1]))

			local probability = tonum(drop[3])
			if specialBattleCnt and itemInfo.type == ItemTypeId.HeroFragment then
				probability = specialProbability[math.floor(specialBattleCnt % 10)]
			end

			for i = 1, tonum(drop[2]) do
				if randomInt( 0, 100 ) <= probability then
					if not result[index] then
						result[index] = {
							itemTypeId = itemInfo.type,
							itemId = itemInfo.itemId,
							num = 1,
						}
					else
						result[index].num = result[index].num + 1
					end
				end
			end
		end
	end
	itemCsv:mergeItems(result)
	return result
end

-- 礼包掉落
function DropItemFactory.giftDrop(giftDropId, params)
	local result = {}

	local giftDropData = giftDropCsv:getDropData(giftDropId)
	if not giftDropData then return result end

	local giftDropKey = string.format("role:%d:giftDrops", params.roleId)

	-- 设定初始阀值
	local existKey = tonumber(redisproxy:hexists(giftDropKey, giftDropId))
	if existKey == 0 then
		redisproxy:hset(giftDropKey, giftDropId, giftDropData.initThreshold)
	end

	local function getDropItem(itemMap)
		local array = {}
		for _, itemData in pairs(itemMap) do
			table.insert(array, { itemId = itemData[1], weight=itemData[2],itemNum = itemData[3] })
		end

		local randIndex = randWeight(array)
		if randIndex then
			return tonumber(array[randIndex].itemId),array[randIndex].itemNum
		end

		return nil
	end

	local heroNum, leftCount = 0, giftDropData.count
	while leftCount > 0 do
		local threshold = tonumber(redisproxy:hget(giftDropKey, giftDropId))

		if threshold <= giftDropData.specialFloor - 1 then
			-- 普掉
			local item, itemNum = getDropItem(giftDropData.commonItems)
			if item then
				local itemData = itemCsv:getItemById(item)
				if itemData.type == ItemTypeId.Hero then
					if heroNum >= 2 then
						goto continue
					else
						table.insert(result, { itemId = item, num = itemNum}) 
						redisproxy:hset(giftDropKey, giftDropId, tonumber(threshold + 1))

						leftCount = leftCount - 1
						heroNum = heroNum + 1
					end	
				else
					table.insert(result, { itemId = item, num = itemNum}) 
					redisproxy:hset(giftDropKey, giftDropId, tonumber(threshold + 1))

					leftCount = leftCount - 1
				end
			end

		elseif threshold >= giftDropData.specialCeil - 1 then
			-- 特掉
			local item, itemNum
			-- 首次10连抽
			if params.firstDraw then
				item, itemNum = getDropItem(giftDropData.firstDropItems)
			else
				item, itemNum = getDropItem(giftDropData.specialItems)
			end
			if item then table.insert(result, { itemId = item, num = itemNum}) end

			leftCount = leftCount - 1
			redisproxy:hset(giftDropKey, giftDropId, "0")
		else
			-- 普掉
			local item,itemNum = getDropItem(giftDropData.commonItems)
			if item then 
				local itemData = itemCsv:getItemById(item)
				if itemData.type == ItemTypeId.Hero then
					if heroNum >= 2 then
						goto continue
					else
						table.insert(result, { itemId = item, num = itemNum}) 
						redisproxy:hset(giftDropKey, giftDropId, tonumber(threshold + 1))
						
						leftCount = leftCount - 1
						heroNum = heroNum + 1
					end	
				else
					table.insert(result, { itemId = item, num = itemNum}) 
					redisproxy:hset(giftDropKey, giftDropId, tonumber(threshold + 1))
						
					leftCount = leftCount - 1
				end
			end
		end
		::continue::
	end

	return result,tonum(giftDropData.specialCeil - tonumber(redisproxy:hget(giftDropKey, giftDropId)) )
end

return DropItemFactory