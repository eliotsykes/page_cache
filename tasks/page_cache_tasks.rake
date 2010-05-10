namespace :page_cache do
  desc 'Update the Page Cache'
  task :update => :environment do
    puts "Updating cached pages (may take some time)"
    require 'action_controller/integration'
    app = ActionController::Integration::Session.new
    PageCache::CachedPage.urls_to_cache.each do |url|
      app.get url
    end
    puts "Cached pages updated"
  end
end
