# Arizona BatWatch subject processing scripts

## General (in the past tense as this will change if done again)

The Ruby scripts included in this repo were used to slice large video files into small files. The small files were then uploaded as subjects for the Zooniverse project Arizona BatWatch. 

The process was as follows:

1. Have large videos for splitting
2. Have place to put small videos
3. Have SQL database to store info to help track processing and for subject set manifest(s)
  * **NOTE: Steps #4-11 done for each subject set, or date, in Arizona BatWatch's case**
4. Update `config.yml` to reflect #1, #2 and #3
5. Update if needed and run `seed.rb`
6. Update if needed and run `manifest.rb` (line 107 - hardcoded date based on filename)
7. Update if needed and run `process.rb` in reasonable batches (line 26 `LIMIT` = 1,000-2,000)
8. Export CSV from SQL db/table, creating full manifest.csv, used Sequel Pro
9. Edit full manifest.csv if needed, considering metadata wanted, formatting, etc.
10. Split full manifest.csv into batches (1,000-2,000) for upload into Panoptes
11. Upload subjects with smaller manifest.csv in batches using [Panoptes-CLI](https://github.com/zooniverse/panoptes-cli)

Original full videos copied on hard drive in Adler Planetarium, Citizen Science "HARD DRIVES" drawer, labeled "Arizona BatWatch Full Videos."
Subjects for August 6, 2011 (uploaded, subject set #6432) and August 20, 2011 (not uploaded to Panoptes) are on a hard drive in same drawer noted, labeled "Arizona BatWatch Subjects."
