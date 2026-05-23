# frozen_string_literal: true

##
# Configurable app billing/properties payloads for offline WebMock tests.
#
module AppBillingStubState
  module_function

  def reset!
    @credit = '1000'
    @cost_users = '0'
    @cost_resources = '0'
    @price = '0'
  end

  def configure(credit: nil, cost_users: nil, cost_resources: nil, price: nil)
    @credit = credit if credit
    @cost_users = cost_users unless cost_users.nil?
    @cost_resources = cost_resources unless cost_resources.nil?
    @price = price unless price.nil?
  end

  def billing_payload(app_id)
    {
      'app_id' => app_id,
      'credit' => @credit,
      'cost' => {
        'users' => @cost_users,
        'resources' => @cost_resources
      }
    }
  end

  def properties_payload
    {
      'count' => '0',
      'price' => @price
    }
  end

  reset!
end
