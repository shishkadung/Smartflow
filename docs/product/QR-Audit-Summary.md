# QR Audit Summary for Presentation

## Ano ang ipapakita kay Sir

1. **Mobile scan flow**
   - `mobile/flutter/lib/screens/staff/scanner_screen.dart`
   - Ang mobile app ang nag-scan ng QR at nagve-verify ng token bago i-load ang document.
   - May support para sa secured QR token at legacy plain tracking ID.

2. **Secure QR token logic**
   - `backend/backend/api/qr-token-helper.php`
   - Gumagawa ng signed payload na may HMAC-SHA256 signature.
   - May expiry check para hindi magamit ang luma o forged na label.

3. **Verification endpoint**
   - `backend/backend/api/qr-verify.php`
   - Pinapalakad ang QR verification at nag-audit log ng success/reject.

4. **Movement validation**
   - `backend/backend/api/movements-create.php`
   - Kung may `qr_payload`, bine-validate bago i-record ang IN/OUT movement.
   - Nag-reject ng mismatched, expired, invalid, o duplicate scans.

## Ano ang magandang i-demo

1. Buksan ang mobile scanner.
2. I-scan ang secured QR label.
3. Ipakita ang `verifyQr(...)` API call sa backend.
4. Ipakita kung paano nabablock ang invalid o expired na QR.
5. I-record ang movement at ipaliwanag na may audit trail.

## Key talking points

- **Secured QR labels** — hindi basta plain text, may tamper-proof signature.
- **Expiry enforcement** — QR label may expiration para mas secure.
- **Backend audit** — parehong `qr.verify` at `movement.scan` events ay naka-log.
- **Mismatch protection** — hindi papayagan ang ibang document ID kahit lahat ng iba ay tama.
- **Demo-ready** — may script para tumakbo sa `mobile/flutter` at XAMPP backend.

## Files to open during presentation

- `mobile/flutter/lib/screens/staff/scanner_screen.dart`
- `backend/backend/api/qr-token-helper.php`
- `backend/backend/api/qr-verify.php`
- `backend/backend/api/movements-create.php`

## Quick note

Kung gusto mo, puwede rin tayong gumawa ng isang maikling slide o visual diagram mula sa summary na ito.
