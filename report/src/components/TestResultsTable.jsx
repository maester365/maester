import { useState } from "react";
import { Card, Table, TableRow, TableCell, TableHead, TableHeaderCell, TableBody, MultiSelect, MultiSelectItem, } from "@tremor/react";
import ResultInfoDialog from "./ResultInfoDialog";
import StatusLabel from "./StatusLabel";

export default function TestResultsTable(props) {
  const [selectedStatus, setSelectedStatus] = useState([]);
  const testResults = props.TestResults;

  const isStatusSelected = (salesPerson) =>
    selectedStatus.includes(salesPerson.Result) || selectedStatus.length === 0;

  const status = ['Passed', 'Failed', 'Not tested'];

  return (
    <Card>
      <MultiSelect
        onValueChange={setSelectedStatus}
        placeholder="Select status..."
        className="max-w-xs"
      >
        {status.map((item) => (
          <MultiSelectItem key={item} value={item}>
            {item}
          </MultiSelectItem>
        ))}
      </MultiSelect>
      <Table className="mt-6">
        <TableHead>
          <TableRow>
            <TableHeaderCell>Test</TableHeaderCell>
            <TableHeaderCell className="text-center">Status</TableHeaderCell>
            <TableHeaderCell className="text-center">Info</TableHeaderCell>

          </TableRow>
        </TableHead>

        <TableBody>
          {testResults.Tests
            .filter((item) => isStatusSelected(item))
            .map((item) => (
              <TableRow key={item.Name}>
                <TableCell>{item.Name}</TableCell>
                <TableCell className="text-center">
                  <StatusLabel Result={item.Result} />
                </TableCell>
                <TableCell className="text-center"><ResultInfoDialog Item={item} /></TableCell>
              </TableRow>
            ))}
        </TableBody>
      </Table>
    </Card>
  );
}