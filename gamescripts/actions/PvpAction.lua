local PvpAction = {}

-- 查找匹配角色并返回简要信息
function PvpAction.searchMatchRoles(agent, data)
	local msg = pb.decode("EnterPvpBattle", data)

	local role = agent.role

	if role:getProperty("pvpRank") == 0 then
		-- 玩家第一次进入PVP战场, 排在最后
		if role:getProperty("level") < PVP_OPEN_LEVEL then
			-- 级别不满足
			role:sendSysErrMsg(SYS_ERR_PVP_LOW_ROLE_LEVEL)
			return
		end
		local index = redisproxy:rpush("pvp_rank", tostring(role:getProperty("id")))
		role:setProperty("pvpRank", index)
		role:setProperty("pvpBestRank", index)
	end

	local rank = role:getProperty("pvpRank")
	PvpAction.refreshOpponentList(agent, rank)
end

-- 选择已经匹配好的对手
function PvpAction.chooseOpponent(agent, data)
	local msg = pb.decode("ChoosePvpOpponent", data)

	local selfRole = agent.role
	-- 如果当天PVP次数已经用完
	if selfRole.dailyData:getProperty("pvpCount") < 0 then
		selfRole:sendSysErrMsg(SYS_ERR_PVP_TODAY_RUN_OUT)
		return
	end

	local vipData = vipCsv:getDataByLevel(selfRole:getProperty("vipLevel"))

	-- pvp的cd时间限制
	local selfLastPvpTime = selfRole.timestamps:getProperty("lastPvpTime")
	if (selfLastPvpTime ~= 0 and selfLastPvpTime + PVP_CD_TIME > skynet.time())
		and not vipData.pvpCd then
		selfRole:sendSysErrMsg(SYS_ERR_PVP_IN_CD_TIME)
		return
	end

	-- 当前玩家被选择了
	local opponentRole = require("datamodel.Role").new({ key = string.format("role:%d", msg.opponentRoleId)})
	local opponentRole = redisproxy:hmget(string.format("role:%d", msg.opponentRoleId),
		"id", "pvpRank", "pveFormationJson", "pvpStatus")

	if tonumber(opponentRole[4]) == RoleStatus.PvP then
		selfRole:sendSysErrMsg(SYS_ERR_PVP_OPPONENT_BE_CHOSEN)
		return
	end

	-- 排名已经变过
	if tonumber(opponentRole[2]) ~= msg.opponentRank then
		-- 重新刷新并提示
		selfRole:sendSysErrMsg(SYS_ERR_PVP_OPPONENT_LEVEL_CHANGE)
		PvpAction.refreshOpponentList(agent, selfRole:getProperty("pvpRank"))
		return
	end 

	

	-- 更新被挑战者的信息
	-- opponentRole:setProperty("pvpStatus", RoleStatus.PvP)

	-- 获得敌方的阵型数据
	local opponentPvpFormation = PvpAction.loadFormationHero(tonumber(opponentRole[1]), opponentRole[3])
	local bin = pb.encode("BattleData", opponentPvpFormation)
	SendPacket(actionCodes.PvpFormationInfo, bin)
end

function PvpAction.buyPvpCount(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	-- 当天次数已经购买完毕
	if role.dailyData:getProperty("pvpBuyCount") >= role:getPvpBuyLimit() then
		role:sendSysErrMsg(SYS_ERR_PVP_BUY_COUNT_LIMIT)
		return
	end

	-- 元宝不足
	local costYuanbao = functionCostCsv:getCostValue("pvpCount", role.dailyData:getProperty("pvpBuyCount"))
	
	if not role:spendYuanbao(costYuanbao) then
		role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
		return	
	end

	logger.info("r_out_yuanbao", role:logData({
		behavior = "o_yb_pvp_add",
		vipLevel = role:getProperty("vipLevel"),
		pm1 = costYuanbao,
		pm2 = 0,
		pm3 = 0,	
	}))

	-- 更新玩家属性
	role:setPvpCount(role.dailyData:getProperty("pvpCount") + 1)
	role.dailyData:updateProperty({ field = "pvpBuyCount" })
end

-- 消除pvp的cd时间, 直接将cd时间设置成0
function PvpAction.eraseCdTime(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	-- 元宝不足
	local costData = functionCostCsv:getFieldValue("eraseCdTime")
	if not role:spendYuanbao(costData.initValue) then
		role:sendSysErrMsg(SYS_ERR_YUANBAO_NOT_ENOUGH)
		return	
	end
	logger.info("r_out_yuanbao", role:logData({
		behavior = "o_yb_pvp_fresh",
		vipLevel = role:getProperty("vipLevel"),
		pm1 = costData.initValue,
		pm2 = 0,
		pm3 = 0,
	}))

	-- 更新玩家属性
	role.timestamps:updateProperty({ field = "lastPvpTime", newValue = 0 })
end

function PvpAction.battleEnterRequest(agent, data)
	local selfRole = agent.role

	local msg = pb.decode("SimpleEvent", data)

	if selfRole.dailyData:getProperty("pvpCount") <= 0 then
		selfRole:sendSysErrMsg(SYS_ERR_PVP_BATTLE_COUNT_LIMIT)
		return	
	end

	-- 更新挑战者的挑战信息
	-- selfRole:setProperty("pvpStatus", RoleStatus.PvP)
	selfRole:setPvpCount(selfRole.dailyData:getProperty("pvpCount") - 1)
	selfRole.timestamps:updateProperty({ field = "lastPvpTime", newValue = skynet.time() })	-- 玩家最近一次的pvp时间

	selfRole:setProperty("enterFlag", 1)

	local bin = pb.encode("SimpleEvent", { roleId = msg.roleId})
	SendPacket(actionCodes.PvpBattleEnterResponse, bin)
end

-- 客户端战斗结束
function PvpAction.endGameNotify(agent, data)
	local msg = pb.decode("PvpBattleEndResult", data)

	local selfRole = agent.role
	local roleId = selfRole:getProperty("id")

	if selfRole:getProperty("enterFlag") ~= 1 then return end
	selfRole:setProperty("enterFlag", 0)

	local opponentKey = string.format("role:%d", msg.opponentRoleId)
	local opponentAgent = datacenter.get("agent", msg.opponentRoleId)

	local pvpAwardData = pvpAwardCsv:getAwardData(selfRole:getProperty("pvpRank"))

	local origLevel = selfRole:getProperty("level")

	local money = pvpAwardData.money * tonum(pvpAwardData.moneyStarBonus[tostring(msg.starNum)]) / 100
	local exp = pvpAwardData.exp * tonum(pvpAwardData.expStarBonus[tostring(msg.starNum)]) / 100
	local zhangong = pvpAwardData.zhangong * tonum(pvpAwardData.zhangongStarBonus[tostring(msg.starNum)]) / 100
	selfRole:gainMoney(money)
	-- 增加英雄经验
	selfRole:addHeroExp(exp)
	selfRole:addZhangongNum(zhangong)
	logger.info("r_in_zhangong", selfRole:logData({
		behavior = "i_zg_pvp_win",
		pm1 = zhangong,
		pm2 = msg.starNum,
	}))

	-- 更新状态
	selfRole:setProperty("pvpStatus", RoleStatus.Idle)
	if opponentAgent then
		skynet.call(opponentAgent.serv, "role", "setProperty", "pvpStatus", RoleStatus.Idle)
	else
		redisproxy:hset(opponentKey, "pvpStatus", RoleStatus.Idle)
	end

	local selfRank = selfRole:getProperty("pvpRank")
	local opponentRank
	if opponentAgent then
		opponentRank = skynet.call(opponentAgent.serv, "role", "getProperty", "pvpRank")
	else
		opponentRank = tonumber(redisproxy:hget(opponentKey, "pvpRank"))
	end

	local rankResult = {}
	-- 更新名次仅当自己排名低
	if msg.starNum ~= 0 and selfRank > opponentRank then
		-- 更新自己的排名
		selfRole:setProperty("pvpRank", opponentRank)
		redisproxy:lset("pvp_rank", opponentRank - 1, tostring(msg.roleId))

		-- 更新被挑战者的排名
		if opponentAgent then
			skynet.call(opponentAgent.serv, "role", "setProperty", "pvpRank", selfRank)
		else
			redisproxy:hset(opponentKey, "pvpRank", selfRank)
		end
		selfRole:sendPvpUpAward(opponentRank, rankResult)
		redisproxy:lset("pvp_rank", selfRank - 1, tostring(msg.opponentRoleId))

		--全服通告
		if worldNoticeCsv:isConditionFit(worldNoticeCsv.pvp, opponentRank) then
			local opponentName = redisproxy:hget(opponentKey, "name")
			local content = worldNoticeCsv:getDesc(worldNoticeCsv.pvp, {playerName = selfRole:getProperty("name"), param1 = opponentName})
			sendWorldNotice(content)
		end
	end

	local Hero = require "datamodel.Hero"
	-- 将玩家最新战力相关的数据写入
	if msg.starNum > 0 then
		-- 写入映射 roleId -> force (sortedset); zadd
		-- roleId -> heroDtl (set); sadd
		local passiveSkills, beauties = selfRole.sGetFightBeautySkills(roleId)
		-- 当前上阵信息
		local key = string.format("role:%d", roleId)
		local slots = json.decode(redisproxy:hget(key, "slotsJson")) or {}
		local fighter = {}
		local roleInfo = redisproxy:hmget(string.format("role:%d", roleId), "name", "level")
		fighter['name'] = roleInfo[1]
		fighter['level'] = roleInfo[2]
		fighter['angryCD'] = 0
		fighter.heroList = {}
		for k, v in pairs(slots) do
			if tonum(v.heroId) == 0  then goto continue end
			local heroInfo = redisproxy:hmget(string.format("hero:%d:%d", roleId, v.heroId), 
				"level", "evolutionCount", "skillLevelJson", "star")
			local attrValues = Hero.sGetTotalAttrValues(roleId, v.heroId)
			local heroDtl = {
				id = v.heroId,
				level = heroInfo[1],
				evolutionCount = heroInfo[2],
				skillLevelJson = heroInfo[3],
				blood = 100, 
				slot = tonumber(k),
				attrsJson = json.encode(attrValues),
				star = heroInfo[4],
			}
			table.insert(fighter.heroList, heroDtl)
			::continue::
		end
		local force = selfRole:getBattleValue()
		redisproxy:zadd("expedition:forceRank:w", force, roleId)
		redisproxy:hset("expedition:fightInfo:w", roleId, json.encode(fighter))
	end

	-- 通知客户端结果
	local pvpBattleResult = { 
		roleId = msg.roleId,
		opponentRoleId = msg.opponentRoleId,
		starNum = msg.starNum,
		money = money,
		exp = exp,
		origLevel = origLevel,
		zhangong = zhangong,
	}
	table.merge(pvpBattleResult, rankResult)
	local bin = pb.encode("PvpBattleEndResult", pvpBattleResult)
	SendPacket(actionCodes.PvpEndGameResponse, bin)

	logger.info('r_pvp', selfRole:logData())
	
	-- 每日任务
	selfRole:updateDailyTask(DailyTaskIdMap.PvpBattle)

	-- 记录pvp记录
	local pvpRankRecord = {
		roleId = msg.roleId,
		opponentRoleId = msg.opponentRoleId,
		starNum = msg.starNum,
		deltaRank = msg.starNum > 0 and selfRank - opponentRank or 0,	-- 名次变化
		createTime = skynet.time(),
		zhangong = zhangong,
	}

	local bin = pb.encode("HistoryRecord", pvpRankRecord)
	-- 战报记录
	-- TODO 数据有冗余, 主要是敌手会删除记录, 所以不能用共同的数据源
	redisproxy:lpush(string.format("role:%d:pvpRecords", selfRole:getProperty("id")), bin)
	redisproxy:ltrim(string.format("role:%d:pvpRecords", selfRole:getProperty("id")), 0, PVP_HISTORY_LIMIT - 1)
	redisproxy:lpush(string.format("role:%d:pvpRecords", msg.opponentRoleId), bin)
	redisproxy:ltrim(string.format("role:%d:pvpRecords", msg.opponentRoleId), 0, PVP_HISTORY_LIMIT - 1)
end

function PvpAction.giftAwardRequest(agent, data)
	local msg = pb.decode("PvpGiftAwardRequest", data)

	local role = agent.role

	local awardPvpGiftData = pvpGiftCsv:getGiftData(msg.floorRank)
	if not awardPvpGiftData then return end

	role:gainMoney(awardPvpGiftData.money)
	role:gainYuanbao(awardPvpGiftData.yuanbao)
	
	role:awardItemCsv(awardPvpGiftData.cardGiftId)
end

function PvpAction.queryRankList(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local rankResponse = { rankList = {} }
	local limit = 50
	for index = 1, math.min(limit, redisproxy:llen("pvp_rank")) do
		local rankRoleId = tonumber(redisproxy:lindex("pvp_rank", index - 1))
		local rankInfo = {
			roleId = rankRoleId,
			pvpRank = index,
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
		table.insert(rankResponse.rankList, rankInfo)
	end

	local bin = pb.encode("PvpRankList", rankResponse)
	SendPacket(actionCodes.PvpRankResponse, bin)
end

local getBattleReports = function(roleId)
	local reports = {}
	local limit = 10

	local pvpRecordKey = string.format("role:%d:pvpRecords", roleId)
	for index = 1, math.min(limit, redisproxy:llen(pvpRecordKey)) do
		local pvpRecordBin = redisproxy:lindex(pvpRecordKey, index - 1)
		local pvpRecord = pb.decode("HistoryRecord", pvpRecordBin)

		local roleName = redisproxy:hget(string.format("role:%d", pvpRecord.roleId), "name")
		local curRoleInfo = redisproxy:hmget(string.format("role:%d", pvpRecord.opponentRoleId), 
			"name", "level", "mainHeroId")

		local mainHeroInfo = redisproxy:hmget(string.format("hero:%d:%s", pvpRecord.opponentRoleId, curRoleInfo[3]),
			"type", "delete")
		if tonumber(mainHeroInfo[2]) == 0 then
			table.insert(reports, {
				roleId = pvpRecord.roleId,
				roleName = roleName,
				opponentRoleId = pvpRecord.opponentRoleId,
				opponentRoleMainHeroType = tonumber(mainHeroInfo[1]),
				opponentRoleName = curRoleInfo[1],
				opponentRoleLevel = tonumber(curRoleInfo[2]),
				deltaRank = pvpRecord.deltaRank,
				createTime = pvpRecord.createTime,
				zhangong = pvpRecord.zhangong,
			})
		end
	end

	return reports
end

function PvpAction.battleReportRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local response = {}
	response.reports = getBattleReports(msg.roleId)

	local bin = pb.encode("BattleReportList", response)
	SendPacket(actionCodes.PvpBattleReportResponse, bin)
end

-- 根据给定排行刷新挑战榜单
function PvpAction.refreshOpponentList(agent, rank)
	local role = agent.role

	local matchRolesInfo = {}
	matchRolesInfo.pvpRank = rank 
	matchRolesInfo.matchRoles = {}
	for _, rank in ipairs(pvpMatchCsv:getMatchRanks(rank)) do
		local roleId = tonumber(redisproxy:lindex("pvp_rank", rank - 1)) -- 下标以0开始
		if roleId then
			local matchRole = require("datamodel.Role").new({ key = string.format("role:%d", roleId)})
			if matchRole:load() then
				local matchRoleInfo = {
					id = matchRole:getProperty("id"),
					name = matchRole:getProperty("name"),
					level = matchRole:getProperty("level"),
					pvpRank = matchRole:getProperty("pvpRank"),
				}
				local mainHeroId = matchRole:getProperty("mainHeroId")
				if mainHeroId > 0 then
					local mainHeroInfo = redisproxy:hmget(string.format("hero:%d:%s", roleId, mainHeroId),
						"type", "wakeLevel", "star", "evolutionCount")
					matchRoleInfo.mainHeroType = tonumber(mainHeroInfo[1])
					matchRoleInfo.mainHeroWakeLevel = tonumber(mainHeroInfo[2])
					matchRoleInfo.mainHeroStar = tonumber(mainHeroInfo[3])
					matchRoleInfo.mainHeroEvolutionCount = tonumber(mainHeroInfo[4])
					table.insert(matchRolesInfo.matchRoles, matchRoleInfo)
				end
			end
		end
	end

	matchRolesInfo.reports = getBattleReports(role:getProperty("id"))

	local bin = pb.encode("MatchRolesResponse", matchRolesInfo)
	SendPacket(actionCodes.PvpSearchMatchResponse, bin)
end

-- 加载阵型的武将信息
function PvpAction.loadFormationHero(roleId, pveFormationJson)
	local pveFormation = json.decode(pveFormationJson)

	local pvpFormation = { roleId = roleId, heros = {} }

	local Role = require "datamodel.Role"
	local Hero = require "datamodel.Hero"

	-- 美人信息
	pvpFormation.passiveSkills, pvpFormation.beauties = Role.sGetFightBeautySkills(roleId)
	-- 技能释放顺序
	local skillOrder = json.decode(redisproxy:hget(string.format("role:%d", roleId), "skillOrderJson")) or {}
	-- 武将信息
	for index, heroId in pairs(pveFormation) do
		local isExist = redisproxy:sismember(string.format("role:%d:heroIds", roleId), heroId)
		if isExist then
			local heroInfo = redisproxy:hmget(string.format("hero:%d:%d", roleId, heroId),
				"type", "level", "evolutionCount", "skillLevelJson")	

			local attrValues = Hero.sGetTotalAttrValues(roleId, heroId)

			table.insert(pvpFormation.heros, {
				id = heroId,
				type = tonumber(heroInfo[1]),
				index = index,
				level = tonumber(heroInfo[2]),
				attrsJson = json.encode(attrValues),
				evolutionCount = tonumber(heroInfo[3]),
				skillLevelJson = heroInfo[4],
				skillOrder = table.keyOfItem(skillOrder, heroId),
			})
		end
	end

	return pvpFormation
end

return PvpAction