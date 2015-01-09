local ReChargeCsvData = {
	m_data = {},
}

function ReChargeCsvData:load(fileName)
	local csvData = CsvLoader.load(fileName)

	self.m_data = {}

	for index = 1, #csvData do
		local id = tonum(csvData[index]["充值id"])
		if id > 0 then
			self.m_data[id] = {
				id = id,
				rmbValue = tonum(csvData[index]["RMB"]),
				paidYuanbao = tonum(csvData[index]["元宝"]),
				freeYuanbao = tonum(csvData[index]["赠送元宝"]),
				yuekaFlag = tonum(csvData[index]["月卡"]),
				firstYuanbao = tonum(csvData[index]["首充赠送元宝"]),
			}
		end
	end
end

function ReChargeCsvData:getRechargeDataByRmb(rmb)
	for _, data in pairs(self.m_data) do
		if tonumber(rmb) == data.rmbValue then
			return data
		end
	end

	return nil
end

function ReChargeCsvData:getRechargeDataById(id)
	return self.m_data[id]
end

return ReChargeCsvData