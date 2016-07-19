local Carbon = class("Carbon", require("shared.ModelBase"))

function Carbon:ctor(properties)
	Carbon.super.ctor(self, properties)
	require("shared.EventProtocol").extend(self)
end

Carbon.schema = {
    key     = {"string"},       -- redis key
    id 		= {"number"},      	-- id 存储用户 ID
    mapId   = {"number"},       -- 地图ID
    starNum = {"number", 0},    -- 星级评定
    status  = {"number", 0},    -- 完成状态
    playCnt = {"number", 0},	-- 挑战次数
    lastPlayTime = {"number", 0},	-- 上次挑战时间
    buyCnt 	= {"number", 0}		-- 重置次数
}   

Carbon.fields = {
	id = true, 
	starNum = true, 
	status = true,
	playCnt = true,
	lastPlayTime = true,
	buyCnt = true,
}

function Carbon:pbData()
	return {
		carbonId = self:getProperty("id"),
		starNum = self:getProperty("starNum"), 
		status = self:getProperty("status"),
		playCnt = self:getProperty("playCnt"),
		buyCnt = self:getProperty("buyCnt"),
	}
end

return Carbon