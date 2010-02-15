namespace :page_cache do
  desc 'Update the Page Cache'
  # If you change all_up_to_date_file_path, also edit value in CachedPage.
  all_up_to_date_file_path = 'public/cache/all_up_to_date'
  task :update do
    # We do it like this so we don't load the Rails environment in the rake
    # task unless we need to. This is because it takes some time and we want
    # to minimise load on server.
    if File.exist? all_up_to_date_file_path
      puts "Cached pages not updated, already up-to-date"
    else
      Rake::Task['page_cache:force_update'].invoke
    end
  end
  task :force_update => :environment do
    puts "Updating cached pages (may take some time)"
    require 'action_controller/integration'
    app = ActionController::Integration::Session.new
    PageCache::CachedPage.urls_to_cache.each do |url|
      puts "Getting page: '#{url}'"
      app.get url
    end
    FileUtils.makedirs(File.dirname(all_up_to_date_file_path))
    FileUtils.touch all_up_to_date_file_path
    puts "Cached pages updated"
  end
end
