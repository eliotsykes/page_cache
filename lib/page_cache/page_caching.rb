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
        after_filter({:only => actions}.merge(options)) { |controller| controller.do_page_caching }
        PageCache::CachedPage.add_cached_pages(:controller => self, :actions => actions, :expires_on => expires_on)
      end
    end
    
    def do_page_caching
      return unless perform_caching && caching_allowed
      # TODO raise exception
      # if perform_caching && not_localhost
      # end
      CachedPage.cache(request, response)
    end
    
  end
end