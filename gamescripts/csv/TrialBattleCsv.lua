local TrialBattleCsvData = {
    m_data = {},
}

function TrialBattleCsvData:load(fileName)
    self.m_data = {}

    local csvData = CsvLoader.load(fileName)
    
    for index = 1, #csvData do
        local battleid= tonum(csvData[index]["id"])
        if battleid > 0 then
            self.m_data[battleid] = {
                id = battleid,
                desc = tostring(csvData[index]["副本描述"]),
                hard = tostring(csvData[index]["难度"]),
                health = tonum(csvData[index]["体力消耗"]),
                level = tonum(csvData[index]["开放等级"]),
                openday = string.toArray(csvData[index]["开放日期"], " ", true),
               
                btres = tostring(csvData[index]["战斗配表"]),
                bgRes1 = tostring(csvData[index]["战斗场景1"]),
                bgRes2 = tostring(csvData[index]["战斗场景2"]),
                bgRes3 = tostring(csvData[index]["战斗场景3"]),
                dropDatas = string.toTableArray(csvData[index]["单位道具奖励"]),
                heroExp = tonum(csvData[index]["武将经验"]),
            }

            table.sort(self.m_data[battleid].dropDatas, function(a, b)
                    return tonum(a[4]) > tonum(b[4])
                end)
        end
    end
end

function TrialBattleCsvData:isOpen(id)
    local data = self:getDataById(id)
    if data then
        local day = os.date("*t", skynet.time()).wday
        day = day == 1 and 7 or day - 1
        for i=1, #data.openday do
            if data.openday[i] == day then 
                return true
            end
        end
        return false
    end
    --没有数据处理成长期开放
    return true
end
        

function TrialBattleCsvData:getDataById(id)
    return self.m_data[tonumber(id)]
end

return TrialBattleCsvData