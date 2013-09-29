shared_examples "message id collection" do |expected_length|
  it "should be a collection of #{expected_length} ID#{expected_length == 1 ? "" : "s"}" do
    expect(subject).to_not be_empty
    expect(subject.count).to eq(expected_length)
    subject.each do |id|
      expect(id).to be_an_instance_of(String)

      # NOTE: The API docs specifically say to not expect a particular format for the IDs,
      # but I'll put this here anyways just to make sure the values are right, without
      # having to query the API for each one.
      expect(id).to match(/^[0-9a-f]{24}$/)
    end
  end
end
