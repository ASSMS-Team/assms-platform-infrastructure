-- These are local development credentials and should not be used in any deployed environment

CREATE DATABASE jobdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'job_svc'@'%' IDENTIFIED BY 'JobLocalDev!23';
GRANT ALL PRIVILEGES ON jobdb.* TO 'job_svc'@'%';
FLUSH PRIVILEGES;