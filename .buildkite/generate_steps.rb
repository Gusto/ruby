require 'yaml'

branch = ENV['BUILDKITE_BRANCH']

def get_ruby_minor_version(filename, major_version)
  File.open(filename) do |file|
    file.each_line do |line|
      if (line["RUBY_VERSION #{major_version}"])
        return line.split(" ")[2]
      end
    end
  end
end

SUPPORTED_PAIRS = {
  "2.7": {
    "ubuntu20.04": ["amd64", "arm64"],
    "ubuntu18.04": ["amd64"],
  },
  "3.0": {
    "ubuntu20.04": ["amd64", "arm64"],
  },
  "3.1": {
    "ubuntu20.04": ["amd64", "arm64"],
  }
}

QUEUES_FOR_PLATFORM = {
  'amd64' => 'default',
  'arm64' => 'default_arm'
}

step_counter = 0
steps = []

SUPPORTED_PAIRS.each do |ruby_version, os_bases|
  os_bases.each do |os_version, platforms|
    dockerfile = "#{ruby_version}/#{os_version}/Dockerfile"
    minor_version = get_ruby_minor_version(dockerfile, ruby_version)
    ruby_major_tag = "#{ruby_version}-#{os_version}"
    ruby_minor_tag = "#{minor_version}-#{os_version}"

    platform_keys = []

    platforms.each do |platform|
      step_counter += 1
      name = ":ruby:Ruby #{ruby_version} on :ubuntu:#{os_version} for #{platform}"
      step_key = "ruby-build-step-#{step_counter}"
      ruby_builder_name = "ruby-builder-#{step_counter}"
      platform_step = {
        'name' => name,
        'key' => step_key,
        'agents' => {
          'queue' => QUEUES_FOR_PLATFORM[platform]
        },
        'commands' => [
          "docker buildx create --name #{ruby_builder_name}",
          "docker buildx build --builder #{ruby_builder_name} --platform linux/#{platform} --cache-to type=local,dest=#{platform}-image-build -f #{dockerfile} .",
          "docker buildx rm #{ruby_builder_name} || true",
          "ls -al",
        ],
        'plugins' => [{
          "ssh://git@github.com/Gusto/cache-buildkite-plugin.git#v1.11" => { 
            "save" => {
              "name" => step_key,
              "key" => [
                dockerfile
              ],
              "path" => [
                "#{platform}-image-build"
              ]
            }
          }
        }]
      }

      platform_keys.push(step_key)
      steps.push(platform_step)
    end

    platform_caches = platforms.map { |platform| "--cache-from type=local,src=#{platform}-image-build" }.join(" ")
    platform_args = platforms.map { |platform| "linux/#{platform}" }.join(",")
    push_args = branch == "master" ? "--push" : ""

    step_counter += 1
    ruby_builder_name = "ruby-builder-#{step_counter}"

    steps.push({
      'name' => ":ladle:Ruby #{ruby_version} on :ubuntu:#{os_version}",
      'depends_on' => platform_keys,
      'plugins' => [{
        "ssh://git@github.com/Gusto/cache-buildkite-plugin.git#v1.11" => { 
          "restore" => platform_keys
        }
      }],
      'commands' => [
        "ls -al",
        "docker buildx create --name #{ruby_builder_name}",
        "docker buildx build --builder #{ruby_builder_name} --tag gusto/ruby:#{ruby_major_tag} --platform #{platform_args} #{platform_caches} #{push_args} -f #{dockerfile} .",
        "docker buildx build --builder #{ruby_builder_name} --tag gusto/ruby:#{ruby_minor_tag} --platform #{platform_args} #{platform_caches} #{push_args} -f #{dockerfile} .",
        "docker buildx rm #{ruby_builder_name} || true",
      ]
    })
  end
end

puts "Generated YAML"
generated_yaml = {"steps" => steps}.to_yaml
puts generated_yaml

File.open('.buildkite/pipeline.yml', 'w') do |f|
  f.puts generated_yaml
end
