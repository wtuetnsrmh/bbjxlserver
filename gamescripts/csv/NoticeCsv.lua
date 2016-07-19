local NoticeCsvData = {
	m_data = {},
}

function NoticeCsvData:load(fileName)
	self.m_data = {}

	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local id = tonum(csvData[index]["公告ID"])
		if id > 0 then
			self.m_data[id] = {
				id = id,
				title = csvData[index]["标题"],
				contentPath = csvData[index]["正文"],
				order = tonum(csvData[index]["显示顺序"]),
			}
		end
	end
end

function NoticeCsvData:getNotifyById(noticeId)
	return self.m_data[noticeId]
end

return NoticeCsvData