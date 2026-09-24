<?php
// Email configuration for SmartFlow
// Using Mailtrap SMTP for testing (https://mailtrap.io)

// Mailtrap Credentials - Email Testing Sandbox
const EMAIL_SMTP_HOST = 'sandbox.smtp.mailtrap.io';
const EMAIL_SMTP_PORT = 2525;
const EMAIL_SMTP_USER = '25a93e1a9d9c22';
const EMAIL_SMTP_PASS = 'c287536ad6eff9';
const EMAIL_FROM = 'smartflow@urbiztondo.gov.ph';
const EMAIL_FROM_NAME = 'SmartFlow LGU System';

/**
 * Send email via Gmail SMTP
 * 
 * @param string $to Recipient email
 * @param string $subject Email subject
 * @param string $body Email body (plain text)
 * @return array ['success' => bool, 'message' => string]
 */
function send_email_gmail(string $to, string $subject, string $body): array
{
    // Check if config is still default
    if (EMAIL_SMTP_USER === 'YOUREMAIL@gmail.com') {
        return [
            'success' => false,
            'message' => 'Email not configured. Please update email-config.php with your Gmail credentials.'
        ];
    }

    try {
        $socket = @stream_socket_client(
            'tls://' . EMAIL_SMTP_HOST . ':' . EMAIL_SMTP_PORT,
            $errno,
            $errstr,
            30
        );

        if (!$socket) {
            return [
                'success' => false,
                'message' => "Failed to connect to SMTP server: $errstr"
            ];
        }

        // Read server greeting
        fread($socket, 1024);

        // EHLO
        fwrite($socket, "EHLO " . EMAIL_SMTP_HOST . "\r\n");
        fread($socket, 1024);

        // STARTTLS (already connected via TLS)
        // AUTH LOGIN
        fwrite($socket, "AUTH LOGIN\r\n");
        fread($socket, 1024);

        // Username (base64 encoded)
        fwrite($socket, base64_encode(EMAIL_SMTP_USER) . "\r\n");
        fread($socket, 1024);

        // Password (base64 encoded)
        fwrite($socket, base64_encode(EMAIL_SMTP_PASS) . "\r\n");
        $authResponse = fread($socket, 1024);

        if (!str_starts_with($authResponse, '235')) {
            fclose($socket);
            return [
                'success' => false,
                'message' => 'Email authentication failed. Check your Gmail app password.'
            ];
        }

        // MAIL FROM
        fwrite($socket, "MAIL FROM:<" . EMAIL_FROM . ">\r\n");
        fread($socket, 1024);

        // RCPT TO
        fwrite($socket, "RCPT TO:<$to>\r\n");
        fread($socket, 1024);

        // DATA
        fwrite($socket, "DATA\r\n");
        fread($socket, 1024);

        // Email content
        $headers = "From: " . EMAIL_FROM_NAME . " <" . EMAIL_FROM . ">\r\n";
        $headers .= "To: <$to>\r\n";
        $headers .= "Subject: $subject\r\n";
        $headers .= "MIME-Version: 1.0\r\n";
        $headers .= "Content-Type: text/plain; charset=UTF-8\r\n";
        $headers .= "\r\n";

        fwrite($socket, $headers . $body . "\r\n.\r\n");
        $dataResponse = fread($socket, 1024);

        // QUIT
        fwrite($socket, "QUIT\r\n");
        fclose($socket);

        if (str_starts_with($dataResponse, '250')) {
            return [
                'success' => true,
                'message' => 'Email sent successfully'
            ];
        } else {
            return [
                'success' => false,
                'message' => 'Failed to send email: ' . trim($dataResponse)
            ];
        }

    } catch (Throwable $e) {
        return [
            'success' => false,
            'message' => 'Email error: ' . $e->getMessage()
        ];
    }
}
