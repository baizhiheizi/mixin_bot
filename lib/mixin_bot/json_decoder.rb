# frozen_string_literal: true

module MixinBot
  # json 3.x made +JSON.parse+ keyword-only, while faraday's JSON middleware
  # calls its decoder with positional options. Splatted keywords keep this
  # compatible with both json 2.x and 3.x.
  module JSONDecoder
    module_function

    def parse(body, options = {})
      JSON.parse(body, **options)
    end
  end
end
