SET sql_log_bin = 0;
-- Create percona user with full grants and grant option for all hosts
CREATE USER IF NOT EXISTS 'percona'@'%' IDENTIFIED BY 'Percona1234';
GRANT ALL PRIVILEGES ON *.* TO 'percona'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

