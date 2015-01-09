local BirthHeroCsvData = {
	m_data = {}
}

function BirthHeroCsvData:load(fileName)
	self.m_data = {}

	local csvData = CsvLoader.load(fileName)

	for line = 1, #csvData do
		local id = tonum(csvData[line]["id"])
		if id > 0 then
			self.m_data[id] = {
				id = id,
				type = tonum(csvData[line]["武将ID"]),
				initLevel = tonum(csvData[line]["初始等级"]),
			}
		end
	end
end

return BirthHeroCsvData