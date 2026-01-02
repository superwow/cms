<?php
require_once __DIR__ . '/../bootstrap.php';
require_once __DIR__ . '/../../engine/classes/audit_logger.php';

class WarcryEtl
{
	private $staging;
	private $realms;
	private $authConfig;
	private $audit;

	public function __construct(PDO $staging, array $realms, array $authConfig)
	{
		$this->staging = $staging;
		$this->realms = $realms;
		$this->authConfig = $authConfig;
		$this->audit = new AuditLogger($staging);
	}

	public function run($dumpPath)
	{
		$this->materializeRealms();

		if ($dumpPath)
		{
			$this->loadWarcryDump($dumpPath);
		}

		$this->syncAuthDatabase();
		$this->syncRealmDatabases();
		$this->recalculateAggregates();

		$this->audit->log(null, 'etl', 'warcry_completed', array('dump' => $dumpPath), 'cli');
	}

	private function materializeRealms()
	{
		foreach ($this->realms as $id => $realm)
		{
			$query = $this->staging->prepare("
				INSERT INTO realms (id, name, type, region, created_at)
				VALUES (:id, :name, :type, :region, NOW())
				ON DUPLICATE KEY UPDATE name = VALUES(name), type = VALUES(type), region = VALUES(region)
			");

			$query->execute(array(
				':id' => $id,
				':name' => isset($realm['name']) ? $realm['name'] : 'realm-' . $id,
				':type' => isset($realm['descr']) ? $realm['descr'] : null,
				':region' => isset($realm['region']) ? $realm['region'] : null
			));
		}
	}

	private function loadWarcryDump($zipPath)
	{
		if (!file_exists($zipPath))
		{
			throw new InvalidArgumentException('Dump file not found: ' . $zipPath);
		}

		$extractDir = sys_get_temp_dir() . '/warcry_etl';
		if (!is_dir($extractDir))
		{
			mkdir($extractDir, 0777, true);
		}

		$zip = new ZipArchive();
		if ($zip->open($zipPath) !== true)
		{
			throw new RuntimeException('Unable to open dump: ' . $zipPath);
		}

		$zip->extractTo($extractDir);
		$zip->close();

		$sqlFiles = glob($extractDir . '/*.sql');
		foreach ($sqlFiles as $sqlFile)
		{
			$this->importSqlFile($sqlFile);
		}
	}

	private function importSqlFile($path)
	{
		$content = file_get_contents($path);
		$statements = array_filter(array_map('trim', explode(';', $content)));

		$this->staging->beginTransaction();
		foreach ($statements as $statement)
		{
			if ($statement === '')
			{
				continue;
			}
			$this->staging->exec($statement);
		}
		$this->staging->commit();
	}

	private function syncAuthDatabase()
	{
		$authPdo = cms_bootstrap_pdo(array(
			'host' => $this->authConfig['DatabaseHost'],
			'user' => $this->authConfig['DatabaseUser'],
			'pass' => $this->authConfig['DatabasePass'],
			'name' => $this->authConfig['DatabaseName'],
			'encoding' => $this->authConfig['DatabaseEncoding']
		));

		if (!$this->tableExists($authPdo, 'account'))
		{
			return;
		}

		$this->staging->exec('SET NAMES utf8mb4');

		$this->staging->exec("
			INSERT INTO users (id, username, email, password_hash, status, created_at)
			SELECT a.id, a.username, a.email, a.sha_pass_hash, 'active', NOW()
			FROM " . $this->authConfig['DatabaseName'] . ".account a
			ON DUPLICATE KEY UPDATE email = VALUES(email), password_hash = VALUES(password_hash)
		");
	}

	private function syncRealmDatabases()
	{
		foreach ($this->realms as $realmId => $realmConfig)
		{
			if (!isset($realmConfig['Database']))
			{
				continue;
			}

			$db = $realmConfig['Database'];
			$realmPdo = cms_bootstrap_pdo(array(
				'host' => $db['host'],
				'user' => $db['user'],
				'pass' => $db['pass'],
				'name' => $db['name'],
				'encoding' => $db['encoding']
			));

			if ($this->tableExists($realmPdo, 'characters'))
			{
				$insert = $this->staging->prepare("
					INSERT INTO realm_stats (realm_id, metric, metric_value, measured_at)
					VALUES (:realm_id, 'characters', :metric_value, NOW())
					ON DUPLICATE KEY UPDATE metric_value = VALUES(metric_value), measured_at = VALUES(measured_at)
				");

				$count = $realmPdo->query("SELECT COUNT(*) AS cnt FROM characters")->fetch();
				$insert->execute(array(
					':realm_id' => $realmId,
					':metric_value' => isset($count['cnt']) ? $count['cnt'] : 0
				));
			}
		}
	}

	private function recalculateAggregates()
	{
		$this->staging->exec("
			INSERT INTO vote_counters (site_id, realm_id, total_votes)
			SELECT site_id, realm_id, COUNT(*) FROM votes GROUP BY site_id, realm_id
			ON DUPLICATE KEY UPDATE total_votes = VALUES(total_votes)
		");

		$walletBalance = $this->staging->query("SELECT COALESCE(SUM(balance),0) AS total FROM wallet_accounts")->fetch();
		$walletActivity = $this->staging->query("
			SELECT COALESCE(SUM(CASE WHEN direction='credit' THEN amount ELSE -amount END),0) AS total FROM wallet_activity
		")->fetch();

		$status = ($walletBalance['total'] == $walletActivity['total']) ? 'balanced' : 'mismatch';
		$this->audit->log(null, 'etl', 'wallet_validation', array(
			'balance_total' => $walletBalance['total'],
			'activity_total' => $walletActivity['total'],
			'status' => $status
		));
	}

	private function tableExists(PDO $pdo, $table)
	{
		$statement = $pdo->prepare("SHOW TABLES LIKE :table");
		$statement->execute(array(':table' => $table));
		$result = $statement->fetch();

		return $result !== false;
	}
}

function etlOptions()
{
	$options = array(
		'dump' => null,
		'staging-db' => null
	);

	foreach ($GLOBALS['argv'] as $arg)
	{
		if (strpos($arg, '--dump=') === 0)
		{
			$options['dump'] = substr($arg, strlen('--dump='));
		}
		if (strpos($arg, '--staging-db=') === 0)
		{
			$options['staging-db'] = substr($arg, strlen('--staging-db='));
		}
	}

	return $options;
}

$options = etlOptions();
$stagingDb = isset($options['staging-db']) && $options['staging-db'] !== '' ? $options['staging-db'] : $config['DatabaseName'];
$dump = isset($options['dump']) ? $options['dump'] : null;

$pdo = cms_bootstrap_pdo(array('name' => $stagingDb));

$etl = new WarcryEtl($pdo, cms_bootstrap_realms(), $auth_config);
$etl->run($dump);

echo "ETL completed for database {$stagingDb}" . PHP_EOL;
