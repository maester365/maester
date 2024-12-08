---
title: Maester alerts → Microsoft Teams
description: Find out how you can send your Maester daily results to a Teams channel
slug: maester-teams-alert
authors: merill
tags: [teams, alerts]
hide_table_of_contents: false
image: ./img/maester-teams-alert.png
date: 2024-12-08
---

The command `Send-MtTeamsMessage` to post your Maester results to a Teams channel has been there for a while but we did forget to write the documentation for it. This is now fixed!

![Maester - Microsoft Teams Alerts](./img/maester-teams-alert.png)

<!-- truncate -->

You can find the steps in the [Teams Alerts](/docs/monitoring/teams) page.

A huge shout out to [Guido Baijense](https://blog.pentiago365.nl/) for contributing the code for this feature!

This is what I really ❤️ about the Maester community. 🙏

Next up, we need to add this as configurable option to the GitHub Action. This way you can easily enable it for your workflows without having to write scripts. If you are interested in helping out with this, check out the [action.yml](https://github.com/maester365/maester/blob/main/action.yml) that needs to be updated.

Reach out on the Maester channel on our [Discord server](https://discord.com/channels/1125617152368594976/1226351860693205062) if you have any questions or feedback.
