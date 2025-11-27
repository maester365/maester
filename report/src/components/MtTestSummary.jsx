"use client";
import React from "react";
import { Grid, Flex, Metric, Text, Icon, CategoryBar, ProgressBar, Card } from "@tremor/react";
import { CheckCircleIcon, ExclamationTriangleIcon, ArchiveBoxIcon, ExclamationCircleIcon, ForwardIcon } from "@heroicons/react/24/solid";

export default function MtTestSummary(props) {

    const pctPassed = getPercentage(props.PassedCount);
    const pctFailed = getPercentage(props.FailedCount);
    const pctSkipped = getPercentage(props.SkippedCount);
    const pctNotRun = getPercentage(props.NotRunCount);
    const pctError = getPercentage(props.ErrorCount);

    const testSummary = [pctPassed, pctFailed, pctSkipped, pctNotRun, pctError];
    const testSummaryColors = ["emerald", "rose", "yellow", "gray", "orange"];

    function getPercentage(count) {
        return Math.round((count / props.TotalCount) * 100);
    }

    return (
        <Grid numItemsSm={2} numItemsLg={6} className="gap-6 mb-6">
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
                <ProgressBar value={pctPassed} color="emerald" className="mt-3" showAnimation={true} />
            </Card>
            <Card>
                <Flex alignItems="start">
                    <Text>Failed</Text>
                    <Icon icon={ExclamationTriangleIcon} color="rose" size="md" className="ml-2 w-4 h-4" />
                </Flex>
                <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                    <Metric>{props.FailedCount}</Metric>
                </Flex>
                <ProgressBar value={pctFailed} color="rose" className="mt-3" showAnimation={true} />
            </Card>
            {props.SkippedCount > 0 && (
                <Card>
                    <Flex alignItems="start">
                        <Text>Skipped</Text>
                        <Icon icon={ForwardIcon} color="yellow" size="md" className="ml-2 w-4 h-4" />
                    </Flex>
                    <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                        <Metric>{props.SkippedCount}</Metric>
                    </Flex>
                    <ProgressBar value={pctSkipped} color="yellow" className="mt-3" showAnimation={true} />
                </Card>
            )}
            <Card>
                <Flex alignItems="start">
                    <Text>Not tested</Text>
                    <Icon icon={ArchiveBoxIcon} size="md" color="gray" className="ml-2 w-4 h-4" />
                </Flex>
                <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                    <Metric>{props.NotRunCount}</Metric>
                </Flex>
                <ProgressBar value={pctNotRun} color="gray" className="mt-3" showAnimation={true} />
            </Card>
            {props.ErrorCount > 0 && (
                <Card>
                    <Flex alignItems="start">
                        <Text>Error</Text>
                        <Icon icon={ExclamationCircleIcon} color="orange" size="md" className="ml-2 w-4 h-4" />
                    </Flex>
                    <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                        <Metric>{props.ErrorCount}</Metric>
                    </Flex>
                    <ProgressBar value={pctError} color="orange" className="mt-3" showAnimation={true} />
                </Card>
            )}
        </Grid>
    );
}