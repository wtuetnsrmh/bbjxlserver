local ProfessionLevelCsvData = {
	m_data = {}
}

function ProfessionLevelCsvData:load(fileName)
	self.m_data = {}

	local csvData = CsvLoader.load(fileName)

	for line = 1, #csvData do
		local profession = tonum(csvData[line]["职业ID"])
		local phase = tonum(csvData[line]["阶级"])
		local level = tonum(csvData[line]["等级"])
		if profession > 0 and phase > 0 and level > 0 then
			self.m_data[profession] = self.m_data[profession] or {}
			self.m_data[profession][phase] = self.m_data[profession][phase] or {}
			self.m_data[profession][phase][level] = {
				atkBonus = tonum(csvData[line]["攻击加成"]),
				defBonus = tonum(csvData[line]["防御加成"]),
				hpBonus = tonum(csvData[line]["生命加成"]),
				restraintBonus = tonum(csvData[line]["克制伤害加成"]),
				lingpaiNum = tonum(csvData[line]["升级消耗"]),
			}
		end
	end
end

function ProfessionLevelCsvData:getDataByLevel(profession, phase, level)
	return self.m_data[profession][phase][level]
end

return ProfessionLevelCsvData