
import React, { useState, useEffect, useCallback, useRef } from "react";
import { Card, Title } from "@/components/ui/report";
import { Maximize2, X } from "lucide-react";

const series = [
    { key: "Passed", color: "#10b981" },
    { key: "Failed", color: "#f43f5e" },
    { key: "Investigate", color: "#a855f7" },
];

function CategoryChart({ data, showLegend = false, className = "" }) {
    const chartRef = useRef(null);
    const gridRef = useRef(null);
    const plotRef = useRef(null);
    const [chartWidth, setChartWidth] = useState(315);
    const [hoveredIndex, setHoveredIndex] = useState(null);
    const largestValue = Math.max(1, ...data.flatMap(item => series.map(({ key }) => item[key] || 0)));
    const tickStep = Math.max(1, Math.ceil(largestValue / 4));
    const maxValue = tickStep * 4;
    const ticks = [0, tickStep, tickStep * 2, tickStep * 3, maxValue];
    const points = key => data.map((item, index) => `${data.length < 2 ? 50 : index * 100 / (data.length - 1)},${100 - (item[key] || 0) / maxValue * 100}`).join(" ");
    const labelSlots = Math.max(2, Math.floor((chartWidth - 65) / 80));
    const labelStep = data.length <= labelSlots ? 1 : Math.max(1, Math.floor((data.length - 1) / (labelSlots - 1)));

    useEffect(() => {
        if (!chartRef.current) return;
        const observer = new ResizeObserver(([entry]) => setChartWidth(entry.contentRect.width));
        observer.observe(chartRef.current);
        return () => observer.disconnect();
    }, []);

    // Like recharts, anywhere over the plot shows the nearest category, including the edges.
    function handleMouseMove(event) {
        const grid = gridRef.current.getBoundingClientRect();
        const plot = plotRef.current.getBoundingClientRect();
        if (event.clientX < grid.left || event.clientX > grid.right || event.clientY < grid.top || event.clientY > grid.bottom) {
            setHoveredIndex(null);
            return;
        }
        const nearest = data.length < 2 ? 0 : Math.round((event.clientX - plot.left) / plot.width * (data.length - 1));
        setHoveredIndex(Math.min(data.length - 1, Math.max(0, nearest)));
    }

    return (
        <div ref={chartRef} className={`relative text-xs text-gray-500 dark:text-gray-500 ${className}`} aria-label="Test results by category" onMouseMove={handleMouseMove} onMouseLeave={() => setHoveredIndex(null)}>
            {showLegend && (
                <div className="absolute top-[10px] right-0 flex justify-center gap-5 text-xs text-gray-500 dark:text-gray-500">
                    {series.map(item => <span key={item.key} className="flex items-center gap-1.5"><i className="size-2.5 rounded-sm" style={{ backgroundColor: item.color }} />{item.key}</span>)}
                </div>
            )}
            <div ref={gridRef} className={`absolute right-0 bottom-[30px] left-[65px] ${showLegend ? "top-[49px]" : "top-[5px]"}`}>
                {ticks.map((tick, index) => (
                    <React.Fragment key={tick}>
                        <span className="absolute right-[calc(100%+8px)] w-14 translate-y-1/2 text-right" style={{ bottom: `${tick / maxValue * 100}%` }}>{tick}</span>
                        {index !== ticks.length - 2 && <span className="absolute right-0 left-0 border-t border-gray-200 dark:border-zinc-800" style={{ bottom: `${tick / maxValue * 100}%` }} />}
                    </React.Fragment>
                ))}
            </div>
            <div ref={plotRef} className={`absolute right-5 bottom-[30px] left-[85px] ${showLegend ? "top-[49px]" : "top-[5px]"}`}>
                <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="absolute inset-0 h-full w-full overflow-visible" role="img">
                    <defs>
                        {series.map(({ key, color }) => (
                            <linearGradient key={key} id={`category-${key}`} x1="0" y1="0" x2="0" y2="1">
                                <stop offset="0" stopColor={color} stopOpacity="0.2" />
                                <stop offset="1" stopColor={color} stopOpacity="0.01" />
                            </linearGradient>
                        ))}
                    </defs>
                    {series.map(({ key, color }) => (
                        <g key={key}>
                            <polygon points={`0,100 ${points(key)} 100,100`} fill={`url(#category-${key})`} />
                            <polyline points={points(key)} fill="none" stroke={color} strokeWidth="2" vectorEffect="non-scaling-stroke" />
                        </g>
                    ))}
                    {hoveredIndex !== null && data[hoveredIndex] && (
                        <g>
                            <line x1={data.length < 2 ? 50 : hoveredIndex * 100 / (data.length - 1)} y1="0" x2={data.length < 2 ? 50 : hoveredIndex * 100 / (data.length - 1)} y2="100" stroke="#9ca3af" strokeWidth="1" vectorEffect="non-scaling-stroke" />
                        </g>
                    )}
                </svg>
                {hoveredIndex !== null && data[hoveredIndex] && series.map(({ key, color }) => (
                    <i
                        key={key}
                        className="absolute size-3 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white dark:border-zinc-900"
                        style={{
                            left: `${data.length < 2 ? 50 : hoveredIndex * 100 / (data.length - 1)}%`,
                            top: `${100 - (data[hoveredIndex][key] || 0) / maxValue * 100}%`,
                            backgroundColor: color,
                        }}
                    />
                ))}
                {data.map((item, index) => (
                    <div
                        key={item.Name}
                        className="absolute top-0 bottom-0 -translate-x-1/2 outline-none focus-visible:bg-gray-500/10"
                        style={{ left: `${data.length < 2 ? 50 : index * 100 / (data.length - 1)}%`, width: `${100 / Math.max(1, data.length - 1)}%` }}
                        tabIndex={0}
                        aria-label={`${item.Name}: ${series.map(({ key }) => `${item[key] || 0} ${key.toLowerCase()}`).join(", ")}`}
                        onFocus={() => setHoveredIndex(index)}
                        onBlur={() => setHoveredIndex(null)}
                    >
                        {(index % labelStep === 0) && <span className="absolute top-[calc(100%+10px)] left-1/2 -translate-x-1/2 whitespace-nowrap text-gray-500 dark:text-gray-500">{item.Name}</span>}
                        {hoveredIndex === index && (
                            <div className={`absolute z-20 w-[174px] rounded-lg border border-gray-200 bg-white text-sm text-gray-500 shadow-lg dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-500 ${showLegend ? "top-[-49px]" : "top-[-5px]"} ${index === data.length - 1 ? "right-[calc(50%+10px)]" : "left-1/2 ml-[18px] -translate-x-1/2"}`}>
                                <p className="border-b border-gray-200 px-4 py-2 font-medium text-gray-700 dark:border-zinc-800 dark:text-zinc-300">{item.Name}</p>
                                <div className="space-y-1 px-4 py-2">
                                    {series.map(({ key, color }) => (
                                        <p key={key} className="flex justify-between gap-4"><span className="flex items-center gap-2"><i className="size-2.5 rounded-full" style={{ backgroundColor: color }} />{key}</span><span className="text-gray-700 dark:text-zinc-300">{item[key] || 0}</span></p>
                                    ))}
                                </div>
                            </div>
                        )}
                    </div>
                ))}
            </div>
        </div>
    );
}

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

    // Process blocks to use formatted names and rename count fields
    const formattedBlocks = props.Blocks?.map(block => ({
        ...block,
        Name: formatCategoryName(block.Name),
        Passed: block.PassedCount,
        Failed: block.FailedCount,
        Investigate: block.InvestigateCount
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
                <CategoryChart className="mt-4 h-40" data={formattedBlocks} />
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
                        <CategoryChart className="h-[calc(90vh-100px)]" data={formattedBlocks} showLegend />
                    </div>
                </div>
            )}
        </>
    );
}
