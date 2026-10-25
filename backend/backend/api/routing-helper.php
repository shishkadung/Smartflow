<?php

declare(strict_types=1);

/** Explicit named Others folders keep their own workflow, even with financial words in the name. */
function smartflow_type_is_other(string $type): bool
{
    return str_starts_with(strtolower(trim($type)), 'others:');
}

function smartflow_type_is_dv(string $type): bool
{
    $type = strtolower(trim($type));
    return !smartflow_type_is_other($type)
        && (str_contains($type, 'disbursement') || str_contains($type, 'voucher'));
}

function smartflow_type_is_approved_budget(string $type): bool
{
    $type = strtolower(trim($type));
    return !smartflow_type_is_other($type) && str_contains($type, 'approved budget');
}

/**
 * Suggested next office for Mark OUT (LGU DV path).
 *
 * Client-validated DV trail:
 * ENG → BUD → ACC → TRE → MAY → TRE (check release) → ACC if the folder returns.
 *
 * @param list<string> $visitedOfficeCodes Office codes that already scanned IN this folder.
 * @return array{code: string, reason: string}|null
 */
function smartflow_suggest_forward_destination(
    string $documentType,
    string $fromOfficeCode,
    array $visitedOfficeCodes = []
): ?array {
    $type = strtolower(trim($documentType));
    $from = strtoupper(trim($fromOfficeCode));
    $visited = array_map(static fn ($c) => strtoupper(trim((string)$c)), $visitedOfficeCodes);

    if (smartflow_type_is_approved_budget($type) || $type === 'budget') {
        if ($from === 'ACC' && in_array('BUD', $visited, true)) {
            return null;
        }
        if ($from === 'BUD') {
            return [
                'code' => 'ACC',
                'reason' => 'Approved budgets are forwarded to Accounting.',
            ];
        }
        if ($from === 'ENG') {
            return [
                'code' => 'BUD',
                'reason' => 'Engineering often sends project files to Budget first.',
            ];
        }
        return [
            'code' => 'BUD',
            'reason' => 'Budget office usually handles budget documents.',
        ];
    }

    if (smartflow_type_is_dv($type)) {
        if ($from === 'ENG') {
            return [
                'code' => 'BUD',
                'reason' => 'DV from Engineering often goes to Budget for fund check.',
            ];
        }
        if ($from === 'BUD') {
            return [
                'code' => 'ACC',
                'reason' => 'After Budget review, DVs go to Accounting for supporting-doc check.',
            ];
        }
        if ($from === 'ACC') {
            if (in_array('TRE', $visited, true) && in_array('MAY', $visited, true)) {
                return null;
            }
            return [
                'code' => 'TRE',
                'reason' => 'After Accounting, the folder goes to Treasury for payment processing.',
            ];
        }
        if ($from === 'TRE') {
            if (in_array('MAY', $visited, true)) {
                return [
                    'code' => 'ACC',
                    'reason' => 'After Mayor and check release, return the folder to Accounting if needed.',
                ];
            }
            return [
                'code' => 'MAY',
                'reason' => 'Treasury forwards the DV to the Office of the Mayor for signature.',
            ];
        }
        if ($from === 'MAY') {
            return [
                'code' => 'TRE',
                'reason' => 'After Mayor signature, return to Treasury for check release.',
            ];
        }
        if ($from === 'HR') {
            return [
                'code' => 'ACC',
                'reason' => 'Disbursement vouchers are released through Accounting.',
            ];
        }
        return [
            'code' => 'ACC',
            'reason' => 'Disbursement documents typically go to Accounting, then Treasury and Mayor.',
        ];
    }

    return null;
}

/**
 * SQL boolean expression: TRUE when the document's custody trail is finished
 * (no more due dates, not "active" / overdue).
 *   DV             → latest IN at TRE after MAY scanned IN (check release), or
 *                    latest IN at ACC after TRE and MAY both scanned IN (optional return)
 *   Approved Budget → latest IN at ACC after BUD scanned IN
 *
 * @param string $documentIdExpr SQL expression or placeholder for the document id
 */
function smartflow_sql_trail_complete(string $documentIdExpr): string
{
    $predicate = smartflow_sql_trail_complete_known_latest('tcd', 'tcm', 'tco');
    return "EXISTS (
        SELECT 1 FROM documents tcd
        JOIN movements tcm ON tcm.document_id=tcd.id AND tcm.id = (SELECT tcl.id FROM movements tcl WHERE tcl.document_id=tcd.id ORDER BY tcl.scanned_at DESC,tcl.id DESC LIMIT 1)
        JOIN offices tco ON tco.id=tcm.office_id
        WHERE tcd.id = {$documentIdExpr} AND {$predicate}
    )";
}

/** Same completion rule when a queue already joined the latest movement and office. */
function smartflow_sql_trail_complete_known_latest(string $document, string $movement, string $office): string
{
    $visited = static fn (string $code): string => "EXISTS (
        SELECT 1 FROM movements tcv
        JOIN offices tcvo ON tcvo.id = tcv.office_id
        WHERE tcv.document_id = {$document}.id AND tcv.status = 'IN' AND tcvo.code = '{$code}'
    )";
    $visitedTre = $visited('TRE');
    $visitedMay = $visited('MAY');
    $visitedBud = $visited('BUD');

    return "({$movement}.status = 'IN'
          AND (
            (LOWER({$document}.type) NOT REGEXP '^[[:space:]]*others:' AND (
              (
                (LOWER({$document}.type) LIKE '%disbursement%' OR LOWER({$document}.type) LIKE '%voucher%')
                AND {$visitedMay}
                AND ({$office}.code = 'TRE' OR ({$office}.code = 'ACC' AND {$visitedTre}))
              )
              OR ({$office}.code = 'ACC' AND LOWER({$document}.type) LIKE '%approved budget%' AND {$visitedBud})
            ))
            OR {$document}.filed_at IS NOT NULL
          )
    )";
}

function smartflow_type_has_fixed_route(string $type): bool
{
    $type = strtolower(trim($type));
    return smartflow_type_is_dv($type)
        || smartflow_type_is_approved_budget($type)
        || $type === 'budget';
}

function smartflow_ensure_documents_filed_columns(PDO $pdo): void
{
    static $ready = false;
    if ($ready) {
        return;
    }
    $stmt = $pdo->query("
        SELECT COLUMN_NAME FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'documents'
          AND COLUMN_NAME IN ('filed_at', 'filed_by')
    ");
    $existing = array_map('strtolower', $stmt->fetchAll(PDO::FETCH_COLUMN));
    if (!in_array('filed_at', $existing, true)) {
        $pdo->exec('ALTER TABLE documents ADD COLUMN filed_at DATETIME NULL');
    }
    if (!in_array('filed_by', $existing, true)) {
        $pdo->exec('ALTER TABLE documents ADD COLUMN filed_by INT UNSIGNED NULL');
    }
    $ready = true;
}

/**
 * @param array{status?:string,office_code?:string,office_id?:int|string} $last
 * @return array{office_id:int,office_code:string,office_name:string,reason:string}|null
 */
function smartflow_build_suggested_forward(PDO $pdo, string $documentId, string $type, array $last): ?array
{
    if (strtoupper((string)($last['status'] ?? '')) !== 'IN') {
        return null;
    }
    $stmtVisited = $pdo->prepare('
        SELECT DISTINCT ofc.code
        FROM movements m
        JOIN offices ofc ON ofc.id = m.office_id
        WHERE m.document_id = :id AND m.status = :st
    ');
    $stmtVisited->execute([':id' => $documentId, ':st' => 'IN']);
    $visited = array_map(
        static fn ($row) => strtoupper((string)$row['code']),
        $stmtVisited->fetchAll()
    );
    $hint = smartflow_suggest_forward_destination($type, (string)($last['office_code'] ?? ''), $visited);
    if ($hint === null) {
        return null;
    }
    $stmtCode = $pdo->prepare('SELECT id FROM offices WHERE code = :code LIMIT 1');
    $stmtCode->execute([':code' => $hint['code']]);
    $destId = $stmtCode->fetchColumn();
    $destId = $destId === false ? null : (int)$destId;
    $fromId = (int)($last['office_id'] ?? 0);
    if ($destId === null || $destId === $fromId) {
        return null;
    }
    $stmtDest = $pdo->prepare('SELECT name, code FROM offices WHERE id = :id LIMIT 1');
    $stmtDest->execute([':id' => $destId]);
    $destRow = $stmtDest->fetch();
    if (!$destRow) {
        return null;
    }
    return [
        'office_id' => $destId,
        'office_code' => $destRow['code'],
        'office_name' => $destRow['name'],
        'reason' => $hint['reason'],
    ];
}

function smartflow_document_trail_complete(PDO $pdo, string $documentId): bool
{
    $stmt = $pdo->prepare('SELECT ' . smartflow_sql_trail_complete(':id') . ' AS done');
    $stmt->execute([':id' => $documentId]);
    return (int)$stmt->fetchColumn() === 1;
}
