<?php
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/../engine/ci/ModuleRegistry.php';
require_once __DIR__ . '/../engine/ci/Integrations.php';

$registry = new ModuleRegistry($config, cms_bootstrap_realms());
$registry->registerDefaults($auth_config);

$integrations = new IntegrationServices($config);

echo 'CI modules wired from configuration:' . PHP_EOL;
foreach ($registry->all() as $module)
{
	$missing = $module->validate();
	$status = count($missing) ? 'missing config: ' . implode(', ', $missing) : 'ready';
	echo '- ' . $module->getName() . ' => ' . $status . PHP_EOL;
}

echo PHP_EOL . 'Integration settings:' . PHP_EOL;
echo '- Captcha provider: ' . (isset($integrations->captchaConfig()['provider']) ? $integrations->captchaConfig()['provider'] : 'unset') . PHP_EOL;
echo '- Session driver: ' . (isset($integrations->sessionConfig()['driver']) ? $integrations->sessionConfig()['driver'] : 'unset') . PHP_EOL;
echo '- Social providers: ' . implode(', ', array_keys(isset($integrations->socialConfig()['providers']) ? $integrations->socialConfig()['providers'] : array())) . PHP_EOL;
echo '- Localization locales: ' . implode(', ', isset($integrations->localizationConfig()['available_locales']) ? $integrations->localizationConfig()['available_locales'] : array()) . PHP_EOL;
