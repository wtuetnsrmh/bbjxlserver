local Hero = require("datamodel.Hero")

local Soldier = class("Soldier")

function Soldier:ctor(params)
	self.battle = params.battle
	self.battleField = params.battleField

	self.position = { x = 0 , y = 0 } -- 真实坐标
	self.anchPoint = { x = params.anchPointX or 0, y = params.anchPointY or 0,}	--	相对坐标, 武将的锚点(1, 1)
	self.camp = params.camp or "left"	-- 阵营
	self.beBoss = params.beBoss or false	-- 敌方阵营boss
	self.assistHero = params.assistHero or false 	-- 助战武将

	-- 武将基本属性
	self.id = params.id or 0
	self.csvId = params.csvId or 0
	self.level = params.level or 0
	self.type = params.type or 0
	self.evolutionCount = params.evolutionCount or 0
	self.skillLevel = params.skillLevel or 1

	self.unitData = unitCsv:getUnitByType(self.type)
	self.heroProfession = heroProfessionCsv:getDataByProfession(self.unitData.profession)
	
	self.exp = params.exp or 0
	self.createTime = params.createTime or 0
	self.name = params.name or self.unitData.name

	-- pve敌人
	self.skillable = params.skillable or false
	self.skillCdTime = params.skillCdTime or 0
	self.skillWeight = params.skillWeight or 0

	-- 状态变量
	self.hasDead = false
	self.hasPaused = false
	self.inSkillAttack = false
	self.waitFrame = math.huge

	-- 武将的一些战斗属性值
	self.hp = params.hp or 0
	self.maxHp = self.hp 	-- 最大血量

	self.attack = params.attack or 0
	self.curAttack = self.attack 	-- 当前攻击力

	self.attackRange = params.attackRange or 0	--攻击范围

	self.attackSpeed = params.attackSpeed or 0	--攻击间隔时间
	self.curAttackSpeed = self.attackSpeed 	-- 当前攻击间隔时间
	self.attackDetectPoint = 0	-- 检测点

	self.moveSpeed = params.moveSpeed or 0		--原始移动速度
	self.curMoveSpeed = self.moveSpeed 	--目前移动速度

	self.defense = params.defense or 0
	self.curDefense = self.defense

	-- 伤害减免
	self.derateOtherAtk = 0
	self.curDerateOtherAtk = self.derateOtherAtk

	-- 最终伤害减免
	self.hurtDerate = 0
	self.curHurtDerate = self.hurtDerate

	-- 暴击
	self.crit = params.crit or self.unitData.crit
	self.curCrit = self.crit

	-- 暴伤
	self.critHurt = params.critHurt or self.unitData.critHurt
	self.curCritHurt = self.critHurt

	-- 韧性
	self.tenacity = params.tenacity or self.unitData.tenacity
	self.curTenacity = self.tenacity

	-- 抵抗
	self.resist = params.resist or self.unitData.resist
	self.curResist = self.resist

	-- 闪避
	self.miss = params.miss or self.unitData.miss
	self.curMiss = self.miss

	-- 命中
	self.hit = params.hit or self.unitData.hit
	self.curHit = self.hit

	-- 格挡
	self.parry = params.parry or self.unitData.parry
	self.curParry = self.parry

	-- 破击
	self.ignoreParry = params.ignoreParry or self.unitData.ignoreParry
	self.curIgnoreParry = self.ignoreParry

	self.slowdown = false 	-- 缓速
	self.buqu = false

	-- 技能cd时间
	self.skillCd = 0

	-- 具体的实现技能和buff类
	self.reflections = {
		skill = params.skillDef or "logical.battle.Skill",
		buff = params.buffDef or "logical.battle.Buff"
	}

	-- 上场后, 身上携带的组合技
	self.associationSkills = {}

	-- 武将的被动技能
	self.passiveSkills = {}
	self:initPassiveSkills()

	-- 被作用的buff
	self.buffIndex = 1
	self.buffs = {}

	-- 武将状态机
	cc.GameObject.extend(self):addComponent("components.behavior.StateMachine"):exportMethods()
	self:initEventMap()
end

function Soldier:initEventMap()
	self:setupState({
		initial = "standby",

		events = {
			{ name = "ToIdle", from = "move", to = "standby" },
			{ name = "ToIdle", from = "attack", to = "standby" },
			{ name = "ToIdle", from = "skillAttack", to = "standby" },
			{ name = "ToIdle", from = "damaged", to = "standby"},
			{ name = "ToIdle", from = "dizzy", to = "standby" },
			{ name = "ToIdle", from = "frozen", to = "standby" },
			{ name = "BeginAttack", from = "standby", to = "attack" },
			{ name = "BeginAttack", from = "move", to = "attack" },
			{ name = "BeginAttack", from = "dizzy", to = "attack" },
			{ name = "BeginAttack", from = "frozen", to = "attack" },
			{ name = "BeginSkillAttack", from = "standby", to = "skillAttack" },
			{ name = "BeginSkillAttack", from = "move", to = "skillAttack" },
			{ name = "BeginSkillAttack", from = "attack", to = "skillAttack" },
			{ name = "BeginSkillAttack", from = "frozen", to = "skillAttack" },
			{ name = "BeginSkillAttack", from = "dizzy", to = "skillAttack" },
			{ name = "BeginSkillAttack", from = "damaged", to = "skillAttack" },
			{ name = "BeDamaged", from = "standby", to = "damaged" },
			{ name = "BeDamaged", from = "move", to = "damaged" },
			{ name = "BeDamaged", from = "attack", to = "damaged" },
			{ name = "BeDamaged", from = "damaged", to = "damaged" },
			{ name = "Freeze", from = "standby", to = "frozen" },
			{ name = "Freeze", from = "move", to = "frozen" },
			{ name = "Freeze", from = "attack", to = "frozen" },
			{ name = "Freeze", from = "dizzy", to = "frozen" },
			{ name = "ToDizzy", from = "standby", to = "dizzy" },
			{ name = "ToDizzy", from = "move", to = "dizzy" },
			{ name = "ToDizzy", from = "attack", to = "dizzy" },
			{ name = "ToDizzy", from = "frozen", to = "dizzy" },
			{ name = "BeginMove", from = "standby", to = "move" },
			{ name = "BeginMove", from = "attack", to = "move" },
			{ name = "BeginMove", from = "frozen", to = "move" },
			{ name = "BeginMove", from = "dizzy", to = "move" },
			{ name = "BeKilled", from = "*", to = "dead" },
		},

		callbacks = {
			onStart = function(event) end,
			onToIdle = function(event) end,
			-- 开始攻击状态
			onBeginAttack = function(event)
				self.waitFrame = math.random(0, 30)
			end,
			onBeginSkillAttack = function(event) end,
			onBeginMove = function(event)
				self.waitFrame = math.random(0, 30)
			end,
			onBeKilled = function(event) end,

			onbeforeFreeze = function(event) self:saveStatus() end,
			onbeforeToDizzy = function(event) self:saveStatus() end,
			
			-- 离开攻击状态
			onleaveattack = function(event)
				self.attackDetectPoint = 0
				self.waitFrame = math.huge
			end,
			onleaveskillAttack = function(event) self.inSkillAttack = false end,

			-- 受击
			onenterdamaged = function(event) self:onDamaged() end,

			-- 眩晕
			onenterdizzy = function(event) self:onDizzy() end,

			-- 冰冻
			onenterfrozen = function(event) self:onPause(true) end,
		}
	})
end

function Soldier:getAnchKey()
	return self.camp .. self.anchPoint.x .. self.anchPoint.y
end

function Soldier:saveStatus()
	self.lastEventName = self:getEventName()
end

function Soldier:restoreStatus()
	self:doEvent(self.lastEventName)
end

-- 玩家自己的武将属性
function Soldier:initHeroAttribute(params)
	params = params or {}

	local heroProfessionInfo = heroProfessionCsv:getDataByProfession(self.unitData and self.unitData.profession or 0)

	local totalAttrValues
	if game.role.heros[self.id] then
		local hero = game.role.heros[self.id]
		totalAttrValues = hero:getTotalAttrValues()
	else
		totalAttrValues = Hero.sGetBaseAttrValues(self.type, self.level, self.evolutionCount)
	end
	local hpModify, atkModify, defModify = params.hpModify or 0, atkModify or 0, defModify or 0
	-- 战斗属性修正

	self.hp = totalAttrValues.hp * (100 + hpModify) / 100
	self.maxHp = self.hp

	self.attack = totalAttrValues.atk * (100 + atkModify) / 100
	self.curAttack = self.attack

	self.defense = totalAttrValues.def * (100 + defModify) / 100
	self.curDefense = self.defense

	self:initHeroAttributeByPassiveSkills()

	-- 战斗属性替换
	self.moveSpeed = (self.unitData.moveSpeed ~= 0 and self.unitData.moveSpeed or heroProfessionInfo.moveSpeed) / 1000
	self.curMoveSpeed = self.moveSpeed

	self.attackSpeed = self.unitData.attackSpeed ~= 0 and self.unitData.attackSpeed or heroProfessionInfo.attackSpeed
	self.curAttackSpeed = self.attackSpeed

	self.attackRange = self.unitData.atcRange ~= 0 and self.unitData.atcRange or heroProfessionInfo.atcRange
end

function Soldier:initHeroAttributeByPassiveSkills()
	local passiveSkills = {}
	table.insertTo(passiveSkills, self.passiveSkills)
	if self.camp == "left" then
		table.insertTo(passiveSkills, game.role:getFightBeautySkills())
	end

	local basicAttrValues = Hero.sGetBaseAttrValues(self.type, self.level, self.evolutionCount)
	-- 没有触发条件的被动技能去更新初始值
	for _,value in ipairs(passiveSkills) do
		local passiveSkill = skillPassiveCsv:getPassiveSkillById(value)

		if not passiveSkill then
			return
		end

		-- 没有触发条件的被动技能
		if passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_NONE)] then
			if passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_ATK)] then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_ATK)])
				self.attack = self.attack  +  basicAttrValues.atk * effectValue / 100
				self.curAttack = self.attack
			elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_DEFENSE)] then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_DEFENSE)])
				self.defense = self.defense + basicAttrValues.def * effectValue / 100
				self.curDefense = self.defense
			elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HP)] then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HP)])
				self.hp = self.hp + basicAttrValues.hp * effectValue / 100
				self.maxHp = self.hp
			elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_CRIT)] then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_CRIT)])
				self.crit = self.crit + effectValue
				self.curCrit = self.crit
			elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_TENACITY)] then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_TENACITY)])
				self.tenacity = self.tenacity + effectValue
				self.curTenacity = self.tenacity
			elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_CRIT_HURT)] then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_CRIT_HURT)])
				self.critHurt = self.critHurt + effectValue
				self.curCritHurt = self.critHurt
			elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_MISS)] then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_MISS)])
				self.miss = self.miss + effectValue
				self.curMiss = self.miss
			elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HIT)] then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HIT)])
				self.hit = self.hit + effectValue
				self.curHit = self.hit
			elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_PARRY)] then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_PARRY)])
				self.parry = self.parry + effectValue
				self.curParry = self.parry
			elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_IGNORE_PARRY)] then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_IGNORE_PARRY)])
				self.ignoreParry = self.ignoreParry + effectValue
				self.curIgnoreParry = self.ignoreParry
			elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_RESIST)] then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_RESIST)])
				self.resist = self.resist + effectValue
				self.curResist = self.resist
			end
		end
	end
end

-- 根据职业和阵营重新计算武将属性的加成
function Soldier:reCalcAttrByPassiveSkills(soldiers)
	for _,skillId in pairs(self.passiveSkills) do
		local passiveSkill = skillPassiveCsv:getPassiveSkillById(skillId)

		-- 职业加成
		if passiveSkill and passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_PROFESSION)] then
			local profession = tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_PROFESSION)])
			for _,soldier in pairs(soldiers) do
				if soldier.unitData.profession == profession then
					if passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_ATK)] then
						local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_ATK)])
						soldier.attack = soldier.attack * ( 100 + effectValue ) / 100
						soldier.curAttack = soldier.attack
					elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_DEFENSE)] then
						local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_DEFENSE)])
						soldier.defense = soldier.defense * ( 100 + effectValue ) / 100
						soldier.curDefense = soldier.defense
					elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HP)] then
						local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HP)])
						soldier.hp = soldier.hp * ( 100 + effectValue ) / 100
						soldier.maxHp = soldier.hp
					end
				end
			end
		end

		-- 阵营加成
		if passiveSkill and passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_CAMP)] then
			local camp = tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_CAMP)])
			for _,soldier in pairs(soldiers) do
				if soldier.unitData.camp == camp then
					if passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_ATK)] then
						local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_ATK)])
						soldier.attack = soldier.attack * ( 100 + effectValue ) / 100
						soldier.curAttack = soldier.attack
					elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_DEFENSE)] then
						local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_DEFENSE)])
						soldier.defense = soldier.defense * ( 100 + effectValue ) / 100
						soldier.curDefense = soldier.defense
					elseif passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HP)] then
						local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HP)])
						soldier.hp = soldier.hp * ( 100 + effectValue ) / 100
						soldier.maxHp = soldier.hp
					end
				end
			end
		end

	end

end

-- 阶段性恢复生命
function Soldier:recoverHp()
	self.hp = self.hp + self.maxHp * globalCsv:getFieldValue("phaseRecoverHp") / 100
	if self.hp > self.maxHp then 
		self.hp = self.maxHp 
	end
end

function Soldier:resetAttribute()
	self.curAttack = self.attack
	self.curDefense = self.defense
	self.curMoveSpeed = self.moveSpeed
	self.curAttackSpeed = self.attackSpeed
	self.curDerateOtherAtk = self.derateOtherAtk
	self.curHurtDerate = self.hurtDerate
	-- 二级属性
	self.curCrit = self.crit
	self.curTenacity = self.tenacity
	self.curCritHurt = self.critHurt
	self.curResist = self.resist
	self.curMiss = self:calMissValue()
	self.curHit = self.hit
	self.curParry = self.parry
	self.curIgnoreParry = self.ignoreParry

	self.slowdown = false
end

function Soldier:updateFrame()
	if self.hasPaused then return end

	-- BUFF都是在原始属性上修改
	self:resetAttribute()

	-- 身上的buff全部走一遍
	local breakUpdate = false
	local deleteBuffs = {}
	for id, buff in pairs(self.buffs) do
		-- 技能攻击状态下, 中毒和加血BUFF暂停
		if self:getState() ~= "skillAttack" or not (buff.csvData.type == 1 or buff.csvData.type == 4) then
			local result = buff:effect(self)
			if result == 0 then deleteBuffs[#deleteBuffs + 1] = id end
			if result == 2 and not breakUpdate then breakUpdate = true end
		end
	end
	-- 删除结束的BUFF
	for _, key in ipairs(deleteBuffs) do
		self.buffs[key] = nil
	end

	-- 眩晕或者冰冻
	if breakUpdate then return end

	while true do
		while self:getState() == "standby" do
			local enemy = self.battleField:getAttackObject(self)
			if not enemy then
				self:onStandby({})
				return
			end

			-- 判定移动优先还是攻击优先
			if globalCsv:getFieldValue("battleMoveFirst") == 1 then
				if self:canMove(1) then
					self:doEvent("BeginMove")
					break
				end

				-- 有可以攻击的敌人
				if self:canAttack(enemy) == true then
					self:doEvent("BeginAttack")
					break
				end
			else
				-- 有可以攻击的敌人
				if self:canAttack(enemy) == true then
					self:doEvent("BeginAttack")
					break
				end

				if self:canMove(1) then
					self:doEvent("BeginMove")
					break
				end
			end

			self:onStandby({})
			return
		end

		while self:getState() == "move" do
			if self.waitFrame ~= math.huge and self.waitFrame > 0 then
				self:onStandby()
				self.waitFrame = self.waitFrame - 1
				return
			end
			local enemy = self.battleField:getAttackObject(self)
			if not enemy then
				self:doEvent("ToIdle")
				break
			end

			-- 有可以攻击的敌人, 并且正前方没有队友
			if globalCsv:getFieldValue("battleMoveFirst") == 1 then
				if self:canAttack(enemy) and self.battleField:beforeXTeamer(self) == nil then
					self:doEvent("BeginAttack")
					break
				end
			end

			local curMoveSpeed = self:modifyMoveSpeed()
			local elapseTime = self.battle.frame
			-- 是否降速
			local moveDistance = curMoveSpeed * elapseTime / (self.slowdown and 2 or 1)
			local continueMove, canMoveDistance = self:canMove(moveDistance)
			if not continueMove then
				self:beingMove({ beginX = self.position.x, offset = canMoveDistance, time = elapseTime })
				self:doEvent("ToIdle")
				return
			end

			self:beingMove({ beginX = self.position.x, offset = moveDistance, time = elapseTime })

			if globalCsv:getFieldValue("battleMoveFirst") == 0 or not self:canMove(1) then
				-- 有可以攻击的敌人
				local enemy = self.battleField:getAttackObject(self)
				if enemy and self:canAttack(enemy) then
					self:doEvent("BeginAttack")
					break
				end
			end

			return
		end

		-- 冰冻
		while self:getState() == "frozen" do
			self:onFrozen()
			return
		end

		-- 眩晕
		while self:getState() == "damaged" do
			return
		end

		-- 普攻
		while self:getState() == "attack" do
			if self.waitFrame ~= math.huge and self.waitFrame > 0 then
				self:onStandby()
				self.waitFrame = self.waitFrame - 1
				return
			end

			-- 验证最近的敌人
			local enemy = self.battleField:getAttackObject(self)
			if not enemy then
				self:doEvent("BeginMove")
				break
			end
			-- 计算伤害值
			local hurtValue,restraintValue = self:calcHurtValue(self, enemy)
			local finalValues = self:secondAttrEffect({ enemy = enemy, hurtValue = hurtValue})

			-- 如果还在攻击cd范围内
			local inAttackCd = self.attackDetectPoint > 0
			if inAttackCd and self:canAttack(enemy) then
				self:checkAttackStatus({ enemy = enemy, hurtValues = finalValues, restraint = restraintValue})
				local elapseTime = self.slowdown and (self.battle.frame / 2) or self.battle.frame
				self.attackDetectPoint = self.attackDetectPoint - self.battle.frame
				return

			elseif self:canAttack(enemy) then
				if not self:releasePassiveSkill() then
					self:onAttack({ enemy = enemy , text = text, atk = atk, type = 1})
				else
					self:onAttack({ enemy = enemy , text = text, atk = atk, type = 2})
				end
				self.attackDetectPoint = self.curAttackSpeed
				return

			else
				-- 最近敌人已经被消灭
				self:doEvent("BeginMove")
				break
			end
		end

		-- 技能
		while self:getState() == "skillAttack" do
			if self.inSkillAttack then
				self:checkSkillAttackStatus()
				return
			else
				self:onSkillAttack({})
				self.inSkillAttack = true
				return
			end
		end

		if self:getState() == "dead" then
			-- 如果死掉, 需要从战场上移掉
			self:onDeath({})
			break
		end
	end
end

-- 处理被动技能
function Soldier:handlePassiveSkill(atkSoldier, defSoldier)

	-- 攻击相关
	for _,skillId in ipairs(atkSoldier.passiveSkills) do
		local passiveSkill = skillPassiveCsv:getPassiveSkillById(skillId)

		-- 攻击职业
		if passiveSkill and passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_PROFESSION)] then
			local triggerValue = tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_PROFESSION)])
			if triggerValue == defSoldier.unitData.profession then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_ATK)])
				atkSoldier.curAttack = atkSoldier.curAttack * ( 100 + effectValue ) / 100
			end
		end

		-- 攻击阵营
		if passiveSkill and passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_CAMP)] then
			local triggerValue = tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_CAMP)])
			if triggerValue == defSoldier.unitData.camp then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_ATK)])
				atkSoldier.curAttack = atkSoldier.curAttack * ( 100 + effectValue ) / 100
			end
		end

		-- 攻击性别
		if passiveSkill and passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_SEX)]then
			local triggerValue = tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_SEX)])
			if triggerValue == defSoldier.unitData.sex then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_ATK)])
				atkSoldier.curAttack = atkSoldier.curAttack * ( 100 + effectValue ) / 100
			end
		end
	end

	-- 被攻击相关
	for _,skillId in ipairs(defSoldier.passiveSkills) do
		local passiveSkill = skillPassiveCsv:getPassiveSkillById(skillId)

		-- 被职业攻击
		if passiveSkill and passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_BY_PROFESSION)] then
			local triggerValue = tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_BY_PROFESSION)])
			if triggerValue == atkSoldier.unitData.profession then
				if table.nums(passiveSkill.triggerMap) == 1 then
					local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HURT_LESS)])
					defSoldier.curHurtDerate = effectValue / 100
				elseif passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_PROFESSION)] and 
					tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_PROFESSION)]) == defSoldier.unitData.profession then
					local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HURT_LESS)])
					defSoldier.curHurtDerate = effectValue / 100
				end
			end
		end

		-- 被阵营攻击
		if passiveSkill and passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_BY_CAMP)] then
			local triggerValue = tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_BY_CAMP)])
			if triggerValue == atkSoldier.unitData.camp then
				local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HURT_LESS)])
				defSoldier.curHurtDerate = effectValue / 100
			end
		end
	end

	-- 被攻击美人计相关
	if defSoldier.camp == "left" then
		local beautySkills = game.role:getFightBeautySkills()
		for _,skillId in ipairs(beautySkills) do
			local passiveSkill = skillPassiveCsv:getPassiveSkillById(skillId)

			-- 被职业攻击
			if passiveSkill and passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_BY_PROFESSION)] then
				local triggerValue = tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_BY_PROFESSION)])
				if triggerValue == atkSoldier.unitData.profession then
					if table.nums(passiveSkill.triggerMap) == 1 then
						local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HURT_LESS)])
						defSoldier.curHurtDerate = effectValue / 100
					elseif passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_PROFESSION)] and 
						tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_PROFESSION)]) == defSoldier.unitData.profession then
						local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HURT_LESS)])
						defSoldier.curHurtDerate = effectValue / 100
					end
				end
			end

			-- 被阵营攻击
			if passiveSkill and passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_BY_CAMP)] then
				local triggerValue = tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_ATK_BY_CAMP)])
				if triggerValue == atkSoldier.unitData.camp then
					local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_HURT_LESS)])
					defSoldier.curHurtDerate = effectValue / 100
				end
			end
		end
	end
end

	-- 计算伤害值
function Soldier:calcHurtValue(atkSoldier, defSoldier)
	self:handlePassiveSkill(atkSoldier, defSoldier)
	-- 敌人可能有减免BUFF
	local restraintValue = restraintCsv:getValue(atkSoldier.unitData.profession, defSoldier.unitData.profession) / 100
	local attackValue = atkSoldier.curAttack * (100 - defSoldier.curDerateOtherAtk) / 100
	local enemyDefense = defSoldier.curDefense / (attackValue * globalCsv:getFieldValue("k2") + defSoldier.curDefense * globalCsv:getFieldValue("k3"))
	local hurtValue = globalCsv:getFieldValue("k1") * attackValue * restraintValue * (1 - enemyDefense) * (1 - defSoldier.curHurtDerate)

	return hurtValue,restraintValue
end

-- 通过二次属性计算新的伤害值
function Soldier:secondAttrEffect(params)
	params = params or {}

	local effect = "normal"
	local miss = math.min(math.max(globalCsv:getFieldValue("missFloor"), params.enemy.curMiss - self.curHit), globalCsv:getFieldValue("missCeil"))
	if math.random(0, 100) <= miss then
		-- 闪避成功
		return { enemy = 0, self = 0 , effect = "miss"}
	end

	local enemyHurtValue, selfHurtValue = 0, 0
	local parry = math.min(math.max(globalCsv:getFieldValue("parryFloor"), params.enemy.curParry - self.curIgnoreParry), globalCsv:getFieldValue("parryCeil"))	
	if math.random(0, 100) <= parry then
		-- 格挡成功
		enemyHurtValue = params.hurtValue * 0.6
		selfHurtValue = params.hurtValue * 0.4
		effect = "parry"
	else
		local crit = math.min(math.max(globalCsv:getFieldValue("critFloor"), self.curCrit - params.enemy.curTenacity), globalCsv:getFieldValue("critCeil"))	
		if  math.random(0, 100) <= crit then
			enemyHurtValue = params.hurtValue * self.curCritHurt / 100
			effect = "crit"
		else
			enemyHurtValue = params.hurtValue
		end
	end

	return { enemy = enemyHurtValue, self = selfHurtValue , effect = effect}
end

-- 是否可以攻击
-- @param enemy 	被攻击方
-- @return 能攻击返回true, 否则false
function Soldier:canAttack(enemy)
	if not enemy then return false end

	local enemyPosX = enemy.position.x
	if self.anchPoint.y ~= enemy.anchPoint.y then
		enemyPosX = enemy.anchPoint.y == 2 and enemyPosX + self.battleField.xPosOffset or enemyPosX - self.battleField.xPosOffset
	end
	local distance = math.abs(self.position.x - enemyPosX)

	-- 左边优先一个像素的距离
	if self.camp == "left" then
		distance = distance - 1
	end

	if distance > self.attackRange then return false end

	-- 距离允许
	return true
end

function Soldier:canReleaseSkill()
	if self.hp <= 0 then return false end
	if self.hasPaused then return false end

	local state = self:getState()
	if state == "skillAttack" or state == "dizzy" or state == "frozen" then
		return false
	end

	local skillData = skillCsv:getSkillById(self.unitData and self.unitData.talentSkillId or 0)
	if not skillData then return false end

	-- 技能等级修正技能豆
	local angryUnitNum = self.skillLevel >= 2 and skillData.angryUnitNum * skillData["consume" .. self.skillLevel] or skillData.angryUnitNum

	-- 被动技能，技能豆消耗减少
	local lessAngry = 0
	for _, skillId in ipairs(self.passiveSkills) do
		local passiveSkill = skillPassiveCsv:getPassiveSkillById(skillId)

		if passiveSkill and passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_RELEASE_SKILL)] then
			lessAngry = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_ANGRY_LESS)])
		end
	end

	-- 被动技能
	local releaseAngry = angryUnitNum - lessAngry < 1 and 1 or angryUnitNum - lessAngry
	-- 技能豆不够
	if self.skillCd > 0 or not skillData or releaseAngry > self.battleField[self.camp .. "Camp"].angryUnitNum then
		return false, releaseAngry
	end

	return true, releaseAngry
end

function Soldier:releaseSkill()
	local releasable, releaseAngry = self:canReleaseSkill()
	if not releasable then return false end

	-- 消耗技能豆
	self.battleField[self.camp .. "Camp"]:consumeAngryValue(releaseAngry)
	
	local skillData = skillCsv:getSkillById(self.unitData and self.unitData.talentSkillId or 0)
	self.curSkill = require(self.reflections["skill"]).new({ id = skillData.skillId, owner = self, battleField = self.battleField })
	self.curSkill:onShow()

	return true
end

-- 释放被动触发主动计
function Soldier:releasePassiveSkill()
	if self.hp <= 0 then return false end

	if self:getState() == "skillAttack" then return false end

	if self.hasPaused then return false end

	local skillId = nil
	local random = nil
	for _,value in ipairs(self.passiveSkills) do
		local passiveSkill = skillPassiveCsv:getPassiveSkillById(value)

		if not passiveSkill then
			return false
		end

		if passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_SKILL)] then
			random = tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_SKILL)])
			if passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_SKILL)] then
				skillId = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_SKILL)])
				break
			end
		end
	end

	if not skillId then return false end

	if math.random(0,100) > random then return false end

	-- 被动技能直接作用
	self.curPassiveSkill = require(self.reflections["skill"]).new({ id = skillId, owner = self, battleField = self.battleField })
	return true
end

function Soldier:addBuff(params)
	if self.hp <= 0 then return end
	params.owner = self

	local buff = require(self.reflections["buff"]).new(params)
	if not buff.csvData or buff.csvData.type <= 0 then
		-- buff数据不存在
		return 0
	end

	-- 免疫
	for _,skillId in ipairs(self.passiveSkills) do
		local passiveSkill = skillPassiveCsv:getPassiveSkillById(skillId)
		
		if passiveSkill and passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_DEBUFF)] and
			buff.csvData.debuff == 1 then
			self:onEffect("mianyi")
			return 0
		end
	end

	-- 抵抗
	if buffCsv:canResist(params.buffId) and math.random(0, 100) > (buff.buffValue - self.curResist) then
		self:onEffect("dikang")
		return 0
	end
	
	buff.primaryKey = self.buffIndex
	self.buffIndex = self.buffIndex + 1

	self.buffs[buff.primaryKey] = buff
	buff:beginEffect(self)

	return buff.primaryKey
end

-- 是否有相应的被动技能
-- @param 被动技能id
-- @return boolean 是否有被动技能
function Soldier:hasPassiveSkill(skill)
	for _, value in ipairs(self.passiveSkills) do 
		if value == skill then
			return true
		end
	end

	return false
end

-- 得到闪避值
function Soldier:calMissValue()
	self.curMiss = self.miss

	-- 被动技能 不屈 id为33 提高闪避
	local passiveSkill = skillPassiveCsv:getPassiveSkillById(33)
	local triggerValue = tonum(passiveSkill.triggerMap[tostring(skillPassiveCsv.TRIGGER_HP_LESS)])
	if self:hasPassiveSkill(33) and self.hp < self.maxHp * triggerValue / 100  then
		local effectValue = tonum(passiveSkill.effectMap[tostring(skillPassiveCsv.EFFECT_MISS)])
		self.curMiss = self.curMiss + effectValue
		self.buqu = true
	end

	return self.curMiss
end

-- 初始化被动技能列表
function Soldier:initPassiveSkills()
	if self.evolutionCount >= globalCsv:getFieldValue("passiveSkillLevel1") and
		self.evolutionCount < globalCsv:getFieldValue("passiveSkillLevel2") then
		if self.unitData.passiveSkill1 > 0 then
			table.insert(self.passiveSkills, self.unitData.passiveSkill1)
		end
	elseif self.evolutionCount >= globalCsv:getFieldValue("passiveSkillLevel2") and
		self.evolutionCount < globalCsv:getFieldValue("passiveSkillLevel3") then
		if self.unitData.passiveSkill1 > 0 then
			table.insert(self.passiveSkills, self.unitData.passiveSkill1)
		end
		if self.unitData.passiveSkill2 > 0 then
			table.insert(self.passiveSkills, self.unitData.passiveSkill2)
		end
	elseif self.evolutionCount >= globalCsv:getFieldValue("passiveSkillLevel3") then
		if self.unitData.passiveSkill1 > 0 then
			table.insert(self.passiveSkills, self.unitData.passiveSkill1)
		end
		if self.unitData.passiveSkill2 > 0 then
			table.insert(self.passiveSkills, self.unitData.passiveSkill2)
		end
		if self.unitData.passiveSkill3 > 0 then
			table.insert(self.passiveSkills, self.unitData.passiveSkill3)
		end
	end
end

-- 根据前面的兵来修正自己的移动速度
function Soldier:modifyMoveSpeed()
	local beforeTeamer = self.battleField:beforeXTeamer(self)
	if not beforeTeamer then
		self.curMoveSpeed = self.moveSpeed
	else
		self.curMoveSpeed = beforeTeamer.curMoveSpeed <= self.moveSpeed and beforeTeamer.curMoveSpeed or self.moveSpeed	
	end

	return self.curMoveSpeed
end

-- 判断武将能否移动给定的距离
-- @param moveDistance	需要移动的距离
-- @return 可移动的距离
function Soldier:canMove(moveDistance)
	local soldier = self.battleField:getBeforeObject(self)

	local distance
	if soldier then
		local enemyPosX = soldier.position.x
		if self.anchPoint.y ~= soldier.anchPoint.y then
			enemyPosX = soldier.anchPoint.y == 2 and enemyPosX + self.battleField.xPosOffset or enemyPosX - self.battleField.xPosOffset
		end
		distance = math.abs(self.position.x - enemyPosX)
	end

	if not distance or distance <= self.battleField.gridWidth then return false, 0 end

	if distance - self.battleField.gridWidth <= moveDistance then
		return false, distance - self.battleField.gridWidth
	else
		return true, moveDistance
	end
end

function Soldier:beingHurt(params)
	if params.hurtValue == 0 then return end

	local origHp = self.hp

	-- 已经被杀死
	if origHp <= 0 then return true end

	if params.hurtValue > 0 then
		if self.hp <= params.hurtValue then
			self.hp = 0
			self:doEvent("BeKilled")

			-- 对方加怒气
			local campInstance = self.battleField[(self.camp == "right" and "left" or "right") .. "Camp"]
			campInstance:addAngryUnit(globalCsv:getFieldValue("killEnemyAnger"))
		else
			self.hp = origHp - params.hurtValue

			-- 僵直状态
			if params.hurtValue / self.maxHp >= globalCsv:getFieldValue("damagedFloor") / 100 and self:getState() ~= "frozen" and self:getState() ~= "dizzy" then
				self:doEvent("BeDamaged")
			end
		end
	else
		if self.hp - params.hurtValue >= self.maxHp then
			self.hp = self.maxHp
		else
			self.hp = origHp - params.hurtValue
		end
	end

	self:onHurt({ origHp = origHp, hurtValue = params.hurtValue , effect = params.effect, restraint = params.restraint})

	return self.hp <= 0	-- true表示已经被杀死
end

function Soldier:changeAttribute(params)
	local attrName = "cur" .. params.name
	self[attrName] = self[attrName] + params.value
end

function Soldier:beingMove(params)
	if self.camp == "left" then
		self.position.x = params.beginX + params.offset
	else
		self.position.x = params.beginX - params.offset
	end

	self:onMove(params)
end

function Soldier:pause(bool)
	self.hasPaused = bool
	self:onPause(bool)
end

-- onXXX() 都是子类需要实现的, 比如客户端的特效释放等

function Soldier:onMove(params)
end

function Soldier:onStandby(params)
end

function Soldier:onAttack(params)
end

function Soldier:checkAttackStatus(params)
end

function Soldier:onSkillAttack(params)
end

function Soldier:checkSkillAttackStatus(params)
end

function Soldier:onHurt(params)
end

function Soldier:onDeath(params)
end

function Soldier:onFrozen(params)
end

function Soldier:onDizzy(params)
end

function Soldier:onDamaged(params)
end

function Soldier:onPause(bool)
end

function Soldier:onEffect(effect)
end

function Soldier:onChangeAttribute(params)
end

-- 清除武将的一些特效
function Soldier:clearStatus()
	if not self:isState("standby") and not self:isState("dead") then
		self:doEvent("ToIdle")
	end

	-- 上场后, 身上携带的组合技
	self.associationSkills = {}

	-- 被作用的buff
	for key, buff in pairs(self.buffs) do
		buff:dispose(self)
	end
	self.buffs = {}

	self.skillCd = 0
	self.inSkillAttack = false
	self.hasPaused = false
end

function Soldier:dispose()
	for key, buff in pairs(self.buffs) do
		buff:dispose(self)
	end
	self.buffs = {}
end

return Soldier