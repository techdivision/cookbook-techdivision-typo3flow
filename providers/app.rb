#
# Cookbook Name:: typo3flow
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

  recipe_eval do

    #
    # Each Flow app gets its own shell user:
    #
    app_username = new_resource.app_name.gsub('.', '')

    user app_username do
      comment "Site owner user"
      shell "/bin/zsh"
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
      directory "/var/www/#{new_resource.app_name}/#{folder}" do
        user app_username
        group "www-data"
        mode 00775
      end
    end

    link "/var/www/#{new_resource.app_name}/releases/current" do
      to "./default"
      not_if "test -e /var/www/#{new_resource.app_name}/releases/current"
    end

    link "/var/www/#{new_resource.app_name}/releases/current" do
      to "./vagrant"
    end

    file "/var/www/#{new_resource.app_name}/releases/default/Web/index.php" do
      content "This application has not been released yet."
      owner app_username
      group "www-data"
      mode 00775
    end

    template "/var/www/#{new_resource.app_name}/shared/Configuration/Production/Settings.yaml" do
      cookbook "typo3flow"
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

    link "/var/www/#{new_resource.app_name}/www/index.php" do
      to "../releases/current/Web/index.php"
    end

    link "/var/www/#{new_resource.app_name}/www/_Resources" do
      to "../releases/current/Web/_Resources"
    end

    mysql_database app_username do
      connection ({:host => "localhost", :username => 'root', :password => 'root'})
      action :create
    end

  end

  web_app new_resource.app_name do
    cookbook "typo3flow"
    template "typo3flow_app_production.conf.erb"
    server_name "mistermaks.com"
    server_aliases ["www.mistermaks.com", "mistermaks.com.prodbox"]
    docroot "/var/www/mistermaks.com/www"
    rootpath "/var/www/mistermaks.com/releases/current/"
  end

  execute "doctrine migrate" do
    command "./flow doctrine:migrate"
    cwd "/var/www/#{new_resource.app_name}/releases/current"
    environment ({'FLOW_CONTEXT' => 'Production'})
    action :run
  end

end

action :remove do

end
