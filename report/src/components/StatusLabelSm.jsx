"use client";
import React from "react";
import { Icon } from "@tremor/react";
import { CheckCircleIcon, ExclamationTriangleIcon, ArchiveBoxIcon } from "@heroicons/react/24/solid";

export default function StatusLabelSm(props) {

    return (
        <>
            {props.Result === "Passed" &&
                <Icon icon={CheckCircleIcon} color="emerald" size="sm" />
            }
            {props.Result === "Failed" &&
                <Icon icon={ExclamationTriangleIcon} color="rose" size="sm" />
            }
            {props.Result != "Passed" && props.Result != "Failed" &&
                <Icon icon={ArchiveBoxIcon} size="md" color="gray" />
            }
        </>
    );
}