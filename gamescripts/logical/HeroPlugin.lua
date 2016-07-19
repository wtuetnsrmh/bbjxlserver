local Role = require "datamodel.Role"

local HeroPlugin = {}

function HeroPlugin.bind(Hero)
	-- 等级升级所需总经验
	function Hero:getLevelExp(level)
		return heroExpCsv:getLevelUpExp(level)
	end

	-- 等级升级所需总经验
	function Hero:getLevelTotalExp()
		return self:getLevelExp(self:getProperty("level"))
	end

	-- 得到升级所需剩余经验
	function Hero:getLevelUpExp()
		return self:getLevelExp(self:getProperty("level")) - self:getProperty("exp")
	end

	-- 得到升到角色满级的所需总经验
	function Hero:getLevelMaxExp(roleLevel)
		local heroLevel = self:getProperty("level")

		if roleLevel >= heroLevel then
			local totalExp = self:getLevelUpExp()
			for index = heroLevel, roleLevel-1 do
				totalExp = totalExp + self:getLevelExp(index)
			end
			return totalExp
		end
	end

	-- 得到出售武将所得钱
	function Hero:getSellMoney(onlyExp)
		local totalExp = 0
		for level = 1, self:getProperty("level") - 1 do
			totalExp = totalExp + self:getLevelExp(level)
		end
		totalExp = totalExp + self:getProperty("exp")
		local money = totalExp * globalCsv:getFieldValue("moneyPerExp")
		return onlyExp and money or money + self.unitData.sellMoney
	end

	-- 得到此卡的祭司经验
	function Hero:getWorshipExp()
		local level = self:getProperty("level")
		local totalExp = self.unitData.worshipExp - tonum(self.unitData.worshipExpGrowth[1][3])
		for _,value in ipairs(self.unitData.worshipExpGrowth) do 
			local min = tonum(value[1])
			local max = tonum(value[2])
			local add = tonum(value[3])

			if level >= min and level <= max then
				totalExp = totalExp + (level - (min-1)) * add
			elseif level > max then
				totalExp = totalExp + (max - (min-1)) * add
			end
		end
		return totalExp
	end

	-- 根据强化等级和进化次数计算的基础值
	function Hero:getBaseAttrValues()
		return Hero.sGetBaseAttrValues(self.owner:getProperty("id"), self:getProperty("id"))
	end

	function Hero.sGetBaseAttrValues(roleId, heroId)
		local heroInfo = redisproxy:hmget(string.format("hero:%d:%d", roleId, heroId), 
			"type", "level", "evolutionCount", "wakeLevel", "star")

		local type, level, evolutionCount, wakeLevel, star = tonumber(heroInfo[1]), tonumber(heroInfo[2]),
			tonumber(heroInfo[3]), tonumber(heroInfo[4]), tonumber(heroInfo[5])

		local unitData = unitCsv:getUnitByType(type)
		local hpBase = unitData.hp + (level - 1) * unitData.hpGrowth
		local atkBase = unitData.attack + (level - 1) * unitData.attackGrowth
		local defBase = unitData.defense + (level - 1) * unitData.defenseGrowth

		local hpFactor, atkFactor, defFactor = evolutionModifyCsv:getModifies(evolutionCount)
		local starFactor = globalCsv:getFieldValue("starFactor")[star]
		local attrs = { hp = hpBase * (hpFactor + starFactor - 1), atk = atkBase * (atkFactor + starFactor - 1), def = defBase * (defFactor + starFactor - 1) }
		for key, value in pairs(EquipAttEnum) do
			if not attrs[key] then
				attrs[key] = unitData[key] or 0
			end
		end
		return attrs
	end

	-- 得到武将的总属性
	function Hero.sGetTotalAttrValues(roleId, heroId)
		local assistantBonus = {}		-- 副将加成
		local techBonus = {}			-- 科技加成
		local starBonus = {}			-- 星魂加成
		local beautyBonus = {}			-- 美人加成

		local basicValues = Hero.sGetBaseAttrValues(roleId, heroId)

		techBonus = Hero.sGetProfessionBonusValues(roleId, heroId, basicValues)
		techBonus.hp = techBonus.hpBonus
		techBonus.atk = techBonus.atkBonus
		techBonus.def = techBonus.defBonus

		starBonus = Hero.sGetStarSoulBonusValues(roleId, heroId)
		starBonus.hp = starBonus.hpBonus
		starBonus.atk = starBonus.atkBonus
		starBonus.def = starBonus.defBonus

		beautyBonus = Role.sGetBeautyBonusValues(roleId)
		beautyBonus.hp = beautyBonus.hpBonus
		beautyBonus.atk = beautyBonus.atkBonus
		beautyBonus.def = beautyBonus.defBonus

		--装备属性
		local equipAttrs = Hero.sGetEquipAttrs(roleId, heroId)
		--情缘
		local relationAttrs = Hero.sGetRelationBonusValues(roleId, heroId, basicValues)
		--战魂
		local battleSoulAttrs = Hero.sGetBattleSoulAttrs(roleId, heroId)

		attrs = {}
		for key, value in pairs(EquipAttEnum) do
			attrs[key] = math.floor((basicValues[key] or 0) + (assistantBonus[key] or 0) + (techBonus[key] or 0) 
						+ (starBonus[key] or 0) + (beautyBonus[key] or 0) + (equipAttrs[key] or 0) + (relationAttrs[key] or 0) + (battleSoulAttrs[key] or 0))
		end

		return attrs
	end

	local function getHeroSlot(slots, heroId)
		for slot, data in pairs(slots) do
			if tonumber(data.heroId) == tonumber(heroId) then
				return tonumber(slot)
			end
		end
		return 0
	end

	-- 根据职业加成计算属性加成值
	function Hero.sGetProfessionBonusValues(roleId, heroId, baseValues)
		local heroType = tonumber(redisproxy:hget(string.format("hero:%d:%d", roleId, heroId), "type"))
		local unitData = unitCsv:getUnitByType(heroType)

		local bonuses = Role.sGetProfessionBonus(roleId, unitData.profession)
		if not baseValues then
			baseValues = Hero.sGetBaseAttrValues(roleId, heroId)
		end

		return { hpBonus = baseValues.hp * bonuses[3] / 100, atkBonus = baseValues.atk * bonuses[1] / 100, 
			defBonus = baseValues.def * bonuses[2] / 100 }
	end

	-- 根据星魂计算阵营加成值
	function Hero.sGetStarSoulBonusValues(roleId, heroId)
		local allBonuses = Role.sCalStarAttrBonuses(roleId)

		local heroType = tonumber(redisproxy:hget(string.format("hero:%d:%d", roleId, heroId), "type"))
		local unitData = unitCsv:getUnitByType(heroType)

		local professionBonuses = allBonuses[unitData.camp]

		return { hpBonus = professionBonuses.hpBonus or 0, atkBonus = professionBonuses.atkBonus or 0, 
			defBonus = professionBonuses.defBonus or 0 }
	end

	-- 装备属性加成
	function Hero.sGetEquipAttrs(roleId, heroId)
		local slotsJson = redisproxy:hget(string.format("role:%d", roleId), "slotsJson")
		local slots = json.decode(slotsJson)

		local slot = getHeroSlot(slots, heroId)
		if slot == 0 then
			equips = {}
		else
			equips = slots[tostring(slot)].equips or {}
		end

		local attrs = {}
		local sets = {}
		local cjson = require("cjson")
	
		for _, equipId in pairs(equips) do
			if equipId ~= cjson.null then
				local equip = require("datamodel.Equip").new({ key = string.format("equip:%d:%d", roleId, equipId)})
				equip:load()
				local equipAttrs = equip:getBaseAttributes()
				--基础属性
				for key, value in pairs(EquipAttEnum) do
					attrs[key] = (attrs[key] or 0) + (equipAttrs[key] or 0)
				end
				
				--套装
				if equip.csvData.setId ~= 0 then		

					sets[equip.csvData.setId] = (sets[equip.csvData.setId] or 0) + 1
				end
			end
		end

		--套装效果
		for setId, count in pairs(sets) do
			if count >= 2 then
				count = math.min(count, 4)
				local setCsv = equipSetCsv:getDataById(setId)
				for effectCnt = 2, count do
					for key, value in pairs(EquipAttEnum) do
						attrs[key] = (attrs[key] or 0) + (setCsv["effect" .. effectCnt][value] or 0)
					end
				end
			end
		end 

		return attrs

	end

	function Hero.sGetRelationBonusValues(roleId, heroId, baseValues)
		local cjson = require("cjson")
		local slotsJson = redisproxy:hget(string.format("role:%d", roleId), "slotsJson")
		local slots = json.decode(slotsJson)

		local relationAttrs = {}
		local slot = getHeroSlot(slots, heroId)
		if slot == 0 then
			return relationAttrs
		end

		local heroType = tonumber(redisproxy:hget(string.format("hero:%d:%d", roleId, heroId), "type"))
		local unitData = unitCsv:getUnitByType(heroType)
		if not unitData.relation then
			return relationAttrs
		end

		if not baseValues then
			baseValues = Hero.sGetBaseAttrValues(roleId, heroId)
		end

		local heroTypes = {}
		--出战types
		for _, value in pairs(slots) do
			if value ~= cjson.null and value.heroId and value.heroId ~= 0 then
				table.insert(heroTypes, value.heroId)
			end
		end

		--加入小伙伴types
		local partnersJson = redisproxy:hget(string.format("role:%d", roleId), "partnersJson")
		if partnersJson == "" then partnersJson = '[]' end
		local partners = cjson.decode(partnersJson)
		for _, heroType in pairs(partners) do
			if heroType ~= cjson.null then
				table.insert(heroTypes, heroType)
			end
		end

		--武器types
		
		local equipTypes = {}
		equips = slots[tostring(slot)].equips or {}
		for _, equipId in pairs(equips) do
			if equipId ~= cjson.null then
				table.insert(equipTypes, tonumber(redisproxy:hget(string.format("equip:%d:%d", roleId, equipId), "type")))
			end
		end	

		local relations = {}
		for _, relation in pairs(unitData.relation) do
			if relation[1] == 1 and table.contain(heroTypes, relation[2]) then
				table.insert(relations, relation)
			elseif relation[1] == 2 and table.contain(equipTypes, relation[2]) then
				table.insert(relations, relation)
			end
		end

		for _, relation in pairs(relations) do
			for index = 1, #relation[3] do	
				local key = table.keyOfItem(EquipAttEnum, relation[3][index])
				if key then
					relationAttrs[key] = (relationAttrs[key] or 0) + (baseValues[key] or 0) * relation[4][index] / 100 + relation[5][index]
				end
			end
		end
		return relationAttrs
	end

	function Hero.sGetBattleSoulAttrs(roleId, heroId)
		local heroInfo = redisproxy:hmget(string.format("hero:%d:%d", roleId, heroId), 
			"type", "evolutionCount", "battleSoulJson")
		local type, evolutionCount, battleSoul = tonumber(heroInfo[1]), tonumber(heroInfo[2]), json.decode(heroInfo[3]) or {}
		local unitData = unitCsv:getUnitByType(type)
		local attrs = {hp = 0, atk = 0, def = 0}
		--先加上以前累积的
		for evolCount = 1, evolutionCount do
			local resources = unitData["evolMaterial" .. evolCount]
			for _, itemId in ipairs(resources) do
				local id = itemId - battleSoulCsv.toItemIndex
				local data = battleSoulCsv:getDataById(id)
				if data then
					attrs.hp = attrs.hp + data.hp
					attrs.atk = attrs.atk + data.atk
					attrs.def = attrs.def + data.def
				end
			end
		end

		local resources = unitData["evolMaterial" .. (evolutionCount + 1)]
		if resources then 
			--再加上现在镶嵌的
			for slot in pairs(battleSoul) do
				local itemId = resources[tonum(slot)]
				local id = tonum(itemId) - battleSoulCsv.toItemIndex
				local data = battleSoulCsv:getDataById(id)
				if data then
					attrs.hp = attrs.hp + data.hp
					attrs.atk = attrs.atk + data.atk
					attrs.def = attrs.def + data.def
				end
			end
		end
		return attrs
	end

	-- 得到此卡的祭司金币
	function Hero:getWorshipMoney()
		return self:getWorshipExp() * globalCsv:getFieldValue("intensifyGoldNum")
	end
end

return HeroPlugin