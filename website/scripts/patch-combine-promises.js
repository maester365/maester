/**
 * Workaround: combine-promises@1.2.0 is missing its CJS entry point (dist/index.js).
 *
 * The package.json "main" field points to "dist/index.js", but the tsdx build
 * only produced "dist/combine-promises.cjs.development.js" and
 * "dist/combine-promises.cjs.production.min.js". On Node.js v24, the stricter
 * module resolution immediately fails with MODULE_NOT_FOUND.
 *
 * This script creates the missing dist/index.js that delegates to the correct
 * CJS bundle based on NODE_ENV, matching standard tsdx output.
 *
 * This patch can be removed once combine-promises publishes a fixed version
 * or Docusaurus removes the dependency.
 * See: https://github.com/slorber/combine-promises
 */

'use strict';

const fs = require('fs');
const path = require('path');

const indexPath = path.join(
  __dirname,
  '..',
  'node_modules',
  'combine-promises',
  'dist',
  'index.js'
);

if (fs.existsSync(indexPath)) {
  process.exit(0);
}

const content = `'use strict';

if (process.env.NODE_ENV === 'production') {
  module.exports = require('./combine-promises.cjs.production.min.js');
} else {
  module.exports = require('./combine-promises.cjs.development.js');
}
`;

const dir = path.dirname(indexPath);
if (fs.existsSync(dir)) {
  fs.writeFileSync(indexPath, content, 'utf8');
}
