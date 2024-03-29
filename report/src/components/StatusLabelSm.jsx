"use client";
import React from "react";
import { Icon } from "@tremor/react";
import { CheckCircleIcon, ExclamationTriangleIcon, ArchiveBoxIcon } from "@heroicons/react/24/solid";

export default function StatusLabelSm(props) {

    return (
        <>
            {props.Result === "Passed" &&
                <Icon icon={CheckCircleIcon} color="emerald" size="md" className="ml-2 w-4 h-4" />
            }
            {props.Result === "Failed" &&
                <Icon icon={ExclamationTriangleIcon} color="rose" size="md" className="ml-2 w-4 h-4" />
            }
            {props.Result != "Passed" && props.Result != "Failed" &&
                <Icon icon={ArchiveBoxIcon} size="md" color="gray" className="ml-2 w-4 h-4" />
            }
        </>
    );
}