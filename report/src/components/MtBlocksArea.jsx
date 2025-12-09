
import React, { useState, useEffect, useCallback } from "react";
import { Text, AreaChart, ListItem, Card, Title, CategoryBar } from "@tremor/react";
import { Maximize2, X } from "lucide-react";

export default function MtBlocksArea(props) {
    const [isModalOpen, setIsModalOpen] = useState(false);

    const closeModal = useCallback(() => {
        setIsModalOpen(false);
    }, []);

    // Handle Escape key press
    useEffect(() => {
        if (!isModalOpen) return;

        const handleKeyDown = (e) => {
            if (e.key === "Escape") {
                closeModal();
            }
        };

        document.addEventListener("keydown", handleKeyDown);
        return () => document.removeEventListener("keydown", handleKeyDown);
    }, [isModalOpen, closeModal]);

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

    // Process blocks to use formatted names and rename count fields
    const formattedBlocks = props.Blocks?.map(block => ({
        ...block,
        Name: formatCategoryName(block.Name),
        Passed: block.PassedCount,
        Failed: block.FailedCount,
        Skipped: block.SkippedCount,
    })) || [];

    return (
        <>
            <Card>
                <div className="flex items-center justify-between">
                    <Title>By category</Title>
                    <button
                        onClick={() => setIsModalOpen(true)}
                        className="p-1.5 rounded-md text-gray-500 hover:text-gray-700 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-gray-200 dark:hover:bg-gray-800 transition-colors"
                        aria-label="Expand chart"
                    >
                        <Maximize2 className="h-4 w-4" />
                    </button>
                </div>
                <AreaChart
                    className="mt-4 h-40"
                    data={formattedBlocks}
                    index="Name"
                    yAxisWidth={65}
                    categories={["Passed", "Failed", "Skipped"]}
                    colors={["emerald", "rose", "gray"]}
                    showAnimation={true}
                    showLegend={false}
                />
            </Card>

            {/* Full-screen Modal */}
            {isModalOpen && (
                <div
                    className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm"
                    onClick={closeModal}
                >
                    <div
                        className="relative w-[95vw] h-[90vh] bg-white dark:bg-gray-900 rounded-lg shadow-xl p-6"
                        onClick={(e) => e.stopPropagation()}
                    >
                        <div className="flex items-center justify-between mb-4">
                            <Title>By category</Title>
                            <button
                                onClick={closeModal}
                                className="p-1.5 rounded-md text-gray-500 hover:text-gray-700 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-gray-200 dark:hover:bg-gray-800 transition-colors"
                                aria-label="Close"
                            >
                                <X className="h-5 w-5" />
                            </button>
                        </div>
                        <AreaChart
                            className="h-[calc(90vh-100px)]"
                            data={formattedBlocks}
                            index="Name"
                            yAxisWidth={65}
                            categories={["Passed", "Failed", "Skipped"]}
                            colors={["emerald", "rose", "gray"]}
                            showAnimation={true}
                            showLegend={true}
                        />
                    </div>
                </div>
            )}
        </>
    );
}