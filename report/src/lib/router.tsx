import {
  createContext,
  type MouseEvent,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react"

type ReportLocation = { pathname: string; hash: string }
type Destination = string | { pathname: string; hash?: string }
type NavigateOptions = { replace?: boolean }

interface RouterContextValue {
  location: ReportLocation
  navigate: (destination: Destination, options?: NavigateOptions) => void
}

const RouterContext = createContext<RouterContextValue | null>(null)

function readLocation(): ReportLocation {
  const route = window.location.hash.slice(1) || "/"
  const anchorIndex = route.indexOf("#")
  const pathname = anchorIndex === -1 ? route : route.slice(0, anchorIndex)
  const hash = anchorIndex === -1 ? "" : route.slice(anchorIndex)
  return { pathname: pathname.startsWith("/") ? pathname : `/${pathname}`, hash }
}

export function HashRouter({ children }: { children: ReactNode }) {
  const [location, setLocation] = useState(readLocation)

  useEffect(() => {
    const handleHashChange = () => setLocation(readLocation())
    window.addEventListener("hashchange", handleHashChange)
    return () => window.removeEventListener("hashchange", handleHashChange)
  }, [])

  const navigate = useCallback((destination: Destination, options?: NavigateOptions) => {
    const next = typeof destination === "string" ? destination : `${destination.pathname}${destination.hash || ""}`
    const normalized = next.startsWith("/") ? next : `/${next}`

    if (options?.replace) {
      window.history.replaceState(null, "", `${window.location.pathname}${window.location.search}#${normalized}`)
      setLocation(readLocation())
    } else {
      window.location.hash = normalized
    }
  }, [])

  const value = useMemo(() => ({ location, navigate }), [location, navigate])
  return <RouterContext.Provider value={value}>{children}</RouterContext.Provider>
}

function useRouter() {
  const context = useContext(RouterContext)
  if (!context) throw new Error("Router hooks must be used within HashRouter")
  return context
}

export function useLocation() {
  return useRouter().location
}

export function useNavigate() {
  return useRouter().navigate
}

export function Link({ to, onClick, children, ...props }: Omit<React.AnchorHTMLAttributes<HTMLAnchorElement>, "href"> & { to: string }) {
  const navigate = useNavigate()
  const handleClick = (event: MouseEvent<HTMLAnchorElement>) => {
    onClick?.(event)
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    navigate(to)
  }

  return <a href={`#${to}`} onClick={handleClick} {...props}>{children}</a>
}
