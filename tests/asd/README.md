# ASD Essential Eight and ISM

Checks that verify a Microsoft 365 tenant against the
[Essential Eight maturity model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
and the [Information security manual](https://www.cyber.gov.au/ism) (ISM), both published by the Australian Signals
Directorate (ASD). They are also known as the ACSC Essential Eight and the ACSC ISM; the Australian Cyber Security
Centre (ACSC) is part of ASD. ASD maps each requirement of the maturity model to an ISM control.

## Layout

- `suite.json` declares the suite (`ASD`) and its two frameworks, `essential-eight` and `ism`.
- `frameworks/essential-eight.json` and `frameworks/ism.json` are the catalogues of the two frameworks. They are
  generated from the ISM OSCAL release by `build/asd/Update-AsdFramework.ps1`; do not edit them by hand.
- `<service>/Test.ASD.<ISM control>.ps1` and `.md` are the checks, one folder per product (`entra/`, `intune/`).

## IDs and mapping

ASD publishes the maturity model with a
[mapping of every requirement to one ISM control](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model-ism-mapping)
(October 2024 edition), and the ISM OSCAL release ships that mapping as Essential Eight baseline profiles, so a
check is named after the control it implements: `ASD.ISM-1504` implements ISM-1504. Its attribute names the
requirement in the Essential Eight framework first, `Control = 'essential-eight:ISM-1504'`, and the framework file
relates that requirement to `ism:ISM-1504`, which Maester adds to the result. A check for a control that the
maturity model does not use names the ISM directly, `Control = 'ism:ISM-0421'`.

The `Benchmark` of a result carries the facts of the requirement: the maturity level that first requires it
(`Level`: `ML1`, `ML2` or `ML3`) and the mitigation strategy or strategies (`Strategy`) from the Essential Eight framework, or the
guideline, section and classification applicability from the ISM.

A passing check is evidence for the control it names. It is not an assessment: an Essential Eight assessment also
covers endpoints, servers and processes that a tenant check cannot see.

## Checks that another suite already has

Where ASD asks for what a CIS, CISA or Maester test already checks, the ASD check is a shim: it declares its own
ID, title and `Control` and returns the result of that test (`ASD.ISM-1504` returns `Test-MtCisMfaForEveryUser`).
Where ASD names a different value, the shim passes it as a parameter (`ASD.ISM-1403` runs the CIS lockout check
with a maximum of 5). A check has logic of its own only where ASD's own sources (the ISM, the Essential Eight
assessment process guide and the ASD Blueprint for Secure Cloud) ask for something no other test checks. See
[Tests that another suite already has](https://maester.dev/docs/next/writing-tests#tests-that-another-suite-already-has).
