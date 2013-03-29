#
# Cookbook Name:: robertlemke-typo3flow
# Resource:: app
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

actions :add, :remove

attribute :app_name, :kind_of => String, :name_attribute => true
attribute :cookbook_name, :kind_of => String
attribute :rewrite_rules, :kind_of => [Array, NilClass], :default => nil

def initialize(*args)
  super
  @action = :add
end
