# frozen_string_literal: true

RSpec.describe "Search thumbnails" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:post_with_image) { Fabricate(:post_with_uploaded_image, user: user) }

  before do
    SiteSetting.search_thumbnails_enabled = true
    CookedPostProcessor.new(post_with_image).update_post_image
    SearchIndexer.enable
    SearchIndexer.index(post_with_image.topic, force: true)
    SearchIndexer.index(post_with_image, force: true)
  end

  it "includes image_search_data when searching with:images" do
    get "/search/query.json", params: { term: "with:images" }

    expect(response.status).to eq(200)
    post_data = response.parsed_body["posts"].find { |p| p["id"] == post_with_image.id }
    expect(post_data["image_search_data"]).to be_present
    expect(post_data["image_search_data"]["urls"].length).to be <= 5
    expect(post_data["image_search_data"]["total"]).to be_a(Integer)
  end

  it "excludes image_search_data without with:images filter by default" do
    get "/search/query.json", params: { term: post_with_image.topic.title }

    expect(response.status).to eq(200)
    post_data = response.parsed_body["posts"]&.find { |p| p["id"] == post_with_image.id }
    expect(post_data).not_to have_key("image_search_data") if post_data
  end

  it "includes image_search_data for all searches when only_with_images_filter is disabled" do
    SiteSetting.search_thumbnails_only_with_images_filter = false

    get "/search/query.json", params: { term: post_with_image.topic.title }

    expect(response.status).to eq(200)
    post_data = response.parsed_body["posts"]&.find { |p| p["id"] == post_with_image.id }
    expect(post_data["image_search_data"]).to be_present
  end

  it "filters out images with rejected classes" do
    post_with_image.update!(cooked: <<~HTML)
        <p><img src="/uploads/default/original/1X/real.jpg"></p>
        <p><img src="/uploads/default/original/1X/smiley.png" class="emoji"></p>
        <p><img src="/uploads/default/original/1X/icon.png" class="site-icon"></p>
        <p><img src="/uploads/default/original/1X/thumb.jpg" class="thumbnail"></p>
      HTML

    get "/search/query.json", params: { term: "with:images" }

    expect(response.status).to eq(200)
    post_data = response.parsed_body["posts"].find { |p| p["id"] == post_with_image.id }
    expect(post_data["image_search_data"]["urls"]).to eq(["/uploads/default/original/1X/real.jpg"])
    expect(post_data["image_search_data"]["total"]).to eq(1)
  end

  it "respects max_count setting" do
    post_with_image.update!(cooked: <<~HTML)
        <p><img src="/uploads/default/original/1X/img1.jpg"></p>
        <p><img src="/uploads/default/original/1X/img2.jpg"></p>
        <p><img src="/uploads/default/original/1X/img3.jpg"></p>
        <p><img src="/uploads/default/original/1X/img4.jpg"></p>
        <p><img src="/uploads/default/original/1X/img5.jpg"></p>
      HTML
    SiteSetting.search_thumbnails_max_count = 2

    get "/search/query.json", params: { term: "with:images" }

    expect(response.status).to eq(200)
    post_data = response.parsed_body["posts"].find { |p| p["id"] == post_with_image.id }
    expect(post_data["image_search_data"]["urls"].length).to eq(2)
    expect(post_data["image_search_data"]["total"]).to eq(5)
  end

  it "returns all images when max_count is 0 (unlimited)" do
    post_with_image.update!(cooked: <<~HTML)
        <p><img src="/uploads/default/original/1X/img1.jpg"></p>
        <p><img src="/uploads/default/original/1X/img2.jpg"></p>
        <p><img src="/uploads/default/original/1X/img3.jpg"></p>
        <p><img src="/uploads/default/original/1X/img4.jpg"></p>
        <p><img src="/uploads/default/original/1X/img5.jpg"></p>
        <p><img src="/uploads/default/original/1X/img6.jpg"></p>
      HTML
    SiteSetting.search_thumbnails_max_count = 0

    get "/search/query.json", params: { term: "with:images" }

    expect(response.status).to eq(200)
    post_data = response.parsed_body["posts"].find { |p| p["id"] == post_with_image.id }
    expect(post_data["image_search_data"]["urls"].length).to eq(6)
    expect(post_data["image_search_data"]["total"]).to eq(6)
  end
end
