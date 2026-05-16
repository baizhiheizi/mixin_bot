# frozen_string_literal: true

##
# In-memory conversation graph for offline WebMock conversation tests.
#
module ConversationStubState
  module_function

  def reset!
    @groups = {}
  end

  def group(cid)
    @groups[cid] ||= {
      'conversation_id' => cid,
      'name' => '',
      'announcement' => '',
      'participants' => [],
      'code_id' => SecureRandom.uuid
    }
  end

  def touch_rotate!(cid)
    g = group(cid)
    g['code_id'] = SecureRandom.uuid
    g
  end

  reset!
end
