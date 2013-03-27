#
# Cookbook Name:: robertlemke-typo3flow
# Provider:: app
# Author:: Robert Lemke <rl@robertlemke.com>
#
# Copyright (c) 2013 Robert Lemke
#
# Licensed under the MIT License (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://opensource.org/licenses/MIT
#

action :add do

  app_name = new_resource.app_name
  app_username = new_resource.app_name.gsub('.', '')
  flow_production_context = node.attribute?('vagrant') ? "Production/Vagrant" : "Production"
  flow_development_context = node.attribute?('vagrant') ? "Development/Vagrant" : "Development"

  recipe_eval do

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
      cookbook "robertlemke-typo3flow"
      source "robots.txt.erb"
      owner app_username
      group app_username
      mode "0644"
      variables(
        :app_name => app_name
      )
    end

    template "zshrc.erb" do
      cookbook "robertlemke-typo3flow"
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
      to "./default"
      not_if "test -e /var/www/#{app_name}/releases/current"
    end

    if node.attribute?('vagrant')
      link "/var/www/#{app_name}/releases/current" do
        to "./vagrant"
      end
    end

    file "/var/www/#{app_name}/releases/default/Web/index.php" do
      content "This application has not been released yet."
      owner app_username
      group "www-data"
      mode 00775
    end

    template "/var/www/#{app_name}/shared/Configuration/Production/Settings.yaml" do
      cookbook "robertlemke-typo3flow"
      source "Settings.yaml.erb"
      variables(
        :database_name => "#{app_username}",
        :database_user => "root",
        :database_password => "root"
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

    mysql_database app_username do
      connection ({:host => "localhost", :username => 'root', :password => 'root'})
      action :create
    end

  end

  web_app new_resource.app_name do


    cookbook "robertlemke-typo3flow"
    template "typo3flow_app.conf.erb"

    server_name "#{app_name}"

    if node.attribute?('vagrant')
      server_aliases ["www.#{app_name}", "#{app_name}.prodbox"]
    else
      server_aliases ["www.#{app_name}"]
    end

    docroot "/var/www/#{app_name}/www"
    rootpath "/var/www/#{app_name}/releases/current/"

    flow_context flow_production_context
  end

  web_app "#{app_name}-development" do
    cookbook "robertlemke-typo3flow"
    template "typo3flow_app.conf.erb"

    server_name "dev.#{app_name}"

    if node.attribute?('vagrant')
      server_aliases ["#{app_name}.devbox"]
    else
      server_aliases []
    end

    docroot "/var/www/#{app_name}/www"
    rootpath "/var/www/#{app_name}/releases/current/"
    flow_context "#{flow_development_context}"
  end

  web_app "#{app_name}-next-production" do
    cookbook "robertlemke-typo3flow"
    template "typo3flow_app.conf.erb"

    server_name "next.#{app_name}"

    server_aliases []

    docroot "/var/www/#{app_name}/www"
    rootpath "/var/www/#{app_name}/releases/next/"

    flow_context flow_production_context
  end

end

action :remove do

end
