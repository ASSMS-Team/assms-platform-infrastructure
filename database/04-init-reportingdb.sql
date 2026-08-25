-- These are local development credentials and should not be used in any deployed environment

CREATE DATABASE reportingdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'reporting_svc'@'%' IDENTIFIED BY 'ReportingLocalDev!23';
GRANT ALL PRIVILEGES ON reportingdb.* TO 'reporting_svc'@'%';
FLUSH PRIVILEGES;