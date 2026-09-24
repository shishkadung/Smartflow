-- Optional manual run. Thresholds auto-create on first API call via thresholds-helper.php.
USE smartflow;

CREATE TABLE IF NOT EXISTS processing_thresholds (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  office_id INT UNSIGNED NOT NULL,
  document_type VARCHAR(50) NOT NULL,
  max_hours INT UNSIGNED NOT NULL DEFAULT 48,
  out_unconfirmed_hours INT UNSIGNED NOT NULL DEFAULT 24,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_processing_thresholds (office_id, document_type),
  CONSTRAINT fk_pt_office FOREIGN KEY (office_id) REFERENCES offices (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
