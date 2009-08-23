require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ConnectionPossibilityRequest do
  before(:each) do
    @valid_attributes = {
      :created_by_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    ConnectionPossibilityRequest.create!(@valid_attributes)
  end
end
