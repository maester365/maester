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
// Platform icons in colour: Windows as its four blue panes, Linux as a small Tux, macOS as the Apple mark in
// graphite (it has no colour of its own).
export const osGlyph = (name) => {
  if (name === "Windows")
    return (
      <svg className={ui.optionIcon} viewBox="0 0 24 24" aria-hidden="true">
        {[[3, 3], [12.5, 3], [3, 12.5], [12.5, 12.5]].map(([x, y]) => (
          <rect key={x + "-" + y} x={x} y={y} width="8.5" height="8.5" fill="#0078D4" />
        ))}
      </svg>
    );
  if (name === "Linux")
    return (
      <svg className={ui.optionIcon} viewBox="0 0 24 24" aria-hidden="true">
        <path
          d="M12 2.500c-2.200 0-3.600 1.700-3.600 4 0 1.600.200 2.600-.900 4.300C6 13.100 4.800 15.200 4.800 17.700c0 2 1.500 3.100 7.200 3.100s7.200-1.100 7.200-3.100c0-2.500-1.200-4.600-2.700-6.900-1.100-1.700-.900-2.700-.900-4.300 0-2.300-1.400-4-3.600-4z"
          fill="#2B2B2B"
          stroke="#8A8A8A"
          strokeWidth="0.5"
        />
        <ellipse cx="12" cy="15.6" rx="3.7" ry="4.6" fill="#fff" />
        <circle cx="10.6" cy="6.500" r="1" fill="#fff" />
        <circle cx="13.4" cy="6.500" r="1" fill="#fff" />
        <circle cx="10.8" cy="6.600" r="0.450" fill="#2B2B2B" />
        <circle cx="13.2" cy="6.600" r="0.450" fill="#2B2B2B" />
        <path d="M9.800 8.600l2.200-1.100 2.200 1.100-2.200 1.800z" fill="#F5B301" />
        <ellipse cx="7.800" cy="20.800" rx="3.200" ry="1.600" fill="#F5B301" />
        <ellipse cx="16.200" cy="20.800" rx="3.200" ry="1.600" fill="#F5B301" />
      </svg>
    );
  return OS_PATHS[name] ? (
    <svg className={ui.optionIcon} viewBox="0 0 24 24" aria-hidden="true">
      <path fill="#7D7D82" d={OS_PATHS[name]} />
    </svg>
  ) : null;
};

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
            <span className={ui.radioLabel}>
              {o.icon}
              {o.label || o.value}
            </span>
            {o.text && <span className={ui.radioText}>{o.text}</span>}
          </span>
        </label>
      ))}
    </RadioGroupPrimitive.Root>
  );
}

// One stroke icon per attribute. The paths shared with the HTML report are those of report/src/components/
// report/ui.tsx, so an attribute has the same icon here as in the report.
const ATTRIBUTE_ICONS = {
  product: "M21 8l-9-5-9 5 9 5 9-5zM3 8v8l9 5 9-5V8M12 13v8",
  related: "M8 7h11v11M19 7 5 21",
  feature: "M12 3l9 5-9 5-9-5 9-5zM3 13l9 5 9-5",
  area: "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6l8-3z",
  resource: "M12 4a8 8 0 1 0 0 16 8 8 0 0 0 0-16zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z",
  severity: "M12 4l9 16H3L12 4zM12 10v4M12 17h.01",
  impact: "M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM3 20c0-3 3-5 6-5s6 2 6 5M16 5a3 3 0 0 1 0 6M21 20c0-2.5-1.5-4.3-4-4.8",
  effort: "M14.7 6.3a4 4 0 0 0-5.4 5.2L3 17.8V21h3.2l6.3-6.3a4 4 0 0 0 5.2-5.4l-2.6 2.6-2.4-.6-.6-2.4z",
  lifecycle: "M6 3v12M18 9a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM6 21a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM18 9a9 9 0 0 1-9 9",
  service: "M9 2v6M15 2v6M6 8h12v4a6 6 0 0 1-12 0V8zM12 18v4",
  licence: "M4 7h16v10H4zM8 11h5M8 14h3M16 11v3",
  permission: "M6 11h12v10H6zM8 11V7a4 4 0 0 1 8 0v4",
  duration: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 7v5l3 2",
  source: "M3 7h6l2 2h10v10H3z",
  framework: "M9 5h11M9 12h11M9 19h11M4 5l1 1 2-2M4 12l1 1 2-2M4 19l1 1 2-2",
  attack: "M12 3v4M12 17v4M3 12h4M17 12h4M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z",
  tag: "M3 12V3h9l9 9-9 9-9-9zM7.5 7.5h.01",
  params: "M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M14 4v4M8 10v4M16 16v4",
  // Only here: the report has no row for these.
  id: "M5 9h14M5 15h14M10 4 8 20M16 4l-2 16",
  title: "M4 6h16M4 12h16M4 18h10",
  code: "M8 6l-6 6 6 6M16 6l6 6-6 6",
  tenant: "M4 21V5l8-2v18M12 9h8v12M8 8h.01M8 12h.01M8 16h.01M16 13h.01M16 17h.01M2 21h20",
  cloud: "M7 18a4 4 0 0 1-.5-8 6 6 0 0 1 11.6 1.5A3.5 3.5 0 0 1 17.5 18z",
  platform: "M3 5h18v11H3zM8 20h8M12 16v4",
  person: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21c0-4 3.6-6 8-6s8 2 8 6",
  preview: "M9 3h6M10 3v6l-5 9a2 2 0 0 0 1.8 3h10.4a2 2 0 0 0 1.8-3l-5-9V3M7.5 15h9",
  stable: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8 12l3 3 5-6",
  deprecated: "M3 5h18v4H3zM5 9v10h14V9M10 13h4",
  explore: "M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM21 21l-5-5M8 11h6M11 8v6",
  maester: "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6l8-3zM9 12l2 2 4-4",
};
export function AttributeIcon({ name, tone, className }) {
  if (!ATTRIBUTE_ICONS[name]) return null;
  return (
    <svg className={clsx(ui.attrIcon, tone && ui["tone-" + tone], className)} viewBox="0 0 24 24" aria-hidden="true">
      <path d={ATTRIBUTE_ICONS[name]} />
    </svg>
  );
}

// Small flags for the national clouds, drawn here because flag emoji do not render on Windows. They are
// simplified to read at 16 pixels: the colours and layout of each flag, not every star.
const star = (cx, cy, r) =>
  Array.from({ length: 10 }, (_, i) => {
    const a = (Math.PI / 5) * i - Math.PI / 2;
    const d = i % 2 ? r * 0.4 : r;
    return (cx + d * Math.cos(a)).toFixed(2) + "," + (cy + d * Math.sin(a)).toFixed(2);
  }).join(" ");
const FLAGS = {
  us: (
    <>
      <rect width="20" height="14" fill="#fff" />
      {[0, 4, 8, 12].map((y) => (
        <rect key={y} y={y} width="20" height="2" fill="#B22234" />
      ))}
      <rect width="9" height="8" fill="#3C3B6E" />
      {[2.25, 4.5, 6.75].map((x) => [2.5, 5.5].map((y) => <circle key={x + "-" + y} cx={x} cy={y} r="0.6" fill="#fff" />))}
    </>
  ),
  cn: (
    <>
      <rect width="20" height="14" fill="#DE2910" />
      <polygon points={star(4.5, 4.5, 2.6)} fill="#FFDE00" />
      {[[8.5, 1.8], [10, 3.6], [10, 6], [8.5, 7.8]].map(([x, y]) => (
        <circle key={y} cx={x} cy={y} r="0.6" fill="#FFDE00" />
      ))}
    </>
  ),
  fr: (
    <>
      <rect width="20" height="14" fill="#fff" />
      <rect width="6.67" height="14" fill="#0055A4" />
      <rect x="13.33" width="6.67" height="14" fill="#EF4135" />
    </>
  ),
  de: (
    <>
      <rect width="20" height="14" fill="#DD0000" />
      <rect width="20" height="4.67" fill="#000" />
      <rect y="9.33" width="20" height="4.67" fill="#FFCE00" />
    </>
  ),
  sg: (
    <>
      <rect width="20" height="14" fill="#fff" />
      <rect width="20" height="7" fill="#EF3340" />
      <circle cx="5" cy="3.5" r="2.4" fill="#fff" />
      <circle cx="6" cy="3.5" r="2.2" fill="#EF3340" />
      {[[7.6, 1.9], [6.4, 2.9], [8.8, 2.9], [6.9, 4.4], [8.3, 4.4]].map(([x, y]) => (
        <circle key={x} cx={x} cy={y} r="0.5" fill="#fff" />
      ))}
    </>
  ),
};
export function Flag({ country, label }) {
  if (!FLAGS[country])
    return (
      <svg className={ui.flagGlobe} viewBox="0 0 16 16" role="img" aria-label={label}>
        <title>{label}</title>
        <circle cx="8" cy="8" r="7" fill="#2B88D8" />
        <path d="M4.2 3.1c1.2-.3 2.3.1 2.9 1 .5.9-.2 1.600-1 2.100-.9.500-.7 1.500-1.600 1.800C3.400 8.300 2.300 7.500 1.600 6.300c.4-1.400 1.300-2.500 2.600-3.200zM9.600 7.400c1-.6 2.400-.4 3.300.3.800.7 1.900.6 2 1.500-.3 1.700-1.300 3.200-2.700 4.100-.9-.3-1.100-1.300-1.900-1.900-.8-.6-1.600-1.200-1.600-2.200 0-.8.300-1.400.9-1.800zM5.300 10.600c.8.100 1.400.7 1.500 1.500.1.800-.2 1.700-.8 2.300-1.300-.4-2.400-1.300-3.100-2.400.6-.800 1.500-1.400 2.400-1.400z" fill="#57C454" />
        <circle cx="8" cy="8" r="6.6" fill="none" stroke="#1B5FA8" strokeWidth="0.8" />
      </svg>
    );
  return (
    <svg className={ui.flag} viewBox="0 0 20 14" role="img" aria-label={label}>
      <title>{label}</title>
      {FLAGS[country]}
    </svg>
  );
}

// A level, drawn as bars: `level` of `of` are filled, in the colour of `tone`. Info is a circled i, because an
// Info test makes no judgement and so has no level.
export function LevelIcon({ level, of = 3, tone }) {
  if (!level)
    return (
      <svg className={clsx(ui.level, ui["tone-" + tone])} viewBox="0 0 16 16" aria-hidden="true">
        <circle cx="8" cy="8" r="6.25" fill="none" stroke="currentColor" strokeWidth="1.5" />
        <path d="M8 7.25v4M8 4.75h.01" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
      </svg>
    );
  const width = of > 3 ? 2.5 : 3.25;
  const gap = (16 - of * width) / (of + 1);
  return (
    <svg className={clsx(ui.level, ui["tone-" + tone])} viewBox="0 0 16 16" aria-hidden="true">
      {Array.from({ length: of }, (_, i) => {
        const height = 4 + ((i + 1) * 10) / of;
        return <rect key={i} x={gap + i * (width + gap)} y={15 - height} width={width} height={height} rx="0.75" fill="currentColor" opacity={i < level ? 1 : 0.22} />;
      })}
    </svg>
  );
}

// A radio group as one row of choices. Only the selected option's text is shown, under the row.
export function RadioPills({ value, onValueChange, options, label }) {
  const picked = options.find((o) => o.value === value);
  return (
    <div className={ui.pillsWrap}>
      <RadioGroupPrimitive.Root className={ui.pills} value={value} onValueChange={onValueChange} aria-label={label}>
        {options.map((o) => (
          <RadioGroupPrimitive.Item key={o.value} value={o.value} className={ui.pill} title={o.text}>
            {o.icon}
            {o.label || o.value}
          </RadioGroupPrimitive.Item>
        ))}
      </RadioGroupPrimitive.Root>
      {picked && picked.text && <p className={ui.pillText}>{picked.text}</p>}
    </div>
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
const KEEP_OPEN = '[data-help-trigger], #starlight__sidebar ul.top-level a, main a[href^="/docs/"], [data-radix-popper-content-wrapper]';
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
        <DialogPrimitive.Content data-help-sheet className={ui.sheet} style={style} onPointerDownOutside={keepOpenFor} onFocusOutside={(e) => e.preventDefault()} onOpenAutoFocus={(e) => e.preventDefault()}>
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
