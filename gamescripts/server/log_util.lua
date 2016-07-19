
--[[
功能拆分目的：
为了避免重复查找具体代码位置

]]
local _M = {}

-- 商店购买
function _M.log_store_expend(role, priceKey, itemId, itemNum, price, storeId)
	local behav = ""
	local typ = ""
	if "1" == priceKey then
		typ = "r_out_yuanbao"
		behav = "o_yb_buy_store"
	elseif "3" == priceKey then
		typ = "r_out_zhangong"
		behav = "o_zg_buy_store"
	elseif "4" == priceKey then			
		typ = "r_out_herosoul"
		behav = "o_hs_buy_store"
	else
		return
	end
	if typ == "r_out_yuanbao" then
		logger.info(typ, role:logData({
			behavior = behav,
			vipLevel = role:getProperty("vipLevel"),
			pm1 = price,
			pm2 = itemId,
			pm3 = storeId,
		}))
	else
		logger.info(typ, role:logData({
			behavior = behav,
			pm1 = price,
			pm2 = itemId,
			pm3 = storeId,
		}))
	end
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	if ItemTypeId.HeroFragment == itemInfo.type then
		logger.info("r_in_fragment", role:logData({
			behavior = "i_fg_buy_store",
			pm1 = itemId,
			pm2 = itemNum,
			pm3 = storeId,
		}))		
	end
end

-- 出生赠送
-- 令牌，星魂
function _M.log_born_award(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	if ItemTypeId.Lingpai == itemInfo.type then
		logger.info("r_in_lingpai", role:logData({
			behavior = "i_lp_born",
			pm1 = itemNum,
		}))
	elseif ItemTypeId.StarSoul == itemInfo.type then
		logger.info("r_in_starsoul", role:logData({
			behavior = "i_ss_born",
			pm1 = itemNum,
		}))
	elseif ItemTypeId.Hero == itemInfo.type then
		logger.info("r_in_hero", role:logData({
			behavior = "i_hr_born",
			pm1 = itemNum,
			pm2 = itemInfo.heroType,
		}))
	end	
end

-- 日常任务
function _M.log_task_award(role, taskId)
	local taskData = dailyTaskCsv:getTaskById(taskId)
	if 4 == taskId then
		logger.info("r_in_zhangong", role:logData({
			behavior = "i_zg_task",
			pm1 = taskData.zhangong,
			pm2 = taskId,
		}))
	elseif 8 == taskId then
		logger.info("r_in_starsoul", role:logData({
			behavior = "i_ss_task",
			pm1 = taskData.starSoul,
			pm2 = taskId,
		}))
	elseif 9 == taskId then
		logger.info("r_in_herosoul", role:logData({
			behavior = "i_hs_task",
			pm1 = taskData.heroSoul,
			pm2 = taskId,
		}))
	end	
	if taskData.yuanbao > 0 then
		logger.info("r_in_yuanbao", role:logData({
			behavior = "i_yb_day_task",
			pm1 = taskData.yuanbao,
			pm2 = taskId,
			str1 = "0",
		}))		
	end		
end

-- 签到奖励
-- 英雄碎片，元宝
function _M.log_sign_award(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	local day = tonum(...)
	if ItemTypeId.HeroFragment == itemInfo.type then
		logger.info("r_in_fragment", role:logData({
			behavior = "i_fg_sign",
			pm1 = itemNum,
			pm2 = itemId,
		}))
	elseif ItemTypeId.Yuanbao == itemInfo.type then
		logger.info("r_in_yuanbao", role:logData({
			behavior = "i_yb_sign",
			pm1 = itemNum,
			pm2 = day,
			str1 = "0",
		}))
	elseif ItemTypeId.Equip == itemInfo.type then
		logger.info("r_in_equip", role:logData({
			behavior = "i_eq_sign",
			pm1 = itemNum,
			pm2 = itemId,
			pm3 = day,
		}))
	elseif ItemTypeId.Hero == itemInfo.type then
		logger.info("r_in_hero", role:logData({
			behavior = "i_hr_sign",
			pm1 = itemNum,
			pm2 = itemInfo.heroType,
		}))
	end
end

-- 开服礼包
-- 元宝
function _M.log_openserv_award(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	local day = tonum(...)
	if ItemTypeId.Yuanbao == itemInfo.type then
		logger.info("r_in_yuanbao", role:logData({
			behavior = "i_yb_open_serv",
			pm1 = itemNum,
			pm2 = day,
			str1 = "0",
		}))
	elseif ItemTypeId.Equip == itemInfo.type then
		logger.info("r_in_equip", role:logData({
			behavior = "i_eq_open_serv",
			pm1 = itemNum,
			pm2 = itemId,
			pm3 = day,
		}))
	elseif ItemTypeId.Hero == itemInfo.type then
		logger.info("r_in_hero", role:logData({
			behavior = "i_hr_openserv",
			pm1 = itemNum,
			pm2 = itemInfo.heroType,
		}))
	end	
end

-- 等级礼包
-- 碎片，元宝，装备
function _M.log_level_award(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	local giftLvl = tonum(...)
	if ItemTypeId.HeroFragment == itemInfo.type then
		logger.info("r_in_fragment", role:logData({
			behavior = "i_fg_lvl_gift",
			pm1 = itemNum,
			pm2 = itemId,
			pm3 = giftLvl,
		}))
	elseif ItemTypeId.Yuanbao == itemInfo.type then
		logger.info("r_in_yuanbao", role:logData({
			behavior = "i_yb_lvl_gift",
			pm1 = itemNum,
			pm2 = giftLvl,
			str1 = "0",
		}))		
	elseif ItemTypeId.Equip == itemInfo.type then
		logger.info("r_in_equip", role:logData({
			behavior = "i_eq_lvl_gift",
			pm1 = itemNum,
			pm2 = itemId,
			pm3 = giftLvl,
		}))
	elseif ItemTypeId.Hero == itemInfo.type then
		logger.info("r_in_hero", role:logData({
			behavior = "i_hr_lvl_gift",
			pm1 = itemNum,
			pm2 = itemInfo.heroType,
		}))
	end	
end

-- vip礼包,或者其他礼包
function _M.log_gift_bag(role, itemId, itemNum, bagId)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	if ItemTypeId.Equip == itemInfo.type then
		logger.info("r_in_equip", role:logData({
			behavior = "i_eq_gift_bag",
			pm1 = itemNum,
			pm2 = itemId,
			pm3 = bagId,
		}))			
	elseif ItemTypeId.Hero == itemInfo.type then		
		logger.info("r_in_hero", role:logData({
			behavior = "i_hr_gift_bag",
			pm1 = itemNum,
			pm2 = itemInfo.heroType,
			pm3 = bagId,
		}))			
	end
end

-- 邮件礼包
-- 元宝
function _M.log_mail_award(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	local emailId = tonum(...)
	if ItemTypeId.Yuanbao == itemInfo.type then
		logger.info("r_in_yuanbao", role:logData({
			behavior = "i_yb_mail",
			pm1 = itemNum,
			pm2 = emailId,
			str1 = "0",
		}))
	elseif ItemTypeId.Lingpai == itemInfo.type then
		logger.info("r_in_lingpai", role:logData({
			behavior = "i_lp_mail",
			pm1 = itemNum,
		}))
	elseif ItemTypeId.Hero == itemInfo.type then
		logger.info("r_in_hero", role:logData({
			behavior = "i_hr_mail",
			pm1 = itemNum,
			pm2 = itemInfo.heroType,
		}))	
	elseif ItemTypeId.ZhanGong == itemInfo.type then
		logger.info("r_in_zhangong", role:logData({
			behavior = "i_zg_mail", 
			pm1 = itemNum,
			pm2 = emailId,
		}))
	end
end

-- 副本奖励
-- 令牌，碎片，元宝
function _M.log_map_award(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	if ItemTypeId.Lingpai == itemInfo.type then
		logger.info("r_in_lingpai", role:logData({
			behavior = "i_lp_carbon",
			pm1 = itemNum,
		}))
	elseif ItemTypeId.HeroFragment == itemInfo.type then
		logger.info("r_in_fragment", role:logData({
			behavior = "i_fg_carbon",
			pm1 = itemNum,
			pm2 = itemId,
		}))
	elseif ItemTypeId.Yuanbao == itemInfo.type then
		logger.info("r_in_yuanbao", role:logData({
			behavior = "i_yb_carbon",
			pm1 = itemNum,
			str1 = "0",
		}))		
	end		
end

-- 爬塔奖励 元宝除外
function _M.log_tower_award(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	if ItemTypeId.Equip == itemInfo.type then
		logger.info("r_in_equip", role:logData({
			behavior = "i_eq_tower",
			pm1 = itemNum,
			pm2 = itemId,
			pm3 = 0,
		}))
	end
end

-- 商城购买 i_lp_buy_store
function _M.log_store(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	local yuanbao = tonum(...)
	if ItemTypeId.Lingpai == itemInfo.type then
		logger.info("r_in_lingpai", role:logData({
			behavior = "i_lp_buy_store",
			pm1 = itemNum,
			pm2 = yuanbao,
		}))
	end
end

-- 抽卡
function _M.log_buy_card(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	if ItemTypeId.HeroFragment == itemInfo.type then
		logger.info("r_in_fragment", role:logData({
			behavior = "i_fg_card",
			pm1 = itemNum,
			pm2 = itemId,
		}))
	elseif ItemTypeId.Equip == itemInfo.type then
		logger.info("r_in_equip", role:logData({
			behavior = "i_eq_card",
			pm1 = itemNum,
			pm2 = itemId,
		}))	
	elseif ItemTypeId.Hero == itemInfo.type then
		logger.info("r_in_hero", role:logData({
			behavior = "i_hr_card",
			pm1 = itemNum or 1,
			pm2 = itemInfo.heroType,
		}))			
	end
end

-- 副本掉落
function _M.log_fb_drop(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	local carbonId = tonum(...)
	if ItemTypeId.HeroFragment == itemInfo.type then
		logger.info("r_in_fragment", role:logData({
			behavior = "i_fg_fb_drop",
			pm1 = itemNum,
			pm2 = itemId,
			pm3 = carbonId,
		}))
	elseif ItemTypeId.Equip == itemInfo.type then
		logger.info("r_in_equip", role:logData({
			behavior = "i_eq_fb_drop",
			pm1 = itemNum,
			pm2 = itemId,
			pm3 = carbonId,
		}))		
	end	
end

function _M.log_expedition_award(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	if ItemTypeId.HeroFragment == itemInfo.type then
		local lvl = tonumber(...)
		logger.info("r_in_fragment", role:logData({
			behavior = "i_fg_yz_award", 
			pm1 = itemNum,
			pm2 = itemId,
			pm3 = lvl,
		}))
	end
end

function _M.log_god_hero(role, itemId, itemNum, ...)
	local itemInfo = itemCsv:getItemById(itemId)
	if not itemInfo then return end
	if ItemTypeId.HeroFragment == itemInfo.type then
		logger.info("r_in_fragment", role:logData({
			behavior = "i_fg_godhero",
			pm1 = itemNum,
			pm2 = itemId,
		}))
	elseif ItemTypeId.Hero == itemInfo.type then
		logger.info("r_in_hero", role:logData({
			behavior = "i_hr_godhero",
			pm1 = itemNum,
			pm2 = itemId,
		}))
	end	
end

return _M