<?php
if (!defined('init_engine'))
{
	define('init_engine', true);
}

require_once __DIR__ . '/../configuration/config.php';

if (!isset($config['RootPath']) || $config['RootPath'] === '' || $config['RootPath'] === 'C:\xampp\htdocs')
{
	$config['RootPath'] = realpath(__DIR__ . '/..');
}

if (!isset($config['BaseURL']) || $config['BaseURL'] === 'http://sitename.com')
{
	$config['BaseURL'] = 'http://localhost';
}

if (!isset($PDO_config['errorHandler']))
{
	$PDO_config['errorHandler'] = PDO::ERRMODE_EXCEPTION;
}

if (!isset($PDO_config['fetch']))
{
	$PDO_config['fetch'] = PDO::FETCH_ASSOC;
}

function cms_bootstrap_pdo(array $override = array())
{
	global $config, $PDO_config;

	$settings = array(
		'host' => isset($config['DatabaseHost']) ? $config['DatabaseHost'] : 'localhost',
		'user' => isset($config['DatabaseUser']) ? $config['DatabaseUser'] : 'root',
		'pass' => isset($config['DatabasePass']) ? $config['DatabasePass'] : '',
		'name' => isset($config['DatabaseName']) ? $config['DatabaseName'] : '',
		'encoding' => isset($config['DatabaseEncoding']) ? $config['DatabaseEncoding'] : 'utf8'
	);

	foreach ($override as $key => $value)
	{
		$settings[$key] = $value;
	}

	$dsn = 'mysql:dbname=' . $settings['name'] . ';host=' . $settings['host'] . ';';
	$pdo = new PDO($dsn, $settings['user'], $settings['pass'], array());
	$pdo->setAttribute(PDO::ATTR_ERRMODE, $PDO_config['errorHandler']);
	$pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, $PDO_config['fetch']);
	$pdo->query("SET NAMES '" . $settings['encoding'] . "'");

	return $pdo;
}

function cms_bootstrap_realms()
{
	return isset($GLOBALS['realms_config']) ? $GLOBALS['realms_config'] : array();
}
