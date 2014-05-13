#
# Cookbook Name:: techdivision-typo3flow
# Resource:: app
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

actions :add, :remove

attribute :app_name, :kind_of => String, :name_attribute => true
attribute :cookbook_name, :kind_of => String
attribute :rewrite_rules, :kind_of => [Array, NilClass], :default => nil
attribute :database_name, :kind_of => String
attribute :database_username, :kind_of => String
attribute :database_password, :kind_of => String
attribute :base_uri, :kind_of => String, :default => ""

def initialize(*args)
  super
  @action = :add
end
