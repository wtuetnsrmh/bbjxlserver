local PvpRobotsCsvData = {
    m_data = {},
}

function PvpRobotsCsvData:load(fileName)
    m_data = {} 
   
    local csvData = CsvLoader.load(fileName)
    for line = 1, #csvData do 
        local rank = tonum(csvData[line]["排名"])
        if rank > 0 then
            self.m_data[rank] = self.m_data[rank] or {} 
            self.m_data[rank].name = csvData[line]["玩家名"]
            self.m_data[rank].level = csvData[line]["玩家等级"]
            for pos = 1, 6 do 
                self.m_data[rank][pos] = self.m_data[rank][pos] or {} 
                local profession = tonum(csvData[line]["职业" .. pos])
                if profession > 0 then
                    self.m_data[rank][pos] = {
                        profession = profession,
                        level = tonum(csvData[line]["等级" .. pos]),
                        stars = tonum(csvData[line]["星级" .. pos]),
                        evolutionCount = tonum(csvData[line]["进化" .. pos]),
                    }  
                end
            end
        end
    end
end

function PvpRobotsCsvData:getHerosByRank(rank)
    return self.m_data[rank]
end

return PvpRobotsCsvData