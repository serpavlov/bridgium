require 'net/http'
require 'pp'
require 'pry'
require 'webrick'
require 'securerandom'
require 'json'

require_relative 'session'

server = WEBrick::HTTPServer.new(:Port=>4328)

sessions = Hash.new
elements = Hash.new

server.mount_proc('/wd/hub/session'){ |req, resp|
  if req.request_method == 'POST'
    uuid = SecureRandom.uuid
    sessions[uuid] = Hash.new
    sessions[uuid][:session] = Session.new(uuid, nil)
    resp_hash = Hash.new
    resp_hash[:sessionId] = uuid
    resp_hash[:value] = new_session_hash
    resp_hash[:status] = 0

    resp['Content-Type'] = 'application/json'
    resp.status = 200
    resp.body = JSON.generate(resp_hash)

    server.mount_proc("/wd/hub/session/#{uuid}/element") do |req, resp|
      locator = JSON.parse(req.body)

      values_of_json = locator.values
      new_locator = Hash.new
      new_locator[values_of_json.first.downcase.tr!(" ", "_").to_sym] = values_of_json.last
      found_element = sessions[uuid][:session].element(new_locator)

      el_uuid = SecureRandom.uuid
      elements[el_uuid] = found_element

      server.mount_proc("/wd/hub/session/#{uuid}/element/#{el_uuid}/click") do |req, resp|
        elements[el_uuid].click
        resp_hash[:status] = 0
        resp['Content-Type'] = 'application/json'
        resp.body = JSON.generate(resp_hash)
        resp.status = 200
      end

      resp_hash = Hash.new
      resp_hash[:sessionId] = uuid
      resp_hash[:status] = 0
      resp_hash[:value] = Hash.new
      resp_hash[:value][:ELEMENT] = el_uuid
      resp['Content-Type'] = 'application/json'
      resp.status = 200
      resp.body = JSON.generate(resp_hash)
    end

    server.mount_proc("/wd/hub/session/#{uuid}/elements") do |req, resp|
      locator = JSON.parse(req.body)

      values_of_json = locator.values
      new_locator = Hash.new
      new_locator[values_of_json.first.downcase.tr!(" ", "_").to_sym] = values_of_json.last
      found_elements = sessions[uuid][:session].elements(new_locator)

      array_of_els_uuid = Array.new
      found_elements.each do |element|
        el_uuid = SecureRandom.uuid
        elements[el_uuid] = element
        array_of_els_uuid.push el_uuid

        server.mount_proc("/wd/hub/session/#{uuid}/element/#{el_uuid}/click") do |req, resp|
          elements[el_uuid].click
          resp_hash[:status] = 0
          resp['Content-Type'] = 'application/json'
          resp.body = JSON.generate(resp_hash)
          resp.status = 200
        end
      end

      resp_hash = Hash.new
      resp_hash[:sessionId] = uuid
      resp_hash[:value] = Array.new
      resp_hash[:status] = 0
      array_of_els_uuid.each do |element|
        el_hash = Hash.new
        el_hash[:ELEMENT] = element
        resp_hash[:value].push el_hash
      end
      resp['Content-Type'] = 'application/json'
      resp.status = 200
      resp.body = JSON.generate(resp_hash)
    end
  end
  if req.request_method == 'DELETE'
    uuid = JSON.parse(req.body)
    server.umount("/session/#{uuid}")
  end
}

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

server.start
