local PvpMatchCsvData = {
	m_data = {},
}

function PvpMatchCsvData:load(fileName)

	local csvData = CsvLoader.load(fileName)

	self.m_data = {}

	for index = 1, #csvData do
		local id = tonum(csvData[index]["id"])
		local floorRank = tonum(csvData[index]["名次上限"])

		if id > 0 then
			self.m_data[floorRank] = {
				id = id,
				floorRank = floorRank,
				ceilRank = tonum(csvData[index]["名次下限"]),
				rankInterval = tonum(csvData[index]["名次间隔"]),
			}
		end
	end
end

function PvpMatchCsvData:getMatchData(rank)
	return lowerBoundSeach(self.m_data, rank)
end

function PvpMatchCsvData:getMatchRanks(rank, count)
	count = count or 5

	local result = {}	-- 结果集

	-- 如果玩家排名在1-5名，则除去玩家自己，提起前5名作为被挑战者
	if rank <= 5 then
		for index = 1, 6 do
			if rank ~= index then
				table.insert(result, index)
			end
		end

		return result
	end

	local rankData = self:getMatchData(rank)
	if not rankData then return result end

	-- 考虑跨界
	local nextRank = rank - rankData.rankInterval
	while count > 0 do
		local nextRankData = self:getMatchData(nextRank)
		table.insert(result, nextRank)
		nextRank = nextRank - nextRankData.rankInterval

		count = count - 1
	end

	return result
end

return PvpMatchCsvData