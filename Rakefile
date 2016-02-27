require 'rake/version_task'
Rake::VersionTask.new do |task|
	task.with_git_tag=true
end

desc "Lint FILE (defaults to mapwrap.rb)"
task :lint do
  filename = ENV['FILE'] || 'mapwrap.rb'
  sh "ruby -c #{filename}"  
end
