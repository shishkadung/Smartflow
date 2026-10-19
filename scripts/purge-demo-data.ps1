# Retired: the old HTTP helper could purge operational data without authentication.
$ErrorActionPreference = 'Stop'
throw 'HTTP demo purging is disabled. Preserve the working database. Use scripts/test-request-linking.php for a disposable test database; deliberate CLI maintenance requires a separately verified target and explicit opt-in.'
