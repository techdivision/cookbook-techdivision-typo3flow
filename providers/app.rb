#
# Cookbook Name:: techdivision-typo3flow
# Provider:: app
# Author:: Robert Lemke <r.lemke@techdivision.com>
#
# Copyright (c) 2014 Robert Lemke, TechDivision GmbH
#
# Licensed under the MIT License (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://opensource.org/licenses/MIT
#

action :add do

  new_resource = @new_resource

  app_name = new_resource.app_name
  app_username = new_resource.app_name.gsub(".", "")
  app_contextname = app_username.capitalize

  database_name = new_resource.database_name
  database_username = new_resource.database_username
  database_password = new_resource.database_password

  base_uri_production = new_resource.base_uri_production
  base_uri_development = new_resource.base_uri_development

  behat = new_resource.behat
  behat_database_name = "#{database_name}-behat"

  redis_proxy = new_resource.redis_proxy

  flow_production_context = "Production/#{app_contextname}"
  flow_development_context = "Development/#{app_contextname}"

  Chef::Log.info("#{@new_resource}: adding new TYPO3 Flow application '#{app_name}' ... #{new_resource.rewrite_rules}")

  #
  # Each Flow app gets its own shell user:
  #

  directory "/var/www/#{app_name}" do
    mode 02775
  end

  user app_username do
    comment "Site owner user"
    shell "/bin/zsh"
    home "/var/www/#{app_name}"
  end

  group "web" do
    action :modify
    members app_username
    append true
  end

  template "zshrc.erb" do
    cookbook "techdivision-typo3flow"
    path "/var/www/#{app_name}/.zshrc"
    source "zshrc.erb"
    owner app_username
    group app_username
    mode 0644
    variables(
      :flow_context => flow_production_context
    )
  end

  #
  # If we're in Vagrant mode, switch the "app_username" to "vagrant" now, because that makes life much easier
  # for people logging into their box with user "vagrant":
  #

  if node["vagrant"] then
    app_username = "vagrant"

    group "web" do
      action :modify
      members "vagrant"
      append true
    end
  end

  #
  # Creating the directory structure for the virtual host and Surf deployments
  #
  # (btw, not using "recursive" here, because then group and mode wouldn't be applied to parent directories)
  #

  %w{
    releases
    releases/default
    releases/default/Configuration
    releases/default/Configuration/Development
    releases/default/Configuration/Production
    releases/default/Web
    releases/default/Web/_Resources
    shared
    shared/Configuration
    shared/Configuration/Development
    shared/Configuration/Production
    shared/Data
    shared/Data/Persistent
    shared/Data/Logs
    shared/Data/Logs/Exceptions
    www
  }.each do |folder|
    directory "/var/www/#{app_name}/#{folder}" do
      user app_username
      group "web"
      mode 02775
    end
  end

  directory "/var/www/#{app_name}/shared/Configuration/#{flow_production_context}" do
    user app_username
    group "web"
    mode 02775
  end

  directory "/var/www/#{app_name}/shared/Configuration/#{flow_development_context}" do
    user app_username
    group "web"
    mode 02775
  end

  #
  # Create robots.txt
  #

  template "/var/www/#{app_name}/www/robots.txt" do
    cookbook "techdivision-typo3flow"
    source "robots.txt.erb"
    owner app_username
    group "web"
    mode 0644
    variables(
      :app_name => app_name
    )
  end

  #
  # Create a reasonable default release if nothing has been released yet:
  #

  link "/var/www/#{app_name}/releases/current" do
    to "./vagrant"
    only_if "test -e /var/www/#{app_name}/releases/vagrant"
  end

  link "/var/www/#{app_name}/releases/current" do
    to "./default"
    not_if "test -e /var/www/#{app_name}/releases/current"
  end

  file "/var/www/#{app_name}/releases/default/Web/index.php" do
    content "<h1>#{app_name}</h1><p>This application has not been released yet.</p>"
    owner app_username
    mode 0660
  end

  #
  # Create symlinks for shared configuration, resources and log files:
  #

  template "/var/www/#{app_name}/shared/Configuration/#{flow_production_context}/Settings.yaml" do
    cookbook "techdivision-typo3flow"
    source "Settings.yaml.erb"
    variables(
      :database_name => database_name,
      :database_user => database_username,
      :database_password => database_password,
      :base_uri => base_uri_production
    )
    owner app_username
    group "web"
    mode 0660
  end

  template "/var/www/#{app_name}/shared/Configuration/#{flow_development_context}/Settings.yaml" do
    cookbook "techdivision-typo3flow"
    source "Settings.yaml.erb"
    variables(
      :database_name => database_name,
      :database_user => database_username,
      :database_password => database_password,
      :base_uri => base_uri_development
    )
    owner app_username
    group "web"
    mode 0660
  end

  %w{
    Data
    Data/Temporary
    Data/Temporary/Development
    Data/Temporary/Production
  }.each do |folder|
    directory "/var/www/#{app_name}/releases/current/#{folder}" do
      user app_username
      group "web"
      mode 02775
    end
  end

  directory "/var/www/#{app_name}/releases/current/Data/Temporary/Development/SubContext#{app_contextname}" do
    user app_username
    recursive true
    mode 02775
    group "web"
  end

  directory "/var/www/#{app_name}/releases/current/Data/Temporary/Production/SubContext#{app_contextname}" do
    user app_username
    recursive true
    mode 02775
    group "web"
  end

  directory "/var/www/#{app_name}/releases/current/Data/Logs" do
    action :delete
    recursive true
    only_if "test -d /var/www/#{app_name}/releases/current/Data/Logs"
    not_if "test -L /var/www/#{app_name}/releases/current/Data/Logs"
  end

  link "/var/www/#{app_name}/releases/current/Data/Logs" do
    to "/var/www/#{app_name}/shared/Data/Logs"
  end

  directory "/var/www/#{app_name}/releases/current/Data/Persistent" do
    action :delete
    recursive true
    only_if "test -d /var/www/#{app_name}/releases/current/Data/Persistent"
    not_if "test -L /var/www/#{app_name}/releases/current/Data/Persistent"
  end

  link "/var/www/#{app_name}/releases/current/Data/Persistent" do
    to "/var/www/#{app_name}/shared/Data/Persistent"
  end

  link "/var/www/#{app_name}/releases/current/Configuration/#{flow_production_context}" do
    to "/var/www/#{app_name}/shared/Configuration/#{flow_production_context}"
  end

  link "/var/www/#{app_name}/releases/current/Configuration/#{flow_development_context}" do
    to "/var/www/#{app_name}/shared/Configuration/#{flow_development_context}"
  end

  link "/var/www/#{app_name}/www/index.php" do
    to "../releases/current/Web/index.php"
  end

  link "/var/www/#{app_name}/www/_Resources" do
    to "../releases/current/Web/_Resources"
  end

  if behat then

    directory "/var/www/#{app_name}/shared/Configuration/Development/Behat" do
      user app_username
      group "web"
      mode 02775
      recursive true
    end

    template "/var/www/#{app_name}/shared/Configuration/Development/Behat/Settings.yaml" do
      cookbook "techdivision-typo3flow"
      source "Settings.yaml.erb"
      variables(
        :database_name => behat_database_name,
        :database_user => database_username,
        :database_password => database_password,
      )
      owner app_username
      group "web"
      mode 0660
    end

    directory "/var/www/#{app_name}/shared/Configuration/Testing/Behat" do
      user app_username
      group "web"
      mode 02775
      recursive true
    end

    template "/var/www/#{app_name}/shared/Configuration/Testing/Behat/Settings.yaml" do
      cookbook "techdivision-typo3flow"
      source "Settings.yaml.erb"
      variables(
        :database_name => behat_database_name,
        :database_user => database_username,
        :database_password => database_password,
      )
      owner app_username
      group "web"
      mode 0660
    end

    link "/var/www/#{app_name}/releases/current/Configuration/Development/Behat" do
      to "/var/www/#{app_name}/shared/Configuration/Development/Behat"
    end

    link "/var/www/#{app_name}/releases/current/Configuration/Testing/Behat" do
      to "/var/www/#{app_name}/shared/Configuration/Testing/Behat"
    end


    directory "/var/www/#{app_name}/releases/current/Data/Temporary/Development/SubContextBehat" do
      user app_username
      recursive true
      mode 02775
      group "web"
    end
    directory "/var/www/#{app_name}/releases/current/Data/Temporary/Testing/SubContextBehat" do
      user app_username
      recursive true
      mode 02775
      group "web"
    end

  end

  #
  # Database
  #

  mysql_database database_name do
    connection ({:host => "localhost", :username => "root", :password => node['mysql']['server_root_password']})
    action :create
  end

  mysql_database_user database_username do
    connection ({:host => 'localhost', :username => 'root', :password => node['mysql']['server_root_password']})
    password database_password
    database_name database_name
    privileges [:all]
    action :grant
  end

  if behat then
    mysql_database behat_database_name do
      connection ({:host => "localhost", :username => "root", :password => node['mysql']['server_root_password']})
      action :create
    end

    mysql_database_user database_username do
      connection ({:host => 'localhost', :username => 'root', :password => node['mysql']['server_root_password']})
      password database_password
      database_name behat_database_name
      privileges [:all]
      action :grant
    end
  end

  #
  # Nginx virtual host
  #

  template new_resource.app_name do
    cookbook "techdivision-typo3flow"
    path "/etc/nginx/sites-available/#{app_name}"
    source "site.erb"
    owner "root"
    group "root"
    mode 0644

    variables({
      :server_name => app_name,
      :document_root => "/var/www/#{app_name}/www",
      :application_root => "/var/www/#{app_name}/releases/current",
      :flow_context => flow_production_context,
    })

    notifies :reload, "service[nginx]"
  end

  nginx_site app_name do
    enable true
  end

  if node["vagrant"] then
    template "#{new_resource.app_name}dev" do
      cookbook "techdivision-typo3flow"
      path "/etc/nginx/sites-available/#{app_name}dev"
      source "site.erb"
      owner "root"
      group "root"
      mode 0644

      variables({
        :server_name => "#{app_name}dev",
        :document_root => "/var/www/#{app_name}/www",
        :application_root => "/var/www/#{app_name}/releases/current",
        :flow_context => flow_development_context,
      })

      notifies :reload, "service[nginx]"
    end

    nginx_site "#{app_name}dev" do
      enable true
    end
  end

  if behat then
    template "#{new_resource.app_name}behat" do
      cookbook "techdivision-typo3flow"
      path "/etc/nginx/sites-available/#{app_name}behat"
      source "site.erb"
      owner "root"
      group "root"
      mode 0644

      variables({
        :server_name => "#{app_name}behat",
        :document_root => "/var/www/#{app_name}/www",
        :application_root => "/var/www/#{app_name}/releases/current",
        :flow_context => 'Development/Behat',
      })

      notifies :reload, "service[nginx]"
    end

    nginx_site "#{app_name}behat" do
      enable true
    end
  end

  if redis_proxy then
    template "#{new_resource.app_name}redis" do
      cookbook "techdivision-typo3flow"
      path "/etc/nginx/sites-available/#{app_name}redis"
      source "site-redis.erb"
      owner "root"
      group "root"
      mode 0644

      variables({
        :server_name => "#{app_name}redis",
        :document_root => "/var/www/#{app_name}/www",
        :application_root => "/var/www/#{app_name}/releases/current",
        :flow_context => flow_production_context
      })

      notifies :reload, "service[nginx]"
    end

    nginx_site "#{app_name}redis" do
      enable true
    end
  end

  #
  # For Vagrant run doctrine:migrate if it hasn't been run already
  #

  if node["vagrant"] then
    execute "Running doctrine:migrate for #{app_name}" do
      user "vagrant"
      umask 0002
      cwd "/var/www/#{app_name}/releases/vagrant"
      command "FLOW_CONTEXT=#{flow_development_context} ./flow doctrine:migrate && touch /var/www/#{app_name}/shared/Configuration/#{flow_development_context}/dont_run_doctrine_migrate"
      not_if "test -e /var/www/#{app_name}/shared/Configuration/#{flow_development_context}/dont_run_doctrine_migrate"
    end
  end
end

action :remove do

end
