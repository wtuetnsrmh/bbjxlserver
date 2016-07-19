local skynet = require "skynet"
local syslog = require "syslog"

local command = {}

function command.close()
	syslog.closelog()
end

function command.debug(msg)
	syslog.syslog("LOG_DEBUG", msg)
end

function command.info(msg)
	syslog.syslog("LOG_INFO", msg)
end

function command.notice(msg)
	syslog.syslog("LOG_NOTICE", msg)
end

function command.warning(msg)
	syslog.syslog("LOG_WARNING", msg)
end

function command.error(msg)
	syslog.syslog("LOG_ERR", msg)
end

function command.crit(msg)
	syslog.syslog("LOG_CRIT", msg)
end

function command.alert(msg)
	syslog.syslog("LOG_ALERT", msg)
end

function command.emerg(msg)
	syslog.syslog("LOG_EMERG", msg)
end

skynet.start(function()
	syslog.openlog("luanwusanguo", syslog.LOG_PERROR + syslog.LOG_ODELAY, "LOG_LOCAL7")

	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = command[string.lower(cmd)]
		f(...)
	end)
	skynet.register "LOGGER"	
end)