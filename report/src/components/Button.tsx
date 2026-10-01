import { forwardRef, type ComponentPropsWithoutRef } from "react"

import { cn, focusRing } from "@/lib/utils"

interface ButtonProps extends ComponentPropsWithoutRef<"button"> {
  isLoading?: boolean
  loadingText?: string
  variant?: "primary" | "secondary" | "light" | "ghost" | "destructive"
  size?: "sm" | "md" | "lg"
}

const variantClasses = {
  primary: "border-transparent bg-orange-500 text-white hover:bg-orange-600 disabled:bg-orange-300",
  secondary: "border-gray-300 bg-white text-gray-900 hover:bg-gray-50 disabled:text-gray-400 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100",
  light: "border-transparent bg-gray-200 text-gray-900 shadow-none hover:bg-gray-300/70 disabled:bg-gray-100 disabled:text-gray-400",
  ghost: "border-transparent bg-transparent text-gray-900 shadow-none hover:bg-gray-100 disabled:text-gray-400",
  destructive: "border-transparent bg-red-600 text-white hover:bg-red-700 disabled:bg-red-300",
}

const sizeClasses = {
  sm: "h-8 px-2.5 text-xs",
  md: "h-9 px-3 text-sm",
  lg: "h-10 px-4 text-base",
}

const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ isLoading = false, loadingText, className, disabled, variant = "primary", size = "md", children, ...props }, ref) => (
    <button
      ref={ref}
      className={cn(
        "relative inline-flex items-center justify-center whitespace-nowrap rounded-sm border text-center font-medium transition-all duration-100 ease-in-out disabled:pointer-events-none",
        focusRing,
        variantClasses[variant],
        sizeClasses[size],
        className,
      )}
      disabled={disabled || isLoading}
      {...props}
    >
      {isLoading && <span className="mr-2 size-4 animate-spin rounded-full border-2 border-current border-t-transparent" aria-hidden />}
      {isLoading && loadingText ? loadingText : children}
    </button>
  ),
)

Button.displayName = "Button"

export { Button, type ButtonProps }
