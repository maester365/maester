"use client"

import { cx } from "@/lib/utils"
import { RiArrowRightSLine, RiMenuFoldLine, RiMenuUnfoldLine } from "@remixicon/react"
import Link from "next/link"
import { usePathname } from "next/navigation"
import { useSidebar } from "./Sidebar"

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
    <div className="flex items-center gap-3 border-b border-gray-200 bg-white px-6 py-3">
      {/* Toggle sidebar button */}
      <button
        onClick={() => setIsCollapsed(!isCollapsed)}
        className={cx(
          "flex h-8 w-8 items-center justify-center rounded-md border border-gray-300 bg-white text-gray-500 shadow-xs transition-colors hover:bg-gray-50 hover:text-gray-700"
        )}
        aria-label={isCollapsed ? "Expand sidebar" : "Collapse sidebar"}
      >
        {isCollapsed ? (
          <RiMenuUnfoldLine className="h-4 w-4" />
        ) : (
          <RiMenuFoldLine className="h-4 w-4" />
        )}
      </button>

      {/* Divider */}
      <div className="h-5 w-px bg-gray-200" />

      {/* Breadcrumbs */}
      <nav aria-label="Breadcrumb" className="flex items-center">
        <ol className="flex items-center gap-1">
          {breadcrumbs.map((item, index) => (
            <li key={index} className="flex items-center">
              {index > 0 && (
                <RiArrowRightSLine className="mx-1 h-4 w-4 text-gray-400" />
              )}
              {item.href ? (
                <Link
                  href={item.href}
                  className="text-sm text-gray-500 hover:text-gray-900 transition-colors"
                >
                  {item.label}
                </Link>
              ) : (
                <span className="text-sm font-medium text-gray-900">
                  {item.label}
                </span>
              )}
            </li>
          ))}
        </ol>
      </nav>
    </div>
  )
}

export default Breadcrumb
