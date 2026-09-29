
import React, { useState } from "react";
import { Card, Title, Switch, Flex } from "@/components/ui/report";

export default function MtSeverityChart(props) {
    const tests = props.Tests || [];
    const [showPassed, setShowPassed] = useState(true);
    const [showFailed, setShowFailed] = useState(true);
    const [hoveredIndex, setHoveredIndex] = useState(null);

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

    const maxValue = Math.max(...filteredData.map(item => Math.max(item.Passed, item.Failed)));
    const tickValues = [0, Math.round(maxValue / 3), maxValue];

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
            <div className="relative mt-4 h-40 text-xs text-gray-500 dark:text-gray-500" aria-label="Test results by severity">
                <div className="absolute inset-x-0 top-[5px] bottom-[30px]">
                    {tickValues.map((tick) => (
                        <React.Fragment key={tick}>
                            <span className="absolute left-0 w-10 translate-y-1/2 text-right" style={{ bottom: `${maxValue ? tick / maxValue * 100 : 0}%` }}>{tick}</span>
                            <span className="absolute right-0 left-12 border-t border-gray-200 dark:border-zinc-800" style={{ bottom: `${maxValue ? tick / maxValue * 100 : 0}%` }} />
                        </React.Fragment>
                    ))}
                    <div className="absolute inset-y-0 right-5 left-[68px] flex">
                        {filteredData.map((item, index) => (
                            <div
                                key={item.name}
                                className="relative flex min-w-0 flex-1 items-end justify-center gap-1"
                                onMouseEnter={() => setHoveredIndex(index)}
                                onMouseLeave={() => setHoveredIndex(null)}
                            >
                                {showPassed && <div className="w-7 bg-emerald-500 transition-[height] duration-300" style={{ height: `${maxValue ? item.Passed / maxValue * 100 : 0}%` }} />}
                                {showFailed && <div className="w-7 bg-rose-500 transition-[height] duration-300" style={{ height: `${maxValue ? item.Failed / maxValue * 100 : 0}%` }} />}
                                <span className="absolute top-[135px] left-1/2 -translate-x-1/2 whitespace-nowrap text-gray-500 dark:text-gray-500">{item.name}</span>
                                {hoveredIndex === index && (
                                    <div className={index === filteredData.length - 1 ? "absolute top-[-5px] right-0 z-20 w-[152px] rounded-lg border border-gray-200 bg-white text-sm text-gray-500 shadow-lg dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-500" : "absolute top-[-5px] left-1/2 z-20 ml-3 w-[152px] rounded-lg border border-gray-200 bg-white text-sm text-gray-500 shadow-lg dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-500"}>
                                        <p className="border-b border-gray-200 px-4 py-2 font-medium text-gray-700 dark:border-zinc-800 dark:text-zinc-300">{item.name}</p>
                                        <div className="space-y-1 px-4 py-2">
                                            {showPassed && <p className="flex justify-between gap-4"><span className="flex items-center gap-2"><i className="size-2.5 rounded-full bg-emerald-500" />Passed</span><span className="text-gray-700 dark:text-zinc-300">{item.Passed}</span></p>}
                                            {showFailed && <p className="flex justify-between gap-4"><span className="flex items-center gap-2"><i className="size-2.5 rounded-full bg-rose-500" />Failed</span><span className="text-gray-700 dark:text-zinc-300">{item.Failed}</span></p>}
                                        </div>
                                    </div>
                                )}
                            </div>
                        ))}
                    </div>
                </div>
            </div>
        </Card>
    );
}
