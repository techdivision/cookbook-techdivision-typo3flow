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
  app_username = new_resource.app_name.gsub('.', '')
  database_name = new_resource.database_name
  database_username = new_resource.database_username
  database_password = new_resource.database_password
  flow_production_context = node.attribute?('vagrant') ? "Production/Vagrant" : "Production"
  flow_development_context = node.attribute?('vagrant') ? "Development/Vagrant" : "Development"

  Chef::Log.info("#{@new_resource}: adding new TYPO3 Flow application '#{app_name}' ... #{new_resource.rewrite_rules}")

  #
  # Each Flow app gets its own shell user:
  #

  directory "/var/www/#{app_name}" do
  end

  user app_username do
    comment "Site owner user"
    shell "/bin/zsh"
    home "/var/www/#{app_name}"
  end

  group "www-data" do
    action :modify
    members app_username
    append true
  end

  #
  # Creating the directory structure for the virtual host and Surf deployments:
  #

  %w{
    releases
    releases/default
    releases/default/Web
    releases/default/Web/_Resources
    shared
    shared/Configuration
    shared/Configuration/Production
    shared/Data
    shared/Data/Persistent
    shared/Data/Logs
    shared/Data/Logs/Exceptions
    www
  }.each do |folder|
    directory "/var/www/#{app_name}/#{folder}" do
      user app_username
      group "www-data"
      mode 00775
    end
  end

  #
  # Create robots.txt and humans.txt
  #

  template "/var/www/#{app_name}/www/robots.txt" do
    cookbook "techdivision-typo3flow"
    source "robots.txt.erb"
    owner app_username
    group app_username
    mode "0644"
    variables(
      :app_name => app_name
    )
  end

  template "zshrc.erb" do
    cookbook "techdivision-typo3flow"
    path "/var/www/#{app_name}/.zshrc"
    source "zshrc.erb"
    owner app_username
    group app_username
    mode "0644"
    variables(
      :flow_context => flow_production_context
    )
  end

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
    group "www-data"
    mode 00775
  end

  template "/var/www/#{app_name}/shared/Configuration/Production/Settings.yaml" do
    cookbook "techdivision-typo3flow"
    source "Settings.yaml.erb"
    variables(
      :database_name => database_name,
      :database_user => database_username,
      :database_password => database_password
    )
    owner app_username
    group "www-data"
    mode 00660
  end

  link "/var/www/#{app_name}/www/index.php" do
    to "../releases/current/Web/index.php"
  end

  link "/var/www/#{app_name}/www/_Resources" do
    to "../releases/current/Web/_Resources"
  end

  mysql_database database_name do
    connection ({:host => "localhost", :username => "root", :password => node[:mysql][:server_root_password]})
    action :create
  end

  mysql_database_user database_username do
    connection ({:host => 'localhost', :username => 'root', :password => node[:mysql][:server_root_password]})
    password database_password
    database_name database_name
    privileges [:all]
    action :grant
  end

  template new_resource.app_name do
    cookbook "techdivision-typo3flow"
    path "/etc/nginx/sites-available/#{app_name}"
    source "site.erb"
    owner "root"
    group "root"
    mode "0644"

    variables({
      :server_name => app_name,
      :document_root => "/var/www/#{app_name}/www",
      :application_root => "/var/www/#{app_name}/releases/current"
    })

    notifies :reload, resources(:service => "nginx")
  end

  nginx_site app_name do
    enable true
  end

end

action :remove do

end
