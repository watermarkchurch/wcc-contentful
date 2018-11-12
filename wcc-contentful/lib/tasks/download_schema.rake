
require 'wcc/contentful'
require 'wcc/contentful/downloads_schema'

namespace :wcc_contentful do
  desc "Downloads the schema from the currently configured space and stores it in" \
    "db/contentful-schema.json"
  task :download_schema => :environment do
    WCC::Contentful::DownloadsSchema.call
  end
end
