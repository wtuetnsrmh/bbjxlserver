local CsvData = {
	m_data = {}
}

function CsvData:load(fileName)
	self.m_data = {}
	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local id = tostring(csvData[index]["通关差次"])
		if id ~= "" then
			self.m_data[id] = tonumber(csvData[index]["战斗力修正"])
		end
	end
end

function CsvData:getData()
	return self.m_data
end

return CsvData