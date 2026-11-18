import assert from 'node:assert/strict';
import test from 'node:test';
import { retiredTestRedirects } from '../src/lib/redirects.mjs';

test('retired check URLs and preview URLs resolve directly to the surviving check', () => {
  const actual = retiredTestRedirects(
    { Tests: [{ Id: 'AD-SITE-04' }] },
    { Tags: [{ Tag: 'AD-SUB-01', Tests: ['AD-SITE-04'] }] },
    { 'AD-SUB-01': '2.3.0' },
    (path) => path === '/docs/tests/AD-SITE-04',
  );
  assert.deepEqual(actual, [
    ['/docs/tests/AD-SUB-01', '/docs/tests/AD-SITE-04'],
    ['/docs/next/tests/AD-SUB-01', '/docs/tests/AD-SITE-04'],
  ]);
});

test('active IDs, broad tags, missing targets and unpublished names are not redirected', () => {
  const actual = retiredTestRedirects(
    { Tests: [{ Id: 'AD-SITE-04' }] },
    { Tags: [
      { Tag: 'AD-SITE-04', Tests: ['AD-SITE-04'] },
      { Tag: 'AD', Tests: ['AD-SITE-04', 'AD-SUB-03'] },
      { Tag: 'AD-SUB-01', Tests: ['MISSING'] },
      { Tag: 'unpublished', Tests: ['AD-SITE-04'] },
    ] },
    { 'AD-SITE-04': '2.3.0', 'AD-SUB-01': '2.3.0' },
    () => true,
  );
  assert.deepEqual(actual, []);
});

test('does not emit a redirect to a target page absent from the built output', () => {
  assert.deepEqual(retiredTestRedirects(
    { Tests: [{ Id: 'AD-SITE-04' }] },
    { Tags: [{ Tag: 'AD-SUB-01', Tests: ['AD-SITE-04'] }] },
    { 'AD-SUB-01': '2.3.0' },
    () => false,
  ), []);
});
