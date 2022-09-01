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

    platform_build_keys = []
    ruby_major_tags = []
    ruby_minor_tags = []

    platforms.each do |platform|
      step_counter += 1
      name = ":ruby:Ruby #{ruby_version} on :ubuntu:#{os_version} for #{platform}"
      ruby_major_tag = "#{ruby_version}-#{os_version}-#{platform}"
      ruby_minor_tag = "#{minor_version}-#{os_version}-#{platform}"
      platform_step = {
        'name' => name,
        'key' => "step-#{step_counter}",
        'agents' => {
          'queue' => QUEUES_FOR_PLATFORM[platform]
        }
      }

      platform_build_keys.push(platform_step["key"])
      ruby_major_tags.push("gusto/ruby:#{ruby_major_tag}")
      ruby_minor_tags.push("gusto/ruby:#{ruby_minor_tag}")

      platform_step['commands'] = if branch == 'master'
        [
          "docker buildx rm ruby-builder || true",
          "docker buildx create --name ruby-builder --use",
          "docker buildx build --platform #{platform} --push -t gusto/ruby:#{ruby_major_tag} -f #{dockerfile} .",
          "docker buildx build --platform #{platform} --push -t gusto/ruby:#{ruby_minor_tag} -f #{dockerfile} .",
        ]
      else
        [
          "docker buildx rm ruby-builder || true",
          "docker buildx create --name ruby-builder --use",
          "docker buildx build --platform #{platform} -f #{dockerfile} .",
        ]
      end

      steps.push(platform_step)
    end

    if branch == 'master'
      steps.push({
        'name' => 'merge manifest',
        'depends_on' => platform_build_keys,
        'commands' => [
          "docker manifest create gusto/ruby:#{ruby_version}-#{os_version} --amend " + ruby_major_tags.join(" --amend "),
          "docker manifest create gusto/ruby:#{minor_version}-#{os_version} --amend " + ruby_minor_tags.join(" --amend "),
          "docker manifest push gusto/ruby:#{ruby_version}-#{os_version}",
          "docker manifest push gusto/ruby:#{minor_version}-#{os_version}"
        ]
      })
    end
  end
end

puts "Generated YAML"
generated_yaml = {"steps" => steps}.to_yaml
puts generated_yaml

File.open('.buildkite/pipeline.yml', 'w') do |f|
  f.puts generated_yaml
end
