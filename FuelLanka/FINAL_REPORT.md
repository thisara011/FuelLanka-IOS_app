# FuelSmart LK — Final Project Report

**Student name:** Thisara Edirisingha

**Index number:** `[REPLACE WITH INDEX NUMBER]`

**Batch:** `[REPLACE WITH BATCH]`

**Project title:** FuelSmart LK

**Submission date:** `[REPLACE WITH DATE]`

## Executive summary

FuelSmart LK is a native iOS application designed to make Sri Lankan fuel information easier to discover and manage. Customers can locate stations using search or an interactive map, inspect reported fuel stock and prices, compare the same grade between stations, save favourites and view a local fuel-demand outlook. Managers maintain assigned-station stock, sales, deliveries and prices, while administrators access protected operational functions. Firebase supplies identity and real-time data; Apple frameworks provide mapping, on-device machine learning, biometrics, widgets, notifications, receipt capture, charts and Live Activities.

The application avoids representing predictions as guaranteed availability. Every report exposes its source and time where available, stale or incomplete data is handled explicitly, and seeded records are identified as demonstration data.

## 1. Application overview

### 1.1 Problem and objective

Fuel availability and prices can vary by location and time. Drivers need a single mobile interface for discovering stations and evaluating recent reports, while station personnel need controlled workflows for maintaining operational records. FuelSmart LK addresses these needs through role-specific experiences within one iOS application.

### 1.2 User roles

- **Customer:** registers, verifies an email address, signs in, searches stations, views the map and reports, compares prices, saves favourites, enables notifications and views forecasts.
- **Manager:** works only with the assigned station, recording stock, sales, deliveries and prices and reviewing analytics.
- **Administrator:** accesses protected user, role and station operations.

The client does not allow a user to choose a privileged role. Firebase Authentication establishes identity and trusted role information routes the session to the permitted workspace.

### 1.3 Principal functionality

The customer workspace contains Home, Find, Map, Predict and Profile experiences. Station details combine reported availability, stock/capacity, price, update time, data source, directions and fuel outlook. Comparison evaluates the same selected fuel grade rather than comparing unrelated products. Favourites feed the customer list and the Home Screen widget.

The manager workspace contains station overview, stock editing, completed sales, delivery receipts, fuel price publishing, notifications and analytics. Input rules reject invalid quantities, stock above capacity, future receipt dates and incomplete references. Administrator operations provide a distinct privileged workspace.

## 2. UI and interaction design

The interface was implemented with SwiftUI and native navigation, controls, sheets and alerts. Customer tasks are placed in a five-tab workspace, while manager and administrator functions are separated to reduce accidental access. Semantic system colours and text styles support light/dark appearance and Dynamic Type. Empty, loading, stale, permission-denied and service-error states are shown separately so missing information is not represented as zero.

On iPhone, the compact tab-based design prioritises one-handed navigation and pushes details onto the navigation stack. On iPad, the same adaptive SwiftUI layout gains more space and readable content widths; modal sheets and maps use the larger canvas without changing the underlying task model. A future dedicated iPad optimisation could adopt `NavigationSplitView` to keep the station list and selected station visible simultaneously.

The README contains a UI tour and feature-flow diagram. The source also provides SwiftUI previews for customer, manager, administrator, authentication, map, comparison and station-detail screens, including dark and accessibility-size variants where applicable.

## 3. Development process

### 3.1 Approach

Development proceeded incrementally:

1. Establish reusable SwiftUI navigation and form patterns.
2. Implement authentication forms and validation.
3. Build role-specific customer, manager and administrator workspaces.
4. Integrate Firebase Authentication and Cloud Firestore.
5. Add MapKit/Core Location and station discovery.
6. Add protected Face ID sign-in and Keychain storage.
7. Add the Core ML demand model and responsible fallback behaviour.
8. Add WidgetKit, notifications, Vision receipt capture, Charts and ActivityKit.
9. Add Swift Testing unit coverage and XCUIAutomation flows.
10. Populate labelled demonstration records and validate a build-for-testing configuration.

Observable stores isolate Firestore reads and application state from presentation code. Validation models are testable without launching the UI. Async/await is used for asynchronous service calls.

### 3.2 Challenges and resolutions

**Incomplete imported station records.** Some imported LIOC stations lacked coordinates, reports and transaction history, causing blank maps, comparison and forecasts. Missing fields were identified and completed with clearly labelled demonstration coordinates, reports and confirmed sales. UI destinations were connected to the same station and prediction stores so random station selection behaved consistently.

**Responsible forecasting.** A forecast generated from one old report would be misleading. Eligibility rules now require a current usable stock report and confirmed recent sales spanning multiple days. Deliveries and unconfirmed sales are excluded. The app blocks stale or insufficient input and exposes whether Core ML or the baseline engine was used.

**Passwordless registration and biometric setup.** Email-link or Apple accounts may not initially have a Firebase password. Session routing now requires password creation before entering the protected workspace. Face ID setup requires the current Firebase password, stores the credential in access-controlled Keychain storage and preserves password fallback.

**Widget not appearing on iOS 26.5.** The widget extension initially targeted iOS 27.0 while the simulator ran iOS 26.5. Aligning the extension deployment target with the application allowed iOS to register the embedded WidgetKit extension.

**Notifications versus remote push.** Firestore listeners can schedule local alerts while the app is active or backgrounded, but they do not guarantee delivery after termination. The current behaviour is described accurately; full production delivery requires APNs credentials, Firebase Cloud Messaging token management and a trusted sending backend.

**Protecting privileged access.** Client-selected roles would be insecure. Role routing uses authenticated server-provided claims, and Firestore Security Rules remain part of the backend boundary.

## 4. Advanced iOS features

### 4.1 Core ML fuel-demand outlook

`FuelDemandRegressor.mlmodel` is bundled and compiled by Xcode. Confirmed station sales are grouped into daily totals for the selected fuel. Local feature preparation calculates recent three-day and seven-day demand, the preceding baseline, trend and weekend context. Core ML then predicts demand on the device. Current reported stock divided by bounded predicted daily demand produces estimated days remaining and an estimated run-out date.

No prediction features are sent to a cloud inference API. When the model is unavailable or history is insufficient for model inference, the app either uses an identified transparent local baseline or refuses to display an estimate. Tests verify bundled-model inference, rejection of stale input, exclusion of deliveries/unconfirmed sales and insufficient-history handling.

### 4.2 MapKit and Core Location

Firestore station coordinates become MapKit annotations. Selecting a pin opens the same station details used by list search, preventing inconsistent functionality. Core Location is requested only when the user asks for location support. Manual search remains available if permission is denied. Valid coordinates can be passed to Apple Maps for directions.

### 4.3 LocalAuthentication and Keychain

Face ID is opt-in after authenticated password confirmation. LocalAuthentication performs biometric policy evaluation; only after success is the Firebase credential retrieved from Keychain. The credential is not stored in `UserDefaults`. If biometric enrolment changes, protected Keychain access can fail and the user returns to password sign-in.

### 4.4 WidgetKit and App Groups

The first suitable favourite-station report is encoded into shared App Group storage. The WidgetKit extension reads that snapshot and presents station, fuel, availability, price and time information in small and medium families. The app requests a timeline reload after synchronisation, while iOS retains control over the actual refresh schedule.

### 4.5 Notifications, Vision, Charts and ActivityKit

UserNotifications presents local price/restock alerts after checking notification preferences, favourite station IDs and preferred fuels. Vision/VisionKit assists with delivery-receipt text capture, but the manager reviews extracted values before saving. Swift Charts visualises scoped confirmed station activity. ActivityKit provides a time-limited fuel-journey Live Activity on supported devices.

## 5. Backend and external services

### 5.1 Firebase Authentication

Firebase Authentication provides email/password accounts, verification, reset flows, Sign in with Apple linking and persistent authenticated identity. The Firebase project identifier is `fuelsmart-lk` and the iOS bundle identifier is `thisara.FuelLanka`.

### 5.2 Cloud Firestore

Firestore stores user profiles, station metadata, coordinates, reports, prices, transactions and alert events. Timestamps, source labels and stale-state handling allow the UI to distinguish current, missing and outdated information. Security rules are included as `firestore.rules`.

### 5.3 Marker access

The following identifiers are prepared for assessment:

| Role | Email |
| --- | --- |
| Customer | `customer@fuelsmart-lk.app` |
| Manager | `manager@fuelsmart-lk.app` |
| Administrator | `admin@fuelsmart-lk.app` |

Passwords must be supplied privately through the approved LMS marker notes or directly to the lecturer; they must not be committed to Git. If console inspection is required, the lecturer should be invited to the Firebase project with the minimum read-only role necessary. The repository includes `GoogleService-Info.example.plist`; the real Firebase configuration must be supplied privately or downloaded by an authorised marker.

## 6. Verification and testing

The active Xcode test plan contains 56 enabled tests: 51 Swift Testing unit tests and 5 XCUIAutomation tests. Unit coverage includes authentication state/role routing, password setup gating, registration and sign-in validation, stock/capacity arithmetic, prices, delivery receipts and OCR parsing, station coordinates, Apple sign-in nonce handling, manager analytics and Core ML prediction safeguards.

The project built successfully for testing on 24 October 2026. The full combined simulator test run should be executed again immediately before creating the final commit and its result recorded here: **`[REPLACE WITH FINAL TEST RESULT]`**. Device validation is additionally required for Face ID, camera receipt capture, notification permission/presentation, widgets and Live Activities.

## 7. Learning outcomes reflection

> Check the wording below against the official module handbook and replace each LO heading with the institution's exact published wording before submission.

### LO1 — Evaluate iOS platforms, capabilities and design choices

This project developed my ability to match platform capabilities to user needs rather than adding frameworks for decoration. MapKit is appropriate for spatial discovery, Core ML supports private low-latency inference, WidgetKit supports glanceable information and LocalAuthentication delegates biometric trust to the operating system.

Device form factor affects design. On iPhone, a bottom tab bar and pushed detail screens suit the narrow portrait layout and one-handed use. On iPad, the same SwiftUI views adapt to a larger canvas, but a production-focused iPad version should use a split view for simultaneous list/map and details, larger pointer-friendly targets, keyboard shortcuts and multitasking/window resizing. Widget families and Live Activity presentation also vary by device capability. These differences show why responsive layout is preferable to fixed coordinates.

### LO2 — Design and implement a native mobile solution

I translated requirements into role-specific SwiftUI workflows, separated presentation from validation and stores, and used observable state plus async/await for responsive updates. Native navigation, sheets, alerts and semantic styling improved consistency and accessibility. Explicit loading, missing and stale states prevented misleading UI.

### LO3 — Integrate advanced frameworks and persistent/network services

I integrated Firebase identity and Firestore data with Apple technologies including MapKit, Core Location, Core ML, WidgetKit, ActivityKit, LocalAuthentication, Keychain, UserNotifications, Vision and Charts. The most important learning was understanding boundaries: Core ML inference is local, Firebase is remote; Face ID authenticates the device user, while Firebase authenticates the account; local notifications are not equivalent to guaranteed remote push.

### LO4 — Test, evaluate and reflect on solution quality

Swift Testing made validation and prediction rules independently repeatable. XCUIAutomation covered launch and authentication validation paths. Security and data quality were treated as correctness requirements through role routing, Firestore rules, input checks, stale-data rejection and credential hygiene. Remaining limitations—demo data, remote push configuration and prediction uncertainty—are documented rather than hidden.

## 8. Limitations and future work

- Replace demonstration station reports with authorised live operator or government data feeds.
- Configure production APNs and Firebase Cloud Messaging for terminated-app delivery.
- Evaluate the Core ML model on a larger time-ordered real dataset and publish appropriate error metrics.
- Add a dedicated iPad `NavigationSplitView` experience and conduct complete VoiceOver/Dynamic Type audits.
- Add offline conflict policies and backend audit tooling for concurrent manager updates.
- Expand automated UI coverage across role workspaces and permission-denied cases.

## 9. LLM-use declaration

An OpenAI coding assistant was used during the project for documentation drafting, explanation, troubleshooting, code review and implementation assistance. All generated suggestions were reviewed in Xcode, adjusted to the project, and validated through builds/tests where recorded. No LLM was given production passwords or committed access tokens. Because the assessment brief states that LLM use is permitted for non-code tasks only, this declaration must remain truthful and the student should confirm the acceptability of any implementation assistance with the lecturer before submission. The student remains responsible for understanding and defending every submitted component.

## 10. Repository and immutable final commit

Repository: <https://github.com/thisara011/FuelLanka-IOS_app>

Final commit URL: `https://github.com/thisara011/FuelLanka-IOS_app/commit/<FINAL_COMMIT_SHA>`

Do not use the repository home page as the final submission link. After the final source, tests and report are committed, replace `<FINAL_COMMIT_SHA>` with that commit's full SHA and do not make further assessed changes after it.

## 11. Demonstration video plan (3–5 minutes)

1. **0:00–0:25:** Problem, app purpose and role model.
2. **0:25–1:10:** Customer sign-in/Face ID, Home and favourites.
3. **1:10–2:05:** Find/MapKit, random station details and Apple Maps directions.
4. **2:05–2:45:** Price comparison and Core ML fuel outlook, including engine and limitations.
5. **2:45–3:20:** Widget and notification demonstration.
6. **3:20–4:10:** Manager stock/sale/delivery update and analytics.
7. **4:10–4:35:** Administrator role, tests, backend and security.
8. **4:35–5:00:** Limitations and learning summary.

The YouTube video must be **Unlisted**, not Private, and its link should be tested in an incognito window.

## 12. Final submission checklist

- [ ] Replace student index, batch, submission date and exact LO wording.
- [ ] Run all 56 tests and replace the final test-result placeholder.
- [ ] Confirm no password, token, service-account file or real Firebase plist is tracked.
- [ ] Add the lecturer as collaborator to the private GitHub repository.
- [ ] Commit the final source and report, then insert the immutable `/commit/<sha>` URL.
- [ ] Export this report as `<studentid>_individual_report.pdf`.
- [ ] Create `<studentid>_individual_source_code.zip` without DerivedData or secrets.
- [ ] Upload the unlisted 3–5 minute YouTube demonstration and test its link privately.
- [ ] Complete the acknowledgement form and copy the generated `IOS-XXXX` code.
- [ ] Paste the code into the LMS text box and upload both required files.
