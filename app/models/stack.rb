require 'puppetdb'
class Stack

  def self.endpoint
    'http://sulpuppet-db.stanford.edu:8080'
  end

  def self.client
    PuppetDB::Client.new(server: endpoint)
  end

  # in eyaml a fact for a machine looks like:
  # stack: 'exhibits'
  # and in puppetdb that fact looks like:
  # {"value" : "exhibits", "name" : "stack", "certname" : "exhibits-prod-a.stanford.edu"}

  def self.members(stack_name)
    response = client.request('facts', ['and', ['=', 'name', 'stack'], ['=', 'value', stack_name]])
    response.data.collect { |x| x['certname'] }
  end

  def self.all
    response = client.request('facts', ['=', 'name', 'stack'])
    response.data.collect { |x| x['value'] }.uniq
  end

  def self.empties
    report = []
    all.each do |stack|
      report << stack if members(stack).empty?
    end
    report
  end

  def self.orphans
    all_nodes_response = client.request('facts', ['=', 'name', 'hostname'])
    all_nodes = all_nodes_response.data.collect { |x| x['certname'] }
    non_orphan_response = client.request('facts', ['=', 'name', 'stack'])
    stack_nodes = non_orphan_response.data.collect { |x| x['certname'] }
    all_nodes - stack_nodes
  end
end
