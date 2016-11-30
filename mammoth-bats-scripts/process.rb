require 'json'
require 'mysql2'
require 'open3'
require 'shellwords'
require 'yaml'

config = YAML.load_file File.join Dir.pwd, 'config.yml'
mysql = Mysql2::Client.new(
  host: config['mysql']['host'],
  username: config['mysql']['username'],
  password: config['mysql']['password'],
  database: config['mysql']['database']
)

def close_streams(*args)
  args.each{|arg| arg.close}
end

upload_path = File.expand_path config['process']['upload_path']
`mkdir -p #{ upload_path }`

subjects = mysql.query <<-SQL
  SELECT *
  FROM manifest
  WHERE
    pix_fmt = 'yuv411p' &&
    video_codec = 'dvvideo' &&
    source_drive = 'coro_survey_2011'
  LIMIT 1
  SQL

total = subjects.count
count = 0
per_slice = 8

subjects.each_slice(per_slice).with_index do |subjects_slice, i|
  puts "#{ (i + 1) * per_slice } / #{ total }"

  threads = []
  subjects_slice.each do |subject|
    threads << Thread.new do
      bson_id = subject['bson_id']
      source_file = subject['source_file']
      video_codec = subject['video_codec']
      start_time = subject['start_time']
      duration = subject['desired_duration']

      subject_path = File.join upload_path, "/subjects/#{ bson_id }/"
      `mkdir -p #{ subject_path }`

      # Thumbnail
      # cmd = "ffmpeg -nostdin -ss #{ start_time } -i \"#{ source_file }\" -y -r 1 -to 1 #{subject_path }/#{ bson_id }.jpg"
      # system cmd #, [:out, :err] => '/dev/null'

      # h264
      cmd = "ffmpeg -nostdin -ss #{ start_time } -i '#{ source_file }' -y -to #{ duration } -c:v libx264 -preset medium -crf 23 -vf scale=\"720:trunc(ow/a/2)*2\" -r 24 -pix_fmt yuv420p -threads 0 -an '#{ subject_path }/#{ bson_id }.mp4'"
      system cmd #, [:out, :err] => '/dev/null'
    end
  end
  threads.each &:join
end

puts "Done."


# -nostdin disables standard input interaction
# -ss <position> when before -i will seek in the input file to position
# -i <filename> input
# -y overwrite output files without asking
# -to <position> stop writing output at position. must be time duration specification
# -c:v codec:stream_specifier selects an encoder when before an output file. 
# libx264 is h.264 codec
# -preset medium is default and can be left out
# -crf (constant rate factor). Determines compression. 23 is default.
# -vf <filtergraph>. Create filtergraph specified and use it to filter stream
# -r force framerate to specified fps
# -pix_fmt sets pixel format.
# -threads number of encoding threads
# -an disable audio recording