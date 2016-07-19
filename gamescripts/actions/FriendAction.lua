local FriendAction = {}

function FriendAction.canBeFriend(roleId, objectId)
	local isFriend = redisproxy:sismember(string.format("role:%d:friends", roleId), tostring(objectId))
	if isFriend then return false end

	-- 是否已经申请过了
	local applicantIds = redisproxy:hkeys(string.format("role:%d:friendApplications", objectId))
	for _, applicantId in ipairs(applicantIds) do
		if roleId == tonumber(applicantId) then
			return false
		end
	end

	return true
end

function FriendAction.randomSearchRole(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	local leftCount, filterRoleIds, searchRoleList = 20, {}, {}
	searchRoleList.searchRoles = {}
	local maxRoleId = tonumber(redisproxy:hget("autoincrement_set", "role"))
	while leftCount > 0 do
		-- 1~10000保留字段
		local curRoleId = math.random(10001, maxRoleId)
		leftCount = leftCount - 1

		if curRoleId ~= msg.roleId and not filterRoleIds[curRoleId] then
			-- 过滤已经是自己的朋友
			if FriendAction.canBeFriend(msg.roleId, curRoleId) then
				local curRoleInfo = redisproxy:hmget(string.format("role:%d", curRoleId), 
					"name", "level", "pvpRank", "lastLoginTime", "delete", "money", "mainHeroId", "vipLevel")
				-- 角色没有删除
				if tonumber(curRoleInfo[5]) == 0 and tonumber(curRoleInfo[2]) <= role:getProperty("level") then
					local mainHeroInfo = redisproxy:hmget(string.format("hero:%d:%s", curRoleId, tonumber(curRoleInfo[7])),
						"type", "delete", "wakeLevel", "star", "evolutionCount")
					-- 存在主将
					if tonumber(mainHeroInfo[2]) == 0 then
						table.insert(searchRoleList.searchRoles, {
							roleId = curRoleId,
							name = curRoleInfo[1], 
							level = tonumber(curRoleInfo[2]), 
							pvpRank = tonumber(curRoleInfo[3]), 
							lastLoginTime = tonumber(curRoleInfo[4]),
							money = tonumber(curRoleInfo[6]),
							mainHeroType = tonumber(mainHeroInfo[1]),
							vipLevel = tonumber(curRoleInfo[8]),
							wakeLevel = tonumber(mainHeroInfo[3]),
							star = tonumber(mainHeroInfo[4]),
							evolutionCount = tonumber(mainHeroInfo[5]),
							friendCnt = redisproxy:scard(string.format("role:%d:friends", curRoleId)),
							isFriend = 0,
						})
					end
				end
			end
			filterRoleIds[curRoleId] = true
		end

		-- 查找完毕
		if #searchRoleList.searchRoles == FRIEND_RANDOM_SEARCH_LIMIT then
			break
		end
	end

	local bin = pb.encode("SearchRoleList", searchRoleList)
	SendPacket(actionCodes.FriendMatchedRoleResponse, bin)
end

function FriendAction.searchRoleByName(agent, data)
	local msg = pb.decode("SearchRoleByName", data)

	local role = agent.role
	if not role then return end

	local searchRoleList = {}
	searchRoleList.searchRoles = {}
	local searchPattern = string.format("user:*%s*", msg.namePattern)
	for _, roleName in ipairs(redisproxy:keys(searchPattern)) do
		local curRoleId = tonumber(redisproxy:get(roleName))

		if curRoleId ~= msg.roleId then
			if FriendAction.canBeFriend(msg.roleId, curRoleId) then
				local curRoleInfo = redisproxy:hmget(string.format("role:%s", curRoleId), 
					"name", "level", "pvpRank", "lastLoginTime", "delete", "money", "mainHeroId", "vipLevel")
				-- 角色没有删除
				if tonumber(curRoleInfo[5]) == 0 then
					local mainHeroInfo = redisproxy:hmget(string.format("hero:%d:%s", curRoleId, tonumber(curRoleInfo[7])),
							"type", "delete", "wakeLevel", "star", "evolutionCount")
					-- 存在主将
					if tonumber(mainHeroInfo[2]) == 0 then
						table.insert(searchRoleList.searchRoles, {
							roleId = tonumber(curRoleId),
							name = curRoleInfo[1],
							level = tonumber(curRoleInfo[2]),
							pvpRank = tonumber(curRoleInfo[3]),
							lastLoginTime = tonumber(curRoleInfo[4]),
							money = tonumber(curRoleInfo[6]),
							mainHeroType = tonumber(mainHeroInfo[1]),
							vipLevel = tonumber(curRoleInfo[8]),
							wakeLevel = tonumber(mainHeroInfo[3]),
							star = tonumber(mainHeroInfo[4]),
							evolutionCount = tonumber(mainHeroInfo[5]),
							friendCnt = redisproxy:scard(string.format("role:%s:friends", curRoleId)),
							isFriend = 0, 
						})
					end
				end
			end
		end
	end

	local bin = pb.encode("SearchRoleList", searchRoleList)
	SendPacket(actionCodes.FriendMatchedRoleResponse, bin)
end

function FriendAction.listFriendRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local friendList = {}
	friendList.friends = {}
	local friendIds = redisproxy:smembers(string.format("role:%d:friends", msg.roleId))
	for _, friendIdStr in ipairs(friendIds) do
		local friendId = tonumber(friendIdStr)
		local friendInfo = redisproxy:hmget(string.format("role:%s", friendId), 
			"name", "level", "pvpRank", "delete", "lastLoginTime", "money", "mainHeroId", "vipLevel")
		local hasReceived = redisproxy:hget(string.format("role:%d:receivedHealth:%s", msg.roleId, os.date("%Y%m%d")), tostring(friendId))
		if tonumber(friendInfo[4]) == 0 then
			local mainHeroInfo = redisproxy:hmget(string.format("hero:%d:%s", friendId, tonumber(friendInfo[7])),
				"type", "delete", "wakeLevel", "star", "evolutionCount")
			-- 存在主将
			if tonumber(mainHeroInfo[2]) == 0 then
				table.insert(friendList.friends, {
					roleId = friendId,
					name = friendInfo[1],
					level = tonumber(friendInfo[2]),
					pvpRank = tonumber(friendInfo[3]),
					lastLoginTime = tonumber(friendInfo[4]),
					money = tonumber(friendInfo[6]),
					vipLevel = tonumber(friendInfo[8]),
					mainHeroType = tonumber(mainHeroInfo[1]),
					wakeLevel = tonumber(mainHeroInfo[3]),
					star = tonumber(mainHeroInfo[4]),
					evolutionCount = tonumber(mainHeroInfo[5]),
					friendCnt = redisproxy:scard(string.format("role:%d:friends", friendId)),
					canDonate = redisproxy:sismember(string.format("role:%d:donateHealth:%s", msg.roleId, os.date("%Y%m%d")), tostring(friendId)) and 0 or 1,
					canReceive = hasReceived == nil and 3  or (hasReceived == "0" and 1 or 0),
				})
			end
		end
	end

	local bin = pb.encode("FriendList", friendList)
	SendPacket(actionCodes.FriendListFriendResponse, bin)
end

function FriendAction.createApplication(agent, data)
	local msg = pb.decode("ApplicationInfo", data)

	local role = agent.role
	if not role then return end

	-- 加入到被申请者的队列里面去
	local newApplicationId = redisproxy:hincrby("autoincrement_set", "friendApplication", 1)
	local newApplication = {
		applicationId = newApplicationId,
		roleId = msg.roleId,
		objectId = msg.objectId,
		timestamp = msg.timestamp,
		content = msg.content,
	}

	redisproxy:hset(string.format("role:%d:friendApplications", msg.objectId), msg.roleId,
		pb.encode("ApplicationInfo", newApplication))
end

function FriendAction.handleApplication(agent, data)
	local msg = pb.decode("HandleApplication", data)

	local role = agent.role
	if not role then return end

	local applicationBin = redisproxy:hget(string.format("role:%d:friendApplications", msg.roleId), 
		tostring(msg.objectId))
	if not applicationBin then return end

	local applicationInfo = pb.decode("ApplicationInfo", applicationBin)

	if msg.handleCode == "Agree" then
		-- 检查好友个数上限
		local currentFriendCnt = redisproxy:scard(string.format("role:%d:friends", msg.roleId))
		if currentFriendCnt >= role:getFriendCntLimit() then
			role:sendSysErrMsg(SYS_ERR_FRIEND_COUNT_LIMIT)
			return
		end
		
		-- 统计好友申请
		redisproxy:sadd(string.format("role:%d:friends", msg.roleId), applicationInfo.roleId)
		redisproxy:sadd(string.format("role:%d:friends", applicationInfo.roleId), msg.roleId)
		role:sendSysErrMsg(SYS_ERR_FRIEND_APPLICATION_AGREE, msg.objectId)
		-- 如果存在我申请对方的申请记录也删除
		redisproxy:hdel(string.format("role:%d:friendApplications", msg.objectId), tostring(msg.roleId))
	elseif msg.handleCode == "Deny" then
		role:sendSysErrMsg(SYS_ERR_FRIEND_APPLICATION_DENY, msg.objectId)
	end

	-- 删除好友申请记录
	redisproxy:hdel(string.format("role:%d:friendApplications", msg.roleId), tostring(msg.objectId))
end

function FriendAction.listApplications(agent, data)
	local msg = pb.decode("SimpleEvent", data)


	local applicationList = {}
	applicationList.applications = {}

	local applications = redisproxy:hgetall(string.format("role:%d:friendApplications", msg.roleId))
	for objectId, applicationBin in pairs(applications) do
		local applicationInfo = pb.decode("ApplicationInfo", applicationBin)
		local applicantsInfo = redisproxy:hmget(string.format("role:%s", applicationInfo.roleId), 
			"name", "level", "pvpRank", "delete", "mainHeroId")
		if tonumber(applicantsInfo[4]) == 0 then
			local mainHeroInfo = redisproxy:hmget(string.format("hero:%d:%s", applicationInfo.roleId, tonumber(applicantsInfo[5])),
				"type", "delete")
			-- 存在主将
			if tonumber(mainHeroInfo[2]) == 0 then
				table.insert(applicationList.applications, {
					roleId = applicationInfo.roleId,
					name = applicantsInfo[1],
					level = tonumber(applicantsInfo[2]),
					pvpRank = tonumber(applicantsInfo[3]),
					applicationId = applicationInfo.applicationId,
					timestamp = applicationInfo.timestamp,
					mainHeroType = tonumber(mainHeroInfo[1]),
				})
			end
		end
	end

	local bin = pb.encode("ApplicationList", applicationList)
	SendPacket(actionCodes.FriendApplicationsResponse, bin)
end

function FriendAction.deleteFriend(agent, data)
	local msg = pb.decode("DeleteFriend", data)

	local role = agent.role
	if not role then return end

	-- 清楚与该好友相关的记录
	local function deleteRelation(roleId, objectId)
		local todayTimestamp = os.date("%Y%m%d")
		-- 删除好友
		redisproxy:srem(string.format("role:%d:friends", roleId), objectId)

		-- 删除获得他的体力记录, 特殊处理, 已经获得不需要删除, 需要作为计数
		local todayReceiveHealthKey = string.format("role:%d:receivedHealth:%s", roleId, todayTimestamp)
		if redisproxy:hget(todayReceiveHealthKey, tostring(objectId)) == "0" then
			redisproxy:hdel(todayReceiveHealthKey, tostring(objectId))
		end
	end

	-- 互相删除
	deleteRelation(msg.roleId, msg.objectId)
	deleteRelation(msg.objectId, msg.roleId)

	role:sendSysErrMsg(SYS_ERR_FRIEND_DELETE_SUCCESS)
end

-- 捐献体力给好友
function FriendAction.donateHealth(agent, data)
	local msg = pb.decode("DonateHealthToFriend", data)

	local role = agent.role
	if not role then return end

	-- 检查当前赠送体力次数
	local todayDonateHealthKey = string.format("role:%d:donateHealth:%s", msg.roleId, os.date("%Y%m%d"))
	if redisproxy:scard(todayDonateHealthKey) == FRIEND_DONATE_HEALTH_TIMES then
		role:sendSysErrMsg(SYS_ERR_FRIEND_DONATE_HEALTH_LIMIT)
		return
	end

	-- 该玩家已经被赠送过了
	if redisproxy:sismember(todayDonateHealthKey, tostring(msg.objectId)) then
		role:sendSysErrMsg(SYS_ERR_FRIEND_HAS_DONATED)
		return
	end

	redisproxy:sadd(todayDonateHealthKey, msg.objectId)

	-- 加入到玩家的接受队列里面
	redisproxy:hset(string.format("role:%d:receivedHealth:%s", msg.objectId, os.date("%Y%m%d")), 
		msg.roleId, 0)
	role:sendSysErrMsg(SYS_ERR_FRIEND_DONATE_SUCCESS)
end

-- 获取好友赠送的体力
function FriendAction.receiveHealth(agent, data)
	local msg = pb.decode("ReceiveDonatedHealth", data)

	local role = agent.role
	if not role then return end

	-- 检查赠送记录
	local todayReceiveHealthKey = string.format("role:%d:receivedHealth:%s", role:getProperty("id"), os.date("%Y%m%d"))
	local hasReceived = redisproxy:hget(todayReceiveHealthKey, tostring(msg.objectId))
	if not hasReceived or hasReceived == "1" then
		return
	end

	-- 体力已满
	if role:getProperty("health") >= role:getHealthLimit() then
		role:sendSysErrMsg(SYS_ERR_HEALTH_FULL)
		return
	end

	local hasReceivedCnt = 0
	for _, friendId in ipairs(redisproxy:hkeys(todayReceiveHealthKey)) do
		if redisproxy:hget(todayReceiveHealthKey, tostring(friendId)) == "1" then
			hasReceivedCnt = hasReceivedCnt + 1
		end
	end

	-- 今天已经领取达到上限
	if hasReceivedCnt >= FRIEND_RECEIVE_HEALTH_TIMES then
		role:sendSysErrMsg(SYS_ERR_FRIEND_RECV_LIMIT)
		return
	end

	-- 可以领取
	redisproxy:hset(todayReceiveHealthKey, tostring(msg.objectId), 1)
	local real_val = role:recoverHealth(FRIEND_DONATE_HEALTH_UNIT, {notify = true, checkLimit = false, sendError = true})
	
	if real_val > 0 then 
		logger.info("r_in_health", role:logData({
			behavior = "i_hl_friend",
			pm1 = real_val,
			pm2 = msg.objectId,
		}))

		role:sendSysErrMsg(SYS_ERR_FRIEND_RECV_SUCCESS)
	end
end


return FriendAction