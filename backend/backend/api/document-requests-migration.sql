-- Run once: document request module (inter-office requests + routing).
-- mysql smartflow < document-requests-migration.sql

USE smartflow;

CREATE TABLE IF NOT EXISTS document_requests (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  request_code        VARCHAR(24)  NOT NULL,
  request_kind        ENUM('access','pull') NOT NULL DEFAULT 'access',
  document_category   VARCHAR(30)  NOT NULL,
  requested_by        INT UNSIGNED NOT NULL,
  requester_office_id INT UNSIGNED NOT NULL,
  requester_role      VARCHAR(20)  NOT NULL,
  handler_office_id   INT UNSIGNED NOT NULL,
  target_office_id    INT UNSIGNED NULL,
  purpose             TEXT         NOT NULL,
  related_document_id VARCHAR(50)  NULL,
  status              ENUM('pending','approved','rejected','fulfilled','cancelled')
                      NOT NULL DEFAULT 'pending',
  reviewed_by         INT UNSIGNED NULL,
  reviewed_at         DATETIME     NULL,
  review_notes        TEXT         NULL,
  fulfilled_at        DATETIME     NULL,
  created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_dr_code (request_code),
  KEY idx_dr_handler_status (handler_office_id, status),
  KEY idx_dr_requester (requested_by),
  KEY idx_dr_created (created_at),
  CONSTRAINT fk_dr_requester FOREIGN KEY (requested_by) REFERENCES users (id),
  CONSTRAINT fk_dr_requester_office FOREIGN KEY (requester_office_id) REFERENCES offices (id),
  CONSTRAINT fk_dr_handler_office FOREIGN KEY (handler_office_id) REFERENCES offices (id),
  CONSTRAINT fk_dr_target_office FOREIGN KEY (target_office_id) REFERENCES offices (id),
  CONSTRAINT fk_dr_reviewed_by FOREIGN KEY (reviewed_by) REFERENCES users (id),
  CONSTRAINT fk_dr_document FOREIGN KEY (related_document_id) REFERENCES documents (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
