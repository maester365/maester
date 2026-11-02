
import React from "react";
import { Icon } from "@/components/ui/report";
import { CircleCheck, TriangleAlert, Archive, CircleAlert, FastForward, SearchCheck } from "lucide-react"

export default function StatusLabelSm(props) {

    return (
        <>
            {props.Result === "Passed" &&
                <Icon icon={CircleCheck} color="emerald" size="sm" />
            }
            {props.Result === "Failed" &&
                <Icon icon={TriangleAlert} color="rose" size="sm" />
            }
            {props.Result === "Skipped" &&
                <Icon icon={FastForward} color="yellow" size="sm" />
            }
            {props.Result === "Error" &&
                <Icon icon={CircleAlert} color="orange" size="sm" />
            }
            {props.Result === "Investigate" &&
                <Icon icon={SearchCheck} color="purple" size="sm" />
            }
            {(props.Result === "NotRun" || props.Result === "Not tested") &&
                <Icon icon={Archive} size="md" color="gray" />
            }
        </>
    );
}
