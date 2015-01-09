local Map = class("Map", require("shared.ModelBase"))

function Map:ctor(properties)
	Map.super.ctor(self, properties)
end

Map.schema = {
    key     = {"string"},       -- redis key
    mapId   = {"number"},       -- 地图ID
    award1  = {"number", 0},    -- 奖励1
    award2 	= {"number", 0},	-- 奖励2
    award3 	= {"number", 0},	-- 奖励3
}   

Map.fields = {
	mapId = true, 
	award1 = true,
	award2 = true,
	award3 = true,
}

function Map:pbData()
	return {
		mapId = self:getProperty("mapId"),
		award1Status = self:getProperty("award1"), 
		award2Status = self:getProperty("award2"),
		award3Status = self:getProperty("award3"),
	}
end

return Map