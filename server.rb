require 'net/http'
require 'pp'
require 'pry'
require 'webrick'
require 'securerandom'
require 'json'
require 'base64'

require_relative 'session'

server = WEBrick::HTTPServer.new(:Port=>4328)
trap 'INT' do server.shutdown end

@sessions = Hash.new
@elements = Hash.new

server.mount_proc('/wd/hub/session'){ |req, resp|
  if req.request_method == 'POST'
    server.logger.info "New session request"

    uuid = SecureRandom.uuid
    capabilites = JSON.parse(req.body)

    server.logger.info "Creating session with capabilites: #{capabilites}"

    @sessions[uuid] = Hash.new
    @sessions[uuid][:session] = Session.new(uuid, capabilites["desiredCapabilities"], server.logger)

    server.logger.info "New session created"

    server.mount_proc("/wd/hub/session/#{uuid}/execute"){ |req, resp|
      server.logger.info "Executing script #{req.body}"

      resp_hash = { sessionid: uuid, value: @sessions[uuid][:session].execute(JSON.parse(req.body)), status: 0 }
      resp['Content-Type'] = 'application/json'
      resp.status = 200
      resp.body = JSON.generate(resp_hash)
    }

    server.mount_proc("/wd/hub/session/#{uuid}/back"){ |req, resp|
      server.logger.info 'pressing back button'
      @sessions[uuid][:session].back

      resp_hash = { sessionId: uuid, status: 0 }
      resp['Content-Type'] = 'application/json'
      resp.status = 200
      resp.body = JSON.generate(resp_hash)
    }

    server.mount_proc("/wd/hub/session/#{uuid}/screenshot"){ |req, resp|
      server.logger.info 'Taking screenshot'
      @sessions[uuid][:session].take_screenshot

      resp_hash = { sessionId: uuid, value: Base64.encode64(File.read('temp/screenshot.png')), status: 0 }
      resp['Content-Type'] = 'application/json'
      resp.status = 200
      resp.body = JSON.generate(resp_hash)
    }

    server.mount_proc("/wd/hub/session/#{uuid}/source"){ |req, resp|
      server.logger.info "Taking screen source"
      resp_hash = { sessionId: uuid, status: 0, value: @sessions[uuid][:session].source }
      resp['Content-Type'] = 'application/json'
      resp.status = 200
      resp.body = JSON.generate(resp_hash)
    }

    resp_hash = { sessionId: uuid, value: NEW_SESSION_HASH, status: 0 }
    resp['Content-Type'] = 'application/json'
    resp.status = 200
    resp.body = JSON.generate(resp_hash)

    add_element(server, uuid, @sessions[uuid][:session])
    add_elements(server, uuid, @sessions[uuid][:session])
  end
}

def add_element(server, path, object)
  server.mount_proc("/wd/hub/session/#{path}/element") do |req, resp|
    server.logger.info "Searching element with parameters: #{req.body}"

    found_element = object.element(parse_locator req.body)

    el_uuid = SecureRandom.uuid
    @elements[el_uuid] = found_element

    add_element(server, "#{path}/element/#{el_uuid}", @elements[el_uuid])
    add_elements(server, "#{path}/element/#{el_uuid}", @elements[el_uuid])
    add_click(server, path.split('/').first, el_uuid)
    add_text(server, path.split('/').first, el_uuid)

    resp_hash = { sessionId: path.split('/').first, status: 0, value: { ELEMENT: el_uuid } }
    resp['Content-Type'] = 'application/json'
    resp.status = 200
    resp.body = JSON.generate(resp_hash)

    server.logger.info "Resposing client with #{resp.body}"
  end
end

def add_elements(server, path, object)
  server.mount_proc("/wd/hub/session/#{path}/elements") do |req, resp|
    found_elements = object.elements(parse_locator req.body)

    array_of_els_uuid = []
    found_elements.each do |element|
      el_uuid = SecureRandom.uuid
      @elements[el_uuid] = element
      array_of_els_uuid.push el_uuid

      add_element(server, "#{path}/element/#{el_uuid}", @elements[el_uuid])
      add_elements(server, "#{path}/element/#{el_uuid}", @elements[el_uuid])
      add_click(server, path.split('/').first, el_uuid)
      add_text(server, path.split('/').first, el_uuid)
    end

    resp_hash = { sessionId: path.split('/').first, value: [], status: 0 }

    array_of_els_uuid.each do |element|
      el_hash = { ELEMENT: element }
      resp_hash[:value].push el_hash
    end

    resp['Content-Type'] = 'application/json'
    resp.status = 200
    resp.body = JSON.generate(resp_hash)
  end
end

def add_click(server, session_uuid, el_uuid)
  server.mount_proc("/wd/hub/session/#{session_uuid}/element/#{el_uuid}/click") do |req, resp|
    @elements[el_uuid].click
    resp_hash ={ status: 0 }
    resp['Content-Type'] = 'application/json'
    resp.body = JSON.generate(resp_hash)
    resp.status = 200
  end
end

def add_text(server, session_uuid, el_uuid)
  server.mount_proc("/wd/hub/session/#{session_uuid}/element/#{el_uuid}/text") do |req, resp|
    resp_hash ={ status: 0, value: @elements[el_uuid].text }
    resp['Content-Type'] = 'application/json'
    resp.body = JSON.generate(resp_hash)
    resp.status = 200
  end
end

NEW_SESSION_HASH = { :browserName => 'Chrome',
                     :version => '1.0',
                     :platform => 'Android',
                     :javascriptEnabled => 'false',
                     :cssSelectorsEnabled => 'false',
                     :takesScreenshot => 'true',
                     :nativeEvents => 'true',
                     :rotatable => 'true' }

def parse_locator(json)
  hash_from_json = JSON.parse(json)

  values_in_array = hash_from_json.values
  new_locator = { values_in_array.first.downcase.tr(" ", "_").to_sym => values_in_array.last }
end

server.start
