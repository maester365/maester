import React from "react"

interface LogoProps {
  className?: string
}

export function MaesterLogo({ className }: LogoProps) {
  return (
    <div className={className}>
      <svg
        viewBox="0 0 140 32"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        className="h-full w-auto"
      >
        {/* Shield Icon */}
        <g transform="translate(0, 0)">
          <path
            d="M16 2L2 8V16C2 22.5 8 27.5 16 29C24 27.5 30 22.5 30 16V8L16 2Z"
            fill="#F97316"
          />
          <path
            d="M16 5L5 10V16C5 21 9.5 25 16 26.5C22.5 25 27 21 27 16V10L16 5Z"
            fill="white"
          />
          <path
            d="M11 15L14.5 18.5L21 12"
            stroke="#F97316"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            fill="none"
          />
        </g>
        {/* Maester Text */}
        <text
          x="36"
          y="21"
          fontFamily="system-ui, -apple-system, sans-serif"
          fontSize="18"
          fontWeight="700"
          fill="#0f172a"
        >
          Maester
        </text>
      </svg>
    </div>
  )
}

export function MaesterMark({ className }: LogoProps) {
  return (
    <svg
      viewBox="0 0 32 32"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
    >
      <path
        d="M16 2L2 8V16C2 22.5 8 27.5 16 29C24 27.5 30 22.5 30 16V8L16 2Z"
        fill="#F97316"
      />
      <path
        d="M16 5L5 10V16C5 21 9.5 25 16 26.5C22.5 25 27 21 27 16V10L16 5Z"
        fill="white"
      />
      <path
        d="M11 15L14.5 18.5L21 12"
        stroke="#F97316"
        strokeWidth="2.5"
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
      />
    </svg>
  )
}
