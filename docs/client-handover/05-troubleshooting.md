# SmartFlow User Manual — Part 5: Troubleshooting

Messages you may see in SmartFlow, what they mean, and what to do. If a problem is not listed here, note the exact message and the document ID, and contact the Municipal Accountant / Admin or LGU IT.

---

## Signing in

| Message | What to do |
|---|---|
| *Username and password are required* | Fill in both fields. |
| *Invalid username or password* | Check spelling and Caps Lock. Use **Forgot password?** if you forgot it. |
| *Account pending admin approval…* | Your access request has not been approved yet. Ask the Municipal Accountant / Admin to review it. |
| *This account has been deactivated. Contact your municipal administrator.* | Your account was turned off. Ask the Admin to reactivate it if you still need access. |
| Reset code is invalid or expired | Codes expire after 1 hour and only the newest code works. Request a new code. |
| No reset code email arrived | Check the spam folder and make sure the email in your profile is correct. Ask the Admin or LGU IT if it still does not arrive. |
| You are suddenly back at the sign-in screen | Your 24-hour session ended. Sign in again. |

---

## Registering a folder

| Message | What to do |
|---|---|
| *Logbook fields required for Disbursement Voucher: …* | Fill in Reference / DV no., Payee, and Fund source. |
| *Logbook fields required for Approved Budget: …* | Fill in the Reference number. |
| *Name the folder under Others (at least 3 characters).* | Type a name for the folder when you choose **Others**. |
| *Accounting does not originate project DVs — choose the office that sent this folder* | Accounting clerks: choose the office the DV came from under **Received from office**. |
| *You can only register documents your office physically holds…* | Only register folders that are at your office. For files in another office, send a **Request**. |
| **Reference already used** pop-up | A document with the same reference number exists. Click **Cancel** and check it in **History**. Only click **Register anyway** if this is truly a different folder. |

---

## Scanning

| Message | Meaning | What to do |
|---|---|---|
| *Document is still IN at [office]. That office must Mark OUT first.* | The sending office forgot to scan the folder out | Call that office and ask them to **Mark OUT** to your office, then scan again |
| *This folder was sent to [office]…* | The folder was marked OUT to a different office, and only that office can Mark IN next | Bring the folder to that office. If the sender chose the wrong office by mistake, that office marks it IN and then marks it OUT to you |
| *Already marked IN at your office. Mark OUT when you forward this document.* | You already received it | Nothing to do now. Mark OUT when you forward it |
| *Already marked OUT from your office. The receiving office must scan IN next.* | You already sent it | Ask the receiving office to Mark IN |
| *Cannot mark OUT — document is not currently IN at your office…* | The folder is not recorded at your office | Mark IN first if it just arrived. If it was never sent to you, check its **History** |
| *Mark IN first when the physical document arrives at your office.* | You tried to send a folder that was not received yet | Mark IN, then Mark OUT |
| *You can only record movements for your assigned office…* | You are signed in with an account from another office | Sign in with your own account |
| *This QR label has expired. Ask Accounting to reprint the label.* | Labels are valid for about 6 months | Type the Document ID written on the folder in **Tracking ID or QR text** to continue, then have the label replaced (see below) |
| *Invalid QR — label may be damaged or forged…* | The label is damaged, altered, or not a SmartFlow label | Type the Document ID instead, then have the label replaced. Report labels that look tampered with to the Admin |
| *Document not found…* | The ID does not exist | Check the ID for typing mistakes. If the folder was never registered, the office holding it should **Register** it |
| *Could not record movement. Try again in a moment.* | Temporary connection or server problem | Wait a moment and try again. If it continues, ask the Admin to check **System** status |

**Replacing a QR label:** the label is printed right after the folder is registered (**Open printable label**). SmartFlow has no reprint button for older folders yet, so print the label immediately and keep it safe. If a label is lost, damaged, or expired, use the Document ID written on the folder when scanning, and report it to the Municipal Accountant / Admin.

**Camera does not open:** allow camera access for SmartFlow in your phone or browser settings, or use **Upload QR image** or type the Document ID instead.

---

## Requests

| Message | What to do |
|---|---|
| *Cannot pull from your own office — process locally* | You cannot send a request to your own office. Handle it at your desk. |
| Purpose or Required by is missing | Both are required. Fill them in and send again. |
| Cannot decline a request | **Decline notes** are required. Type the reason first. Remember to also notify the requester by phone or memo. |

---

## Admin

| Message | What to do |
|---|---|
| *You cannot deactivate your own account* | Ask another Admin to do it. |
| *Cannot deactivate the last active admin account* | Approve or reactivate another Admin first. |
| Dashboard numbers look wrong or empty | Click **Refresh status** on **System**. If the API or MySQL is not online, contact LGU IT. |

---

## The system is down

If nobody can sign in or every scan fails:

1. Check your internet or office network connection.
2. Ask the Admin to open **System** and check whether **API / PHP** and **MySQL** are online.
3. Contact LGU IT to restart the server.

While SmartFlow is down, continue passing folders as usual and write down each handoff (document ID, office, time). Scan them in SmartFlow once it is back up, so the trail stays complete.
