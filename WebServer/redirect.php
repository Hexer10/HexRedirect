<?php

require 'config.php';

/**** DON'T EDIT DOWN HERE ****/

$db = new mysqli($host, $username, $password, $dbname, $port);

if ($db->connect_errno) {

    echo 'Failed to make a MySQL connection: <br>' .
        'Errno: ' . $db->connect_errno . '<br>' .
        'Error: ' . $db->connect_error . '<br>';

    http_response_code(500);
    exit;
}
if (isset($_GET['token'])) {
	$token = $db->escape_string($_GET['token']);
	$url = $db->escape_string($_GET['url']);
	
	$sql = "INSERT INTO redirects (token, url, time)
				VALUES ('$token', '$url', UNIX_TIMESTAMP())
			ON DUPLICATE KEY UPDATE
				token = '$token',
				url = '$url',
				time = UNIX_TIMESTAMP()";
	
	if (!$result = $db->query($sql)) {
		echo 'Failed to perform a query: <br>' .
			'Errno: ' . $db->errno . '<br>' .
			'Error: ' . $db->error . '<br>';

		http_response_code(500);
		exit;
	}
} else {
	if ($method === 'ip') {
		$ipAddress = $_SERVER['REMOTE_ADDR'];
		if (array_key_exists('HTTP_X_FORWARDED_FOR', $_SERVER)) {
			$ipAddress = array_pop(explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']));
		}
		$sql = "SELECT url FROM redirects WHERE token = '$ipAddress' AND UNIX_TIMESTAMP() < time + $expire";

		if (!$result = $db->query($sql)) {
			echo 'Failed to perform a query: <br>' .
				'Errno: ' . $db->errno . '<br>' .
				'Error: ' . $db->error . '<br>';

			http_response_code(500);
			exit;
		}

		if ($result->num_rows === 0) {
			header("Location: {$homepage}");
			exit;
		}

		$result = $result->fetch_assoc();
		header("Location: {$result['url']}");
	} elseif ($method === 'steam') {
		session_start();
		if (isset($_SESSION['steamid'])) {
			$sql = "SELECT url FROM redirects WHERE token = {$_SESSION['steamid']} AND UNIX_TIMESTAMP() < time + $expire";

			if (!$result = $db->query($sql)) {
				echo 'Failed to perform a query: <br>' .
					'Errno: ' . $db->errno . '<br>' .
					'Error: ' . $db->error . '<br>';

				http_response_code(500);
				exit;
			}

			if ($result->num_rows === 0) {
				header("Location: {$homepage}");
				exit;
			}

			$result = $result->fetch_assoc();
			header("Location: {$result['url']}");
		} else {
			require_once 'openid.php';
			try {
				/** @noinspection PhpUndefinedClassInspection */
				$openid = new LightOpenID($_SERVER['HTTP_HOST']);
				$openid->identity = 'https://steamcommunity.com/openid';
				if (!$openid->mode) {
					$openid->identity = 'https://steamcommunity.com/openid';
					header('Location: ' . $openid->authUrl());

				} elseif ($openid->mode === 'cancel') {
					echo 'Authentication canceled!';

				} else if ($openid->validate()) {
					$id = $openid->identity;
					$ptn = "/^https?:\/\/steamcommunity\.com\/openid\/id\/(7[0-9]{15,25}+)$/";
					preg_match($ptn, $id, $matches);
					$_SESSION['steamid'] = $matches[1];

					$fullurl = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http') . "://$_SERVER[HTTP_HOST]$_SERVER[REQUEST_URI]";
					$url = strtok($fullurl, '?');

					echo("Location: {$url}");
					exit;

				} else {
					exit('Authentication failed!');
				}
			} catch (ErrorException $e) {
				exit("Error occured: $e");
			}
		}
	}
}