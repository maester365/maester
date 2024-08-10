---
id: overview
title: CIS Microsoft 365 Foundations Benchmark Tests
sidebar_label: 🏢 CIS Overview
description: Implementation of CIS Microsoft 365 Foundations Benchmark Controls
---

# CIS Microsoft 365 Foundations Benchmark

## Overview

The tests in this section verifies that a Micorosft 365 tenant's configuration conforms to the [CIS Microsoft 365 Foundations Benchmark](https://www.cisecurity.org/benchmark/microsoft_365) recommendations (v3.1.0).

The CIS published material is shared for these tests as it aligns with their licensing of [CC BY-NC-SA 4.0](https://www.cisecurity.org/terms-and-conditions-table-of-contents).

## Connecting to Azure, Exchange and other services

In order to run all the CIS tests, you need to install and connect to the Azure and Exchange Online modules.

See the [Installation guide](/docs/installation#optional-modules-and-permissions) for more information.

## Tests

| Cmdlet Name | CIS Recommendation ID |
| - | - |
| Test-MtCisCloudAdmin | CIS 1.1.1: Ensure Administrative accounts are separate and cloud-only |