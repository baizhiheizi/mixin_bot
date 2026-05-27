# frozen_string_literal: true

module MixinBot
  class Client
    ##
    # Maps Mixin API +error+ objects to Ruby exceptions.
    #
    module ErrorMapper
      CODE_MAP = {
        400 => ValidationError,
        401 => UnauthorizedError,
        403 => ForbiddenError,
        404 => NotFoundError,
        429 => RateLimitError,
        10_002 => ValidationError,
        10_006 => AppUpdateRequiredError,
        10_104 => TransientError,
        10_105 => TransientError,
        10_404 => UserNotFoundError,
        20_116 => ConflictError,
        20_117 => InsufficientBalanceError,
        20_118 => PinError,
        20_119 => PinError,
        20_120 => TransferError,
        20_121 => UnauthorizedError,
        20_123 => ConflictError,
        20_124 => InsufficientBalanceError,
        20_125 => ConflictError,
        20_127 => TransferError,
        20_131 => ValidationError,
        20_133 => ConflictError,
        20_134 => TransferError,
        20_135 => TransferError,
        20_150 => ValidationError,
        30_102 => InvalidAddressFormatError,
        30_103 => InsufficientPoolError,
        500 => ServerError,
        7000 => ServerError,
        7001 => ServerError
      }.freeze

      module_function

      def raise_for!(verb:, path:, body:, response:, result:)
        err = result['error'] || {}
        code = err['code']&.to_i
        klass = CODE_MAP[code] || default_class_for_code(code)
        raise APIError.build(klass, verb:, path:, body:, response:, result:)
      end

      def build(klass, verb:, path:, body:, response:, result:, **)
        APIError.build(klass, verb:, path:, body:, response:, result:, **)
      end

      def default_class_for_code(_code)
        ResponseError
      end
    end
  end
end
