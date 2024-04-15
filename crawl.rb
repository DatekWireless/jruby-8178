#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'concurrent-ruby'
  gem 'mechanize'
end

class Spider
  def initialize(nest, id)
    @id = id
    @nest = nest
    @queue = Queue.new
    Thread.start do
      url = nil
      referer = nil
      agent = Mechanize.new
      puts format('%s %s', Time.now.strftime("%T"), "[#{id}] READY")
      @nest.spider_ready(self, working: false)
      loop do
        level, url, referer = @queue.pop
        start_time = Time.now

        page = agent.get(url)
        duration = Time.now - start_time
        puts "Slow: #{duration.round(3)}s #{url}" if duration > 2
        @nest.visited[url] = duration
        @nest.visited[page.uri.path] = duration
        if page.is_a? Mechanize::Page
          page.links_with(href: /../).each do |link|
            unless link.attributes['data-method']
              href = link.href
              unless href =~ %r{^(http|/)}
                href = "#{page.uri.path}#{'/' unless page.uri.path =~%r{/$} || href =~ /^[#?]/}#{href}"
              end
              if href !~ /^http/ || URI(href).host == page.uri.host
                href.prepend "/#{$1}" if href !~ %r{^/\d+/} && page.uri.path =~ %r{^(?:https?://[^/]+)?/(\d+)/}
                @nest.enqueue(href, level + 1, page.uri.to_s)
              elsif @nest.ignored.add?(href)
                puts "Ignore external link: #{href}"
              end
            end
          end
        else
          puts "Found file."
        end
        @nest.spider_ready(self)
      end
    rescue StandardError => e
      puts
      abort format('%-10s: %s', 'Error', "#{url.inspect}, #{e}, referer: #{referer}")
    end
  end

  def scan_url(level, url, referer)
    @queue.push([level, url, referer])
  end
end


class SpiderNest
  attr_reader :ignored, :visited

  def self.scan(...)
    new(...).scan
  end

  def initialize(root:, max_urls:)
    @spiders = Queue.new
    @workers = Concurrent::Set.new
    @spider_count = [(Etc.nprocessors * 2), max_urls].min
    @spider_count.times { |i| Spider.new(self, i + 1) }
    @max_urls = max_urls
    @start_time = Time.now
    @urls = Queue.new
    @found = Concurrent::Set.new
    @visited = Concurrent::Map.new
    @ignored = Concurrent::Set.new
    enqueue(root, 0, nil)
  end

  def spider_ready(spider, working: true)
    if working
      @workers.delete?(spider) or abort("Spider not working")
    end
    @spiders.push(spider)
  end

  def enqueue(url, level, referer)
    url = url.sub(/[?&]lang=(iw|sv)/, '')
    return if @found.size >= @max_urls
    return if url =~ %r{/logout$|^/test}
    if url =~ /^http/
      uri = URI(url)
      path = uri.path
      if uri.query
        path+=uri.query
      end
    else
      path = url
    end
    return unless @found.add?(path)

    @urls << [url, level, referer]
  end

  def scan
    i = 0
    while !@urls.empty? || i < @found.size || @workers.any?
      begin
        url, level, referer = @urls.pop(true)
        i += 1
        puts format('%s %-10s: %s', Time.now.strftime("%T"), "Visit [#{i}/#{@found.size}] (#{level})", url.inspect)
        spider = @spiders.pop
        @workers.add?(spider) or abort("Spider already working.")
        spider.scan_url(level, url, referer)
      rescue ThreadError
        puts 'Wait for next URL...' if @workers.empty?
        sleep 0.1
      end
    end
    @spider_count.times{@spiders.pop} # Wait for the spider to complete cleanup.
    @visited.size
  end
end

if __FILE__ == $PROGRAM_NAME
  start = Time.now
  $stdout.sync = true
  count = SpiderNest.scan(root: 'http://localhost:8080/', max_urls: 2000)
  duration = Time.now - start
  puts "Total time: #{duration.round}s.  #{count} pages.  #{(duration / count).round(3)}s/page  #{(count / duration).round(3)}pages/s"
  abort('Found no links.') if count < 2
end
