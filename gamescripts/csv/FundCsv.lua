local FundCsvData = {
	m_data = {},
}

function FundCsvData:load(fileName)
	self.m_data = {}
	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local level = tonum(csvData[index]["需求等级"])

		if level ~= 0 then
			local data = {}
			data.yuanbao = tonum(csvData[index]["领取元宝"])
			self.m_data[level] = data
		end
	end
end

function FundCsvData:getDataByLevel(level)
	return self.m_data[level]
end

return FundCsvData