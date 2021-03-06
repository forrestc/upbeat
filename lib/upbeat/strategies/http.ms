var Base = require('./base-strategy');
var QS   = require('querystring');
var URL  = require('url');
var http = require('http');

export class Http extends Base {

  static var TIMEOUT  = 10000;
  static var INTERVAL = 10000;

  static function getRequestOptions(config) {
    var method = 'get';

    if (config.post) {
      method = 'post';
    } else if (config.put) {
      method = 'put';
    } 

    // setup data
    var params = config[method];
    for (var key in params) {
      if (typeof params[key] == 'object') {
        params[key] = JSON.stringify(params[key]);
      }
    }

    var data = params ? QS.stringify(params) : null;
    var url  = config.url;

    if (method == 'get' && data) {
      url = url + '?' + data; 
    } 

    var parsedUrl = URL.parse(url, false);
    var host = config.host || parsedUrl.host || '127.0.0.1';
    host = host.replace(/\:\d+$/, '');

    return {
      host: host,
      port: config.port || parsedUrl.port || 80,
      path: parsedUrl.pathname + (parsedUrl.query ? '?' + parsedUrl.query: ''),
      method: method.toUpperCase()
    };
  }

  function execute(values, data, fn) {
    if (values == null) {
      return true;
    }

    else if (typeof values == "string") {
      return fn(values, data);
    }

    else {
      var ret = true;
      for (var i in values) {
        ret = ret && fn(values[i], data);
      }
      return ret;
    }
  }

  function initialize(config) {
    this.interval = config.interval || 5000;
    this.timeout  = config.timeout  || 1000;
    this.method   = 'get';
    this.matches  = config.matches;
    this.lambda   = config.lambda;
    this.status   = config.status || '200';
    

    this.options = KLASS.getRequestOptions(config);
    this.url = "http://" + this.options.host + ':' + this.options.port + this.options.path;

    this.id = this.url;
  }

  function getRequest(callback) {
    return http.request(this.options, callback);
  }

  function check(callback) {
    var $this = this;
    
    this.req = this.getRequest(#(resp) { 
      var data = [];
      resp.on('data', #{ data.push($1) });
      resp.on('end',  #{
        $this.calculatePass(resp, data.join(''), #(passed) {
          callback(passed);
        });
      }); 
    });

    if (this.data) this.req.write(this.data + "\n");

    this.req.on('error', #{ callback(false) });
    this.req.end();
  }

  function calculatePass(resp, data, callback) {
    var matches = this.execute(this.matches, data, #(regex, data) {
      var match = new RegExp(regex);
      return match.test(data);
    });

    var test = this.execute(this.lambda, data, #(fn, data) {
      try {
        eval('var lambda = ' + fn);
        var ret = lambda(data);
        return ret;
      } catch (e) {
        console.log("Error in test: " + config.lambda);
        console.log(e.stack);
      }
    });

    var stat    = resp.statusCode == this.status;

    if (!matches) console.log("Failed to match regex " + this.matches.toString());
    if (!test) console.log("Failed to pass the given lambda!");
    if (!stat) console.log("Failed to get " + this.status + " from: " + this.url + " --- " + resp.statusCode);

    return callback(matches && test && stat);
  }

  function clear() {
    if (this.req) this.req.end();
  }
}
