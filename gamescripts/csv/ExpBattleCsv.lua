local ExpBattleCsvData = {
    m_data = {},
}

function ExpBattleCsvData:load(fileName)
    self.m_data = {}

    local csvData = CsvLoader.load(fileName)
    
    for index = 1, #csvData do
        local battleid= tonum(csvData[index]["id"])
        if battleid > 0 then
            self.m_data[battleid] = {
                id = battleid,
                desc = tostring(csvData[index]["副本描述"]),
                hard = tostring(csvData[index]["难度"]),
                health = tostring(csvData[index]["体力消耗"]),
                level = tostring(csvData[index]["开放等级"]),
                openday = tostring(csvData[index]["开放日期"]),
                atk = tostring(csvData[index]["实力系数"]),
                btres = tostring(csvData[index]["战斗配表"]),
                bgres = tostring(csvData[index]["战斗场景"]),
                talkid = tostring(csvData[index]["战斗对话"]),
                items = self:itemByString(tostring(csvData[index]["单位道具奖励"])),
                pass = self:itemByString(tostring(csvData[index]["通关奖励"])),
                money = tostring(csvData[index]["游戏币奖励"]),
                maxround = tonum(csvData[index]["战斗阶段"]),
                scenes = self:getscenes(tonumber(csvData[index]["战斗阶段"]),csvData[index]),
                heroExp = tonum(csvData[index]["武将经验"]),
            }
        end
    end
end

function ExpBattleCsvData:getDataById(id)
    if id then
        return self.m_data[tonumber(id)]
    end
end

function ExpBattleCsvData:getscenes(maxRound,dataTable)
    local t = {}
    local key = nil 
    for i=1,tonum(maxRound) do
        k = string.format("战斗场景%d",i)
        t[#t + 1] = tostring(dataTable[k])
    end
    return t
end

--奖励的道具列表like {{id = 1,num = 10,prob = 40}...}
function ExpBattleCsvData:itemByString(str)
    local objTable = {}
    local temp = string.split(str," ")
    for k,v in pairs(temp) do
        local t = string.split(v, "=")
        objTable[k] = {}
        objTable[k].id = tonumber(t[1])
        objTable[k].num = tonumber(t[2])
        objTable[k].prob = tonumber(t[3])
    end
    return objTable
end

--对应id，掉落次数，掉落类型(pass,items)
function ExpBattleCsvData:dropItemByIDAndTimes(id,times,dtype)
    local record = self.m_data[tonumber(id)]
    local resultTable = {}
    local curProb
    for i=1,times do
        local max = 0 
        for _,w in pairs(record[dtype]) do
           max = max + tonumber(w.prob)
        end
        local randomNum = math.random(1,max)
        -- printf("第%d随机数 ======= %d",i,randomNum)
        curProb = 0
        for _,v in pairs(record[dtype]) do
            curProb = curProb + v.prob
            -- print("curProb ======= ",curProb)
            if randomNum < curProb then
                resultTable[#resultTable + 1] = v
                break
            end
        end
    end
    return resultTable
end

return ExpBattleCsvData