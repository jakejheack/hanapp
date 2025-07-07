-- Run this SQL in your Hostinger phpMyAdmin to add required columns for social login
-- Only add columns that don't already exist in your users table

-- Add firebase_uid column if it doesn't exist
ALTER TABLE users ADD COLUMN firebase_uid VARCHAR(255) NULL UNIQUE AFTER id;

-- Add auth_provider column if it doesn't exist  
ALTER TABLE users ADD COLUMN auth_provider VARCHAR(50) DEFAULT 'email' AFTER password;

-- Add profile_picture_url column if it doesn't exist (might already exist)
ALTER TABLE users ADD COLUMN profile_picture_url TEXT NULL AFTER email;

-- Add last_login column if it doesn't exist
ALTER TABLE users ADD COLUMN last_login TIMESTAMP NULL AFTER updated_at;

-- Create index for faster lookups
CREATE INDEX idx_firebase_uid ON users(firebase_uid);
CREATE INDEX idx_auth_provider ON users(auth_provider);

-- Optional: Create login_history table if it doesn't exist
CREATE TABLE IF NOT EXISTS login_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    device_info TEXT,
    login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    auth_provider VARCHAR(50),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
