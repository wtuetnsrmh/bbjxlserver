local SystemAction = {}

function SystemAction.disconnectRole(event)
	local role = self.app.sessionRoleMap[event.sessionId]
	if not role then return end

	role:saveAll()
	-- self.app.roles[role:getProperty("id")] = nil
	-- self.app.sessionRoleMap[event.sessionId] = nil
end

function SystemAction.updateTime(event)
	local dataStr = gTimestamp.year .. string.format("%02d", gTimestamp.month) .. string.format("%02d", gTimestamp.day)
	GameData = GameData or {}
	GameData[dataStr] = GameData[dataStr] or {}
	
	local todayData = GameData[dataStr]

	local recoverHealthData = dailyGiftCsv.m_data
	-- 恢复体力点1
	if gTimestamp.hour .. gTimestamp.min == recoverHealthData[1].time 
		and not todayData[recoverHealthData[1].time] then
		self:recoverAllHealth()
		todayData[recoverHealthData[1].time] = true
	end

	-- 恢复体力点2
	if gTimestamp.hour .. gTimestamp.min == recoverHealthData[2].time 
		and not todayData[recoverHealthData[2].time] then
		self:recoverAllHealth()
		todayData[recoverHealthData[2].time] = true
	end

	-- 在线角色
	for roleId, role in pairs(self.app.roles) do
		if role:getProperty("session") > 0 then
			role:update(event.diff)
		end
	end

	local pvpCheckPoint = "0011"
	-- 晚上9点pvp发送邮件礼包
	local timeStr = string.format("%02d", gTimestamp.hour) .. string.format("%02d", gTimestamp.min)
	if timeStr == pvpCheckPoint and not GameData[dataStr][pvpCheckPoint] then
		for index = 1, redisproxy:llen("pvp_rank") do
			local roleId = tonumber(redisproxy:lindex("pvp_rank", index - 1))
			local giftData = pvpGiftCsv:getGiftData(index)
			redisproxy:runScripts("insertEmail", 3, roleId, giftData.emailId, skynet.time())
		end
		GameData[dataStr][pvpCheckPoint] = true
	end
end

function SystemAction.recoverAllHealth(recoverHealthData)
	local maxRoleId = tonumber(redisproxy:hget("autoincrement_set", "role"))

	for id = 1, maxRoleId do
		local buffRole = self.app.roles[roleId]
		if buffRole then
			local afterHealth = buffRole:getProperty("health") + recoverHealthData.donateHealth
			local nowHealth = afterHealth > 70 and 70 or afterHealth
			buffRole:setProperty("health", nowHealth);

			if buffRole:getProperty("session") > 0 then
				-- 在线
				buffRole:notifyUpdateProperty("health", nowHealth)
			end
		else
			if redisproxy:exists(string.format("role:%d")) then
				local roleInfo = redisproxy:hmget(string.format("role:%d", id), "health", "delete")
				if tonumber(roleInfo[1]) == 0 then
					local afterHealth = tonumber(roleInfo[2]) + recoverHealthData.donateHealth
					local nowHealth = afterHealth > 70 and 70 or afterHealth
					redisproxy:hset(string.format("role:%d", id), "health", nowHealth)
				end
			end
		end
	end
end

return SystemAction