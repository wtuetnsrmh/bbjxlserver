local RoleProfessionCsvData = {
	m_data = {},
}

function RoleProfessionCsvData:load(file)
    self.m_data = {}

    local csvData = CsvLoader.load(fileName)

    for index = 1, #csvData do
    	local professionId = tonum(csvData[index]["职业ID"])
    	if professionId > 0 then
    		local professionData = {}
    		professionData.jobID = csvData[index]["职业ID"]
    		professionData.jobName = csvData[index]["职业名称"]
    		professionData.moveSpeed = csvData[index]["移动速度"]
    		professionData.attackSpeed = csvData[index]["攻击速度"]
    		professionData.atcRange = csvData[index]["攻击距离"]	

    		self.m_data[professionData.jobID] = professionData
    	end
	end
end

return RoleProfessionCsvData