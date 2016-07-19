<?php

    $dirPath = dirname(__FILE__);
	include_once $dirPath . "/Common.php";

	# 去掉php运行时间限制
	set_time_limit(0);
	# 过滤notice以及deprecated错误
    error_reporting (E_ALL & ~E_NOTICE & ~E_DEPRECATED);

    date_default_timezone_set("Asia/Shanghai"); 

    # redis
    GRedisDB();
    global $redis;
    $redis->delete("towerrank");
    echo "remove today tower rank data\t" . time() . LRLF;
exit();