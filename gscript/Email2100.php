<?php

    $dirPath = dirname(__FILE__);
    include_once $dirPath . "/Common.php";

	# 去掉php运行时间限制
	set_time_limit(0);
	# 过滤notice以及deprecated错误
    error_reporting (E_ALL & ~E_NOTICE & ~E_DEPRECATED);

    date_default_timezone_set("Asia/Shanghai"); 

    # 获取时间戳
    $nowTime = isset($argv[1]) ? intval(strtotime($argv[1])) : time();

    # redis
    GRedisDB();
    global $redis;

    # 将读表删除，写表复制为读表，继续在写表上更新
    {
        $redis->delete("expedition:forceRank:r");
        $redis->zunion("expedition:forceRank:r", ["expedition:forceRank:w"]);
        $redis->delete("expedition:fightInfo:r");
        $temp = $redis->hgetall("expedition:fightInfo:w");
        $redis->hmset("expedition:fightInfo:r", $temp);
    }

    $sha1 = gen_sha1($dirPath . "/../gamescripts/redis_scripts/InsertEmail.lua");
    echo "start\t" . time() . LRLF;
    {
        echo "pvp rank award\t" . time() . LRLF;
        {
            $dict = load_rank_gift($dirPath . "/../csv/pvp_gift.csv");
            $len = $redis->lLen("pvp_rank");
            for ($i = 0; $i < $len; $i++) {
                $roleId = intval($redis->lIndex("pvp_rank", $i));
                if ($roleId > 10000) {
                    $emailId = get_email_id($dict, $i+1);
                    if ($emailId) RunScript($sha1, [$roleId, $emailId, $nowTime]);
                    // $emailId2 = get_temp_email_id("pvp_rank", $index+1);
                    // if ($emailId2) RunScript($sha1, [$roleId, $emailId2, $nowTime]);
                }
            }
        }
        echo "tower rank award\t" . time() . LRLF;
        {
            $dict = load_rank_gift($dirPath . "/../csv/tower_gift.csv");
            $range = $redis->zRevRange('towerrank', 0, 49);
            for ($i = 0; $i < count($range); $i++) {
                if ($range[$i] > 10000) {
                    $emailId = get_email_id($dict, $i+1);
                    if ($emailId) RunScript($sha1, [$range[$i], $emailId, $nowTime, $i+1]);
                }
            }
        }
        // echo "level&tower rank award\t" . time() . LRLF;
        // {
        //     $rankTbl = ["levelRank", "towerrank",];
        //     foreach ($rankTbl as $val) {
        //         $range = $redis->zRevRange($val, 0, 49, true);
        //         $i = 1;
        //         foreach ($range as $k => $v) {
        //             $emailId = get_temp_email_id($val, $i);
        //             if ($emailId) RunScript($sha1, [$k, $emailId, $nowTime]);
        //             $i++;
        //         }
        //     }
        // }        
    }
    echo "end\t" . time() . LRLF;
exit();

function load_rank_gift($fileName)
{
	$csvData = csv_to_array($fileName);
	$dict = [];
	foreach($csvData as $data) {
        $id = $data["段位id"];
		if ($id > 0) {
            $dict[$id]['up'] = $data["排名上限"];
            $dict[$id]['down'] = $data["排名下限"];
            $dict[$id]['emailId'] = $data["邮件id"];
        }
	}
	return $dict;
}

function get_email_id($dict, $rank)
{
    foreach($dict as $val) {
        if ($rank >= $val['up'] && $rank <= $val['down']) 
            return $val['emailId'];
    }
    return false;
}

// function lowerBoundSeach($keys, $rank)
// {
// 	sort($keys, SORT_NUMERIC);
//     $lastKey = 0;
// 	foreach ($keys as $val) {
// 		if ($rank < $val) 
//             break;	
//         $lastKey = $val;
// 	}
// 	return $lastKey != 0 ? $lastKey : end($keys);
// }

// function get_temp_email_id($rankType, $rank)
// {
//     $rankDict = ["levelRank"=>101, "pvp_rank"=>111, "towerrank"=>121,];
// 	$start = $rankDict[$rankType];
// 	if ($rank > 50 || !isset($start)) {
// 		return false;
// 	}
// 	if ($rank == 1) return $start;
// 	if ($rank == 2) return $start + 1;
// 	if ($rank == 3) return $start + 2;
// 	if ($rank >= 4 && $rank <= 10) return $start + 3;
// 	if ($rank >= 11 && $rank <= 20) return $start + 4;
// 	if ($rank >= 21 && $rank <= 50) return $start + 5;
// }
