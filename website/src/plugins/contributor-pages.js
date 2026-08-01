// Registers a static route for every contributor: /contributors/<github-handle>
// (lowercased). Data comes from the generated snapshot at src/data/contributors.json.
const path = require("path");

module.exports = function contributorPagesPlugin() {
  return {
    name: "contributor-pages",
    async contentLoaded({ actions }) {
      const { addRoute, createData } = actions;
      // Resolve at call time so a regenerated snapshot is picked up on restart.
      const dataPath = path.join(__dirname, "..", "data", "contributors.json");
      delete require.cache[require.resolve(dataPath)];
      const { profiles } = require(dataPath);
      for (const profile of profiles) {
        const idModule = await createData(`contributor-${profile.id.toLowerCase()}.json`, JSON.stringify(profile.id));
        addRoute({
          path: `/contributors/${profile.id.toLowerCase()}`,
          component: "@site/src/components/ContributorPage/index.js",
          exact: true,
          modules: { contributorId: idModule },
        });
      }
    },
  };
};
