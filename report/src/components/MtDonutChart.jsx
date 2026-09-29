
import React from "react";
import { Card, Title } from "@/components/ui/report";

export default function MtDonutChart(props) {

    function getPercentage(count) {
        let total = (props.PassedCount || 0) + (props.FailedCount || 0) + (props.InvestigateCount || 0);
        let percent = Math.round(count / total * 100);
        if (isNaN(percent)) percent = "0";
        return percent + "%";
    }

    const passed = props.PassedCount || 0;
    const failed = props.FailedCount || 0;
    const investigate = props.InvestigateCount || 0;
    const total = passed + failed + investigate;
    const passStop = total ? passed / total * 100 : 0;
    const failStop = total ? (passed + failed) / total * 100 : passStop;
    const chartBackground = `conic-gradient(#22c55e 0 ${passStop}%, #f43f5e ${passStop}% ${failStop}%, #a855f7 ${failStop}% 100%)`;

    return (
        <Card>
            <Title>Test status</Title>
                <div className="p-4 flex items-center space-x-6">
                <div className="flex w-2/3 items-center justify-center" aria-label={`Test status: ${props.Result}`}>
                    <div className="relative aspect-square w-full max-w-40 rounded-full" style={{ background: chartBackground }}>
                        <div className="absolute inset-[12.5%] flex items-center justify-center rounded-full bg-white text-base text-gray-700 dark:bg-zinc-900 dark:text-gray-200">
                            {props.Result}
                        </div>
                    </div>
                </div>
                <ul className="w-1/3 divide-y divide-gray-200 text-sm text-gray-600 dark:divide-gray-800 dark:text-gray-300">
                    <li className="flex items-center justify-between space-x-2 py-2">
                        <div className="flex items-center space-x-2 truncate">
                            <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-emerald-500" />
                            <span className="truncate">Pass</span>
                        </div>
                        <span>{getPercentage(props.PassedCount)}</span>
                    </li>
                    <li className="flex items-center justify-between space-x-2 py-2">
                        <div className="flex items-center space-x-2 truncate">
                            <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-rose-500" />
                            <span className="truncate">Fail</span>
                        </div>
                        <span>{getPercentage(props.FailedCount)}</span>
                    </li>
                    {(props.InvestigateCount > 0) && (
                        <li className="flex items-center justify-between space-x-2 py-2">
                            <div className="flex items-center space-x-2 truncate">
                                <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-purple-500" />
                                <span className="truncate">Investigate</span>
                            </div>
                            <span>{getPercentage(props.InvestigateCount)}</span>
                        </li>
                    )}
                </ul>
            </div>
        </Card>
    );
}
