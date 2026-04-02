-- Minimal users table for login/register used by the Flutter app.
-- Adjust as needed to match your existing admin panel schema.

CREATE TABLE IF NOT EXISTS users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'alumni',
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    program VARCHAR(50) NULL,
    year_graduated VARCHAR(10) NULL,
    linkedin_sub VARCHAR(255) NULL,
    linkedin_email VARCHAR(255) NULL,
    auth_provider VARCHAR(50) NULL,
    linkedin_linked_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
