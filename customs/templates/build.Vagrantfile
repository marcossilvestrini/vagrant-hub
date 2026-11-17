require "uri"
require "json"

def local_box_url(path)
  absolute_path = File.expand_path(path).tr("\\", "/")
  absolute_path = "/#{absolute_path}" unless absolute_path.start_with?("/")
  "file://#{URI::DEFAULT_PARSER.escape(absolute_path)}"
end

base_box_path = ENV.fetch("CUSTOM_BASE_BOX_PATH")
profile_name = ENV.fetch("CUSTOM_PROFILE_NAME")
provider_name = ENV.fetch("CUSTOM_VAGRANT_PROVIDER")

Vagrant.configure("2") do |config|
  config.vm.box = "local/#{ENV.fetch('CUSTOM_BASE_BOX_NAME')}"
  config.vm.box_url = local_box_url(base_box_path)
  config.vm.box_check_update = false
  config.vm.synced_folder ENV.fetch("CUSTOM_ANSIBLE_DIR"), "/home/vagrant/ansible"

  config.vm.provider provider_name do |vm|
    if provider_name == "virtualbox"
      vm.name = "custom-#{profile_name}-build"
      vm.memory = Integer(ENV.fetch("CUSTOM_MEMORY"))
      vm.cpus = Integer(ENV.fetch("CUSTOM_CPUS"))
    else
      vm.vmx["displayName"] = "custom-#{profile_name}-build"
      vm.vmx["memsize"] = ENV.fetch("CUSTOM_MEMORY")
      vm.vmx["numvcpus"] = ENV.fetch("CUSTOM_CPUS")
    end
  end

  config.vm.provision "ansible_local" do |ansible|
    ansible.install_mode = "default"
    ansible.compatibility_mode = "2.0"
    ansible.raw_arguments = ["--roles-path", "/home/vagrant/ansible/roles"]
    ansible.limit = "all"
    ansible.provisioning_path = "/home/vagrant/ansible"
    ansible.inventory_path = "inventory.ini"
    ansible.playbook = "playbooks/#{ENV.fetch('CUSTOM_PLAYBOOK')}"
    ansible.extra_vars = JSON.parse(ENV.fetch("CUSTOM_EXTRA_VARS", "{}"))
  end
end


