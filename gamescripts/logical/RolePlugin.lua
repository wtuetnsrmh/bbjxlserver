local Beauty = require "datamodel.Beauty"

local RolePlugin = {}

function RolePlugin.bind(Role)
	-- 发送系统消息码
	-- @param errCode 错误码
	function Role:sendSysErrMsg(errCode, ...)
		local param1, param2, param3, param4 = unpack({ ... })

		local sysErrorMsg = {
			errCode = errCode,
			param1 = param1,
			param2 = param2,
			param3 = param3,
			param4 = param4,
		}

		local bin = pb.encode("SysErrMsg", sysErrorMsg)
		SendPacket(actionCodes.SysErrorMsg, bin)
	end

	function Role:loadHero(heroId)
		local hero = require("datamodel.Hero").new({ key = string.format("hero:%d:%d", self:getProperty("id"), heroId)})
		if not hero:load() then
			return nil
		end

		hero.skillLevels = json.decode(hero:getProperty("skillLevelJson"))
		hero.battleSoul = json.decode(hero:getProperty("battleSoulJson")) or {}

		if hero:getProperty("delete") ~= 1 then
			hero.owner = self
			self.heros[heroId] = hero
		end

		return hero
	end 

	-- 加载玩家所有的卡牌
	function Role:loadHeros()
		local heroIds = redisproxy:smembers(string.format("role:%d:heroIds", self:getProperty("id")))
		for _, heroId in ipairs(heroIds) do
			self:loadHero(tonum(heroId))	
		end
	end

	-- 玩家获得新的卡牌
	-- @param 卡牌信息
	function Role:addHero(data)
		local heroId = data.type
		local unitData = unitCsv:getUnitByType(data.type)
		if self.heros[heroId] then
			self:addFragments({{fragmentId = data.type + 2000, num = globalCsv:getFieldValue("decomposeFragNum")[unitData.stars]}})
			return heroId, true
		end
		redisproxy:sadd(string.format("role:%d:heroIds", self:getProperty("id")), heroId)
		redisproxy:sadd(string.format("role:%d:heroTypes", self:getProperty("id")), data.type)
		
		local newHeroProperties = {
			key = string.format("hero:%d:%d", self:getProperty("id"), heroId),
			id = heroId,
			type = data.type,
			level = data.level or 1,
			star = data.star or unitData.stars,
			evolutionCount = data.evolutionCount or 0,
		}

		local newHero = require("datamodel.Hero").new(newHeroProperties)
		newHero:create()

		newHero.owner = self
		self.heros[heroId] = newHero

		-- 主动技能等级
		if newHero.unitData.talentSkillId > 0 then
			newHero.skillLevels = { [tostring(newHero.unitData.talentSkillId)] = 1 }

			local skillLevelJson = json.encode(newHero.skillLevels)
    		newHero:setProperty("skillLevelJson", skillLevelJson)
		end

		--全服通告
		if worldNoticeCsv:isConditionFit(worldNoticeCsv.newHero, unitData.stars) then
			local content = worldNoticeCsv:getDesc(worldNoticeCsv.newHero, {playerName = self:getProperty("name"), param1 = unitData.name})
			sendWorldNotice(content)
		end

		return heroId, false
	end

	function Role:loadBeauty(beautyId)
		local beauty = require("datamodel.Beauty").new({ key = string.format("beauty:%d:%d", self:getProperty("id"), beautyId)})
		if not beauty:load() then return nil end

		if beauty:getProperty("delete") ~= 1 then
			beauty.owner = self
			self.beauties[beautyId] = beauty
		end

		return beauty
	end

	-- 加载玩家所有美人
	function Role:loadBeauties()
		local beautyIds = redisproxy:smembers(string.format("role:%d:beautyIds", self:getProperty("id")))
		for _, bid in ipairs(beautyIds) do
			bid = tonumber(bid)
			self:loadBeauty(bid)	
		end
	end

	-- 增加一个美人
	function Role:addBeauty(bid, data)
		data = data or {}

		redisproxy:sadd(string.format("role:%d:beautyIds", self:getProperty("id")), bid)

		local newBeautyProperties = {
			key = string.format("beauty:%d:%d", self:getProperty("id"), bid),
			beautyId = bid,
		}

		for property,value in pairs(data) do
			newBeautyProperties[property] = value
		end

		-- TODO 初始化位置信息
		local newBeauty = require("datamodel.Beauty").new(newBeautyProperties)
		newBeauty:create()

		newBeauty.owner = self
		self.beauties[bid] = newBeauty
	end

	-- 计算玩家给定职业的属性加成值
	function Role:getProfessionBonus(profession)
		if not self.professionBonuses[profession] then
			return {0, 0, 0, 0, 0}
		end

		local phase = self.professionBonuses[profession][1]
		local totalAtkBonus, totalDefBonus, totalHpBonus, totalRestraintBonus, totalLingpaiNum = 0, 0, 0, 0, 0
		for p = 1, phase do
			-- atk
			local lMax = p < phase and 4 or self.professionBonuses[profession][2]
			for l = 1, lMax do
				local levelData = professionLevelCsv:getDataByLevel(profession, p, l)
				totalAtkBonus = totalAtkBonus + levelData.atkBonus
				totalLingpaiNum = totalLingpaiNum + levelData.lingpaiNum
			end

			-- def
			local lMax = p < phase and 4 or self.professionBonuses[profession][3]
			for l = 1, lMax do
				local levelData = professionLevelCsv:getDataByLevel(profession, p, l)
				totalDefBonus = totalDefBonus + levelData.defBonus
				totalLingpaiNum = totalLingpaiNum + levelData.lingpaiNum
			end

			-- hp
			local lMax = p < phase and 4 or self.professionBonuses[profession][4]
			-- 等级加成
			for l = 1, lMax do
				local levelData = professionLevelCsv:getDataByLevel(profession, p, l)
				totalHpBonus = totalHpBonus + levelData.hpBonus
				totalLingpaiNum = totalLingpaiNum + levelData.lingpaiNum
			end

			-- restraint
			local lMax = p < phase and 4 or self.professionBonuses[profession][5]
			for l = 1, lMax do
				local levelData = professionLevelCsv:getDataByLevel(profession, p, l)
				totalRestraintBonus = totalRestraintBonus + levelData.restraintBonus
				totalLingpaiNum = totalLingpaiNum + levelData.lingpaiNum
			end

			-- 进阶加成
			if p < phase then
				local phaseData = professionPhaseCsv:getDataByPhase(profession, p)
				totalAtkBonus = totalAtkBonus + phaseData.atkBonus
				totalDefBonus = totalDefBonus + phaseData.defBonus
				totalHpBonus = totalHpBonus + phaseData.hpBonus
				totalRestraintBonus = totalRestraintBonus + phaseData.restraintBonus

				totalLingpaiNum = totalLingpaiNum + phaseData.lingpaiNum
			end
		end
		return { totalAtkBonus, totalDefBonus, totalHpBonus, totalRestraintBonus, totalLingpaiNum }
	end


	-- 加载玩家背包物品
	function Role:loadItems()
		local itemIds = redisproxy:smembers(string.format("role:%d:items", self:getProperty("id")))
		for _, itemId in ipairs(itemIds) do
			itemId = tonumber(itemId)
			local item = require("datamodel.Item").new({ key = string.format("item:%d:%d", self:getProperty("id"), itemId)})
			item:load()
			item.owner = self
			self.items[itemId] = item
		end
	end

	-- 增加或减少一个物品
	function Role:addItem(data)
		if not self.items[data.id] then
			redisproxy:sadd(string.format("role:%d:items", self:getProperty("id")), data.id)

			local newItemProperties = {
				key = string.format("item:%d:%d", self:getProperty("id"), data.id),
				id = data.id,
			}
			local newItem = require("datamodel.Item").new(newItemProperties)
			newItem:create()
			newItem.owner = self
			self.items[data.id] = newItem
			self.items[data.id]:addCount(data.count, data.notNotifyClient)
		else
			self.items[data.id]:addCount(data.count, data.notNotifyClient)
		end
	end


	-- 加载玩家所有的装备
	function Role:loadEquips()
		local equipIds = redisproxy:smembers(string.format("role:%d:equipIds", self:getProperty("id")))
		for _, equipId in pairs(equipIds) do
			equipId = tonumber(equipId)
			local equip = require("datamodel.Equip").new({ key = string.format("equip:%d:%d", self:getProperty("id"), equipId)})
			equip:load()
			equip.owner = self
			self.equips[equipId] = equip
		end
	end

	-- 玩家获得新的装备
	-- @param 装备信息
	function Role:addEquip(data)
		local equipId = redisproxy:hincrby("autoincrement_set", "equip", 1)
		redisproxy:sadd(string.format("role:%d:equipIds", self:getProperty("id")), equipId)

		local newEquipProperties = {
			key = string.format("equip:%d:%d", self:getProperty("id"), equipId),
			id = equipId,
			type = data.id,
			level = data.level or 1,
		}
		local newEquip = require("datamodel.Equip").new(newEquipProperties)
		newEquip:create()
		newEquip.owner = self
		self.equips[equipId] = newEquip

		-- 将装备信息发送给客户端		
		local bin = pb.encode("EquipDetail", {id = equipId, type = newEquipProperties.type, level = newEquipProperties.level})
		SendPacket(actionCodes.EquipLoadDataSet, bin)

		return equipId
	end

	function Role:addEquipFragments(fragments)
		local fragmentsKey = string.format("role:%d:equipFragments", self:getProperty("id"))
		local fragmentsData = { fragments = {} }
		for _, fragmentUnit in ipairs(fragments) do
			local origNum = redisproxy:hget(fragmentsKey, fragmentUnit.fragmentId) or 0
			self.equipFragments[fragmentUnit.fragmentId] = tonumber(origNum) + fragmentUnit.num
			redisproxy:hset(fragmentsKey, fragmentUnit.fragmentId, tonumber(origNum) + fragmentUnit.num)

			table.insert(fragmentsData.fragments, { fragmentId = fragmentUnit.fragmentId, num = fragmentUnit.num})
		end

		-- 将装备信息发送给客户端
		if not fragments.notNotifyClient then
			local bin = pb.encode("FragmentList", fragmentsData)
			SendPacket(actionCodes.EquipFragmentLoadDataSet, bin)
		end
	end

	function Role:loadEquipFragments()
		local fragments = redisproxy:hgetall(string.format("role:%d:equipFragments", self:getProperty("id")))

		for id, num in pairs(fragments) do
			self.equipFragments[tonumber(id)] = tonumber(num)
		end
	end

	function Role:loadCarbon(carbonId)
		local carbon = require("datamodel.Carbon").new({ key = string.format("carbon:%d:%d", self:getProperty("id"), carbonId)})
		if not carbon:load() then
			return nil
		end

		-- mapId可计算，所以不用存储在数据库
		local mapId = math.floor(carbonId / 100)
		carbon:setProperty("mapId", mapId)
		self.carbons[carbonId] = carbon
		self.mapCarbons[mapId] = self.mapCarbons[mapId] or {}
		self.mapCarbons[mapId][carbonId] = true

		-- 加载地图数据
		local mapId = math.floor(carbonId / 100)
		if not self.maps[mapId] then
			local map = require("datamodel.Map").new({ key = string.format("map:%d:%d", self:getProperty("id"), mapId)})
			map:load()
			self.maps[mapId] = map
		end

		return carbon
	end

	-- 加载所有的副本信息
	function Role:loadCarbons()
		local carbonIds = redisproxy:smembers(string.format("role:%d:carbonIds", self:getProperty("id")))
		for _, carbonId in ipairs(carbonIds) do
			carbonId = tonumber(carbonId)
			self:loadCarbon(carbonId)	
		end
	end

	-- 增加新的副本信息
	-- @param data 副本信息
	function Role:addCarbon(data)
		redisproxy:sadd(string.format("role:%d:carbonIds", self:getProperty("id")), data.carbonId)

		local newCarbonProperties = {
			key = string.format("carbon:%d:%d", self:getProperty("id"), data.carbonId),
			id = data.carbonId,
			mapId = math.floor(data.carbonId / 100),
			starNum = data.starNum,
			status = data.status,
		}

		-- 创建新的数据库记录
		local newCarbon = require("datamodel.Carbon").new(newCarbonProperties)
		newCarbon:create()
		self.carbons[data.carbonId] = newCarbon

		-- 产生新地图
		local mapId = math.floor(data.carbonId / 100)
		self.mapCarbons[mapId] = self.mapCarbons[mapId] or {}
		self.mapCarbons[mapId][data.carbonId] = true
		
		if not self.maps[mapId] then
			local newMapProperties = {
				key = string.format("map:%d:%d", self:getProperty("id"), mapId),
				mapId = mapId,
			}

			local newMap = require("datamodel.Map").new(newMapProperties)
			newMap:create()

			self.maps[mapId] = self.maps[mapId] or {}
			self.maps[mapId] = newMap
		end

		return data.carbonId
	end

	function Role:updateCarbon(carbonId, data)
		local carbon = self.carbons[carbonId]
		if carbon == nil then return end

		-- 战斗成功才更新副本信息
		if data.code == "Failure" then return end

		carbon:setProperty("starNum", data.starNum)
		carbon:setProperty("status", 1)
		carbon:save()

		-- 开启新的副本关卡
		local newCarbons = mapBattleCsv:getCarbonByPrev(self:getProperty("level"), carbonId)
		for _, carbonInfo in ipairs(newCarbons) do
			local data = {carbonId = carbonInfo.carbonId, status = 0, starNum = 0}
			self:addCarbon(data)
		end
	end

	function Role:addFragments(fragments)
		local fragmentsKey = string.format("role:%d:fragments", self:getProperty("id"))
		local fragmentsData = { fragments = {} }
		for _, fragmentUnit in ipairs(fragments) do
			local origNum = redisproxy:hget(fragmentsKey, fragmentUnit.fragmentId) or 0
			self.fragments[fragmentUnit.fragmentId] = tonumber(origNum) + fragmentUnit.num
			if self.fragments[fragmentUnit.fragmentId] == 0 then
				redisproxy:hdel(fragmentsKey, fragmentUnit.fragmentId)
			else
				redisproxy:hset(fragmentsKey, fragmentUnit.fragmentId, self.fragments[fragmentUnit.fragmentId])
			end

			table.insert(fragmentsData.fragments, { fragmentId = fragmentUnit.fragmentId, num = fragmentUnit.num})
		end

		-- 将英雄信息发送给客户端
		if not fragments.notNotifyClient then
			local bin = pb.encode("FragmentList", fragmentsData)
			SendPacket(actionCodes.FragmentLoadDataSet, bin)
		end
	end

	function Role:loadFragments()
		local fragments = redisproxy:hgetall(string.format("role:%d:fragments", self:getProperty("id")))

		for id, num in pairs(fragments) do
			self.fragments[tonumber(id)] = tonumber(num)
		end
	end

	-- 奖励武将
	-- @param itemId
	-- @param params	额外信息(例如奖励来源等)
	function Role:awardHero(itemId, params)
		params = params or {}
		if itemId <= 0 then return end

		local heroResponse = {}
		heroResponse.heros = {}

		local newHeroId, exist = self:addHero({ 
			type = itemId,
			level = params.level,
			evolutionCount = params.evolutionCount 
		})

		if exist then
			return newHeroId
		end

		local newHero = self.heros[newHeroId]
		if newHero then
			table.insert(heroResponse.heros, newHero:pbData())
		end

		-- 记录日志
		if #heroResponse.heros == 0 then return end

		-- 将英雄信息发送给客户端	
		local bin = pb.encode("HeroResponse", heroResponse)
		SendPacket(actionCodes.HeroLoadDataSet, bin)

		return newHeroId
	end

	function Role:addTodayPvpCnt(pvpCnt)
		self:setTodayPvpCnt(self:getProperty("todayPvpCount") + pvpCnt)
		return true
	end

	function Role:resetCarbon()
		for carbonId, carbon in pairs(self.carbons) do
			carbon:setProperty("playCnt", 0)
			carbon:setProperty("buyCnt", 0)
		end
	end

	function Role:setLoginDay(dateYm, day)
		local roleId = self:getProperty("id")
		local loginStr = redisproxy:hget("role:"..roleId..":login", dateYm)
		loginStr = loginStr or ""

		-- 补齐没登陆的天数，为0
		local len = day - (string.len(loginStr) + 1)
		if len > 0 then
			loginStr = loginStr..string.rep(0, len)	
		end
		-- 今天登录了设置为1
		loginStr = loginStr..1
		redisproxy:hset("role:"..roleId..":login", dateYm, loginStr)
	end

	function Role:getGiftDrops(giftDropIds, params)
		params = params or {}
		
		params.roleId = self:getProperty("id")

		local totalItems = {}
		for _, giftDropId in pairs(giftDropIds) do
			local giftItems = require("logical.DropItemFactory").giftDrop(tonumber(giftDropId), params)
			for _, itemInfo in pairs(giftItems) do
				if itemInfo.itemTypeId then
					itemInfo.itemId = itemCsv:calItemId(itemInfo)
				end

				self:awardItemCsv(itemInfo.itemId, {notNotifyClient = false})

				table.insert(totalItems, itemInfo)
			end
		end

		return itemCsv:mergeItems(totalItems)
	end

	function Role:refreshShopByIndex(indies)
		local response = { shopDatas = {} }
		for _, index in ipairs(indies) do
			local randomItems = shopCsv:randomShopIds(index, self:getProperty("level"))
			local jsonValue = json.encode(randomItems)
			local jsonKey = string.format("shop%dItemsJson", index)
			self:setProperty(jsonKey, jsonValue)

			local time = skynet.time()
			local nowTm = os.date("*t", time)
			local nexttime = shopOpenCsv:getNextRefreshTime(index, nowTm.day, time)

			self.timestamps:setProperty(string.format("lastShop%dTime", index), nexttime)

			response.shopDatas[#response.shopDatas + 1] = {
				shopIndex = index,
				refreshLeftTime = self.timestamps:getShopLeftTime(index),
				shopItemsJson = self:getProperty(jsonKey)
			}
		end

		local bin = pb.encode("RoleShopDataResponse", response)
		SendPacket(actionCodes.RoleShopRefresResponse, bin)	
	end

	function Role:refreshActivityListTime()
		local serverId = skynet.getenv "serverid"
		local curServerActivityList = { activityTimeList={} }
		curServerActivityList.activityTimeList=activityListCsv:getDataStrListByServerId(tonum(serverId))

		local bin = pb.encode("SimpleEvent", {param5=json.encode(curServerActivityList)})
		SendPacket(actionCodes.RoleGetActivityTimeListRespose, bin)
	end

	-- 从道具表给玩家添加物品
	function Role:awardItemCsv(itemId, params)
		params = params or {}
		
		local itemInfo = itemCsv:getItemById(tonum(itemId))
		if not itemInfo then return false end

		if itemInfo.type == ItemTypeId.Gift then
			self:getGiftDrops(itemInfo.giftDropIds, params)

		elseif itemInfo.type == ItemTypeId.GoldCoin then
			self:gainMoney(itemInfo.money * (params.num or 1), params)

		elseif itemInfo.type == ItemTypeId.Yuanbao then
			self:gainYuanbao(itemInfo.yuanbao * (params.num or 1), params)

		elseif itemInfo.type == ItemTypeId.ZhanGong then
			self:addZhangongNum(itemInfo.zhangong * (params.num or 1), params)

		elseif itemInfo.type == ItemTypeId.Hero then
			for index = 1, (params.num or 1) do
				self:awardHero(itemInfo.heroType, params)
			end

		elseif itemInfo.type == ItemTypeId.HeroFragment then
			self:addFragments({{ fragmentId = itemInfo.heroType + 2000, num = params.num or 1 }, notNotifyClient = params.notNotifyClient})

		elseif itemInfo.type == ItemTypeId.Skill then

		elseif itemInfo.type == ItemTypeId.Lingpai then
			self:addLingpaiNum(params.num, params)

		elseif itemInfo.type == ItemTypeId.StarSoul then
			self:addStarSoulNum(params.num, params)

		elseif itemInfo.type == ItemTypeId.HeroSoul then
			self:addHeroSoulNum(params.num, params)
			
		elseif itemInfo.type == ItemTypeId.Equip then
			params.id = itemId - Equip2ItemIndex.ItemTypeIndex
			self:addEquip(params)

		elseif itemInfo.type == ItemTypeId.EquipFragment then
			self:addEquipFragments({{ fragmentId = tonumber(itemId), num = params.num or 1 }, notNotifyClient = params.notNotifyClient})		

		elseif itemCsv:isItem(itemInfo.type) then
			self:addItem({ id = tonumber(itemId), count = params.num or 1, notNotifyClient = params.notNotifyClient })

		elseif itemInfo.type == ItemTypeId.Reputation then
			self:addReputation(params.num, params)
		end

		return true
	end

	-- 创建一个新的礼包给玩家
	function Role:addGift(params)
		local itemCsvData = itemCsv:getItemById(params.itemId)
		if not itemCsvData then return end

		local giftId = redisproxy:hincrby("autoincrement_set", "gift", 1)
		redisproxy:sadd(string.format("role:%d:giftIds", self:getProperty("id")), giftId)

		local newGiftProperties = {
			key = string.format("gift:%d:%d", self:getProperty("id"), giftId),
			id = giftId,
			itemId = params.itemId,
			createTime = skynet.time(),
		}

		local newGift = require("datamodel.Gift").new(newGiftProperties)
		newGift:create()

		return giftId
	end

	function Role:handlePurchase(params)
		local rechargeId, oid, dtime = params['rechargeId'], params['oid'], params['dtime']
		
		local rechargeData = rechargeCsv:getRechargeDataByRmb(tonumber(params["amount"]))
		if not rechargeData then
			self:sendSysErrMsg(SYS_ERR_STORE_ITEM_NOT_EXIST)
			return
		end

		local yuanbaoValue = rechargeData.paidYuanbao 
		if rechargeData.firstYuanbao == 0 or self.firstRecharge[tostring(rechargeData.id)] == 1 then
			yuanbaoValue = yuanbaoValue + rechargeData.freeYuanbao
		else
		 	yuanbaoValue = yuanbaoValue + rechargeData.firstYuanbao
		 	self.firstRecharge[tostring(rechargeData.id)] = 1
		 	self:updateFirstRecharge()
		end

		self:addRechargeRMB(rechargeData.rmbValue, yuanbaoValue)

		redisproxy:zincrby("rmbRank", rechargeData.rmbValue, self:getProperty("id"))

		logger.info("r_in_yuanbao", self:logData({
			behavior = "i_yb_rechange",
			pm1 = yuanbaoValue,
			pm2 = rechargeId,
			pm3 = math.floor(params['amount']),
			str1 = oid,
			tstamp = dtime,
		}))

		if rechargeData.yuekaFlag == 1 then
			--添加月卡
			self:addYueka()
		end

		local rechargeResult = { param1 = yuanbaoValue, }
		local bin = pb.encode("SimpleEvent", rechargeResult)
		SendPacket(actionCodes.StoreRechargeResult, bin)
	end

	-- 登录时更新玩家体力值
	function Role:loginUpdateHealth(loginTime)
		local lastHealthTime = self.timestamps:getProperty("lastHealthTime")

		local deltaValue = 0
		while loginTime - lastHealthTime > Role.UpdateHealthTimer do
			deltaValue = deltaValue + 1
			lastHealthTime = lastHealthTime + Role.UpdateHealthTimer
		end
		local real_val = self:recoverHealth(deltaValue, { time = true })
		if real_val > 0 then
			logger.info("r_in_health", self:logData({
				behavior = "i_hl_return",
				pm1 = real_val,
				pm2 = 2, -- offline
			}))
		end
		-- 保证恢复时间没有截断的片段
		self.timestamps:setProperty("lastHealthTime", lastHealthTime)
	end

	-- 计算玩家给定职业的属性加成值
	function Role.sGetProfessionBonus(roleId, profession, professionBonuses)
		if not professionBonuses then
			local professionData = redisproxy:hget(string.format("role:%d", roleId), "professionData")
			professionBonuses = json.decode(professionData)
		end

		if not professionBonuses[profession] then
			return { 0, 0, 0, 0 }
		end

		local phase = professionBonuses[profession][1]
		local totalAtkBonus, totalDefBonus, totalHpBonus, totalRestraintBonus, totalLingpaiNum = 0, 0, 0, 0, 0
		for p = 1, phase do
			-- atk
			local lMax = p < phase and 4 or professionBonuses[profession][2]
			for l = 1, lMax do
				local levelData = professionLevelCsv:getDataByLevel(profession, p, l)
				totalAtkBonus = totalAtkBonus + levelData.atkBonus
				totalLingpaiNum = totalLingpaiNum + levelData.lingpaiNum
			end

			-- def
			local lMax = p < phase and 4 or professionBonuses[profession][3]
			for l = 1, lMax do
				local levelData = professionLevelCsv:getDataByLevel(profession, p, l)
				totalDefBonus = totalDefBonus + levelData.defBonus
				totalLingpaiNum = totalLingpaiNum + levelData.lingpaiNum
			end

			-- hp
			local lMax = p < phase and 4 or professionBonuses[profession][4]
			-- 等级加成
			for l = 1, lMax do
				local levelData = professionLevelCsv:getDataByLevel(profession, p, l)
				totalHpBonus = totalHpBonus + levelData.hpBonus
				totalLingpaiNum = totalLingpaiNum + levelData.lingpaiNum
			end

			-- restraint
			local lMax = p < phase and 4 or professionBonuses[profession][5]
			for l = 1, lMax do
				local levelData = professionLevelCsv:getDataByLevel(profession, p, l)
				totalRestraintBonus = totalRestraintBonus + levelData.restraintBonus
				totalLingpaiNum = totalLingpaiNum + levelData.lingpaiNum
			end

			-- 进阶加成
			if p < phase then
				local phaseData = professionPhaseCsv:getDataByPhase(profession, p)
				totalAtkBonus = totalAtkBonus + phaseData.atkBonus
				totalDefBonus = totalDefBonus + phaseData.defBonus
				totalHpBonus = totalHpBonus + phaseData.hpBonus
				totalRestraintBonus = totalRestraintBonus + phaseData.restraintBonus

				totalLingpaiNum = totalLingpaiNum + phaseData.lingpaiNum
			end
		end
		return { totalAtkBonus, totalDefBonus, totalHpBonus, totalRestraintBonus, totalLingpaiNum }
	end

	function Role.sGetNextStarAttrId(starPoint)
		if (starPoint % 100 + 1) > 12 then
			local nextMapType = math.floor(starPoint / 100) + 1
			local nextMapData = heroStarInfoCsv:getDataByType(nextMapType)
			if not nextMapData then
				return nil
			end

			return nextMapType * 100 + 1
		end

		return starPoint + 1
	end

	function Role.sCalStarAttrBonuses(roleId, starPoint)
		if not starPoint then 
			starPoint = tonumber(redisproxy:hget(string.format("role:%d", roleId), "starPoint"))
		end

		local attrBonuses = { [1] = {}, [2] = {}, [3] = {}, [4] = {} }
		-- 1 = 血, 2 = 攻, 3 = 防
		local starAttrName = { [1] = "hp", [2] = "atk", [3] = "def" }

		local beginPoint = 101
		if beginPoint > starPoint then return attrBonuses end

		while true do
			local starAttrData = heroStarAttrCsv:getDataById(beginPoint)
			attrBonuses[starAttrData.camp][starAttrName[starAttrData.attrId] .. "Bonus"] = 
				attrBonuses[starAttrData.camp][starAttrName[starAttrData.attrId] .. "Bonus"] or 0
			attrBonuses[starAttrData.camp][starAttrName[starAttrData.attrId] .. "Bonus"] = 
				attrBonuses[starAttrData.camp][starAttrName[starAttrData.attrId] .. "Bonus"] + starAttrData.attrValue

			beginPoint = Role.sGetNextStarAttrId(beginPoint)
			if not beginPoint or beginPoint > starPoint then
				break
			end
		end

		return attrBonuses
	end

	function Role.sGetBeautyBonusValues(roleId)
		-- 出战美人
		local hpBonus,atkBonus,defBonus = 0,0,0

		local beautyIds = redisproxy:smembers(string.format("role:%d:beautyIds", roleId))
		for _, beautyId in pairs(beautyIds) do
			local beautyInfo = redisproxy:hmget(string.format("beauty:%d:%d", roleId, beautyId),
				"beautyId", "level", "evolutionCount", "status", "potentialHp", "potentialAtk", 
				"potentialDef")
			if tonumber(beautyInfo[4]) == Beauty.STATUS_FIGHT or tonumber(beautyInfo[4]) == Beauty.STATUS_REST then
				local beautyData = beautyListCsv:getBeautyById(tonumber(beautyInfo[1]))
				local curBeautyLevel = tonumber(beautyInfo[2]) + (tonumber(beautyInfo[3]) - 1) * beautyData.evolutionLevel

				local hpAdd = ( beautyData.hpInit + beautyData.hpGrow * (curBeautyLevel - 1 ) + tonumber(beautyInfo[5])) * globalCsv:getFieldValue("beautyHpFactor")
				local atkAdd = ( beautyData.atkInit + beautyData.atkGrow * (curBeautyLevel - 1 ) + tonumber(beautyInfo[6])) * globalCsv:getFieldValue("beautyAtkFactor")
				local defAdd = ( beautyData.defInit + beautyData.defGrow * (curBeautyLevel - 1 ) + tonumber(beautyInfo[7])) * globalCsv:getFieldValue("beautyDefFactor")

				hpBonus = hpBonus + hpAdd
				atkBonus = atkBonus + atkAdd
				defBonus = defBonus + defAdd
			end
		end

		return {hpBonus = hpBonus, atkBonus = atkBonus, defBonus = defBonus}
	end

	function Role.sGetFightBeautySkills(roleId)
		local skills, beauties = {}, {}

		local beautyIds = redisproxy:smembers(string.format("role:%d:beautyIds", roleId))
		for _, beautyId in pairs(beautyIds) do
			local beautyInfo = redisproxy:hmget(string.format("beauty:%d:%d", roleId, beautyId),
				"beautyId", "level", "evolutionCount", "status", "potentialHp", "potentialAtk", 
				"potentialDef") 
			if tonumber(beautyInfo[4]) == Beauty.STATUS_FIGHT then
				local beautyData = beautyListCsv:getBeautyById(tonumber(beautyInfo[1]))

				local evolutionCount = tonumber(beautyInfo[3])
				if evolutionCount == 1 then
					table.insert(skills, beautyData.beautySkill1)
				elseif evolutionCount == 2 then
					table.insertTo(skills, {beautyData.beautySkill1, beautyData.beautySkill2})
				else
					table.insertTo(skills, {beautyData.beautySkill1, beautyData.beautySkill2, beautyData.beautySkill3})
				end

				table.insert(beauties, 
					{ 
						beautyId = tonumber(beautyInfo[1]),
						level = tonumber(beautyInfo[2]),
						evolutionCount = tonumber(beautyInfo[3]),
						status = tonumber(beautyInfo[4]),
						potentialHp = tonumber(beautyInfo[5]),
						potentialAtk = tonumber(beautyInfo[6]),
						potentialDef = tonumber(beautyInfo[7]),
					})
			end
		end

		return skills, beauties
	end


	function Role:updateDailyTask(taskId, recv, params)
		local params = params or {}
		local DailyTaskField = {
			[1] = "commonCarbonCount",
			[2] = "specialCarbonCount",
			[3] = "heroIntensifyCount",
			[4] = "pvpBattleCount",
			[5] = "techLevelUpCount",
			[6] = "beautyTrainCount",
			[7] = "towerBattleCount",
			[8] = "heroStarCount",
			[9] = "legendBattleCount",
			[10] = "zhaoCaiCount",
			[11] = "yuekaCount",
			[13] = "equipIntensifyCount",
			[14] = "drawCardCount",
			[15] = "trainCarbonCount",
			[16] = "expeditionCount",
		}
		local finishCount = self.dailyData:getProperty(DailyTaskField[taskId])
		-- 如果小于0, 表示已经领过奖励, 不需要再统计
		if finishCount < 0 then return end
		
		if not recv then
			local deltaCount = params.deltaCount or 1
			self.dailyData:setProperty(DailyTaskField[taskId], finishCount + deltaCount)
			self:notifyUpdateProperty(DailyTaskField[taskId], finishCount + deltaCount, finishCount)
		else
			self.dailyData:setProperty(DailyTaskField[taskId], -finishCount)
			self:notifyUpdateProperty(DailyTaskField[taskId], -finishCount, finishCount)
		end
	end

	function Role:saveAll()
		self:save()

		for _, carbon in pairs(self.carbons) do
			carbon:save()
		end

		for _, hero in pairs(self.heros) do
			hero:save()
		end
	end

	function Role:sendPvpUpAward(rank, t)
		local bestRank = self:getProperty("pvpBestRank")
		if rank >= bestRank then return end
		local old = pvpUpCsv:findGradeByRank(bestRank)
		local new = pvpUpCsv:findGradeByRank(rank)
		local award = 0
		if old.id == new.id then
			award = (bestRank-rank)*new.step + new.extra
		else
			-- 先计算边界
			award = (bestRank-old.max)*old.step
			award = award + (new.min-rank+1)*new.step + new.extra

			for i = new.id+1, old.id-1 do
				local data = pvpUpCsv:getDataById(i)
				award = award + (data.min-data.max+1)*data.step
			end
		end
		award = math.floor(award)
		t.oldBestRank = bestRank
		t.bestRank = rank
		t.yuanbao = award
		redisproxy:runScripts("insertEmail", 6, self:getProperty("id"), globalCsv:getFieldValue("pvpUpEmailId"), skynet.time(),
			rank, bestRank-rank, award)
		self:setProperty("pvpBestRank", rank)
	end

	function Role:resetTowerData()
		local towerDataKey = string.format("role:%d:towerData", self:getProperty("id"))
		redisproxy:del(towerDataKey)
		self.towerData = nil
	end

	Role.UpdateHealthTimer = dailyGiftCsv.m_data[3].condition * 60	-- 间隔时长
	Role.UpdateHealthValue = dailyGiftCsv.m_data[3].donateHealth    -- 增加量

	function Role:checkNewEvent()
		local roleId = self:getProperty("id")

		local eventNotifyResponse = { newEvents = {} }
		-- 检查新邮件
		local emailIds = redisproxy:lrange(string.format("role:%d:emailIds", roleId), 0, 19)
		for _, id in ipairs(emailIds) do
			local status = redisproxy:hget(string.format("email:%d:%s", roleId, id), "status")
			if tonum(status) == 0 then
				table.insert(eventNotifyResponse.newEvents, { key = "email", value = 1 })
				break
			end	
		end

		-- 检查好友相关
		-- 1 申请消息
		local applicationNum = redisproxy:hlen(string.format("role:%d:friendApplications", roleId))	
		if tonum(applicationNum) > 0 then
			table.insert(eventNotifyResponse.newEvents, { key = "friendApplication", value = 1 })
		end

		-- 2 可领取体力
		local recvHealthKey = string.format("role:%d:receivedHealth:%s", roleId, os.date("%Y%m%d"))
		local donatedRoleIds = redisproxy:hkeys(recvHealthKey)
		for _, donatedRoleId in ipairs(donatedRoleIds) do
			local status = redisproxy:hget(recvHealthKey, donatedRoleId)
			if tonum(status) == 0 then
				table.insert(eventNotifyResponse.newEvents, { key = "friendHealth", value = 1 })
				break
			end
		end

		-- 3. 可吃鸡腿
		local eatTime = 0
		local hour = tonumber(os.date("%H"))
		if hour > 13 then
			eatTime = self.dailyData:getProperty("eatChickenCountPM")
		else
			eatTime = self.dailyData:getProperty("eatChickenCountAM")
		end

		if (hour >= 12 and hour < 14) or (hour >= 18 and hour < 20) then
			if eatTime == 0 then
				table.insert(eventNotifyResponse.newEvents, { key = "eatChicken", value = 1 })
			end
		else
			table.insert(eventNotifyResponse.newEvents, { key = "eatChicken", value = -200 })
		end

		-- 4. 可免费抽卡
		local packageIds = { 1, 3 }
		for _, packageId in ipairs(packageIds) do
			local storeCardData = storeCsv:getStoreItemById(packageId)
			local startTime = self.timestamps:getProperty("store" .. packageId .. "StartTime")
			local leftTime = startTime + storeCardData.freeCd - skynet.time()

			local freeCountKey = string.format("card%dDrawFreeCount", packageId)
			if storeCardData.freeCount > 0 and leftTime <= 0 and self.dailyData:getProperty(freeCountKey) < storeCardData.freeCount then
				table.insert(eventNotifyResponse.newEvents, { key = "freeDrawCard", value = 1 })
				break
			end
		end

		-- 5. 可签到
		local nowTm = os.date("*t")
		local signKey = string.format("role:%d:login:%s", roleId, os.date("%Y%m"))
		if redisproxy:getbit(signKey, nowTm.day) == 0 then
			table.insert(eventNotifyResponse.newEvents, { key = "sign", value = 1 })
		end

		-- 6. 可领取首充
		if self:getProperty("firstRechargeAwardState") == 1 then
			table.insert(eventNotifyResponse.newEvents, { key = "firstRechargeAwardState", value = 1 })
		end

		-- 7. 可领取累充
		local serverId = skynet.getenv "serverid"
		if activityListCsv:inLimitTime(serverId,1,skynet.time()) then
			local used=false
			
			for i=1,5 do
				used=self.rechargeGifts[i]==1
				if self:getProperty("rechargeRMB") >= tonum(ljczCsv:getDataById(i).accumulatedRech) and (not used) then
					table.insert(eventNotifyResponse.newEvents, { key = "accumulatedRechargeState", value = 1 })
					break
				end
			end
			
		end

		-- 8.买vip0礼包
		local storeItems = storeCsv:getTabItems(3)
		local vip0Data = storeItems[1]
		local buyCount = tonum(redisproxy:hget(string.format("store:%d", roleId), vip0Data.id))
		if vip0Data.totalBuyLimit > buyCount then
			table.insert(eventNotifyResponse.newEvents, { key = "vip0Gift", value = 1 })
		end
		
		if #eventNotifyResponse.newEvents > 0 then
			local bin = pb.encode("NewMessageNotify", eventNotifyResponse)
			SendPacket(actionCodes.RoleNotifyNewEvents, bin)
		end
	end
end

return RolePlugin