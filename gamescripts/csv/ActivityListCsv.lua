local ActivityListCsvData = {
	m_data = {},
}



function ActivityListCsvData:load(fileName)
	self.m_data = {}
	self.m_data_str = {}

	local csvData = CsvLoader.load(fileName)

	for index = 1, #csvData do
		local serverId = tonum(csvData[index]["服务器ID"])
		if serverId > 0 then
			self.m_data[serverId] = {
				serverId = serverId,
				activityTimeList = {
					[1] = self:myRead(tostring(csvData[index]["活动1时间"])),
					[2] = self:myRead(tostring(csvData[index]["活动2时间"])),
				}
			}
			self.m_data_str[serverId] = {
				activityTimeList ={
					[1] = self:myRead(tostring(csvData[index]["活动1时间"]), true),
					[2] = self:myRead(tostring(csvData[index]["活动2时间"]), true),
				}
			}
		end
	end
end

function ActivityListCsvData:myRead(str, keepStr)
	local t = {}
	local temp = string.toArray(str, ";")
	for index, strData in ipairs(temp) do
		local data = string.split(strData, ":")
		table.insert(t, {time = keepStr and data[1] or self:getTimeTable(data[1]), id = tonum(data[2])})
	end
	return t
end

function ActivityListCsvData:inLimitTime(sId,activityId,time)
	local t = self:getDataByServerId(sId,activityId)
	for index, data in ipairs(t) do
		local timeData = data.time
		if #timeData > 0 then
			local startTime=os.time{year=timeData[1].year, month=timeData[1].month, day=timeData[1].day, hour=0, min=0, sec=0}
			local endTime=os.time{year=timeData[2].year, month=timeData[2].month, day=timeData[2].day , hour=0, min=0, sec=0}
			if tonum(time)>startTime and tonum(time)<endTime then
				return index
			end
		end
	end

	return nil
end

function ActivityListCsvData:getDataStrListByServerId(serverId, index)
	if not index then
		index = self:inLimitTime(serverId, time)
	end
	index = index and index or 1
	local timeList=self.m_data_str[serverId].activityTimeList
	local returnList={}
	for activityId, data in ipairs(timeList) do
		local temp = data[index]
		table.insert(returnList, {startAndEndTime = tostring(temp.time), data = self:getExtraDataById(serverId, activityId, temp.id, index)})
	end
	return returnList
end

--获得额外信息，目前只有限时神将需要
function ActivityListCsvData:getExtraDataById(serverId, activityId, id, index)
	local t
	if activityId == 2 then
		local csvData = godHeroCsv:getDataById(id)
		if csvData then
			t = {csvData.heroType}
			local timeData = self.m_data[serverId].activityTimeList[activityId][index].time
			local startTime = os.time({year=timeData[1].year, month=timeData[1].month, day=timeData[1].day, hour=0, min=0, sec=0})
			local heros = godHeroCsv:getTodayHeros(startTime, id)
			for _, heroType in ipairs(heros) do
				table.insert(t, tonum(heroType))
			end	
		end
	end
	return t
end

function ActivityListCsvData:getDataByServerId(serverId,activityId)
	local curData=self.m_data[tonum(serverId)]
	local curTimeData=curData.activityTimeList[tonum(activityId)]
	return curTimeData or {}

end

function ActivityListCsvData:getTimeTable(timeStr)
	local t = {}
	if timeStr ~= nil then
		local temp = string.split(timeStr, " ")
		for i=1,table.nums(temp) do
			local st = string.split(tostring(temp[i]), "=") 
			t[i] = {}
			t[i]["year"]    = st[1]
			t[i]["month"] = st[2]
			t[i]["day"] = st[3]
		end
	end
	return t
end

function ActivityListCsvData:getAllData()
	return self.m_data
end


return ActivityListCsvData