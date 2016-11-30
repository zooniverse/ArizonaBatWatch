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
  TRUNCATE table manifest
  SQL

puts "Manifest table reset."
