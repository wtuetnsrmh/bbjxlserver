local DailyGiftCsvData = {
	m_data = {}
}

function DailyGiftCsvData:load(fileName)
	self.m_data = {}

	local csvData = CsvLoader.load(fileName)

	for line = 1, #csvData do
		local id = tonum(csvData[line]["id"])
		if id > 0 then
			self.m_data[id] = {
				time = csvData[line]["时间"],
				condition = tonum(csvData[line]["条件参数"]),
				donateHealth = tonum(csvData[line]["体力赠送"]),
			}
		end
	end
end

return DailyGiftCsvData