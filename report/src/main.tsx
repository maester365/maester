import React from 'react'
import ReactDOM from 'react-dom/client'
import { HashRouter } from './lib/router'
import App from './App'
import './index.css'
import { loadReportData } from './lib/reportData'

const root = document.getElementById('root')!

loadReportData().then(
  (testResults) => {
    ReactDOM.createRoot(root).render(
      <React.StrictMode>
        <HashRouter>
          <App testResults={testResults} />
        </HashRouter>
      </React.StrictMode>,
    )
  },
  (error: unknown) => {
    console.error(error)
    root.textContent = 'The report data could not be loaded. Try generating the report again.'
  },
)
