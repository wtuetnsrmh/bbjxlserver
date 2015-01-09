local serverId = skynet.getenv "serverid"

local RoleAction = {}

local function getPackageName(packageName)
	local defaultValue = "com.dangge.xinsanguozhi"

	packageName = packageName or ""
	return packageName == "" and deltaValue or packageName
end

-- 随机玩家名
local function randomRoleName()
	local function validName(name)
		-- body
		local SERV = string.format("G_FUNCTIONS%d", math.random(1, 8))

		local exist = redisproxy:exists(string.format("user:%s", name))
		local legal = skynet.call(SERV, "lua", "check_words", name)

		return (not exist) and legal
	end

	local name = nameDictCsv:randomName()
	
	-- 过滤已经存在的名字
	while not validName(name) do
		name = nameDictCsv:randomName()
	end

	return name
end

function RoleAction.randomNameRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local name = randomRoleName()

	local bin = pb.encode("RoleDetail", { name = name })
	SendPacket(actionCodes.RoleRandomNameResponse, bin)
end

function RoleAction.create(agent, data)
	local openserv = redisproxy:hget("autoincrement_set", "server_start")
	local openTime = toUnixtime(openserv .. "04")
	
	local msg = pb.decode("RoleCreate", data)
	local uid = msg.uid
	local user = randomRoleName()
	local heroType = 1

	-- 临时保存客户端包名
	agent.packageName = msg.packageName
	agent.deviceId = msg.deviceId

	local response = {}

	--获取角色ID，并创建角色
	roleId = redisproxy:hincrby("autoincrement_set", "role", 1)
	local newRole = require("datamodel.Role").new({
		key = string.format("role:%d", roleId), 
		id = roleId,
		uid = uid,
		name = user,
		uname = msg.uname,
	})
	if newRole:create() then
		--更新USER表
		redisproxy:set(string.format("user:%s", user), roleId)
		redisproxy:set(string.format("uid:%d", uid), user)
		newRole:setProperty('uid', uid)
		response.result = "SUCCESS"
		response.roleId = roleId
		response.roleName = user
	else
		response.result = "DB_ERROR"
		local bin = pb.encode("RoleCreateResponse", response)

		SendPacket(actionCodes.RoleCreateResponse, bin)
		return 
	end

	logger.info('r_create', newRole:logData({d_id = msg.deviceId}))

	-- 运营商日志
	local platform_logs = {}
	table.insert(platform_logs, string.sub(newRole:getProperty("uid"), 1, -3))
	table.insert(platform_logs, newRole:getProperty("id"))
	local ip = agent.ip or "127.0.0.1"
	table.insert(platform_logs, string.sub(ip, 1, (string.find(ip, ":") or 0) - 1))
	table.insert(platform_logs, skynet.time())
	table.insert(platform_logs, newRole:getProperty("uname"))
	table.insert(platform_logs, 2045)
	table.insert(platform_logs, serverId)
	table.insert(platform_logs, getPackageName(agent.packageName))
	table.insert(platform_logs, agent.deviceId)
	logger.warning(table.concat(platform_logs, "\t"))

	-- 给角色自动加载当前副本数据
	local newCarbons = mapBattleCsv:getCarbonByMap(101)
	for _, carbonInfo in ipairs(newCarbons) do
		if carbonInfo.openLevel <= newRole:getProperty("level") and carbonInfo.prevCarbonId == 0 then 
			local data = {carbonId = carbonInfo.carbonId, status = 0, starNum = 0}
			newRole:addCarbon(data)
		end
	end

	-- 出生道具
	local birthItemCsv = require("csv.BirthItemCsv")
	birthItemCsv:load("csv/birth.csv")
	for itemId, data in pairs(birthItemCsv.m_data) do
		log_util.log_born_award(newRole, itemId, data.num)
		newRole:awardItemCsv(itemId, { num = data.num })	
	end

	-- 选择的主将
	local firstHeroId = newRole:addHero({ type = heroType })
	newRole:setProperty("mainHeroId", firstHeroId)
	newRole.heros[firstHeroId]:setProperty("choose", 1)
	newRole.chooseHeroIds[firstHeroId] = true
	newRole:updateChooseHeroIds()

	newRole.slots["1"] = {heroId = firstHeroId}
	newRole:setProperty("slotsJson", json.encode(newRole.slots))

	-- 设置阵型
	local pveFormation = { [1] = firstHeroId }
	newRole:setProperty("pveFormationJson", json.encode(pveFormation))

	-- 设置技能顺序
	newRole.skillOrder = { [1] = firstHeroId }
	newRole:setProperty("skillOrderJson", json.encode(newRole.skillOrder))

	-- 设置新手引导
	newRole:setProperty("guideStep", 2)

	-- 加载当天数据
	local dailyKey = string.format("role:%d:daily", roleId)
	newRole.dailyData = require("datamodel.RoleDaily").new({ key = dailyKey })
	newRole.dailyData:create()
	newRole.dailyData:refreshDailyData(newRole)

	local deltaDay = function(timeA, timeB)
		return (timeB - timeA) / 86400 + 1
	end

	local bin = pb.encode("RoleCreateResponse", response)
	SendPacket(actionCodes.RoleCreateResponse, bin)
end

--登录角色
-- 1. 检查角色在数据库是否存在
-- 2. 检查role 对象是否存在
-- 2a. 否，创建role对象,并加载数据
-- 3. 刷新数据
-- 4. 组装登录包发送客户端
function RoleAction.login(agent, data)
	local msg = pb.decode("RoleLoginData", data)
	local response = {}

	-- 临时保存客户端包名
	agent.packageName = msg.packageName ~= "" and msg.packageName or "com.dangge.xinsanguozhi"
	agent.deviceId = msg.deviceId

	-- 1.
	local roleId = redisproxy:get(string.format("user:%s", msg.name))
	if roleId == nil then
		response.result = "NOT_EXIST"
		local bin = pb.encode("RoleLoginResponse", response)
		SendPacket(actionCodes.RoleLoginResponse, bin)

		return
	end

	local now = skynet.time()

	local nowTm = os.date("*t", now)

	roleId = tonumber(roleId)

	local role = agent.role
	-- 2
	if not role then
		-- 2a
		role = require("datamodel.Role").new({ key = string.format("role:%d", roleId )})
		if role:load() == false then
			response.result = "DB_ERROR"
			local bin = pb.encode("RoleLoginResponse", response)
			SendPacket(actionCodes.RoleLoginResponse, bin)
			return
		end			

		-- 2a1. 加载时间管理
		role.timestamps = require("datamodel.RoleTimestamps").new({ key = string.format("role:%d:timestamps", roleId) })
		role.timestamps:load()
		role.timestamps.owner = role

		-- 2a2. 加载玩家的英雄数据
		role:loadHeros()

		-- 上场武将
		local chooseHeroIds = json.decode(role:getProperty("chooseHeroIds")) or {}
		for _, heroId in ipairs(chooseHeroIds) do
			role.chooseHeroIds[heroId] = true
		end	

		local mainHeroId = role:getProperty("mainHeroId")
		role.mainHeroType =  role.heros[mainHeroId]:getProperty("type")

		-- 2a3. 加载玩家的美人数据
		role:loadBeauties()

		-- 2a4. 加载玩家的物品数据
		role:loadItems()

		-- 2a5. 加载玩家的装备数据
		role:loadEquips()

		-- 2a6. 加载玩家的装备碎片数据
		role:loadEquipFragments()

		-- 2a7. 加载碎片
		role:loadFragments()

		-- 2a8. 加载当天数据
		local dailyKey = string.format("role:%d:daily", roleId)
		role.dailyData = require("datamodel.RoleDaily").new({ key = dailyKey })
		role.dailyData.owner = role		

		if not role.dailyData:load() then
			role.dailyData:create()
		end	

		-- 2a9. 加载玩家的地图和副本数据
		role:loadCarbons()
	end

	role.levelGifts = json.decode(role:getProperty("levelGiftsJson")) or {}
	role.serverGifts = json.decode(role:getProperty("serverGiftsJson")) or {}
	role.fund = json.decode(role:getProperty("fundJson")) or {}
	role.slots = json.decode(role:getProperty("slotsJson")) or {}
	role.pveFormation = json.decode(role:getProperty("pveFormationJson")) or {}
	role.partners = json.decode(role:getProperty("partnersJson")) or {}
	role.rechargeGifts = json.decode(role:getProperty("rechargeGiftsJson")) or {}
	role.firstRecharge = json.decode(role:getProperty("firstRechargeJson")) or {}
	role.skillOrder = json.decode(role:getProperty("skillOrderJson")) or {}

	local heros = {}
	for heroId, hero in pairs(role.heros) do
		if hero:getProperty("type") > 0 then
			table.insert(heros, hero:pbData())
		end
	end
	response.heros = heros

	local beauties = {}
	for bid, beauty in pairs(role.beauties) do
		if beauty:getProperty("beautyId") > 0 then
			table.insert(beauties, beauty:pbData())
		end
	end
	response.beauties = beauties

	local items = {}
	for itemId, item in pairs(role.items) do
		table.insert(items, item:pbData())
	end
	response.items = items

	local equips = {}
	for equipId, equip in pairs(role.equips) do
		table.insert(equips, equip:pbData())
	end
	response.equips = equips

	local equipFragments = {}
	for fragmentId, num in pairs(role.equipFragments) do
		table.insert(equipFragments, { fragmentId = fragmentId, num = num })
	end
	response.equipFragments = equipFragments

	local fragments = {}
	for fragmentId, num in pairs(role.fragments) do
		table.insert(fragments, { fragmentId = fragmentId, num = num })
	end
	response.fragments = fragments

	local carbons, maps = {}, {}
	for carbonId, carbon in pairs(role.carbons) do
		table.insert(carbons, carbon:pbData())
	end
	for mapId, map in pairs(role.maps) do
		table.insert(maps, map:pbData())
	end
	response.carbons = carbons
	response.maps = maps

	-- 3.
	role:loginUpdateHealth(now)	-- 恢复体力

	local dateYm = os.date("%Y%m", now)
	-- 玩家当前月登陆的天数 1010101010101
	local monthSignDay = ""
	for day = 1, 31 do
		monthSignDay = monthSignDay .. redisproxy:getbit(string.format("role:%d:login:%s", roleId, dateYm), day)
	end

	-- 如果是今天第一次登录
	local firstLogin = not isToday(role:getProperty("lastLoginTime"))
	if true then
		-- 公告
		local notices = {}
		for id, data in pairs(noticeCsv.m_data) do
			if data.order ~= 0 then
				local notice = {}
				notice.order = data.order
				notice.title = data.title
				notice.content = data.contentPath ~= "" and io.readfile("res/" .. data.contentPath) or nil
				-- print(notice.content, data.contentPath)
				table.insert(notices, notice)
			end
		end
		table.sort(notices, function(a, b) return a.order < b.order end) 
		response.notices = notices
	end

	-- 重置日常数据
	local nextResetTime = role:getProperty("nextResetDailyTime")
	if now >= nextResetTime then
		-- 设置登录天数
		role:setProperty("loginDays", role:getProperty("loginDays") + 1)

		-- 重置副本
		role:resetCarbon()
		local carbons, maps = {}, {}
		for carbonId, carbon in pairs(role.carbons) do
			table.insert(carbons, carbon:pbData())
		end
		for mapId, map in pairs(role.maps) do
			table.insert(maps, map:pbData())
		end
		response.carbons = carbons
		response.maps = maps

		-- 设置登录天数string
		role:setLoginDay(dateYm, nowTm.day)

		-- 刷新每日数据
		role.dailyData:refreshDailyData(role)
		local _, nextResetTime = diffTime({hour = RESET_TIME})
		role:setProperty("nextResetDailyTime", nextResetTime)

		role:resetTowerData()

		-- 刷新名将
		role:getNextLegendCardonIdIndex()
	end

	role.professionBonuses = require("shared.json").decode(role:getProperty("professionData"))

	--玩家信息同步到客户端的数据
	response.result = "SUCCESS"
	response.roleInfo = role:pbData()
	response.roleInfo.monthSignDay = monthSignDay
	response.serverTime = now
	response.dailyData = role.dailyData:pbData()
	response.timestamps = role.timestamps:pbData()

	local logdata = role:logData({
		vipLevel = role:getProperty("vipLevel"),
		level = role:getProperty("level"),
		behavior = "login_success",
		d_id = msg.deviceId,
	})
	logger.info("r_login", logdata)

	-- 运营商日志
	local platform_logs = {}
	table.insert(platform_logs, string.sub(role:getProperty("uid"), 1, -3))
	table.insert(platform_logs, role:getProperty("id"))
	table.insert(platform_logs, role:getProperty("uname"))
	local ip = agent.ip or "127.0.0.1"
	table.insert(platform_logs, string.sub(ip, 1, (string.find(ip, ":") or 0) - 1))
	table.insert(platform_logs, now)
	table.insert(platform_logs, 2045)
	table.insert(platform_logs, serverId)
	table.insert(platform_logs, getPackageName(agent.packageName))
	table.insert(platform_logs, agent.deviceId)
	logger.notice(table.concat(platform_logs, "\t"))

	local bin = pb.encode("RoleLoginResponse", response)
	SendPacket(actionCodes.RoleLoginResponse, bin)

	role:refreshActivityListTime()

	-- 更新在线角色列表
	role:setProperty("session", agent.client_fd)
	role:setProperty("lastLoginTime", now)

	datacenter.set("agent", roleId, { 
		serv = skynet.self(),
		fd = client_fd,
	})

	agent.role = role

	-- 开启定时器
	start_agent_timer()

	-- 注册
	local w_channel = datacenter.get("MC_W_CHANNEL")
	if w_channel then
		mcast_util:sub_world(w_channel)
	end
end

function RoleAction.activeSuccess(agent, data)
	local role = agent.role

	local platform_logs = {}
	table.insert(platform_logs, string.sub(role:getProperty("uid"), 1, -3))
	table.insert(platform_logs, role:getProperty("id"))
	local ip = agent.ip or "127.0.0.1"
	table.insert(platform_logs, string.sub(ip, 1, (string.find(ip, ":") or 0) - 1))
	table.insert(platform_logs, skynet.time())
	table.insert(platform_logs, role:getProperty("uname"))
	table.insert(platform_logs, 2045)
	table.insert(platform_logs, serverId)
	logger.alert(table.concat(platform_logs, "\t"))
end

function RoleAction.loadHeroReq(agent, data)
	local role = agent.role
	if not role then return end
	local heroData = {}
	for heroId, hero in pairs(role.heros) do
		if hero:getProperty("type") > 0 then
			table.insert(heroData, hero:pbData())
		end
	end
	local bin = pb.encode("RoleLoadHeroPost", { heros = heroData })
	SendPacket(actionCodes.RoleLoadHeroPost, bin)
end

-- 客户端更新玩家属性
function RoleAction.updateProperty(agent, data)
	local msg = pb.decode("RoleUpdateProperty", data)

	local role = agent.role
	if not role then return end

	if msg.key == "pveFormationJson" then
		role.pveFormation = json.decode(msg.newValue)
	end

	if msg.key == "skillOrderJson" then
		role.skillOrder = json.decode(msg.newValue)
	end

	role:setProperty(msg.key, msg.newValue)
end

function RoleAction.shopRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local response = { shopDatas = {} }

	local now = skynet.time()
	local nowTm = os.date("*t", now)
	for index = msg.param1, msg.param2 do
		-- 商店1
		role[string.format("shop%dItems", index)] = json.decode(role:getProperty(string.format("shop%dItemsJson", index)))
		if role.timestamps:getShopLeftTime(index) <= 0 then
			local randomItems = shopCsv:randomShopIds(index, role:getProperty("level"))
			role[string.format("shop%dItems", index)] = randomItems

			local nexttime = shopOpenCsv:getNextRefreshTime(index, nowTm.day, now)

			role.timestamps:setProperty(string.format("lastShop%dTime", index), nexttime)

			role:setProperty(string.format("shop%dItemsJson", index), json.encode(randomItems))
		end
		response.shopDatas[#response.shopDatas + 1] = {
			shopIndex = index,
			refreshLeftTime = role.timestamps:getShopLeftTime(index),
			shopItemsJson = role:getProperty(string.format("shop%dItemsJson", index))
		}
	end

	local bin = pb.encode("RoleShopDataResponse", response)
	SendPacket(actionCodes.RoleShopResponse, bin)
end

function RoleAction.shopBuyRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local jsonField = string.format("shop%dItemsJson", msg.param1)
	local shopItems = json.decode(role:getProperty(jsonField))

	local exist=false
	local existIndex
	for index,item in pairs(shopItems) do
		if item.shopId==tostring(msg.param2) then
			exist=true
			existIndex=index
		end
	end

	if not exist then
		role:sendSysErrMsg(SYS_PVP_SHOP_BUY_EXPIRE)
		return
	end

	local itemNum = tonum(msg.param3)
	if itemNum <= 0 then
		role:sendSysErrMsg(SYS_PVP_SHOP_BUY_AGAIN)
		return
	end

	local shopData = shopCsv:getShopData(msg.param2)
	if not shopData then return end

	local PriceMap = {
		["1"] = { field = "yuanbao", errCode = SYS_ERR_YUANBAO_NOT_ENOUGH },
		["2"] = { field = "money", errCode = SYS_ERR_MONEY_NOT_ENOUGH },
		["3"] = { field = "zhangongNum", errCode = SYS_ERR_ZHAOCAI_COUNT_NOT_ENOUGH },
		["4"] = { field = "heroSoulNum", errCode = SYS_ERR_UNKNOWN },
		["5"] = { field = "reputation", errCode = SYS_ERR_UNKNOWN },
		["6"] = { field = "starSoulNum", errCode = SYS_ERR_STAR_SOUL_NOT_ENOUGH },
	}

	local priceKey = shopItems[existIndex].priceType
	local totalPrice = shopData.price[priceKey] * itemNum
	if role:getProperty(PriceMap[priceKey].field) < totalPrice then
		role:sendSysErrMsg(PriceMap[priceKey].errCode)
		return
	end
	-- 负数表示已经购买过的
	shopItems[existIndex].num = -itemNum
	role:setProperty(jsonField, json.encode(shopItems))

	if priceKey == "1" then
		role:spendYuanbao(totalPrice)
	elseif priceKey == "2" then
		role:spendMoney(totalPrice)
	elseif priceKey == "3" then
		role:addZhangongNum(-totalPrice)
	elseif priceKey == "4" then
		role:addHeroSoulNum(-totalPrice)
	elseif priceKey == "5" then
		role:addReputation(-totalPrice)
	elseif priceKey == "6" then
		role:addStarSoulNum(-totalPrice)
	end
	log_util.log_store_expend(role, priceKey, shopData.itemId, itemNum, totalPrice, msg.param1)

	role:awardItemCsv(shopData.itemId, { num = itemNum })

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
	SendPacket(actionCodes.RoleShopBuyResponse, bin)	
end

function RoleAction.shopRefreshRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local now = skynet.time()
	local nowTm = os.date("*t", now)
	local index = msg.param1

	local cost = shopOpenCsv:getCostValue(index, role.dailyData:getProperty(string.format("shop%dRefreshCount", index)))

	-- 先消耗名将刷新符
	if not role.items[52] or role.items[52]:getProperty("count") <= 0 then
		if not role:spendYuanbao(cost) then
			role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
			return
		end
		logger.info("r_out_yuanbao", role:logData({
			behavior = "o_yb_store_fresh",
			vipLevel = role:getProperty("vipLevel"),
			pm1 = cost,
			pm2 = index,
		}))
		role.dailyData:updateProperty({ field = string.format("shop%dRefreshCount", index)})
	else
		role:addItem({ id = 52, count = -1})
	end
	

	local response = { shopDatas = {} }

	if index >= 1 and index <= 7 then
		-- 商店1
		local randomItems = shopCsv:randomShopIds(index, role:getProperty("level"))
		role[string.format("shop%dItems", index)] = randomItems

		local nexttime = shopOpenCsv:getNextRefreshTime(index, nowTm.day, now)
		role.timestamps:setProperty(string.format("lastShop%dTime", index), nexttime)

		role:setProperty(string.format("shop%dItemsJson", index), json.encode(randomItems))
		response.shopDatas[#response.shopDatas + 1] = {
			shopIndex = index,
			refreshLeftTime = role.timestamps:getShopLeftTime(index),
			shopItemsJson = role:getProperty(string.format("shop%dItemsJson", index))
		}
	end


	local bin = pb.encode("RoleShopDataResponse", response)
	SendPacket(actionCodes.RoleShopRefresResponse, bin)	
end

function RoleAction.bornHeroRequest(agent, data)
	local msg = pb.decode("RoleBornRequest", data)

	local role = agent.role

	local firstHeroId = role:addHero({ type = msg.heroType })
	role:setProperty("mainHeroId", firstHeroId)
	role.heros[firstHeroId]:setProperty("choose", 1)
	role.chooseHeroIds[firstHeroId] = true
	role:updateChooseHeroIds()

	role.slots["1"] = {heroId = firstHeroId}
	role:updateSlots()

	-- 设置阵型
	local pveFormation = { [1] = firstHeroId }
	role:setProperty("pveFormationJson", json.encode(pveFormation))

	-- 设置技能顺序
	role.skillOrder[1] = firstHeroId
	roel:updateSkillOrder()

	-- 设置新手引导
	role:setProperty("guideStep", 2)

	local bin = pb.encode("RoleBornResponse", { result = "SUCCESS" })
	SendPacket(actionCodes.RoleBornHeroResponse, bin)
end

function RoleAction.decomposeFragmentRequest(agent, data)
	local msg = pb.decode("DecomposeFragment", data)

	local role = agent.role

	msg.stars = msg.stars or {}
	msg.fragmentIds = msg.fragmentIds or {}

	if table.nums(role.fragments) == 0 then
		role:loadFragments()
	end

	local totalSoulNum = 0
	for index, fragmentId in pairs(msg.fragmentIds) do
		local unitData = unitCsv:getUnitByType(math.floor(fragmentId - 2000))
		if unitData then
			totalSoulNum = totalSoulNum + globalCsv:getFieldValue("fragmentToSoul") * role.fragments[fragmentId]
			logger.info("r_out_fragment", role:logData({
				behavior = "o_fg_resolve", 
				pm1 = role.fragments[fragmentId],
				pm2 = fragmentId,
			}))
		end

		role.fragments[fragmentId] = nil
		redisproxy:hdel(string.format("role:%d:fragments", msg.roleId), tostring(fragmentId))
	end
	role:addHeroSoulNum(totalSoulNum)
	logger.info("r_in_herosoul", role:logData({
		behavior = "i_hs_resolve",
		pm1 = totalSoulNum,
	}))


	SendPacket(actionCodes.FragmentDecomposeResponse, data)
end

function RoleAction.buyHeroBySoul(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local shopData = legendShopCsv:getShopData(msg.param1)
	if not shopData then return end

	if role:getProperty("heroSoulNum") < shopData.soulPrice then
		return
	end

	role:addHeroSoulNum(-shopData.soulPrice)
	role:awardHero(shopData.heroType)
end

function RoleAction.fragmentExchangeRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local unitData = unitCsv:getUnitByType(math.floor(msg.param1 - 2000))
	local needFragmentNum = globalCsv:getComposeFragmentNum(unitData.stars)
	if needFragmentNum > role.fragments[msg.param1] then
		return 
	end

	role:addFragments({{ fragmentId = msg.param1, num = -needFragmentNum }})

	role:awardHero(msg.param1 - 2000)

	logger.info("r_in_hero", role:logData({
		behavior = "i_hr_compose",
		pm1 = 1,
		pm2 = msg.param1 - 2000
	}))

	logger.info("r_out_fragment", role:logData({
		behavior = "o_fg_compose", 
		pm1 = needFragmentNum,
		pm2 = msg.param1,
	}))

	local bin = pb.encode("SimpleEvent", { param1 = msg.param1 })
	SendPacket(actionCodes.FragmentExchangeResponse, bin)
end

function RoleAction.washTechPointReqeust(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local yuanbao = globalCsv:getFieldValue("washTechNeedYuanbao")

	if not role:spendYuanbao(yuanbao) then
		role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
		return
	end

	logger.info("r_out_yuanbao", role:logData({
		behavior = "o_yb_tech_wash",
		vipLevel = role:getProperty("vipLevel"),
		pm1 = yuanbao,
	}))

	local lingpaiConsumeNum = 0
	local professionIds = {1, 3, 4, 5}
	for _, profession in ipairs(professionIds) do
		local professionBonuses = role:getProfessionBonus(profession)
		lingpaiConsumeNum = lingpaiConsumeNum + professionBonuses[5]
	end

	role.professionBonuses = clone(DefaultRoleValues.professionData)
	role:updateProfessionData()
	role:addLingpaiNum(lingpaiConsumeNum)
	
	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
	SendPacket(actionCodes.TechWashPointResponse, bin)
end

function RoleAction.promoteTechPhaseRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local profession = msg.param1
	local professionData = role.professionBonuses[profession]
	if not professionData then return end

	if professionData[1] >= 4 then 
		return 
	end

	local levelSum = professionData[2] + professionData[3] + professionData[4] + professionData[5]
	if levelSum < 16 then 
		return
	end

	-- 消耗令牌
	local phaseData = professionPhaseCsv:getDataByPhase(profession, professionData[1])
	if role:getProperty("lingpaiNum") < phaseData.lingpaiNum then
		role:sendSysErrMsg(SYS_ERR_LINGPAI_NOT_ENOUGH)
		return
	end
	role:addLingpaiNum(-phaseData.lingpaiNum)

	role.professionBonuses[profession] = { professionData[1] + 1, 0, 0, 0, 0}
	role:updateProfessionData()

	local bin = pb.encode("SimpleEvent", { param1 = profession, param2 = professionData[1] + 1 })
	SendPacket(actionCodes.TechPhasePromoteResponse, bin)
end

function RoleAction.techLevelupRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local profession = msg.param1
	local professionData = role.professionBonuses[profession]
	if not professionData then return end

	local curLevel = professionData[msg.param2 + 1]
	if curLevel >= 4 then return end

	local levelData = professionLevelCsv:getDataByLevel(profession, professionData[1], curLevel + 1)
	if role:getProperty("lingpaiNum") < levelData.lingpaiNum then
		role:sendSysErrMsg(SYS_ERR_LINGPAI_NOT_ENOUGH)
		return
	end
	role:addLingpaiNum(-levelData.lingpaiNum)
	logger.info("r_out_lingpai", role:logData({
		behavior = "o_lp_tech_up",
		pm1 = levelData.lingpaiNum,
		pm2 = profession,
		pm3 = msg.param2 + 1,
	}))

	role.professionBonuses[profession][msg.param2 + 1] = curLevel + 1
	role:updateProfessionData()
	role:updateDailyTask(DailyTaskIdMap.TechLevelUp)

	local bin = pb.encode("SimpleEvent", { param1 = msg.param2, param2 = curLevel + 1 })
	SendPacket(actionCodes.TechLeveupResponse, bin)
end
--将星：
function RoleAction.promoteStarHeroRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local curStarPoint = role:getProperty("starPoint")
	local nextStarPoint = role.sGetNextStarAttrId(curStarPoint)
	if not nextStarPoint then return end

	if msg.param1 ~= nextStarPoint then return end

	local starHeroAttrData = heroStarAttrCsv:getDataById(msg.param1)
	if not starHeroAttrData then return end

	if role:getProperty("starSoulNum") < starHeroAttrData.starSoulNum then
		role:sendSysErrMsg(SYS_ERR_STAR_SOUL_NOT_ENOUGH)	
		return
	end
	if not role:spendMoney(starHeroAttrData.moneyNum) then
		role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
		return
	end

	role:setStarPoint(nextStarPoint)
	role:addStarSoulNum(-starHeroAttrData.starSoulNum)
	role:updateDailyTask(DailyTaskIdMap.HeroStar)

	logger.info("r_out_starsoul", role:logData({
		behavior = "o_ss_star_up",
		pm1 = starHeroAttrData.starSoulNum,
		pm2 = nextStarPoint,
	}))

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId })
	SendPacket(actionCodes.StarHeroPromoteResponse, bin)
end

function RoleAction.chatSendRequest(agent, data)
	local msg = pb.decode("ChatMsg", data)

	local role = agent.role

	local chatType = msg.chatType
	-- local toName = msg.player.name
	local content = msg.content

	local time = skynet.time()

	local response_error = function (errCode)
		local bin = pb.encode("ChatMsg", {err = errCode})
		SendPacket(actionCodes.ChatReceiveResponse, bin)
	end

	if time <= role:getProperty("silent") then
		if time + 5 < role:getProperty("silent") then
			response_error(SYS_ERR_CHAT_SILENT)
		else
			response_error(SYS_ERR_CHAT_TOO_FAST)
		end
		return
	end

	local servId = role:getProperty("id") % G_SERV_COUNT 
	local SERV = string.format("G_FUNCTIONS%d", servId)
	-- 检查敏感字符
	local ok = skynet.call(SERV, "lua", "check_words", content)
	if not ok then
		response_error(SYS_ERR_CHAT_ILL_WORD)	
		return	
	end

	local player = {
		name = role:getProperty("name"),
		vipLevel = role:getProperty("vipLevel"),
		mainId = role:getProperty("mainHeroId"),
		level = role:getProperty("level"),
		roleId = role:getProperty("id"),
	}

	local from = {
		chatType = chatType,
		player = player,
		content = content,
		tstamp = time,
	}

	if player.level < globalCsv:getFieldValue("chatLevelLimit") then 
		response_error(SYS_ERR_CHAT_LVL_LIMIT)
		return
	end

	if chatType == ChatType.World then
		local count = role.dailyData:getProperty("worldChatCount")
		if tonum(msg.gold) ~= 1 and count > globalCsv:getFieldValue("worldChatLimit") then 
			response_error(SYS_ERR_CHAT_W_CNT_LIMIT)
			return
		end
		if tonum(msg.gold) == 1 then
			if not role:spendYuanbao(5) then
				role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
				return 
			end
			logger.info("r_out_yuanbao", role:logData({
				behavior = "o_yb_chat", 
				vipLevel = role:getProperty("vipLevel"),
				pm1 = 5,
			}))	
		end	
		role.dailyData:setProperty("worldChatCount", count + 1)
		role:notifyUpdateProperty("worldChatCount", count + 1)
		local bin = pb.encode("ChatMsg", from)
		mcast_util:pub_world(actionCodes.ChatReceiveResponse, bin)
	elseif chatType == ChatType.P2P then
		-- mcast_util:pub_person(source, target, from)
	end
	role:setProperty("silent", time + 5)
end

function RoleAction.digestInfoRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	local roleDbData = redisproxy:runScripts("loadRoleInfo", 1, msg.roleId)

	-- 判断是否为好友
	local isFriend = 0
	if msg.param1 and msg.param1 == 1 then
		local friendIds = redisproxy:smembers(string.format("role:%d:friends", role:getProperty("id")))
		for _, friendIdStr in ipairs(friendIds) do
			local friendId = tonumber(friendIdStr)
			if friendId == msg.roleId then
				isFriend = 1
				break
			end
		end
	end

	--装备
	local tempSlotsJson=json.decode(tostring(roleDbData[6]))
	local returnEquips={}
	local returnAssiSlots={}
	for _,slotsJson in pairs(tempSlotsJson) do
		if slotsJson.equips then
			for _,equip in pairs(slotsJson.equips) do
				if tonumber(equip) then
					local key=string.format("equip:%d:%d", tonumber(msg.roleId), tonumber(equip))
					local newEquipProperties =redisproxy:hmget(key,
					 "id", "type", "level")
					local temp={
						id=tonumber(newEquipProperties[1]),
						type=tonumber(newEquipProperties[2]),
						level=tonumber(newEquipProperties[3])
						}
					table.insert(returnEquips,temp)
				end
			end
		end

		--副将
		if slotsJson.assistants then
			for _,slotsId in pairs(slotsJson.assistants) do
				local tempSlots={}
				tempSlots.id=tonum(slotsId)
				tempSlots.type=tonum(redisproxy:hget(string.format("hero:%d:%d",tonumber(msg.roleId),tempSlots.id),"type"))
				table.insert(returnAssiSlots,tempSlots)
			end
		end
	end

	local response = {}
	response.roleInfo = {
		name = roleDbData[1],
		level = tonum(roleDbData[2]),
		pvpRank = tonum(roleDbData[3]),
		lastLoginTime = tonum(roleDbData[5]),
		slotsJson=tostring(roleDbData[6]),
		partnersJson = tostring(roleDbData[7]),
	}
	response.equips=returnEquips

	response.assisoldier=returnAssiSlots

	-- pvp 机器人
	if msg.roleId <= 10000 then
		local nowTm = os.date("*t", skynet.time())
		response.roleInfo.lastLoginTime = os.time({ 
			year = nowTm.year, month = nowTm.month, day = nowTm.day,
			hour = randomInt(0, nowTm.hour),
			min = randomInt(0, nowTm.min),
			sec = randomInt(0, nowTm.sec),
		})
	end

	local Hero = require "datamodel.Hero"
	response.heros = {}
	local start, interval = 8, 6
	for index = start, interval*5+start-1, interval do
		if not roleDbData[index] then break end

		if tonumber(roleDbData[index]) == tonumber(roleDbData[4]) then
			response.roleInfo.mainHeroType = tonum(roleDbData[index + 1])
		end
		table.insert(response.heros, { id=tonum(roleDbData[index]),type = tonum(roleDbData[index + 1]), evolutionCount = tonum(roleDbData[index + 2]),
		 wakeLevel = tonum(roleDbData[index + 3]),level=tonum(roleDbData[index + 4]), star = tonum(roleDbData[index + 5]),
		 attrsJson=json.encode(Hero.sGetTotalAttrValues(tonumber(msg.roleId), tonumber(roleDbData[index]))) })
	end

	response.partners = {}
	local partners = json.decode(tostring(roleDbData[7]))
	
	if partners and #partners > 0 then
		for _,heroId in ipairs(partners) do
			local heroInfo = redisproxy:hmget(string.format("hero:%d:%d", tonum(msg.roleId), tonum(heroId)),"type", "evolutionCount","level", "star")
			
			table.insert(response.partners, { type = tonum(heroInfo[1]), evolutionCount = tonum(heroInfo[2]),
			 level=tonum(heroInfo[3]), star = tonum(heroInfo[4]) })
		end
	end

	response.beauty = {}
	local beautyList = redisproxy:smembers(string.format("role:%d:beautyIds",tonum(msg.roleId)))
	if beautyList then
		for _,beautyId in pairs(beautyList) do
			local beautyInfo = redisproxy:hmget(string.format("beauty:%d:%d",tonum(msg.roleId),tonum(beautyId)),"status","evolutionCount")
			
			if tonum(beautyInfo[1]) == 3 then
				response.beauty = {id = beautyId, beautyId = beautyId,evolutionCount = beautyInfo[2]}
				break
			end
		end
		
	end
	
	response.isFriend = isFriend
	
	local bin = pb.encode("RoleLoginResponse", response)
	SendPacket(actionCodes.RoleDigestInfoResponse, bin)
end

function RoleAction.buyItemAndUseRequest(agent, data)
	-- 暂时用于体力丹购买并使用
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	if msg.param1 == 701 then
		if role:getHealthBuyCount() <= role.dailyData:getProperty("healthBuyCount") then
			role:sendSysErrMsg(SYS_ERR_STORE_DAILY_BUY_LIMIT)
			return
		end

		if not role:checkHealthFinalLimit(true) then
			return
		end

		-- 扣元宝
		local costYuanbao = functionCostCsv:getCostValue("health", role.dailyData:getProperty("healthBuyCount"))
		
		if not role:spendYuanbao(costYuanbao) then
			role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
			return
		end

		local buyCount = role.dailyData:getProperty("healthBuyCount") + 1
		-- 加体力
		local real_val = role:recoverHealth(50, { notify = true, checkLimit = false })
		if real_val > 0 then
			logger.info("r_in_health", role:logData({
				behavior = "i_hl_buy_yb",
				pm1 = real_val,
				pm2 = buyCount,
			}))			
		end
		logger.info("r_out_yuanbao", role:logData({
			behavior = "o_yb_buy_hl",
			vipLevel = role:getProperty("vipLevel"),
			pm1 = costYuanbao,
			pm2 = 0,
			pm3 = 0,
		}))		

		role.dailyData:setProperty("healthBuyCount", buyCount)
		role:notifyUpdateProperty("healthBuyCount", buyCount)
	end

	local bin = pb.encode("SimpleEvent", {})
	SendPacket(actionCodes.RoleBuyItemAndUseResponse, bin)
end

function RoleAction.itemUseRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	local itemId = msg.param1
	local itemCount = msg.param2

	if not role.items[itemId] or role.items[itemId]:getProperty("count") < itemCount then
		print("没有该物品或者物品数量不足")
		return
	end

	-- 体力
	local itemData = itemCsv:getItemById(itemId)
	if itemData.type == 4 then
		local param1 = 1
		if not role:checkHealthFinalLimit(true) then
			param1 = 2
		else
			-- 扣掉物品
			role.items[itemId]:addCount(-itemCount)
		end
		local real_val = role:recoverHealth(itemData.health * itemCount, { notify = true, checkLimit = false})
		if real_val > 0 then 
			logger.info("r_in_health", role:logData({
				behavior = "i_hl_use_item",
				pm1 = real_val,
				pm2 = itemId
			}))
		end
		local bin = pb.encode("SimpleEvent", {param1 = param1})
		SendPacket(actionCodes.ItemUseResponse, bin)
		return
	end

	-- 武将经验丹
	if itemData.type == ItemTypeId.HeroExp then
		local heroId = msg.param3
		local hero = role.heros[heroId]
		if not hero or hero:getLevelMaxExp(role:getProperty("level")) == 0 then
			return
		end
		role:updateDailyTask(DailyTaskIdMap.HeroIntensify, nil, {deltaCount = itemCount})	
		hero:addExp(itemData.heroExp * itemCount)
	end

	-- 扣掉物品
	role.items[itemId]:addCount(-itemCount)

	-- 道具包
	if itemId >= 5000 and itemId <= 9999 then
		local packageData = itemCsv:getItemById(itemId)
		for id, num in pairs(packageData.itemInclude) do
			role:awardItemCsv(tonum(id), { num = tonum(num)})
			log_util.log_gift_bag(role, tonum(id), tonum(num), itemId)
		end

		local bin = pb.encode("SimpleEvent", {})
		SendPacket(actionCodes.ItemUseResponse, bin)	

		return
	end

	-- 随机碎片
	if itemData.type == 20 then
		local giftItems = role:getGiftDrops(itemData.giftDropIds, { dropPlace = 4 })

		local bin = pb.encode("ItemList", { items = giftItems })
		SendPacket(actionCodes.ItemUseResponse, bin)	

		return
	end

	-- 随机道具包
	if itemData.type == ItemTypeId.RandomItemBox then
		local weightArrary = {}
		for _, data in pairs(itemData.randomIds) do
			weightArrary[#weightArrary + 1] = {
				itemId = tonumber(data[1]), weight = tonumber(data[2]), num = tonumber(data[3])
			}
		end
		
		local items = {}
		local randomIndex = randWeight(weightArrary)
		if weightArrary[randomIndex] then
			local itemData = weightArrary[randomIndex]
			role:awardItemCsv(itemData.itemId, {num = itemData.num })
			table.insert(items, { itemId = itemData.itemId, num = itemData.num })
		end

		local bin = pb.encode("ItemList", { items = items })
		SendPacket(actionCodes.ItemUseResponse, bin)	

		return
	end

	local bin = pb.encode("SimpleEvent", {})
	SendPacket(actionCodes.ItemUseResponse, bin)
end

function RoleAction.signRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role
	local roleId = role:getProperty("id")
	local nowTm = os.date("*t")
	local nowYm = os.date("%Y%m")
	local sign_key = string.format("role:%d:login:%s", roleId, nowYm)
    -- 检查是否已经领取 
    if redisproxy:getbit(sign_key, nowTm.day) == 1 then
    	local bin = pb.encode("SimpleEvent", { param1 = 1 })
		SendPacket(actionCodes.RoleSignResponse, bin)
    	return 
    end
    redisproxy:setbit(sign_key, nowTm.day, 1)
    -- 获取领取次数
	local nowCnt = tonumber(redisproxy:bitcount(string.format("role:%d:login:%s", roleId, nowYm)))

	local signData = activitySignCsv:getItemId(nowCnt, nowTm.month)
	local num = signData.num
	if signData.doubleVipLevel > 0 and signData.doubleVipLevel <= role:getProperty("vipLevel") then
		num = num * 2
	end
	role:awardItemCsv(signData.itemId, { num = num })
	log_util.log_sign_award(role, signData.itemId, signData.num, nowTm.day)

	local bin = pb.encode("SimpleEvent", { param1 = 0 })
	SendPacket(actionCodes.RoleSignResponse, bin)
end

function RoleAction.getLevelGiftRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local giftLevel = msg.param1

	-- 等级不足
	if role:getProperty("level") < giftLevel then
		return
	end

	-- 已领取
	if role.levelGifts[tostring(giftLevel)] == 1 then
		return
	end

	local giftData = levelGiftCsv:getDataByLevel(giftLevel)
	for _, itemData in pairs(giftData.itemtable) do
		role:awardItemCsv(itemData.itemId, {num = tonum(itemData.itemCount)})
		log_util.log_level_award(role, tonum(itemData.itemId), tonum(itemData.itemCount), giftLevel)
	end
	role.levelGifts[tostring(giftLevel)] = 1
	role:setProperty("levelGiftsJson", json.encode(role.levelGifts))
	role:notifyUpdateProperty("levelGiftsJson", role:getProperty("levelGiftsJson"))

	local bin = pb.encode("SimpleEvent", {})
	SendPacket(actionCodes.RoleGetLevelGiftResponse, bin)
end

function RoleAction.getServerGiftRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local day = msg.param1

	-- 今日已领取
	if day > role:getProperty("loginDays") then
		role:sendSysErrMsg(SYS_ERR_SERVER_GIFT_HAS_RECV)
		return
	end

	-- 已领取
	if role.serverGifts[day] == 1 then
		return
	end

	local giftData = serverGiftCsv:getDataByDay(day)
	for _, itemData in pairs(giftData.itemtable) do
		log_util.log_openserv_award(role, tonum(itemData.itemId), tonum(itemData.itemCount), day)
		role:awardItemCsv(itemData.itemId, {num = tonum(itemData.itemCount)})
	end
	role.serverGifts[day] = 1
	role:setProperty("serverGiftsJson", json.encode(role.serverGifts))
	role:notifyUpdateProperty("serverGiftsJson", role:getProperty("serverGiftsJson"))

	local bin = pb.encode("SimpleEvent", {})
	SendPacket(actionCodes.RoleGetServerGiftResponse, bin)
end

--获取当前服的活动时间列表
function RoleAction.getActivityTimeListRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	role:refreshActivityListTime()
end

--领取累充奖励
function RoleAction.getAccumulatedRechargeGiftRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role

	local id = msg.param1

	local giftData = ljczCsv:getDataById(id)
	
	--未在活动时间内  1:为活动ID
	if not activityListCsv:inLimitTime(serverId,1,skynet.time()) then
		role:sendSysErrMsg(SYS_ERR_ACCUMULATED_RECHARGE_OVER)
		return
	end

	-- 未达到领取条件
	local currentRechargeRMB = role:getProperty("rechargeRMB")
	if currentRechargeRMB < giftData.accumulatedRech then
		role:sendSysErrMsg(SYS_ERR_ACCUMULATED_RECHARGE_GIFT_DONT_RECV)
		return
	end

	-- 已领取
	if role.rechargeGifts[id] == 1 then
		role:sendSysErrMsg(SYS_ERR_ACCUMULATED_RECHARGE_GIFT_HAS_RECV)
		return
	end
	
	for _, itemData in pairs(giftData.awardItems) do
		-- TODO 累充奖励 奖励：道具 宝箱
		-- log_util.log_openserv_award(role, tonum(itemData.itemId), tonum(itemData.itemCount), id)
		role:awardItemCsv(itemData.itemId, {num = tonum(itemData.itemCount)})
	end
	role.rechargeGifts[id] = 1
	role:setProperty("rechargeGiftsJson", json.encode(role.rechargeGifts))
	role:notifyUpdateProperty("rechargeGiftsJson", role:getProperty("rechargeGiftsJson"))

	local bin = pb.encode("SimpleEvent", {})
	SendPacket(actionCodes.RoleGetAccumulatedRechargeGiftResponse, bin)
end

function RoleAction.recvTaskAwardRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)
	local role = agent.role 

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
		[12] = "hellPlayCount",
		[13] = "equipIntensifyCount",
		[14] = "drawCardCount",
		[15] = "trainCarbonCount",
		[16] = "expeditionCount",
	}

	local taskData = dailyTaskCsv:getTaskById(msg.param1)
	if not taskData then role:sendSysErrMsg(SYS_ERR_UNKNOWN) return end

	local finishCount = role.dailyData:getProperty(DailyTaskField[msg.param1])
	if finishCount < 0 then
		role:sendSysErrMsg(SYS_ERR_DAILY_TASK_HAS_RECV)
		return
	end

	if finishCount < taskData.count then
		role:sendSysErrMsg(SYS_ERR_DAILY_TASK_COUNT_LACK)
		return
	end

	if msg.param1 == 11 and skynet.time() >= role.timestamps:getProperty("yuekaDeadline") then
		return
	end

	role:updateDailyTask(msg.param1, true)	

	role:gainMoney(taskData.money)
	role:gainYuanbao(taskData.yuanbao)

	local roleLevel = role:getProperty("level")
	local expValue = taskData.exp
	role:addExp(expValue)
	role:addZhangongNum(taskData.zhangong)
	role:addHeroSoulNum(taskData.heroSoul)
	role:addStarSoulNum(taskData.starSoul)
	
	log_util.log_task_award(role, msg.param1)

	local bin = pb.encode("SimpleEvent", {})
	SendPacket(actionCodes.RoleRecvTaskAwardResponse, bin)
end

--招财活动
function RoleAction.buyMoneyRequest(agent, data)
	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role

	local times = tonumber(msg.param1)

	local vipData = vipCsv:getDataByLevel(role:getProperty("vipLevel"))
	local buyLimit = vipData and vipData.moneyBuyLimit or 0

	local haveBuyCount = role.dailyData:getProperty("moneybuytimes") or 0
	-- 检查次数
	if haveBuyCount + times > buyLimit then
		role:sendSysErrMsg(SYS_ERR_ZHAOCAI_COUNT_NOT_ENOUGH)
		return
	end

	-- 获得暴击权重
	local weightArray = string.tomap(globalCsv:getFieldValue("zhaoCaiCrit"))
	local zhaocaiWeight = {}
	for factor, weight in pairs(weightArray) do
		table.insert(zhaocaiWeight, { factor = tonumber(factor), weight = tonumber(weight) })
	end

	-- 获得招财倍率
	local function getFactor()
		local index = randWeight(zhaocaiWeight)
		if index then return zhaocaiWeight[index].factor end

		return 0
	end

	local needYuanbao, totalMoney, deltaCount = 0, 0, 0
	local buyMoneyResults = { results = {} }

	for time = 1, times do
		-- 消耗元宝
		local yuanbao = zhaoCaiCsv:getGoldByTimes(haveBuyCount + time)
		needYuanbao = needYuanbao + yuanbao

		local money = zhaoCaiCsv:getMoneyByTimes(haveBuyCount + time)
		if role:getProperty("level") >= 20 then
			money = money + (role:getProperty("level") - 20) * 20
		end
		local currentCount = getFactor()
		money = money * currentCount

		table.insert(buyMoneyResults.results, 
			{ yuanbao = yuanbao, money = money, critFactor = currentCount })
		totalMoney = totalMoney + money
	end

	-- 元宝不够
	if not role:spendYuanbao(needYuanbao) then
		role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
		return
	end

	logger.info("r_out_yuanbao", role:logData({
		behavior = "o_yb_money",
		vipLevel = role:getProperty("vipLevel"),
		pm1 = needYuanbao,
		pm2 = 0,
		pm3 = 0,
	}))

	role:gainMoney(totalMoney)
	role.dailyData:updateProperty({ field = "moneybuytimes", deltaValue = times })

	role:updateDailyTask(DailyTaskIdMap.ZhaoCai)

	local bin = pb.encode("BuyMoneyResult", buyMoneyResults)
	SendPacket(actionCodes.RoleBuyMoneyRequest, bin)
end

--吃鸡腿
function RoleAction.canEatChickenRequest(agent, data)
	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role
	local errCode = RoleAction.canEat(role)
	local bin = pb.encode("SimpleEvent", { param1 = errCode})
	SendPacket(actionCodes.RoleCanEatChickenRequest, bin)
end

function RoleAction.eatChickenRequest(agent,data)
	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role
	local errCode , isAM = RoleAction.canEat(role)
	local objVar = isAM and "eatChickenCountAM" or "eatChickenCountPM"
	if errCode == 3 then
		local real_val = role:recoverHealth(30, { notify = true, checkLimit = false, sendError = true })
		if real_val > 0 then
			logger.info("r_in_health", role:logData({
				behavior = "i_hl_chicken",
				pm1 = real_val,
				pm2 = 0,
			}))
			role.dailyData:setProperty(objVar, 1) --置为1					
		else
			errCode = 4	
		end
	end
	local bin = pb.encode("SimpleEvent", { param1 = errCode})
	SendPacket(actionCodes.RoleEatChickenRequest, bin)
end

function RoleAction.canEat(role,isAM)
	local errCode = 0  --1:时间未到，2：已经领过 3：可以领取
	local eatTime = 0
	local isAM = true
	local curTime = tonumber(os.date("%H"))
	if curTime > 13 then
		eatTime = role.dailyData:getProperty("eatChickenCountPM")
		isAM = false
	else
		eatTime = role.dailyData:getProperty("eatChickenCountAM")
	end
	if (curTime > 11 and curTime < 14) or ( curTime > 17 and curTime < 20 ) then
		errCode = (eatTime == 0) and 3 or 2
	else
		errCode = 1
	end

	return errCode,isAM
end


--获取下次health恢复时间：
function RoleAction.reHealthTimeRequest(agent,data)
	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role
	local lastHealthTime = skynet.time() - role.timestamps:getProperty("lastHealthTime")

	-- local temp = os.date("*t", role:getProperty("lastHealthTime"))
	-- local cur = os.date("*t", skynet.time())
	-- local endTime = os.date("*t", role:getProperty("lastHealthTime") + 600)

	local bin = pb.encode("SimpleEvent", { param1 = lastHealthTime})
	SendPacket(actionCodes.RoleReHealthTimeRequest, bin)
end

--重命名：state---200成功，1已经存在，2,元宝不足；3, 非法
function RoleAction.renameRequest(agent,data)
	local msg  = pb.decode("RenameEvent", data)
	local role = agent.role
	local state = 0

	-- 检查名字是否包含敏感字符
	local servId = string.byte(role:getProperty("uid"), -3) - 48
	local SERV = string.format("G_FUNCTIONS%d", servId)
	if not skynet.call(SERV, "lua", "check_words", msg.param1) then
		local bin = pb.encode("RenameEvent", { param2 = 3 })
		SendPacket(actionCodes.RoleRenameRequest, bin)
		return 
	end

	local curRoleID = redisproxy:get(string.format("user:%s", role:getProperty("name")))
	local roleId = redisproxy:get(string.format("user:%s", msg.param1))
	if roleId == nil then
		local changeData = functionCostCsv:getFieldValue("cNameCost")
		local renameCount = role:getProperty("renameCount")

		local costNum = (renameCount == 0) and 0 or (changeData and changeData.initValue or 100)
		local curYuanBao = role:getProperty("yuanbao")
		if costNum <= curYuanBao  then
			--减去消耗的元宝数量：test
			role:spendYuanbao(costNum)
			logger.info("r_out_yuanbao", role:logData({
				behavior = "o_yb_rename",
				vipLevel = role:getProperty("vipLevel"),
				pm1 = costNum,
			}))
			--更改名字：
			redisproxy:del(string.format("user:%s", role:getProperty("name"))) --删除
			redisproxy:set(string.format("user:%s", msg.param1),curRoleID)     --插入
			-- redisproxy:get(string.format("role:%s", curRoleID)):setProperty("name",msg.param1) --设置name1
			role:setProperty("name",msg.param1)   
			role:setProperty("renameCount", renameCount + 1)
			                                             --设置name2
			local uid = redisproxy:hget(string.format("role:%d", curRoleID), "uid")
			redisproxy:set(string.format("uid:%d", uid), msg.param1)
			role:notifyUpdateProperty("name", msg.param1)
			role:notifyUpdateProperty("renameCount", role:getProperty("renameCount"))

			state = 200
		else
			state = 2
		end
	else
		state = 1
	end
	local bin = pb.encode("RenameEvent", { param2 = state})
	SendPacket(actionCodes.RoleRenameRequest, bin)
end

function RoleAction.buyHeroBagRequest(agent, data)
	local msg  = pb.decode("SimpleEvent", data)
	local role = agent.role

	local buyCount = role:getProperty("bagHeroBuyCount")
	if buyCount >= globalCsv:getFieldValue("bagHeroBuyLimit") then
		role:sendSysErrMsg(SYS_ERR_HERO_BAG_BUY_LIMIT)
		return
	end

	local totalCost = functionCostCsv:getCostValue("addHeroBag", buyCount)

	if not role:spendYuanbao(totalCost) then
		role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
		return	
	end		

	role:setProperty("bagHeroBuyCount", buyCount + 1)
	local bin = pb.encode("SimpleEvent", { param1 = buyCount + 1 })
	SendPacket(actionCodes.RoleBuyHeroBagResponse, bin)
end

function RoleAction.itemSellRequest(agent, data)
	local msg  = pb.decode("ItemList", data)
	local role = agent.role

	local sellMoney = 0
	for _, item in ipairs(msg.items) do
		local itemId = item.itemId
		local count = role.items[itemId]:getProperty("count")
		local itemData = itemCsv:getItemById(itemId)
		if itemData then
			sellMoney = sellMoney + itemData.sellMoney * count
		end
		redisproxy:srem(string.format("role:%d:items", role:getProperty("id")), itemId)
		redisproxy:del(string.format("item:%d:%d", role:getProperty("id"), itemId))
		
		role.items[itemId] = nil
	end
	role:gainMoney(sellMoney)

	local bin = pb.encode("SimpleEvent", { param1 = sellMoney })
    SendPacket(actionCodes.ItemSellResponse, bin)
end

function RoleAction.rankRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	local flag = msg.param1

	local rankResponse = { rankList = {} }
	local limit = 50
	local redisResult = {}
	if flag == 1 then
		redisResult = redisproxy:zrevrange("levelRank", 0, limit - 1, "withscores")
	elseif flag == 2 then
		redisResult = redisproxy:lrange("pvp_rank", 0, limit - 1)
	elseif flag == 4 then
		redisResult = redisproxy:zrevrange("towerrank", 0, limit - 1, "withscores")
	elseif flag == 31 then
		redisResult = redisproxy:zrevrange("normalRank", 0, limit - 1, "withscores")
	elseif flag == 32 then
		redisResult = redisproxy:zrevrange("challengeRank", 0, limit - 1, "withscores")
	elseif flag == 33 then
		redisResult = redisproxy:zrevrange("hardRank", 0, limit - 1, "withscores")
	end

	local rankList = {}
	if flag ~= 2 then
		for i = 1, #redisResult, 2 do
	    	table.insert(rankList, { tonumber(redisResult[i]), tonumber(redisResult[i + 1])})
	    end
	else
		for i = 1, #redisResult do
	    	table.insert(rankList, { tonumber(redisResult[i]) })
	    end
	end

	for index, data in ipairs(rankList) do
		local rankRoleId = data[1]
		local rankInfo = {
			roleId = rankRoleId,
			rank = index,
			name = redisproxy:hget(string.format("role:%d", rankRoleId), "name"),
			level = tonumber(redisproxy:hget(string.format("role:%d", rankRoleId), "level")),
		}

		local mainHeroId = tonumber(redisproxy:hget(string.format("role:%d", rankRoleId), "mainHeroId"))
		local mainHeroInfo = redisproxy:hmget(string.format("hero:%d:%s", rankRoleId, mainHeroId),
			"type", "delete", "wakeLevel", "star", "evolutionCount")
		if tonumber(mainHeroInfo[2]) == 0 then
			rankInfo.mainHeroType = tonumber(mainHeroInfo[1])
			rankInfo.mainHeroWakeLevel = tonumber(mainHeroInfo[3])
			rankInfo.mainHeroStar = tonumber(mainHeroInfo[4])
			rankInfo.mainHeroEvolutionCount = tonumber(mainHeroInfo[5])
		end

		if flag == 4 then
			--闯关数量
			rankInfo.extraParam1 = math.floor(tonumber(data[2]) / 1000)
			--获得星数
			rankInfo.extraParam2 = tonumber(data[2]) % 1000
		elseif flag > 30 then
			--副本最后一关id
			rankInfo.extraParam1 = math.floor(data[2])
		end
		table.insert(rankResponse.rankList, rankInfo)
	end
	
	local bin = pb.encode("RankList", rankResponse)
	SendPacket(actionCodes.RoleRankResponse, bin)
end

function RoleAction.exchange(agent, data)
	local msg = pb.decode("KeyValuePair", data)

	local role = agent.role
	local giftCode = msg.key

	local result = {}
	local codeData = exchangeCsv:getDataByCode(giftCode)
	local flag = redisproxy:hget("giftCodes", giftCode)
	print(tonumber(string.sub(role:getProperty("uid"), -2, -1)))
	if not codeData or not flag then
		result.param1 = 1   --无效礼包码
	elseif tonum(flag) ~= 0 then
		result.param1 = 3 	--礼包码已被领取
	elseif (codeData.platformId ~= 0 and codeData.platformId ~= tonumber(string.sub(role:getProperty("uid"), -2, -1))) then
		result.param1 = 4   --渠道不对应
	elseif redisproxy:get(string.format("awardGiftItem:%d:%d", role:getProperty("id"), codeData.itemId)) then
		result.param1 = 2   --已领取过同类型礼包
	else
		result.param1 = 0
		result.param2 = codeData.itemId
		role:awardItemCsv(codeData.itemId)
		redisproxy:hset("giftCodes", giftCode, skynet.time())
		redisproxy:set(string.format("awardGiftItem:%d:%d", role:getProperty("id"), codeData.itemId), 0)
	end

	local bin = pb.encode("SimpleEvent", result)
    SendPacket(actionCodes.RoleExchangeResponse, bin)
end

function RoleAction.fund(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	local level = tonum(msg.param1)

	if level == 0 then
		if role.fund["isBought"] or globalCsv:getFieldValue("fundLevel") > role:getProperty("level") then
			return
		end

		if not role:spendYuanbao(globalCsv:getFieldValue("fundCost")) then
			role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
			return
		end

		role.fund["isBought"] = 1
	else
		if not role.fund["isBought"] or role.fund[tostring(level)] or level > role:getProperty("level") then
			return
		end
		local data = fundCsv:getDataByLevel(level)
		role:gainYuanbao(data.yuanbao)
		role.fund[tostring(level)] = 1
	end

	role:setProperty("fundJson", json.encode(role.fund))
	role:notifyUpdateProperty("fundJson", role:getProperty("fundJson"))

	local bin = pb.encode("SimpleEvent", {})
    SendPacket(actionCodes.RoleGetFundRequest, bin)
end

function RoleAction.composeBattleSoul(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role
	local soulId = tonum(msg.param1)
	local csvData = battleSoulCsv:getDataById(soulId)
	if not csvData then return end

	--检查物品
	local items = {}
	for id, num in pairs(csvData.material) do
		local itemId = id + battleSoulCsv.toItemIndex
		local item = role.items[itemId]
		local itemCount = item and item:getProperty("count") or 0

		if itemCount < num then
			role:sendSysErrMsg(SYS_ERR_ITEM_NUM_NOT_ENOUGH)
			return
		else
			table.insert(items, {["id"] = itemId, ["count"] = num})
		end
	end

	--检查金钱
	if not role:checkMoney(csvData.money) then
		role:sendSysErrMsg(SYS_ERR_MONEY_NOT_ENOUGH)
		return
	end

	--实际扣除
	role:spendMoney(csvData.money)
	for _, item in pairs(items) do
		role:addItem({id = item.id, count = -item.count})
	end

	--添加新合成物品
	role:addItem({id = soulId + battleSoulCsv.toItemIndex, count = 1})

	local bin = pb.encode("SimpleEvent", {})
    SendPacket(actionCodes.RoleComposeBattleSoul, bin)
end

return RoleAction