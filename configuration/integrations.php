<?php
if (!defined('init_config'))
{	
	header('HTTP/1.0 404 not found');
	exit;
}

// Modernized integration settings for captcha, session handling, and social auth
$config['INTEGRATIONS'] = array(
	'captcha' => array(
		'provider' => 'hcaptcha',
		'site_key' => '',
		'secret_key' => '',
		'webhook_secret' => ''
	),
	'sessions' => array(
		'driver' => 'secure_filesystem',
		'cookie_samesite' => 'Lax',
		'cookie_secure' => true,
		'rotation_seconds' => 1800
	),
	'social' => array(
		'providers' => array(
			'discord' => array(
				'client_id' => '',
				'client_secret' => '',
				'redirect_uri' => ''
			),
			'google' => array(
				'client_id' => '',
				'client_secret' => '',
				'redirect_uri' => ''
			)
		)
	),
	'webhooks' => array(
		'signature_header' => 'X-WCW-Signature',
		'replay_window' => 300,
		'hmac_algorithm' => 'sha256',
		'webhook_secret' => ''
	),
	'localization' => array(
		'default_locale' => 'en',
		'available_locales' => array('en', 'de', 'fr', 'es', 'pt', 'ru')
	)
);
