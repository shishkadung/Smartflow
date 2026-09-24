-- SmartFlow — MySQL schema (Municipality of Urbiztondo)
-- Matches Figure 2-6 / docs/chapter 2/erd.md
-- Engine: InnoDB · Charset: utf8mb4

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS roles (
  role_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  role_name   VARCHAR(50)  NOT NULL,
  PRIMARY KEY (role_id),
  UNIQUE KEY uk_roles_name (role_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS offices (
  office_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  office_name VARCHAR(100) NOT NULL,
  PRIMARY KEY (office_id),
  UNIQUE KEY uk_offices_name (office_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS users (
  user_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  username      VARCHAR(50)  NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  full_name     VARCHAR(100) NOT NULL,
  office_id     INT UNSIGNED NOT NULL,
  role_id       INT UNSIGNED NOT NULL,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (user_id),
  UNIQUE KEY uk_users_username (username),
  KEY idx_users_office (office_id),
  KEY idx_users_role (role_id),
  CONSTRAINT fk_users_office FOREIGN KEY (office_id) REFERENCES offices (office_id),
  CONSTRAINT fk_users_role   FOREIGN KEY (role_id)   REFERENCES roles (role_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS document_types (
  type_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  type_name VARCHAR(50)  NOT NULL,
  PRIMARY KEY (type_id),
  UNIQUE KEY uk_document_types_name (type_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS documents (
  document_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tracking_code     VARCHAR(50)  NOT NULL,
  type_id           INT UNSIGNED NOT NULL,
  reference_no      VARCHAR(100) NULL,
  origin_office_id  INT UNSIGNED NOT NULL,
  current_office_id INT UNSIGNED NOT NULL,
  status            VARCHAR(30)  NOT NULL DEFAULT 'active',
  created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at      DATETIME     NULL,
  PRIMARY KEY (document_id),
  UNIQUE KEY uk_documents_tracking (tracking_code),
  KEY idx_documents_type (type_id),
  KEY idx_documents_origin (origin_office_id),
  KEY idx_documents_current (current_office_id),
  KEY idx_documents_status (status),
  CONSTRAINT fk_documents_type    FOREIGN KEY (type_id)           REFERENCES document_types (type_id),
  CONSTRAINT fk_documents_origin  FOREIGN KEY (origin_office_id)  REFERENCES offices (office_id),
  CONSTRAINT fk_documents_current FOREIGN KEY (current_office_id) REFERENCES offices (office_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS scan_logs (
  scan_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  document_id INT UNSIGNED NOT NULL,
  office_id   INT UNSIGNED NOT NULL,
  user_id     INT UNSIGNED NOT NULL,
  action      VARCHAR(20)  NOT NULL,
  scanned_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  remarks     TEXT         NULL,
  PRIMARY KEY (scan_id),
  KEY idx_scan_logs_document (document_id),
  KEY idx_scan_logs_office (office_id),
  KEY idx_scan_logs_user (user_id),
  KEY idx_scan_logs_scanned_at (scanned_at),
  CONSTRAINT fk_scan_logs_document FOREIGN KEY (document_id) REFERENCES documents (document_id),
  CONSTRAINT fk_scan_logs_office   FOREIGN KEY (office_id)   REFERENCES offices (office_id),
  CONSTRAINT fk_scan_logs_user   FOREIGN KEY (user_id)     REFERENCES users (user_id),
  CONSTRAINT chk_scan_logs_action CHECK (action IN ('receive', 'forward'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS thresholds (
  threshold_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  office_id         INT UNSIGNED NOT NULL,
  document_type_id  INT UNSIGNED NOT NULL,
  max_hours         INT UNSIGNED NOT NULL,
  is_active         TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (threshold_id),
  UNIQUE KEY uk_thresholds_office_type (office_id, document_type_id),
  CONSTRAINT fk_thresholds_office FOREIGN KEY (office_id)        REFERENCES offices (office_id),
  CONSTRAINT fk_thresholds_type   FOREIGN KEY (document_type_id) REFERENCES document_types (type_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS alerts (
  alert_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  document_id  INT UNSIGNED NOT NULL,
  office_id    INT UNSIGNED NOT NULL,
  triggered_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_resolved  TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (alert_id),
  KEY idx_alerts_document (document_id),
  KEY idx_alerts_office (office_id),
  KEY idx_alerts_resolved (is_resolved),
  CONSTRAINT fk_alerts_document FOREIGN KEY (document_id) REFERENCES documents (document_id),
  CONSTRAINT fk_alerts_office   FOREIGN KEY (office_id)   REFERENCES offices (office_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- Seed data (pilot)
INSERT INTO roles (role_name) VALUES
  ('admin'), ('accountant'), ('head'), ('clerk')
ON DUPLICATE KEY UPDATE role_name = VALUES(role_name);

INSERT INTO offices (office_name) VALUES
  ('Engineering'), ('Human Resources'), ('Budget'), ('Accounting')
ON DUPLICATE KEY UPDATE office_name = VALUES(office_name);

INSERT INTO document_types (type_name) VALUES
  ('Disbursement Voucher'), ('Payroll Record'), ('Approved Budget')
ON DUPLICATE KEY UPDATE type_name = VALUES(type_name);
