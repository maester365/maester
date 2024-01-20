"use client";
import React from "react";
import { Badge } from "@tremor/react";
import { CheckCircleIcon, ExclamationIcon, ArchiveIcon } from "@heroicons/react/solid";

export default function StatusLabel(props) {

    return (
        <>
            {props.Result === "Passed" &&
                <Badge color="emerald" size="xs" icon={CheckCircleIcon}>
                    {props.Result}
                </Badge>
            }
            {props.Result === "Failed" &&
                <Badge color="rose" size="xs" icon={ExclamationIcon}>
                    {props.Result}
                </Badge>
            }
            {props.Result != "Passed" && props.Result != "Failed" &&
                <Badge color="gray" size="xs" icon={ArchiveIcon}>
                    {props.Result}
                </Badge>
            }

        </>
    );
}