
import React from "react";
import { Badge } from "@tremor/react";
import { CheckCircleIcon, ExclamationTriangleIcon, ArchiveBoxIcon, ExclamationCircleIcon, ForwardIcon, MagnifyingGlassCircleIcon } from "@heroicons/react/24/solid";

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
            {props.Result === "Skipped" &&
                <Badge color="yellow" size="xs" icon={ForwardIcon}>
                    {props.Result}
                </Badge>
            }
            {props.Result === "Error" &&
                <Badge color="orange" size="xs" icon={ExclamationCircleIcon}>
                    {props.Result}
                </Badge>
            }
            {props.Result === "Investigate" &&
                <Badge color="purple" size="xs" icon={MagnifyingGlassCircleIcon}>
                    {props.Result}
                </Badge>
            }
            {(props.Result === "NotRun" || props.Result === "Not tested") &&
                <Badge color="gray" size="xs" icon={ArchiveBoxIcon}>
                    Not tested
                </Badge>
            }
        </>
    );
}