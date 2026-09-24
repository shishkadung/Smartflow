-- Optional: per-document due date (manual deadline on documents table)
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS due_at DATETIME NULL DEFAULT NULL AFTER description;
