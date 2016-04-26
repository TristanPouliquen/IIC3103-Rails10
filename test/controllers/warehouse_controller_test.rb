require 'test_helper'

class WarehouseControllerTest < ActionController::TestCase
  test "should get warehouses" do
    get :warehouses
    assert_response :success
  end

end
