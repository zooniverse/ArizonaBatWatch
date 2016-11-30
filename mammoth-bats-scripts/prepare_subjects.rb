require 'bson'
require 'mysql2'
require 'json'

DESIRED_SUBJECT_LENGTH = 20
DESIRED_OVERLAP = 0

mysql = Mysql2::Client.new host: 'localhost', username: 'mammoth', password: 'mammoth123', database: 'mammoth_bats'

manifest_rows = mysql.query <<-SQL
    select * from manifest
  SQL

total = manifest_rows.count
counter = 0

manifest_rows.each do |row|
  puts "#{ counter += 1 } / #{ total }"
  file = row['file']
  
  # Destructive for now
  mysql.query <<-SQL
    delete from subjects where source_file='#{ file }'
  SQL

  duration = row['duration']
  pix_fmt = row['pix_fmt']

  pointer = 0
  until pointer > duration
    pointer = pointer + DESIRED_SUBJECT_LENGTH - DESIRED_OVERLAP
    id = BSON::ObjectId.new.to_s

    mysql.query <<-SQL
      insert into subjects
        (source_file, bson_id, duration, start_time)
      values (
        '#{ file }',
        '#{ id }',
        #{ DESIRED_SUBJECT_LENGTH },
        #{ pointer }
      )
    SQL
  end
end