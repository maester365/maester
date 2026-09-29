
import React, { useLayoutEffect, useRef, useState } from "react";
import { Card, Title } from "@/components/ui/report";

export default function MtDonutChart(props) {

    function getPercentage(count) {
        let total = (props.PassedCount || 0) + (props.FailedCount || 0) + (props.InvestigateCount || 0);
        let percent = Math.round(count / total * 100);
        if (isNaN(percent)) percent = "0";
        return percent + "%";
    }

    const passed = props.PassedCount || 0;
    const failed = props.FailedCount || 0;
    const investigate = props.InvestigateCount || 0;
    const total = passed + failed + investigate;
    const passStop = total ? passed / total * 100 : 0;
    const failStop = total ? (passed + failed) / total * 100 : passStop;
    const chartBackground = `conic-gradient(#22c55e 0 ${passStop}%, #f43f5e ${passStop}% ${failStop}%, #a855f7 ${failStop}% 100%)`;
    const segments = [
        { name: "Pass", value: passed, color: "#22c55e", end: passStop },
        { name: "Fail", value: failed, color: "#f43f5e", end: failStop },
        { name: "Investigate", value: investigate, color: "#a855f7", end: 100 },
    ];

    const areaRef = useRef(null);
    const tooltipRef = useRef(null);
    const [hover, setHover] = useState(null);

    // Find the segment under the pointer from its angle, and only while it is on the ring itself.
    function handleMouseMove(event) {
        const ring = event.currentTarget.getBoundingClientRect();
        const dx = event.clientX - (ring.left + ring.width / 2);
        const dy = event.clientY - (ring.top + ring.height / 2);
        const distance = Math.hypot(dx, dy) / (ring.width / 2);
        if (!total || distance < 0.75 || distance > 1) {
            setHover(null);
            return;
        }
        const percent = ((Math.atan2(dx, -dy) * 180 / Math.PI + 360) % 360) / 3.6;
        const index = segments.findIndex(item => item.value > 0 && percent < item.end);
        const segment = segments[index === -1 ? 2 : index];
        const start = index > 0 ? segments[index - 1].end : 0;
        // Recharts anchors the tooltip at the middle of the segment's arc, not at the pointer.
        const angle = (start + segment.end) / 2 * 3.6 * Math.PI / 180;
        const radius = ring.width / 2 * 0.875;
        const area = areaRef.current.getBoundingClientRect();
        setHover({
            segment,
            x: ring.left - area.left + ring.width / 2 + Math.sin(angle) * radius,
            y: ring.top - area.top + ring.height / 2 - Math.cos(angle) * radius,
        });
    }

    // Place the tooltip like recharts: 10px from the anchor, flipped when it would overflow the chart.
    useLayoutEffect(() => {
        const tooltip = tooltipRef.current;
        if (!hover || !tooltip) return;
        const { width, height } = areaRef.current.getBoundingClientRect();
        const left = hover.x + 10 + tooltip.offsetWidth > width ? Math.max(0, hover.x - 10 - tooltip.offsetWidth) : hover.x + 10;
        const top = hover.y + 10 + tooltip.offsetHeight > height ? Math.max(0, hover.y - 10 - tooltip.offsetHeight) : hover.y + 10;
        tooltip.style.transform = `translate(${left}px, ${top}px)`;
    }, [hover]);

    return (
        <Card>
            <Title>Test status</Title>
                <div className="p-4 flex items-center space-x-6">
                <div ref={areaRef} className="relative flex w-2/3 items-center justify-center" aria-label={`Test status: ${props.Result}`}>
                    {/* Without any results there is nothing to split, so show an empty ring instead of a purple one. */}
                    <div className={`relative aspect-square w-full max-w-40 rounded-full ${total ? "" : "bg-gray-200 dark:bg-zinc-800"}`} style={total ? { background: chartBackground } : undefined} onMouseMove={handleMouseMove} onMouseLeave={() => setHover(null)}>
                        <div className="absolute inset-[12.5%] flex items-center justify-center rounded-full bg-white text-base text-gray-700 dark:bg-zinc-900 dark:text-gray-200">
                            {props.Result}
                        </div>
                    </div>
                    {hover && (
                        <div ref={tooltipRef} className="pointer-events-none absolute top-0 left-0 z-20 rounded-lg border border-gray-200 bg-white text-sm shadow-md dark:border-zinc-800 dark:bg-zinc-900">
                            <div className="flex items-center justify-between space-x-8 px-4 py-2">
                                <div className="flex items-center space-x-2">
                                    <span className="size-3 shrink-0 rounded-full border-2 border-white shadow-sm dark:border-zinc-900" style={{ backgroundColor: hover.segment.color }} />
                                    <p className="whitespace-nowrap text-right text-gray-500 dark:text-zinc-500">{hover.segment.name}</p>
                                </div>
                                <p className="whitespace-nowrap text-right font-medium tabular-nums text-gray-700 dark:text-zinc-200">{hover.segment.value}</p>
                            </div>
                        </div>
                    )}
                </div>
                <ul className="w-1/3 divide-y divide-gray-200 text-sm text-gray-500 dark:divide-zinc-800 dark:text-zinc-500">
                    <li className="flex items-center justify-between space-x-2 py-2">
                        <div className="flex items-center space-x-2 truncate">
                            <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-emerald-500" />
                            <span className="truncate">Pass</span>
                        </div>
                        <span>{getPercentage(props.PassedCount)}</span>
                    </li>
                    <li className="flex items-center justify-between space-x-2 py-2">
                        <div className="flex items-center space-x-2 truncate">
                            <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-rose-500" />
                            <span className="truncate">Fail</span>
                        </div>
                        <span>{getPercentage(props.FailedCount)}</span>
                    </li>
                    {(props.InvestigateCount > 0) && (
                        <li className="flex items-center justify-between space-x-2 py-2">
                            <div className="flex items-center space-x-2 truncate">
                                <span className="h-2.5 w-2.5 rounded-sm flex-shrink-0 bg-purple-500" />
                                <span className="truncate">Investigate</span>
                            </div>
                            <span>{getPercentage(props.InvestigateCount)}</span>
                        </li>
                    )}
                </ul>
            </div>
        </Card>
    );
}
