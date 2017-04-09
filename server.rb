require 'net/http'
require 'pp'
require 'pry'
require 'webrick'
server = WEBrick::HTTPServer.new(:Port=>8080)
server.mount_proc('/session'){ |req, resp|
  if req.request_method == 'POST'
    sessions[i] = Session.new
    i+=1
    server.mount_proc("/session/#{}") { |req, resp|
      
    }
  end
  
  if req.request_method == 'DELETE'
    sessions[i] = Session.new
    i+=1
    server.mount_proc("/session/#{}") { |req, resp|
      
    }
  end
}

server.start
