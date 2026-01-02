-- Core user, security, and identity schema
CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    external_id VARCHAR(64) DEFAULT NULL,
    username VARCHAR(64) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    status ENUM('active','banned','pending','disabled') NOT NULL DEFAULT 'pending',
    locale VARCHAR(10) DEFAULT 'en',
    timezone VARCHAR(64) DEFAULT NULL,
    last_login_at DATETIME DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL,
    deleted_at DATETIME NULL DEFAULT NULL,
    INDEX idx_users_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS profiles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    display_name VARCHAR(120) NOT NULL,
    avatar_url VARCHAR(255) DEFAULT NULL,
    country_code CHAR(2) DEFAULT NULL,
    bio TEXT,
    locale VARCHAR(10) DEFAULT 'en',
    timezone VARCHAR(64) DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL,
    UNIQUE KEY uk_profiles_user (user_id),
    CONSTRAINT fk_profiles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS security_events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED DEFAULT NULL,
    realm_id VARCHAR(32) DEFAULT NULL,
    ip_address VARCHAR(45) DEFAULT NULL,
    user_agent VARCHAR(255) DEFAULT NULL,
    event_type VARCHAR(64) NOT NULL,
    payload JSON DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_security_events_user (user_id),
    INDEX idx_security_events_type (event_type),
    CONSTRAINT fk_security_events_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- RBAC
CREATE TABLE IF NOT EXISTS roles (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64) NOT NULL UNIQUE,
    description VARCHAR(255) DEFAULT NULL,
    is_system BOOLEAN NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS permissions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(96) NOT NULL UNIQUE,
    description VARCHAR(255) DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id INT UNSIGNED NOT NULL,
    permission_id INT UNSIGNED NOT NULL,
    granted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_roles (
    user_id BIGINT UNSIGNED NOT NULL,
    role_id INT UNSIGNED NOT NULL,
    assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by BIGINT UNSIGNED DEFAULT NULL,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_assigned FOREIGN KEY (assigned_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Audit logging & API tokens
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED DEFAULT NULL,
    scope VARCHAR(64) NOT NULL,
    action VARCHAR(96) NOT NULL,
    detail JSON DEFAULT NULL,
    ip_address VARCHAR(45) DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_scope (scope),
    INDEX idx_audit_user (user_id),
    CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS api_clients (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    contact VARCHAR(255) DEFAULT NULL,
    webhook_url VARCHAR(255) DEFAULT NULL,
    webhook_secret VARCHAR(128) DEFAULT NULL,
    active BOOLEAN NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS api_tokens (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    client_id INT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED DEFAULT NULL,
    token VARCHAR(128) NOT NULL UNIQUE,
    scopes JSON DEFAULT NULL,
    last_used_at DATETIME DEFAULT NULL,
    expires_at DATETIME DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at DATETIME DEFAULT NULL,
    INDEX idx_api_tokens_client (client_id),
    INDEX idx_api_tokens_user (user_id),
    CONSTRAINT fk_api_tokens_client FOREIGN KEY (client_id) REFERENCES api_clients(id) ON DELETE CASCADE,
    CONSTRAINT fk_api_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS api_token_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    token_id BIGINT UNSIGNED NOT NULL,
    http_method VARCHAR(8) NOT NULL,
    path VARCHAR(255) NOT NULL,
    response_code SMALLINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_api_token_logs_token FOREIGN KEY (token_id) REFERENCES api_tokens(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Wallet and payments
CREATE TABLE IF NOT EXISTS wallet_accounts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    realm_id VARCHAR(32) DEFAULT NULL,
    currency VARCHAR(8) NOT NULL DEFAULT 'USD',
    balance DECIMAL(14,2) NOT NULL DEFAULT 0,
    locked_balance DECIMAL(14,2) NOT NULL DEFAULT 0,
    status ENUM('active','suspended','closed') NOT NULL DEFAULT 'active',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL,
    INDEX idx_wallet_user (user_id),
    INDEX idx_wallet_realm (realm_id),
    CONSTRAINT fk_wallet_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS wallet_activity (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    wallet_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    realm_id VARCHAR(32) DEFAULT NULL,
    direction ENUM('credit','debit') NOT NULL,
    amount DECIMAL(14,2) NOT NULL,
    reference_type VARCHAR(64) DEFAULT NULL,
    reference_id VARCHAR(64) DEFAULT NULL,
    balance_after DECIMAL(14,2) NOT NULL,
    metadata JSON DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_wallet_activity_wallet (wallet_id),
    INDEX idx_wallet_activity_user (user_id),
    INDEX idx_wallet_activity_reference (reference_type, reference_id),
    CONSTRAINT fk_wallet_activity_wallet FOREIGN KEY (wallet_id) REFERENCES wallet_accounts(id) ON DELETE CASCADE,
    CONSTRAINT fk_wallet_activity_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS payments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    wallet_id BIGINT UNSIGNED NOT NULL,
    provider VARCHAR(64) NOT NULL,
    provider_ref VARCHAR(128) DEFAULT NULL,
    amount DECIMAL(14,2) NOT NULL,
    currency VARCHAR(8) NOT NULL DEFAULT 'USD',
    status ENUM('initiated','succeeded','failed','refunded') NOT NULL DEFAULT 'initiated',
    webhook_verified BOOLEAN NOT NULL DEFAULT 0,
    locale VARCHAR(10) DEFAULT 'en',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL,
    CONSTRAINT fk_payments_wallet FOREIGN KEY (wallet_id) REFERENCES wallet_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS payment_refunds (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    payment_id BIGINT UNSIGNED NOT NULL,
    amount DECIMAL(14,2) NOT NULL,
    reason VARCHAR(255) DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payment_refunds_payment FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS payment_webhooks (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    provider VARCHAR(64) NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    payload JSON NOT NULL,
    verified BOOLEAN NOT NULL DEFAULT 0,
    received_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at DATETIME DEFAULT NULL,
    signature VARCHAR(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Voting and recruit-a-friend
CREATE TABLE IF NOT EXISTS vote_sites (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    endpoint VARCHAR(255) NOT NULL,
    reward_points INT UNSIGNED NOT NULL DEFAULT 0,
    cooldown_seconds INT UNSIGNED NOT NULL DEFAULT 43200,
    locale VARCHAR(10) DEFAULT 'en'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS votes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    site_id INT UNSIGNED NOT NULL,
    realm_id VARCHAR(32) DEFAULT NULL,
    reward_points INT UNSIGNED NOT NULL DEFAULT 0,
    awarded_wallet_id BIGINT UNSIGNED DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_votes_user (user_id),
    INDEX idx_votes_site (site_id),
    CONSTRAINT fk_votes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_votes_site FOREIGN KEY (site_id) REFERENCES vote_sites(id) ON DELETE CASCADE,
    CONSTRAINT fk_votes_wallet FOREIGN KEY (awarded_wallet_id) REFERENCES wallet_accounts(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS vote_counters (
    site_id INT UNSIGNED NOT NULL,
    realm_id VARCHAR(32) DEFAULT NULL,
    total_votes BIGINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (site_id, realm_id),
    CONSTRAINT fk_vote_counters_site FOREIGN KEY (site_id) REFERENCES vote_sites(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS referrals (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    referrer_id BIGINT UNSIGNED NOT NULL,
    referee_id BIGINT UNSIGNED NOT NULL,
    realm_id VARCHAR(32) DEFAULT NULL,
    status ENUM('pending','validated','rewarded','expired') NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL,
    UNIQUE KEY uk_referrals_pair (referrer_id, referee_id),
    CONSTRAINT fk_referrals_referrer FOREIGN KEY (referrer_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_referrals_referee FOREIGN KEY (referee_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS referral_rewards (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    referral_id BIGINT UNSIGNED NOT NULL,
    wallet_activity_id BIGINT UNSIGNED DEFAULT NULL,
    reward_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_referral_rewards_referral FOREIGN KEY (referral_id) REFERENCES referrals(id) ON DELETE CASCADE,
    CONSTRAINT fk_referral_rewards_wallet_activity FOREIGN KEY (wallet_activity_id) REFERENCES wallet_activity(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Content and localization
CREATE TABLE IF NOT EXISTS content_items (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    slug VARCHAR(150) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    locale VARCHAR(10) NOT NULL DEFAULT 'en',
    translation_key VARCHAR(128) DEFAULT NULL,
    author_id BIGINT UNSIGNED DEFAULT NULL,
    published_at DATETIME DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL,
    CONSTRAINT fk_content_author FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS content_comments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    content_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED DEFAULT NULL,
    body TEXT NOT NULL,
    locale VARCHAR(10) DEFAULT 'en',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL,
    CONSTRAINT fk_content_comments_content FOREIGN KEY (content_id) REFERENCES content_items(id) ON DELETE CASCADE,
    CONSTRAINT fk_content_comments_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Forums
CREATE TABLE IF NOT EXISTS forums (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    slug VARCHAR(120) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    description VARCHAR(255) DEFAULT NULL,
    locale VARCHAR(10) DEFAULT 'en',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS forum_topics (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    forum_id INT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    locale VARCHAR(10) DEFAULT 'en',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL,
    CONSTRAINT fk_forum_topics_forum FOREIGN KEY (forum_id) REFERENCES forums(id) ON DELETE CASCADE,
    CONSTRAINT fk_forum_topics_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS forum_posts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    topic_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    body TEXT NOT NULL,
    locale VARCHAR(10) DEFAULT 'en',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL,
    CONSTRAINT fk_forum_posts_topic FOREIGN KEY (topic_id) REFERENCES forum_topics(id) ON DELETE CASCADE,
    CONSTRAINT fk_forum_posts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Bug tracking
CREATE TABLE IF NOT EXISTS bug_reports (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED DEFAULT NULL,
    realm_id VARCHAR(32) DEFAULT NULL,
    category VARCHAR(64) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    status ENUM('open','triaged','in_progress','resolved','closed') NOT NULL DEFAULT 'open',
    priority ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
    locale VARCHAR(10) DEFAULT 'en',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL DEFAULT NULL,
    CONSTRAINT fk_bug_reports_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bug_comments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    bug_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED DEFAULT NULL,
    body TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bug_comments_bug FOREIGN KEY (bug_id) REFERENCES bug_reports(id) ON DELETE CASCADE,
    CONSTRAINT fk_bug_comments_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Promotions
CREATE TABLE IF NOT EXISTS promo_codes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    description VARCHAR(255) DEFAULT NULL,
    reward_type VARCHAR(64) NOT NULL,
    reward_value VARCHAR(128) NOT NULL,
    locale VARCHAR(10) DEFAULT 'en',
    max_uses INT UNSIGNED DEFAULT NULL,
    expires_at DATETIME DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS promo_redemptions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    promo_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    wallet_activity_id BIGINT UNSIGNED DEFAULT NULL,
    redeemed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_promo_redemption (promo_id, user_id),
    CONSTRAINT fk_promo_redemptions_promo FOREIGN KEY (promo_id) REFERENCES promo_codes(id) ON DELETE CASCADE,
    CONSTRAINT fk_promo_redemptions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_promo_redemptions_wallet FOREIGN KEY (wallet_activity_id) REFERENCES wallet_activity(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Realms and stats
CREATE TABLE IF NOT EXISTS realms (
    id VARCHAR(32) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    type VARCHAR(64) DEFAULT NULL,
    region VARCHAR(32) DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS realm_stats (
    realm_id VARCHAR(32) NOT NULL,
    metric VARCHAR(64) NOT NULL,
    metric_value BIGINT NOT NULL DEFAULT 0,
    measured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (realm_id, metric, measured_at),
    CONSTRAINT fk_realm_stats_realm FOREIGN KEY (realm_id) REFERENCES realms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Password resets
CREATE TABLE IF NOT EXISTS password_resets (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    token VARCHAR(128) NOT NULL UNIQUE,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    consumed_at DATETIME DEFAULT NULL,
    CONSTRAINT fk_password_resets_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Sessions & localization friendly activity
CREATE TABLE IF NOT EXISTS user_sessions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    session_key VARCHAR(128) NOT NULL UNIQUE,
    ip_address VARCHAR(45) DEFAULT NULL,
    user_agent VARCHAR(255) DEFAULT NULL,
    locale VARCHAR(10) DEFAULT 'en',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user_sessions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Schema migrations registry
CREATE TABLE IF NOT EXISTS schema_migrations (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    database_name VARCHAR(128) DEFAULT NULL,
    applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_schema_migrations (name, database_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
