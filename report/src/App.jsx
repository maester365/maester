import { Card, Metric, Text, Title, DonutChart, LineChart, Grid, Flex, Divider } from "@tremor/react";

import './App.css'
import TestResultsTable from './components/TestResultsTable';
import { Icon, Badge, CategoryBar, ProgressBar, List, ListItem } from "@tremor/react";
import { CheckCircleIcon, ExclamationIcon, ArchiveIcon, CalendarIcon, OfficeBuildingIcon } from "@heroicons/react/solid";
import { utcToZonedTime } from 'date-fns-tz'
import ThemeSwitch from "./components/ThemeSwitch";
import { ThemeProvider } from 'next-themes'
import logo from './assets/maester.png';

/*The sample data will be replaced by the New-MtReport when it runs the generation.*/
const testResults = {
  "Result": "Failed",
  "FailedCount": 4,
  "PassedCount": 3,
  "SkippedCount": 0,
  "TotalCount": 7,
  "ExecutedAt": "2024-01-19T02:21:13.621744+11:00",
  "TenantId": "0817c655-a853-4d8f-9723-3a333b5b9235",
  "TenantName": "Pora Inc.",
  "Account": "merill@elapora.com",
  "Tests": [
    {
      "Name": "ID1002: App management restrictions on applications and service principals is configured and enabled.",
      "HelpUrl": "https://maester.dev/t/ID.1002",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtAppManagementPolicyEnabled | Should -Be $true -Because \"There is no app policy to use secure credentials\"\n    ",
      "ErrorRecord": "Expected $true, because There is no app policy to use secure credentials, but got $false.",
      "Duration": "00:00:00.0611901",
      "Block": "[-] App Management Policies"
    },
    {
      "Name": "ID1001: At least one Conditional Access policy is configured with device compliance.",
      "HelpUrl": "https://maester.dev/t/ID.1001",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaDeviceComplianceExists | Should -Be $true -Because \"There is no policy which requires device compliances\"\n    ",
      "ErrorRecord": "",
      "Duration": "00:00:04.7308833",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1003: At least one Conditional Access policy is configured with All Apps.",
      "HelpUrl": "https://maester.dev/t/ID.1003",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists -SkipCheckAllUsers | Should -Be $true -Because \"There is no policy scoped to All Apps\"\n    ",
      "ErrorRecord": "",
      "Duration": "00:00:00.0036193",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1004: At least one Conditional Access policy is configured with All Apps and All Users.",
      "HelpUrl": "https://maester.dev/t/ID.1004",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists | Should -Be $true -Because \"There is no policy scoped to All Apps and All Users\"\n    ",
      "ErrorRecord": "Expected $true, because There is no policy scoped to All Apps and All Users, but got $false.",
      "Duration": "00:00:00.0058164",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1005: All Conditional Access policies are configured to exclude at least one emergency account or group.",
      "HelpUrl": "https://maester.dev/t/ID.1005",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaEmergencyAccessExists | Should -Be $true -Because \"There is no emergency access account or group present in all enabled policies\"\n    ",
      "ErrorRecord": "Expected $true, because There is no emergency access account or group present in all enabled policies, but got $false.",
      "Duration": "00:00:00.0146871",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1006: At least one Conditional Access policy is configured to require MFA for admins.",
      "HelpUrl": "https://maester.dev/t/ID.1006",
      "Tag": null,
      "Result": "Failed",
      "ScriptBlock": "\n        Test-MtCaAllAppsExists | Should -Be $true -Because \"There is no policy that requires MFA for admins\"\n    ",
      "ErrorRecord": "Expected $true, because There is no policy that requires MFA for admins, but got $false.",
      "Duration": "00:00:00.0038247",
      "Block": "[-] Conditional Access Baseline Policies"
    },
    {
      "Name": "ID1007: At least one Conditional Access policy is configured to require MFA for all users.",
      "HelpUrl": "https://maester.dev/t/ID.1007",
      "Tag": null,
      "Result": "Passed",
      "ScriptBlock": "\n        Test-MtCaMfaForAllUsers | Should -Be $true -Because \"There is no policy that requires MFA for all users\"\n    ",
      "ErrorRecord": "",
      "Duration": "00:00:00.0020725",
      "Block": "[-] Conditional Access Baseline Policies"
    }
  ]
};
/* Note: DO NOT place any code between the line 'const testResults = {' and 'function App'.
    They will be stripped away new New-MtReport cmdlet generates the user's content */

function App() {

  const testDateLocal = utcToZonedTime(testResults.ExecutedAt, Intl.DateTimeFormat().resolvedOptions().timeZone).toLocaleString();
  const testSummary = [40, 60, 0];
  const testSummaryColors = ["emerald", "rose", "gray"];

  function getPercentage(count) {
    return Math.round((count / testResults.TotalCount) * 100) + "%";
  }

  function getTenantName() {
    if (testResults.TenantName == "") return "Tenant ID: " + testResults.TenantId;
    return testResults.TenantName + " (" + testResults.TenantId + ")";
  }

  return (
    <ThemeProvider attribute="class" >
      <div className="text-left">
        <div className="flex mb-6">
          <img src={logo} className="h-10 w-10 mr-1" alt="Maester logo" />
          <h1 className="text-3xl font-bold self-end">Maester Test Results</h1>
        </div>
        <Flex>
          <Badge className="bg-blue-200" icon={OfficeBuildingIcon}>{getTenantName()}</Badge>
          <Badge className="bg-blue-200" icon={CalendarIcon}>{testDateLocal}</Badge>
        </Flex>
        <Divider />
        <h2 className="text-2xl font-bold mb-6">Test summary</h2>
        <Grid numItemsSm={2} numItemsLg={4} className="gap-6 mb-6">
          <Card>
            <Flex alignItems="start">
              <Text>Total tests</Text>
            </Flex>
            <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
              <Metric>{testResults.TotalCount}</Metric>
            </Flex>
            <CategoryBar
              values={testSummary}
              colors={testSummaryColors}
              className="mt-4"
              showLabels={false}
            />
          </Card>
          <Card>
            <Flex alignItems="start">
              <Text>Passed</Text>
              <Icon icon={CheckCircleIcon} color="emerald" size="md" className="ml-2 w-4 h-4" />
            </Flex>
            <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
              <Metric>{testResults.PassedCount}</Metric>
            </Flex>
            <ProgressBar value={42} color="emerald" className="mt-3" />
          </Card>
          <Card>
            <Flex alignItems="start">
              <Text>Failed</Text>
              <Icon icon={ExclamationIcon} color="rose" size="md" className="ml-2 w-4 h-4" />
            </Flex>
            <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
              <Metric>{testResults.FailedCount}</Metric>
            </Flex>
            <ProgressBar value={58} color="rose" className="mt-3" />
          </Card>
          <Card>
            <Flex alignItems="start">
              <Text>Not tested</Text>
              <Icon icon={ArchiveIcon} size="md" color="gray" className="ml-2 w-4 h-4" />
            </Flex>
            <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
              <Metric>{testResults.SkippedCount}</Metric>
            </Flex>
            <ProgressBar value={0} color="gray" className="mt-3" />
          </Card>
        </Grid>
        <Grid numItemsSm={2} numItemsLg={2} className="gap-6 mb-6">
          <Card className="max-w-lg mb-6">
            <Title>Test Status</Title>
            <div className="p-4 flex items-center space-x-6">
              <DonutChart
                className="h-40 w-2/3"
                data={[
                  {
                    name: 'Passed',
                    count: testResults.PassedCount,
                  },
                  {
                    name: 'Failed',
                    count: testResults.FailedCount,
                  },
                  {
                    name: 'Not tested',
                    count: testResults.SkippedCount,
                  }
                ]}
                category="count"
                index="name"
                colors={["green", "rose", "gray"]}
                label={testResults.Result}
              />
              <List className="w-1/3">
                <ListItem className="space-x-2">
                  <div className="flex items-center space-x-2 truncate">
                    <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-emerald-500" />
                    <span className="truncate">Passed</span>
                  </div>
                  <span>{getPercentage(testResults.PassedCount)}</span>
                </ListItem>
                <ListItem className="space-x-2">
                  <div className="flex items-center space-x-2 truncate">
                    <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-rose-500" />
                    <span className="truncate">Failed</span>
                  </div>
                  <span>{getPercentage(testResults.FailedCount)}</span>
                </ListItem>
                <ListItem className="space-x-2">
                  <div className="flex items-center space-x-2 truncate">
                    <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-gray-500" />
                    <span className="truncate">Not tested</span>
                  </div>
                  <span>{getPercentage(testResults.SkippedCount)}</span>
                </ListItem>
              </List>
            </div>
          </Card>
        </Grid>

        <Divider />
        <h2 className="text-2xl font-bold mb-6">Test details</h2>
        <div className="grid grid-cols-2 gap-12">
          {/* <div>
          <h2 className="text-2xl font-bold mb-6">Barbie</h2>
          <Card className="max-w-lg mb-6">
            <Title>Sales</Title>
            <DonutChart
              className="mt-6 mb-6"
              data={[
                {
                  name: 'false',
                  userScore: dataBarbie.vote_average,
                },
                {
                  name: 'false',
                  userScore: 10 - dataBarbie.vote_average,
                }
              ]}
              category="userScore"
              index="name"
              colors={["green", "slate"]}
              label={`${(dataBarbie.vote_average * 10).toFixed()}%`}
            />
          </Card>
          <Card className="max-w-xs mx-auto mb-6" decoration="top" decorationColor="indigo">
            <Text>Total Tests</Text>
            <Metric className="text-right">{testResults.TotalCount}</Metric>
          </Card>
          <Card className="max-w-xs mx-auto mb-6" decoration="top" decorationColor="indigo">
            <Text>Budget</Text>
            <Metric>${addCommasToNumber(dataBarbie.budget)}</Metric>
          </Card>
        </div>
        <div>
          <h2 className="text-2xl font-bold mb-6">Oppenheimer</h2>
          <Card className="max-w-lg mb-6">
            <Title>Sales</Title>
            <DonutChart
              className="mt-6 mb-6"
              data={[
                {
                  name: 'false',
                  userScore: dataOppenheimer.vote_average,
                },
                {
                  name: 'false',
                  userScore: 10 - dataOppenheimer.vote_average,
                }
              ]}
              category="userScore"
              index="name"
              colors={["green", "slate"]}
              label={`${(dataOppenheimer.vote_average * 10).toFixed()}%`}
            />
          </Card>
          <Card className="max-w-xs mx-auto mb-6" decoration="top" decorationColor="indigo">
            <Text>Revenue</Text>
            <Metric>${addCommasToNumber(dataOppenheimer.global_revenue)}</Metric>
          </Card>
          <Card className="max-w-xs mx-auto mb-6" decoration="top" decorationColor="indigo">
            <Text>Budget</Text>
            <Metric>${addCommasToNumber(dataOppenheimer.budget)}</Metric>
          </Card>
        </div>
        */}
        </div>

        <TestResultsTable TestResults={testResults} />
        <Divider />
        <Grid numItemsSm={2} numItemsLg={2} className="gap-6 mb-6">
          <Text><a href="https://maester.dev" target="_blank" rel="noreferrer">Maester.dev</a></Text>
          <div className="place-self-end">
            <ThemeSwitch />
          </div>
        </Grid>
      </div>
    </ThemeProvider>
  )
}

export default App
