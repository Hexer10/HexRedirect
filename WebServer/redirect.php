<?php
/**** EDIT HERE ****/

//Can be either 'ip' or 'steam'. When steam the user will need to authenticate its steam account before redirecting.
//Must be the same as in the gameserver.
$method = 'steam';

$host = 'localhost';
$username = 'root';
$password = 'mypsw';
$dbname = 'hexredirect';
$port = 3306;

//Redirect when no url is found.
$homepage = 'https://www.google.com/';

//Timer after an URL is considered as expired.
$expire = 60;

//Set to 1 to display errors
define('DEV_MODE', 0);

if (DEV_MODE === 1) {
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
}
?>
<html>
<head>
    <style>
        body {
            background-color: white;
        }
    </style>
</head>
<body>
<?php

/**** DON'T EDIT DOWN HERE ****/

$db = new mysqli($host, $username, $password, $dbname, $port);

if ($db->connect_errno) {

    echo 'Failed to make a MySQL connection: <br>' .
        'Errno: ' . $db->connect_errno . '<br>' .
        'Error: ' . $db->connect_error . '<br>';

    http_response_code(500);
    exit;
}

if ($method === 'ip') {
    $sql = "SELECT time,url FROM redirects WHERE token = '{$_SERVER['REMOTE_ADDR']}'";

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

    date_default_timezone_set('Europe/London');

    $result = $result->fetch_assoc();
    $time = strtotime($result['time']);

    if (time() < $time + $expire) {
        header("Location: {$result['url']}");
        exit;
    }

    header("Location: {$homepage}");
} elseif ($method === 'steam') {
    session_start();
    if ($_SESSION['steamid']) {
        $sql = "SELECT time,url FROM redirects WHERE token = {$_SESSION['steamid']}";

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

        date_default_timezone_set('Europe/London');

        $result = $result->fetch_assoc();
        $time = strtotime($result['time']);

        if (time() < $time + $expire) {
            header("Location: {$result['url']}");
            exit;
        }

        header("Location: {$homepage}");
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

                header("Location: $url");
                exit;

            } else {
                exit('Authentication failed!');
            }
        } catch (ErrorException $e) {
            exit("Error occured: $e");
        }
    }
}
?>
</body>
</html>
