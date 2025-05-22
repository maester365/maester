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

      if (sortColumn === "Id") {
        valueA = a.Id || "";
        valueB = b.Id || "";
      } else if (sortColumn === "Title") {
        valueA = a.Title || "";
        valueB = b.Title || "";
      } else if (sortColumn === "Severity") {
        const severityOrder = { "Critical": 5, "High": 4, "Medium": 3, "Low": 2, "Info": 1, "": 0 };
        valueA = a.Severity ? severityOrder[a.Severity] : 0;
        valueB = b.Severity ? severityOrder[b.Severity] : 0;
      } else if (sortColumn === "Status") {
        const statusOrder = { "Failed": 4, "Passed": 3, "Skipped": 2, "NotRun": 1 };
        valueA = statusOrder[a.Result] || 0;
        valueB = statusOrder[b.Result] || 0;
      }

      if (sortDirection === "asc") {
        return valueA > valueB ? 1 : valueA < valueB ? -1 : 0;
      } else {
        return valueA < valueB ? 1 : valueA > valueB ? -1 : 0;
      }
    });
  };

  const getFilteredSortedData = () => {
    return getSortedData(testResults.Tests.filter((item) => isStatusSelected(item)));
  };

  const filteredSortedData = getFilteredSortedData();

  const handleDialogOpen = (dialogId) => {
    setActiveDialog(dialogId);
  };

  const handleDialogClose = () => {
    setActiveDialog(null);
  };

  const dialogRefs = useRef({});

  useEffect(() => {
    const handleKeyDown = (event) => {
      if (!activeDialog) return;

      const currentItemIndex = activeDialog ? parseInt(activeDialog.split('-')[1]) : null;
      if (currentItemIndex === null) return;

      const currentDialogIndexInFiltered = filteredSortedData.findIndex(item => item.Index === currentItemIndex);
      if (currentDialogIndexInFiltered === -1) return;

      if (event.key === "ArrowRight") {
        const nextIndex = currentDialogIndexInFiltered + 1;
        if (nextIndex < filteredSortedData.length) {
          setActiveDialog(`dialog-${filteredSortedData[nextIndex].Index}-button`);
        }
      } else if (event.key === "ArrowLeft") {
        const prevIndex = currentDialogIndexInFiltered - 1;
        if (prevIndex >= 0) {
          setActiveDialog(`dialog-${filteredSortedData[prevIndex].Index}-button`);
        }
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [activeDialog, filteredSortedData]);

  const handleNavigateToNext = () => {
    const currentItemIndex = activeDialog ? parseInt(activeDialog.split('-')[1]) : null;
    if (currentItemIndex === null) return;
    const currentIndexInFiltered = filteredSortedData.findIndex(item => item.Index === currentItemIndex);
    if (currentIndexInFiltered !== -1 && currentIndexInFiltered < filteredSortedData.length - 1) {
      setActiveDialog(`dialog-${filteredSortedData[currentIndexInFiltered + 1].Index}-button`);
    }
  };

  const handleNavigateToPrevious = () => {
    const currentItemIndex = activeDialog ? parseInt(activeDialog.split('-')[1]) : null;
    if (currentItemIndex === null) return;
    const currentIndexInFiltered = filteredSortedData.findIndex(item => item.Index === currentItemIndex);
    if (currentIndexInFiltered > 0) {
      setActiveDialog(`dialog-${filteredSortedData[currentIndexInFiltered - 1].Index}-button`);
    }
  };

  const uniqueBlocks = [...new Set(testResults.Tests.map(item => item.Block).filter(Boolean))];

  const status = ['Passed', 'Failed', 'NotRun', 'Skipped'];
  const severities = ['Critical', 'High', 'Medium', 'Low', 'Info', 'None'];
  const uniqueTags = [...new Set(testResults.Tests.flatMap((t) => t.Tag || []))];

  const SortableTableHeaderCell = ({ column, label, className }) => {
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
            <SortableTableHeaderCell column="Id" label="ID" className="text-left w-auto whitespace-nowrap" />
            <SortableTableHeaderCell column="Title" label="Title" className="text-left w-full" />
            <SortableTableHeaderCell column="Severity" label="Severity" className="text-center whitespace-nowrap" />
            <SortableTableHeaderCell column="Status" label="Status" className="text-center whitespace-nowrap" />
            <TableHeaderCell className="text-center whitespace-nowrap">Info</TableHeaderCell>
          </TableRow>
        </TableHead>

        <TableBody>
          {filteredSortedData.map((item, index) => {
            const hasPrevious = index > 0;
            const hasNext = index < filteredSortedData.length - 1;
            const dialogIdForId = `dialog-${item.Index}-id`;
            const dialogIdForTitle = `dialog-${item.Index}-title`;
            const dialogIdForButton = `dialog-${item.Index}-button`;

            return (
              <TableRow key={item.Index}>
                <TableCell className="font-mono text-xs text-gray-600 dark:text-gray-400 whitespace-nowrap">
                  <ResultInfoDialog
                    Title={false}
                    Item={item}
                    DisplayText={item.Id || item.Name}
                    onNavigateNext={hasNext ? handleNavigateToNext : null}
                    onNavigatePrevious={hasPrevious ? handleNavigateToPrevious : null}
                    onDialogOpen={() => handleDialogOpen(dialogIdForId)}
                    onDialogClose={handleDialogClose}
                    isOpen={activeDialog === dialogIdForId}
                    dialogId={dialogIdForId}
                  />
                </TableCell>
                <TableCell className="whitespace-normal cursor-pointer hover:text-blue-600 hover:underline transition-colors">
                  <ResultInfoDialog
                    Title={false}
                    Item={item}
                    DisplayText={item.Title || (item.Name && item.Name.split(': ')[1])}
                    onNavigateNext={hasNext ? handleNavigateToNext : null}
                    onNavigatePrevious={hasPrevious ? handleNavigateToPrevious : null}
                    onDialogOpen={() => handleDialogOpen(dialogIdForTitle)}
                    onDialogClose={handleDialogClose}
                    isOpen={activeDialog === dialogIdForTitle}
                    dialogId={dialogIdForTitle}
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
                    onDialogOpen={() => handleDialogOpen(dialogIdForButton)}
                    onDialogClose={handleDialogClose}
                    isOpen={activeDialog === dialogIdForButton}
                    dialogId={dialogIdForButton}
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