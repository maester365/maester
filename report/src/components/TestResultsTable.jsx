import { useState, useEffect, useCallback, lazy, Suspense, useMemo } from "react";
import { Flex, Card, Table, TableRow, TableCell, TableHead, TableHeaderCell, TableBody, MultiSelect, MultiSelectItem, TextInput } from "@tremor/react";
import StatusLabel from "./StatusLabel";
import SeverityBadge from "./SeverityBadge";
import { ArrowDownIcon, ArrowUpIcon, MagnifyingGlassIcon } from "@heroicons/react/24/solid";
import { useLocation, useNavigate } from "react-router-dom";
import { getLinkedTestResultId, getPreferredScrollBehavior, getTestResultAnchorHash, getTestResultAnchorId } from "@/lib/reportLinks";

// Lazy load the ResultInfoSheet component
const ResultInfoSheet = lazy(() => import("./ResultInfoSheet"));
const defaultSelectedStatus = ['Passed', 'Failed', 'Skipped', 'Investigate', 'NotRun', 'Error'];

function testMatchesSearch(item, searchQuery) {
  if (!searchQuery) return true;

  const normalizedSearchQuery = searchQuery.toLowerCase();
  return (item.Id && item.Id.toLowerCase().includes(normalizedSearchQuery)) ||
    (item.Title && item.Title.toLowerCase().includes(normalizedSearchQuery));
}

export default function TestResultsTable(props) {
  const location = useLocation();
  const navigate = useNavigate();
  const [internalSelectedStatus, setInternalSelectedStatus] = useState(
    props.selectedStatus ?? defaultSelectedStatus
  );
  const selectedStatus = props.selectedStatus ?? internalSelectedStatus;
  const setSelectedStatus = props.onStatusChange ?? setInternalSelectedStatus;
  const [selectedBlock, setSelectedBlock] = useState([]);
  const [selectedTag, setSelectedTag] = useState([]);
  const [selectedSeverity, setSelectedSeverity] = useState([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [sortColumn, setSortColumn] = useState("Id");
  const [sortDirection, setSortDirection] = useState("asc");
  const [selectedItem, setSelectedItem] = useState(null);
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [linkedAnchorId, setLinkedAnchorId] = useState(null);
  const testResults = props.TestResults;
  const linkedTestResultId = useMemo(() => getLinkedTestResultId(location), [location]);
  const linkedTestResult = useMemo(() => {
    if (!linkedTestResultId) return null;
    return testResults.Tests.find((item) => getTestResultAnchorId(item) === linkedTestResultId) ?? null;
  }, [linkedTestResultId, testResults.Tests]);

  const handleOpenSheet = useCallback((item) => {
    setSelectedItem(item);
    setIsSheetOpen(true);
  }, []);

  const handleOpenLinkedSheet = useCallback((item) => {
    const anchorId = getTestResultAnchorId(item);

    if (anchorId) {
      navigate({
        pathname: "/",
        hash: getTestResultAnchorHash(anchorId),
      });
    }

    handleOpenSheet(item);
  }, [handleOpenSheet, navigate]);

  const handleCloseSheet = useCallback(() => {
    setIsSheetOpen(false);
    // Don't clear selectedItem immediately - let the animation complete
  }, []);

  const isStatusSelected = useCallback((item) => {
    const matchesSearch = testMatchesSearch(item, searchQuery);

    const matchesSeverity = selectedSeverity.length === 0 ||
      selectedSeverity.includes(item.Severity) ||
      (selectedSeverity.includes("None") && !item.Severity);

    return (selectedStatus.length === 0 || selectedStatus.includes(item.Result)) &&
      (selectedBlock.length === 0 || selectedBlock.includes(item.Block)) &&
      (selectedTag.length === 0 || (item.Tag || []).some(tag => selectedTag.includes(tag))) &&
      matchesSeverity &&
      matchesSearch;
  }, [searchQuery, selectedStatus, selectedBlock, selectedTag, selectedSeverity]);

  useEffect(() => {
    if (!linkedTestResult || props.isPrintView) return;

    const anchorId = getTestResultAnchorId(linkedTestResult);
    if (!anchorId) return;

    setLinkedAnchorId(anchorId);

    if (!location.hash) {
      navigate({
        pathname: "/",
        hash: getTestResultAnchorHash(anchorId),
      }, { replace: true });
    }

    if (linkedTestResult.Result && selectedStatus.length > 0 && !selectedStatus.includes(linkedTestResult.Result)) {
      setSelectedStatus([...selectedStatus, linkedTestResult.Result]);
    }

    if (selectedBlock.length > 0 && !selectedBlock.includes(linkedTestResult.Block)) {
      setSelectedBlock([]);
    }

    const linkedTags = linkedTestResult.Tag || [];
    if (selectedTag.length > 0 && !linkedTags.some((tag) => selectedTag.includes(tag))) {
      setSelectedTag([]);
    }

    const linkedSeverity = linkedTestResult.Severity || "None";
    if (selectedSeverity.length > 0 && !selectedSeverity.includes(linkedSeverity)) {
      setSelectedSeverity([]);
    }

    if (searchQuery && !testMatchesSearch(linkedTestResult, searchQuery)) {
      setSearchQuery("");
    }
  }, [
    linkedTestResult,
    location.hash,
    navigate,
    props.isPrintView,
    searchQuery,
    selectedBlock,
    selectedSeverity,
    selectedStatus,
    selectedTag,
    setSelectedStatus,
  ]);

  const handleSort = (column) => {
    if (sortColumn === column) {
      setSortDirection(sortDirection === "asc" ? "desc" : "asc");
    } else {
      setSortColumn(column);
      setSortDirection("asc");
    }
  };

  const getSortedData = useCallback((data) => {
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
        // Sort by status with a specific order: Failed, Investigate, Passed, Skipped, NotRun
        const statusOrder = { "Error": 6, "Failed": 5, "Investigate": 4, "Passed": 3, "Skipped": 2, "NotRun": 1 };
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
  }, [sortColumn, sortDirection]);

  // Memoize the filtered and sorted data to prevent unnecessary recalculations
  // Memoize the filtered and sorted data to prevent unnecessary recalculations
  const filteredSortedData = useMemo(() => {
    const filtered = testResults.Tests.filter((item) => isStatusSelected(item));
    return getSortedData(filtered);
  }, [testResults.Tests, isStatusSelected, getSortedData]);

  // Store the current index in filtered data as state to avoid findIndex issues with non-unique Index values
  const [currentFilteredIndex, setCurrentFilteredIndex] = useState(-1);

  // Update currentFilteredIndex when selectedItem changes from external source (clicking on row)
  useEffect(() => {
    if (selectedItem && filteredSortedData.length > 0) {
      // Find by both Index and Id to ensure uniqueness
      const idx = filteredSortedData.findIndex(
        item => item.Index === selectedItem.Index && item.Id === selectedItem.Id
      );
      if (idx !== -1 && idx !== currentFilteredIndex) {
        setCurrentFilteredIndex(idx);
      }
    }
  }, [selectedItem, filteredSortedData]);

  useEffect(() => {
    if (!linkedAnchorId || !linkedTestResult || props.isPrintView) return;

    const linkedResultIsVisible = filteredSortedData.some(
      (item) => getTestResultAnchorId(item) === linkedAnchorId
    );

    if (!linkedResultIsVisible) return;

    // Consume the anchor immediately so that subsequent user-driven filter or
    // sort changes do not re-scroll and re-open the flyout.
    setLinkedAnchorId(null);

    window.requestAnimationFrame(() => {
      document.getElementById(linkedAnchorId)?.scrollIntoView({
        behavior: getPreferredScrollBehavior(),
        block: "center",
      });
      handleOpenSheet(linkedTestResult);
    });
  }, [filteredSortedData, handleOpenSheet, linkedAnchorId, linkedTestResult, props.isPrintView]);

  const handleNavigateToNext = useCallback(() => {
    if (currentFilteredIndex === -1 || currentFilteredIndex >= filteredSortedData.length - 1) {
      return;
    }
    const nextIndex = currentFilteredIndex + 1;
    const nextItem = filteredSortedData[nextIndex];
    setCurrentFilteredIndex(nextIndex);
    setSelectedItem(nextItem);
  }, [currentFilteredIndex, filteredSortedData]);

  const handleNavigateToPrevious = useCallback(() => {
    if (currentFilteredIndex <= 0) {
      return;
    }
    const prevIndex = currentFilteredIndex - 1;
    const prevItem = filteredSortedData[prevIndex];
    setCurrentFilteredIndex(prevIndex);
    setSelectedItem(prevItem);
  }, [currentFilteredIndex, filteredSortedData]);

  const uniqueBlocks = [...new Set(testResults.Tests.map(item => item.Block).filter(Boolean))];

  const status = ['Passed', 'Failed', 'Investigate', 'Skipped', 'NotRun', 'Error'];
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
      {!props.isPrintView && (
        <>
          <Flex justifyContent="between" className="gap-2 mb-2">
            <TextInput
              icon={MagnifyingGlassIcon}
              placeholder="Search by ID or Title..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-1/3"
            />

            <MultiSelect
              value={selectedSeverity}
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
              value={selectedStatus}
              onValueChange={setSelectedStatus}
              placeholder="Status"
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
              value={selectedBlock}
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
              value={selectedTag}
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
        </>
      )}

      <Table className="mt-2 w-full">
        <TableHead>
          <TableRow>
            <SortableHeader column="Id" label="ID" className="text-left w-auto whitespace-nowrap" />
            <SortableHeader column="Title" label="Title" className="text-left w-full" />
            <SortableHeader column="Severity" label="Severity" className="text-center whitespace-nowrap" />
            <SortableHeader column="Status" label="Status" className="text-center whitespace-nowrap" />
          </TableRow>
        </TableHead>

        <TableBody>
          {filteredSortedData.map((item, index) => {
            // These are used for the single dialog navigation logic
            const hasPrevious = index > 0;
            const hasNext = index < filteredSortedData.length - 1;

            return (<TableRow
              key={`${item.Index}-${item.Id || index}`}
              id={getTestResultAnchorId(item)}
              className="hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors cursor-pointer scroll-mt-4"
              onClick={() => !props.isPrintView && handleOpenLinkedSheet(item)}
            >
              <TableCell className="text-xs text-zinc-600 dark:text-zinc-300 whitespace-nowrap max-w-[12rem]">
                {props.isPrintView ? (
                  <a href={`#${item.Id}`} className="text-left font-medium outline-none text-sm text-zinc-500 dark:text-zinc-300 bg-transparent hover:text-blue-600 dark:hover:text-blue-400 transition-colors truncate w-full block">
                    <span className="truncate text-tremor-default">{item.Id || item.Name}</span>
                  </a>
                ) : (
                  <span className="truncate text-tremor-default">{item.Id || item.Name}</span>
                )}
              </TableCell>
              <TableCell className="whitespace-normal">
                {props.isPrintView ? (
                  <a href={`#${item.Id}`} className="text-left font-medium outline-none text-sm text-zinc-700 dark:text-zinc-200 bg-transparent hover:text-blue-600 dark:hover:text-blue-400 transition-colors block">
                    <span className="whitespace-normal text-tremor-default">{item.Title || (item.Name && item.Name.split(': ')[1])}</span>
                  </a>
                ) : (
                  <span className="whitespace-normal text-tremor-default text-zinc-700 dark:text-zinc-200">{item.Title || (item.Name && item.Name.split(': ')[1])}</span>
                )}
              </TableCell>
              <TableCell className="text-center">
                {item.Severity && item.Severity !== "" ? <SeverityBadge Severity={item.Severity} /> : ""}
              </TableCell>
              <TableCell className="text-center">
                <StatusLabel Result={item.Result} />
              </TableCell>
            </TableRow>
            );
          })}
        </TableBody>
      </Table>

      {/* Single sheet instance for all items - lazy loaded with Suspense */}
      <Suspense fallback={null}>
        <ResultInfoSheet
          Item={selectedItem}
          isOpen={isSheetOpen}
          onClose={handleCloseSheet}
          onNavigateNext={currentFilteredIndex < filteredSortedData.length - 1 ? handleNavigateToNext : undefined}
          onNavigatePrevious={currentFilteredIndex > 0 ? handleNavigateToPrevious : undefined}
          currentIndex={currentFilteredIndex !== -1 ? currentFilteredIndex + 1 : undefined}
          totalCount={filteredSortedData.length}
        />
      </Suspense>
    </Card>
  );
}
