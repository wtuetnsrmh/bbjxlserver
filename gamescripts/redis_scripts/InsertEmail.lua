local pm1 = KEYS[4] or ""
local pm2 = KEYS[5] or ""
local pm3 = KEYS[6] or ""

local roleInfo = redis.call("HGET", string.format("role:%d", KEYS[1]), "delete")

if tonumber(roleInfo) == 1 then return end

local id = redis.call("HINCRBY", "autoincrement_set", "email", 1)
redis.call("LPUSH", string.format("role:%d:emailIds", KEYS[1]), id)
local deleteIds = redis.call("LRANGE", string.format("role:%d:emailIds", KEYS[1]), 20, -1)
for _, deleteId in ipairs(deleteIds) do
	redis.call("DEL", string.format("email:%d:%d", KEYS[1], deleteId))
end

redis.call("LTRIM", string.format("role:%d:emailIds", KEYS[1]), 0, 19)
redis.call("HMSET", string.format("email:%d:%d", KEYS[1], id), "id", tostring(id), "emailId", KEYS[2],
	"status", "0", "createtime", KEYS[3], "pm1", pm1, "pm2", pm2, "pm3", pm3)
