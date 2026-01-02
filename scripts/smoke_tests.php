<?php
require_once __DIR__ . '/bootstrap.php';

function tableExists(PDO $pdo, $table)
{
	$statement = $pdo->prepare("SHOW TABLES LIKE :table");
	$statement->execute(array(':table' => $table));
	return $statement->fetch() !== false;
}

$pdo = cms_bootstrap_pdo();

$results = array();

if (tableExists($pdo, 'users'))
{
	$count = $pdo->query("SELECT COUNT(*) AS cnt FROM users")->fetch();
	$results['auth'] = (int)$count['cnt'] >= 1 ? 'pass' : 'warn';
}

if (tableExists($pdo, 'payments'))
{
	$open = $pdo->query("SELECT COUNT(*) AS cnt FROM payments WHERE status IN ('initiated','succeeded')")->fetch();
	$results['payments'] = (int)$open['cnt'] >= 0 ? 'pass' : 'warn';
}

if (tableExists($pdo, 'votes') && tableExists($pdo, 'vote_counters'))
{
	$totalVotes = $pdo->query("SELECT COUNT(*) AS cnt FROM votes")->fetch();
	$totalCounters = $pdo->query("SELECT COALESCE(SUM(total_votes),0) AS cnt FROM vote_counters")->fetch();
	$results['voting'] = ((int)$totalVotes['cnt'] == (int)$totalCounters['cnt']) ? 'pass' : 'warn';
}

if (tableExists($pdo, 'forum_topics') && tableExists($pdo, 'forum_posts'))
{
	$topics = $pdo->query("SELECT COUNT(*) AS cnt FROM forum_topics")->fetch();
	$posts = $pdo->query("SELECT COUNT(*) AS cnt FROM forum_posts")->fetch();
	$results['forums'] = ((int)$posts['cnt'] >= (int)$topics['cnt']) ? 'pass' : 'warn';
}

if (tableExists($pdo, 'content_items'))
{
	$contentCount = $pdo->query("SELECT COUNT(*) AS cnt FROM content_items")->fetch();
	$results['content'] = (int)$contentCount['cnt'] >= 0 ? 'pass' : 'warn';
}

echo 'Smoke test summary:' . PHP_EOL;
foreach ($results as $key => $status)
{
	echo '- ' . $key . ': ' . $status . PHP_EOL;
}

echo PHP_EOL . 'Cutover plan:' . PHP_EOL;
echo "1. Enable read-only mode for user-facing transactions.\n";
echo "2. Apply migrations via scripts/migrations.php.\n";
echo "3. Run ETL: php scripts/etl/warcry_etl.php --dump=warcry.sql.zip --staging-db=" . $config['DatabaseName'] . "\n";
echo "4. Re-run smoke tests (this script) and verify wallet/vote counters align.\n";
echo "5. Lift read-only mode if checks pass; otherwise restore from backup and re-run ETL.\n";
