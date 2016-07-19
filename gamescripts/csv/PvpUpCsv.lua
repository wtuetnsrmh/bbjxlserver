local _M = {
	m_data = {},
}

function _M:load(fileName)
	self.m_data = {}

	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local id = tonum(csvData[index]["id"])
		if id > 0 then
			self.m_data[id] = self.m_data[id] or {}
			self.m_data[id].id = id
			self.m_data[id].max = tonum(csvData[index]["名次区间上限"])
			self.m_data[id].min = tonum(csvData[index]["名次区间下限"])
			self.m_data[id].step = tonum(csvData[index]["每级获得"])
			self.m_data[id].extra = tonum(csvData[index]["每次额外收益"])
		end
	end
end

function _M:getDataById(id)
	return self.m_data[id]
end

function _M:findGradeByRank(rank)
	for _, v in pairs(self.m_data) do
		if rank >= v.max and rank <= v.min then
			return v
		end
	end
	return nil
end

return _M