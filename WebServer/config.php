<?php

//Can be either 'ip' or 'steam'. When steam the user will need to authenticate its steam account before redirecting.
//Must be the same as in the gameserver.
$method = 'ip';

//In order to perform POST requests the client must server this value as auth parameter.
$auth = 'myrandomstring';

//Database information
$host = 'localhost';
$username = 'root';
$password = 'mypsw';
$dbname = 'hexredirect';
$port = 3306;

//Redirect when no url is found.
$homepage = 'https://www.google.com/';

//Timer after an URL is considered as expired.
$expire = 60;