# SmartFlow Authentication and Access Flow — As Implemented

This is a separate authentication figure. It does not replace or modify the Staff, Head, or Admin operational flowcharts.

```mermaid
flowchart TD
  S([Start]) --> ENTRY[Open SmartFlow]
  ENTRY --> CHOICE{Choose access action}

  %% SIGN IN
  CHOICE -->|Sign in| LOGIN[Enter username and password]
  LOGIN --> REQUIRED{Both fields provided?}
  REQUIRED -->|No| FIELD_ERR[Show: Username and password are required] --> LOGIN
  REQUIRED -->|Yes| PENDING{Latest signup request still pending?}
  PENDING -->|Yes| PENDING_MSG[Show pending-admin-approval message] --> LOGIN
  PENDING -->|No| VERIFY{Username exists and password matches?}
  VERIFY -->|No| INVALID[Show generic invalid username or password message] --> LOGIN
  VERIFY -->|Yes| ACTIVE{Account active?}
  ACTIVE -->|No| DEACT[Show account-deactivated message; contact administrator] --> LOGIN
  ACTIVE -->|Yes| TOKEN[Generate authenticated token with 24-hour lifetime]
  TOKEN --> ROLE{Read approved role}
  ROLE -->|staff| STAFF[Redirect to Staff own-office dashboard]
  ROLE -->|head| HEAD[Redirect to Head assigned-office dashboard]
  ROLE -->|admin| ADMIN[Redirect to Municipal Accountant / Admin dashboard]
  STAFF --> SESSION[Use protected SmartFlow functions]
  HEAD --> SESSION
  ADMIN --> SESSION
  SESSION --> LOGOUT[Log out and clear authenticated session]
  LOGOUT --> E([End])

  %% REQUEST ACCESS / SIGN UP
  CHOICE -->|Request access| ACCOUNT[Step 1: Enter full name, username, email, password, and confirmation]
  ACCOUNT --> ACCOUNT_OK{Account fields valid?}
  ACCOUNT_OK -->|No| ACCOUNT_ERR[Require valid email, matching passwords, and at least 8 characters] --> ACCOUNT
  ACCOUNT_OK -->|Yes| WORK[Step 2: Select municipal office and requested role]
  WORK --> ROLE_OK{Office available and role is staff, head, or admin?}
  ROLE_OK -->|No| WORK_ERR[Show office or role validation error] --> WORK
  ROLE_OK -->|Yes| UNIQUE{Username available?}
  UNIQUE -->|No: active user| TAKEN[Show username already taken] --> ACCOUNT
  UNIQUE -->|No: pending request| ALREADY_PENDING[Show pending signup already exists] --> STATUS
  UNIQUE -->|No: previously approved| SIGN_IN_INSTEAD[Prompt user to sign in] --> LOGIN
  UNIQUE -->|Previously rejected| REAPPLY[Update rejected request and return it to pending]
  UNIQUE -->|Yes| CREATE_REQ[Create signup request with REQ code and pending status]
  REAPPLY --> STATUS[Show Signup Pending screen]
  CREATE_REQ --> STATUS
  STATUS --> POLL[Check signup status using request code and username]
  POLL --> ADMIN_DECISION{Admin decision}
  ADMIN_DECISION -->|Still pending| STATUS
  ADMIN_DECISION -->|Rejected| REJECTED[Show rejected status; user may correct and reapply] --> ACCOUNT
  ADMIN_DECISION -->|Approved| CREATE_USER[Create active user with approved office and role]
  CREATE_USER --> APPROVED[Show approval details]
  APPROVED --> LOGIN

  %% FORGOT PASSWORD
  CHOICE -->|Forgot password| FORGOT[Enter username]
  FORGOT --> USERNAME{Username provided?}
  USERNAME -->|No| USER_ERR[Show username required] --> FORGOT
  USERNAME -->|Yes| LOOKUP{Active account exists?}
  LOOKUP -->|No| GENERIC[Show generic response without revealing account existence] --> LOGIN
  LOOKUP -->|Yes| INVALIDATE[Invalidate earlier unused reset codes]
  INVALIDATE --> CODE[Generate six-digit reset code valid for one hour]
  CODE --> EMAIL{Email delivery successful?}
  EMAIL -->|Yes| SENT[Send reset code to registered email]
  EMAIL -->|No / demo| DISPLAY[Provide demo reset code]
  SENT --> RESET[Open New Password screen]
  DISPLAY --> RESET
  RESET --> RESET_FORM[Enter username, reset code, new password, and confirmation]
  RESET_FORM --> RESET_VALID{Fields valid and password at least 8 characters?}
  RESET_VALID -->|No| RESET_ERR[Show validation error] --> RESET_FORM
  RESET_VALID -->|Yes| CODE_VALID{Latest unused code correct and not expired?}
  CODE_VALID -->|No| CODE_ERR[Show invalid or expired reset code] --> RESET_FORM
  CODE_VALID -->|Yes| UPDATE[Hash and save new password]
  UPDATE --> USED[Mark reset code used and write password-reset audit event]
  USED --> SUCCESS[Show reset successful and redirect to Sign in]
  SUCCESS --> LOGIN
```

## Verified Rules

- Login uses `username` and `password`.
- Pending signup requests cannot sign in.
- Deactivated accounts cannot sign in.
- Successful login creates a token with a 24-hour lifetime.
- Role redirect is `staff → /staff`, `head → /head`, and `admin → /admin`.
- Signup requires full name, unique username, valid email, password of at least eight characters, confirmation, office, and requested role.
- New accounts remain pending until Admin approves them.
- A rejected signup can be corrected and resubmitted using the same request record.
- Password reset uses a six-digit code that expires after one hour.
- Password-reset responses do not reveal whether a username exists.
- Successful password reset invalidates the code and records an audit event.

