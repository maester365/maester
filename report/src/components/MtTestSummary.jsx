"use client";
import React from "react";
import { Grid, Flex, Metric, Text, Icon, CategoryBar, ProgressBar, Card } from "@tremor/react";
import { CheckCircleIcon, ExclamationIcon, ArchiveIcon } from "@heroicons/react/solid";

export default function MtTestSummary(props) {

    const testSummary = [40, 60, 0];
    const testSummaryColors = ["emerald", "rose", "gray"];

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
                <ProgressBar value={42} color="emerald" className="mt-3" />
            </Card>
            <Card>
                <Flex alignItems="start">
                    <Text>Failed</Text>
                    <Icon icon={ExclamationIcon} color="rose" size="md" className="ml-2 w-4 h-4" />
                </Flex>
                <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                    <Metric>{props.FailedCount}</Metric>
                </Flex>
                <ProgressBar value={58} color="rose" className="mt-3" />
            </Card>
            <Card>
                <Flex alignItems="start">
                    <Text>Not tested</Text>
                    <Icon icon={ArchiveIcon} size="md" color="gray" className="ml-2 w-4 h-4" />
                </Flex>
                <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                    <Metric>{props.SkippedCount}</Metric>
                </Flex>
                <ProgressBar value={0} color="gray" className="mt-3" />
            </Card>
        </Grid>
    );
}