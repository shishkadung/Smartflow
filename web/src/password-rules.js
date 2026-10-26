// Wording shared with the phone: the same message wherever a new password is typed twice.

/** Sign-up and reset-by-code forms. */
export const PASSWORDS_DO_NOT_MATCH = 'Passwords do not match'

/** Forms that replace a known password: Profile and the temporary-password screen. */
export const NEW_PASSWORD_MISMATCH = 'New password and confirmation do not match.'

export const passwordsMatch = (password, confirmation) => password === confirmation
