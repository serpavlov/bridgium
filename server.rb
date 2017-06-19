require 'net/http'
require 'pp'
require 'pry'
require 'webrick'
require 'securerandom'
require 'json'
require 'base64'

require_relative 'session'
require_relative 'webrick'

server = WEBrick::HTTPServer.new(Port: 4328)
trap('INT') { server.shutdown }

@sessions = {}

temp_hash = { browserName: 'Chrome',
              version: '1.0',
              platform: 'Android',
              javascriptEnabled: 'false',
              cssSelectorsEnabled: 'false',
              takesScreenshot: 'true',
              nativeEvents: 'true',
              rotatable: 'true' }

NEW_SESSION_HASH = temp_hash

server.mount_proc('/wd/hub/session') do |req, resp|
  if req.path == '/wd/hub/session'
    if req.request_method == 'POST'
      server.logger.info 'New session request'

      uuid = SecureRandom.uuid
      capabilites = JSON.parse(req.body)

      server.logger.info "Creating session with capabilites: #{capabilites}"

      @sessions[uuid] = {}
      @sessions[uuid][:session] = Session.new(capabilites['desiredCapabilities'],
                                              server.logger)
      @sessions[uuid][:elements] = {}

      server.logger.info 'New session created'

      add_session(server, uuid)
      add_execute(server, uuid)
      add_screenshot(server, uuid)
      add_source(server, uuid)
      add_back(server, uuid)
      resp_hash = { sessionId: uuid,
                    value: NEW_SESSION_HASH,
                    status: 0 }
      resp['Content-Type'] = 'application/json'
      resp.status = 200
      resp.body = JSON.generate(resp_hash)

      add_element(server, uuid, @sessions[uuid][:session])
      add_elements(server, uuid, @sessions[uuid][:session])
    end
  else
    resp_hash = { status: 9,
                  value: 'UnknownCommand' }
    resp['Content-Type'] = 'application/json'
    resp.status = 404
    resp.body = JSON.generate(resp_hash)
  end
end

def add_session(server, session_uuid)
  server.mount_proc("/wd/hub/session/#{session_uuid}") do |req, resp|
    if req.path == "/wd/hub/session/#{session_uuid}"
      if req.request_method == 'GET'
        server.logger.info 'Client requiesting session capabilites'
        resp_hash = { sessionid: session_uuid,
                      value: @sessions[session_uuid][:session].caps,
                      status: 0 }
        resp['Content-Type'] = 'application/json'
        resp.status = 200
        resp.body = JSON.generate(resp_hash)
      elsif req.request_method == 'DELETE'
        server.logger.info 'Client deleting session'

        @sessions[session_uuid][:elements].keys.each do |element_uuid|
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/element")
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/elements")
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/click")
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/text")
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/displayed")
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/enabled")
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/value")
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/value")
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/size")
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/location")
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/attribute")
          server.umount("/wd/hub/session/#{session_uuid}/element/#{element_uuid}/clear")
        end
        server.umount("/wd/hub/session/#{session_uuid}")
        server.umount("/wd/hub/session/#{session_uuid}/element")
        server.umount("/wd/hub/session/#{session_uuid}/elements")
        server.umount("/wd/hub/session/#{session_uuid}/execute")
        server.umount("/wd/hub/session/#{session_uuid}/screenshot")
        server.umount("/wd/hub/session/#{session_uuid}/back")
        server.umount("/wd/hub/session/#{session_uuid}/source")

        @sessions.delete session_uuid
        resp_hash = { sessionid: session_uuid,
                      status: 0 }
        resp['Content-Type'] = 'application/json'
        resp.status = 200
        resp.body = JSON.generate(resp_hash)
      end
    else
      resp_hash = { status: 6,
                    value: 'NoSuchDriver' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_execute(server, session_uuid)
  server.mount_proc("/wd/hub/session/#{session_uuid}/execute") do |req, resp|
    if req.path == "/wd/hub/session/#{session_uuid}/execute"
      if req.request_method == 'POST'
        server.logger.info "Executing script #{req.body}"
        command = JSON.parse(req.body)
        resp_hash = { sessionid: session_uuid,
                      value: @sessions[session_uuid][:session].execute(command),
                      status: 0 }
        resp['Content-Type'] = 'application/json'
        resp.status = 200
        resp.body = JSON.generate(resp_hash)
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_screenshot(server, session_uuid)
  server.mount_proc("/wd/hub/session/#{session_uuid}/screenshot") do |req, resp|
    if req.path == "/wd/hub/session/#{session_uuid}/screenshot"
      if req.request_method == 'GET'
        server.logger.info 'Taking screenshot'
        @sessions[session_uuid][:session].take_screenshot
        resp_hash = { sessionId: session_uuid,
                      value: Base64.encode64(File.read('temp/screenshot.png')),
                      status: 0 }
        resp['Content-Type'] = 'application/json'
        resp.status = 200
        resp.body = JSON.generate(resp_hash)
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_back(server, session_uuid)
  server.mount_proc("/wd/hub/session/#{session_uuid}/back") do |req, resp|
    if req.path == "/wd/hub/session/#{session_uuid}/back"
      if req.request_method == 'POST'
        server.logger.info 'pressing back button'
        @sessions[session_uuid][:session].back

        resp_hash = { sessionId: session_uuid, status: 0 }
        resp['Content-Type'] = 'application/json'
        resp.status = 200
        resp.body = JSON.generate(resp_hash)
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_source(server, session_uuid)
  server.mount_proc("/wd/hub/session/#{session_uuid}/source") do |req, resp|
    if req.path == "/wd/hub/session/#{session_uuid}/source"
      if req.request_method == 'GET'
        server.logger.info 'Taking screen source'
        resp_hash = { sessionId: session_uuid,
                      status: 0,
                      value: @sessions[session_uuid][:session].source }
        resp['Content-Type'] = 'application/json'
        resp.status = 200
        resp.body = JSON.generate(resp_hash)
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_element(server, path, object)
  server.mount_proc("/wd/hub/session/#{path}/element") do |req, resp|
    if req.path == "/wd/hub/session/#{path}/element"
      if req.request_method == 'POST'
        server.logger.info "Searching element with parameters: #{req.body}"

        found_element = object.find_element(parse_locator(req.body))

        if found_element
          el_uuid = SecureRandom.uuid
          @sessions[path][:elements][el_uuid] = found_element

          add_element(server, "#{path}/element/#{el_uuid}", @sessions[path][:elements][el_uuid])
          add_elements(server, "#{path}/element/#{el_uuid}", @sessions[path][:elements][el_uuid])
          add_subrequests(server, path.split('/').first, el_uuid)

          resp_hash = { sessionId: path.split('/').first,
                        status: 0,
                        value: { ELEMENT: el_uuid } }
          resp.status = 200
        else
          resp_hash = { sessionId: path.split('/').first,
                        status: 7 }
          resp.status = 404
        end
        resp['Content-Type'] = 'application/json'

        resp.body = JSON.generate(resp_hash)

        server.logger.info "Reposing client with #{resp.body}"
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_elements(server, path, object)
  server.mount_proc("/wd/hub/session/#{path}/elements") do |req, resp|
    if req.path == "/wd/hub/session/#{path}/elements"
      if req.request_method == 'POST'
        found_elements = object.find_elements(parse_locator(req.body))

        array_of_els_uuid = []
        found_elements.each do |element|
          el_uuid = SecureRandom.uuid
          @sessions[path][:elements][el_uuid] = element
          array_of_els_uuid.push el_uuid

          add_element(server, "#{path}/element/#{el_uuid}", @sessions[path][:elements][el_uuid])
          add_elements(server, "#{path}/element/#{el_uuid}", @sessions[path][:elements][el_uuid])
          add_subrequests(server, path.split('/').first, el_uuid)
        end

        resp_hash = { sessionId: path.split('/').first,
                      value: [],
                      status: 0 }

        array_of_els_uuid.each do |element|
          el_hash = { ELEMENT: element }
          resp_hash[:value].push el_hash
        end

        resp['Content-Type'] = 'application/json'
        resp.status = 200
        resp.body = JSON.generate(resp_hash)
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_subrequests(server, path, el_uuid)
  add_click(server, path, el_uuid)
  add_text(server, path, el_uuid)
  add_attribute(server, path, el_uuid)
  add_clear(server, path, el_uuid)
  add_displayed(server, path, el_uuid)
  add_enabled(server, path, el_uuid)
  add_size(server, path, el_uuid)
  add_location(server, path, el_uuid)
  add_value(server, path, el_uuid)
end

def add_click(server, session_uuid, el_uuid)
  path = "/wd/hub/session/#{session_uuid}/element/#{el_uuid}/click"
  server.mount_proc(path) do |req, resp|
    if req.path == path
      if req.request_method == 'POST'
        @sessions[session_uuid][:elements][el_uuid].click
        resp_hash = { status: 0 }
        resp['Content-Type'] = 'application/json'
        resp.body = JSON.generate(resp_hash)
        resp.status = 200
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_clear(server, session_uuid, el_uuid)
  path = "/wd/hub/session/#{session_uuid}/element/#{el_uuid}/clear"
  server.mount_proc(path) do |req, resp|
    if req.path == path
      if req.request_method == 'POST'
        @sessions[session_uuid][:elements][el_uuid].clear
        resp_hash = { status: 0 }
        resp['Content-Type'] = 'application/json'
        resp.body = JSON.generate(resp_hash)
        resp.status = 200
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_displayed(server, session_uuid, el_uuid)
  path = "/wd/hub/session/#{session_uuid}/element/#{el_uuid}/displayed"
  server.mount_proc(path) do |req, resp|
    if req.path == path
      if req.request_method == 'GET'
        resp_hash = { status: 0, value: @sessions[session_uuid][:elements][el_uuid].displayed? }
        resp['Content-Type'] = 'application/json'
        resp.body = JSON.generate(resp_hash)
        resp.status = 200
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_enabled(server, session_uuid, el_uuid)
  path = "/wd/hub/session/#{session_uuid}/element/#{el_uuid}/enabled"
  server.mount_proc(path) do |req, resp|
    if req.path == path
      if req.request_method == 'GET'
        resp_hash = { status: 0, value: @sessions[session_uuid][:elements][el_uuid].enabled? }
        resp['Content-Type'] = 'application/json'
        resp.body = JSON.generate(resp_hash)
        resp.status = 200
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_size(server, session_uuid, el_uuid)
  path = "/wd/hub/session/#{session_uuid}/element/#{el_uuid}/size"
  server.mount_proc(path) do |req, resp|
    if req.path == path
      if req.request_method == 'GET'
        resp_hash = { status: 0, value: @sessions[session_uuid][:elements][el_uuid].size }
        resp['Content-Type'] = 'application/json'
        resp.body = JSON.generate(resp_hash)
        resp.status = 200
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_location(server, session_uuid, el_uuid)
  path = "/wd/hub/session/#{session_uuid}/element/#{el_uuid}/location"
  server.mount_proc(path) do |req, resp|
    if req.path == path
      if req.request_method == 'GET'
        resp_hash = { status: 0, value: @sessions[session_uuid][:elements][el_uuid].location }
        resp['Content-Type'] = 'application/json'
        resp.body = JSON.generate(resp_hash)
        resp.status = 200
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_value(server, session_uuid, el_uuid)
  path = "/wd/hub/session/#{session_uuid}/element/#{el_uuid}/value"
  server.mount_proc(path) do |req, resp|
    if req.path == path
      if req.request_method == 'POST'
        requested_value = JSON.parse req.body
        @sessions[session_uuid][:elements][el_uuid].send_keys requested_value['value'].first
        resp_hash = { status: 0 }
        resp['Content-Type'] = 'application/json'
        resp.body = JSON.generate(resp_hash)
        resp.status = 200
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def add_attribute(server, session_uuid, el_uuid)
  path = "/wd/hub/session/#{session_uuid}/element/#{el_uuid}/attribute"
  server.mount_proc(path) do |req, resp|
    if req.request_method == 'GET'
      requested_attribute = req.path.split('/').last
      resp_hash = { status: 0,
                    value: @sessions[session_uuid][:elements][el_uuid].attribute(requested_attribute) }
      resp['Content-Type'] = 'application/json'
      resp.body = JSON.generate(resp_hash)
      resp.status = 200
    end
  end
end

def add_text(server, session_uuid, el_uuid)
  path = "/wd/hub/session/#{session_uuid}/element/#{el_uuid}/text"
  server.mount_proc(path) do |req, resp|
    if req.path == path
      if req.request_method == 'GET'
        resp_hash = { status: 0, value: @sessions[session_uuid][:elements][el_uuid].text }
        resp['Content-Type'] = 'application/json'
        resp.body = JSON.generate(resp_hash)
        resp.status = 200
      end
    else
      resp_hash = { status: 9,
                    value: 'UnknownCommand' }
      resp['Content-Type'] = 'application/json'
      resp.status = 404
      resp.body = JSON.generate(resp_hash)
    end
  end
end

def parse_locator(json)
  hash_from_json = JSON.parse(json)

  values_in_array = hash_from_json.values
  { values_in_array.first.downcase.tr(' ', '_').to_sym => values_in_array.last }
end

server.start
