# Explainer voice-over and music

Tools for the audio of the website's explainers (`website/public/explainers/<slug>/`). They are not part of the site
build and CI never installs them.

```shell
cd website/scripts/narration
npm install
node narrate.mjs how-it-works   # Kokoro voice-over from the chapters in src/data/explainers.json
node music.mjs how-it-works     # an original music bed, mixed under the voice into audio/mix.mp3
```

- `narrate.mjs` reads each chapter's `say` text (or `text`) and voice from `src/data/explainers.json`, records it with
  [Kokoro](https://huggingface.co/hexgrad/Kokoro-82M) (Apache 2.0; the first run downloads the model, about 330 MB),
  and writes the chapter start times back into `explainers.json` and the composition's `timings.js`.
- `music.mjs` synthesises the music in code (no samples or third-party audio, so there is nothing to license), and
  ducks it while the voice speaks.
- Spell names the way they sound in `say`: "Mayster" for Maester, "Microsoft three sixty-five", "C.I.S.", "Sissa".
