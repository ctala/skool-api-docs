source "https://rubygems.org"

# Lock to the exact stack GitHub Pages runs in production
# https://pages.github.com/versions/
gem "github-pages", group: :jekyll_plugins

# Plugins (already enabled in _config.yml — listed here for bundle install)
group :jekyll_plugins do
  gem "jekyll-sitemap"
  gem "jekyll-seo-tag"
  gem "jekyll-feed"
end

# Required for Ruby 3+ on macOS
gem "webrick", "~> 1.7"

# Performance — silences `did not find a default ENGINE` warning
gem "wdm", "~> 0.1.1", :install_if => Gem.win_platform?
