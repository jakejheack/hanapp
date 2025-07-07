<?php
// hanapp_backend/api/debug_paths.php
// Debug script to check directory paths

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$debug = [
    'script_directory' => __DIR__,
    'current_working_directory' => getcwd(),
    'relative_paths' => [
        'uploads' => file_exists('uploads') ? 'EXISTS' : 'NOT FOUND',
        '../uploads' => file_exists('../uploads') ? 'EXISTS' : 'NOT FOUND',
        '../../uploads' => file_exists('../../uploads') ? 'EXISTS' : 'NOT FOUND',
    ],
    'absolute_paths' => [
        'uploads' => realpath(__DIR__ . '/uploads'),
        '../uploads' => realpath(__DIR__ . '/../uploads'),
        '../../uploads' => realpath(__DIR__ . '/../../uploads'),
    ],
    'parent_directories' => [
        'parent' => dirname(__DIR__),
        'grandparent' => dirname(dirname(__DIR__)),
    ]
];

echo json_encode($debug, JSON_PRETTY_PRINT);
?> 