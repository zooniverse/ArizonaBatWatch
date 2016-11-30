require 'mysql2'
require 'yaml'

config = YAML.load_file File.join Dir.pwd, 'config.yml'
mysql = Mysql2::Client.new(
  host: config['mysql']['host'],
  username: config['mysql']['username'],
  password: config['mysql']['password'],
  database: config['mysql']['database']
)

mysql.query <<-SQL
  CREATE TABLE `manifest` (
    `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
    -- used for subject generation
    `bson_id` varchar(255) DEFAULT NULL,
    `source_path` varchar(255) DEFAULT NULL,
    `start_time` int(11) DEFAULT NULL,
    `desired_duration` int(11) DEFAULT NULL,
    `processed` tinyint(1) DEFAULT '0',
    `processed_time` varchar(50) DEFAULT NULL,
    -- used for subject metadata
    `source_file` varchar(255) DEFAULT NULL,
    `gate` int(11) DEFAULT NULL,
    `tape` int(11) DEFAULT NULL,
    `date` date DEFAULT NULL,
    PRIMARY KEY (`id`)
  ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
SQL

    # `video_codec` varchar(255) DEFAULT NULL,
    # `pix_fmt` varchar(255) DEFAULT NULL,
