<?php

declare(strict_types=1);

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

    if (str_contains($type, 'approved budget') || $type === 'budget') {
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

    if (str_contains($type, 'disbursement') || str_contains($type, 'voucher')) {
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
    $visited = static fn (string $code): string => "EXISTS (
        SELECT 1 FROM movements tcv
        JOIN offices tcvo ON tcvo.id = tcv.office_id
        WHERE tcv.document_id = tcd.id AND tcv.status = 'IN' AND tcvo.code = '{$code}'
    )";
    $visitedTre = $visited('TRE');
    $visitedMay = $visited('MAY');
    $visitedBud = $visited('BUD');

    return "EXISTS (
        SELECT 1
        FROM documents tcd
        JOIN movements tcm ON tcm.id = (
            SELECT tcl.id FROM movements tcl
            WHERE tcl.document_id = tcd.id
            ORDER BY tcl.scanned_at DESC, tcl.id DESC
            LIMIT 1
        )
        JOIN offices tco ON tco.id = tcm.office_id
        WHERE tcd.id = {$documentIdExpr}
          AND tcm.status = 'IN'
          AND (
            (
              (LOWER(tcd.type) LIKE '%disbursement%' OR LOWER(tcd.type) LIKE '%voucher%')
              AND {$visitedMay}
              AND (tco.code = 'TRE' OR (tco.code = 'ACC' AND {$visitedTre}))
            )
            OR (tco.code = 'ACC' AND LOWER(tcd.type) LIKE '%approved budget%' AND {$visitedBud})
          )
    )";
}

function smartflow_document_trail_complete(PDO $pdo, string $documentId): bool
{
    $stmt = $pdo->prepare('SELECT ' . smartflow_sql_trail_complete(':id') . ' AS done');
    $stmt->execute([':id' => $documentId]);
    return (int)$stmt->fetchColumn() === 1;
}
