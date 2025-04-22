CREATE TABLE incidents (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    description TEXT NOT NULL,
    status ENUM('open', 'in_progress', 'resolved', 'closed') NOT NULL DEFAULT 'open',
    incident_type JSON NOT NULL, 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
