-- Replication Users Setup
-- This file contains SQL commands to create replication users on all MySQL instances

-- Create percona user with full grants and grant option for all hosts
CREATE USER IF NOT EXISTS 'percona'@'%' IDENTIFIED BY 'Percona1234';
GRANT ALL PRIVILEGES ON *.* TO 'percona'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- Create replication user for MySQL 5.7 (Source)
-- Run this on mysql57 (192.168.56.157)
CREATE USER IF NOT EXISTS 'repl_user'@'192.168.56.180' IDENTIFIED BY 'repl_password';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'192.168.56.180';
FLUSH PRIVILEGES;

-- Create replication user for MySQL 8.0 (Intermediate - receives from 5.7)
-- Run this on mysql8 (192.168.56.180)
CREATE USER IF NOT EXISTS 'repl_user'@'192.168.56.184' IDENTIFIED BY 'repl_password';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'192.168.56.184';
FLUSH PRIVILEGES;

-- Create replication user for MySQL 8.4 (Target - receives from 8.0)
-- Run this on mysql84 (192.168.56.184)
-- No replication user needed as this is the final target

-- Create monitoring user for all instances
-- Run this on all MySQL instances
CREATE USER IF NOT EXISTS 'monitor_user'@'192.168.56.100' IDENTIFIED BY 'monitor_password';
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'monitor_user'@'192.168.56.100';
GRANT SELECT ON mysql.* TO 'monitor_user'@'192.168.56.100';
FLUSH PRIVILEGES; 
