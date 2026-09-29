import React from 'react'
import ReactDOM from 'react-dom/client'
import { HashRouter } from './lib/router'
import App from './App'
import './index.css'
import { loadReportData } from './lib/reportData'

loadReportData().then((testResults) => {
  ReactDOM.createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <HashRouter>
        <App testResults={testResults} />
      </HashRouter>
    </React.StrictMode>,
  )
})
