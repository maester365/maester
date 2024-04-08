---
sidebar_position: 1
title: Introduction
---

## What is Maester?

Maester is a PowerShell based test automation framework to help you stay in control of your Microsoft security configuration.

## Why Maester?

As business needs evolve, we often need to make changes to our tenant configuration. As employees come and go, new features are added, and existing features are updated. How do you ensure that a change in one area doesn't introduce a security vulnerability in another?

Take for example conditional access policies. You may have a policy that requires multi-factor authentication for a group of users. What if someone accidentally deletes the group or removes users from the group? **Your conditional access policy is now ineffective.**

Let's take another scenario that is fairly common. What if the original author of the conditional access policy leaves the company and someone else makes a change to the policy without understanding the implications?

## How does Maester help?

What if we could run a set of tests to ensure that our configuration is in compliance with our security policies?

That is exactly what Maester does.

:::info[Why Maester?]

Maester helps you monitor your Microsoft 365 tenant by running a set of tests to ensure your configuration is in compliance with your security policies.

:::

Maester provides a framework for you to bring DevOps practices to managing your Microsoft security configuration.

* Define your security policies as code and store them in a version control system.
* Continuously run tests that ensure your tenant configuration is complying with the defined policies.
* Found an incorrect configuration? Create a new test to ensure it doesn't happen again.
* Write tests using [Pester](https://pester.dev/), a popular testing framework for PowerShell.
* Use the built-in tests to quickly get started with monitoring your tenant.
* Write custom tests as you introduce new configuration and codify your intent for the configuration.
