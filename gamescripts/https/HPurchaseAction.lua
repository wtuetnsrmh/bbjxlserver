local PurchaseAction = {}

-- 充值成功
function PurchaseAction.confirm_order(params)
	skynet.error(cjson.encode(params))
	
	local roleName = redisproxy:get(string.format("uid:%s", params["uid"]))
	local roleId = redisproxy:get(string.format("user:%s", roleName))
	local orderKey = string.format("order:%d:%s", roleId, params["orderId"])

	local result = {}
	-- 已经处理过该订单
	if tonumber(redisproxy:hget(orderKey, "kunlunTime")) ~= 0 then
		result.retcode = -1
		result.retmsg = "订单已被处理过"

		return cjson.encode(result)
	end

	local agent = datacenter.get("agent", tonumber(roleId))

	if agent and agent.serv then
		skynet.call(agent.serv, "role", "handlePurchase", params)
	else
		-- 不在线
		local roleKey = string.format("role:%s", roleId)

		local firstRecharge = cjson.decode(redisproxy:hget(roleKey, "firstRechargeJson"))

		-- 根据充值金额来返还
		local rechargeData = rechargeCsv:getRechargeDataByRmb(tonumber(params["amount"]))
		if not rechargeData then
			result.retcode = -2
			result.retmsg = "充值档位错误"

			return cjson.encode(result)
		end

		local yuanbaoValue = rechargeData.paidYuanbao 
		if rechargeData.firstYuanbao == 0 or firstRecharge[tostring(rechargeData.id)] == 1 then
			yuanbaoValue = yuanbaoValue + rechargeData.freeYuanbao
		else
			yuanbaoValue = yuanbaoValue + rechargeData.firstYuanbao
			firstRecharge[tostring(rechargeData.id)] = 1
			redisproxy:hset(roleKey, "firstRechargeJson", cjson.encode(firstRecharge))
		end

		redisproxy:hincrby(roleKey, "rechargeRMB", rechargeData.rmbValue)
		local rechargedRMB = tonumber(redisproxy:hget(roleKey, "rechargeRMB"))
		local vipLevel = vipCsv:getLevelByCurMoney(rechargedRMB)
		redisproxy:hset(roleKey, "vipLevel", vipLevel)
		redisproxy:hincrby(roleKey, "yuanbao", yuanbaoValue)
		redisproxy:zincrby("rmbRank", rechargeData.rmbValue, roleId)

		if rechargeData.yuekaFlag == 1 then
			local timeKey = string.format("role:%d:timestamps", roleId)
			local yuekaDeadline = tonum(redisproxy:hget(timeKey, "yuekaDeadline"))
			local nowTime = skynet.time()
			local nowDate = os.date("*t", nowTime)
			local yuekaDays = 30
			local secOneDay = 24 * 3600
			--从0点开始算起
			if nowTime >= yuekaDeadline then
				yuekaDeadline = os.time({year = nowDate.year, month = nowDate.month, day = nowDate.day, hour = 0, min = 0, sec = 0}) + (yuekaDays - 1) * secOneDay
			else
				yuekaDeadline = yuekaDeadline + yuekaDays * secOneDay
			end
			redisproxy:hset(timeKey, "yuekaDeadline", yuekaDeadline)
		end

		logger.info("r_in_yuanbao", {
			p_id = tonumber(string.sub(params['uid'], -2, -1)),
			u_id = params['uid'],
			r_id = tonumber(roleId),
			r_name = roleName,
			behavior = 'i_yb_rechange',
			pm1 = yuanbaoValue,
			pm2 = tonumber(params['rechargeId']),
			pm3 = math.floor(params['amount']),
			str1 = params['oid'],
			tstamp = tonumber(params["dtime"]),
		})
	end

	-- 更新订单状态
	redisproxy:hmset(orderKey, "kunlunOrder", params["oid"], "uname", params["uname"],
		"kunlunTime", params["dtime"])

	-- 记录订单日志

	result.retcode = 0
	result.retmsg = "成功处理订单"

	return cjson.encode(result)
end

return PurchaseAction