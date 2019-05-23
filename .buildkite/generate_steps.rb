require 'yaml'

branch = ENV['BUILDKITE_BRANCH']

def get_ruby_minor_version(filename, major_version)
  File.open(filename) do |file|
    file.each_line do |line|
      if (line['RUBY_VERSION ' + major_version])
        return line.split(" ")[2]
      end
    end
  end
end

first = true
steps = Dir.glob("./**/Dockerfile").map do |dockerfile|
  ruby_version = dockerfile.split('/')[1]
  os_version = dockerfile.split('/')[2]
  name = ":ruby:Ruby #{ruby_version} on :ubuntu:#{os_version}"
  minor_version = get_ruby_minor_version(dockerfile, ruby_version)

  if branch == 'master'
    if first
      {
        'name' => name + " to push the latest tag",
        'commands' => [
          "docker build -t gusto/ruby:latest -f #{dockerfile} .",
          "docker push gusto/ruby:latest",
        ]
      }
      first = false
    end
    if os_version == 'ubuntu18.04'
      {
        'name' => name + " to push the version tag",
        'commands' => [
          "docker build -t gusto/ruby:#{ruby_version} -f #{dockerfile} .",
          "docker push gusto/ruby:#{ruby_version}",
          "docker build -t gusto/ruby:#{minor_version} -f #{dockerfile} .",
          "docker push gusto/ruby:#{minor_version}",
        ]
      }
    end
    {
      'name' => name,
      'commands' => [
        "docker build -t gusto/ruby:#{ruby_version}-#{os_version} -f #{dockerfile} .",
        "docker push gusto/ruby:#{ruby_version}-#{os_version}",
        "docker build -t gusto/ruby:#{minor_version}-#{os_version} -f #{dockerfile} .",
        "docker push gusto/ruby:#{minor_version}-#{os_version}",
      ]

    }
  else
    {
      'name' => name,
      'command' => "docker build -f #{dockerfile} .",
    }
  end
end

File.open('.buildkite/pipeline.yml', 'w') do |f|
  f.puts YAML.dump(steps)
end
