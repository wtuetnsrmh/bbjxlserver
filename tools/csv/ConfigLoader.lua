local ConfigLoader = {
    configs = {
        ["unitCsv"] = { parser = "UnitCsv", file = "csv/unit.csv" }, 
        ["pvpRobotsCsv"] = { parser = "PvpRobotsCsv", file = "csv/pvp.csv" }, 
        ["emailCsv"] = { parser = "EmailCsv", file = "csv/email.csv" }, 
		["dailyGiftCsv"] = { parser = "DailyGiftCsv", file = "csv/daily_gift.csv" },
        ["evolutionModifyCsv"] = { parser = "EvolutionModifyCsv", file = "csv/evolution.csv" },
        ["globalCsv"] = { parser = "GlobalCsv", file = "csv/global.csv" },
        ["equipCsv"] = { parser = "EquipCsv", file = "csv/equip.csv" },
        ["battleSoulCsv"] = { parser = "BattleSoulCsv", file = "csv/zhanhun.csv" },
    }  
}

function ConfigLoader.loadCsv()
    for name, data in pairs(ConfigLoader.configs) do 
        _G[name] = require("csv." .. data.parser)
        _G[name]:load(data.file)
    end
end

return ConfigLoader