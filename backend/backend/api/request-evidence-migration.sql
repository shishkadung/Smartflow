-- Additive request decision evidence. Select the intended runtime database explicitly.
-- Run once only; normal API schema bootstrap performs equivalent idempotent additions.
-- Keep historical notes/actors untouched: NULL means unavailable legacy evidence.
ALTER TABLE document_requests
  ADD COLUMN reviewed_office_id INT UNSIGNED NULL,
  ADD COLUMN fulfilled_notes TEXT NULL,
  ADD COLUMN cancelled_at DATETIME NULL,
  ADD COLUMN cancelled_by INT UNSIGNED NULL,
  ADD COLUMN cancelled_office_id INT UNSIGNED NULL,
  ADD COLUMN cancelled_notes TEXT NULL;
