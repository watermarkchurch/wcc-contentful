# frozen_string_literal: true

require 'wcc/contentful'

namespace :wcc_contentful do
  desc 'Rewrites JSON fixtures from locale=* to locale=en-US'
  task :rewrite_fixtures, [:glob, :locale] => :environment do |t, args|
    glob = args[:glob] || 'spec/fixtures/**/*.json'
    locale = args[:locale] || 'en-US'

    Dir.glob(glob) do |filename|
      next unless File.file?(filename)

      contents = JSON.parse(File.read(filename))
      next unless contents.is_a?(Hash) && contents['sys']

      rewritten_contents =
        case type = contents['sys']['type']
        when 'Array'
          rewrite_array(contents, locale: locale)
        when 'Entry', 'Asset'
          rewrite_entry(contents, locale: locale)
        end
      next unless rewritten_contents

      File.write(filename, JSON.pretty_generate(rewritten_contents))
    end
  end

  def rewrite_array(contents, locale: 'en-US')
    contents['items'] =
      contents['items'].map do |item|
        rewrite_entry(item, locale: locale)
      end
    if contents['includes']
      if contents['includes']['Entry']
        contents['includes']['Entry'] =
          contents['includes']['Entry'].map do |item|
            rewrite_entry(item, locale: locale)
          end
      end
      if contents['includes']['Asset']
        contents['includes']['Asset'] =
          contents['includes']['Asset'].map do |item|
            rewrite_entry(item, locale: locale)
          end
      end
    end

    contents
  end

  def rewrite_entry(contents, locale: 'en-US')
    return contents unless contents['sys']

    WCC::Contentful::EntryLocaleTransformer.transform_to_locale(
      contents,
      locale
    )
  end
end
