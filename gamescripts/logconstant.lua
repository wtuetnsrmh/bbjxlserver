logFields = {
	-- user
	['u_name'] = 1,
	['p_id'] = 2,
	['u_id'] = 3,
	['u_ip'] = 4,
	['d_id'] = 5,

	-- role,
	['r_id'] = 101,
	['r_name'] = 102,
	['r_level'] = 103,
	['r_exp'] = 104,
	['r_health'] = 105,
	['r_money'] = 106,
	['r_yuanbao'] = 107,
	['r_pvpRank'] = 108,
	['r_lastLoginTime'] = 109,
	-- ['r_createTime'] = 110,
	['r_vipLevel'] = 111,

	-- hero,
	['h_id'] = 201,
	['h_type'] = 202,
	['h_level'] = 203,
	['h_exp'] = 204,
	['h_evolutionCount'] = 205,
	['h_createTime'] = 206,

	-- common
	['behavior'] = 10000,
	['pm1'] = 10001,
	['pm2'] = 10002,
	['pm3'] = 10003,
	['str1'] = 10004,

	['tstamp'] = 99999,
}

logActions = {
	['r_create'] = {
		code = 101,
		field = "p_id,u_id,d_id,r_id,r_name,tstamp",
	},
	['r_login'] = {
		code = 102,
		field = "p_id,u_id,d_id,r_id,r_name,r_level,r_vipLevel,behavior,tstamp",
	},
	['r_logout'] = {
		code = 103,
		field = "p_id,u_id,r_id,r_name,r_level,r_vipLevel,tstamp",
	},
	['r_property_update'] = {
		code = 104,
		field = "",
	},
	['r_in_yuanbao'] = {
		code = 105,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,str1,tstamp",
	}, 		
	['r_out_yuanbao'] = {
		code = 106,
		field = "p_id,u_id,r_id,r_name,r_vipLevel,behavior,pm1,pm2,pm3,tstamp",
	},		
	['r_in_health'] = {
		code = 107,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},			
	['r_out_health'] = {
		code = 108,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},			
	['r_in_zhangong'] = {
		code = 109,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},		
	['r_out_zhangong'] = {
		code = 110,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},		
	['r_in_starsoul'] = {
		code = 111,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},		
	['r_out_starsoul'] = {
		code = 112,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},		
	['r_in_lingpai'] = {
		code = 113,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	}, 		
	['r_out_lingpai'] = {
		code = 114,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},		
	['r_in_herosoul'] = {
		code = 115,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},		
	['r_out_herosoul'] = {
		code = 116,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},		
	['r_in_fragment'] = {
		code = 117,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	}, 		
	['r_out_fragment'] = {
		code = 118,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},		
	['r_in_equip'] = {
		code = 119,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},			
	['r_out_equip'] = {
		code = 120,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},			
	['r_in_hero'] = {
		code = 121,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},
	['r_out_hero'] = {
		code = 122,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},
	['r_carbon'] = {
		code = 150,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	},   			
	['r_legend'] = {
		code = 151,
		field = "p_id,u_id,r_id,r_name,tstamp",
	},				
	['r_trial_fb'] = {
		code = 152,
		field = "p_id,u_id,r_id,r_name,behavior,pm1,pm2,pm3,tstamp",
	}, 			
	['r_tower'] = {
		code = 153,
		field = "p_id,u_id,r_id,r_name,pm1,pm2,pm3,tstamp",
	},				
	['r_pvp']	= {
		code = 154,
		field = "p_id,u_id,r_id,r_name,tstamp",
	},				
	['h_create'] = {
		code = 201,
		field = "",
	},				
	['h_levelup'] = {
		code = 202,
		field = "",
	},
	['s_num_user_on'] = {
		code = 999,
		field = "pm1,pm2,pm3,tstamp",
	}, 
}

logBehaviors = {
	-- r_login
	['login_success'] = 10201,
	['login_role_not_exist'] = 10202,
	
	-- r_in_yuanbao
	['i_yb_rechange'] = 10501,			-- 玩家充值 pm1 = 元宝数量, pm2 = 充值金额 
	['i_yb_gm_send'] = 10502,			-- gm发放   pm1 = 元宝数量
	['i_yb_open_serv'] = 10503,			-- 开服礼包 pm1 = 元宝数量, pm2 = day
	['i_yb_lvl_gift'] = 10504,			-- 等级礼包 pm1 = 元宝数量, pm2 = lvl
	['i_yb_sign'] = 10505,				-- 签到奖励 pm1 = 元宝数量, pm2 = day
	['i_yb_day_task'] = 10506,			-- 每日任务 pm1 = 元宝数量, pm2 = taskId
	['i_yb_tower'] = 10507,				-- 爬塔奖励 pm1 = 元宝数量
	['i_yb_mail'] = 10508,				-- 邮件附件 pm1 = 元宝数量, pm2 = mailId
	['i_yb_carbon']	= 10509,			-- 副本奖励 pm1 = 元宝数量

	-- r_out_yuanbao
	['o_yb_buy_card'] = 10601,			-- 抽卡 	pm1 = 元宝数量, pm2 = 抽卡类型
	['o_yb_buy_store'] = 10602,			-- 商城购买 pm1 = 元宝数量, pm2 = itemId, pm3 = 商城类型
	['o_yb_reset_carbon'] = 10603,		-- 副本重置 pm1 = 元宝数量, pm2 = 副本id
	['o_yb_employ_b'] = 10604, 			-- 招募美人 pm1 = 元宝数量, pm2 = 美人id
	['o_yb_legend_fresh'] = 10605,		-- 名将刷新 pm1 = 元宝数量
	['o_yb_legend_add'] = 10606, 		-- 名将次数 pm1 = 元宝数量
	['o_yb_tech_wash'] = 10607,			-- 科技洗点 pm1 = 元宝数量
	['o_yb_pvp_fresh'] = 10608,			-- 刷新cd   pm1 = 元宝数量
	['o_yb_pvp_add'] = 10609,			-- pvp 次数 pm1 = 元宝数量
	['o_yb_buy_hl']	= 10610,			-- 购买体力 pm1 = 元宝数量
	['o_yb_money']	= 10611,			-- 购买银币 pm1 = 元宝数量
	['o_yb_store_fresh'] = 10612,		-- 商店刷新 pm1 = 元宝数量, pm2 = 商店类型
	['o_yb_b_canwu'] = 10613,			-- 美人参悟 pm1 = 元宝数量, pm2 = 美人id
	['o_yb_rename'] = 10614,			-- 改名		pm1 = 元宝数量
	['o_yb_chat'] = 10615,				-- 元宝聊天 pm1 = 元宝数量
	['o_yb_godhero'] = 10616,			-- 神将		pm1 = 元宝数量
	['o_yb_tower_box'] = 10617,			-- 爬塔宝箱 pm1 = 元宝数量
	
	['i_hl_return'] = 10701,			-- 体力回复 pm1 = 数量, pm2 = 1(online) or 2(offline) 
	['i_hl_use_item'] = 10702,			-- 体力丹  	pm1 = 数量, pm2 = itemId
	['i_hl_friend'] = 10703,			-- 玩家赠送 pm1 = 数量, pm2 = 玩家id
	['i_hl_buy_yb'] = 10704,			-- 元宝购买 pm1 = 数量, pm2 = 购买次数
	['i_hl_lvl_up'] = 10705,			-- 玩家升级 pm1 = 数量, pm2 = 玩家等级
	['i_hl_chicken'] = 10706,			-- 吃鸡腿   pm1 = 数量
	['o_hl_carbon'] = 10801,			-- 副本挑战	pm1 = 数量, pm2 = 副本id

	['i_zg_mail'] = 10901, 				-- 邮件发送 pm1 = 战功数量
	['i_zg_pvp_win'] = 10902,			-- pvp 奖励 pm1 = 战功数量
	['i_zg_task'] = 10903,				-- 任务奖励 pm1 = 战功数量, pm2 = 任务id
	['o_zg_buy_store'] = 11001,   		-- 战功商店 pm1 = 战功数量, pm2 = itemId

	['i_ss_tower'] = 11101,				-- 爬塔奖励 pm1 = 数目, pm2 = 难度, pm3 = 层数
	['i_ss_task'] = 11102,				-- 任务奖励 pm1 = 数目, pm2 = 任务id, pm3 = 0
	['i_ss_born'] = 11103,				-- 出生奖励 pm1 = 数目, pm2 = 0, pm3 = 0
	['o_ss_star_up'] = 11201,			-- 点亮将星 pm1 = 数目, pm2 = 将星位置

	['i_lp_carbon'] = 11301,			-- 副本奖励 pm1 = 数目
	['i_lp_buy_store'] = 11302,			-- 商城购买 pm1 = 数目, pm2 = 花费元宝
	['i_lp_born'] = 11303,				-- 出生奖励 pm1 = 数目
	['i_lp_mail'] = 11304, 				-- 邮件附件 pm1 = 数目
	['o_lp_tech_up'] = 11401,			-- 科技升级 pm1 = 数目, pm2 = 职业, pm3 = 位置

	['i_hs_resolve'] = 11501,			-- 碎片分解 pm1 = 数目
	['i_hs_task'] = 11502,				-- 任务奖励 pm1 = 数目, pm2 = 任务id
	['o_hs_buy_store'] = 11601,			-- 名将商店 pm1 = 数目, pm2 = itemId

	-- ['i_fg_resolve'] = 11701,			-- 武将分解 pm1 = 数目, pm2 = 碎片id
	['i_fg_card'] = 11701,				-- 抽卡 	pm1 = 数目, pm2 = 碎片id
	['i_fg_sign'] = 11702,				-- 签到		pm1 = 数目, pm2 = 碎片id
	['i_fg_carbon'] = 11703,			-- 副本奖励 pm1 = 数目,
	['i_fg_buy_store'] = 11704,			-- 商店购买 pm1 = 数目, pm2 = 碎片id, pm3 = storeId
	['i_fg_lg_drop'] = 11705,			-- 名将掉落 pm1 = 数目, pm2 = 碎片id
	['i_fg_lvl_gift'] = 11706,			-- 等级礼包 pm1 = 数目, pm2 = 碎片id, pm3 = gift_lvl
	['i_fg_fb_drop'] = 11707,			-- 副本掉落 pm1 = 数目, pm2 = 碎片id, pm3 = 副本id
	['i_fg_yz_award'] = 11708,			-- 出塞奖励 pm1 = 数目, pm2 = 碎片id, pm3 = 出塞关卡
	['i_fg_godhero'] = 11709,			-- 神将	    pm1 = 数目, pm2 = 碎片id
	['o_fg_compose'] = 11801,			-- 碎片合成 pm1 = 数目, pm2 = fragId,
	['o_fg_resolve'] = 11802,			-- 碎片分解 pm1 = 数目, pm2 = fragId,
	['o_fg_star_up'] = 11803,			-- 升星    	pm1 = 数目, pm2 = fragId, pm3 = 觉醒等级

	['i_eq_lvl_gift'] = 11901,			-- 等级礼包 pm1 = 数目, pm2 = 装备id, pm3 = gift_lvl
	['i_eq_open_serv'] = 11902,			-- 开服礼包 pm1 = 数目, pm2 = 装备id, pm3 = day
	['i_eq_sign'] = 11903,				-- 签到礼包 pm1 = 数目, pm2 = 装备id, pm3 = day
	['i_eq_buy_store'] = 11904,			-- 名将商店 pm1 = 数目, pm2 = 装备id
	['i_eq_gift_bag'] = 11905,			-- 礼包 	pm1 = 数目, pm2 = 装备id, pm3 = bagId
	['i_eq_fb_drop'] = 11906,			-- 副本掉落 pm1 = 数目, pm2 = 装备id, pm3 = 副本id
	['i_eq_card'] = 11907,				-- 抽卡     pm1 = 数目, pm2 = 装备id
	['i_eq_tower'] = 11908,				-- 爬塔奖励 pm1 = 数目, pm2 = 装备id
	['o_eq_sell'] = 12001,				-- 出售		pm1 = 数目, pm2 = 装备id
	['o_eq_evol'] = 12002,				-- 炼化 	pm1 = 数目, pm2 = 装备id

	['i_hr_born'] = 12101,				-- 出生 	pm1 = 数目, pm2 = 类型id
	['i_hr_sign'] = 12102,				-- 签到     pm1 = 数目, pm2 = 类型id
	['i_hr_lvl_gift'] = 12103,			-- 等级礼包 pm1 = 数目, pm2 = 类型id
	['i_hr_openserv'] = 12104,			-- 开服礼包 pm1 = 数目, pm2 = 类型id
	['i_hr_gift_bag'] = 12105,			-- 礼包     pm1 = 数目, pm2 = 类型id, pm3 = bagId
	['i_hr_card'] = 12106,				-- 抽卡     pm1 = 数目, pm2 = 类型id 
	['i_hr_compose'] = 12107,			-- 碎片合成 pm1 = 数目, pm2 = 类型id
	['i_hr_mail'] = 12108,				-- 邮件赠送 pm1 = 数目, pm2 = 类型id
	['i_hr_godhero'] = 12109,			-- 神将		pm1 = 数目, pm2 = 类型id
	['o_hr_sell'] = 12201,				-- 出售  	pm1 = 数目, pm2 = 类型id
	-- ['o_hr_lvl_up'] = 12202,			-- 英雄升级 pm1 = 数目, pm2 = 类型id 
	['o_hr_decompose'] = 12202,			-- 英雄分解 pm1 = 数目, pm2 = 类型id

	['carbon_info'] = 15001,			-- 副本 pm1 = 副本id, pm2 = 进入or结算; 1进入，2结算
	['trial_exp'] = 15201,				-- pm1 = 副本id, pm2 = 经验产出
	['trial_money'] = 15202,			-- pm1 = 副本id, pm2 = 金钱产出
	['trial_qun'] = 15203,				-- pm1 = 副本id,
	['trial_wei'] = 15204,				-- pm1 = 副本id,
	['trial_shu'] = 15205,				-- pm1 = 副本id,
	['trial_wu'] = 15206,				-- pm1 = 副本id,
	['trial_beauty'] = 15207,			-- pm1 = 副本id,
}