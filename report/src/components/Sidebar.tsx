"use client"

import { cx } from "@/lib/utils"
import {
  RiArrowDownSLine,
  RiArrowUpSLine,
} from "@remixicon/react"
import {
  House,
  Eye,
  FileText,
  Printer,
  Table,
} from "lucide-react"
import Link from "next/link"
import Image from "next/image"
import { usePathname } from "next/navigation"
import React, { useState, createContext, useContext } from "react"

interface SidebarContextType {
  isCollapsed: boolean
  setIsCollapsed: (collapsed: boolean) => void
}

const SidebarContext = createContext<SidebarContextType>({
  isCollapsed: false,
  setIsCollapsed: () => {},
})

export const useSidebar = () => useContext(SidebarContext)

interface NavItemProps {
  href: string
  icon: React.ElementType
  label: string
  isActive?: boolean
  isCollapsed?: boolean
}

function NavItem({
  href,
  icon: Icon,
  label,
  isActive,
  isCollapsed,
}: NavItemProps) {
  return (
    <Link
      href={href}
      className={cx(
        "group relative flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-all duration-100",
        isActive
          ? "bg-orange-50 text-orange-600"
          : "text-gray-700 hover:bg-gray-100 hover:text-gray-900"
      )}
    >
      <Icon className={cx("size-[18px] shrink-0", isCollapsed && "mx-auto")} />
      {!isCollapsed && <span>{label}</span>}
    </Link>
  )
}

interface NavGroupProps {
  icon: React.ElementType
  label: string
  isActive?: boolean
  isCollapsed?: boolean
  children: React.ReactNode
  defaultOpen?: boolean
}

function NavGroup({
  icon: Icon,
  label,
  isActive,
  isCollapsed,
  children,
  defaultOpen = false,
}: NavGroupProps) {
  const [isOpen, setIsOpen] = useState(defaultOpen || isActive)

  return (
    <div>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className={cx(
          "group relative flex w-full items-center justify-between gap-3 rounded-md px-3 py-2 text-sm font-medium transition-all duration-100",
          isActive
            ? "bg-orange-50 text-orange-600"
            : "text-gray-700 hover:bg-gray-100 hover:text-gray-900"
        )}
      >
        <div className="flex items-center gap-3">
          <Icon className={cx("size-[18px] shrink-0", isCollapsed && "mx-auto")} />
          {!isCollapsed && <span>{label}</span>}
        </div>
        {!isCollapsed && (
          isOpen ? (
            <RiArrowUpSLine className="h-4 w-4 text-gray-400" />
          ) : (
            <RiArrowDownSLine className="h-4 w-4 text-gray-400" />
          )
        )}
      </button>
      {isOpen && !isCollapsed && (
        <div className="relative ml-4 mt-1 space-y-1 pl-4">
          {/* Vertical connecting line - dashed */}
          <div className="absolute left-0 top-0 bottom-2 w-px">
            <svg className="h-full w-full" preserveAspectRatio="none">
              <line
                x1="0.5"
                y1="0"
                x2="0.5"
                y2="100%"
                className="stroke-gray-300"
                strokeWidth="1"
                strokeDasharray="3 3"
              />
            </svg>
          </div>
          {children}
        </div>
      )}
    </div>
  )
}

interface SubNavItemProps {
  href: string
  icon: React.ElementType
  label: string
  isActive?: boolean
}

function SubNavItem({ href, icon: Icon, label, isActive }: SubNavItemProps) {
  return (
    <Link
      href={href}
      className={cx(
        "group relative flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-all duration-100",
        isActive
          ? "bg-orange-50 text-orange-600 font-medium"
          : "text-gray-600 hover:bg-gray-100 hover:text-gray-900"
      )}
    >
      {/* Horizontal connecting line - dashed */}
      <div className="absolute -left-4 top-1/2 w-4 h-px">
        <svg className="h-full w-full" preserveAspectRatio="none">
          <line
            x1="0"
            y1="0.5"
            x2="100%"
            y2="0.5"
            className="stroke-gray-300"
            strokeWidth="1"
            strokeDasharray="3 3"
          />
        </svg>
      </div>
      <Icon className="size-[18px] shrink-0" />
      <span>{label}</span>
    </Link>
  )
}

interface SidebarProps {
  testResults?: {
    TenantName?: string
    TenantId?: string
    TenantLogo?: string
  }
}

export function SidebarProvider({ children }: { children: React.ReactNode }) {
  const [isCollapsed, setIsCollapsed] = useState(false)

  return (
    <SidebarContext.Provider value={{ isCollapsed, setIsCollapsed }}>
      {children}
    </SidebarContext.Provider>
  )
}

export function Sidebar({ testResults }: SidebarProps) {
  const { isCollapsed } = useSidebar()
  const pathname = usePathname()

  const isViewActive = pathname.startsWith("/view")
  const currentView = pathname.split("/").pop()

  const getTenantDisplay = () => {
    if (testResults?.TenantLogo) {
      return (
        <img
          src={testResults.TenantLogo}
          alt={testResults.TenantName || "Tenant"}
          className="h-8 w-8 rounded-full object-cover"
        />
      )
    }
    const name = testResults?.TenantName || testResults?.TenantId || "Te"
    const prefix = name.substring(0, 2).toUpperCase()
    return (
      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-orange-500 to-orange-600 text-xs font-semibold text-white">
        {prefix}
      </div>
    )
  }

  return (
    <div
      className={cx(
        "relative flex h-full flex-col border-r border-gray-200 bg-white transition-all duration-300",
        isCollapsed ? "w-16" : "w-64"
      )}
    >
      {/* Logo Header */}
      <div className={cx(
        "flex h-16 items-center gap-3 border-b border-gray-200",
        isCollapsed ? "justify-center px-2" : "px-4"
      )}>
        <Link href="/" aria-label="Home" className="flex items-center gap-3">
          <span className="sr-only">Maester Logo (go home)</span>
          <Image
            src="/assets/maester.png"
            alt="Maester"
            width={32}
            height={32}
            className="h-8 w-8 shrink-0"
          />
          {!isCollapsed && (
            <div className="flex flex-col overflow-hidden">
              <span className="text-sm font-semibold text-gray-900">Maester</span>
              <span className="truncate text-xs text-gray-500">
                {testResults?.TenantName || testResults?.TenantId || "Tenant"}
              </span>
            </div>
          )}
        </Link>
      </div>

      {/* Navigation */}
      <nav className="flex-1 space-y-1 overflow-y-auto p-3">
        <NavItem
          href="/"
          icon={House}
          label="Home"
          isActive={pathname === "/"}
          isCollapsed={isCollapsed}
        />

        <NavGroup
          icon={Eye}
          label="View"
          isActive={isViewActive}
          isCollapsed={isCollapsed}
          defaultOpen={isViewActive}
        >
          <SubNavItem
            href="/view/markdown"
            icon={FileText}
            label="Markdown"
            isActive={currentView === "markdown"}
          />
          <SubNavItem
            href="/view/print"
            icon={Printer}
            label="Print"
            isActive={currentView === "print"}
          />
          <SubNavItem
            href="/view/excel"
            icon={Table}
            label="Excel"
            isActive={currentView === "excel"}
          />
        </NavGroup>
      </nav>

      {/* Settings / Tenant info at bottom */}
      <div className="border-t border-gray-200 p-3">
        <Link
          href="/settings"
          className={cx(
            "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-all duration-100",
            pathname === "/settings"
              ? "bg-orange-50 text-orange-600"
              : "text-gray-700 hover:bg-gray-100 hover:text-gray-900"
          )}
        >
          {getTenantDisplay()}
          {!isCollapsed && (
            <div className="flex flex-col overflow-hidden">
              <span className="truncate font-medium">Settings</span>
              <span className="truncate text-xs text-gray-500">
                {testResults?.TenantName || testResults?.TenantId || "Tenant"}
              </span>
            </div>
          )}
        </Link>
      </div>
    </div>
  )
}

export default Sidebar
