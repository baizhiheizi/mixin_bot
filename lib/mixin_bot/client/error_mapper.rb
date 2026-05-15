# frozen_string_literal: true

module MixinBot
  class Client
    ##
    # Maps Mixin API +error+ objects to Ruby exceptions.
    #
    module ErrorMapper
      module_function

      def raise_for!(verb:, path:, body:, response:, result:)
        err = result['error'] || {}
        code = err['code']
        desc = err['description']
        req_id = response&.headers&.[]('X-Request-Id')
        srv_time = response&.headers&.[]('X-Server-Time')
        errmsg = "#{verb.upcase} | #{path} | #{body}, errcode: #{code}, errmsg: #{desc}, request_id: #{req_id}, server_time: #{srv_time}"

        case code
        when 401, 20_121
          raise UnauthorizedError, errmsg
        when 403, 20_116, 10_002, 429
          raise ForbiddenError, errmsg
        when 404
          raise NotFoundError, errmsg
        when 20_117
          raise InsufficientBalanceError, errmsg
        when 20_118, 20_119
          raise PinError, errmsg
        when 30_103
          raise InsufficientPoolError, errmsg
        when 10_404
          raise UserNotFoundError, errmsg
        else
          raise ResponseError, errmsg
        end
      end
    end
  end
end
