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
  created_by       INT UNSIGNED NOT NULL,
  date_registered  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
  scanned_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_movements_document (document_id),
  KEY idx_movements_office (office_id),
  KEY idx_movements_user (user_id),
  KEY idx_movements_scanned_at (scanned_at),
  KEY idx_movements_dedupe (document_id, office_id, status, user_id, scanned_at),
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

INSERT IGNORE INTO offices (id, name, code) VALUES
  (1, 'Engineering Office', 'ENG'),
  (2, 'Human Resources Office', 'HR'),
  (3, 'Budget Office', 'BUD'),
  (4, 'Accounting Office', 'ACC'),
  (5, 'Municipal Treasury', 'TRE'),
  (6, 'Office of the Mayor', 'MAY');

SET FOREIGN_KEY_CHECKS = 1;

-- After import, seed pilot user accounts (no sample documents):
-- GET http://localhost/Smartflow/backend/backend/api/dev-seed-demo-users.php
-- Optional: remove legacy demo docs — dev-purge-demo-documents.php
--
-- Existing DBs: run backend/api/signup-migration.sql once for sign-up support.
