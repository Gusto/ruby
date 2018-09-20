require 'yaml'

branch = ENV['BUIDLKITE_BRANCH']

steps = Dir.glob("./**/Dockerfile").map do |dockerfile|
  ruby_version = dockerfile.split('/')[1]
  os_version = dockerfile.split('/')[2]
  if branch == 'master'
  
    {
      'name' => "Ruby #{ruby_version} on #{os_version}",
      'command' => "docker build -t gusto/ruby:#{ruby_version}-#{os_version} && docker push gusto/ruby:#{ruby_version}-#{os_version}",
    }
  else
    {
      'name' => "Ruby #{ruby_version} on #{os_version}",
      'command' => "docker build -t gusto/ruby:#{ruby_version}-#{os_version}",
    }
  end
end

puts steps
