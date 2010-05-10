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
        before_filter({:only => actions}.merge(options)) { |controller| controller.handle_leaked_requests }
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
      !local_request?
    end
    
    def handle_leaked_requests
      if leaked_request?
        Rails.logger.warn('Unwanted leaked request got through to page cache plugin.')
        cached_page = CachedPage.find_by_url(request.url)
        if cached_page.nil?
          render_cached_page_not_found
        elsif cached_page.block_leaked_requests
          render_for_leaked_request(cached_page)
        end
      end
    end
    
    def do_page_caching
      return unless perform_caching && caching_allowed
      CachedPage.cache(request, response)
    end
    
    def render_cached_page_not_found
      render :file => "#{RAILS_ROOT}/public/404.html", :status => :not_found
    end
    
    def render_for_leaked_request(cached_page)
      if cached_page.live_exists?
        Rails.logger.info('Leaked request handled gracefully, cached file rendered.')
        render :file => cached_page.live_path
      else
        Rails.logger.error("Leaked request for '#{cached_page}'. Cached file not available, error response will be given.")
        render :text => 'Currently not in cache', :status => 503        
      end
    end
    
  end
end