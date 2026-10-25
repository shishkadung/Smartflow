-- Existing API databases: run once if documents.qr_issued_at_unix is absent.
-- The QR helper also adds this nullable column automatically for local installs.
-- Issuance timestamps are initialized on first QR access; existing signed QRs
-- remain valid until their own embedded expiry.
ALTER TABLE documents ADD COLUMN qr_issued_at_unix BIGINT NULL;
