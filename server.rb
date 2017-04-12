require 'net/http'
require 'pp'
require 'pry'
require 'webrick'
require 'securerandom'
require 'json'

require_relative 'session'

server = WEBrick::HTTPServer.new(:Port=>4328)

@sessions = Hash.new
@elements = Hash.new

server.mount_proc('/wd/hub/session'){ |req, resp|
  if req.request_method == 'POST'
    uuid = SecureRandom.uuid
    @sessions[uuid] = Hash.new
    @sessions[uuid][:session] = Session.new(uuid, nil)

    server.mount_proc("/wd/hub/session/#{uuid}/back"){ |req, resp|
      @sessions[uuid][:session].back

      resp_hash = { sessionId: uuid, status: 0 }
      resp['Content-Type'] = 'application/json'
      resp.status = 200
      resp.body = JSON.generate(resp_hash)
    }

    server.mount_proc("/wd/hub/session/#{uuid}/source"){ |req, resp|
      resp_hash = { sessionId: uuid, status: 0, value: @sessions[uuid][:session].source }
      resp['Content-Type'] = 'application/json'
      resp.status = 200
      resp.body = JSON.generate(resp_hash)
    }

    resp_hash = { sessionId: uuid, value: new_session_hash, status: 0 }
    resp['Content-Type'] = 'application/json'
    resp.status = 200
    resp.body = JSON.generate(resp_hash)

    add_element(server, uuid, @sessions[uuid][:session])
    add_elements(server, uuid, @sessions[uuid][:session])
  end
  #if req.request_method == 'DELETE'
  #  uuid = JSON.parse(req.body)
  #  server.umount("/session/#{uuid}")
  #end
}

def add_element(server, path, object)
  server.mount_proc("/wd/hub/session/#{path}/element") do |req, resp|
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

def add_text(server, uuid, el_uuid)
  server.mount_proc("/wd/hub/session/#{uuid}/element/#{el_uuid}/text") do |req, resp|
    resp_hash ={ status: 0, value: @elements[el_uuid].text }
    resp['Content-Type'] = 'application/json'
    resp.body = JSON.generate(resp_hash)
    resp.status = 200
  end
end

def new_session_hash
    resp_hash = Hash.new
    resp_hash[:browserName] = 'Chrome'
    resp_hash[:version] = '1.0'
    resp_hash[:platform] = 'Android'
    resp_hash[:javascriptEnabled] = 'false'
    resp_hash[:cssSelectorsEnabled] = 'false'
    resp_hash[:takesScreenshot] = 'true'
    resp_hash[:nativeEvents] = 'true'
    resp_hash[:rotatable] = 'true'
    resp_hash
end

def parse_locator(json)
  hash_from_json = JSON.parse(json)

  values_in_array = hash_from_json.values
  new_locator = { values_in_array.first.downcase.tr(" ", "_").to_sym => values_in_array.last }
end

server.start
