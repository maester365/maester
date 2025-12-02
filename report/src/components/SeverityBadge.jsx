
import React from "react";
import { Badge } from "@tremor/react";
import {
  ExclamationCircleIcon,
  ShieldExclamationIcon,
  ExclamationTriangleIcon,
  BellIcon,
  InformationCircleIcon
} from "@heroicons/react/24/solid";

export default function SeverityBadge(props) {
    if (!props.Severity || props.Severity === "") {
        return null;
    }

    // Common style for all severity badges to reduce prominence
    const badgeStyle = "opacity-60 hover:opacity-100 transition-opacity";

    return (
        <>
            {props.Severity === "Critical" &&
                <Badge color="rose" size="xs" className={badgeStyle}>
                    {props.Severity}
                </Badge>
            }
            {props.Severity === "High" &&
                <Badge color="red" size="xs" className={badgeStyle}>
                    {props.Severity}
                </Badge>
            }
            {props.Severity === "Medium" &&
                <Badge color="amber" size="xs" className={badgeStyle}>
                    {props.Severity}
                </Badge>
            }
            {props.Severity === "Low" &&
                <Badge color="green" size="xs" className={badgeStyle}>
                    {props.Severity}
                </Badge>
            }
            {props.Severity === "Info" &&
                <Badge color="gray" size="xs" className={badgeStyle}>
                    {props.Severity}
                </Badge>
            }
        </>
    );
}