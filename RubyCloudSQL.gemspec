require 'rubygems'
require 'rake'

RUBYCLOUDSQL_GEMSPEC = Gem::Specification.new do |spec|
  spec.rubyforge_project = 'RubyCloudSQL'
  spec.name = 'RubyCloudSQL'
  spec.summary = "Wrapper for Zoho Cloud database"
  spec.add_dependency('xml-simple', '~> 1.0.12')
  spec.version = File.read('VERSION').strip
  spec.author = "Thane Vo"
  spec.authors = ['Thane Vo']
  spec.email = 'Thane.Vo@gmail.com'
  spec.description = <<-END
    Wrapper for Zoho Cloud database
  END

  spec.files = FileList['lib/**/*', 'spec/*', 'test/**/*'].to_a
end