import { cx } from "@/lib/utils"
import {
  House,
  Eye,
  FileText,
  Printer,
  Table,
  Monitor,
  CircleAlert,
  Settings,
  ArrowUpRight,
  ChevronsUpDown,
  ChevronUp,
  ChevronDown,
  FileJson,
  BookOpen,
  MessageCircle,
} from "lucide-react"
import { RiGithubFill } from "@remixicon/react"
import { Link, useLocation } from "react-router-dom"
import React, { useState, createContext, useContext, useRef, useEffect } from "react"
import maesterLogo from "@/assets/maester.png"

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
      to={href}
      className={cx(
        "group relative flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium tracking-tight transition-all duration-100",
        isActive
          ? "bg-orange-50 text-orange-600 dark:bg-orange-950 dark:text-orange-400"
          : "text-gray-700 hover:bg-gray-100 hover:text-gray-900 dark:text-gray-300 dark:hover:bg-gray-800 dark:hover:text-gray-100"
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
          "group relative flex w-full items-center justify-between gap-3 rounded-md px-3 py-2 text-sm font-medium tracking-tight transition-all duration-100",
          isActive
            ? "bg-orange-50 text-orange-600 dark:bg-orange-950 dark:text-orange-400"
            : "text-gray-700 hover:bg-gray-100 hover:text-gray-900 dark:text-gray-300 dark:hover:bg-gray-800 dark:hover:text-gray-100"
        )}
      >
        <div className="flex items-center gap-3">
          <Icon className={cx("size-[18px] shrink-0", isCollapsed && "mx-auto")} />
          {!isCollapsed && <span>{label}</span>}
        </div>
        {!isCollapsed && (
          isOpen ? (
            <ChevronUp className="h-4 w-4 text-gray-400 dark:text-gray-500" />
          ) : (
            <ChevronDown className="h-4 w-4 text-gray-400 dark:text-gray-500" />
          )
        )}
      </button>
      {isOpen && !isCollapsed && (
        <div className="relative ml-4 mt-1 space-y-0.5 pl-4">
          {/* Vertical connecting line - solid */}
          <div className="absolute left-0 top-0 bottom-2 w-px bg-gray-200 dark:bg-gray-700" />
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
      to={href}
      className={cx(
        "group relative flex items-center gap-3 rounded-md px-3 py-2 text-sm tracking-tight transition-all duration-100",
        isActive
          ? "bg-orange-50 text-orange-600 font-medium dark:bg-orange-950 dark:text-orange-400"
          : "text-gray-600 hover:bg-gray-100 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-800 dark:hover:text-gray-100"
      )}
    >
      <Icon className="size-[18px] shrink-0" />
      <span>{label}</span>
    </Link>
  )
}

interface TenantLogos {
  Banner?: string | null
}

interface SidebarProps {
  testResults?: {
    TenantName?: string
    TenantId?: string
    TenantLogos?: TenantLogos | null
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
  const location = useLocation()
  const pathname = location.pathname

  const isViewActive = pathname.startsWith("/view")
  const currentView = pathname.split("/").pop()

  const getTenantDisplay = () => {
    return (
      <Settings className="h-5 w-5 text-gray-500 dark:text-gray-400" />
    )
  }

  return (
    <div
      className={cx(
        "relative flex h-full flex-col border-r border-gray-200 bg-white transition-all duration-300 dark:border-gray-800 dark:bg-black",
        isCollapsed ? "w-16" : "w-64"
      )}
    >
      {/* Logo Header */}
      <div className={cx(
        "flex h-16 items-center gap-3 border-b border-gray-200 dark:border-gray-800",
        isCollapsed ? "justify-center px-2" : "px-4"
      )}>
        <Link to="/" aria-label="Home" className="flex items-center gap-3">
          <span className="sr-only">Maester Logo (go home)</span>
          <img
            src={maesterLogo}
            alt="Maester"
            width={32}
            height={32}
            className="h-8 w-8 shrink-0"
          />
          {!isCollapsed && (
            <div className="flex flex-col overflow-hidden">
              <span className="text-sm font-semibold tracking-tight text-gray-900 dark:text-gray-100">Maester</span>
              <span className="truncate text-xs tracking-tight text-gray-500 dark:text-gray-400">
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
          defaultOpen={true}
        >
          <SubNavItem
            href="/view/markdown"
            icon={FileText}
            label="Markdown"
            isActive={currentView === "markdown"}
          />
          <SubNavItem
            href="/view/excel"
            icon={Table}
            label="Excel"
            isActive={currentView === "excel"}
          />
          <SubNavItem
            href="/view/print"
            icon={Printer}
            label="Print"
            isActive={currentView === "print"}
          />
        </NavGroup>
      </nav>

      {/* Settings / Tenant info at bottom */}
      <div className="relative border-t border-gray-200 p-3 dark:border-gray-800">
        <SettingsMenu
          isCollapsed={isCollapsed}
          getTenantDisplay={getTenantDisplay}
          tenantName={testResults?.TenantName}
          tenantId={testResults?.TenantId}
          pathname={pathname}
        />
      </div>
    </div>
  )
}

interface SettingsMenuProps {
  isCollapsed: boolean
  getTenantDisplay: () => React.ReactNode
  tenantName?: string
  tenantId?: string
  pathname: string
}

function SettingsMenu({ isCollapsed, getTenantDisplay, tenantName, tenantId, pathname }: SettingsMenuProps) {
  const [isOpen, setIsOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setIsOpen(false)
      }
    }

    document.addEventListener("mousedown", handleClickOutside)
    return () => {
      document.removeEventListener("mousedown", handleClickOutside)
    }
  }, [])

  const menuItems = [
    {
      label: "Config",
      icon: FileJson,
      href: "/config",
      isActive: pathname === "/config",
    },
    {
      label: "System info",
      icon: Monitor,
      href: "/system",
      isActive: pathname === "/system",
    },
    { separator: true },
    {
      label: "Documentation",
      icon: BookOpen,
      href: "https://maester.dev/docs/intro",
      external: true,
    },
    {
      label: "GitHub",
      icon: RiGithubFill,
      href: "https://github.com/maester365/maester",
      external: true,
    },
    {
      label: "Issues",
      icon: CircleAlert,
      href: "https://github.com/maester365/maester/issues",
      external: true,
    },
    {
      label: "Join Discord",
      icon: MessageCircle,
      href: "https://discord.maester.dev/",
      external: true,
    },
  ]

  return (
    <div ref={menuRef} className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className={cx(
          "flex w-full items-center gap-3 rounded-md text-sm font-medium tracking-tight transition-all duration-100",
          isCollapsed ? "justify-center px-0 py-2" : "px-3 py-2",
          isOpen
            ? "bg-orange-50 text-orange-600 dark:bg-orange-950 dark:text-orange-400"
            : "text-gray-700 hover:bg-gray-100 hover:text-gray-900 dark:text-gray-300 dark:hover:bg-gray-800 dark:hover:text-gray-100"
        )}
      >
        <div className="shrink-0">
          {getTenantDisplay()}
        </div>
        {!isCollapsed && (
          <div className="flex flex-1 flex-col overflow-hidden text-left">
            <span className="truncate font-medium tracking-tight">Settings</span>
            <span className="truncate text-xs tracking-tight text-gray-500 dark:text-gray-400">
              {tenantName || tenantId || "Tenant"}
            </span>
          </div>
        )}
        {!isCollapsed && (
          <ChevronsUpDown className="h-4 w-4 text-gray-400 dark:text-gray-500" />
        )}
      </button>

      {/* Popup Menu */}
      {isOpen && (
        <div
          className={cx(
            "absolute z-50 rounded-md border border-gray-200 bg-white py-1 shadow-lg dark:border-gray-700 dark:bg-gray-900",
            isCollapsed ? "bottom-0 left-full ml-2 w-48" : "bottom-full left-0 mb-2 w-full"
          )}
        >
          {menuItems.map((item, index) =>
            item.separator ? (
              <div key={`separator-${index}`} className="my-1 border-t border-gray-200 dark:border-gray-700" />
            ) : item.external ? (
              <a
                key={item.label}
                href={item.href}
                target="_blank"
                rel="noopener noreferrer"
                onClick={() => setIsOpen(false)}
                className="flex items-center gap-3 px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800"
              >
                {item.icon && <item.icon className="h-4 w-4" />}
                <span className="flex-1">{item.label}</span>
                <ArrowUpRight className="h-3 w-3 text-gray-400 dark:text-gray-500" />
              </a>
            ) : (
              <Link
                key={item.label}
                to={item.href!}
                onClick={() => setIsOpen(false)}
                className={cx(
                  "flex items-center gap-3 px-3 py-2 text-sm",
                  item.isActive
                    ? "bg-orange-50 text-orange-600 dark:bg-orange-950 dark:text-orange-400"
                    : "text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800"
                )}
              >
                {item.icon && <item.icon className="h-4 w-4" />}
                <span>{item.label}</span>
              </Link>
            )
          )}
        </div>
      )}
    </div>
  )
}

export default Sidebar
