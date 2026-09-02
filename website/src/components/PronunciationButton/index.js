import { useCallback, useEffect, useRef, useState } from "react";
import clsx from "clsx";
import useBaseUrl from "@docusaurus/useBaseUrl";

import styles from "./styles.module.css";

function SpeakerIcon() {
  return (
    <svg
      className={styles.icon}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M11 5 6 9H3v6h3l5 4z" />
      <path className={styles.waveInner} d="M15.5 8.8a4.5 4.5 0 0 1 0 6.4" />
      <path className={styles.waveOuter} d="M18.4 5.9a8.5 8.5 0 0 1 0 12.2" />
    </svg>
  );
}

/**
 * A small speaker button that plays a recording of how "Maester" is pronounced.
 *
 * The Audio element is created on the first click rather than on render, so the
 * file is only fetched when someone actually asks for it and nothing touches
 * `window` while Docusaurus is server-rendering the page.
 *
 * The clip lives in `static/audio/`. Keep any replacement short (~1 second),
 * trimmed of silence and faded at both ends so playback does not click.
 *
 * @param {string} [src] Path to the audio file, relative to the site base URL.
 * @param {string} [label] Accessible name, also used as the tooltip.
 * @param {string} [className] Extra class for positioning by the parent.
 */
export default function PronunciationButton({
  src = "/audio/maester-pronunciation.mp3",
  label = "Hear how Maester is pronounced",
  className,
}) {
  const audioUrl = useBaseUrl(src);
  const audioRef = useRef(null);
  const [isPlaying, setIsPlaying] = useState(false);

  useEffect(
    () => () => {
      audioRef.current?.pause();
      audioRef.current = null;
    },
    [],
  );

  const play = useCallback(() => {
    let audio = audioRef.current;
    if (!audio) {
      audio = new Audio(audioUrl);
      audio.preload = "none";
      audio.addEventListener("ended", () => setIsPlaying(false));
      audio.addEventListener("error", () => setIsPlaying(false));
      audioRef.current = audio;
    }

    audio.currentTime = 0;
    setIsPlaying(true);
    // Safari returns undefined instead of a promise, so wrap it before catching.
    Promise.resolve(audio.play()).catch(() => setIsPlaying(false));
  }, [audioUrl]);

  return (
    <button
      type="button"
      className={clsx(styles.button, isPlaying && styles.isPlaying, className)}
      onClick={play}
      aria-label={label}
      title={label}
    >
      <SpeakerIcon />
    </button>
  );
}
