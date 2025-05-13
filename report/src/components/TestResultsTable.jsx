import { useState, useEffect, useRef } from "react";
import { Flex, Card, Table, TableRow, TableCell, TableHead, TableHeaderCell, TableBody, MultiSelect, MultiSelectItem, TextInput, Grid } from "@tremor/react";
import ResultInfoDialog from "./ResultInfoDialog";
import StatusLabel from "./StatusLabel";
import SeverityBadge from "./SeverityBadge";
import { ArrowDownIcon, ArrowUpIcon, MagnifyingGlassIcon } from "@heroicons/react/24/solid";

export default function TestResultsTable(props) {
  const [selectedStatus, setSelectedStatus] = useState(['Passed', 'Failed', 'Skipped']);
  const [selectedBlock, setSelectedBlock] = useState([]);
  const [selectedTag, setSelectedTag] = useState([]);
  const [selectedSeverity, setSelectedSeverity] = useState([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [sortColumn, setSortColumn] = useState("Id");
  const [sortDirection, setSortDirection] = useState("asc");
  // Track the currently active dialog
  const [activeDialog, setActiveDialog] = useState(null);
  const testResults = props.TestResults;

  const isStatusSelected = (item) => {
    const matchesSearch = !searchQuery ||
      (item.Id && item.Id.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (item.Title && item.Title.toLowerCase().includes(searchQuery.toLowerCase()));

    return (selectedStatus.length === 0 || selectedStatus.includes(item.Result)) &&
      (selectedBlock.length === 0 || selectedBlock.includes(item.Block)) &&
      (selectedTag.length === 0 || item.Tag.some(tag => selectedTag.includes(tag))) &&
      (selectedSeverity.length === 0 ||
      (selectedSeverity.includes(item.Severity)) ||
      (selectedSeverity.includes("None") && (!item.Severity))) &&
      matchesSearch;
  }

  const handleSort = (column) => {
    if (sortColumn === column) {
      setSortDirection(sortDirection === "asc" ? "desc" : "asc");
    } else {
      setSortColumn(column);
      setSortDirection("asc");
    }
  };

  const getSortedData = (data) => {
    if (!sortColumn) return data;

    return [...data].sort((a, b) => {
      let valueA, valueB;

      // Handle different column types
      if (sortColumn === "Id") {
        valueA = a.Id || "";
        valueB = b.Id || "";
      } else if (sortColumn === "Title") {
        valueA = a.Title || "";
        valueB = b.Title || "";
      } else if (sortColumn === "Severity") {
        // Sort by severity with a specific order: Critical, High, Medium, Low, Info, undefined
        const severityOrder = { "Critical": 5, "High": 4, "Medium": 3, "Low": 2, "Info": 1, "": 0 };
        valueA = a.Severity ? severityOrder[a.Severity] : 0;
        valueB = b.Severity ? severityOrder[b.Severity] : 0;
      } else if (sortColumn === "Status") {
        // Sort by status with a specific order: Failed, Passed, Skipped, NotRun
        const statusOrder = { "Failed": 4, "Passed": 3, "Skipped": 2, "NotRun": 1 };
        valueA = statusOrder[a.Result] || 0;
        valueB = statusOrder[b.Result] || 0;
      }

      // Apply sort direction
      if (sortDirection === "asc") {
        return valueA > valueB ? 1 : valueA < valueB ? -1 : 0;
      } else {
        return valueA < valueB ? 1 : valueA > valueB ? -1 : 0;
      }
    });
  };

  // Get the filtered and sorted data (reused for navigation and rendering)
  const getFilteredSortedData = () => {
    return getSortedData(testResults.Tests.filter((item) => isStatusSelected(item)));
  };

  // Dialog management methods
  const handleDialogOpen = (itemId) => {
    setActiveDialog(itemId);
  };

  const handleDialogClose = () => {
    setActiveDialog(null);
  };

  // Navigation handlers for moving between result items
  const handleNavigateToNext = (currentItemId) => {
    const filteredData = getFilteredSortedData();
    const currentIndex = filteredData.findIndex(
      (item) => (item.Id || item.Name) === currentItemId
    );

    // If current item found and not the last one, move to next
    if (currentIndex !== -1 && currentIndex < filteredData.length - 1) {
      const nextItem = filteredData[currentIndex + 1];
      const nextItemId = nextItem.Id || nextItem.Name;

      // Simply set the active dialog to the next item
      // The dialog component will handle showing/hiding appropriately
      setActiveDialog(nextItemId);
    }
  };

  const handleNavigateToPrevious = (currentItemId) => {
    const filteredData = getFilteredSortedData();
    const currentIndex = filteredData.findIndex(
      (item) => (item.Id || item.Name) === currentItemId
    );

    // If current item found and not the first one, move to previous
    if (currentIndex > 0) {
      const prevItem = filteredData[currentIndex - 1];
      const prevItemId = prevItem.Id || prevItem.Name;

      // Simply set the active dialog to the previous item
      // The dialog component will handle showing/hiding appropriately
      setActiveDialog(prevItemId);
    }
  };

  // Create a sortable header cell
  const SortableHeader = ({ column, label, className }) => (
    <TableHeaderCell
      className={`cursor-pointer hover:bg-tremor-background-subtle transition-colors ${className || ""}`}
      onClick={() => handleSort(column)}
    >
      <div className="flex items-center justify-center gap-1">
        {label}
        {sortColumn === column && (
          sortDirection === "asc" ?
            <ArrowUpIcon className="h-4 w-4" /> :
            <ArrowDownIcon className="h-4 w-4" />
        )}
      </div>
    </TableHeaderCell>
  );

  const status = ['Passed', 'Failed', 'NotRun', 'Skipped'];
  const severities = ['Critical', 'High', 'Medium', 'Low', 'Info', 'None'];
  const uniqueTags = [...new Set(testResults.Tests.flatMap((t) => t.Tag || []))];

  // Get the filtered and sorted data once for rendering
  const filteredSortedData = getFilteredSortedData();

  return (
    <Card>
      {/* First row: Search, Status, Severity in one row */}
      <Flex justifyContent="between" className="gap-2 mb-2">
        <TextInput
          icon={MagnifyingGlassIcon}
          placeholder="Search by ID or Title..."
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-1/3"
        />

        <MultiSelect
          onValueChange={setSelectedSeverity}
          placeholder="Severity"
          className="w-1/3"
        >
          {severities.map((severity) => (
            <MultiSelectItem key={severity} value={severity}>
              {severity !== "None" ?
                <SeverityBadge Severity={severity} /> :
                "None"
              }
            </MultiSelectItem>
          ))}
        </MultiSelect>

        <MultiSelect
          onValueChange={setSelectedStatus}
          placeholder="Status"
          defaultValue={['Passed', 'Failed', 'Skipped']}
          className="w-1/3"
        >
          {status.map((item) => (
            <MultiSelectItem key={item} value={item}>
              <StatusLabel Result={item} />
            </MultiSelectItem>
          ))}
        </MultiSelect>
      </Flex>

      {/* Second row: Category and Tag in one row */}
      <Flex justifyContent="between" className="gap-2 mb-4">
        <MultiSelect
          onValueChange={setSelectedBlock}
          placeholder="Category"
          className="w-1/2"
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
          onValueChange={setSelectedTag}
          placeholder="Tag"
          className="w-1/2"
        >
          {uniqueTags
            .sort((a, b) => a > b ? 1 : -1)
            .map((tag) => (
              <MultiSelectItem key={tag} value={tag}>
                {tag}
              </MultiSelectItem>
            ))}
        </MultiSelect>
      </Flex>

      <Table className="mt-2 w-full">
        <TableHead>
          <TableRow>
            <SortableHeader column="Id" label="ID" className="text-left w-auto whitespace-nowrap" />
            <SortableHeader column="Title" label="Title" className="text-left w-full" />
            <SortableHeader column="Severity" label="Severity" className="text-center whitespace-nowrap" />
            <SortableHeader column="Status" label="Status" className="text-center whitespace-nowrap" />
            <TableHeaderCell className="text-center whitespace-nowrap">Info</TableHeaderCell>
          </TableRow>
        </TableHead>

        <TableBody>
          {filteredSortedData.map((item, index) => {
            const itemId = item.Id || item.Name;
            const hasPrevious = index > 0;
            const hasNext = index < filteredSortedData.length - 1;

            return (
              <TableRow key={item.Index}>
                <TableCell className="font-mono text-xs text-gray-600 dark:text-gray-400 whitespace-nowrap">
                  <ResultInfoDialog
                    Title={false}
                    Item={item}
                    DisplayText={itemId}
                    onNavigateNext={hasNext ? handleNavigateToNext : null}
                    onNavigatePrevious={hasPrevious ? handleNavigateToPrevious : null}
                    onDialogOpen={handleDialogOpen}
                    onDialogClose={handleDialogClose}
                    activeDialog={activeDialog}
                  />
                </TableCell>
                <TableCell className="whitespace-normal cursor-pointer hover:text-blue-600 hover:underline transition-colors">
                  <ResultInfoDialog
                    Title={false}
                    Item={item}
                    DisplayText={item.Title || (item.Name && item.Name.split(': ')[1])}
                    onNavigateNext={hasNext ? handleNavigateToNext : null}
                    onNavigatePrevious={hasPrevious ? handleNavigateToPrevious : null}
                    onDialogOpen={handleDialogOpen}
                    onDialogClose={handleDialogClose}
                    activeDialog={activeDialog}
                  />
                </TableCell>
                <TableCell className="text-center">
                  {item.Severity && item.Severity !== "" ? <SeverityBadge Severity={item.Severity} /> : ""}
                </TableCell>
                <TableCell className="text-center">
                  <StatusLabel Result={item.Result} />
                </TableCell>
                <TableCell className="text-center">
                  <ResultInfoDialog
                    Button={true}
                    Item={item}
                    onNavigateNext={hasNext ? handleNavigateToNext : null}
                    onNavigatePrevious={hasPrevious ? handleNavigateToPrevious : null}
                    onDialogOpen={handleDialogOpen}
                    onDialogClose={handleDialogClose}
                    activeDialog={activeDialog}
                  />
                </TableCell>
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
    </Card>
  );
}