-- SmartFlow runtime schema for backend/api/*.php
-- (Practical capstone implementation — differs from thesis ERD in schema.sql)

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Shared hosting (InfinityFree, etc.): select your DB in phpMyAdmin first, then import.
-- Do not use CREATE DATABASE / USE here — the host assigns the database name.

CREATE TABLE IF NOT EXISTS offices (
  id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  code VARCHAR(10)  NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_offices_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS users (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name          VARCHAR(100) NOT NULL,
  username      VARCHAR(50)  NOT NULL,
  email         VARCHAR(120) NULL,
  password_hash VARCHAR(255) NOT NULL,
  office_id     INT UNSIGNED NOT NULL,
  role          VARCHAR(20)  NOT NULL DEFAULT 'staff',
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  avatar_path   VARCHAR(255) NULL,
  must_change_password     TINYINT(1) NOT NULL DEFAULT 0,
  temp_password_expires_at DATETIME   NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_username (username),
  UNIQUE KEY idx_users_email (email),
  KEY idx_users_office (office_id),
  CONSTRAINT fk_users_office FOREIGN KEY (office_id) REFERENCES offices (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS documents (
  id               VARCHAR(50)  NOT NULL,
  title            VARCHAR(200) NOT NULL,
  type             VARCHAR(50)  NOT NULL,
  origin_office_id INT UNSIGNED NOT NULL,
  description      TEXT         NULL,
  folder_inventory LONGTEXT NULL,
  qr_issued_at_unix BIGINT       NULL,
  created_by       INT UNSIGNED NOT NULL,
  date_registered  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  filed_at         DATETIME     NULL,
  filed_by         INT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY idx_documents_origin (origin_office_id),
  CONSTRAINT fk_documents_origin FOREIGN KEY (origin_office_id) REFERENCES offices (id),
  CONSTRAINT fk_documents_created_by FOREIGN KEY (created_by) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS movements (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  document_id VARCHAR(50)  NOT NULL,
  office_id   INT UNSIGNED NOT NULL,
  destination_office_id INT UNSIGNED NULL DEFAULT NULL,
  status      VARCHAR(10)  NOT NULL,
  user_id     INT UNSIGNED NOT NULL,
  remarks     TEXT         NULL,
  contents_receipt LONGTEXT NULL,
  scanned_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_movements_document (document_id),
  KEY idx_movements_office (office_id),
  KEY idx_movements_destination (destination_office_id),
  KEY idx_movements_user (user_id),
  KEY idx_movements_scanned_at (scanned_at),
  KEY idx_movements_dedupe (document_id, office_id, status, user_id, scanned_at),
  KEY idx_movements_latest (document_id, scanned_at, id),
  KEY idx_movements_receipt (document_id, status, scanned_at, id),
  KEY idx_movements_office_time (office_id, scanned_at, id),
  CONSTRAINT fk_movements_document FOREIGN KEY (document_id) REFERENCES documents (id),
  CONSTRAINT fk_movements_office   FOREIGN KEY (office_id)   REFERENCES offices (id),
  CONSTRAINT fk_movements_user     FOREIGN KEY (user_id)     REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS audit_logs (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  event_type    VARCHAR(64)     NOT NULL,
  document_id   VARCHAR(50)     NULL,
  user_id       INT UNSIGNED    NULL,
  office_id     INT UNSIGNED    NULL,
  status        VARCHAR(10)     NULL,
  outcome       VARCHAR(20)     NOT NULL,
  message       VARCHAR(255)    NOT NULL,
  meta_json     JSON            NULL,
  ip_address    VARCHAR(45)     NULL,
  user_agent    VARCHAR(255)    NULL,
  created_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_audit_event_created (event_type, created_at),
  KEY idx_audit_document (document_id, created_at),
  KEY idx_audit_user (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS signup_requests (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  request_code    VARCHAR(20)  NOT NULL,
  full_name       VARCHAR(100) NOT NULL,
  username        VARCHAR(50)  NOT NULL,
  email           VARCHAR(120) NOT NULL,
  password_hash   VARCHAR(255) NOT NULL,
  office_id       INT UNSIGNED NOT NULL,
  requested_role  VARCHAR(20)  NOT NULL DEFAULT 'staff',
  status          ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  approved_by     INT UNSIGNED NULL,
  approved_at     DATETIME     NULL,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_signup_username (username),
  UNIQUE KEY uk_signup_code (request_code),
  KEY idx_signup_status (status),
  CONSTRAINT fk_signup_office FOREIGN KEY (office_id) REFERENCES offices (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Office checklists contain requirements, never assumed physical page counts.
CREATE TABLE IF NOT EXISTS folder_checklists (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  office_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  document_type VARCHAR(150) NOT NULL,
  items_json LONGTEXT NOT NULL,
  updated_by INT NOT NULL,
  is_active TINYINT NOT NULL DEFAULT 1,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX checklist_office (office_id, is_active)
) ENGINE=InnoDB;

-- Movement and outcome are committed together; cancelled IDs block late writes.
CREATE TABLE IF NOT EXISTS movement_requests (
  request_id CHAR(32) NOT NULL PRIMARY KEY,
  user_id INT NOT NULL,
  document_id VARCHAR(50) NOT NULL,
  body_hash CHAR(64) NULL,
  state VARCHAR(12) NOT NULL,
  response_json LONGTEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX movement_request_owner (user_id, created_at)
) ENGINE=InnoDB;

INSERT IGNORE INTO offices (id, name, code) VALUES
  (1, 'Engineering Office', 'ENG'),
  (2, 'Human Resources Office', 'HR'),
  (3, 'Budget Office', 'BUD'),
  (4, 'Accounting Office', 'ACC'),
  (5, 'Municipal Treasury', 'TRE'),
  (6, 'Office of the Mayor', 'MAY');

SET FOREIGN_KEY_CHECKS = 1;

-- HTTP maintenance endpoints are disabled. Never seed or purge the working database.
-- Use scripts/test-request-linking.php for disposable sample accounts and folders.
-- Deliberate CLI maintenance requires a verified target and explicit non-production opt-in.
--
-- Existing DBs: run backend/api/signup-migration.sql once for sign-up support.
