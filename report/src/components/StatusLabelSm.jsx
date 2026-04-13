
import React from "react";
import { Icon } from "@tremor/react";
import { CheckCircleIcon, ExclamationTriangleIcon, ArchiveBoxIcon, ExclamationCircleIcon, ForwardIcon, MagnifyingGlassCircleIcon } from "@heroicons/react/24/solid";

export default function StatusLabelSm(props) {

    return (
        <>
            {props.Result === "Passed" &&
                <Icon icon={CheckCircleIcon} color="emerald" size="sm" />
            }
            {props.Result === "Failed" &&
                <Icon icon={ExclamationTriangleIcon} color="rose" size="sm" />
            }
            {props.Result === "Skipped" &&
                <Icon icon={ForwardIcon} color="yellow" size="sm" />
            }
            {props.Result === "Error" &&
                <Icon icon={ExclamationCircleIcon} color="orange" size="sm" />
            }
            {props.Result === "Investigate" &&
                <Icon icon={MagnifyingGlassCircleIcon} color="purple" size="sm" />
            }
            {(props.Result === "NotRun" || props.Result === "Not tested") &&
                <Icon icon={ArchiveBoxIcon} size="md" color="gray" />
            }
        </>
    );
}