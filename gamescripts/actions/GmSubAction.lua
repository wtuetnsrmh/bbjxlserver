local _M = {}

-- broadcast
function _M.broadcast(role, pms)
	local cmd, msg = pms['pm1'], pms['pm2']
	local bin = pb.encode("GmEvent", {cmd = msg})
	if cmd == "common" then
		SendPacket(actionCodes.SysCommonNotice, bin)
	elseif cmd == "maintain" then
		SendPacket(actionCodes.SysMaintainNotice, bin)
	end
	return "指令生效"
end

-- money cnt
function _M.money(role, pms)
	local money = tonumber(pms.pm1)
	role:gainMoney(money)
	return "指令生效"
end

-- yuanbao cnt
function _M.yuanbao(role, pms)
	local yuanbao = tonumber(pms.pm1)
	role:gainYuanbao(yuanbao)
	return "指令生效"
end

-- level cnt
function _M.level(role, pms)
	local lvl = tonumber(pms.pm1)
	-- lvl <= 80
	role:upLevel(lvl)
	return "指令生效"
end

-- exp_fb type 
-- type = 1, 清除次数
-- type = 2, 清除cd
-- type = 3, 都清除
function _M.exp_fb(role, pms)
	if 1 == pms.pm1 then
		role.dailyData:setProperty("expBattleCount", 0)
		role:notifyUpdateProperty("expBattleCount", 0)
	elseif 2 == pms.pm1 then
		role.dailyData:setProperty("expBattleCD", 0)
		role:notifyUpdateProperty("expBattleCD", 0)
	elseif 3 == pms.pm1 then
		role.dailyData:setProperty("expBattleCount", 0)
		role.dailyData:setProperty("expBattleCD", 0)
		role:notifyUpdateProperties({ 
			{ key = "expBattleCount", newValue = 0 },
			{ key = "expBattleCD", newValue = 0 }
		})
	end
	return "指令生效"
end

-- money_fb type 
-- type = 1, 清除次数
-- type = 2, 清除cd
-- type = 3, 都清除
function _M.money_fb(role, pms)
	if 1 == pms.pm1 then
		role.dailyData:setProperty("moneyBattleCount", 0)
		role:notifyUpdateProperty("moneyBattleCount", 0)
	elseif 2 == pms.pm1 then
		role.dailyData:setProperty("moneyBattleCD", 0)
		role:notifyUpdateProperty("moneyBattleCD", 0)
	elseif 3 == pms.pm1 then
		role.dailyData:setProperty("moneyBattleCount", 0)
		role.dailyData:setProperty("moneyBattleCD", 0)
		role:notifyUpdateProperties({ 
			{ key = "moneyBattleCount", newValue = 0 },
			{ key = "moneyBattleCD", newValue = 0 }
		})
	end
	return "指令生效"
end

-- tower_fb type 
-- type = 1, 清除次数
-- type = 2, 清除cd
-- type = 3, 都清除
function _M.tower_fb(role, pms)
	local towerDataKey = string.format("role:%d:towerData", role:getProperty("id"))
	if not role.towerData then
		role.towerData = require("datamodel.Tower").new({ key = towerDataKey })
		role.towerData:load()
	end
	if 1 == pms.pm1 then
		role.towerData:setProperty("count", 3)
	elseif 2 == pms.pm1 then
		role.towerData:setProperty("lastPlayTime", 0)
	elseif 3 == pms.pm1 then
		role.towerData:setProperty("count", 3)
		role.towerData:setProperty("lastPlayTime", 0)
	end
	local bin = pb.encode("TowerData", role.towerData:pbData())
	SendPacket(actionCodes.TowerDataResponse, bin)
	return "指令生效"
end

-- trial_fb type 
-- type = 1, 清除次数
-- type = 2, 清除cd
-- type = 3, 都清除
local map = {"qun", "wei", "shu", "wu", "beauty"}
function _M.trial_fb(role, pms)
	if not pms.pm2 or pms.pm2 > #map or pms.pm2 <= 0 then return "参数错误" end
	local countKey = string.format("%sBattleCount", map[pms.pm2])
	local timeKey = string.format("%sBattleCD", map[pms.pm2])
	if 1 == pms.pm1 then
		role.dailyData:setProperty(countKey, 0)
		role:notifyUpdateProperty(countKey, 0)
	elseif 2 == pms.pm1 then
		role.dailyData:setProperty(timeKey, 0)
		role:notifyUpdateProperty(timeKey, 0)
	elseif 3 == pms.pm1 then
		role.dailyData:setProperty(countKey, 0)
		role.dailyData:setProperty(timeKey, 0)
		role:notifyUpdateProperties({ 
			{ key = countKey, newValue = 0 },
			{ key = timeKey, newValue = 0 }
		})
	end
	return "指令生效"
end

-- hero hero_type lv evolCnt
function _M.hero(role, pms)
	local itemId = tonumber(pms.pm1)
	local lv = tonumber(pms.pm2)
	local evolCnt = tonumber(pms.pm3)
	-- lv <= 玩家等级
	if lv > role:getProperty("level") then return "超过玩家等级" end
	-- evolcnt <= 5
	if evolCnt > evolutionModifyCsv:getEvolMaxCount() then return "超过最大进化值" end

	if not unitCsv:getUnitByType(itemId) then return "英雄type不存在" end

	role:awardHero(itemId, { level = lv, evolutionCount = evolCnt })
	return "指令生效"
end

-- evol heroId value
function _M.evol(role, pms)
	local heroId = tonumber(pms.pm1)
	local hero = role.heros[heroId] 
	if not hero then return "英雄不存在" end

	local val = tonumber(pms.pm2)
	if val <= 0 then return "指令失败" end
	local max = evolutionModifyCsv:getEvolMaxCount()
	val = (val > max) and max or val

	hero:setProperty("evolutionCount", val)

	local evolutionCount = hero:getProperty("evolutionCount")
	for index = 1, 5, 2 do
		if evolutionCount >= index then
			local passiveIndex = math.floor((index + 1) / 2)
			local passiveSkillId = hero.unitData["passiveSkill" .. passiveIndex]
			if not hero.skillLevels[tostring(passiveSkillId + 10000)] then
				hero.skillLevels[tostring(passiveSkillId + 10000)] = 1
			end
		end
	end
	hero:updateSkillLevels()

	local evolutionResponse = {
		result = 0,
		heros = {  
			{ id = heroId, evolutionCount = val }
		},
	}

	local bin = pb.encode("HeroActionResponse", evolutionResponse)
    SendPacket(actionCodes.HeroEvolutionResponse, bin)
    return "指令生效"
end

-- get id num
function _M.get(role, pms)
	local itemId = tonumber(pms.pm1)
	local itemNum = tonumber(pms.pm2)
	if not role:awardItemCsv(itemId, { num = itemNum }) then
		return "物品不存在"
	end
	return "指令生效"
end

-- hero_skill heroId skillindex lv
function _M.hero_skill(role, pms)
	local heroId = pms.pm1
	local index = pms.pm2 or 0
	local level = pms.pm3 or 1
	-- whether hero exist
	local hero = role.heros[heroId] 
	if not hero then
		return "英雄不存在"
	end
	-- whether index between [0,3]
	if index < 0 or index > 3 then
		return "超过技能范围[0-3]"
	end
	-- whether lv <= 20
	if level > 20 then
		return "超过技能最大值20"
	end
	-- 获取技能id
	local heroData = unitCsv:getUnitByType(hero:getProperty("type"))
	local skillId
	if index == 0 then
		skillId = heroData.talentSkillId
	else
		skillId = heroData[string.format("passiveSkill%d", index)] + 10000
	end
	-- 技能级别设置
	hero.skillLevels[tostring(skillId)] = level
	hero:updateSkillLevels()
	return "指令生效"
end

-- hero_level heroId level
function _M.hero_level(role, pms)
	local heroId = pms.pm1
	local lvl = pms.pm2
	local hero = role.heros[heroId]
	if not hero then
		return "英雄不存在"
	end
	hero:upLevel(lvl)
	return "指令生效"
end

-- wake heroId level
function _M.star_up(role, pms)
	local heroId = pms.pm1
	local lvl = pms.pm2
	local hero = role.heros[heroId]
	hero:updateStar(lvl)
	return "指令生效"
end

-- vip level
function _M.vip(role, pms)
	local lv = pms.pm1
	if lv < 0 and lv > 15 then
		return "超过vip范围[0-15]"
	end
	role:changeVipLevel(lv)
	return "指令生效"
end

-- employ bid 
function _M.employ(role, pms)
	role:addBeauty(pms.pm1)
	local bin = pb.encode("BeautyDetail", role.beauties[pms.pm1]:pbData())
	SendPacket(actionCodes.BeautyEmployResponse, bin)
	return "指令生效"
end

-- friend_value value
function _M.friend_value(role, pms)
	if pms.pm1 <= 0 then
		return "指令失败"
	end
	role:addFriendValue(pms.pm1)
	return "指令生效"
end

function _M.lingpai(role, pms)
	local lingpai = tonumber(pms.pm1)
	role:addLingpaiNum(pms.pm1)
	return "指令生效"
end

function _M.zhangong(role, pms)
	local zhangong = tonumber(pms.pm1)
	role:addZhangongNum(pms.pm1)
	return "指令生效"
end

function _M.starsoul(role, pms)
	local starsoul = tonumber(pms.pm1)
	role:addStarSoulNum(pms.pm1)
	return "指令生效"
end

function _M.herosoul(role, pms)
	local herosoul = tonumber(pms.pm1)
	role:addHeroSoulNum(herosoul)
	return "指令生效"
end

function _M.exp(role, pms)
	local exp = tonumber(pms.pm1)
	role:addExp(exp)
	return "指令生效"
end

function _M.health(role, pms)
	local val = tonumber(pms.pm1)
	if val > 0 then
		role:recoverHealth(val, {notify = true, checkLimit = false})
	else
		role:costHealth(-val)
	end
	return "指令生效"
end

function _M.carbon(role, pms)
	local carbonId = tonumber(pms.pm1)
	local carbonData = mapBattleCsv:getCarbonById(carbonId)
	if math.floor(carbonId / 10000) ~= 1 then return "请输入普通副本id" end
	if not carbonData then return "副本id不存在" end
	local pt_ids = mapBattleCsv:get_pt_ids()

	for _, id in ipairs(pt_ids) do
		if id > carbonId then break end
		if not role.carbons[id] then
			role:addCarbon({carbonId = id,status = 1,starNum = 3,})
		end
	end

	local pt_c = math.floor((carbonId - 10000) / 100)

	if pt_c > 2 then
		local jy_line = 20000 + pt_c*100
		local jy_ids = mapBattleCsv:get_jy_ids()
		for _, id in ipairs(jy_ids) do
			if id > jy_line then break end
			if not role.carbons[id] then
				role:addCarbon({carbonId = id,status = 1,starNum = 3,})
			end
		end

		local dy_line = 30000 + pt_c*100
		local dy_ids = mapBattleCsv:get_dy_ids()
		for _, id in ipairs(dy_ids) do
			if id > dy_line then break end
			if not role.carbons[id] then
				role:addCarbon({carbonId = id,status = 1,starNum = 3,})
			end
		end
	end
	return "指令生效"
end

function _M.yuanzheng(role, pms)
	role.dailyData:setProperty("expeditionResetCount", 0)
	return "指令生效"
end

function _M.shengwang(role, pms)
	local zhangong = tonumber(pms.pm1)
	role:addReputation(pms.pm1)
	return "指令生效"
end

function _M.skip_guide(role, pms)
	local activedGuide = "1111111111111111111111111111111111111111111111111111111111111111"
	role:setProperty("activedGuide", activedGuide)
	role:setProperty("guideStep", 1000)
	role:notifyUpdateProperties({
		{key = "guideStep", newValue = 1000},
		{key = "activedGuide", newValue = activedGuide},
	})
	return "指令生效"
end

---用于游戏内逻辑测试---

function _M.event(role, pms)
	local bin = pb.encode("NewMessageNotify", {key = "sign", value = 1})
	SendPacket(actionCodes.RoleNotifyNewEvents, bin)
	return "指令生效"
end

function _M.all_equip(role, pms)
	local ids = equipCsv:getAllEquipIds()
	for _, id in ipairs(ids) do
		role:addEquip({id = id})
	end
	return "指令生效"
end

function _M.silent(role, pms)
	local days = tonumber(pms.pm1)
	if days < 1 then
		role:setProperty("silent", 0)
		return "解禁生效"
	end
	local silent = role:getProperty("silent")
	role:setProperty("silent", silent + days * 86400)
	return "禁言生效"
end

return _M