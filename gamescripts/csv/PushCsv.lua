local PushCsvData = {
	m_data = {},
}

function PushCsvData:load(fileName)
	self.m_data = {}

	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local msgId = tonum(csvData[index]["消息ID"])
		if msgId > 0 then
			self.m_data[msgId] = self.m_data[msgId] or {}

			self.m_data[msgId].id = msgId
			self.m_data[msgId].type = tonum(csvData[index]["类型"])
			self.m_data[msgId].msg = csvData[index]["消息内容"]
		end
	end
end

function PushCsvData:getMsgById(id)
	return self.m_data[id] and self.m_data[id].msg or ""
end

return PushCsvData