import React, { useCallback } from "react";
import { Card, Button, Title, Text, Flex, Divider, Grid } from "@/components/ui/report";
import { ArrowTopRightOnSquareIcon } from "@heroicons/react/24/outline";
import StatusLabel from "./StatusLabel";
import StatusLabelSm from "./StatusLabelSm";
import SeverityBadge from "./SeverityBadge";
import { Markdown } from '@/components/Markdown'
import { useTenant } from "@/context/TenantContext";
import ReportAttachmentButtons from "@/components/ReportAttachmentButtons";
import { getTestAttachments } from "@/lib/reportAttachments";
import { attackTechniquesLabel, benchmarkLabel, controlsLabel, getAttackTechniques, getBenchmarkText, getControls, getTestAttributeFields, hasTestAttributes } from "@/lib/testAttributes";

export default function ResultInfo({ Item, isPrintView }) {
  const { selectedTenant } = useTenant();
  const openInNewTab = useCallback((url) => {
    window.open(url, "_blank", "noreferrer");
  }, []);

  // Typed attributes of Maester 3.0, with their display names from the result's Taxonomy. Each card
  // renders only when the row has the field, so results from Maester 2.x and Pester-format tests look as before.
  const taxonomy = selectedTenant.Taxonomy;
  const attributeFields = getTestAttributeFields(taxonomy, Item);
  const attackTechniques = getAttackTechniques(taxonomy, Item);
  const benchmark = getBenchmarkText(Item);
  const controls = getControls(Item);
  const hasAttributes = hasTestAttributes(Item);
  // The tests that ship with Maester no longer carry tags, so a test with attributes shows Tags only when it has some.
  const showTags = !hasAttributes || (Item.Tag && Item.Tag.length > 0);
  // In the result sheet the single values sit two to a row and the lists take a whole row.
  const listCardClassName = isPrintView ? undefined : "sm:col-span-2";

  const attributeCards = (
    <>
      {attributeFields.map(({ label, value }) => (
        <Card key={label}>
          <Title>{label}</Title>
          <Text>{value}</Text>
        </Card>
      ))}
      {attackTechniques.length > 0 && (
        <Card className={listCardClassName}>
          <Title>{attackTechniquesLabel}</Title>
          <Flex justifyContent="start" className="flex-wrap">
            {attackTechniques.map((technique) => (
              <Text key={technique.id} className="mr-3">
                <a href={technique.url} target="_blank" rel="noopener noreferrer" className="text-blue-500 hover:text-blue-700 hover:underline dark:hover:text-blue-400">
                  {technique.id} {technique.name}
                </a>
              </Text>
            ))}
          </Flex>
        </Card>
      )}
      {benchmark && (
        <Card className={listCardClassName}>
          <Title>{benchmarkLabel}</Title>
          <Text>{benchmark}</Text>
        </Card>
      )}
      {controls.length > 0 && (
        <Card className={listCardClassName}>
          <Title>{controlsLabel}</Title>
          <Flex justifyContent="start" className="flex-wrap">
            {controls.map((control) => (
              <Text key={control} className="mr-3">{control}</Text>
            ))}
          </Flex>
        </Card>
      )}
    </>
  );

  function getTestResult() {
    if (Item.ResultDetail) {
      return Item.ResultDetail.TestResult;
    }
    else if (Item.ResultDetail) {
      return Item.ResultDetail;
    }
    else {
      if (Item.Result === "Passed") {
        return "Tested successfully.";
      }
      if (Item.Result === "Failed") {
        return "Test failed.";
      }
      if (Item.Result === "Skipped") {
        return "Test skipped.";
      }
      if (Item.Result === "Investigate") {
        return "Test requires investigation.";
      }
    }
    return "";
  }

  function getTestDetails() {
    if (Item.ResultDetail) {
      return Item.ResultDetail.TestDescription;
    }
    else {
      //trim the scriptblock whitespace at the beginning and end
      if (Item.ScriptBlock) {
        return Item.ScriptBlock.replace(/^\s+|\s+$/g, '');
      }
    }
    return "";
  }

  //Set bgcolor based on result
  function getBgColor(result) {
    if (result === "Passed") {
      return "bg-green-100 dark:bg-green-900/40";
    }
    if (result === "Failed") {
      return "bg-red-100 dark:bg-red-900/30";
    }
    if (result === "Skipped") {
      return "bg-yellow-100";
    }
    if (result === "Investigate") {
      return "bg-purple-100 dark:bg-purple-900/30";
    }
    return "bg-gray-100";
  }

  return (
    <div className="grid grid-cols-1" id={isPrintView ? Item.Id : undefined}>
      <div className="text-right flex justify-end space-x-2 items-center">
        {Item.Severity && (
          <div title="Severity" className="flex items-center">
            <SeverityBadge Severity={Item.Severity} />
          </div>
        )}
        <StatusLabel Result={Item.Result} />
      </div>
      <Title>{Item.Name}</Title>
      {!isPrintView && Item.HelpUrl &&
        <div className="text-left mt-2">
          <Button icon={ArrowTopRightOnSquareIcon} variant="light" onClick={() => openInNewTab(Item.HelpUrl)}>
            Learn more @ {new URL(Item.HelpUrl).hostname}
          </Button>
        </div>
      }
      {!isPrintView && <ReportAttachmentButtons attachments={getTestAttachments(selectedTenant, Item)} className="mt-3 flex flex-wrap gap-2" />}
      <Divider></Divider>

      <Card className={"break-words " + getBgColor(Item.Result)}>
        <div className="flex flex-row items-center">
          <Title>Test result</Title><StatusLabelSm Result={Item.Result} />
        </div>
        <Markdown className="prose max-w-fit dark:prose-invert">{getTestResult()}</Markdown>
      </Card>
      <Card className="mt-4 bg-slate-50">
        <Title>Test details</Title>
        <Markdown className="prose max-w-fit dark:prose-invert">{getTestDetails()}</Markdown>
      </Card>

      {isPrintView ? (
        <div className="mt-4 grid grid-cols-2 gap-4">
          <Card>
            <Title>Category</Title>
            <Text>{Item.Block}</Text>
          </Card>
          {attributeCards}
          {showTags && (
            <Card>
              <Title>Tags</Title>
              <Flex justifyContent="start" className="flex-wrap">
                {Item.Tag && Item.Tag.map((item) => (
                  <Text key={item} className="mr-3">{item}</Text>
                ))}
              </Flex>
            </Card>
          )}
        </div>
      ) : (
        <>
          <Card className="mt-4">
            <Title>Category</Title>
            <Text>{Item.Block}</Text>
          </Card>
          {hasAttributes && (
            <Grid numItemsSm={2} className="mt-4 gap-4">
              {attributeCards}
            </Grid>
          )}
          {showTags && (
            <Card className="mt-4">
              <Title>Tags</Title>
              <Flex justifyContent="start">
                {Item.Tag && Item.Tag.map((item) => (
                  <Text key={item} className="mr-3">{item}</Text>
                ))}
              </Flex>
            </Card>
          )}
          <Card className="mt-4">
            <Title>Source</Title>
            <Text>{Item.ScriptBlockFile}</Text>
          </Card>
        </>
      )}
    </div>
  );
}
