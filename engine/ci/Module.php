<?php
if (!defined('init_engine'))
{
	define('init_engine', true);
}

class Module
{
	private $name;
	private $config;
	private $realms;

	public function __construct($name, array $config = array(), array $realms = array())
	{
		$this->name = $name;
		$this->config = $config;
		$this->realms = $realms;
	}

	public function getName()
	{
		return $this->name;
	}

	public function toArray()
	{
		return array(
			'name' => $this->name,
			'config' => $this->config,
			'realms' => $this->realms
		);
	}

	public function validate()
	{
		$missing = array();
		foreach ($this->config as $key => $value)
		{
			if ($value === '' || $value === null)
			{
				$missing[] = $key;
			}
		}

		return $missing;
	}
}
