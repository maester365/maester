import React, { createContext, useContext, useEffect, useLayoutEffect, useState } from "react"

type Theme = "light" | "dark" | "system"

interface ThemeContextType {
  theme: Theme
  setTheme: (theme: Theme) => void
  resolvedTheme: "light" | "dark"
}

const ThemeContext = createContext<ThemeContextType>({
  theme: "system",
  setTheme: () => {},
  resolvedTheme: "light",
})

export const useTheme = () => useContext(ThemeContext)

// Suppress CSS transitions while the theme class flips so colours switch instantly
// instead of fading element by element (same approach as next-themes' disableTransitionOnChange).
function disableTransitionsBriefly() {
  const style = document.createElement("style")
  style.appendChild(document.createTextNode("*,*::before,*::after{transition:none!important}"))
  document.head.appendChild(style)
  return () => {
    // Force a style recalc so the new colours are committed before transitions come back.
    window.getComputedStyle(document.body)
    window.setTimeout(() => {
      style.remove()
    }, 1)
  }
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<Theme>("system")
  const [resolvedTheme, setResolvedTheme] = useState<"light" | "dark">("light")

  useEffect(() => {
    // Get stored theme from localStorage
    const stored = localStorage.getItem("theme") as Theme | null
    if (stored) {
      setTheme(stored)
    }
  }, [])

  // Layout effect so the class flips before the next paint rather than a frame later.
  useLayoutEffect(() => {
    const root = document.documentElement

    const applyTheme = (newTheme: "light" | "dark") => {
      const restoreTransitions = disableTransitionsBriefly()
      root.classList.toggle("dark", newTheme === "dark")
      restoreTransitions()
      setResolvedTheme(newTheme)
    }

    if (theme === "system") {
      const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
      applyTheme(mediaQuery.matches ? "dark" : "light")

      const handler = (e: MediaQueryListEvent) => {
        applyTheme(e.matches ? "dark" : "light")
      }
      mediaQuery.addEventListener("change", handler)
      return () => mediaQuery.removeEventListener("change", handler)
    } else {
      applyTheme(theme)
    }
  }, [theme])

  const handleSetTheme = (newTheme: Theme) => {
    setTheme(newTheme)
    localStorage.setItem("theme", newTheme)
  }

  return (
    <ThemeContext.Provider value={{ theme, setTheme: handleSetTheme, resolvedTheme }}>
      {children}
    </ThemeContext.Provider>
  )
}
