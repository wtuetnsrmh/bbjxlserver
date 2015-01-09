local GiftAction = {}

function GiftAction.listGiftRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local giftsResponse = {}
	giftsResponse.gifts = {}

	local giftIds = redisproxy:smembers(string.format("role:%d:giftIds", msg.roleId))

	giftsResponse.totalGiftCnt = #giftIds

	local endIndx = #giftIds > 20 and #giftIds - 20 + 1 or 1
	for index = #giftIds, endIndx, -1 do
		local giftId = tonumber(giftIds[index])

		if redisproxy:exists(string.format("role:%d:giftIds", msg.roleId)) then
			local curGiftInfo = redisproxy:hmget(string.format("gift:%d:%d", msg.roleId, giftId), "id", "itemId", "createTime")
			table.insert(giftsResponse.gifts, {
				id = tonumber(curGiftInfo[1]),
				itemId = tonumber(curGiftInfo[2]),
				createTime = tonumber(curGiftInfo[3]),
			})
		end
	end

	local bin = pb.encode("GiftList", giftsResponse)
	SendPacket(actionCodes.GiftListResponse, bin)
end

function GiftAction.receiveRequest(agent, data)
	local msg = pb.decode("ReceiveGiftReqeust", data)

	local role = agent.role

	local function receiveGift(roleId, giftId)
		local gift = require("datamodel.Gift").new({ key = string.format("gift:%d:%d", roleId, giftId)})
		gift:load()

		role:awardItemCsv(gift:getProperty("itemId"))

		-- 删除礼包数据
		redisproxy:srem(string.format("role:%d:giftIds", roleId), giftId)
		redisproxy:del(string.format("gift:%d:%d", roleId, giftId))
	end
	
	if msg.giftId == 0 then
		-- 收取全部礼品
		local giftIds = redisproxy:smembers(string.format("role:%d:giftIds", msg.roleId))
		for _, giftId in pairs(giftIds) do
			receiveGift(msg.roleId, giftId)
		end
	else
		receiveGift(msg.roleId, msg.giftId)
	end

	local recvResponse = { errorCode = "SUCCESS", giftId = msg.giftId }
	local bin = pb.encode("ReceiveGiftResponse", recvResponse)
	SendPacket(actionCodes.GiftReceiveResponse, bin)
end

function GiftAction.RechargeAwardRequest(agent, data)
	local msg = pb.decode("SimpleEvent", data)

	local role = agent.role

	if role:getProperty("firstRechargeAwardState") == 0 then
		--不可领取
		role:sendSysErrMsg(SYS_ERR_NOT_FIRST_RECHARGE_AWARD)
		return
	end

	if role:getProperty("firstRechargeAwardState") == 2 then
		--已领取
		role:sendSysErrMsg(SYS_ERR_HAVE_RECEIVE_FIRST_RECHARGE_AWARD)
		return
	end

	local awardData = globalCsv:getFieldValue("firstRechargeAward")
	for itemId,itemNum in pairs(awardData) do
		role:awardItemCsv(tonum(itemId), {num = tonum(itemNum)})
		-- TODO 增加日志 首充奖励 奖励：银币道具

	end

	role:updataFirstRechargeAwardState(2)

	local bin = pb.encode("SimpleEvent", {})
	SendPacket(actionCodes.GiftRechargeAwardResponse, bin)
end

return GiftAction