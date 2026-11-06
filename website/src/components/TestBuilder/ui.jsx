import React, { useState } from "react";
import { Select as SelectPrimitive, RadioGroup as RadioGroupPrimitive, Checkbox as CheckboxPrimitive, Tabs as TabsPrimitive, Popover as PopoverPrimitive, Dialog as DialogPrimitive } from "radix-ui";
import { Command as CommandPrimitive } from "cmdk";
import clsx from "clsx";
import ui from "./ui.module.css";

// shadcn/ui components for the test builder. The site has no Tailwind, so these are the same Radix and cmdk
// primitives shadcn wraps, with its default look written as a CSS module on the site's own colour variables.

const Chevron = () => (
  <svg className={ui.icon} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="m6 9 6 6 6-6" />
  </svg>
);
const Check = () => (
  <svg className={ui.icon} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M20 6 9 17l-5-5" />
  </svg>
);

export const PlusIcon = () => (
  <svg className={ui.icon} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M12 5v14M5 12h14" />
  </svg>
);
export const DeleteIcon = () => (
  <svg className={ui.icon} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6M10 11v6M14 11v6" />
  </svg>
);

// Operating system marks (Material Design Icons, from the site's @iconify-json/mdi), for the Platform values.
const OS_PATHS = {
  Windows: "M3 12V6.75l6-1.32v6.48zm17-9v8.75l-10 .15V5.21zM3 13l6 .09v6.81l-6-1.15zm17 .25V22l-10-1.91V13.1z",
  Linux:
    "M14.62 8.35c-.42.28-1.75 1.04-1.95 1.19c-.39.31-.75.29-1.14-.01c-.2-.16-1.53-.92-1.95-1.19c-.48-.31-.45-.7.08-.92c1.64-.69 3.28-.64 4.91.03c.49.21.51.6.05.9m7.22 7.28c-.93-2.09-2.2-3.99-3.84-5.66a4.3 4.3 0 0 1-1.06-1.88c-.1-.33-.17-.67-.24-1.01c-.2-.88-.29-1.78-.7-2.61c-.73-1.58-2-2.4-3.84-2.47c-1.81.05-3.16.81-3.95 2.4c-.21.43-.36.88-.46 1.34c-.17.76-.32 1.55-.5 2.32c-.15.65-.45 1.21-.96 1.71c-1.61 1.57-2.9 3.37-3.88 5.35c-.14.29-.28.58-.37.88c-.19.66.29 1.12.99.96c.44-.09.88-.18 1.3-.31c.41-.15.57-.05.67.35c.65 2.15 2.07 3.66 4.24 4.5c4.12 1.56 8.93-.66 9.97-4.58c.07-.27.17-.37.47-.27c.46.14.93.24 1.4.35c.49.09.85-.16.92-.64c.03-.26-.06-.49-.16-.73",
  MacOS:
    "M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47c-1.34.03-1.77-.79-3.29-.79c-1.53 0-2 .77-3.27.82c-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51c1.28-.02 2.5.87 3.29.87c.78 0 2.26-1.07 3.81-.91c.65.03 2.47.26 3.64 1.98c-.09.06-2.17 1.28-2.15 3.81c.03 3.02 2.65 4.03 2.68 4.04c-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5c.13 1.17-.34 2.35-1.04 3.19c-.69.85-1.83 1.51-2.95 1.42c-.15-1.15.41-2.35 1.05-3.11",
};
export const osGlyph = (name) =>
  OS_PATHS[name] ? (
    <svg className={ui.optionIcon} viewBox="0 0 24 24" aria-hidden="true">
      <path fill="currentColor" d={OS_PATHS[name]} />
    </svg>
  ) : null;

// The icon of an option: an image, a glyph, or a small tile with initials when there is no image.
export function OptionIcon({ icon, initials, glyph }) {
  if (glyph) return glyph;
  if (icon) return <img className={ui.optionIcon} src={icon} alt="" width="16" height="16" loading="lazy" />;
  if (initials) return <span className={ui.optionTile} aria-hidden="true">{initials}</span>;
  return null;
}

export function Button({ variant = "outline", size = "sm", className, ...props }) {
  return <button type="button" className={clsx(ui.button, ui["button-" + variant], ui["button-" + size], className)} {...props} />;
}

export function Input({ className, ...props }) {
  return <input className={clsx(ui.input, className)} {...props} />;
}

export function Textarea({ className, ...props }) {
  return <textarea className={clsx(ui.input, ui.textarea, className)} {...props} />;
}

export function Badge({ variant = "secondary", className, ...props }) {
  return <span className={clsx(ui.badge, ui["badge-" + variant], className)} {...props} />;
}

// options: [{ value, label, hint? }]. footer: one extra option shown after a separator.
export function Select({ id, value, onValueChange, placeholder, options, footer }) {
  return (
    <SelectPrimitive.Root value={value || undefined} onValueChange={onValueChange}>
      <SelectPrimitive.Trigger id={id} className={ui.selectTrigger} aria-label={placeholder}>
        <SelectPrimitive.Value placeholder={placeholder} />
        <SelectPrimitive.Icon>
          <Chevron />
        </SelectPrimitive.Icon>
      </SelectPrimitive.Trigger>
      <SelectPrimitive.Portal>
        <SelectPrimitive.Content className={ui.popover} position="popper" sideOffset={4}>
          <SelectPrimitive.Viewport className={ui.selectViewport}>
            {options.map((o) => (
              <SelectPrimitive.Item key={o.value} value={o.value} className={ui.item}>
                <SelectPrimitive.ItemText>
                  <span className={ui.withIcon}>
                    <OptionIcon icon={o.icon} initials={o.initials} />
                    {o.label}
                  </span>
                </SelectPrimitive.ItemText>
                {o.hint && <span className={ui.itemHint}>{o.hint}</span>}
                <SelectPrimitive.ItemIndicator className={ui.itemCheck}>
                  <Check />
                </SelectPrimitive.ItemIndicator>
              </SelectPrimitive.Item>
            ))}
            {footer && (
              <>
                <SelectPrimitive.Separator className={ui.separator} />
                <SelectPrimitive.Item value={footer.value} className={ui.item}>
                  <SelectPrimitive.ItemText>{footer.label}</SelectPrimitive.ItemText>
                  <SelectPrimitive.ItemIndicator className={ui.itemCheck}>
                    <Check />
                  </SelectPrimitive.ItemIndicator>
                </SelectPrimitive.Item>
              </>
            )}
          </SelectPrimitive.Viewport>
        </SelectPrimitive.Content>
      </SelectPrimitive.Portal>
    </SelectPrimitive.Root>
  );
}

// Radio cards. options: [{ value, label?, text? }]
export function RadioCards({ value, onValueChange, options, label, columns }) {
  return (
    <RadioGroupPrimitive.Root className={clsx(ui.radioGroup, columns && ui.radioColumns)} value={value} onValueChange={onValueChange} aria-label={label}>
      {options.map((o) => (
        <label key={o.value} className={clsx(ui.radioCard, value === o.value && ui.radioCardOn)}>
          <RadioGroupPrimitive.Item value={o.value} className={ui.radio}>
            <RadioGroupPrimitive.Indicator className={ui.radioDot} />
          </RadioGroupPrimitive.Item>
          <span className={ui.radioBody}>
            <span className={ui.radioLabel}>{o.label || o.value}</span>
            {o.text && <span className={ui.radioText}>{o.text}</span>}
          </span>
        </label>
      ))}
    </RadioGroupPrimitive.Root>
  );
}

export function Checkbox({ checked, onCheckedChange, children }) {
  return (
    <label className={ui.checkRow}>
      <CheckboxPrimitive.Root className={ui.checkbox} checked={checked} onCheckedChange={(v) => onCheckedChange(v === true)}>
        <CheckboxPrimitive.Indicator>
          <Check />
        </CheckboxPrimitive.Indicator>
      </CheckboxPrimitive.Root>
      <span>{children}</span>
    </label>
  );
}

export function Tabs({ value, onValueChange, tabs, children }) {
  return (
    <TabsPrimitive.Root value={value} onValueChange={onValueChange}>
      <TabsPrimitive.List className={ui.tabsList}>
        {tabs.map(([key, label]) => (
          <TabsPrimitive.Trigger key={key} value={key} className={ui.tabsTrigger}>
            {label}
          </TabsPrimitive.Trigger>
        ))}
      </TabsPrimitive.List>
      {children}
    </TabsPrimitive.Root>
  );
}
export const TabsContent = (props) => <TabsPrimitive.Content className={ui.tabsContent} {...props} />;

// A searchable list in a popover (shadcn's Combobox). items: [{ value, label, hint?, keywords? }].
// With `creatable`, the typed text can be used as a value of its own.
export function Combobox({ id, value, onSelect, items, placeholder, searchPlaceholder, empty, creatable, keepOpen, hintFor, createPattern, disabledValues = [], limit = 50 }) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const q = query.trim().toLowerCase();
  // An item may bring its own lowercase `search` text, for long lists with many keywords.
  // Items whose own name matches come before items that match only through a keyword.
  const own = (i) => (i.primary || (i.value + " " + i.label).toLowerCase()).includes(q);
  const found = q ? items.filter((i) => (i.search || (i.value + " " + i.label + " " + (i.hint || "")).toLowerCase()).includes(q)) : items;
  // Among those, an item with a higher `weight` (a plan in more products) comes first.
  const byWeight = (a, b) => (b.weight || 0) - (a.weight || 0);
  const matches = (q ? found.filter(own).sort(byWeight).concat(found.filter((i) => !own(i))) : found).slice(0, limit);
  const current = items.find((i) => i.value === value);
  const choose = (v) => {
    onSelect(v);
    if (!keepOpen) setOpen(false);
  };
  const canCreate = creatable && query.trim() && (!createPattern || createPattern.test(query.trim())) && !items.some((i) => i.value === query.trim());
  return (
    <PopoverPrimitive.Root open={open} onOpenChange={setOpen}>
      <PopoverPrimitive.Trigger id={id} className={ui.selectTrigger} role="combobox" aria-expanded={open}>
        <span className={clsx(ui.withIcon, !value && ui.placeholder)}>
          {current && <OptionIcon icon={current.icon} initials={current.initials} />}
          {current ? current.label : value || placeholder}
        </span>
        <Chevron />
      </PopoverPrimitive.Trigger>
      <PopoverPrimitive.Portal>
        <PopoverPrimitive.Content className={clsx(ui.popover, ui.comboContent)} align="start" sideOffset={4}>
          <CommandPrimitive shouldFilter={false}>
            <CommandPrimitive.Input className={ui.commandInput} value={query} onValueChange={setQuery} placeholder={searchPlaceholder || "Search"} />
            <CommandPrimitive.List className={ui.commandList}>
              {matches.length === 0 && !canCreate && <div className={ui.commandEmpty}>{empty || "Nothing matches."}</div>}
              {matches.map((i) => (
                <CommandPrimitive.Item key={i.value} value={i.value} disabled={disabledValues.includes(i.value)} onSelect={() => choose(i.value)} className={ui.item}>
                  <OptionIcon icon={i.icon} initials={i.initials} />
                  <span className={ui.itemMain}>
                    <span>{i.label}</span>
                    {(hintFor ? hintFor(i, q) : i.hint) && <span className={ui.itemHint}>{hintFor ? hintFor(i, q) : i.hint}</span>}
                  </span>
                  {(i.value === value || disabledValues.includes(i.value)) && (
                    <span className={ui.itemCheck}>
                      <Check />
                    </span>
                  )}
                </CommandPrimitive.Item>
              ))}
              {canCreate && (
                <CommandPrimitive.Item value={"create:" + query} onSelect={() => choose(query.trim())} className={ui.item}>
                  Use “{query.trim()}”
                </CommandPrimitive.Item>
              )}
            </CommandPrimitive.List>
          </CommandPrimitive>
        </PopoverPrimitive.Content>
      </PopoverPrimitive.Portal>
    </PopoverPrimitive.Root>
  );
}

export function Dialog({ open, onOpenChange, title, description, children }) {
  return (
    <DialogPrimitive.Root open={open} onOpenChange={onOpenChange}>
      <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay className={ui.overlay} />
        <DialogPrimitive.Content className={ui.dialog}>
          <div className={ui.dialogHead}>
            <div>
              <DialogPrimitive.Title className={ui.dialogTitle}>{title}</DialogPrimitive.Title>
              {description && <DialogPrimitive.Description className={ui.dialogDescription}>{description}</DialogPrimitive.Description>}
            </div>
            <DialogPrimitive.Close asChild>
              <Button variant="outline">Done</Button>
            </DialogPrimitive.Close>
          </div>
          {children}
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}

const Close = () => (
  <svg className={ui.icon} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M18 6 6 18M6 6l12 12" />
  </svg>
);

// A click elsewhere on the page closes the panel, except on what opens or switches it (a help button or a sidebar
// guide), which would otherwise close it and open it again, and inside a dropdown, which renders outside the panel.
const KEEP_OPEN = "[data-help-trigger], #starlight__sidebar ul.top-level a, [data-radix-popper-content-wrapper]";
const keepOpenFor = (e) => {
  const target = e.detail && e.detail.originalEvent ? e.detail.originalEvent.target : e.target;
  if (target && target.closest && target.closest(KEEP_OPEN)) e.preventDefault();
};

// A help panel that slides in at the side of the page (shadcn's Sheet). It is not modal: the form stays usable
// while it is open, so a contributor can read the rubric and pick a value at the same time.
export function Sheet({ open, onOpenChange, title, badge, actions, style, children }) {
  return (
    <DialogPrimitive.Root open={open} onOpenChange={onOpenChange} modal={false}>
      <DialogPrimitive.Portal>
        <DialogPrimitive.Content className={ui.sheet} style={style} onPointerDownOutside={keepOpenFor} onFocusOutside={(e) => e.preventDefault()} onOpenAutoFocus={(e) => e.preventDefault()}>
          <div className={ui.sheetHead}>
            <DialogPrimitive.Title className={ui.sheetTitle}>{title}</DialogPrimitive.Title>
            {badge && <Badge variant="outline">{badge}</Badge>}
            {actions && <span className={ui.sheetActions}>{actions}</span>}
            <DialogPrimitive.Close asChild>
              <Button variant="ghost" className={ui.sheetClose} aria-label="Close help">
                <Close />
              </Button>
            </DialogPrimitive.Close>
          </div>
          <DialogPrimitive.Description className={ui.srOnly}>Help for {title}</DialogPrimitive.Description>
          <div className={ui.sheetBody}>{children}</div>
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}

// The button that opens a field's help.
export function HelpButton({ open, onClick, label, children }) {
  return (
    <button type="button" data-help-trigger className={clsx(ui.helpButton, open && ui.helpButtonOn)} onClick={onClick} aria-expanded={open} aria-label={children ? undefined : "Help: " + label}>
      <svg className={ui.icon} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <circle cx="12" cy="12" r="10" />
        <path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3M12 17h.01" />
      </svg>
      {children}
    </button>
  );
}
