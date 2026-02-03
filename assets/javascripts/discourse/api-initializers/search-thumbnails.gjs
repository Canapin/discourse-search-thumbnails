import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { apiInitializer } from "discourse/lib/api";
import { addSearchResultsCallback } from "discourse/lib/search";

const MOBILE_REDUCTION = 2;

const moveAfterBlurb = modifier((element) => {
  const searchLink = element.closest(".search-link");
  if (searchLink) {
    searchLink.appendChild(element);
  }
});

const isLastIndex = (index, length) => index === length - 1;

class SearchThumbnails extends Component {
  @service capabilities;
  @service siteSettings;

  get maxThumbnails() {
    const setting = this.siteSettings.search_thumbnails_max_count;
    if (setting === 0) {
      return Infinity;
    }
    return this.capabilities.viewport.md
      ? setting
      : Math.max(1, setting - MOBILE_REDUCTION);
  }

  get imageData() {
    const data =
      this.args.outletArgs.post?.image_search_data ||
      this.args.outletArgs.topic?.search_result_image_data ||
      {};

    console.log("--- Search Thumbnail Debug ---");
    console.log("Post ID:", this.args.outletArgs.post?.id);
    console.log("Topic ID:", this.args.outletArgs.topic?.id);
    console.log("Data returned:", data);

    return data;
  }

  get visibleImages() {
    return (this.imageData.urls || []).slice(0, this.maxThumbnails);
  }

  get extraCount() {
    const total = this.imageData.total || 0;
    return total > this.maxThumbnails ? total - this.maxThumbnails : 0;
  }
}

class QuickSearchThumbnails extends SearchThumbnails {
  <template>
    {{#if this.visibleImages.length}}
      <span class="search-result-thumbnails" {{moveAfterBlurb}}>
        {{#each this.visibleImages as |imageUrl index|}}
          <span class="search-result-thumbnail-wrapper">
            <img class="search-result-thumbnail" src={{imageUrl}} />
            {{#if (isLastIndex index this.visibleImages.length)}}
              {{#if this.extraCount}}
                <span
                  class="search-result-thumbnail-more"
                >+{{this.extraCount}}</span>
              {{/if}}
            {{/if}}
          </span>
        {{/each}}
      </span>
    {{/if}}
  </template>
}

class FullPageSearchThumbnails extends SearchThumbnails {
  <template>
    {{#if this.visibleImages.length}}
      <div class="search-result-thumbnails">
        {{#each this.visibleImages as |imageUrl index|}}
          <span class="search-result-thumbnail-wrapper">
            <img class="search-result-thumbnail" src={{imageUrl}} />
            {{#if (isLastIndex index this.visibleImages.length)}}
              {{#if this.extraCount}}
                <span
                  class="search-result-thumbnail-more"
                >+{{this.extraCount}}</span>
              {{/if}}
            {{/if}}
          </span>
        {{/each}}
      </div>
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.search_thumbnails_enabled) {
    return;
  }

  addSearchResultsCallback((results) => {
    results.posts?.forEach((post) => {
      if (post.image_search_data) {
        post.topic.set("search_result_image_data", post.image_search_data);
      }
    });
    return results;
  });

  api.renderInOutlet(
    "search-menu-results-topic-title-suffix",
    QuickSearchThumbnails
  );

  api.renderAfterWrapperOutlet(
    "search-result-entry-blurb-wrapper",
    FullPageSearchThumbnails
  );
});
