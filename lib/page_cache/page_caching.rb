module PageCache
  module PageCaching
    
    def self.included(controller)
      controller.extend(ClassMethods)
    end
    
    module ClassMethods
      def cached_pages(*actions)
        return unless perform_caching
        options = actions.extract_options!
        expires_on = options.delete(:expires_on)
        ttl = options.delete(:ttl)
        block_leaked_requests = options.delete(:block_leaked_requests)
        before_filter({:only => actions}.merge(options)) { |controller| controller.before_page_caching_action }
        after_filter({:only => actions}.merge(options)) { |controller| controller.do_page_caching }
        PageCache::CachedPage.add_cached_pages(:controller => self, 
          :actions => actions, :expires_on => expires_on,
          :ttl => ttl, :block_leaked_requests => block_leaked_requests)
      end
    end
    
    # A leaked request happens when the server does not respond to the user
    # with the static file but passes the request onto the Rails app unexpectedly.
    # This happens sometimes on Apache, due to a File move operation
    # not being atomic I'm *guessing*.
    # Most of the time it is ok for leaked requests to go through and just
    # get served the dynamically generated page, however, for slow to generate
    # pages (e.g. a sitemap.xml with 50,000 URLs might take a few minutes
    # to generate) then you may want a leaked request to be handled differently
    # in this case to prevent your server getting tied up or users waiting for
    # the page to generate. See handle_leaked_requests and the :block_leaked_request
    # option of cached_pages.
    def leaked_request?
      !CacheUpdater.executing?
    end
    
    def before_page_caching_action
      CachedPage.current = CachedPage.find_by_url(request.url)
      if leaked_request?
        if cached_page.nil?
          render_cached_page_not_found
          CachedPage.current = nil
        elsif cached_page.block_leaked_requests
          render_for_leaked_request
          CachedPage.current = nil
        end
      end
    end
    
    def cache_page_to_file?
      perform_caching && caching_allowed && CacheUpdater.executing?
    end
    
    def do_page_caching
      cached_page.cache(response.body) if cache_page_to_file?
      CachedPage.current = nil
    end
    
    def render_cached_page_not_found
      render :file => "#{RAILS_ROOT}/public/404.html", :status => :not_found
    end
    
    def render_for_leaked_request
      successful = render_page_from_cache
      if successful
        Rails.logger.info("Leaked request handled gracefully, cached file rendered for '#{cached_page}'.")
      else
        Rails.logger.error("Leaked request for '#{cached_page}'. Cached file not available, error response will be given.")
      end
    end
    
    # Return true if successfully rendered, otherwise false if the cached file
    # does not exist.
    def render_page_from_cache
      if cached_page.live_exists?
        render :file => cached_page.live_path
        return true
      else
        render :text => 'Currently not in cache', :status => 503
        return false
      end
    end
    
    def cached_page
      CachedPage.current
    end
    
  end
end