-- These are local development credentials and should not be used in any deployed environment

CREATE DATABASE customerdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'customer_svc'@'%' IDENTIFIED BY 'CustomerLocalDev!23';
GRANT ALL PRIVILEGES ON customerdb.* TO 'customer_svc'@'%';
FLUSH PRIVILEGES;