---
title: Privacy Policy
---

# Privacy Policy — Catalogue of Life Mobile

_Effective date: 2026-05-13_

This iPhone app ("Catalogue of Life", "the app") is published by the Catalogue of Life Foundation. We take privacy seriously and this policy explains exactly what data is and isn't handled by the app.

## Summary

- **No accounts.** You don't sign in. The app has no user accounts of any kind.
- **No analytics, no tracking, no advertising, no third-party SDKs.** The app contains no analytics frameworks, no crash reporters, no advertising IDs, and no other tracking technologies.
- **No personal data is collected automatically.** The app does not read your contacts, calendar, photo library, location, microphone, camera, health data, motion, or any other personal sensor.
- **Email address and feedback messages are sent only when you explicitly submit feedback.** They become a public GitHub issue on the Catalogue of Life data repository.

## Data the app stores on your device

The following preferences and bookmarks are stored locally on your device (in `UserDefaults` and the app's local SwiftData database). They never leave your device:

- The dataset release you've selected
- Your preferred common-name display language
- Your chosen GBIF map tile style
- The email address you optionally enter for the feedback feature
- A list of taxa you've bookmarked (favorites)
- A list of taxa you've recently viewed (capped at 50)

You can clear all of this by deleting and reinstalling the app.

## Data the app sends over the network

The app fetches publicly-available taxonomic data over HTTPS from the following services:

- **ChecklistBank API** — `api.checklistbank.org` (operated by the Catalogue of Life Foundation / GBIF) for dataset, taxon, search, and metrics endpoints.
- **GBIF API** — `api.gbif.org` (operated by GBIF, the Global Biodiversity Information Facility) for occurrence statistics, occurrence images, and density map tiles.
- **Third-party image hosts** linked from GBIF occurrence records — typically including `inaturalist-open-data.s3.amazonaws.com` (iNaturalist), `images.phylopic.org`, and other contributing sources. When the app loads an image, the host of that image observes the request like any standard HTTP image load.

These requests are anonymous (no API key, no user identifier). They contain only the standard headers your iOS networking stack sends (e.g. an iOS user-agent string and your IP address, which is observable by any HTTPS server you contact).

## When you submit feedback

The app has a "Report data issue" feature on each taxon detail page. When you tap it and submit:

1. The app sends the message you typed and the email address you entered in About → Preferences to `api.checklistbank.org`.
2. ChecklistBank publishes the message and email as a **public GitHub issue** at `https://github.com/CatalogueOfLife/data/issues`. Anyone with internet access can read it.
3. Curators may reply to the email address you provided to follow up on the data issue.

Do not include sensitive personal information in feedback messages — they become public.

If you have not entered an email address in preferences, the feedback button is disabled and no data is sent.

## Children

The app does not knowingly collect personal data from anyone, including children under 13. The only data ever leaving your device is what you explicitly type into the feedback form and submit.

## Your rights

- **To delete everything**: uninstall the app. All local data (preferences, bookmarks, recents) is removed by iOS.
- **To redact a feedback issue**: contact <support@catalogueoflife.org> with the GitHub issue URL. The Catalogue of Life Foundation maintains the underlying issue tracker.

## Changes to this policy

We will update this page when the practices change. The "Effective date" above reflects the latest revision. Substantial changes will also be summarized in the app's About screen.

## Contact

Questions about this privacy policy:

- Email: <support@catalogueoflife.org>
- Postal: Catalogue of Life Foundation, Amsterdam, Netherlands
