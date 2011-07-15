task :default => :run

task :init do
  sh "bundle install --path vendor/bundle"
end

task :run do
  sh "shotgun config.ru"
end
