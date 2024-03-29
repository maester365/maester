"use client";
import React from "react";
import { Grid, Flex, Metric, Text, Icon, CategoryBar, ProgressBar, Card } from "@tremor/react";
import { CheckCircleIcon, ExclamationTriangleIcon, ArchiveBoxIcon } from "@heroicons/react/24/solid";

export default function MtTestSummary(props) {

    const pctPassed = getPercentage(props.PassedCount);
    const pctFailed = getPercentage(props.FailedCount);
    const pctSkipped = getPercentage(props.SkippedCount);


    const testSummary = [pctPassed, pctFailed, pctSkipped];
    const testSummaryColors = ["emerald", "rose", "gray"];

    function getPercentage(count) {
        return Math.round((count / props.TotalCount) * 100);
    }

    return (
        <Grid numItemsSm={2} numItemsLg={4} className="gap-6 mb-6">
            <Card>
                <Flex alignItems="start">
                    <Text>Total tests</Text>
                </Flex>
                <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                    <Metric>{props.TotalCount}</Metric>
                </Flex>
                <CategoryBar
                    showAnimation={true}
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
                    <Metric>{props.PassedCount}</Metric>
                </Flex>
                <ProgressBar value={getPercentage(props.PassedCount)} color="emerald" className="mt-3" showAnimation={true} />
            </Card>
            <Card>
                <Flex alignItems="start">
                    <Text>Failed</Text>
                    <Icon icon={ExclamationTriangleIcon} color="rose" size="md" className="ml-2 w-4 h-4" />
                </Flex>
                <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                    <Metric>{props.FailedCount}</Metric>
                </Flex>
                <ProgressBar value={getPercentage(props.FailedCount)} color="rose" className="mt-3" showAnimation={true} />
            </Card>
            <Card>
                <Flex alignItems="start">
                    <Text>Not tested</Text>
                    <Icon icon={ArchiveBoxIcon} size="md" color="gray" className="ml-2 w-4 h-4" />
                </Flex>
                <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                    <Metric>{props.SkippedCount}</Metric>
                </Flex>
                <ProgressBar value={getPercentage(props.SkippedCount)} color="gray" className="mt-3" showAnimation={true} />
            </Card>
        </Grid>
    );
}