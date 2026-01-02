<?php
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/../engine/ci/ModuleRegistry.php';
require_once __DIR__ . '/../engine/classes/audit_logger.php';

class MigrationRunner
{
	private $pdo;
	private $databaseName;

	public function __construct(PDO $pdo, $databaseName)
	{
		$this->pdo = $pdo;
		$this->databaseName = $databaseName;
		$this->ensureMigrationsTable();
	}

	private function ensureMigrationsTable()
	{
		$this->pdo->exec("
			CREATE TABLE IF NOT EXISTS schema_migrations (
				id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
				name VARCHAR(255) NOT NULL,
				database_name VARCHAR(128) DEFAULT NULL,
				applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
				UNIQUE KEY uk_schema_migrations (name, database_name)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
		");
	}

	private function alreadyApplied($name)
	{
		$query = $this->pdo->prepare("SELECT COUNT(*) AS cnt FROM schema_migrations WHERE name = :name AND database_name = :db");
		$query->execute(array(':name' => $name, ':db' => $this->databaseName));
		$result = $query->fetch();

		return isset($result['cnt']) && $result['cnt'] > 0;
	}

	private function markApplied($name)
	{
		$query = $this->pdo->prepare("
			INSERT INTO schema_migrations (name, database_name, applied_at)
			VALUES (:name, :db, NOW())
		");
		$query->execute(array(':name' => $name, ':db' => $this->databaseName));
	}

	public function applyDirectory($path)
	{
		$files = glob($path . '/*.sql');
		sort($files);

		foreach ($files as $file)
		{
			$name = basename($file);
			if ($this->alreadyApplied($name))
			{
				continue;
			}

			$sql = file_get_contents($file);
			$statements = array_filter(array_map('trim', explode(';', $sql)));

			$this->pdo->beginTransaction();
			foreach ($statements as $statement)
			{
				if ($statement === '')
				{
					continue;
				}
				$this->pdo->exec($statement);
			}
			$this->markApplied($name);
			$this->pdo->commit();
			echo 'Applied migration: ' . $name . PHP_EOL;
		}
	}
}

function parseOptions()
{
	$options = array(
		'database' => null
	);

	foreach ($GLOBALS['argv'] as $arg)
	{
		if (strpos($arg, '--database=') === 0)
		{
			$options['database'] = substr($arg, strlen('--database='));
		}
	}

	return $options;
}

$options = parseOptions();
$databaseName = isset($options['database']) && $options['database'] !== '' ? $options['database'] : $config['DatabaseName'];

$pdo = cms_bootstrap_pdo(array('name' => $databaseName));
$runner = new MigrationRunner($pdo, $databaseName);
$runner->applyDirectory(__DIR__ . '/../database/migrations');

$audit = new AuditLogger($pdo);
$audit->log(null, 'migrations', 'apply', array('database' => $databaseName), 'cli');

$registry = new ModuleRegistry($config, cms_bootstrap_realms());
$registry->registerDefaults($auth_config);

echo 'Registered modules after migrations: ' . PHP_EOL;
foreach ($registry->all() as $module)
{
	$missing = $module->validate();
	echo '- ' . $module->getName() . (count($missing) ? ' (missing: ' . implode(', ', $missing) . ')' : ' (ready)') . PHP_EOL;
}
