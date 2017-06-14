require 'json'

module WEBrick
  ##
  # An HTTP response.  This is filled in by the service or do_* methods of a
  # WEBrick HTTP Servlet.

  class HTTPResponse
    def set_error(ex, backtrace=false)
      case ex
      when HTTPStatus::Status
        @keep_alive = false if HTTPStatus::error?(ex.code)
        self.status = ex.code
      else
        @keep_alive = false
        self.status = HTTPStatus::RC_INTERNAL_SERVER_ERROR
      end
      @header['content-type'] = 'application/json'


      if @request_uri
        host, port = @request_uri.host, @request_uri.port
      else
        host, port = @config[:ServerName], @config[:Port]
      end

      error_body(ex, host, port)
    end

    private

    # :stopdoc:

    def error_body(ex, host, port)
      body = {}
      body[:title] = HTMLUtils::escape(@reason_phrase)
      body[:message] = HTMLUtils::escape(ex.message)
      body[:server_software] = HTMLUtils::escape(@config[:ServerSoftware])
      body[:address] = { host: host, port: port }
      @body = JSON.generate body
    end

  end
  module HTTPServlet
    class ProcHandler
      alias do_DELETE do_POST
    end
  end
end
