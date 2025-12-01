"use client";
import React from "react";
import Sidebar from "./Sidebar";
import { cx } from "../lib/utils";

export function Layout({ children, currentView, onNavigate, testResults }) {
  return (
    <div className="flex h-screen bg-gray-50 dark:bg-gray-900">
      {/* Sidebar */}
      <Sidebar
        currentView={currentView}
        onNavigate={onNavigate}
        testResults={testResults}
      />

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        <div className="p-6">{children}</div>
      </main>
    </div>
  );
}

export default Layout;
