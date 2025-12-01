
import React from "react";
import { Text, AreaChart, ListItem, Card, Title, CategoryBar } from "@tremor/react";

export default function MtBlocksArea(props) {

    const testSummaryColors = ["emerald", "rose", "gray"];

    // Map long names to short names
    const shortNameMap = {
        "AzureConfig": "Azure",
        "Custom Security Tests": "Custom",
        "Defender for Identity health issues": "MDI",
        "Exposure Management": "XSPM",
    };

    function formatCategoryName(name) {
        // Strip 'Maester/' prefix if present
        let cleanName = name.startsWith("Maester/") ? name.substring(8) : name;
        // Apply short name mapping if available
        return shortNameMap[cleanName] || cleanName;
    }

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

    // Process blocks to use formatted names
    const formattedBlocks = props.Blocks?.map(block => ({
        ...block,
        Name: formatCategoryName(block.Name)
    })) || [];

    return (
        <Card>
            <Title>By category</Title>
            <AreaChart
                className="mt-4 h-40"
                data={formattedBlocks}
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