<?php
if (!defined('init_engine'))
{
	define('init_engine', true);
}

require_once __DIR__ . '/Module.php';

class ModuleRegistry
{
	private $modules = array();
	private $config = array();
	private $realms = array();

	public function __construct(array $config = array(), array $realms = array())
	{
		$this->config = $config;
		$this->realms = $realms;
	}

	public function register(Module $module)
	{
		$this->modules[$module->getName()] = $module;
	}

	public function all()
	{
		return $this->modules;
	}

	public function registerDefaults($authConfig)
	{
		$this->register(new Module('auth', array(
			'database' => isset($authConfig['DatabaseName']) ? $authConfig['DatabaseName'] : null,
			'host' => isset($authConfig['DatabaseHost']) ? $authConfig['DatabaseHost'] : null,
			'user' => isset($authConfig['DatabaseUser']) ? $authConfig['DatabaseUser'] : null,
			'encoding' => isset($authConfig['DatabaseEncoding']) ? $authConfig['DatabaseEncoding'] : null
		)));

		$this->register(new Module('users', array(
			'database' => isset($this->config['DatabaseName']) ? $this->config['DatabaseName'] : null,
			'host' => isset($this->config['DatabaseHost']) ? $this->config['DatabaseHost'] : null
		)));

		$this->register(new Module('wallet', array(
			'database' => isset($this->config['DatabaseName']) ? $this->config['DatabaseName'] : null,
			'providers' => array('coins', 'credits')
		), $this->realms));

		$this->register(new Module('payments', array(
			'paypal_notify' => isset($this->config['payments']['paypal']['notify_url']) ? $this->config['payments']['paypal']['notify_url'] : null,
			'paypal_email' => isset($this->config['payments']['paypal']['email']) ? $this->config['payments']['paypal']['email'] : null
		)));

		$this->register(new Module('voting', array(
			'sites' => isset($this->config['VoteSites']) ? $this->config['VoteSites'] : array(),
			'limits' => isset($this->config['VoteLimit']) ? $this->config['VoteLimit'] : null
		), $this->realms));

		$this->register(new Module('referrals', array(
			'raf_reward' => isset($this->config['RAF_reward']) ? $this->config['RAF_reward'] : null
		), $this->realms));

		$this->register(new Module('content', array(
			'locales' => isset($this->config['INTEGRATIONS']['localization']['available_locales']) ? $this->config['INTEGRATIONS']['localization']['available_locales'] : array('en')
		)));

		$this->register(new Module('forums', array(
			'limits' => isset($this->config['FORUM']) ? $this->config['FORUM'] : array()
		)));

		$this->register(new Module('bugtracker', array(
			'categories' => array('quests', 'class', 'items', 'ui', 'performance')
		), $this->realms));

		$this->register(new Module('promo', array(
			'currency' => isset($this->config['payments']['paypal']['currecy']) ? $this->config['payments']['paypal']['currecy'] : 'USD'
		)));

		$this->register(new Module('realms', array(
			'configured' => $this->realms
		)));

		$this->register(new Module('admin/rbac', array(
			'roles' => array('admin', 'moderator', 'staff'),
			'permissions' => array('users.manage', 'payments.refund', 'content.publish', 'forums.moderate')
		)));
	}
}
