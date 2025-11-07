source "https://rubygems.org"

# Jekyll 4.x - Full Ruby 3.3 support, 40-60% faster builds
gem "jekyll", "~> 4.3.4"
# gem "jekyll-theme-minimal"  # Disabled - using remote_theme for Vercel compatibility
# Note: webrick no longer needed with Jekyll 4.x

group :jekyll_plugins do
  gem "jekyll-sitemap"
  gem "jekyll-seo-tag"
  gem "jekyll-feed"
  gem "jekyll-remote-theme"
end

# Windows and JRuby does not include zoneinfo files, so bundle the tzinfo-data gem
# and associated library.
platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", "~> 1.2"
  gem "tzinfo-data"
end

# Performance-booster for watching directories on Windows
gem "wdm", "~> 0.1.1", :platforms => [:mingw, :x64_mingw, :mswin]

# kramdown v2 ships without the gfm parser by default. If you're using
# kramdown v1, comment out this line.
gem "kramdown-parser-gfm"

# Lock `http_parser.rb` gem to `v0.6.x` on JRuby builds since newer versions of the gem
# do not have a Java counterpart.
gem "http_parser.rb", "~> 0.6.0", :platforms => [:jruby]
