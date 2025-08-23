"use client";
import React from "react";
import { Flex, Text, ListItem, Card, Title, CategoryBar } from "@tremor/react";

export default function MtBlocksBar(props) {

	const testSummaryColors = ["emerald", "rose", "gray"];
	const listItems = props.Blocks
		.sort((a, b) => a.Name > b.Name ? 1 : -1)
		.map(c =>
			<span key={c.Name}>
				<Text className="text-right text-xs text-clip text-nowrap">{c.Name}</Text>
				<CategoryBar
					showAnimation={true}
					values={[c.PassedCount, c.FailedCount, c.NotRunCount, c.SkippedCount]}
					colors={testSummaryColors}
					showLabels={false}
					className="pt-1"
				/>
			</span>);

	return (
		<Card><Title>By category</Title>
			<div className="grid grid-cols-3 gap-1">
				{listItems}
			</div>
		</Card>);
}
