import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-search-thumbnails";

export default {
  name: "search-thumbnails-admin-plugin-icon",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "magnifying-glass");
    });
  },
};
