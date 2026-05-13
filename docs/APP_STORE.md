---
title: App Store Submission Metadata
---

# App Store Submission Metadata

Reference document for Apple App Store Connect submission of **Catalogue of Life Mobile**.

## Basic information

| Field | Value |
|---|---|
| App name | Catalogue of Life |
| Subtitle (30 chars) | The global checklist of life |
| Bundle ID | `org.catalogueoflife.mobile` |
| Primary category | Reference |
| Secondary category | Education |
| Age rating | 4+ (no objectionable content) |
| Supported devices | iPhone (iOS 18+) |
| Languages | English |
| Pricing | Free |
| Publisher | Catalogue of Life Foundation |
| Support URL | https://mdoering.github.io/col-mobile/ |
| Marketing URL | https://www.catalogueoflife.org |
| Privacy policy URL | https://mdoering.github.io/col-mobile/PRIVACY.html |

## Description (4000 char limit)

> Catalogue of Life is the most comprehensive and authoritative global index of species. It combines hundreds of taxonomic sources into a single unified checklist of every named living and recently extinct organism — 2.5 million+ accepted species, 7 million+ scientific names.
>
> This app brings the full Catalogue of Life to your iPhone.
>
> WHAT YOU CAN DO
> • Search scientific and vernacular names across the entire catalogue
> • Browse the tree of life from kingdom down to species and below
> • Drill into a taxon to see classification, synonymy, common names, source, type material, etymology, and remarks
> • Bookmark favorites and revisit recently viewed taxa
> • See worldwide occurrence maps powered by GBIF
> • Browse occurrence images contributed by iNaturalist and other observers
> • Submit data corrections — feedback becomes a public GitHub issue read by curators
> • Switch between the latest release and any of the past five annual COL releases
> • Filter searches by rank, status, and taxonomic group
>
> WHO IT'S FOR
> Biologists, taxonomists, naturalists, students, citizen scientists, museum staff — anyone who needs an authoritative answer to "what's the accepted name of this organism, and what's known about it?"
>
> ABOUT CATALOGUE OF LIFE
> The Catalogue of Life is published by the Catalogue of Life Foundation in Amsterdam and is the taxonomic backbone of GBIF, the Encyclopedia of Life, and many other biodiversity infrastructures. Data is contributed by 200+ specialist databases worldwide and curated by a global community of taxonomic experts.
>
> NO ACCOUNTS, NO ADS, NO TRACKING
> No sign-in. No advertising. No analytics. No third-party SDKs. The app fetches public taxonomic data over HTTPS and stores your bookmarks and preferences locally on your device. See our privacy policy for details.

## Keywords (100 char limit, comma-separated)

```
taxonomy, species, biology, biodiversity, checklist, scientific names, GBIF, nature, naturalist, fauna, flora
```

## Promotional text (170 char limit, updateable without re-submit)

> Search 2.5 million species in the world's most comprehensive taxonomic checklist. Maps, images, and feedback to curators included.

## What's new in this version

Initial release.

## Review notes (private — for Apple reviewers)

This app accesses two public scientific APIs that do not require authentication:

- `api.checklistbank.org` — operated by the Catalogue of Life Foundation
- `api.gbif.org` — operated by GBIF (Global Biodiversity Information Facility)

A "Report data issue" feature lets the user submit a feedback message that becomes a public GitHub issue on github.com/CatalogueOfLife/data. The feature is gated behind the user voluntarily entering their email address in About → Preferences. No account or sign-in is required, and no data is collected automatically.

## App Privacy nutrition label (App Store Connect → App Privacy)

Apple's "App Privacy" disclosures should be answered as follows. **The app does not collect data automatically.** All data the app sends to its servers is initiated explicitly by the user (specifically: submitting feedback).

### Data Types Collected — answer "Yes" only to the types below

| Category | Data Type | Used for | Linked to user? | Tracking? |
|---|---|---|---|---|
| **Contact Info** | **Email Address** | App Functionality | Not Linked to User | No |
| **User Content** | **Other User Content** (feedback message text) | App Functionality | Not Linked to User | No |

Notes for each field:

**Email Address** — Collected only when the user explicitly enters an email in About → Preferences and submits the Report Data Issue feature. The email is sent with the feedback so a curator can follow up. It is published as part of the public GitHub issue created on github.com/CatalogueOfLife/data. The app does not link the email to any in-app identifier and has no user account system.

**Other User Content** — The text of the feedback message that the user types and submits. Published as a public GitHub issue.

### Data Types NOT Collected — answer "No" to all of the following

- Contact Info: Name, Phone Number, Physical Address, Other Contact Info
- Health & Fitness: any
- Financial Info: any
- Location: any (the app shows a map but does NOT read the user's location)
- Sensitive Info: any
- Contacts: any
- User Content: Photos or Videos, Audio Data, Customer Support (the customer support flow IS the feedback feature already disclosed under "Other User Content")
- Browsing History
- Search History (search queries are sent to the public API anonymously and not stored or correlated with user identifiers)
- Identifiers: User ID, Device ID, Purchase History
- Usage Data: Product Interaction, Advertising Data
- Diagnostics: Crash Data, Performance Data, Other Diagnostic Data
- Surroundings: any
- Body: any
- Other: any

### Tracking

The app does **not** track users. It does not use IDFA, does not link data across apps and websites, does not share data with data brokers, and does not contain third-party advertising or analytics SDKs.

The "Allow Apps to Request to Track" prompt is **not** displayed.

### Data linked to the user

None. The email address and feedback content are submitted explicitly by the user but the app has no user identifier of its own to link them to.

## Screenshots required

Apple requires screenshots for at least the latest iPhone display size (6.9" — iPhone Pro Max). Recommended scenes:

1. Tree tab — top-level kingdoms with the suggest field at top and bookmark button
2. Search tab — results for "Felis catus" with the dagger and XR badges visible
3. Taxon detail — classification chips, synonymy, common names, and the GBIF map for a mammal
4. Metrics tab — sunburst with the release timeline chart above
5. About — banner with the alias title and preferences below

## Export compliance

The app uses only standard iOS HTTPS encryption (URLSession). No custom cryptography. Eligible for the standard exemption from the ECCN classification when filing App Store Connect's encryption questionnaire. Answer "No" to the "Does your app use encryption?" follow-up question only if you're sure — when in doubt, answer "Yes" and then "Uses only standard iOS encryption exempt from export documentation."
