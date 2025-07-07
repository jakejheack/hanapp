-- Create login_history table for storing user login sessions
CREATE TABLE login_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    login_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    location VARCHAR(255) DEFAULT 'Unknown',
    device_info VARCHAR(255) DEFAULT 'Unknown',
    ip_address VARCHAR(45) DEFAULT NULL,
    user_agent TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Add indexes for better performance
CREATE INDEX idx_login_history_user_id ON login_history(user_id);
CREATE INDEX idx_login_history_timestamp ON login_history(login_timestamp);
CREATE INDEX idx_login_history_user_timestamp ON login_history(user_id, login_timestamp);

-- Optional: Add a comment to describe the table
ALTER TABLE login_history COMMENT = 'Stores user login sessions with location and device information'; 