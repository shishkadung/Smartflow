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

    if (str_contains($type, 'payroll')) {
        return [
            'code' => 'ACC',
            'reason' => $from === 'HR'
                ? 'Payroll records typically go to Accounting for payment.'
                : 'Payroll documents are usually routed to Accounting.',
        ];
    }

    if (str_contains($type, 'approved budget') || $type === 'budget') {
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
