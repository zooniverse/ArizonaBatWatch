global.XMLHttpRequest = require('xmlhttprequest-cookie').XMLHttpRequest
var PanoptesClient = require('panoptes-client');
var mime = require('mime');
var mysql = require('mysql');
var yaml = require('js-yaml');
var request = require('request');

var fs = require('fs');
var childProcess = require('child_process');

var argv = require('yargs').argv;
if(argv.login == undefined || argv.password == undefined) {
  console.log('Must pass login credentials');
  process.exit(1);
}

var config = null;

try {
  config = yaml.safeLoad(fs.readFileSync(__dirname + '/config.yml', 'utf8'));
} catch (e) {
  console.log('Could not read config file.');
  process.exit(1);
}

var credentials = {
  login: argv.login,
  password: argv.password
};

childProcess.execSync('mkdir -p ' + config['process']['upload_path'])

var dbConfig = {
  connectionLimit: 10,
  host: config['mysql']['host'],
  user: config['mysql']['username'],
  password: config['mysql']['password'],
  database: config['mysql']['database']
};

var pool  = mysql.createPool(dbConfig);

var client = new PanoptesClient({
  appID: 'f79cf5ea821bb161d8cbb52d061ab9a2321d7cb169007003af66b43f7b79ce2a',
  secret: '43ecdefef0ddda5c20317a34cc38b97ce73ad4fbbd08ed17517d99c01744d6d5',
  host: 'https://panoptes.zooniverse.org'
});

var api = client.api;
var auth = api.auth;
var count = 17787;

function handleDisconnect() {
  console.log('Handling disconnect...');
  var connection = mysql.createPool(dbConfig); // Recreate the connection, since
                                              // the old one cannot be reused.

  connection.connect(function(err) {              // The server is either down
    if(err) {                                     // or restarting (takes a while sometimes).
      console.log('error when connecting to db:', err);
      setTimeout(handleDisconnect, 2000); // We introduce a delay before attempting to reconnect,
    }                                     // to avoid a hot loop, and to allow our node script to
  });                                     // process asynchronous requests in the meantime.
                                          // If you're also serving http, display a 503 error.
  connection.on('error', function(err) {
    console.log('db error', err);
    if(err.code === 'PROTOCOL_CONNECTION_LOST') { // Connection to the MySQL server is usually
      handleDisconnect();                         // lost due to either server restart, or a
    } else {                                      // connnection idle timeout (the wait_timeout
      throw err;                                  // server variable configures this)
    }
  });
}

function putFile(location, filePath, type) {
  var stats = fs.statSync(filePath)
  var buffer = fs.readFileSync(filePath)

  return new Promise (function(resolve, reject) {
    var options = {
      url: location,
      method: 'PUT',
      body: buffer,
      headers: {
        'Content-Type': type,
        'Content-Length': stats.size
      },
      forever: true
    };

    request(options, function(e, message, response) {
      if ((typeof message !== "undefined" && message !== null) && message.statusCode < 300) {
        console.log('subject saved', message.statusCode);

        resolve(e);
      } else {
        console.log('reject in putFile', e, response);

        reject(e);
      }
    })
    .on('error', function(err) {
      console.log('on error in putFile', err)
    });
  });
}

api.update({'params.admin': true});
auth.signIn(credentials)
  .then(function(user) {
    api.type('projects').get(config['panoptes']['project_id'])
      .then(function(project) {
        var query = "SELECT * " +
                    "FROM manifest " +
                    "LIMIT 17787, 3000";

        console.log('Querying DB for subject manifests...');

        pool.getConnection(function(error, connection) {
          if(error) throw error;
          var queryStream = connection.query(query);
          queryStream
            .on('error', function(error) {
              console.log('queryStream error', error);
            })
            .on('fields', function(fields) {
              // console.log(fields);
            })
            .on('result', function(rows) {
              connection.pause();

              var base = config['process']['upload_path']
              var locationsSources = {
                'image/jpeg': base + '/' + rows.bson_id + '/' + rows.bson_id + '.jpg',
                'video/mp4': base + '/' + rows.bson_id + '/' + rows.bson_id + '.mp4'
              }

              var subject = {
                locations: ['video/mp4', 'image/jpeg'],
                metadata: {
                  source_file: rows.source_file,
                  start_time: rows.start_time,
                  duration: rows.desired_duration
                },
                links: {
                  project: config['panoptes']['project_id'],
                  subject_sets: [config['panoptes']['subject_set_id']]
                }
              }

              api.type('subjects').create(subject).save()
                .then(function(subject) {
                  var promiseArray = subject.locations.map(function(location, i) {
                    for (var type in location) {
                      return putFile(location[type], locationsSources[type], type)
                    }
                  });

                  Promise.all(promiseArray)
                    .then(function(results) {
                      // connection.resume();
                      count += 1;
                      console.log('subject count', count);
                    })
                    .catch(function(error) {
                      console.log('Error uploading subject data.', error);
                      subject.delete();
                    })
                    .then(function() {
                      connection.resume();
                    });
                })
                .catch(function(error) {
                  console.log('Error saving subject data', error)
                  process.exit(1);
                });
            })
            .on('end', function() {
              console.log('Done!');
              process.exit(0);
            });
          });
      })
      .catch(function(error) {
        console.log('Error getting project', error);
        process.exit(1);
      });
  })
  .catch(function(error) {
    console.log('Error authenticating user', error);
    process.exit(1);
  });
