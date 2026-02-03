# frozen_string_literal: true

# name: discourse-search-thumbnails
# about: Shows thumbnail previews of images in quick search results when using the with:images filter
# version: 0.1.0
# authors: Canapin & AI
# url: https://github.com/discourse/discourse-search-thumbnails
# required_version: 2.7.0

enabled_site_setting :search_thumbnails_enabled

register_asset "stylesheets/search-thumbnails.scss"

after_initialize do
  rejected_img_classes = %w[emoji site-icon thumbnail]

  extract_image_urls = ->(cooked) do
    cooked
      .scan(/<img[^>]*>/)
      .reject do |tag|
        tag[/class="([^"]*)"/, 1]&.split&.any? { |c| rejected_img_classes.include?(c) }
      end
      .filter_map { |tag| tag[/src="([^"]+)"/, 1] }
  end

  add_to_serializer(
    :search_post,
    :image_search_data,
    include_condition: -> { include_image_data? },
  ) do
    urls = extract_image_urls.call(object.cooked)
    { urls: urls.first(5), total: urls.size }
  end

  add_to_serializer(:search_post, :include_image_data?) do
    return false if object.image_upload_id.blank?
    return true unless SiteSetting.search_thumbnails_only_with_images_filter
    options[:result]&.term&.match?(/with:images/i)
  end
end
