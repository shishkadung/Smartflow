<?php

/**
 * Logbook fields on documents (client: SmartFlow should mirror the municipal logbook).
 *   Disbursement Voucher → reference, payee, fund source required
 *   Approved Budget      → reference required
 *   Accounting DV        → received_from_office_id required (ACC does not originate project DVs)
 */

function smartflow_ensure_documents_logbook_columns(PDO $pdo): void
{
    $stmt = $pdo->query("
        SELECT COLUMN_NAME FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'documents'
          AND COLUMN_NAME IN ('reference_no', 'payee', 'fund_source', 'received_from_office_id')
    ");
    $existing = array_map('strtolower', $stmt->fetchAll(PDO::FETCH_COLUMN));

    if (!in_array('reference_no', $existing, true)) {
        $pdo->exec('ALTER TABLE documents ADD COLUMN reference_no VARCHAR(100) NULL AFTER description');
        $pdo->exec('ALTER TABLE documents ADD KEY idx_documents_reference (reference_no)');
    }
    if (!in_array('payee', $existing, true)) {
        $pdo->exec('ALTER TABLE documents ADD COLUMN payee VARCHAR(200) NULL AFTER reference_no');
    }
    if (!in_array('fund_source', $existing, true)) {
        $pdo->exec('ALTER TABLE documents ADD COLUMN fund_source VARCHAR(100) NULL AFTER payee');
    }
    if (!in_array('received_from_office_id', $existing, true)) {
        $pdo->exec('ALTER TABLE documents ADD COLUMN received_from_office_id INT UNSIGNED NULL AFTER fund_source');
    }
}

/**
 * @return list<string> Missing field labels for the given document type.
 */
function smartflow_missing_logbook_fields(string $type, string $referenceNo, string $payee, string $fundSource): array
{
    $missing = [];
    if ($type === 'Disbursement Voucher') {
        if ($referenceNo === '') {
            $missing[] = 'reference / DV no.';
        }
        if ($payee === '') {
            $missing[] = 'payee';
        }
        if ($fundSource === '') {
            $missing[] = 'fund source';
        }
    } elseif ($type === 'Approved Budget') {
        if ($referenceNo === '') {
            $missing[] = 'reference no.';
        }
    }
    return $missing;
}
