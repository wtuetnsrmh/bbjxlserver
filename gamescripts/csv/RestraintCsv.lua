local RestraintCsvData = {
	m_data = {},
}

function RestraintCsvData:load(fileName)

	local csvData = CsvLoader.load(fileName)

	self.m_data = {}

	for index = 1, #csvData do
		local attack = tonum(csvData[index]["克制方"])
		local defense = tonum(csvData[index]["被克制方"])

		if attack > 0 and defense > 0 then
			self.m_data[attack] = self.m_data[attack] or {}
			self.m_data[attack][defense] = tonum(csvData[index]["普攻加成"])
		end
	end
end

function RestraintCsvData:getValue(attack, defense)
	if not self.m_data[attack] then return 1 end

	if not self.m_data[attack][defense] then return 1 end

	return self.m_data[attack][defense]
end

return RestraintCsvData