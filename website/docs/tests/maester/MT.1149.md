---
title: MT.1149 - Ensure ASR Rules are configured correctly
description: Checks Intune Endpoint Security Attack Surface Reduction (ASR) policies for rules configured in Block or Audit mode.
slug: /tests/MT.1149
sidebar_class_name: hidden
---

# Ensure ASR Rules are configured correctly

## Description

Checks Intune Endpoint Security Attack Surface Reduction (ASR) policies for rules configured in **Block** or **Audit** mode.

ASR rules reduce the attack surface of applications by preventing behaviors commonly abused by malware — such as Office macros spawning child processes, credential theft from LSASS, execution of obfuscated scripts, and email-borne threats.

Each ASR rule can operate in one of four modes:

- **Block** — Actively prevents the behavior (recommended for production after testing).
- **Audit** — Logs the event without blocking (recommended for initial rollout).
- **Warn** — Warns the user before allowing the behavior to proceed.
- **Disabled** — Rule is not active.

The test passes if at least one ASR policy has at least one rule configured in **Block** or **Audit** mode. **Warn** is a supported ASR rule state but does not satisfy this control's pass criteria. Policies with all rules in **Audit** mode trigger an informational note recommending a transition to **Block** mode.

## How to fix

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Endpoint security** > **Attack surface reduction**.
3. Click **+ Create policy**.
4. Set **Platform** to **Windows 10 and later** and **Profile** to **Attack Surface Reduction Rules**.
5. Configure individual ASR rules, starting in **Audit** mode for all rules:
   - Block credential stealing from Windows LSASS
   - Block all Office applications from creating child processes
   - Block Win32 API calls from Office macros
   - Block execution of potentially obfuscated scripts
   - Block executable content from email client and webmail
   - Block JavaScript or VBScript from launching downloaded executable content
   - Block process creations originating from PSExec and WMI commands
   - Block untrusted and unsigned processes that run from USB
   - Block persistence through WMI event subscription
   - Use advanced protection against ransomware
6. Assign the policy to your Windows device groups and click **Create**.
7. Monitor audit events in **Microsoft Defender for Endpoint** > **Reports** > **Attack surface reduction rules** for 2–4 weeks before transitioning rules to **Block** mode.

## Learn more

- [Attack surface reduction rules reference](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/attack-surface-reduction-rules-reference)
- [Enable ASR rules in Intune](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/enable-attack-surface-reduction)
- [ASR rules deployment guide](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/attack-surface-reduction-rules-deployment)
