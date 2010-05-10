module PageCache
  class CachedPage
    include ActionController::UrlWriter

    cattr_accessor :cached_pages
    attr_accessor :controller, :action, :expires_on, :url, :latest_path,
      :live_path, :subdomain, :ttl, :block_leaked_requests
    
    def initialize(options)
      self.controller = options[:controller]
      self.action = options[:action]
      self.expires_on = options[:expires_on]
      self.ttl = options[:ttl]
      self.block_leaked_requests = options[:block_leaked_requests]
      self.url = determine_url
      # TODO determine subdomain from url.
      self.subdomain = 'www'
      only_path = true
      request_path = determine_url(only_path)
      self.latest_path = filesystem_path 'latest', request_path
      self.live_path = filesystem_path 'live', request_path
    end
    
    def determine_url(only_path=false)
      # TODO handle different formats
      url_for(:controller => controller.controller_path,
        :action => action, :only_path => only_path)
    end
    
    def self.add_cached_pages(options)
      self.cached_pages = [] if cached_pages.blank?
      cached_pages.concat( create_array(options) )
    end
    
    def self.create_array(options)
      actions = options.delete(:actions)
      cached_pages_array = actions.collect do |action|
        new options.merge(:action => action)
      end
      cached_pages_array
    end
    
    def self.cache(request, response)
      cached_page = find_by_url request.url
      cached_page.cache(response.body)
    end
    
    def cache(content)
      if cache_up_to_date?
        puts "Cache already up to date for '#{url}'"
        return
      end
      puts "Updating cache for '#{url}'"
      # Expire needed in case ttl exceeded is why cache_up_to_date? == false
      expire
      # Write file to latest_path
      FileUtils.makedirs(File.dirname(latest_path))
      File.open(latest_path, "wb+") { |f| f.write(content) }
      # Move a copy of latest to live
      latest_copy = latest_path + ".copy"
      # To try to give holeless cache, we copy file and *then* move it with mv,
      # as mv operations are atomic in most cases, whereas copy is not atomic.
      FileUtils.copy latest_path, latest_copy, :preserve => true
      FileUtils.makedirs(File.dirname(live_path))
      # We make latest_copy live by moving it, and so preserve the file at latest_path.
      FileUtils.mv latest_copy, live_path, :force => true
    end
    
    def live_exists?
      File.exist?(live_path)
    end
    
    def cache_up_to_date?
      File.exist?(latest_path) && !ttl_exceeded? 
    end
    
    def ttl_exceeded?
      return false if ttl.blank?
      lifetime_in_secs >= ttl
    end
    
    def lifetime_in_secs
      if File.exist?(live_path)
        last_mod = File.mtime(live_path) 
        return Time.now.to_i - last_mod.to_i
      end
      0
    end
    
    def expire
      File.delete(latest_path) if File.exist?(latest_path)
    end
    
    def self.handle_event(event)
      return if cached_pages.blank?
      cached_pages.each do |cached_page|
        cached_page.handle_event(event)
      end
    end
    
    def handle_event(event)
      return if expires_on.blank?
      expires_on.each do |expire_on|
        expire if event.is_a? expire_on
      end
    end
    
    def self.find_by_url(url)
      all.each do |cached_page|
        return cached_page if url == cached_page.url
      end
      nil
    end
    
    def self.all
      cached_pages
    end
    
    def to_s
      inspect
    end
    
    private
    
    # Copied from ActionController::Caching::Pages
    def page_cache_file(path)
      name = (path.empty? || path == "/") ? "/index" : URI.unescape(path.chomp('/'))
      name << page_cache_extension unless (name.split('/').last || name).include? '.'
      return name
    end
  
    def page_cache_extension
      '.html'
    end
    
    def filesystem_path(cache_stage, request_path)
      "#{PageCache::CachedPage.page_cache_directory}/#{cache_stage}/#{subdomain}#{page_cache_file(request_path)}"
    end
    
    def self.page_cache_directory
      ActionController::Base.page_cache_directory
    end
    
    def self.urls_to_cache
      urls_to_cache = []
      unless cached_pages.blank?
        urls_to_cache = cached_pages.collect { |cached_page| cached_page.url }
      end
      raise RuntimeError.new('urls_to_cache should not be empty, controller classes have probably not been initialized, ensure config.cache_classes = true') if urls_to_cache.empty?
      urls_to_cache
    end
    
  end
end
