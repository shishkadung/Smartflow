<?php
// Mailtrap API Configuration
// API Token from https://mailtrap.io/api-tokens

const MAILTRAP_API_TOKEN = 'bd34fef20cb805c81eaaf91e35e1aa0d'; // Your token
const MAILTRAP_INBOX_ID = '4679516'; // From your sandbox URL

/**
 * Send email via Mailtrap API (HTTP/cURL) - more reliable than SMTP on XAMPP
 */
function send_email_mailtrap_api(string $to, string $subject, string $body): array
{
    $url = 'https://sandbox.api.mailtrap.io/api/send/' . MAILTRAP_INBOX_ID;
    
    $data = [
        'to' => [['email' => $to, 'name' => '']],
        'from' => ['email' => 'smartflow@urbiztondo.gov.ph', 'name' => 'SmartFlow LGU System'],
        'subject' => $subject,
        'text' => $body,
    ];
    
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . MAILTRAP_API_TOKEN,
        'Content-Type: application/json',
    ]);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // For local dev
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    
    $response = curl_exec($ch);
    $error = curl_error($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($error) {
        return ['success' => false, 'message' => 'cURL error: ' . $error];
    }
    
    if ($httpCode >= 200 && $httpCode < 300) {
        return ['success' => true, 'message' => 'Email sent via Mailtrap API'];
    } else {
        return ['success' => false, 'message' => 'API error (' . $httpCode . '): ' . $response];
    }
}
