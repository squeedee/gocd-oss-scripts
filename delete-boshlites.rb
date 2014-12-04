#!/var/vcap/packages/ruby-2.0.0-p481/2.0.0-p481/bin/ruby

begin
  Gem.install 'aws-sdk'
rescue Gem::InstallError
end

require 'aws-sdk'
require 'logger'

def env_variables_set(env)
  env.has_key?('BOSH_AWS_ACCESS_KEY_ID') && env.has_key?('BOSH_AWS_SECRET_ACCESS_KEY') && env.has_key?('GO_PIPELINE_NAME')
end

def script_environment
  current_environment = ('docker' if File.exists? '/.dockerenv') || ('agent' if Dir.exists? '/var/vcap/jobs/gocd-agent/') || 'other'
end

def error_message
  "\nThe following ENV variables need to be set:

BOSH_AWS_ACCESS_KEY_ID
BOSH_AWS_SECRET_ACCESS_KEY
GO_PIPELINE_NAME

BOSH-Lites on GoCD are automatically tagged by our Vagrant shim with the key, value pair: 'reapable','true' and 'PipelineName',<GoCDPipelineName>\n"
end

current_environment = script_environment
env = ENV.to_hash
logger = Logger.new(STDOUT)
time = env.fetch('BOSH_LITE_LIFESPAN', '180minutes')

raise 'BOSH_LITE_LIFESPAN must include the units (minutes)' unless time.include? 'm'
lifespan = time.to_i * 60

if env_variables_set(env)
    ec2 = AWS::EC2.new(
    :access_key_id => env.fetch('BOSH_AWS_ACCESS_KEY_ID'),
    :secret_access_key => env.fetch('BOSH_AWS_SECRET_ACCESS_KEY'))

  collection = ec2.instances.with_tag('reapable', 'true').with_tag('PipelineName', env.fetch('GO_PIPELINE_NAME'))

  collection.each do |instance|
    if instance.status == :running && Time.now - instance.launch_time > lifespan
      logger.info("Terminating instance #{instance.id}")
      instance.terminate
    end
  end
else
  case current_environment
  when 'docker'
    logger.error("You are currently running this script inside a docker container. #{error_message}")
  when 'agent'
    logger.error("You are currently running this script on a GoCD agent. #{error_message}")
  when 'other'
    logger.error("You are currently running this script outside of GoCD and Docker. #{error_message}")
  end
end