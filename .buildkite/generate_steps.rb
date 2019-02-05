require 'yaml'

branch = ENV['BUILDKITE_BRANCH']

first = true
steps = Dir.glob("./**/Dockerfile").map do |dockerfile|
  ruby_version = dockerfile.split('/')[1]
  os_version = dockerfile.split('/')[2]
  # One day, we'll totally build other os's, but not any time soon
  name = ":ruby:Ruby #{ruby_version} on :ubuntu:#{os_version}"


  if branch == 'master'
    if first
      {
        'name' => name,
        'command' => "docker build -t gusto/ruby:#{ruby_version}-#{os_version} -f #{dockerfile} . && docker push gusto/ruby:latest",
      }
      first = false
    end
    if os_version == 'ubuntu18.04'
      {
        'name' => name,
        'command' => "docker build -t gusto/ruby:#{ruby_version}-#{os_version} -f #{dockerfile} . && docker push gusto/ruby:#{ruby_version}",
      }
    end
    {
      'name' => name,
      'command' => "docker build -t gusto/ruby:#{ruby_version}-#{os_version} -f #{dockerfile} . && docker push gusto/ruby:#{ruby_version}-#{os_version}",
    }
  else
    {
      'name' => name,
      'command' => "docker build -t gusto/ruby:#{ruby_version}-#{os_version} -f #{dockerfile} .",
    }
  end
end

File.open('.buildkite/pipeline.yml', 'w') do |f|
  f.puts YAML.dump(steps)
end
