<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../../config/db_connect.php';

try {
    $category = $_GET['category'] ?? '';
    
    if (empty($category)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Category parameter is required'
        ]);
        exit();
    }
    
    // Get videos by category from the database
    $query = "SELECT id, title, description, link, image_path, video_path, video_url, category, is_active, created_at, updated_at 
              FROM cms_ads 
              WHERE category = ? AND is_active = 1 
              ORDER BY created_at DESC";
    
    $stmt = $conn->prepare($query);
    $stmt->bind_param('s', $category);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $videos = [];
    while ($row = $result->fetch_assoc()) {
        // Convert image_path to full URL if it exists
        if ($row['image_path'] && !empty($row['image_path'])) {
            $row['image_path'] = 'https://autosell.io' . $row['image_path'];
        }
        
        // Convert video_path to full URL if it exists
        if ($row['video_path'] && !empty($row['video_path'])) {
            $row['video_path'] = 'https://autosell.io' . $row['video_path'];
        }
        
        $videos[] = $row;
    }
    
    echo json_encode([
        'success' => true,
        'videos' => $videos,
        'count' => count($videos),
        'category' => $category
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage()
    ]);
}

$conn->close();
?> 