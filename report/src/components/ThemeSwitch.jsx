"use client";
import React from "react";
import { TabGroup, TabList, Tab } from "@tremor/react";
import { ComputerDesktopIcon, MoonIcon, SunIcon } from "@heroicons/react/24/solid";
import { useTheme } from 'next-themes'

export default function ThemeSwitch() {

    const { theme, setTheme } = useTheme()
    const [selectedIndex, setSelectedIndex] = React.useState(getIndexFromTheme(theme));

    function handleThemeChange(value){
        setThemeOnIndex(value);
        setSelectedIndex(value);
    }
    function getIndexFromTheme(themeName)
    {
        if (themeName == 'system') return 0;
        if (themeName == 'dark') return 1;
        if (themeName == 'light') return 2;
    }

    function setThemeOnIndex(index)
    {
        if (index == 0) setTheme('system');
        if (index == 1) setTheme('dark');
        if (index == 2) setTheme('light');
    }

    return (
        <>
            <TabGroup index={selectedIndex} onIndexChange={handleThemeChange}>
                <TabList variant="solid">
                    <Tab value="system" icon={ComputerDesktopIcon}></Tab>
                    <Tab value="dark" icon={MoonIcon}></Tab>
                    <Tab value="light" icon={SunIcon}></Tab>
                </TabList>
            </TabGroup>
        </>
    );
}