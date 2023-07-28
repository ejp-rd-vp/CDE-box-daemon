require './CDE_Transform'
require 'sinatra'
require 'rest-client'
require './http_utils'
require 'open3'

include HTTPUtils

get '/' do
  update
  hefesto
  yarrrml_substitute
  execute
  load_cde
  cleanup
  metadata_update
  "Execution complete.  See docker log for errors (if any)\n\n"
end

def update
  warn 'first open3 git pull'
  o, e, _s = Open3.capture3('cd CDE-semantic-model-implementations && git pull')
  warn "second open3 copy yarrrml #{o}  #{e}"
  # o, e, _s = Open3.capture3('cp -rf ./CDE-semantic-model-implementations/YARRRML_Transform_Templates/templates/*.yaml  /config')   # CDE V1
  o, e, _s = Open3.capture3('cp -rf ./CDE-semantic-model-implementations/CDE_version_2.0.0/YARRRML/CDE_yarrrml_template.yaml  /config') # CDE V2
  warn "second open3 complete #{o} #{e}"
end

def hefesto
  datatype_list = Dir['/data/preCSV.csv']
  datatype_list.each do |d|  # now it is always '/data/preCSV.csv'... but maybe one day we will be more flexible?
    datatype = d.match(%r{.+/([^.]+)\.csv})[1]
    next unless datatype

    _res = RestClient.post('http://hefesto:8000/hefesto-fiab', '{}')
    sleep 3
  end
end

def yarrrml_substitute
  template_list = Dir['/conf/CSV_yarrrml_template.yaml']
  baseURI = ENV.fetch('baseURI', 'http://example.org/')
  template_list.each do |t|  # now it is always /conf/CSV_yarrrml_template.yaml... but maybe one day we will be more flexible?
    content = File.read(t)
    content.gsub!('|||baseURI|||', baseURI)
    f = File.write('/data/CSV_yarrrml.yaml')
    f.puts content
    f.close
  end
end

def execute
  purge_nt
  datatype_list = Dir['/data/*.csv']
  datatype_list.each do |d|
    datatype = d.match(%r{.+/([^.]+)\.csv})[1]
    next unless datatype

    _resp = RestClient.get("http://yarrrml-rdfizer:4567/#{datatype}")
  end
end

def load_cde
  files = Dir['/data/triples/*.nt']
  concatenated = ''
  files.each do |f|
    warn "Processing file #{f}"
    content = File.read(f)
    concatenated += content
    warn "The length of the content to upload is now #{concatenated.length}"
  end
  File.write('/tmp/check.nt', concatenated)

  # write_to_graphdb(concatenated)
end

def write_to_graphdb(concatenated)
  user = ENV.fetch('GraphDB_User', nil)
  pass = ENV.fetch('GraphDB_Pass', nil)
  network = ENV['networkname'] || 'graphdb'
  url = "http://#{network}:7200/repositories/cde/statements"
  #  headers = { content_type: 'application/n-triples' }
  headers = { content_type: 'application/n-quads' }

  HTTPUtils.put(url, headers, concatenated, user, pass)
end

def purge_nt
  File.delete('/data/triples/*.nt')
rescue StandardError
  warn 'Deleting the exisiting .nt files failed!'
ensure
  warn 'looks like it is already clean in here!'
end

def metadata_update
  return if ENV['DIST_RECORDID'].nil? || ENV['DATASET_RECORDID'].nil? || ENV['DATA_SPARQL_ENDPOINT'].nil?
  return if ENV['DIST_RECORDID'].empty? || ENV['DATASET_RECORDID'].empty? || ENV['DATA_SPARQL_ENDPOINT'].empty?

  warn 'calling metadata updater image'
  begin
    resp = RestClient.get('http://updater:4567/update')
  rescue StandardError
    warn "\n\n\ncall to http://updater:4567/update FAILED"
    warn resp
  end
  warn "\n\nMetadata Update complete - look above for errors\n\n"
end

def cleanup
  warn 'closing cleanup open3'
  _o, _s = Open3.capture2('rm -rf /data/triplesstats.csv')
end
