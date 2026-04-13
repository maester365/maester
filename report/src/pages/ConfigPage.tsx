import { useState, useMemo } from "react"
import { Card } from "@tremor/react"
import { Download, FileJson, Settings2, AlertTriangle, AlertCircle, Info, CircleAlert, ShieldAlert, ChevronDown, Check, Plus, Trash2, User, Users, Mail, Hash } from "lucide-react"
import { Listbox, ListboxButton, ListboxOption, ListboxOptions } from "@headlessui/react"
import { useSidebar } from "@/components/Sidebar"

interface EmergencyAccessAccount {
  Type: "User" | "Group"
  Id?: string
  UserPrincipalName?: string
}

interface TestSetting {
  Id: string
  Severity: string
  Title: string
}

interface GlobalSettings {
  EmergencyAccessAccounts?: EmergencyAccessAccount[]
  [key: string]: unknown
}

interface MaesterConfig {
  GlobalSettings?: GlobalSettings
  TestSettings?: TestSetting[]
}

interface ConfigPageProps {
  testResults?: {
    MaesterConfig?: MaesterConfig
  }
}

interface SeverityOption {
  value: string
  label: string
  icon: React.ElementType
  bgColor: string
  textColor: string
  iconColor: string
}

const SEVERITY_OPTIONS: SeverityOption[] = [
  {
    value: "Critical",
    label: "Critical",
    icon: ShieldAlert,
    bgColor: "bg-purple-100 dark:bg-purple-900/50",
    textColor: "text-purple-800 dark:text-purple-200",
    iconColor: "text-purple-600 dark:text-purple-400"
  },
  {
    value: "High",
    label: "High",
    icon: AlertCircle,
    bgColor: "bg-red-100 dark:bg-red-900/50",
    textColor: "text-red-800 dark:text-red-200",
    iconColor: "text-red-600 dark:text-red-400"
  },
  {
    value: "Medium",
    label: "Medium",
    icon: AlertTriangle,
    bgColor: "bg-orange-100 dark:bg-orange-900/50",
    textColor: "text-orange-800 dark:text-orange-200",
    iconColor: "text-orange-600 dark:text-orange-400"
  },
  {
    value: "Low",
    label: "Low",
    icon: CircleAlert,
    bgColor: "bg-yellow-100 dark:bg-yellow-900/50",
    textColor: "text-yellow-800 dark:text-yellow-200",
    iconColor: "text-yellow-600 dark:text-yellow-400"
  },
  {
    value: "Info",
    label: "Info",
    icon: Info,
    bgColor: "bg-blue-100 dark:bg-blue-900/50",
    textColor: "text-blue-800 dark:text-blue-200",
    iconColor: "text-blue-600 dark:text-blue-400"
  },
]

const getSeverityOption = (value: string): SeverityOption => {
  return SEVERITY_OPTIONS.find(opt => opt.value === value) || SEVERITY_OPTIONS[2] // Default to Medium
}

const ACCOUNT_TYPE_OPTIONS = [
  { value: "User" as const, label: "User", icon: User },
  { value: "Group" as const, label: "Group", icon: Users },
]

const IDENTIFIER_TYPE_OPTIONS = [
  { value: "upn" as const, label: "UPN / Email", icon: Mail, placeholder: "BreakGlass@contoso.com" },
  { value: "id" as const, label: "Object ID", icon: Hash, placeholder: "00000000-0000-0000-0000-000000000000" },
]

type IdentifierType = "upn" | "id"

// Helper to determine initial identifier type based on existing data
const getInitialIdentifierType = (account: EmergencyAccessAccount): IdentifierType => {
  // If has Id but no UPN, use id
  if (account.Id && !account.UserPrincipalName) return "id"
  // Default to upn (including when both are present or neither)
  return "upn"
}

export default function ConfigPage({ testResults }: ConfigPageProps) {
  const { isCollapsed } = useSidebar()
  const originalConfig = testResults?.MaesterConfig

  // State for edited emergency access accounts
  const [editedEmergencyAccounts, setEditedEmergencyAccounts] = useState<EmergencyAccessAccount[]>(
    () => originalConfig?.GlobalSettings?.EmergencyAccessAccounts
      ? [...originalConfig.GlobalSettings.EmergencyAccessAccounts.map(a => ({ ...a }))]
      : []
  )

  // State for tracking which identifier type is selected for each account
  const [identifierTypes, setIdentifierTypes] = useState<IdentifierType[]>(
    () => originalConfig?.GlobalSettings?.EmergencyAccessAccounts
      ? originalConfig.GlobalSettings.EmergencyAccessAccounts.map(a => getInitialIdentifierType(a))
      : []
  )

  // State for edited test settings
  const [editedTestSettings, setEditedTestSettings] = useState<TestSetting[]>(
    () => originalConfig?.TestSettings ? [...originalConfig.TestSettings.map(t => ({ ...t }))] : []
  )

  // Check if any changes have been made
  const hasChanges = useMemo(() => {
    // Check emergency access accounts changes
    const originalAccounts = originalConfig?.GlobalSettings?.EmergencyAccessAccounts || []
    const accountsChanged = editedEmergencyAccounts.length !== originalAccounts.length ||
      editedEmergencyAccounts.some((account, index) => {
        const original = originalAccounts[index]
        if (!original) return true
        return account.Type !== original.Type ||
               account.Id !== original.Id ||
               account.UserPrincipalName !== original.UserPrincipalName
      })

    // Check test settings changes
    const testSettingsChanged = originalConfig?.TestSettings && editedTestSettings.some((setting, index) => {
      const original = originalConfig.TestSettings?.[index]
      if (!original) return true
      return setting.Severity !== original.Severity || setting.Title !== original.Title
    })

    return accountsChanged || testSettingsChanged
  }, [editedEmergencyAccounts, editedTestSettings, originalConfig])

  // Emergency Access Account handlers
  const handleAddEmergencyAccount = () => {
    setEditedEmergencyAccounts(prev => [...prev, { Type: "User", UserPrincipalName: "" }])
    setIdentifierTypes(prev => [...prev, "upn"]) // Default to UPN
  }

  const handleRemoveEmergencyAccount = (index: number) => {
    setEditedEmergencyAccounts(prev => prev.filter((_, i) => i !== index))
    setIdentifierTypes(prev => prev.filter((_, i) => i !== index))
  }

  const handleEmergencyAccountTypeChange = (index: number, newType: "User" | "Group") => {
    setEditedEmergencyAccounts(prev =>
      prev.map((account, i) =>
        i === index ? { ...account, Type: newType } : account
      )
    )
  }

  const handleIdentifierTypeChange = (index: number, newIdentifierType: IdentifierType) => {
    setIdentifierTypes(prev =>
      prev.map((type, i) => i === index ? newIdentifierType : type)
    )
    // Clear the other field when switching
    setEditedEmergencyAccounts(prev =>
      prev.map((account, i) => {
        if (i !== index) return account
        if (newIdentifierType === "upn") {
          return { ...account, Id: undefined }
        } else {
          return { ...account, UserPrincipalName: undefined }
        }
      })
    )
  }

  const handleIdentifierValueChange = (index: number, value: string) => {
    const identifierType = identifierTypes[index]
    setEditedEmergencyAccounts(prev =>
      prev.map((account, i) => {
        if (i !== index) return account
        if (identifierType === "upn") {
          return { ...account, UserPrincipalName: value || undefined }
        } else {
          return { ...account, Id: value || undefined }
        }
      })
    )
  }

  const handleSeverityChange = (id: string, newSeverity: string) => {
    setEditedTestSettings(prev =>
      prev.map(setting =>
        setting.Id === id ? { ...setting, Severity: newSeverity } : setting
      )
    )
  }

  const handleTitleChange = (id: string, newTitle: string) => {
    setEditedTestSettings(prev =>
      prev.map(setting =>
        setting.Id === id ? { ...setting, Title: newTitle } : setting
      )
    )
  }

  const handleExport = () => {
    // Clean up emergency accounts - remove empty entries and undefined fields
    const cleanedAccounts = editedEmergencyAccounts
      .filter(account => account.Id || account.UserPrincipalName) // Remove entries without any identifier
      .map(account => {
        const cleaned: EmergencyAccessAccount = { Type: account.Type }
        if (account.Id) cleaned.Id = account.Id
        if (account.UserPrincipalName) cleaned.UserPrincipalName = account.UserPrincipalName
        return cleaned
      })

    const exportConfig = {
      GlobalSettings: {
        ...originalConfig?.GlobalSettings,
        EmergencyAccessAccounts: cleanedAccounts
      },
      TestSettings: editedTestSettings
    }

    const blob = new Blob([JSON.stringify(exportConfig, null, 2)], { type: "application/json" })
    const url = URL.createObjectURL(blob)
    const a = document.createElement("a")
    a.href = url
    a.download = "maester-config.json"
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  const handleReset = () => {
    setEditedEmergencyAccounts(
      originalConfig?.GlobalSettings?.EmergencyAccessAccounts
        ? [...originalConfig.GlobalSettings.EmergencyAccessAccounts.map(a => ({ ...a }))]
        : []
    )
    setIdentifierTypes(
      originalConfig?.GlobalSettings?.EmergencyAccessAccounts
        ? originalConfig.GlobalSettings.EmergencyAccessAccounts.map(a => getInitialIdentifierType(a))
        : []
    )
    setEditedTestSettings(
      originalConfig?.TestSettings
        ? [...originalConfig.TestSettings.map(t => ({ ...t }))]
        : []
    )
  }

  if (!originalConfig) {
    return (
      <div className="p-6">
        <div className="flex items-center gap-3 mb-6">
          <FileJson className="h-8 w-8 text-orange-500" />
          <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Maester Configuration</h1>
        </div>
        <Card className="p-6">
          <p className="text-gray-500 dark:text-gray-400">No Maester configuration available. Make sure maester-config.json exists in your tests folder.</p>
        </Card>
      </div>
    )
  }

  return (
    <div className="p-6 pb-24">
      <div className="flex items-center gap-3 mb-6">
        <FileJson className="h-8 w-8 text-orange-500" />
        <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Maester Configuration</h1>
      </div>

      {/* Emergency Access Accounts Section */}
      <section className="mb-8">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100 flex items-center gap-2">
            <Settings2 className="h-5 w-5" />
            Emergency Access Accounts
          </h2>
          <button
            onClick={handleAddEmergencyAccount}
            className="flex items-center gap-2 px-3 py-1.5 text-sm bg-orange-500 hover:bg-orange-600 text-white font-medium rounded-md transition-colors"
          >
            <Plus className="h-4 w-4" />
            Add Account
          </button>
        </div>
        <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">
          Configure emergency access (break glass) accounts that should be excluded from all Conditional Access policies.
        </p>

        {editedEmergencyAccounts.length > 0 ? (
          <div className="space-y-3">
            {editedEmergencyAccounts.map((account, index) => (
              <Card key={index} className="p-4">
                <div className="flex items-start gap-4">
                  {/* Type Selector */}
                  <div className="flex flex-col gap-1 min-w-[140px]">
                    <label className="text-xs font-medium text-gray-500 dark:text-gray-400">Type</label>
                    <Listbox value={account.Type} onChange={(value) => handleEmergencyAccountTypeChange(index, value)}>
                      <div className="relative">
                        <ListboxButton className="relative w-full cursor-pointer rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 py-2 pl-3 pr-10 text-left text-sm focus:outline-none focus:ring-2 focus:ring-orange-500">
                          <span className="flex items-center gap-2">
                            {account.Type === "User" ? (
                              <User className="h-4 w-4 text-blue-500" />
                            ) : (
                              <Users className="h-4 w-4 text-green-500" />
                            )}
                            <span className="block truncate text-gray-900 dark:text-gray-100">{account.Type}</span>
                          </span>
                          <span className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2">
                            <ChevronDown className="h-4 w-4 text-gray-400" aria-hidden="true" />
                          </span>
                        </ListboxButton>
                        <ListboxOptions className="absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md bg-white dark:bg-gray-800 py-1 text-sm shadow-lg ring-1 ring-black/5 dark:ring-white/10 focus:outline-none">
                          {ACCOUNT_TYPE_OPTIONS.map((option) => {
                            const Icon = option.icon
                            return (
                              <ListboxOption
                                key={option.value}
                                value={option.value}
                                className={({ focus, selected }) =>
                                  `relative cursor-pointer select-none py-2 pl-3 pr-9 ${
                                    focus ? 'bg-gray-100 dark:bg-gray-700' : ''
                                  } ${selected ? 'font-semibold' : ''}`
                                }
                              >
                                {({ selected }) => (
                                  <>
                                    <span className="flex items-center gap-2">
                                      <Icon className={`h-4 w-4 ${option.value === "User" ? "text-blue-500" : "text-green-500"}`} />
                                      <span className="block truncate text-gray-900 dark:text-gray-100">{option.label}</span>
                                    </span>
                                    {selected && (
                                      <span className="absolute inset-y-0 right-0 flex items-center pr-3">
                                        <Check className="h-4 w-4 text-orange-500" aria-hidden="true" />
                                      </span>
                                    )}
                                  </>
                                )}
                              </ListboxOption>
                            )
                          })}
                        </ListboxOptions>
                      </div>
                    </Listbox>
                  </div>

                  {/* Identifier Type Selector */}
                  <div className="flex flex-col gap-1 min-w-[160px]">
                    <label className="text-xs font-medium text-gray-500 dark:text-gray-400">Identifier</label>
                    <Listbox value={identifierTypes[index] || "upn"} onChange={(value) => handleIdentifierTypeChange(index, value)}>
                      <div className="relative">
                        <ListboxButton className="relative w-full cursor-pointer rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 py-2 pl-3 pr-10 text-left text-sm focus:outline-none focus:ring-2 focus:ring-orange-500">
                          <span className="flex items-center gap-2">
                            {(() => {
                              const opt = IDENTIFIER_TYPE_OPTIONS.find(o => o.value === (identifierTypes[index] || "upn"))!
                              const Icon = opt.icon
                              return <Icon className="h-4 w-4 text-gray-500" />
                            })()}
                            <span className="block truncate text-gray-900 dark:text-gray-100">
                              {IDENTIFIER_TYPE_OPTIONS.find(o => o.value === (identifierTypes[index] || "upn"))?.label}
                            </span>
                          </span>
                          <span className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2">
                            <ChevronDown className="h-4 w-4 text-gray-400" aria-hidden="true" />
                          </span>
                        </ListboxButton>
                        <ListboxOptions className="absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md bg-white dark:bg-gray-800 py-1 text-sm shadow-lg ring-1 ring-black/5 dark:ring-white/10 focus:outline-none">
                          {IDENTIFIER_TYPE_OPTIONS.map((option) => {
                            const Icon = option.icon
                            return (
                              <ListboxOption
                                key={option.value}
                                value={option.value}
                                className={({ focus, selected }) =>
                                  `relative cursor-pointer select-none py-2 pl-3 pr-9 ${
                                    focus ? 'bg-gray-100 dark:bg-gray-700' : ''
                                  } ${selected ? 'font-semibold' : ''}`
                                }
                              >
                                {({ selected }) => (
                                  <>
                                    <span className="flex items-center gap-2">
                                      <Icon className="h-4 w-4 text-gray-500" />
                                      <span className="block truncate text-gray-900 dark:text-gray-100">{option.label}</span>
                                    </span>
                                    {selected && (
                                      <span className="absolute inset-y-0 right-0 flex items-center pr-3">
                                        <Check className="h-4 w-4 text-orange-500" aria-hidden="true" />
                                      </span>
                                    )}
                                  </>
                                )}
                              </ListboxOption>
                            )
                          })}
                        </ListboxOptions>
                      </div>
                    </Listbox>
                  </div>

                  {/* Identifier Value Field */}
                  <div className="flex flex-col gap-1 flex-1">
                    <label className="text-xs font-medium text-gray-500 dark:text-gray-400">
                      {IDENTIFIER_TYPE_OPTIONS.find(o => o.value === (identifierTypes[index] || "upn"))?.label}
                    </label>
                    <input
                      type="text"
                      value={(identifierTypes[index] || "upn") === "upn" ? (account.UserPrincipalName || "") : (account.Id || "")}
                      onChange={(e) => handleIdentifierValueChange(index, e.target.value)}
                      placeholder={IDENTIFIER_TYPE_OPTIONS.find(o => o.value === (identifierTypes[index] || "upn"))?.placeholder}
                      className={`w-full px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 placeholder-gray-400 dark:placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent ${(identifierTypes[index] || "upn") === "id" ? "font-mono" : ""}`}
                    />
                  </div>

                  {/* Remove Button */}
                  <div className="flex flex-col gap-1">
                    <label className="text-xs font-medium text-transparent">Remove</label>
                    <button
                      onClick={() => handleRemoveEmergencyAccount(index)}
                      className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-md transition-colors"
                      title="Remove account"
                    >
                      <Trash2 className="h-5 w-5" />
                    </button>
                  </div>
                </div>
                {!account.Id && !account.UserPrincipalName && (
                  <p className="mt-2 text-xs text-amber-600 dark:text-amber-400">
                    ⚠ Please enter a value
                  </p>
                )}
              </Card>
            ))}
          </div>
        ) : (
          <Card className="p-6 text-center">
            <Users className="h-12 w-12 text-gray-300 dark:text-gray-600 mx-auto mb-3" />
            <p className="text-gray-500 dark:text-gray-400 mb-3">No emergency access accounts configured</p>
            <button
              onClick={handleAddEmergencyAccount}
              className="inline-flex items-center gap-2 px-4 py-2 text-sm bg-orange-500 hover:bg-orange-600 text-white font-medium rounded-md transition-colors"
            >
              <Plus className="h-4 w-4" />
              Add Your First Account
            </button>
          </Card>
        )}
      </section>

      {/* Test Settings Section */}
      <section>
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-4 flex items-center gap-2">
          <FileJson className="h-5 w-5" />
          Test Settings
        </h2>

        {editedTestSettings.length > 0 ? (
          <div className="grid gap-4">
            {editedTestSettings.map((setting) => (
              <Card key={setting.Id} className="p-4">
                <div className="flex flex-col gap-3">
                  {/* ID - Read only */}
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-sm font-semibold text-orange-600 dark:text-orange-400">
                      {setting.Id}
                    </span>
                  </div>

                  {/* Title - Editable */}
                  <div className="flex flex-col gap-1">
                    <label htmlFor={`title-${setting.Id}`} className="text-xs font-medium text-gray-500 dark:text-gray-400">Title</label>
                    <input
                      id={`title-${setting.Id}`}
                      type="text"
                      value={setting.Title}
                      onChange={(e) => handleTitleChange(setting.Id, e.target.value)}
                      placeholder="Enter test title"
                      className="w-full px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                    />
                  </div>

                  {/* Severity - Dropdown */}
                  <div className="flex flex-col gap-1">
                    <label className="text-xs font-medium text-gray-500 dark:text-gray-400">Severity</label>
                    <Listbox value={setting.Severity} onChange={(value) => handleSeverityChange(setting.Id, value)}>
                      <div className="relative">
                        <ListboxButton className={`relative w-fit min-w-[140px] cursor-pointer rounded-md py-2 pl-3 pr-10 text-left text-sm font-medium shadow-sm focus:outline-none focus:ring-2 focus:ring-orange-500 ${getSeverityOption(setting.Severity).bgColor} ${getSeverityOption(setting.Severity).textColor}`}>
                          <span className="flex items-center gap-2">
                            {(() => {
                              const opt = getSeverityOption(setting.Severity)
                              const Icon = opt.icon
                              return <Icon className={`h-4 w-4 ${opt.iconColor}`} />
                            })()}
                            <span className="block truncate">{setting.Severity}</span>
                          </span>
                          <span className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2">
                            <ChevronDown className={`h-4 w-4 ${getSeverityOption(setting.Severity).iconColor}`} aria-hidden="true" />
                          </span>
                        </ListboxButton>
                        <ListboxOptions className="absolute z-10 mt-1 max-h-60 w-fit min-w-[180px] overflow-auto rounded-md bg-white dark:bg-gray-800 py-1 text-sm shadow-lg ring-1 ring-black/5 dark:ring-white/10 focus:outline-none">
                          {SEVERITY_OPTIONS.map((option) => {
                            const Icon = option.icon
                            return (
                              <ListboxOption
                                key={option.value}
                                value={option.value}
                                className={({ focus, selected }) =>
                                  `relative cursor-pointer select-none py-2 pl-3 pr-9 ${
                                    focus ? 'bg-gray-100 dark:bg-gray-700' : ''
                                  } ${selected ? 'font-semibold' : ''}`
                                }
                              >
                                {({ selected }) => (
                                  <>
                                    <span className="flex items-center gap-2">
                                      <Icon className={`h-4 w-4 ${option.iconColor}`} />
                                      <span className={`block truncate ${option.textColor}`}>{option.label}</span>
                                    </span>
                                    {selected && (
                                      <span className="absolute inset-y-0 right-0 flex items-center pr-3">
                                        <Check className="h-4 w-4 text-orange-500" aria-hidden="true" />
                                      </span>
                                    )}
                                  </>
                                )}
                              </ListboxOption>
                            )
                          })}
                        </ListboxOptions>
                      </div>
                    </Listbox>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        ) : (
          <Card className="p-4">
            <p className="text-gray-500 dark:text-gray-400 italic">No test settings configured</p>
          </Card>
        )}
      </section>

      {/* Fixed Export Bar at bottom of right pane */}
      <div
        className="fixed bottom-0 right-0 bg-white dark:bg-gray-900 border-t border-gray-200 dark:border-gray-700 px-6 py-4 shadow-lg z-50 transition-all duration-200"
        style={{ left: isCollapsed ? '4rem' : '16rem' }}
      >
        <div className="flex items-center justify-between">
          <p className="text-sm text-gray-600 dark:text-gray-400">
            {hasChanges ? "You have unsaved changes to the configuration." : "Edit settings above to make changes."}
          </p>
          <div className="flex items-center gap-3">
            <button
              onClick={handleReset}
              disabled={!hasChanges}
              className="flex items-center gap-2 px-4 py-2 bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 font-medium rounded-md transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Reset
            </button>
            <button
              onClick={handleExport}
              disabled={!hasChanges}
              className="flex items-center gap-2 px-4 py-2 bg-orange-500 hover:bg-orange-600 text-white font-medium rounded-md transition-colors disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-orange-500"
            >
              <Download className="h-4 w-4" />
              Export Config
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
