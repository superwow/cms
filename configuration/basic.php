<?php
if (!defined('init_config'))
{	
	header('HTTP/1.0 404 not found');
	exit;
}

$config['SiteName'] = 'sitenamehere';

$config['RootPath'] = 'C:\xampp\htdocs'; 		//(No slash at the end)
$config['BaseURL'] = 'http://sitename.com'; 	//(No slash at the end)

//Must be unique for each website
$config['AuthCookieName'] = 'sitename';

//Minifier Settings
//StyleFolderURL rewrites the URLs for the image in the CSS files
$config['StyleFolderURL'] = 'http://sitename.com/template/style/'; //(With slash at the end)

//E-mail Address
$config['Email'] = 'info@localhost';

//Time settings
$config['TimeZone'] = 'Europe/Berlin';
$config['TimeZoneOffset'] = '+1';

//Warcry WoW Database URL
$config['WoWDB_URL'] = 'http://ip or url';	//(No slash at the end)
//Complete URL to the power.js
$config['WoWDB_JS'] = 'http://ip or url/power.js';