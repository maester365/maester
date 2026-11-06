import React, { useEffect, useRef, useState } from "react";
import { Popover as PopoverPrimitive } from "radix-ui";
import { Command as CommandPrimitive } from "cmdk";
import clsx from "clsx";
import { HANDLE } from "./generate";
import { DeleteIcon } from "./ui";
import ui from "./ui.module.css";
import styles from "./styles.module.css";

// Authors and contributors are GitHub handles. Typing looks up public profiles on GitHub from the browser, without
// signing in. GitHub allows about ten searches a minute that way, so when the limit is reached the handle can
// still be typed and added as written.

const profiles = new Map(); // handle (lowercase) -> Promise of { login, name } or null when there is no such user
function profile(handle) {
  const key = handle.toLowerCase();
  if (!profiles.has(key)) {
    profiles.set(
      key,
      fetch("https://api.github.com/users/" + encodeURIComponent(handle))
        .then((r) => (r.status === 404 ? null : r.ok ? r.json() : Promise.reject(new Error(r.status))))
        .then((u) => (u ? { login: u.login, name: u.name } : null))
        .catch(() => {
          profiles.delete(key); // Not known: GitHub was unreachable or rate limited. Try again next time.
          return undefined;
        })
    );
  }
  return profiles.get(key);
}

const avatar = (handle, size = 40) => "https://github.com/" + encodeURIComponent(handle) + ".png?size=" + size;

function Person({ handle, onRemove }) {
  const [info, setInfo] = useState(undefined);
  useEffect(() => {
    let live = true;
    if (HANDLE.test(handle)) profile(handle).then((p) => live && setInfo(p));
    return () => {
      live = false;
    };
  }, [handle]);
  const missing = info === null;
  return (
    <li className={clsx(styles.person, missing && styles.personMissing)} title={missing ? "No GitHub user has this handle" : info && info.name ? info.name : undefined}>
      {!missing && <img src={avatar(handle)} alt="" width="20" height="20" loading="lazy" />}
      <span>
        {info && info.name ? (
          <>
            {info.name} <span className={styles.personHandle}>@{info.login}</span>
          </>
        ) : (
          "@" + handle
        )}
        {missing && <span className={styles.personHandle}> · not found on GitHub</span>}
      </span>
      <button type="button" className={styles.iconButton} aria-label={"Remove " + handle} title="Remove" onClick={onRemove}>
        <DeleteIcon />
      </button>
    </li>
  );
}

export default function GitHubPeople({ id, value, onChange, placeholder }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState([]);
  const [status, setStatus] = useState("idle"); // idle | searching | done | limited | failed
  const latest = useRef("");
  const q = query.trim().replace(/^@/, "");

  useEffect(() => {
    latest.current = q;
    if (q.length < 2) {
      setResults([]);
      setStatus("idle");
      return undefined;
    }
    setStatus("searching");
    const timer = setTimeout(() => {
      fetch("https://api.github.com/search/users?per_page=8&q=" + encodeURIComponent(q + " in:login in:name"))
        .then((r) => (r.status === 403 || r.status === 429 ? Promise.reject(new Error("limited")) : r.ok ? r.json() : Promise.reject(new Error("failed"))))
        .then((body) => {
          if (latest.current !== q) return;
          setResults(body.items.map((u) => u.login));
          setStatus("done");
        })
        .catch((e) => latest.current === q && (setResults([]), setStatus(e.message === "limited" ? "limited" : "failed")));
    }, 350);
    return () => clearTimeout(timer);
  }, [q]);

  const add = (handle) => {
    if (!value.some((v) => v.toLowerCase() === handle.toLowerCase())) onChange([...value, handle]);
    setQuery("");
  };
  const typed = HANDLE.test(q) && !results.some((r) => r.toLowerCase() === q.toLowerCase());
  const open = q.length > 0;

  return (
    <div className={styles.people}>
      {value.length > 0 && (
        <ul className={styles.personList}>
          {value.map((handle) => (
            <Person key={handle} handle={handle} onRemove={() => onChange(value.filter((v) => v !== handle))} />
          ))}
        </ul>
      )}
      <CommandPrimitive shouldFilter={false} loop>
        <PopoverPrimitive.Root open={open} onOpenChange={(o) => !o && setQuery("")}>
          <PopoverPrimitive.Anchor asChild>
            <CommandPrimitive.Input
              id={id}
              className={ui.input}
              value={query}
              onValueChange={setQuery}
              placeholder={placeholder || "Search GitHub by name or handle"}
              autoComplete="off"
              onKeyDown={(e) => {
                if (e.key === "Escape") setQuery("");
              }}
            />
          </PopoverPrimitive.Anchor>
          <PopoverPrimitive.Portal>
            <PopoverPrimitive.Content className={clsx(ui.popover, ui.comboContent)} align="start" sideOffset={4} onOpenAutoFocus={(e) => e.preventDefault()} onInteractOutside={(e) => e.target.closest && e.target.closest("#" + id) && e.preventDefault()}>
              <CommandPrimitive.List className={ui.commandList}>
                {results.map((login) => (
                  <CommandPrimitive.Item key={login} value={login} onSelect={() => add(login)} className={ui.item}>
                    <img className={styles.personAvatar} src={avatar(login)} alt="" width="20" height="20" loading="lazy" />
                    <span>{login}</span>
                  </CommandPrimitive.Item>
                ))}
                {typed && (
                  <CommandPrimitive.Item value={"use:" + q} onSelect={() => add(q)} className={ui.item}>
                    Add “{q}” as written
                  </CommandPrimitive.Item>
                )}
                {status === "searching" && results.length === 0 && <div className={ui.commandEmpty}>Searching GitHub…</div>}
                {status === "done" && results.length === 0 && <div className={ui.commandEmpty}>No GitHub user matches.</div>}
                {status === "limited" && <div className={ui.commandEmpty}>GitHub's search limit for this browser is reached for a minute. Type the full handle and add it as written.</div>}
                {status === "failed" && <div className={ui.commandEmpty}>GitHub could not be reached. Type the full handle and add it as written.</div>}
              </CommandPrimitive.List>
            </PopoverPrimitive.Content>
          </PopoverPrimitive.Portal>
        </PopoverPrimitive.Root>
      </CommandPrimitive>
    </div>
  );
}
