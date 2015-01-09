local GuideCsvData = {
	m_data = {},
	m_carbon_step = {}
}

function GuideCsvData:load(fileName)
	self.m_data = {}
	self.m_carbon_step = {}

	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local guideId = tonum(csvData[index]["引导ID"])
		if guideId > 0 then
			self.m_data[guideId] = {
				guideId = guideId,
				type = tonum(csvData[index]["类型"]),
				updateStep = tonum(csvData[index]["步骤跳转"]),
			}

			local type = self.m_data[guideId].type
			if type > 0 then
				self.m_carbon_step[type] = self.m_data[guideId]
			end
		end
	end
end

function GuideCsvData:getGuideById(id)
	return self.m_data[id]
end

function GuideCsvData:getCarbonUpdateGuide(carbonId)
	return self.m_carbon_step[carbonId]
end

return GuideCsvData