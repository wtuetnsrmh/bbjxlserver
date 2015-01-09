<?php

    $dirPath = dirname(__FILE__);
	include_once $dirPath . "/Common.php";

	# 去掉php运行时间限制
	set_time_limit(0);
	# 过滤notice以及deprecated错误
    error_reporting (E_ALL & ~E_NOTICE & ~E_DEPRECATED);

    date_default_timezone_set("Asia/Shanghai"); 
    # 获取时间戳
    /*
    $nowTime = isset($argv[1]) ? intval(strtotime($argv[1])) : time();
    # redis
    GRedisDB();
    global $redis;
    # 最大角色id
    $maxRoleId = $redis->hget('autoincrement_set', 'role');
    $sha1 = gen_sha1($dirPath . "/../gamescripts/redis_scripts/InsertEmail.lua");

    echo "start\t" . time() . LRLF;
    echo "openserv award\t" . time() . LRLF;
    $openserv = $redis->hget("autoincrement_set", "server_start");
    {
    	$emailIds = [1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,];
    	$dayTime = strtotime(date('Ymd', $nowTime));
    	$openTime = strtotime($openserv);
    	$day = ($dayTime - $openTime) / 86400;
    	if (array_key_exists($day, $emailIds)) {
    		for ($roleId = 10001; $roleId <= $maxRoleId; $roleId++) {
    			RunScript($sha1, [$roleId, $emailIds[$day], $nowTime]);
    		}
    	}
    }
    echo "vip award\t" . time() . LRLF;
    {
        $emailIds = [1101,1102,1103,1104,1105,1106,1107,1108,1109,1110,];
        $dayTime = strtotime(date('Ymd', $nowTime));
        $openTime = strtotime($openserv);
        $day = ($dayTime - $openTime) / 86400;
        if (array_key_exists($day, $emailIds)) {
            for ($roleId = 10001; $roleId <= $maxRoleId; $roleId++) {
                RunScript($sha1, [$roleId, $emailIds[$day], $nowTime]);
            }
        }
    }    
    echo "end\t" . time() . LRLF;
exit();