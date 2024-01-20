"use client";
import React from "react";
import { List, ListItem, Card, Title, DonutChart } from "@tremor/react";

export default function MtDonutChart(props) {

    function getPercentage(count) {
        return Math.round((count / props.TotalCount) * 100) + "%";
    }

    return (
        <Card>
            <Title>Test status</Title>
            <div className="p-4 flex items-center space-x-6">
                <DonutChart
                    showAnimation={true}
                    className="w-2/3"
                    data={[
                        {
                            name: 'Passed',
                            count: props.PassedCount,
                        },
                        {
                            name: 'Failed',
                            count: props.FailedCount,
                        },
                        {
                            name: 'Not tested',
                            count: props.SkippedCount,
                        }
                    ]}
                    category="count"
                    index="name"
                    colors={["green", "rose", "gray"]}
                    label={props.Result}
                />
                <List className="w-1/3">
                    <ListItem className="space-x-2">
                        <div className="flex items-center space-x-2 truncate">
                            <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-emerald-500" />
                            <span className="truncate">Passed</span>
                        </div>
                        <span>{getPercentage(props.PassedCount)}</span>
                    </ListItem>
                    <ListItem className="space-x-2">
                        <div className="flex items-center space-x-2 truncate">
                            <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-rose-500" />
                            <span className="truncate">Failed</span>
                        </div>
                        <span>{getPercentage(props.FailedCount)}</span>
                    </ListItem>
                    <ListItem className="space-x-2">
                        <div className="flex items-center space-x-2 truncate">
                            <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-gray-500" />
                            <span className="truncate">Not tested</span>
                        </div>
                        <span>{getPercentage(props.SkippedCount)}</span>
                    </ListItem>
                </List>
            </div>
        </Card>
    );
}