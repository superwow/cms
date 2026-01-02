<?php
if (!defined('init_engine'))
{
	define('init_engine', true);
}

class IntegrationServices
{
	private $config = array();

	public function __construct(array $config = array())
	{
		$this->config = $config;
	}

	public function captchaConfig()
	{
		return isset($this->config['INTEGRATIONS']['captcha']) ? $this->config['INTEGRATIONS']['captcha'] : array();
	}

	public function sessionConfig()
	{
		return isset($this->config['INTEGRATIONS']['sessions']) ? $this->config['INTEGRATIONS']['sessions'] : array();
	}

	public function socialConfig()
	{
		return isset($this->config['INTEGRATIONS']['social']) ? $this->config['INTEGRATIONS']['social'] : array();
	}

	public function webhookConfig()
	{
		return isset($this->config['INTEGRATIONS']['webhooks']) ? $this->config['INTEGRATIONS']['webhooks'] : array();
	}

	public function localizationConfig()
	{
		return isset($this->config['INTEGRATIONS']['localization']) ? $this->config['INTEGRATIONS']['localization'] : array();
	}

	public function verifyWebhook($payload, $signature, $timestamp)
	{
		$webhookConfig = $this->webhookConfig();
		if (!isset($webhookConfig['webhook_secret']) && !isset($webhookConfig['signature_header']))
		{
			return false;
		}

		$secret = isset($webhookConfig['webhook_secret']) ? $webhookConfig['webhook_secret'] : '';
		$allowedDrift = isset($webhookConfig['replay_window']) ? (int)$webhookConfig['replay_window'] : 300;
		$algo = isset($webhookConfig['hmac_algorithm']) ? $webhookConfig['hmac_algorithm'] : 'sha256';

		if ((time() - (int)$timestamp) > $allowedDrift)
		{
			return false;
		}

		$computed = hash_hmac($algo, $timestamp . '.' . $payload, $secret);
		return hash_equals($computed, $signature);
	}
}
