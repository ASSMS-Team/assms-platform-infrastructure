-- These are local development credentials and should not be used in any deployed environment

CREATE DATABASE dispatchdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'dispatch_svc'@'%' IDENTIFIED BY 'DispatchLocalDev!23';
GRANT ALL PRIVILEGES ON dispatchdb.* TO 'dispatch_svc'@'%';
FLUSH PRIVILEGES;