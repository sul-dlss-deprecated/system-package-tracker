require 'puppetdb'
class Stack

  def self.endpoint
    'http://sulpuppet4-db.stanford.edu:8080'
  end

  # in eyaml a fact for a machine looks like:
  # stack: 'exhibits'
  # and in puppetdb that fact looks like:
  # {"value" : "exhibits", "name" : "stack", "certname" : "exhibits-prod-a.stanford.edu"}

  def self.members(stack_name)
    client = PuppetDB::Client.new(server: Stack.endpoint)
    response = client.request('facts', ['and', ['=', 'name', 'stack'], ['=', 'value', stack_name]])
    response.data.collect { |x| x['certname'] }
  end

end
