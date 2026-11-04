// Copies what the explainer compositions in public/explainers need from node_modules (GSAP, the HyperFrames
// runtime and the site's fonts),
// so they run the same in the site, in `npx hyperframes preview` and in `npx hyperframes render`.
import { copyFileSync, mkdirSync } from 'node:fs';

const shared = new URL('../public/explainers/_shared/', import.meta.url);
mkdirSync(new URL('fonts/', shared), { recursive: true });
const copy = (from, to) => copyFileSync(new URL(`../node_modules/${from}`, import.meta.url), new URL(to, shared));
copy('gsap/dist/gsap.min.js', 'gsap.min.js');
// The HyperFrames runtime plays a composition's audio and keeps it in step with the timeline.
copy('@hyperframes/core/dist/hyperframe.runtime.iife.js', 'hyperframe.runtime.js');
copy('@fontsource-variable/inter/files/inter-latin-wght-normal.woff2', 'fonts/inter.woff2');
copy('@fontsource/geist-mono/files/geist-mono-latin-400-normal.woff2', 'fonts/geist-mono-400.woff2');
copy('@fontsource/geist-mono/files/geist-mono-latin-500-normal.woff2', 'fonts/geist-mono-500.woff2');
