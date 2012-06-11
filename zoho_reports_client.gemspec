# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "zoho_reports_client/version"

Gem::Specification.new do |s|
  s.name = "zoho_reports_client"
  s.version = ZohoReportsClient::VERSION
  s.authors = ["Thane Vo", "Tony Summerville"]
  s.email = %w(Thane.Vo@gmail.com tsummerville@rarestep.com)
  s.homepage = ""
  s.summary = %q{Ruby wrapper for Zoho Reports API}
  s.description = %q{The Zoho Reports client library wraps the raw HTTP based API of Zoho Reports and CloudSQL provided by Zoho (zohoreportsapi.wiki.zoho.com).}

  s.rubyforge_project = "zoho_reports_client"

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = %w(lib)

  s.add_dependency 'xml-simple'
  s.add_dependency 'activesupport'

  s.add_development_dependency 'rspec'
end