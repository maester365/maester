
import React from "react";
import { List, ListItem, Card, Title, DonutChart } from "@tremor/react";

export default function MtDonutChart(props) {

    function getPercentage(count) {
        let total = (props.PassedCount || 0) + (props.FailedCount || 0) + (props.InvestigateCount || 0);
        let percent = Math.round(count / total * 100);
        if(isNaN(percent)) percent = "0";
        return percent + "%";
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
                            name: 'Pass',
                            count: props.PassedCount,
                        },
                        {
                            name: 'Fail',
                            count: props.FailedCount,
                        },
                        {
                            name: 'Investigate',
                            count: props.InvestigateCount || 0,
                        }
                    ]}
                    category="count"
                    index="name"
                    colors={["green", "rose", "purple"]}
                    label={props.Result}
                />
                <List className="w-1/3">
                    <ListItem className="space-x-2">
                        <div className="flex items-center space-x-2 truncate">
                            <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-emerald-500" />
                            <span className="truncate">Pass</span>
                        </div>
                        <span>{getPercentage(props.PassedCount)}</span>
                    </ListItem>
                    <ListItem className="space-x-2">
                        <div className="flex items-center space-x-2 truncate">
                            <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-rose-500" />
                            <span className="truncate">Fail</span>
                        </div>
                        <span>{getPercentage(props.FailedCount)}</span>
                    </ListItem>
                    {(props.InvestigateCount > 0) && (
                        <ListItem className="space-x-2">
                            <div className="flex items-center space-x-2 truncate">
                                <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-purple-500" />
                                <span className="truncate">Investigate</span>
                            </div>
                            <span>{getPercentage(props.InvestigateCount)}</span>
                        </ListItem>
                    )}
                </List>
            </div>
        </Card>
    );
}