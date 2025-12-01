
import React, { useState } from "react";
import { Card, Title, BarChart, Switch, Flex, Text } from "@tremor/react";

export default function MtSeverityChart(props) {
    const tests = props.Tests || [];
    const [showPassed, setShowPassed] = useState(true);
    const [showFailed, setShowFailed] = useState(true);

    // Initialize counts
    const severityCounts = {
        Critical: { Passed: 0, Failed: 0 },
        High: { Passed: 0, Failed: 0 },
        Medium: { Passed: 0, Failed: 0 },
        Low: { Passed: 0, Failed: 0 },
        Info: { Passed: 0, Failed: 0 },
    };

    tests.forEach(test => {
        let severity = test.Severity;
        const result = test.Result;

        if (!severity || severity === "Unknown") return;
        if (severity === "Informational") severity = "Info";

        if (result === "Passed" || result === "Failed") {
            if (!severityCounts[severity]) {
                severityCounts[severity] = { Passed: 0, Failed: 0 };
            }
            severityCounts[severity][result]++;
        }
    });

    const data = Object.keys(severityCounts).map(severity => ({
        name: severity,
        Passed: severityCounts[severity].Passed,
        Failed: severityCounts[severity].Failed
    }));

    // Filter data: always show High, Medium, Low; only show Critical and Info if they have counts
    const filteredData = data.filter(item => {
        const alwaysShow = ["High", "Medium", "Low"];
        if (alwaysShow.includes(item.name)) return true;
        // Only show Critical and Info if they have any Passed or Failed counts
        return item.Passed > 0 || item.Failed > 0;
    });

    // Sort by severity level
    const severityOrder = ["Critical", "High", "Medium", "Low", "Info"];
    filteredData.sort((a, b) => {
        const aIndex = severityOrder.indexOf(a.name);
        const bIndex = severityOrder.indexOf(b.name);
        if (aIndex === -1 && bIndex === -1) return 0;
        if (aIndex === -1) return 1;
        if (bIndex === -1) return -1;
        return aIndex - bIndex;
    });

    const categories = [];
    const colors = [];
    if (showPassed) {
        categories.push("Passed");
        colors.push("emerald");
    }
    if (showFailed) {
        categories.push("Failed");
        colors.push("rose");
    }

    const maxValue = Math.max(...filteredData.map(item => Math.max(item.Passed, item.Failed)));

    return (
        <Card>
            <Flex alignItems="center" justifyContent="between">
                <Title className="whitespace-nowrap">By severity</Title>
                {!props.hideControls && (
                    <Flex justifyContent="end" className="space-x-4">
                        <Switch checked={showPassed} onChange={setShowPassed} color="emerald" />
                        <Switch checked={showFailed} onChange={setShowFailed} color="rose" />
                    </Flex>
                )}
            </Flex>
            <BarChart
                className="mt-4 h-40"
                data={filteredData}
                index="name"
                categories={categories}
                colors={colors}
                yAxisWidth={48}
                stack={false}
                showAnimation={true}
                showLegend={false}
                maxValue={maxValue}
            />
        </Card>
    );
}
