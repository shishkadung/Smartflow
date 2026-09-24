-- Run once if smartflow DB already exists without signup_requests.
USE smartflow;

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
