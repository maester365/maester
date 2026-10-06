import assert from "node:assert/strict";
import test from "node:test";
import { tagGroupFor } from "./tag-groups.mjs";

test("classifies standalone CIS levels without capturing overlapping prefixes", () => {
  const cases = [
    ["L1", "CIS"],
    ["L2", "CIS"],
    ["CIS.L1", "CIS"],
    ["CISA.L1", "CISA"],
    ["EIDSCA.L1", "EIDSCA"],
    ["ORCA.L2", "ORCA"],
    ["ControlL1", "Ungrouped"],
    ["Level2", "Ungrouped"],
  ];

  for (const [tag, expectedGroup] of cases) {
    assert.equal(tagGroupFor(tag), expectedGroup, tag);
  }
});

test("classifies Azure DevOps and Active Directory tags", () => {
  const cases = [
    ["AZDO", "Azure DevOps"],
    ["AZDO.1000", "Azure DevOps"],
    ["AD", "Active Directory"],
    ["AD.User", "Active Directory"],
    ["AD-USER-07", "Active Directory"],
    ["ADMX", "Ungrouped"],
    ["MT.1060", "Maester"],
    ["MT1060", "Maester"],
    ["MTX", "Ungrouped"],
  ];

  for (const [tag, expectedGroup] of cases) {
    assert.equal(tagGroupFor(tag), expectedGroup, tag);
  }
});
