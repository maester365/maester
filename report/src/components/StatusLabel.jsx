"use client";
import React from "react";
import { Badge } from "@tremor/react";
import { CheckCircleIcon, ExclamationTriangleIcon, ArchiveBoxIcon } from "@heroicons/react/24/solid";

export default function StatusLabel(props) {

    return (
        <>
            {props.Result === "Passed" &&
                <Badge color="emerald" size="xs" icon={CheckCircleIcon}>
                    {props.Result}
                </Badge>
            }
            {props.Result === "Failed" &&
                <Badge color="rose" size="xs" icon={ExclamationTriangleIcon}>
                    {props.Result}
                </Badge>
            }
            {props.Result != "Passed" && props.Result != "Failed" &&
                <Badge color="gray" size="xs" icon={ArchiveBoxIcon}>
                    {props.Result}
                </Badge>
            }

        </>
    );
}