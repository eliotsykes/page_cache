namespace :page_cache do
  desc 'Update the Page Cache'
  task :update => :environment do
    PageCache::CacheUpdater.execute
  end
end
