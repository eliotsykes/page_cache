module PageCache
  class CacheUpdater
    
    def self.execute_without_benchmark
      require 'action_controller/integration'
      app = ActionController::Integration::Session.new
      Thread.current[:cache_updater_executing] = true
      cached_pages = CachedPage.cached_pages
      if cached_pages.blank?
        raise 'There are no cached pages when they are expected. Check following caching options are set for this environment: config.action_controller.perform_caching = true and config.cache_classes = true'
      end
      cached_pages.each do |cached_page|
        if cached_page.cache_up_to_date?
          puts "Cache already up-to-date for '#{cached_page.url}'"
        else
          puts "Updating cache for '#{cached_page.url}'"
          elapsed_in_secs = Benchmark.realtime do
            app.get cached_page.url
          end
          puts "Took #{('%.1f' % elapsed_in_secs)}s to update cache for '#{cached_page.url}'"
        end
      end
      Thread.current[:cache_updater_executing] = nil
    end
    
    def self.execute
      puts "Updating cached pages (may take some time)"
      elapsed_in_secs = Benchmark.realtime do
        execute_without_benchmark
      end
      puts "Cached pages updated in #{('%.1f' % elapsed_in_secs)}s"
    end
    
    def self.executing?
      Thread.current[:cache_updater_executing]
    end
    
  end
end
