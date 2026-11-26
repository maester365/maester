# Maester world tour events

Each file here is one talk, workshop, meetup, webinar or livestream about Maester. They are listed at
[maester.dev/events](https://maester.dev/events), in the calendar feed `maester.dev/events.ics` and in the
"Upcoming events" section of the maester.news newsletter (`maester.dev/events/newsletter.md`).

## Adding an event

Most people use the [event form](https://github.com/maester365/maester/issues/new?template=3-event.yml). When a
maintainer adds the `event: approved` label, the **Event submissions** workflow turns the issue into a file here
and opens a pull request for it.

You can also open a pull request yourself. Name the file `<start date>-<short-name>.yml`, for example
`2027-03-16-maester-at-mms.yml`:

```yaml
title: Testing Entra with Maester          # the session's title
event: MMS 2027                            # the conference, meetup or channel
start: 2027-03-16                          # YYYY-MM-DD
end: 2027-03-19                            # optional, for a conference that runs several days
time: "14:00 CET"                          # optional, the session's own time and time zone
format: talk                               # talk, workshop, meetup, webinar, livestream or podcast
attendance: in-person                      # in-person, online or hybrid
city: Minneapolis, MN                      # leave out for an online-only event
country: United States
language: English                          # optional, defaults to English
speakers:
  - name: Ada Lovelace
    github: ada                            # optional, shows their GitHub avatar
url: https://mms.example/session/123       # the event or registration page (https)
recording: https://www.youtube.com/watch?v=…  # optional, add it after the event
slides: https://…                          # optional
summary: One or two sentences on what people will learn.
```

The build checks every file against the schema in `website/src/content.config.ts`.
