<?php
require 'config.php';

$db = new mysqli($host, $username, $password, $dbname, $port);

if ($db->connect_errno) {

    echo 'Failed to make a MySQL connection: <br>' .
        'Errno: ' . $db->connect_errno . '<br>' .
        'Error: ' . $db->connect_error . '<br>';

    http_response_code(500);
    exit;
}
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (empty($_POST['auth']) || $_POST['auth'] !== $auth) {
        http_response_code(401);
        exit;
    }

    if (empty($_POST['token']) || empty($_POST['url'])) {
        http_response_code(400);
        exit;
    }

    $stmt = $db->prepare('INSERT INTO redirects (token, url, time)
				VALUES (?, ?, UNIX_TIMESTAMP())
			ON DUPLICATE KEY UPDATE
				token = ?,
				url = ?,
				time = UNIX_TIMESTAMP()');

    $stmt->bind_param('ssss', $token, $url, $token, $url);
    $token = $_POST['token'];
    $url = $_POST['url'];

    if (!$stmt->execute()) {
        echo 'Failed to perform a query: <br>' .
            'Errno: ' . $stmt->errno . '<br>' .
            'Error: ' . $stmt->error . '<br>';

        http_response_code(500);
        exit;
    }

} else if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if ($method === 'ip') {
        $ipAddress = $_SERVER['REMOTE_ADDR'];
        if (array_key_exists('HTTP_X_FORWARDED_FOR', $_SERVER)) {
            $explode = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
            $ipAddress = array_pop($explode);
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
                header("Location: $homepage");
                exit;
            }

            $result = $result->fetch_assoc();
            header("Location: {$result['url']}");
        } else {
            require_once 'openid.php';
            try {
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