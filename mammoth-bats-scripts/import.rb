require 'bson'
require 'json'
require 'mysql2'
require 'open3'
require 'shellwords'
require 'yaml'

config = YAML.load_file File.join Dir.pwd, 'config.yml'

input_directories = if ARGV[0]
  ARGV[0]
else
  config['input']
end

mysql = Mysql2::Client.new(
  host: config['mysql']['host'],
  username: config['mysql']['username'],
  password: config['mysql']['password'],
  database: config['mysql']['database']
)

files = input_directories.collect { |directory| Dir["#{ File.expand_path(directory) }/**/*"] }.flatten

examples = File.open File.join(Dir.pwd, 'examples.txt'), 'w+'

# Various filters to ensure we can use each entry
files.reject! { |file| File.directory? file }
total = files.length

files.each.with_index do |file, index|
  puts "#{ index + 1 } / #{ total }"

  command = "ffprobe -v quiet -print_format json -show_format -show_streams #{ Shellwords.escape file }"
  output = `#{ command }`
  json_output = JSON.parse output

  examples.puts output if index < 3

  video_stream = json_output['streams'].select { |stream| stream['codec_type'] == 'video'}.first
  audio_streams = json_output['streams'].select { |stream| stream['codec_type'] == 'audo'}

  video_codec = video_stream['codec_name']
  duration = video_stream['duration'].to_i
  width = video_stream['width']
  height = video_stream['height']
  pix_fmt = video_stream['pix_fmt']

  escaped_file = mysql.escape file
  results = mysql.query <<-SQL
      select * from manifest where file='#{ escaped_file }'
    SQL

  if results.count > 0
    mysql.query <<-SQL
      update manifest set
        duration=#{ duration },
        video_codec='#{ video_codec }',
        width=#{ width },
        height=#{ height },
        pix_fmt='#{ pix_fmt }'
      where file='#{ escaped_file }'
    SQL
  else
    mysql.query <<-SQL
      insert into manifest
        (file, duration, video_codec, width, height, pix_fmt)
      values (
        '#{ file }',
        #{ duration },
        '#{ video_codec }',
        #{ width },
        #{ height },
        '#{ pix_fmt }'
      )
    SQL
  end
end
