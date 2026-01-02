<?php
if (!defined('init_engine'))
{
	define('init_engine', true);
}

class AuditLogger
{
	private $pdo;

	public function __construct(PDO $pdo)
	{
		$this->pdo = $pdo;
	}

	public function log($userId, $scope, $action, array $detail = array(), $ip = null)
	{
		$query = $this->pdo->prepare("
			INSERT INTO audit_logs (user_id, scope, action, detail, ip_address, created_at)
			VALUES (:user_id, :scope, :action, :detail, :ip_address, NOW())
		");

		$query->execute(array(
			':user_id' => $userId,
			':scope' => $scope,
			':action' => $action,
			':detail' => json_encode($detail),
			':ip_address' => $ip
		));
	}
}
