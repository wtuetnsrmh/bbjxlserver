local ProfessionPhaseCsvData = {
	m_data = {}
}

function ProfessionPhaseCsvData:load(fileName)
	self.m_data = {}

	local csvData = CsvLoader.load(fileName)

	for line = 1, #csvData do
		local profession = tonum(csvData[line]["职业ID"])
		local phase = tonum(csvData[line]["阶级"])
		if profession > 0 and phase > 0 then
			self.m_data[profession] = self.m_data[profession] or {}
			self.m_data[profession][phase] = {
				name = csvData[line]["职业"],
				atkBonus = tonum(csvData[line]["攻击加成"]),
				defBonus = tonum(csvData[line]["防御加成"]),
				hpBonus = tonum(csvData[line]["攻击加成"]),
				restraintBonus = tonum(csvData[line]["克制伤害加成"]),
				lingpaiNum = tonum(csvData[line]["进阶需要令牌"]),
				atkBonusDesc = csvData[line]["攻击加成描述"],
				defBonusDesc = csvData[line]["防御加成描述"],
				hpBonusDesc = csvData[line]["生命加成描述"],
				restraintBonusDesc = csvData[line]["克制伤害加成描述"],
				restraintProfression = tonum(csvData[line]["克制职业ID"]),
				helpInfo = csvData[line]["帮助信息"],
				phaseName = csvData[line]["阶级名称"],
			}
		end
	end
end

function ProfessionPhaseCsvData:getDataByPhase(profession, phase)
	return self.m_data[profession][phase]
end

return ProfessionPhaseCsvData