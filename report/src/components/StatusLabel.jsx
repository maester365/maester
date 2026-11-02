
import React from "react";
import { Badge } from "@/components/ui/report";
import { CircleCheck, TriangleAlert, Archive, CircleAlert, FastForward, SearchCheck } from "lucide-react"

export default function StatusLabel(props) {

    return (
        <>
            {props.Result === "Passed" &&
                <Badge color="emerald" size="xs" icon={CircleCheck}>
                    {props.Result}
                </Badge>
            }
            {props.Result === "Failed" &&
                <Badge color="rose" size="xs" icon={TriangleAlert}>
                    {props.Result}
                </Badge>
            }
            {props.Result === "Skipped" &&
                <Badge color="yellow" size="xs" icon={FastForward}>
                    {props.Result}
                </Badge>
            }
            {props.Result === "Error" &&
                <Badge color="orange" size="xs" icon={CircleAlert}>
                    {props.Result}
                </Badge>
            }
            {props.Result === "Investigate" &&
                <Badge color="purple" size="xs" icon={SearchCheck}>
                    {props.Result}
                </Badge>
            }
            {(props.Result === "NotRun" || props.Result === "Not tested") &&
                <Badge color="gray" size="xs" icon={Archive}>
                    Not tested
                </Badge>
            }
        </>
    );
}
