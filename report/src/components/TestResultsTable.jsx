import { useState } from "react";
import { Flex, Card, Table, TableRow, TableCell, TableHead, TableHeaderCell, TableBody, MultiSelect, MultiSelectItem, } from "@tremor/react";
import ResultInfoDialog from "./ResultInfoDialog";
import StatusLabel from "./StatusLabel";


export default function TestResultsTable(props) {
  const [selectedStatus, setSelectedStatus] = useState(['Passed', 'Failed', 'Skipped']);
  const [selectedBlock, setSelectedBlock] = useState([]);
  const testResults = props.TestResults;

  const isStatusSelected = (item) => {
    return (selectedStatus.includes(item.Result) || selectedStatus.length === 0) && (selectedBlock.includes(item.Block) || selectedBlock.length === 0);
  }

  const status = ['Passed', 'Failed', 'NotRun', 'Skipped'];

  return (
    <Card>
      <Flex justifyContent="start">
        <MultiSelect
          onValueChange={setSelectedBlock}
          placeholder="Select category..."
          className="max-w-lg mr-6"
        >
          {testResults.Blocks
            .sort((a, b) => a.Name > b.Name ? 1 : -1)
            .map((item) => (
              <MultiSelectItem key={item.Name} value={item.Name}>
                {item.Name}
              </MultiSelectItem>
            ))}
        </MultiSelect>
        <MultiSelect
          defaultValue={['Passed', 'Failed', 'Skipped']}
          onValueChange={setSelectedStatus}
          placeholder="Select status..."
          className="min-w-fit max-w-6"
        >
          {status.map((item) => (
            <MultiSelectItem key={item} value={item}>
              <StatusLabel Result={item} />
            </MultiSelectItem>
          ))}
        </MultiSelect>
      </Flex>
      <Table className="mt-6 w-full">
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
            .sort((a, b) => a.Name > b.Name ? 1 : -1)
            .map((item) => (
              <TableRow>
                <TableCell className="whitespace-normal">
                  <ResultInfoDialog Title={true} Item={item} /></TableCell>
                <TableCell className="text-center">
                  <StatusLabel Result={item.Result} />
                </TableCell>
                <TableCell className="text-center"><ResultInfoDialog Button={true} Item={item} /></TableCell>
              </TableRow>
            ))}
        </TableBody>
      </Table>
    </Card>
  );
}