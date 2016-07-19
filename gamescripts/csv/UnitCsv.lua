require("utils.StringUtil")

ProfessionName = { [1] = "bu", [3] = "qi", [4] = "gong", [5] = "jun" }
CampName = { [1] = "qun", [2] = "wei", [3] = "shu", [4] = "wu" }
EvolutionThreshold = {1, 3, 6, 11, math.huge}

local UnitCsvData = {
	m_data = {},
}

local function readRelation(str)
	local array = {}
	local tempArray = string.split(string.trim(str), " ")
	for _, value in ipairs(tempArray) do
		local trimValue = string.trim(value)
		if trimValue ~= "" then
			value = string.split(trimValue, "=")
			for index, value2 in ipairs(value) do
				if index == 6 then
					value[index] = value2
				elseif index == 1 then
					value[index] = tonum(value2)
				else
					value[index] = string.toArray(string.trim(value2), ";", true)
				end
			end
			table.insert(array, value)
		end
	end
	return array
end

function UnitCsvData:load(fileName)
	self.m_data = {}
	
	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local type = tonum(csvData[index]["武将ID"])
		if type > 0 then
			self.m_data[type] = {
				type = tonum(csvData[index]["武将ID"]),
				name = csvData[index]["武将名称"],
				camp = tonum(csvData[index]["阵营"]),
				profession = tonum(csvData[index]["职业ID"]),
				professionName = csvData[index]["职业名称"],
				stars = tonum(csvData[index]["星级"]),
				skillLevelGrowth = tonum(csvData[index]["技能等级提升"]),
				hp = tonum(csvData[index]["初始生命"]),
				attack = tonum(csvData[index]["初始攻击"]),
				defense = tonum(csvData[index]["初始防御"]),
				hpGrowth = tonum(csvData[index]["生命成长"]),
				attackGrowth = tonum(csvData[index]["攻击成长"]),
				defenseGrowth = tonum(csvData[index]["防御成长"]),
				-- begin 二级属性
				miss = tonum(csvData[index]["初始闪避"]),
				hit = tonum(csvData[index]["初始命中"]),
				parry = tonum(csvData[index]["初始格挡"]),
				ignoreParry = tonum(csvData[index]["初始破击"]),
				crit = tonum(csvData[index]["初始暴击"]),
				tenacity = tonum(csvData[index]["初始韧性"]),
				critHurt = tonum(csvData[index]["初始爆伤"]),
				resist = tonum(csvData[index]["初始抵抗"]),
				-- end
				moveSpeed = tonum(csvData[index]["移动速度"]),
				atkSpeedFactor = tonum(csvData[index]["攻击速度"]),
				atcRange = tonum(csvData[index]["攻击距离"]),
				talentSkillId = tonum(csvData[index]["必杀技ID"]),
				desc = csvData[index]["武将简介"],
				headImage = csvData[index]["头像资源"],
				heroRes = csvData[index]["人物资源"],
				cardRes = csvData[index]["卡牌资源"],
				boneResource = csvData[index]["骨骼动画"],
				boneActXml = csvData[index]["骨骼动作文件"],
				boneRatio = tonum(csvData[index]["骨骼比例"]) == 0 and 100 or tonum(csvData[index]["骨骼比例"]),
				skillAnimateName = csvData[index]["通用模型技能动作"],
				sex = tonum(csvData[index]["性别"]),
				passiveSkill1 = tonum(csvData[index]["被动技能1"]),
				passiveSkill2 = tonum(csvData[index]["被动技能2"]),
				passiveSkill3 = tonum(csvData[index]["被动技能3"]),
				firstTurn = string.split(string.trim(csvData[index]["首轮顺序"]), "="),
				cycleTurn = string.split(string.trim(csvData[index]["循环顺序"]), "="),
				atkBullteId = tonum(csvData[index]["普攻子弹ID"]),
				skillMusicId = tonum(csvData[index]["技能配音ID"]),
				actionTable = csvData[index]["动作配表"],
				scale = tonum(csvData[index]["比例"]),
				weight = tonum(csvData[index]["权值"]),
				dropPlace = tonum(csvData[index]["掉落区域"]),
				fragmentId = tonum(csvData[index]["碎片ID"]),
				exchangeSoulNum = tonum(csvData[index]["兑换所需将魂"]),
				heroOpen = tonum(csvData[index]["图鉴开关"]),
				relation = readRelation(csvData[index]["情缘"]),
			}
			for i=1, math.huge do
				local str = csvData[index][string.format("进化%d材料", i)]
				if str == "" then break end
				self.m_data[type]["evolMaterial" .. tostring(i)] = string.toArray(str, " ", true)
			end
		end
	end
end

function UnitCsvData:getUnitByType( type )
	return self.m_data[type]
end

-- 用修正权重取出所有的武将权重信息
function UnitCsvData:getUnitWeightArray(params)
	local result = {}

	local defaultProfessionWeights = { ["1"] = 1, ["3"] = 1, ["4"] = 1, ["5"] = 1 }
	local defaultCampWeights = { ["1"] = 1, ["2"] = 1, ["3"] = 1, ["4"] = 1 }
	local defaultStarWeights = { ["1"] = 1, ["2"] = 1, ["3"] = 1, ["4"] = 1, ["5"] = 1}
	local dropPlace = params.dropPlace or 0

	local function reCalWeight(inputWeights, default)
		if not inputWeights or table.nums(inputWeights) == 0 then return default end

		local weights = {}
		for key, value in pairs(inputWeights) do
			if tonum(value) > 0 then
				table.insert(weights, { key = key, weight = tonum(value) })
			end
		end

		local randomIndex = randWeight(weights)
		return { [weights[randomIndex].key] = weights[randomIndex].weight }
	end

	local professionWeights = reCalWeight(params.professionWeights, defaultProfessionWeights)
	local campWeights = reCalWeight(params.campWeights, defaultCampWeights)
	local starWeights = reCalWeight(params.starWeights, defaultStarWeights)
	for type, value in pairs(self.m_data) do
		if dropPlace == 0 or value.dropPlace == 0 or value.dropPlace == dropPlace then
			local weight = value.weight * tonum(starWeights[tostring(value.stars)])
					* tonum(professionWeights[tostring(value.profession)])
					* tonum(campWeights[tostring(value.camp)])
			if weight > 0 then
				result[#result + 1] = {itemId = type, weight = weight}
			end
		end
	end

	return result
end

function UnitCsvData:getEvolRichDesc(evolutionCount)
	local function getIndex(evolutionCount)
		evolutionCount = evolutionCount or 0
		local frameNum = 1
		for index = 1, #EvolutionThreshold do
			if evolutionCount < EvolutionThreshold[index] then
				frameNum = index
				break
			end
		end
		return frameNum
	end

	local colorDesc = {"白", "绿", "蓝", "紫", "金"}
	local colorSchema = {
		[1] = "ffffffff",	--白色
		[2] = "ff00ff00",  	-- display.COLOR_GREEN
		[3] = "ff0096ff",  	-- display.COLOR_BLUE
		[4] = "ffff00ff", 	-- 紫色
		[5] = "ffffff00",	--金色
	}
	local index = getIndex(evolutionCount)
	local desc = colorDesc[index]
	evolutionCount = evolutionCount or 0 
	for index = 1, #EvolutionThreshold do
		if evolutionCount < EvolutionThreshold[index] then
			evolutionCount = evolutionCount - tonum(EvolutionThreshold[index - 1])
			break
		end
	end

	if evolutionCount ~= 0 then
		desc = desc .. "+" .. evolutionCount
	end
	desc = string.format("[color=%s]%s[/color]", colorSchema[index], desc)
	return desc
end

return UnitCsvData