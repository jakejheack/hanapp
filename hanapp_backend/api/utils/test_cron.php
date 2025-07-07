<?php
// hanapp_backend/api/utils/test_cron.php
// Simple test file to verify cron job is working

$logFile = '/home/u688984333/domains/autosell.io/public_html/api/utils/cron_test.log';

$message = date('Y-m-d H:i:s') . " - Cron job executed successfully\n";

file_put_contents($logFile, $message, FILE_APPEND);

echo "Cron test executed at " . date('Y-m-d H:i:s') . "\n";
?> 