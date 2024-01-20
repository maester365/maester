"use client";
import React from "react";
import { Text, AreaChart, ListItem, Card, Title, CategoryBar } from "@tremor/react";

export default function MtBlocksArea(props) {

    const testSummaryColors = ["emerald", "rose", "gray"];

    function getPercentage(count, totalCount) {
        return Math.round((count / totalCount) * 100);
    }

    function getPercentages(item) {
        return [
            getPercentage(item.PassedCount, item.TotalCount),
            getPercentage(item.FailedCount, item.TotalCount),
            getPercentage(item.SkippedCount, item.TotalCount)]
            ;
    }
    return (
        <Card>
            <Title>By type</Title>
            <AreaChart
                className="mt-4 h-40"
                data={props.Blocks}
                index="Name"
                yAxisWidth={65}
                categories={["PassedCount", "FailedCount", "SkippedCount"]}
                colors={["emerald", "rose", "gray"]}
                showAnimation={true}
                showLegend={false}
            />
        </Card>
    );
}