local serverId = skynet.getenv "serverid"

local rechargeIdMap = {
	[7] = { order = "2045_0_1_0", name = "yueka" },
	[1] = { order = "2045_0_2_60", name = "60yuanbao" },
	[2] = { order = "2045_0_3_300", name = "300yuanbao" },
	[3] = { order = "2045_0_4_680", name = "680yuanbao" },
	[4] = { order = "2045_0_5_1980", name = "1980yuanbao" },
	[5] = { order = "2045_0_6_3280", name = "3280yuanbao"},
	[6] = { order = "2045_0_7_6480", name = "6480yuanbao" },
}	

local StoreAction = {}

function StoreAction.rechargeRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	if not role then return end

	local rechargeData = rechargeCsv:getRechargeDataById(msg.param1)
	if not rechargeData then
		role:sendSysErrMsg(SYS_ERR_STORE_ITEM_NOT_EXIST)
		return
	end

	--创建订单号
	local orderId = redisproxy:hincrby("autoincrement_set", "order", 1)
	local partnerOrderId = serverId .. "_" -- 服务器id
		.. string.format("%s", orderId) .. "_"	-- 订单号
		.. string.format("%d", rechargeData.id) .. "_"	-- 充值项
		.. string.format("%s", role:getProperty("uid")) -- uid

	local orderKey = string.format("order:%d:%d", role:getProperty("id"), orderId)
	local order = require("datamodel.Order").new({ key = orderKey, order = partnerOrderId })
	order:create()

	-- 如果是player测试
	if msg.param2 == 1 then
		local yuanbaoValue = rechargeData.paidYuanbao 
		if rechargeData.firstYuanbao == 0 or role.firstRecharge[tostring(rechargeData.id)] == 1 then
			yuanbaoValue = yuanbaoValue + rechargeData.freeYuanbao
		else
		 	yuanbaoValue = yuanbaoValue + rechargeData.firstYuanbao
		 	role.firstRecharge[tostring(rechargeData.id)] = 1
		 	role:updateFirstRecharge()
		end

		role:addRechargeRMB(rechargeData.rmbValue, yuanbaoValue)

		if rechargeData.yuekaFlag == 1 then
			--添加月卡
			role:addYueka()
		end
	end

	agent.ignoreHeartbeat = true

	local rechargeConstant = rechargeIdMap[msg.param1]
	local bin = pb.encode("RechargeResponse", { 
		rechargeNO = rechargeConstant.order, 
		orderUUID = partnerOrderId,
		rmbValue = rechargeData.rmbValue,
		productName = rechargeConstant.name 
	})
	SendPacket(actionCodes.StoreRechargeResponse, bin)
end

-- 更新平台订单创建成功时间
function StoreAction.platformNotice(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	if not role then return end

	agent.ignoreHeartbeat = false

	local orderKey = string.format("order:%d:%d", role:getProperty("id"), msg.param2)
	redisproxy:hset(orderKey, "platformTime", msg.param1)
end

function StoreAction.buyCardPackage(agent, data)
	local msg = pb.decode("BuyCardPackageRequest", data)

	local role = agent.role
	if not role then return end

	local awardItemResponse = { awardItems = {}}
	--大于100神将抽卡
	if msg.packageId > 100 then
		local serverId = skynet.getenv "serverid"
		--检查时间
		local index = activityListCsv:inLimitTime(serverId, 2, skynet.time())
		if not index then 
			return 
		end
		local csvData = activityListCsv:getDataByServerId(serverId, 2)
		if not csvData or not csvData[index] then 
			return 
		end
		
		local id = csvData[index].id
		local godCsvData = godHeroCsv:getDataById(id)
		if not godCsvData then return end

		--元宝
		local costYb = globalCsv:getFieldValue("godHeroCost")
		if not role:spendYuanbao(costYb) then
			role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
			return
		end
		logger.info("r_out_yuanbao", role:logData({
			behavior = "o_yb_godhero",
			vipLevel = role:getProperty("vipLevel"),
			pm1 = costYb,
		}))

		for index = 1, 5 do
			local awardItem, num
			if index == 1 then
				role:setProperty("godHeroCount", role:getProperty("godHeroCount") + 1)
				
				if role:getProperty("godHeroCount") % godCsvData.threshold == 0 or math.random(0, 10000) <= godCsvData.rate then
					awardItem = godCsvData.heroType + 1000
					num = 1
				elseif math.random(0, 10000) <= godCsvData.fragRate[2] then
					awardItem = godCsvData.heroType + 2000
					num = godCsvData.fragRate[1]
				else
					local timeData = csvData[index].time
					local startTime = os.time{year=timeData[1].year, month=timeData[1].month, day=timeData[1].day, hour=0, min=0, sec=0}
					local heros = godHeroCsv:getTodayHeros(startTime, id) 
					awardItem = heros[math.random(1, #heros)] + 2000
					num = godCsvData.otherHeroFragNum[randWeight(godCsvData.otherHeroFragNum)].num
				end
			else
				local key = randWeight(godCsvData.otherItems)
				local data = godCsvData.otherItems[key]
				awardItem = data.itemId
				num = data.num
			end
			table.insert(awardItemResponse.awardItems, {
				itemId = awardItem,
				num = num,			
			})
			log_util.log_god_hero(role, awardItem, num)
			role:awardItemCsv(awardItem, { num = num })	
		end
	else	
		local storeCardData = storeCsv:getStoreItemById(msg.packageId)
		if not storeCardData then
			role:sendSysErrMsg(SYS_ERR_STORE_ITEM_NOT_EXIST)
			return 
		end

		-- 新手引导特殊处理
		if msg.guide == 1 and ( msg.packageId == 1 or msg.packageId == 3) then
			local function heroExist(heroType, count)
				return role.heros[heroType]
			end
			if msg.packageId == 3 then
				-- 引导奖励 诸葛果
				local heroType = 25
				if not heroExist(heroType) then
					local heroId = role:awardHero(heroType)
					table.insert(awardItemResponse.awardItems, {
						id = heroId,
						itemTypeId = ItemTypeId.Hero,
						itemId = heroType,
						num = 1,
					})
				end
				local giftDropData = giftDropCsv:getDropData(storeCardData.itemId)
				awardItemResponse.threshold = giftDropData.specialCeil
			elseif msg.packageId == 1 then
				-- 引导奖励
				local heroType = 98
				if not heroExist(heroType) then
					local heroId = role:awardHero(heroType)
					table.insert(awardItemResponse.awardItems, {
						id = heroId,
						itemTypeId = ItemTypeId.Hero,
						itemId = heroType,
						num = 1,
					})
				end

				local giftDropData = giftDropCsv:getDropData(storeCardData.itemId)
				awardItemResponse.threshold = giftDropData.specialCeil
			end
		else
			-- 检查玩家购买上线
			-- 总次数检查
			local totalKey = string.format("store:%d", msg.roleId)
			local totalBuyCount = redisproxy:hget(totalKey, msg.packageId)
			totalBuyCount = totalBuyCount or 0
			if tonum(totalBuyCount) >= storeCardData.totalBuyLimit then
				role:sendSysErrMsg(SYS_ERR_STORE_TOTAL_BUY_LIMIT)
				return
			end

			-- 当天次数
			local dailyKey = string.format("storedaily:%d", msg.roleId)
			local todayBuyCount = redisproxy:hget(dailyKey, msg.packageId)
			if not todayBuyCount then
				-- 没有记录插入新纪录
				local diff = diffTime()
				redisproxy:hset(dailyKey, msg.packageId, 0)
				redisproxy:expire(dailyKey, diff)
				todayBuyCount = 0
			end
			if tonum(todayBuyCount) >= storeCsv:getDayBuyLimit(msg.packageId, role:getProperty("vipLevel")) then
				role:sendSysErrMsg(SYS_ERR_STORE_DAILY_BUY_LIMIT)
				return
			end

			local leftTime
			local startTime = 0
			if msg.packageId == 1 or msg.packageId == 3 then
				startTime = role.timestamps:getProperty("store" .. msg.packageId .. "StartTime")
			end
			leftTime = startTime + storeCardData.freeCd - skynet.time()

			-- local bagHeroBuyCount = redisproxy:hget(string.format("role:%d", role:getProperty("id")), "bagHeroBuyCount")
			-- local bagCount = bagHeroBuyCount * 10
			-- local heroCnts = redisproxy:scard(string.format("role:%d:heroIds", role:getProperty("id")))
			-- if heroCnts >= bagCount + role:getBagHeroLimit() then
			-- 	role:sendSysErrMsg(SYS_ERR_HERO_BAG_LIMIT)
			-- 	return 
			-- end

			local freeCountKey = string.format("card%dDrawFreeCount", msg.packageId)
			if storeCardData.freeCount > 0 and leftTime <= 0 and role.dailyData:getProperty(freeCountKey) < storeCardData.freeCount then
				role.timestamps:setProperty("store" .. msg.packageId .. "StartTime", skynet.time())
				role:notifyUpdateProperty("store" .. msg.packageId .. "LeftTime", 
					role.timestamps:getStoreLeftTime(msg.packageId))

				-- 更新免费次数
				role.dailyData:updateProperty({ field = freeCountKey })
			else
				-- 扣除银币
				if storeCardData.yinbi then
					echoInfo("storeCardData.yinbi=%d", storeCardData.yinbi)
					if not role:spendMoney(storeCardData.yinbi) then
						role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
						return
					end
				end
				

				-- 扣除玩家的金钱
				if storeCardData.yuanbao then
					if not role:spendYuanbao(storeCardData.yuanbao) then
						role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
						return
					end
					-- 记录元宝抽卡流水
					logger.info("r_out_yuanbao", role:logData({
						behavior = "o_yb_buy_card",
		 				vipLevel = role:getProperty("vipLevel"),
						pm1 = storeCardData.yuanbao,
						pm2 = msg.packageId,
						pm3 = 0,
					}))
				end

				--role:addFriendValue(-storeCardData.friendPoint)

				-- 更新次数
				redisproxy:hset(dailyKey, msg.packageId, tonum(todayBuyCount) + 1)
				redisproxy:hset(totalKey, msg.packageId, tonum(totalBuyCount) + 1)

				if msg.packageId == 1 or msg.packageId == 3 then
					role:notifyUpdateProperty("store" .. msg.packageId .. "DailyCount", redisproxy:hget(dailyKey, msg.packageId))
				end
			end

			-- 掉落
			local dropItemFactory = require("logical.DropItemFactory")

			local firstDraw = (tonumber(totalBuyCount) == 0 and (msg.packageId == 4 or msg.packageId ==3))
			awardItemResponse.isfirstDraw = (tonumber(totalBuyCount) == 0 and msg.packageId == 4) and 1000 or 1
			local giftDropItems, threshold = dropItemFactory.giftDrop(storeCardData.itemId, 
				{ roleId = msg.roleId, dropPlace = 4, firstDraw = firstDraw })
			awardItemResponse.threshold = threshold
			
			role:updateDailyTask(DailyTaskIdMap.DrawCard, false, {deltaCount = #giftDropItems})

			local tempAddHeros={}
			for _, dropItem in ipairs(giftDropItems) do
				local itemId = dropItem.itemId
				local heroTrunFrag = 0
				if dropItem.itemTypeId then
					print("dont come here")
					itemId = itemCsv:calItemId(dropItem)
					local heroId = role:awardItemCsv(itemId, {num = dropItem.num})
					table.insert(awardItemResponse.awardItems, {
						itemTypeId = dropItem.itemTypeId,
						itemId = dropItem.itemId,
						num = dropItem.num,
					})
				else
					local itemData = itemCsv:getItemById(dropItem.itemId)
					if itemData.type == ItemTypeId.Hero then
						if tempAddHeros[itemData.heroType] then
							heroTrunFrag = 1
						else
							if role.heros[tonum(itemData.heroType)] then
								heroTrunFrag = 1
							end
						end
						tempAddHeros[itemData.heroType] = true
					end

					table.insert(awardItemResponse.awardItems, {
						itemId = dropItem.itemId,
						num = dropItem.num,	
						heroTrunFrag = heroTrunFrag,			
						})
					log_util.log_buy_card(role, itemId, dropItem.num)
					role:awardItemCsv(itemId, { num = dropItem.num })
				end
			end
		end
	end
	if msg.drawCard then
		local bin = pb.encode("BuyCardPackageResponse", awardItemResponse)
		SendPacket(actionCodes.StoreDrawCardResponse, bin)

		--更新新手引导
		if role:getProperty("guideStep") == 3 then
			role:setProperty("guideStep", 4)
		elseif role:getProperty("guideStep") == 4 then
			role:setProperty("guideStep", 5)
		end

	end
end

function StoreAction.getShopThrosholdRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role
	if not role then return end

	local storeDropData = giftDropCsv:getTotalDropData()
	local keys = table.keys(storeDropData)
	local giftDropKey = string.format("role:%d:giftDrops", msg.roleId)
	local throsholdData={}
	for _,key in ipairs(keys) do
		table.insert(throsholdData,tonum(storeDropData[key].specialCeil)-(redisproxy:hget(giftDropKey,key) or 0))
	end

	-- 元宝十连抽是否为第一次
	local totalKey = string.format("store:%d", msg.roleId)
	local totalBuyCount = redisproxy:hget(totalKey, 4)
	totalBuyCount = totalBuyCount or 0
	local bin = pb.encode("SimpleEvent", { param1 = throsholdData[1], param2 = throsholdData[3], param3 = tonumber(totalBuyCount) })
	SendPacket(actionCodes.StoreGetShopThrosholdResponse, bin)
end

function StoreAction.buyItemRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	if not role then return end

	local storeItemData = storeCsv:getStoreItemById(msg.param1)
	if not storeItemData then 
		role:sendSysErrMsg(SYS_ERR_STORE_ITEM_NOT_EXIST)
		return
	end

	-- 未开放
	if skynet.time() < storeItemData.openDays[1] and skynet.time() > storeItemData.openDays[2] then
		role:sendSysErrMsg(SYS_ERR_STORE_ITEM_CLOSE)
		return
	end

	-- 未开放
	local weekDayFilter = {}
	for _, day in ipairs(storeItemData.weekDays) do
		weekDayFilter[tonumber(day)] = true
	end

	local nowTm = os.date("*t", skynet.time())
	if #weekDayFilter > 0 and not weekDayFilter[nowTm.wday] then
		role:sendSysErrMsg(SYS_ERR_STORE_ITEM_CLOSE)
		return
	end

	-- 总次数检查
	local totalKey = string.format("store:%d", msg.roleId)
	local totalBuyCount = redisproxy:hget(totalKey, msg.param1)
	totalBuyCount = totalBuyCount or 0
	if tonum(totalBuyCount) >= storeItemData.totalBuyLimit then
		role:sendSysErrMsg(SYS_ERR_STORE_TOTAL_BUY_LIMIT)
		return
	end

	-- 当天次数
	local dailyKey = string.format("storedaily:%d", msg.roleId)
	local todayBuyCount = redisproxy:hget(dailyKey, msg.param1)
	if not todayBuyCount then
		-- 没有记录插入新纪录
		local diff = diffTime()
		redisproxy:hset(dailyKey, msg.param1, 0)
		redisproxy:expire(dailyKey, diff)
		todayBuyCount = 0
	end
	if tonum(todayBuyCount) >= storeCsv:getDayBuyLimit(msg.param1, role:getProperty("vipLevel")) then
		role:sendSysErrMsg(SYS_ERR_STORE_DAILY_BUY_LIMIT)
		return
	end

	-- 计算折扣价格
	local yuanbao = storeCsv:getPriceByCount(msg.param1, tonum(totalBuyCount) + 1)
	if not role:spendYuanbao(yuanbao) then
		role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
		return
	end

	-- 记录商场购买流水
	log_util.log_store_expend(role, "1", msg.param1, 1, yuanbao, StoreType.Mall)

	-- 更新次数
	redisproxy:hset(dailyKey, msg.param1, tonum(todayBuyCount) + 1)
	redisproxy:hset(totalKey, msg.param1, tonum(totalBuyCount) + 1)

	-- 道具表
	local itemData = itemCsv:getItemById(storeItemData.itemId)

	role:awardItemCsv(storeItemData.itemId, { num = storeItemData.num })
	log_util.log_store(role, storeItemData.itemId, storeItemData.num, yuanbao)

	local bin = pb.encode("SimpleEvent", {})
	SendPacket(actionCodes.StoreBuyItemResponse, bin)
end

function StoreAction.listItemsRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local filterItems = { items = {} }
	local storeItems = storeCsv:getTabItems(msg.param1)
	for _, storeItemData in ipairs(storeItems) do
		-- 未开放
		local dayOk = false
		dayOk = (skynet.time() >= storeItemData.openDays[1] and skynet.time() <= storeItemData.openDays[2])

		-- 未开放
		local weekDayFilter = {}
		for _, day in ipairs(storeItemData.weekDays) do
			weekDayFilter[tonumber(day)] = true
		end

		local nowTm = os.date("*t", skynet.time())
		local weekDayOk = (#weekDayFilter == 0 or weekDayFilter[nowTm.wday])
		if weekDayOk and dayOk then
			local dailyKey = string.format("storedaily:%d", msg.roleId)
			local totalKey = string.format("store:%d", msg.roleId)
			table.insert(filterItems.items, {
				storeId = storeItemData.id,
				todayBuyCount = tonum(redisproxy:hget(dailyKey, storeItemData.id)),
				totalBuyCount = tonum(redisproxy:hget(totalKey, storeItemData.id)),
			})
		end
	end

	local bin = pb.encode("ShopItemsResponse", filterItems)
	SendPacket(actionCodes.StoreListItemResponse, bin)
end

return StoreAction