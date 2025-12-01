"use client"

import { cx } from "@/lib/utils"
import { RiArrowRightSLine } from "@remixicon/react"
import { PanelLeft } from "lucide-react"
import Link from "next/link"
import { usePathname } from "next/navigation"
import { useSidebar } from "./Sidebar"
import { ThemeToggle } from "./ThemeToggle"

interface BreadcrumbItem {
  label: string
  href?: string
}

function getBreadcrumbs(pathname: string): BreadcrumbItem[] {
  const segments = pathname.split("/").filter(Boolean)
  const breadcrumbs: BreadcrumbItem[] = [{ label: "Home", href: "/" }]

  if (segments.length === 0) {
    return breadcrumbs
  }

  let currentPath = ""
  segments.forEach((segment, index) => {
    currentPath += `/${segment}`
    const label = segment.charAt(0).toUpperCase() + segment.slice(1)

    if (index === segments.length - 1) {
      breadcrumbs.push({ label })
    } else {
      breadcrumbs.push({ label, href: currentPath })
    }
  })

  return breadcrumbs
}

export function Breadcrumb() {
  const pathname = usePathname()
  const { isCollapsed, setIsCollapsed } = useSidebar()
  const breadcrumbs = getBreadcrumbs(pathname)

  return (
    <div className="flex h-16 items-center justify-between border-b border-gray-200 bg-white px-6 dark:border-gray-700 dark:bg-black">
      <div className="flex items-center gap-3">
        {/* Toggle sidebar button */}
        <button
          onClick={() => setIsCollapsed(!isCollapsed)}
          className={cx(
            "flex h-8 w-8 items-center justify-center rounded-md border border-gray-300 bg-white text-gray-500 shadow-xs transition-colors hover:bg-gray-50 hover:text-gray-700 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200"
          )}
          aria-label={isCollapsed ? "Expand sidebar" : "Collapse sidebar"}
        >
          <PanelLeft className="size-[18px] shrink-0 text-gray-700 dark:text-gray-300" aria-hidden />
        </button>

        {/* Divider */}
        <div className="h-5 w-px bg-gray-200 dark:bg-gray-600" />

        {/* Breadcrumbs */}
        <nav aria-label="Breadcrumb" className="flex items-center">
          <ol className="flex items-center gap-1">
            {breadcrumbs.map((item, index) => (
              <li key={index} className="flex items-center">
                {index > 0 && (
                  <RiArrowRightSLine className="mx-1 h-4 w-4 text-gray-400 dark:text-gray-500" />
                )}
                {item.href ? (
                  <Link
                    href={item.href}
                    className="text-sm tracking-tight text-gray-500 hover:text-gray-900 transition-colors dark:text-gray-400 dark:hover:text-gray-100"
                  >
                    {item.label}
                  </Link>
                ) : (
                  <span className="text-sm font-medium tracking-tight text-gray-900 dark:text-gray-100">
                    {item.label}
                  </span>
                )}
              </li>
            ))}
          </ol>
        </nav>
      </div>

      {/* Theme Toggle */}
      <ThemeToggle />
    </div>
  )
}

export default Breadcrumb
