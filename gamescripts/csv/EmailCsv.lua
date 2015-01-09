local EmailCsvData = {
	m_data = {},
}

function EmailCsvData:load(fileName)
	self.m_data = {}

	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local id = tonum(csvData[index]["邮件ID"])
		if id > 0 then
			self.m_data[id] = {
				id = id,
				title = csvData[index]["标题"],
				contentPath = csvData[index]["正文"],
				attachments = csvData[index]["道具"],
			}
		end
	end
end

function EmailCsvData:getEmailById(emailId)
	return self.m_data[emailId]
end

return EmailCsvData