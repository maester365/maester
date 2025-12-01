"use client";
import React from "react";
import { Card, Text, Divider } from "@tremor/react";
import ThemeSwitch from "./ThemeSwitch";

export default function SettingsView({ testResults }) {
  const getTenantDisplay = () => {
    if (testResults?.TenantLogo) {
      return (
        <img
          src={testResults.TenantLogo}
          alt={testResults.TenantName || "Tenant"}
          className="h-16 w-16 rounded-full object-cover"
        />
      );
    }
    const name = testResults?.TenantName || testResults?.TenantId || "Unknown";
    const prefix = name.substring(0, 2).toUpperCase();
    return (
      <div className="flex h-16 w-16 items-center justify-center rounded-full bg-orange-500 text-xl font-medium text-white">
        {prefix}
      </div>
    );
  };

  return (
    <div className="max-w-2xl">
      <h1 className="text-3xl font-bold mb-6">Settings</h1>

      <Card className="mb-6">
        <h2 className="text-lg font-semibold mb-4">Tenant Information</h2>
        <div className="flex items-center gap-4 mb-4">
          {getTenantDisplay()}
          <div>
            <Text className="font-medium text-lg">
              {testResults?.TenantName || "Unknown Tenant"}
            </Text>
            <Text className="text-gray-500 dark:text-gray-400">
              {testResults?.TenantId}
            </Text>
          </div>
        </div>
        <Divider />
        <div className="space-y-2">
          <div className="flex justify-between">
            <Text className="text-gray-500">Account</Text>
            <Text>{testResults?.Account || "N/A"}</Text>
          </div>
          <div className="flex justify-between">
            <Text className="text-gray-500">Executed At</Text>
            <Text>
              {testResults?.ExecutedAt
                ? new Date(testResults.ExecutedAt).toLocaleString()
                : "N/A"}
            </Text>
          </div>
        </div>
      </Card>

      <Card className="mb-6">
        <h2 className="text-lg font-semibold mb-4">Appearance</h2>
        <div className="flex items-center justify-between">
          <div>
            <Text className="font-medium">Theme</Text>
            <Text className="text-gray-500 dark:text-gray-400">
              Switch between light and dark mode
            </Text>
          </div>
          <ThemeSwitch />
        </div>
      </Card>

      <Card>
        <h2 className="text-lg font-semibold mb-4">About</h2>
        <div className="space-y-2">
          <div className="flex justify-between">
            <Text className="text-gray-500">Maester Version</Text>
            <Text>{testResults?.CurrentVersion || "Unknown"}</Text>
          </div>
          <div className="flex justify-between">
            <Text className="text-gray-500">Latest Version</Text>
            <Text>{testResults?.LatestVersion || "Unknown"}</Text>
          </div>
          <Divider />
          <div>
            <a
              href="https://maester.dev"
              target="_blank"
              rel="noreferrer"
              className="text-orange-500 hover:text-orange-600 font-medium"
            >
              Visit Maester Documentation →
            </a>
          </div>
        </div>
      </Card>
    </div>
  );
}
