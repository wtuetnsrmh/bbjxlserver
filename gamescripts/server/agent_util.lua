
local _M = { }

-- 超时次数
local heartTimeoutCount 		= 0
-- 加速次数
local heartQuickCount 			= 0
-- 上次检查心跳时间
local lastHeartCheckTime		= 0
-- 下次进入定时检查的时间
local nextCheckTime				= 0
-- 心跳误差允许范围
local HEART_BEAT_ERROR_LIMIT 	= 1
-- 最大超时次数
local HEART_TIMEOUT_COUNT_MAX 	= 3
-- 最大加速次数
local HEART_QUICK_COUNT_MAX 	= 3
-- 心跳定时间隔
local HEART_TIMER_INTERVAL 		= 5

local function check_heart_beat(agent, now)
	-- 充值等操作不检查心跳
	if agent.ignoreHeartbeat then return end

	if lastHeartCheckTime - now > HEART_TIMER_INTERVAL or 
		now - lastHeartCheckTime > HEART_TIMER_INTERVAL then
		heartTimeoutCount = heartTimeoutCount + 1
		if heartTimeoutCount >= HEART_TIMEOUT_COUNT_MAX then
			print("timeout! then agent will shut down by self", agent.client_fd)
			skynet.call(agent.gate_serv, "lua", "kick", agent.client_fd)
			heartTimeoutCount = 0
		end
	else
		heartTimeoutCount = 0
	end	
end

local function check_health(agent, now)
	local role = agent.role
	role.updateHealthTime = now - role.timestamps:getProperty("lastHealthTime")
	if role.updateHealthTime >= role.UpdateHealthTimer then
		local real_val = role:recoverHealth(role.UpdateHealthValue, { time = true, notify = true })
		if real_val > 0 then
			logger.info("r_in_health", role:logData({
				behavior = "i_hl_return",
				pm1 = real_val,
				pm2 = 1, --online
			}))
		end
		role.timestamps:setProperty("lastHealthTime", now)
	end
end

local PointDataMark = {}
local resetTimeStr = string.format("%02d00", RESET_TIME)

local function check_daily_reset(agent, now)
	local date = os.date("*t", now)
	local timeStr = string.format("%02d", date.hour) .. string.format("%02d", date.min)
	local dataStr = date.year .. string.format("%02d", date.month) .. string.format("%02d", date.day)
	PointDataMark[dataStr] = PointDataMark[dataStr] or {}

	local role = agent.role

	local function timeEffect(checkTimeStr)
		local effect = (timeStr == checkTimeStr) and not PointDataMark[dataStr][checkTimeStr]
		if effect then
			PointDataMark[dataStr][timeStr] = true
		end

		return effect
	end

	if timeEffect(resetTimeStr) then
		-- 刷新每日数据
		local nextResetTime = role:getProperty("nextResetDailyTime")
		if now >= nextResetTime then
			local _, nextTime = diffTime({hour = RESET_TIME})
			role:setProperty("nextResetDailyTime", nextTime)

			role.dailyData:refreshDailyData(role)
			local bin = pb.encode("NewMessageNotify", {newEvents = role.dailyData:pbData()})
			SendPacket(actionCodes.RoleUpdateDailyProps, bin)

			role:setProperty("loginDays", role:getProperty("loginDays") + 1)
			role:notifyUpdateProperty("loginDays", role:getProperty("loginDays"))

			-- 重置副本
			role:resetCarbon()

			local dateYm = os.date("%Y%m", now)
			role:setLoginDay(dateYm, date.day)

			role:resetTowerData()
		end
	end

	if timeEffect("0900") then
		role:refreshShopByIndex({1})
	end

	if timeEffect("1200")  then
		role:refreshShopByIndex({1})
	end

	if timeEffect("1800")  then
		role:refreshShopByIndex({1})
	end

	if timeEffect("2100")  then
		-- 传奇商店
		role:refreshShopByIndex({ 1, 2, 3, 4, 5, 6 })	
	end

	--活动时间点更新
	if timeEffect("0000") then
		role:refreshActivityListTime()
	end
end

function _M:update(agent)
	local now = skynet.time()
	if now >= nextCheckTime then
		check_heart_beat(agent, now)
		nextCheckTime = now + HEART_TIMER_INTERVAL		
	end
	check_health(agent, now)
	agent.role:checkNewEvent()
	check_daily_reset(agent, now)
end

function _M:heart_beat()
	local now = skynet.time()
	if lastHeartCheckTime - now < HEART_TIMER_INTERVAL - HEART_BEAT_ERROR_LIMIT then
		heartQuickCount = heartQuickCount + 1
		if heartQuickCount == HEART_QUICK_COUNT_MAX then
			-- 将错误写入日志, 踢玩家下线
		end
	end
	lastHeartCheckTime = now
end

function _M:reset()
	heartTimeoutCount = 0
	lastHeartCheckTime = skynet.time()
end

return _M
