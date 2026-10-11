import React, { useState } from "react";
import { Select as SelectPrimitive, RadioGroup as RadioGroupPrimitive, Checkbox as CheckboxPrimitive, Tabs as TabsPrimitive, Popover as PopoverPrimitive } from "radix-ui";
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
                <SelectPrimitive.ItemText>{o.label}</SelectPrimitive.ItemText>
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
  const matches = (q ? found.filter(own).concat(found.filter((i) => !own(i))) : found).slice(0, limit);
  const current = items.find((i) => i.value === value);
  const choose = (v) => {
    onSelect(v);
    if (!keepOpen) setOpen(false);
  };
  const canCreate = creatable && query.trim() && (!createPattern || createPattern.test(query.trim())) && !items.some((i) => i.value === query.trim());
  return (
    <PopoverPrimitive.Root open={open} onOpenChange={setOpen}>
      <PopoverPrimitive.Trigger id={id} className={ui.selectTrigger} role="combobox" aria-expanded={open}>
        <span className={value ? undefined : ui.placeholder}>{current ? current.label : value || placeholder}</span>
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
