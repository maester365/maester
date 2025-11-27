import { useState, useEffect, useRef, useCallback, lazy, Suspense, useMemo } from "react";
import { Flex, Card, Table, TableRow, TableCell, TableHead, TableHeaderCell, TableBody, MultiSelect, MultiSelectItem, TextInput, Grid, Button } from "@tremor/react";
import StatusLabel from "./StatusLabel";
import SeverityBadge from "./SeverityBadge";
import { ArrowDownIcon, ArrowUpIcon, MagnifyingGlassIcon } from "@heroicons/react/24/solid";
import { WindowIcon } from "@heroicons/react/24/outline";

// Lazy load the ResultInfoDialog component
const ResultInfoDialog = lazy(() => import("./ResultInfoDialog"));

export default function TestResultsTable(props) {
  const [selectedStatus, setSelectedStatus] = useState(['Passed', 'Failed', 'Skipped','Error']);
  const [selectedBlock, setSelectedBlock] = useState([]);
  const [selectedTag, setSelectedTag] = useState([]);
  const [selectedSeverity, setSelectedSeverity] = useState([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [sortColumn, setSortColumn] = useState("Id");
  const [sortDirection, setSortDirection] = useState("asc");
  const [selectedItem, setSelectedItem] = useState(null);
  const testResults = props.TestResults;

  const handleDialogClose = useCallback(() => {
    setSelectedItem(null);
  }, []);

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
        const statusOrder = { "Error": 5, "Failed": 4, "Passed": 3, "Skipped": 2, "NotRun": 1 };
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
  // Memoize the filtered and sorted data to prevent unnecessary recalculations
  const filteredSortedData = useMemo(() => {
    return getSortedData(testResults.Tests.filter((item) => isStatusSelected(item)));
  }, [testResults.Tests, selectedStatus, selectedBlock, selectedTag, selectedSeverity, searchQuery, sortColumn, sortDirection]);

  const dialogRefs = useRef({});
  useEffect(() => {
    const handleKeyDown = (event) => {
      if (!selectedItem) return;

      if (event.key === "ArrowRight") {
        event.preventDefault();
        handleNavigateToNext();
      } else if (event.key === "ArrowLeft") {
        event.preventDefault();
        handleNavigateToPrevious();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [selectedItem, filteredSortedData]);

  const handleNavigateToNext = () => {
    if (!selectedItem) return;

    const currentIndexInFiltered = filteredSortedData.findIndex(item => item.Index === selectedItem.Index);
    if (currentIndexInFiltered !== -1 && currentIndexInFiltered < filteredSortedData.length - 1) {
      setSelectedItem(filteredSortedData[currentIndexInFiltered + 1]);
    }
  };

  const handleNavigateToPrevious = () => {
    if (!selectedItem) return;

    const currentIndexInFiltered = filteredSortedData.findIndex(item => item.Index === selectedItem.Index);
    if (currentIndexInFiltered > 0) {
      setSelectedItem(filteredSortedData[currentIndexInFiltered - 1]);
    }
  };

  const uniqueBlocks = [...new Set(testResults.Tests.map(item => item.Block).filter(Boolean))];

  const status = ['Passed', 'Failed', 'NotRun', 'Skipped', 'Error'];
  const severities = ['Critical', 'High', 'Medium', 'Low', 'Info', 'None'];
  const uniqueTags = [...new Set(testResults.Tests.flatMap((t) => t.Tag || []))];

  // Create a sortable header cell
  const SortableHeader = ({ column, label, className }) => {
    const isSorted = sortColumn === column;
    const icon = isSorted ? (sortDirection === "asc" ? <ArrowUpIcon className="h-4 w-4 inline" /> : <ArrowDownIcon className="h-4 w-4 inline" />) : null;
    return (
      <TableHeaderCell onClick={() => handleSort(column)} className={`cursor-pointer ${className}`}>
        {label} {icon}
      </TableHeaderCell>
    );
  };

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
          defaultValue={['Passed', 'Failed', 'Skipped','Error']}
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
            // These are used for the single dialog navigation logic
            const hasPrevious = index > 0;
            const hasNext = index < filteredSortedData.length - 1;

            return (<TableRow key={item.Index}>
              <TableCell className="text-xs text-zinc-600 dark:text-zinc-300 whitespace-nowrap max-w-[12rem]">
                <button
                  onClick={() => setSelectedItem(item)}
                  className="text-left tremor-Button-root font-medium outline-none text-sm text-zinc-500 dark:text-zinc-300 bg-transparent hover:text-zinc-700 dark:hover:text-zinc-100 truncate w-full"
                >
                  <span className="truncate tremor-Button-text text-tremor-default">{item.Id || item.Name}</span>
                </button>
              </TableCell>
              <TableCell className="whitespace-normal cursor-pointer hover:text-blue-600 hover:underline transition-colors">
                <button
                  onClick={() => setSelectedItem(item)}
                  className="text-left tremor-Button-root font-medium outline-none text-sm text-zinc-700 dark:text-zinc-200 bg-transparent hover:text-blue-600 dark:hover:text-blue-400 transition-colors"
                >
                  <span className="whitespace-normal tremor-Button-text text-tremor-default">{item.Title || (item.Name && item.Name.split(': ')[1])}</span>
                </button>
              </TableCell>
              <TableCell className="text-center">
                {item.Severity && item.Severity !== "" ? <SeverityBadge Severity={item.Severity} /> : ""}
              </TableCell>
              <TableCell className="text-center">
                <StatusLabel Result={item.Result} />
              </TableCell>
              <TableCell className="text-center">
                <div className="text-right">
                  <Button
                    size="xs"
                    variant="secondary"
                    color="gray"
                    tooltip="View details"
                    icon={WindowIcon}
                    onClick={() => setSelectedItem(item)}
                  />
                </div>
              </TableCell>
            </TableRow>
            );
          })}
        </TableBody>
      </Table>

      {/* Single dialog instance for all items - lazy loaded with Suspense */}
      {selectedItem && (
        <Suspense fallback={null}>
          <ResultInfoDialog
            Item={selectedItem}
            isOpen={Boolean(selectedItem)}
            onDialogClose={handleDialogClose}
            onNavigateNext={handleNavigateToNext}
            onNavigatePrevious={handleNavigateToPrevious}
          />
        </Suspense>
      )}
    </Card>
  );
}