-- Create jobs table
CREATE TABLE IF NOT EXISTS jobs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    company VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    salary VARCHAR(100),
    requirements TEXT,
    contact_email VARCHAR(255) NOT NULL,
    date_posted TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create job_applications table
CREATE TABLE IF NOT EXISTS job_applications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    job_id INT NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
    UNIQUE KEY unique_application (user_id, job_id)
);

-- Optional: Add some sample data
INSERT INTO jobs (title, description, company, location, salary, requirements, contact_email) VALUES
('Software Developer', 'We are looking for a skilled software developer to join our team.', 'TechCorp Inc.', 'Manila, Philippines', '₱50,000 - ₱80,000', 'Bachelor\'s degree in Computer Science, 2+ years experience', 'hr@techcorp.com'),
('Data Analyst', 'Join our analytics team to help drive data-driven decisions.', 'DataSolutions Co.', 'Cebu, Philippines', '₱40,000 - ₱60,000', 'Degree in Statistics/Math, SQL and Python skills', 'careers@datasolutions.com'),
('Project Manager', 'Lead cross-functional teams in delivering successful projects.', 'InnovateTech', 'Davao, Philippines', '₱60,000 - ₱90,000', 'PMP certification, 3+ years PM experience', 'pm@innovatetech.com');