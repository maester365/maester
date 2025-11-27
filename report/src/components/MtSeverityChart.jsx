"use client";
import React from "react";
import { Card, Title, BarChart } from "@tremor/react";

export default function MtSeverityChart(props) {
    const tests = props.Tests || [];

    // Initialize counts
    const severityCounts = {
        Critical: { Passed: 0, Failed: 0 },
        High: { Passed: 0, Failed: 0 },
        Medium: { Passed: 0, Failed: 0 },
        Low: { Passed: 0, Failed: 0 },
        Informational: { Passed: 0, Failed: 0 },
    };

    tests.forEach(test => {
        const severity = test.Severity;
        const result = test.Result;

        if (!severity || severity === "Unknown") return;

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
    })).filter(item => item.Passed > 0 || item.Failed > 0);

    // Sort by severity level
    const severityOrder = ["Critical", "High", "Medium", "Low", "Informational"];
    data.sort((a, b) => {
        return severityOrder.indexOf(a.name) - severityOrder.indexOf(b.name);
    });

    return (
        <Card>
            <Title>By severity</Title>
            <BarChart
                className="mt-4 h-40"
                data={data}
                index="name"
                categories={["Passed", "Failed"]}
                colors={["emerald", "rose"]}
                yAxisWidth={48}
                stack={true}
                showAnimation={true}
                showLegend={false}
            />
        </Card>
    );
}
