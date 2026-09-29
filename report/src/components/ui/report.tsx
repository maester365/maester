import {
  Children,
  type ComponentType,
  type HTMLAttributes,
  type InputHTMLAttributes,
  type ReactElement,
  type ReactNode,
  type RefObject,
  useEffect,
  useRef,
  useState,
} from "react"
import { XCircleIcon } from "@heroicons/react/20/solid"
import { ChevronDown, Search, X } from "lucide-react"

import { cn } from "@/lib/utils"

export function Card({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "report-card rounded-lg bg-white p-6 dark:bg-zinc-900",
        className,
      )}
      {...props}
    />
  )
}

const gridColumns = {
  1: "grid-cols-1",
  2: "sm:grid-cols-2",
  3: "lg:grid-cols-3",
  4: "lg:grid-cols-4",
  5: "lg:grid-cols-5",
}

export function Grid({
  numItemsSm,
  numItemsMd,
  numItemsLg,
  className,
  ...props
}: HTMLAttributes<HTMLDivElement> & {
  numItemsSm?: keyof typeof gridColumns
  numItemsMd?: keyof typeof gridColumns
  numItemsLg?: keyof typeof gridColumns
}) {
  return (
    <div
      className={cn(
        "grid grid-cols-1",
        numItemsSm && gridColumns[numItemsSm],
        numItemsMd === 2 && "md:grid-cols-2",
        numItemsMd === 3 && "md:grid-cols-3",
        numItemsLg && gridColumns[numItemsLg],
        className,
      )}
      {...props}
    />
  )
}

export function Flex({
  alignItems = "center",
  justifyContent = "between",
  className,
  ...props
}: HTMLAttributes<HTMLDivElement> & {
  alignItems?: "start" | "center" | "end" | "baseline"
  justifyContent?: "start" | "center" | "end" | "between"
}) {
  return (
    <div
      className={cn(
        "flex w-full flex-row",
        alignItems === "start" && "items-start",
        alignItems === "center" && "items-center",
        alignItems === "end" && "items-end",
        alignItems === "baseline" && "items-baseline",
        justifyContent === "start" && "justify-start",
        justifyContent === "center" && "justify-center",
        justifyContent === "end" && "justify-end",
        justifyContent === "between" && "justify-between",
        className,
      )}
      {...props}
    />
  )
}

export function Title({ className, ...props }: HTMLAttributes<HTMLParagraphElement>) {
  return <p className={cn("text-lg font-medium text-gray-900 dark:text-gray-100", className)} {...props} />
}

export function Text({ className, ...props }: HTMLAttributes<HTMLParagraphElement>) {
  return <p className={cn("text-sm text-gray-500 dark:text-gray-400", className)} {...props} />
}

export function Metric({ className, ...props }: HTMLAttributes<HTMLParagraphElement>) {
  return <p className={cn("text-3xl font-semibold text-gray-900 dark:text-gray-100", className)} {...props} />
}

const iconColors = {
  amber: "text-amber-500",
  emerald: "text-emerald-500",
  gray: "text-gray-500",
  green: "text-green-500",
  orange: "text-orange-500",
  purple: "text-purple-500",
  red: "text-red-500",
  rose: "text-rose-500",
  yellow: "text-yellow-500",
}

const badgeColors = {
  amber: "bg-amber-500/10 text-amber-600 ring-amber-500/20 dark:bg-amber-500/5 dark:text-amber-600 dark:ring-amber-500/60",
  emerald: "bg-emerald-500/10 text-emerald-600 ring-emerald-500/20 dark:bg-emerald-500/5 dark:text-emerald-600 dark:ring-emerald-500/60",
  gray: "bg-gray-500/10 text-gray-600 ring-gray-500/20 dark:bg-gray-500/5 dark:text-gray-600 dark:ring-gray-500/60",
  green: "bg-green-500/10 text-green-600 ring-green-500/20 dark:bg-green-500/5 dark:text-green-600 dark:ring-green-500/60",
  orange: "bg-orange-500/10 text-orange-600 ring-orange-500/20 dark:bg-orange-500/5 dark:text-orange-600 dark:ring-orange-500/60",
  purple: "bg-purple-500/10 text-purple-600 ring-purple-500/20 dark:bg-purple-500/5 dark:text-purple-600 dark:ring-purple-500/60",
  red: "bg-red-500/10 text-red-600 ring-red-500/20 dark:bg-red-500/5 dark:text-red-600 dark:ring-red-500/60",
  rose: "bg-rose-500/10 text-rose-600 ring-rose-500/20 dark:bg-rose-500/5 dark:text-rose-600 dark:ring-rose-500/60",
  yellow: "bg-yellow-500/10 text-yellow-600 ring-yellow-500/20 dark:bg-yellow-500/5 dark:text-yellow-600 dark:ring-yellow-500/60",
}

type ReportColor = keyof typeof iconColors
type ReportIcon = ComponentType<{ className?: string; "aria-hidden"?: boolean }>

export function Icon({ icon: IconComponent, color = "gray", size = "md", className }: {
  icon: ReportIcon
  color?: ReportColor
  size?: "sm" | "md"
  className?: string
}) {
  return (
    <span className={cn("inline-flex shrink-0 items-center justify-center", size === "sm" ? "p-1.5" : "p-2", iconColors[color], className)}>
      <IconComponent className="size-5 shrink-0" aria-hidden />
    </span>
  )
}

export function Badge({
  icon: IconComponent,
  color = "gray",
  className,
  children,
}: {
  icon?: ReportIcon
  color?: ReportColor
  size?: "xs"
  className?: string
  children: ReactNode
}) {
  return (
    <span className={cn("inline-flex w-max shrink-0 cursor-default items-center justify-center rounded-md px-2 py-0.5 text-xs ring-1 ring-inset", badgeColors[color], className)}>
      {IconComponent && <IconComponent className="-ml-1 mr-1.5 size-4 shrink-0" aria-hidden />}
      <span className="whitespace-nowrap">{children}</span>
    </span>
  )
}

const progressColors = {
  emerald: "bg-emerald-500",
  orange: "bg-orange-500",
  purple: "bg-purple-500",
  rose: "bg-rose-500",
}

const progressTrackColors = {
  emerald: "bg-emerald-500/20 dark:bg-emerald-500/20",
  orange: "bg-orange-500/20 dark:bg-orange-500/20",
  purple: "bg-purple-500/20 dark:bg-purple-500/20",
  rose: "bg-rose-500/20 dark:bg-rose-500/20",
}

export function ProgressBar({ value, color, className }: { value: number; color: keyof typeof progressColors; className?: string; showAnimation?: boolean }) {
  return (
    <div className={cn("h-2 overflow-hidden rounded-full", progressTrackColors[color], className)}>
      <div className={cn("h-full rounded-full transition-all duration-300 ease-in-out", progressColors[color])} style={{ width: `${Math.min(100, Math.max(0, value))}%` }} />
    </div>
  )
}

export function CategoryBar({ values, className }: { values: number[]; colors?: string[]; className?: string; showLabels?: boolean; showAnimation?: boolean }) {
  const total = values.reduce((sum, value) => sum + value, 0)
  const barColors = ["bg-emerald-500", "bg-rose-500", "bg-purple-500", "bg-orange-500"]
  return (
    <div className={cn("flex h-2 overflow-hidden rounded-full bg-gray-200 dark:bg-gray-700", className)}>
      {values.map((value, index) => (
        <span key={index} className={barColors[index]} style={{ width: total ? `${value / total * 100}%` : "0%" }} />
      ))}
    </div>
  )
}

export function Divider({ className }: { className?: string }) {
  return <hr className={cn("my-6 border-gray-200 dark:border-gray-700", className)} />
}

export const Table = ({ className, ...props }: HTMLAttributes<HTMLTableElement>) => <div className={cn("overflow-auto", className)}><table className="w-full text-left text-sm text-gray-500 dark:text-zinc-500" {...props} /></div>
export const TableHead = (props: HTMLAttributes<HTMLTableSectionElement>) => <thead {...props} />
export const TableBody = (props: HTMLAttributes<HTMLTableSectionElement>) => <tbody className="divide-y divide-gray-200 align-top dark:divide-zinc-800" {...props} />
export const TableRow = (props: HTMLAttributes<HTMLTableRowElement>) => <tr {...props} />
export const TableCell = ({ className, ...props }: HTMLAttributes<HTMLTableCellElement>) => <td className={cn("p-4 text-left align-middle", className)} {...props} />
export const TableHeaderCell = ({ className, ...props }: HTMLAttributes<HTMLTableCellElement>) => <th className={cn("whitespace-nowrap px-4 py-3.5 text-left font-semibold text-gray-900 dark:text-zinc-50", className)} {...props} />

export function TextInput({ icon: IconComponent, className, ...props }: InputHTMLAttributes<HTMLInputElement> & { icon?: ReportIcon }) {
  return (
    <label className={cn("relative block min-w-40", className)}>
      {IconComponent && <IconComponent className="pointer-events-none absolute left-3 top-2.5 size-4 text-gray-400" aria-hidden />}
      <input className={cn("h-[38px] w-full rounded-lg border border-gray-200 bg-white pr-3 text-sm text-gray-700 shadow-[0_1px_2px_0_rgb(0_0_0/0.05)] outline-none transition duration-100 placeholder:text-gray-500 hover:bg-gray-50 focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-200 dark:placeholder:text-zinc-500 dark:hover:bg-zinc-800", IconComponent ? "pl-10" : "pl-3")} {...props} />
    </label>
  )
}

type MultiSelectItemProps = { value: string; children: ReactNode }

export function MultiSelectItem(_props: MultiSelectItemProps) {
  return null
}

export function MultiSelect({ value, onValueChange, placeholder, className, children }: {
  value: string[]
  onValueChange: (value: string[]) => void
  placeholder: string
  className?: string
  children: ReactNode
}) {
  const [isOpen, setIsOpen] = useState(false)
  const [query, setQuery] = useState("")
  const rootRef = useRef<HTMLDivElement>(null)
  const items = Children.toArray(children).filter(Boolean) as ReactElement<MultiSelectItemProps>[]
  const visibleItems = items.filter(({ props }) => String(props.children).toLowerCase().includes(query.toLowerCase()))
  const toggle = (selected: string) => onValueChange(value.includes(selected) ? value.filter((item) => item !== selected) : [...value, selected])

  useEffect(() => {
    if (!isOpen) return
    const closeOnOutsideClick = (event: PointerEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) setIsOpen(false)
    }
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setIsOpen(false)
    }
    document.addEventListener("pointerdown", closeOnOutsideClick)
    document.addEventListener("keydown", closeOnEscape)
    return () => {
      document.removeEventListener("pointerdown", closeOnOutsideClick)
      document.removeEventListener("keydown", closeOnEscape)
    }
  }, [isOpen])

  return (
    <div ref={rootRef} className={cn("relative min-w-40 text-sm", className)}>
      <div className="flex h-[38px] items-center rounded-lg border border-gray-200 bg-white text-sm text-gray-500 shadow-[0_1px_2px_0_rgb(0_0_0/0.05)] transition duration-100 hover:bg-gray-50 dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-500 dark:hover:bg-zinc-800">
        <button type="button" onClick={() => setIsOpen((open) => !open)} aria-haspopup="listbox" aria-expanded={isOpen} className={cn("flex h-full min-w-0 flex-1 items-center gap-1 overflow-hidden text-left", value.length === 0 ? "px-3" : "pl-1.5 pr-3")}>
          {value.length === 0 ? <span>{placeholder}</span> : value.map((selected) => (
            <span key={selected} className="flex max-w-[100px] shrink-0 items-center rounded-md bg-gray-100 py-1 pl-2 pr-1.5 font-medium text-gray-700 lg:max-w-[200px] dark:bg-zinc-800 dark:text-zinc-200">
              <span className="truncate text-xs">{selected}</span>
              <X
                className="ml-2 size-3.5 shrink-0 rounded-full text-gray-400 hover:text-gray-500 dark:text-zinc-600 dark:hover:text-zinc-500"
                aria-hidden
                onClick={(event) => {
                  event.stopPropagation()
                  toggle(selected)
                }}
              />
            </span>
          ))}
        </button>
        {value.length > 0 && (
          <button type="button" onClick={() => onValueChange([])} aria-label={`Clear ${placeholder}`} className="mr-1 rounded p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200">
            <XCircleIcon className="size-4" aria-hidden />
          </button>
        )}
        <button type="button" onClick={() => setIsOpen((open) => !open)} aria-label={`Toggle ${placeholder}`} className="mr-2 text-gray-400">
          <ChevronDown className={cn("size-4 transition-transform", isOpen && "rotate-180")} aria-hidden />
        </button>
      </div>
      {isOpen && (
        <div role="listbox" aria-multiselectable="true" className="absolute z-40 mt-1 max-h-72 w-full overflow-auto rounded-lg border border-gray-200 bg-white shadow-md dark:border-zinc-800 dark:bg-zinc-900">
          <label className="relative block border-b border-gray-200 dark:border-zinc-800">
            <Search className="pointer-events-none absolute left-3 top-2.5 size-4 text-gray-400" aria-hidden />
            <input autoFocus value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search" className="h-[35px] w-full bg-transparent pl-9 pr-3 text-sm outline-none placeholder:text-gray-400" />
          </label>
          {visibleItems.map(({ props }) => (
            <label key={props.value} className="flex h-[41px] cursor-pointer items-center gap-2 border-b border-gray-200 px-3 text-sm text-gray-700 last:border-b-0 hover:bg-gray-50 dark:border-zinc-800 dark:text-zinc-300 dark:hover:bg-zinc-800">
              <input type="checkbox" checked={value.includes(props.value)} onChange={() => toggle(props.value)} className="size-3 accent-blue-500" />
              {props.children}
            </label>
          ))}
        </div>
      )}
    </div>
  )
}

export function Switch({ checked, onChange, color }: { checked: boolean; onChange: (checked: boolean) => void; color: "emerald" | "rose" }) {
  const fill = checked ? color === "emerald" ? "bg-emerald-500" : "bg-rose-500" : "bg-gray-200 dark:bg-zinc-800"
  return (
    <button type="button" role="switch" aria-checked={checked} onClick={() => onChange(!checked)} className="group relative inline-flex h-5 w-10 shrink-0 items-center justify-center rounded-full focus:outline-none">
      <span aria-hidden className={cn("pointer-events-none absolute mx-auto h-3 w-9 rounded-full transition-colors duration-100 ease-in-out", fill)} />
      <span aria-hidden className={cn("pointer-events-none absolute left-0 inline-block size-5 rounded-full border-2 border-white shadow-[0_1px_2px_0_rgb(0_0_0/0.05)] transition duration-100 ease-in-out group-focus-visible:ring-2 dark:border-zinc-900", fill, checked ? "translate-x-5" : "translate-x-0", color === "emerald" ? "ring-emerald-300" : "ring-rose-300")} />
    </button>
  )
}

const focusableSelector = 'a[href], button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])'

// Moves focus into a modal while it is open, keeps Tab inside it and returns focus afterwards,
// as the Radix and Headless UI dialogs did.
export function useModalFocus(open: boolean, containerRef: RefObject<HTMLElement | null>) {
  useEffect(() => {
    const container = containerRef.current
    if (!open || !container) return
    const previouslyFocused = document.activeElement instanceof HTMLElement ? document.activeElement : null
    container.focus()

    const keepFocusInside = (event: KeyboardEvent) => {
      if (event.key !== "Tab") return
      const focusable = [...container.querySelectorAll<HTMLElement>(focusableSelector)]
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      const active = document.activeElement
      if (!first || !last) {
        event.preventDefault()
      } else if (event.shiftKey && (active === first || active === container || !container.contains(active))) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && (active === last || !container.contains(active))) {
        event.preventDefault()
        first.focus()
      }
    }

    document.addEventListener("keydown", keepFocusInside)
    return () => {
      document.removeEventListener("keydown", keepFocusInside)
      previouslyFocused?.focus()
    }
  }, [open, containerRef])
}

export function Dialog({ open, onClose, children }: { open: boolean; onClose: () => void; static?: boolean; children: ReactNode }) {
  const containerRef = useRef<HTMLDivElement>(null)
  useModalFocus(open, containerRef)

  useEffect(() => {
    if (!open) return
    const handleKeyDown = (event: KeyboardEvent) => event.key === "Escape" && onClose()
    document.addEventListener("keydown", handleKeyDown)
    return () => document.removeEventListener("keydown", handleKeyDown)
  }, [open, onClose])

  if (!open) return null
  return (
    <div ref={containerRef} tabIndex={-1} className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4 outline-none" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      {children}
    </div>
  )
}

export function DialogPanel({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div role="dialog" aria-modal="true" className={cn("max-h-[90vh] w-full overflow-auto rounded-lg bg-white p-6 shadow-xl dark:bg-gray-900", className)} {...props} />
}

export function Button({ icon: IconComponent, iconPosition, tooltip, variant = "primary", size, className, children, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement> & {
  icon?: ReportIcon
  iconPosition?: "right"
  tooltip?: string
  variant?: "primary" | "secondary" | "light"
  size?: "xs"
  color?: string
}) {
  // Tremor's light variant is a borderless text button.
  const isLight = variant === "light"
  const iconClassName = isLight ? "-ml-1 mr-1.5 size-5 shrink-0" : "size-4"
  return (
    <button title={tooltip} className={cn(isLight ? "inline-flex shrink-0 items-center justify-center bg-transparent text-sm font-medium text-blue-500 outline-none hover:text-blue-700 dark:hover:text-blue-400" : "inline-flex items-center justify-center gap-2 rounded-md border px-3 py-2 text-sm font-medium transition-colors disabled:pointer-events-none disabled:opacity-40", variant === "primary" && "border-orange-500 bg-orange-500 text-white hover:bg-orange-600", variant === "secondary" && "border-gray-300 bg-white text-gray-900 hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100", size === "xs" && "p-1.5", className)} {...props}>
      {IconComponent && iconPosition !== "right" && <IconComponent className={iconClassName} aria-hidden />}
      {children}
      {IconComponent && iconPosition === "right" && <IconComponent className={iconClassName} aria-hidden />}
    </button>
  )
}
