local CsvLoader = {
	configs = {
		["unitCsv"] = { parser = "UnitCsv", file = "csv/unit.csv" },
		["heroProfessionCsv"] = { parser = "HeroProfessionCsv", file = "csv/role_profession.csv" },
		["roleInfoCsv"] = { parser = "RoleInfoCsv", file = "csv/role_info.csv" },
		["pvpMatchCsv"] = { parser = "PvpMatchCsv", file = "csv/pvp_match.csv" },
		["pvpAwardCsv"] = { parser = "PvpAwardCsv", file = "csv/pvp_award.csv" },
		["pvpGiftCsv"] = { parser = "PvpGiftCsv", file = "csv/pvp_gift.csv" },
		["dropCsv"] = { parser = "DropCsv", file = "csv/drop.csv" },
		["giftDropCsv"] = { parser = "GiftDropCsv", file = "csv/gift_drop.csv" },
		["itemCsv"] = { parser = "ItemCsv", file = "csv/item.csv" },
		["activitySignCsv"] = { parser = "ActivitySignCsv", file = "csv/activity_qiandao.csv" },
		["battleResultCsv"] = { parser = "BattleResultCsv", file = "csv/battle_result.csv" },
		["storeCsv"] = { parser = "StoreCsv", file = "csv/store.csv" },
		["rechargeCsv"] = { parser = "ReChargeCsv", file = "csv/recharge.csv" },
		["globalCsv"] = { parser = "GlobalCsv", file = "csv/global.csv" },
		["evolutionModifyCsv"] = { parser = "EvolutionModifyCsv", file = "csv/evolution.csv" },
		["restraintCsv"] = { parser = "RestraintCsv", file = "csv/restraint.csv" },
		["towerDiffCsv"] = { parser = "TowerDiffCsv", file = "csv/tower_diff.csv"},
		["towerBattleCsv"] = { parser = "TowerBattleCsv", file = "csv/tower_battle.csv"},
		["towerAttrCsv"] = { parser = "TowerAttrCsv", file = "csv/tower_attr.csv" },
		["emailCsv"] = { parser = "EmailCsv", file = "csv/email.csv" },
		["techItemCsv"] = { parser = "TechItemCsv", file = "csv/tech_item.csv" },
		["functionCostCsv"] = { parser = "FunctionCostCsv", file = "csv/function_cost.csv" },
		["dailyTaskCsv"] = { parser = "DailyTaskCsv", file = "csv/daily_task.csv" },
		["shopOpenCsv"] = { parser = "ShopOpenCsv", file = "csv/shop_opening.csv"},
		
		["dailyGiftCsv"] = { parser = "DailyGiftCsv", file = "csv/daily_gift.csv" },
		["legendBattleCsv"] = { parser = "LegendBattleCsv", file = "csv/legend_battle.csv" },
		["professionPhaseCsv"] = { parser = "ProfessionPhaseCsv", file = "csv/career_class.csv" },
		["professionLevelCsv"] = { parser = "ProfessionLevelCsv", file = "csv/career_level.csv" },
		["heroStarInfoCsv"] = { parser = "HeroStarInfoCsv", file = "csv/herostar_info.csv" },
		["heroStarAttrCsv"] = { parser = "HeroStarAttrCsv", file = "csv/herostar_attr.csv" },
		["beautyListCsv"] = { parser = "BeautyListCsv", file = "csv/beauty_list.csv"},
		["beautyTrainCsv"] = { parser = "BeautyTrainCsv", file = "csv/beauty_train.csv"},
		["beautyEvolutionCsv"] = { parser = "BeautyEvolutionCsv", file = "csv/beauty_evolution.csv"},
		["beautyPotentialCsv"] = { parser = "BeautyPotentialCsv", file = "csv/beauty_potential.csv"},
		["beautyCritCsv"] = { parser = "BeautyCritCsv", file = "csv/beauty_crit.csv"},
		["vipCsv"] = { parser = "VipCsv", file = "csv/vip.csv" },
		["vipCostCsv"] = { parser = "VipCostCsv", file = "csv/function_cost.csv" },
		["levelGiftCsv"] = { parser = "LevelGiftCsv", file = "csv/level_gift.csv"},
		["serverGiftCsv"] = { parser = "NewServerCsv", file = "csv/login_gift.csv"},
		["zhaoCaiCsv"] = { parser = "ZhaoCaiCsv", file = "csv/zhaocai.csv" },
		["moneyBattleCsv"] = { parser = "MoneyBattleCsv", file = "csv/money_battle.csv" },
		["expBattleCsv"] = { parser = "ExpBattleCsv", file = "csv/exp_battle.csv" },
		["skillLevelCsv"] = { parser = "SkillLevelCsv", file = "csv/skill_level.csv" },
		["skillPassiveLevelCsv"] = { parser = "SkillPassiveLevelCsv", file = "csv/skill_passive_level.csv" },

		["heroExpCsv"] = { parser = "HeroExpCsv", file = "csv/hero_exp.csv" },

		["equipCsv"] = { parser = "EquipCsv", file = "csv/equip.csv" },	
		["equipSetCsv"] = { parser = "EquipSetCsv", file = "csv/equip_set.csv" },	
		["equipLevelCostCsv"] = { parser = "EquipLevelCostCsv", file = "csv/equip_level_cost.csv" },

		["noticeCsv"] = { parser = "NoticeCsv", file = "csv/notice.csv" },
		["shopCsv"] = { parser = "ShopCsv", file = "csv/shop.csv" },
		["nameDictCsv"] = { parser = "NameDictCsv", file = "csv/name_comb.csv" },
		
		["forceMatchCsv"] = { parser = "ForceMatchCsv", file = "csv/force_match.csv" },
		["forceMatchUpdateCsv"] = { parser = "ForceMatchUpdateCsv", file = "csv/force_match_update.csv" },
		
		["exchangeCsv"] = { parser = "ExchangeCodeCsv", file = "csv/libaoma.csv" },

		["trialBattleCsv"] = { parser = "TrialBattleCsv", file = "csv/shilian_battle.csv" },

		["guideCsv"] = { parser = "GuideCsv", file = "csv/user_guide.csv" },

		["ljczCsv"] = { parser = "LjczCsv", file = "csv/ljcz.csv" },

		["activityListCsv"] = { parser = "ActivityListCsv", file = "csv/activity_list.csv" },

		["pushCsv"] = { parser = "PushCsv", file = "csv/push.csv" },

		["fundCsv"] = { parser = "FundCsv", file = "csv/fund.csv" },

		["pvpUpCsv"] = { parser = "PvpUpCsv", file = "csv/pvpjsjl.csv"},
		["battleSoulCsv"] = { parser = "BattleSoulCsv", file = "csv/zhanhun.csv" },
		["godHeroCsv"] = { parser = "GodHeroCsv", file = "csv/shenjiang.csv" },
		["worldNoticeCsv"] = { parser = "WorldNoticeCsv", file = "csv/runhorse.csv" },
	}
}

function CsvLoader.loadCsv(publicCsvDb)
	local function storeCsvDb(name, csvParser)
		publicCsvDb[name] = publicCsvDb[name] or {}

		for key, value in pairs(csvParser) do
			if type(value) == "table" then
				publicCsvDb[name][key] = value
			end
		end
	end

	local mapInfoCsv = require("csv.MapInfoCsv")
	mapInfoCsv:load({ "csv/chapter_info.csv", "csv/challenge_info.csv", })
	storeCsvDb("mapInfoCsv", mapInfoCsv)

	local mapBattleCsv = require("csv.MapBattleCsv")
	mapBattleCsv:load({ "csv/chapter_battle.csv", "csv/challenge_battle.csv", })
	storeCsvDb("mapBattleCsv", mapBattleCsv)

	for name, data in pairs(CsvLoader.configs) do
		local parser = require("csv." .. data.parser)
		parser:load(data.file)
		storeCsvDb(name, parser)
	end
end

function CsvLoader.bindCsvData(publicCsvDb)
	local function attachMethod(name, parser)
		local csvData = publicCsvDb[name] or {}
		for key, value in pairs(csvData) do
			_G[name][key] = value
		end
	end

	mapInfoCsv = require("csv.MapInfoCsv")
	attachMethod("mapInfoCsv", mapInfoCsv)

	mapBattleCsv = require("csv.MapBattleCsv")
	attachMethod("mapBattleCsv", mapBattleCsv)

	for name, data in pairs(CsvLoader.configs) do
		_G[name] = require("csv." .. data.parser)
		attachMethod(name, _G[name])
	end
end

function CsvLoader.unbindCsvData()
	_G["mapInfoCsv"] = nil
	_G["mapBattleCsv"] = nil
	for name, data in pairs(CsvLoader.configs) do
		_G[name] = nil
	end
end

return CsvLoader