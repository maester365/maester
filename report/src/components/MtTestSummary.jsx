
import React from "react";
import { Grid, Flex, Metric, Text, Icon, CategoryBar, ProgressBar, Card } from "@tremor/react";
import { CheckCircleIcon, ExclamationTriangleIcon, ArchiveBoxIcon, ExclamationCircleIcon, ForwardIcon, MagnifyingGlassCircleIcon } from "@heroicons/react/24/solid";

export default function MtTestSummary(props) {

    const allStatuses = ['Passed', 'Failed', 'Skipped', 'Investigate', 'NotRun', 'Error'];

    function handleCardClick(status) {
        if (!props.onStatusChange) return;
        if (status === null) {
            props.onStatusChange(allStatuses);
            return;
        }
        const current = props.selectedStatus ?? allStatuses;
        const isAll = current.length === allStatuses.length;
        if (isAll) {
            // First click from "all" view — narrow to just this one
            props.onStatusChange([status]);
        } else if (current.includes(status)) {
            // Deselect — but don't allow empty selection
            const next = current.filter(s => s !== status);
            props.onStatusChange(next.length > 0 ? next : allStatuses);
        } else {
            props.onStatusChange([...current, status]);
        }
    }

    function isActive(status) {
        if (!props.selectedStatus) return true;
        if (status === null) return props.selectedStatus.length === allStatuses.length;
        return props.selectedStatus.includes(status);
    }

    const cardClass = (status) =>
        `cursor-pointer transition-opacity ${props.onStatusChange && !isActive(status) ? "opacity-50 hover:opacity-100" : ""}`;

    const pctPassed = getPercentage(props.PassedCount);
    const pctFailed = getPercentage(props.FailedCount);
    const pctError = getPercentage(props.ErrorCount);
    const pctInvestigate = getPercentage(props.InvestigateCount);

    const testSummary = [
        props.PassedCount || 0,
        props.FailedCount || 0,
        props.InvestigateCount || 0,
        props.ErrorCount || 0
    ];
    const testSummaryColors = ["emerald", "rose", "purple", "orange"];

    function getPercentage(count) {
        const total = props.TotalCount - (props.SkippedCount || 0) - (props.NotRunCount || 0) || 0;
        if (total === 0) return 0;
        return Math.round(((count || 0) / total) * 100);
    }

    let visibleCards = 3;
    if (props.InvestigateCount > 0) visibleCards++;
    if (props.ErrorCount > 0) visibleCards++;

    return (
        <Grid numItemsSm={2} numItemsLg={visibleCards} className="gap-6 mb-6">
            <Card className={cardClass(null)} onClick={() => handleCardClick(null)}>
                <Flex alignItems="start">
                    <Text>Total tests</Text>
                </Flex>
                <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                    <Metric>{props.TotalCount - (props.SkippedCount || 0) - (props.NotRunCount || 0)}</Metric>
                </Flex>
                <CategoryBar
                    showAnimation={true}
                    values={testSummary}
                    colors={testSummaryColors}
                    className="mt-4"
                    showLabels={false}
                />
            </Card>
            <Card className={cardClass('Passed')} onClick={() => handleCardClick('Passed')}>
                <Flex alignItems="start">
                    <Text>Passed</Text>
                    <Icon icon={CheckCircleIcon} color="emerald" size="md" className="ml-2 w-4 h-4" />
                </Flex>
                <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                    <Metric>{props.PassedCount}</Metric>
                </Flex>
                <ProgressBar value={pctPassed} color="emerald" className="mt-3" showAnimation={true} />
            </Card>
            <Card className={cardClass('Failed')} onClick={() => handleCardClick('Failed')}>
                <Flex alignItems="start">
                    <Text>Failed</Text>
                    <Icon icon={ExclamationTriangleIcon} color="rose" size="md" className="ml-2 w-4 h-4" />
                </Flex>
                <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                    <Metric>{props.FailedCount}</Metric>
                </Flex>
                <ProgressBar value={pctFailed} color="rose" className="mt-3" showAnimation={true} />
            </Card>
            {props.InvestigateCount > 0 && (
                <Card className={cardClass('Investigate')} onClick={() => handleCardClick('Investigate')}>
                    <Flex alignItems="start">
                        <Text>Investigate</Text>
                        <Icon icon={MagnifyingGlassCircleIcon} color="purple" size="md" className="ml-2 w-4 h-4" />
                    </Flex>
                    <Flex justifyContent="start" alignItems="baseline" className="truncate space-x-3">
                        <Metric>{props.InvestigateCount}</Metric>
                    </Flex>
                    <ProgressBar value={pctInvestigate} color="purple" className="mt-3" showAnimation={true} />
                </Card>
            )}
            {props.ErrorCount > 0 && (
                <Card className={cardClass('Error')} onClick={() => handleCardClick('Error')}>
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