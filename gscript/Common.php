<?php
	
	$redisConfig = [			
		'host'     => '127.0.0.1',
		'port'     => 6379,
		'database' => 0,
		'password' => "",
	];

	define('LRLF', "\r\n");

	global $redisConfig, $redis;

	function GRedisDB () 
	{
		global $redisConfig, $redis;
		$redis = new Redis();
		$isConn = $redis->pconnect($redisConfig['host'], $redisConfig['port']);
		if (!$isConn) {
			echo "error connect redis server" . LRLF;
			exit();
		}
		if (strlen($redisConfig['password']) > 0) {
			$redis->auth($redisConfig['password']);
		}
		$redis->select($redisConfig['database']);
	}

    function gen_sha1($fileName) 
    {
    	global $redis;
        $handle = fopen($fileName, 'r');
        $contents = fread($handle, filesize($fileName));
        fclose($handle);
        return $redis->script('load', $contents);
    }

    function RunScript($sha1, $params) 
    {
    	global $redis;
    	return $redis->evalSha($sha1, $params, count($params));
    }

    function csv_to_array($filename='', $delimiter=',')
	{
		if(!file_exists($filename) || !is_readable($filename))
			return FALSE;
		
		$header = NULL;
		$data = array();
		if (($handle = fopen($filename, 'r')) !== FALSE) {
			while (($row = fgetcsv($handle, 4000, $delimiter)) !== FALSE) {
				if(!$header)
					$header = $row;
				else
					$data[] = array_combine($header, $row);
			}
			fclose($handle);
		}
		return $data;
	}
?>