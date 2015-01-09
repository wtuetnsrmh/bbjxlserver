local ExchangeCodeCsvData = {
	m_data = {},
}

function ExchangeCodeCsvData:load(fileName)
	self.m_data = {}

	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local code = csvData[index]["兑换码"]	
		self.m_data[code] = {
			code = code,
			itemId = tonum(csvData[index]["礼包ID"]),
			platformId = tonum(csvData[index]["渠道ID"]),
		}
	end
end

function ExchangeCodeCsvData:getDataByCode(code)

	return self.m_data[code]
end

return ExchangeCodeCsvData