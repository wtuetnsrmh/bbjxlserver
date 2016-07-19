local skynet = require "skynet"
local mysql = require "mysql"
local queue = require "skynet.queue"
require "logconstant"
require "shared.init"

local MAX_REC_SIZE = 5000
local CMD = {}
local recTbl = {}

local db, locker

local makeup_and_exec_sql = function(tbl, recs)
	local sql = "insert into " .. tbl .. "(" .. logActions[tbl].field .. ") values "
	sql = sql .. table.concat(recs, ",")
	local res = db:query(sql)		
	if res.badresult then
		skynet.error("ERR:", res.err)
		skynet.error("SQL:", sql)
	end
end

local loop = function()
	while true do
		locker(function ()
			if db then
				for tbl, recs in pairs(recTbl) do
					makeup_and_exec_sql(tbl, recs)
				end			
				recTbl = {}
			end
		end)
		skynet.sleep(100)
	end
end

local isstr = {r_name = true, d_id = true, str1 = true}
function CMD.log(tbl, msg)
	if not recTbl[tbl]  then recTbl[tbl] = {} end
	local tempstr = logActions[tbl].field
	local newstr, _ = string.gsub(tempstr, "[%w_]+", function(substr) return isstr[substr] and mysql.quote_sql_str(msg[substr]) or msg[substr] end)
	table.insert(recTbl[tbl], "(" .. newstr .. ")")
	if #recTbl >= MAX_REC_SIZE then
		skynet.error("too long", tbl)
		makeup_and_exec_sql(tbl, recTbl[tbl])
		recTbl[tbl] = {}
	end
end

function CMD.open(conf)
	db = mysql.connect{
		host = conf.mysqlhost,
		port = conf.mysqlport,
		database = conf.mysqlbase,
		user = conf.mysqluser,
		password = conf.mysqlpwd,
		max_packet_size = 1024 * 1024,
	}
	if not db then
		print "mysql connect error"
	end
	-- 指定连接字符集为utf8
	db:query("set names utf8")
end

skynet.start(function ()
	skynet.dispatch("lua", function (session, source, command, ...)
		local f = assert(CMD[string.lower(command)])
		if command == "open" then
			skynet.ret(skynet.pack(f(...)))
		else
			local tbl, msg = ...
			locker(function() f(tbl, msg) end)
		end
	end)
	locker = queue()
	skynet.fork(loop)
	skynet.register "LOGD"
end)