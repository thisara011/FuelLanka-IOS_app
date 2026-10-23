# FuelSmart LK implementation baseline

Source: IOS Final Proposal doc.pdf supplied by the user on 19 October 2026.
Design: https://www.figma.com/design/uhgeAkiOKyPdd30Vy4DPcf

## Delivery decisions

User clarification, 19 October 2026: build a real application, not a demo. This overrides the proposal’s demo delivery assumptions. Demo entry points and fabricated station/forecast values have been removed. Continue front-end work screen by screen, then connect real authenticated services.

- Build the front end first, one screen per increment, using the proposal for behavior and Figma for appearance.
- The revised proposal prioritizes native iPhone delivery. Support different iPhone sizes, landscape, Dynamic Type, VoiceOver, dark mode and reduced transparency. Retain existing adaptive layouts; dedicated iPad workspaces are outside the revised scope.
- The current project targets iOS 26.5. Keep deployment compatibility explicit; do not equate this with validation on every later OS release.
- Use SwiftUI system navigation and controls, async/await services and separate validation/data logic from views.
- Use real authorized data for runtime station content. Until services are connected, show empty/unavailable states; keep sample data confined to development previews and tests. Never imply guaranteed fuel on arrival or measured prediction accuracy.
- UI completion and MVP completion are separate milestones. A clickable form does not complete authentication, reporting or any persisted feature.

## Screen-by-screen front-end order

1. Welcome — implemented; light, dark, large-text and wide-layout previews checked.
2. Sign In — front-end implemented: native fields, input validation, keyboard behavior and explicit unavailable-service feedback. No credential persistence or fabricated authentication success. Verified build, 13 Swift Testing cases, one XCUIAutomation navigation/empty-input test, and light/dark/large-text previews on iPhone 17 Pro (iOS 26.5).
3. Customer Create Account — front-end implemented from Figma: five editable fields, contact/password/confirmation validation, unchecked consent, policy availability notice, and return to Sign In. No manager/admin registration selector or account creation service. Build and 11 validation cases passed; light/dark/large-text previews checked. Final policy documents remain required before enabling real registration.
4. Reset Password — front-end implemented from Figma with shared email validation, keyboard handling, explicit service-unavailable notice and return to Sign In. No email is sent and no account-existence information is shown. Build and recovery UI test passed; light/dark/large-text previews checked on iPhone 17 Pro (iOS 26.5). Real request/loading/success/network-error states remain part of Firebase integration.
5. Role routing — derive workspace access from authenticated server-authorized roles. No user-selectable demo role chooser.
6. Customer Home — layout and unavailable-data state implemented with native five-tab navigation, search/See all routing, notifications destination and a separate forecast-unavailable card. No fabricated identity, location, counts, stock or forecast. Build and light/dark/large-text previews checked on iPhone 17 Pro (iOS 26.5). Review via CustomerWorkspaceView previews; runtime authenticated routing, real data rendering, loading/offline/stale states and remaining tab screens are pending.
7. Find Fuel and filters — search UI implemented with native search, fuel/availability menus, manual province/district/city criteria, draft Apply/Cancel, and reset. Connected to Find tab. Build and standard/large-text/filter-sheet previews checked. Runtime data queries, station results and distance filtering remain pending; no fabricated results are shown. Station Details presentation now supports supplied reports, timestamps, sources, stale labels, stock/capacity validation and coordinate-based directions. Missing data and forecasts stay unavailable. Find has a typed details destination; real result links remain pending. Build, two data-guard tests and light/dark/large-text unavailable-state previews checked. Next: Live Map (implemented below).
8. Live Map and location access — implemented native MapKit with Sri Lanka initial region/reset, on-demand Core Location permission, denied/error feedback, fuel/availability filters, supplied-record pins and station-details navigation, and List view routing to manual search. No fabricated pins or stock. Build passed; light and dark/large-text previews rendered on iPhone 17 Pro (iOS 26.5). Preview map tiles were blank, so network tile loading and permission interactions still require simulator/device verification. Real station feed and authenticated access remain pending.
9. Favourites and same-fuel price comparison — front-end implemented from Figma with Home entry, saved-station/detail navigation, Find more stations routing, and separate empty/unavailable states. Comparison selects one fuel grade and presents the latest supplied report with LKR pricing, stock, timestamp, source and stale labels. No fabricated stations or prices. Build passed; light and dark/large-text unavailable-state previews checked on iPhone 17 Pro (iOS 26.5). Account-scoped save/remove persistence, live reports, distances, populated-state verification and customer analytics remain pending.
10. Customer Profile and preferences — front-end implemented from Figma with native Profile tab, edit sheet, contact and Sri Lanka district drafts, four fuel selections, restock/price alert drafts, discard confirmation and explicit unavailable-save feedback. Favourites and comparison links are connected. Build and light/dark/large-text previews checked. Persisted account rendering/writes, validation on real saves, notifications, security, analytics and actual sign-out remain pending; no session or subscription is simulated.
11. Returning-customer and Face ID opt-in/fallback screens; enable biometrics only after authentication integration.
12. Manager Dashboard, assigned-station details, stock update/review, prices, sales and deliveries.
13. Manager Profile, notifications and analytics; preserve station assignment as read-only.
14. Administrator Dashboard, station/user review, fuel data, geography, API controls, analytics and settings.
15. Forecast/model screens — clearly separate estimates from reports; insufficient/stale input fallback.

For each increment: read its Figma context, reuse design tokens, implement interactions within scope, build, check small/large text and light/dark layouts, record remaining destinations. Unimplemented destinations must be explicitly identified; they must never simulate a successful protected action.

## Persisted MVP integration after the front-end pass

| Proposal feature | Integration and completion gate |
| --- | --- |
| Onboarding/sign-in | Firebase Authentication sessions, customer-only registration, authorized role routing, sign-out and recovery; test unauthenticated and unauthorized paths. |
| Profile/settings | Persist contact details, fuel preferences and alert choices; managers see only their assigned station. |
| Role dashboards | Read authorized persisted data; distinguish loading, unavailable, cached, missing and stale records. |
| Firebase services | Firestore users/stations/stock/prices/timestamps, Security Rules and Cloud Functions; server-side authorization and audit records. |
| Push alerts | FCM through APNs, contextual opt-in, preferences, token lifecycle, and authorized deep links. |
| Face ID | LocalAuthentication plus Keychain protection of the existing session; customer opt-in after first sign-in; cancel/failure/unavailable paths return to password. Never store raw passwords. |
| Station search | Persisted fuel/district/availability filters; station price, source and report timestamp. |
| Map | MapKit/Core Location, station selection and directions; denied permission retains manual district search and list access. |
| Favourites/comparison | Account-scoped persisted favourites; compare the same grade by reported stock, price, distance and freshness. |
| Stock/transactions | Assigned-station writes only, quantity/capacity checks, review before a single confirmed save, server timestamps, atomic arithmetic, audit and duplicate protection. |

Before integration, inspect existing configuration and obtain the actual Firebase project configuration and Apple signing/APNs settings needed for this app. Do not invent credentials or deploy permissive rules.

## Advanced SDK stages (after the working MVP)

1. Core ML: evaluate availability-on-arrival against a simple baseline on time-ordered data. Display uncertainty; hide estimates with stale/insufficient inputs.
2. WidgetKit: favourite station's last reported state and timestamp, with system-managed refresh.
3. Vision/VisionKit: scan delivery receipts, review prefilled fields and confirm once; retain manual entry.
4. ActivityKit: time-limited fuel journey, completion/expiry handling and supported-device presentation.

### Core ML local inference increment

The customer fuel outlook now bundles `FuelDemandRegressor.mlmodel` and performs Core ML inference entirely on the device. Runtime inputs are derived locally from confirmed station sales: recent three-day demand, recent seven-day demand, the preceding seven-day baseline, demand trend and weekend context. The prediction is bounded against observed demand, remains blocked for stale/insufficient stock inputs, and falls back to the existing transparent local baseline if the model or sufficient history is unavailable. The UI identifies the active engine as `On-device Core ML` or `Local baseline`; no station prediction features are sent to a cloud inference service. Xcode compiled the model successfully and focused model/baseline prediction tests passed.

## Validation gates

- Firebase Emulator Suite: customers cannot write station reports; managers cannot write other stations; administrative operations require authorized roles.
- Swift Testing: input validation, stock arithmetic/capacity, idempotency behavior and freshness/forecast eligibility.
- XCUIAutomation: welcome/auth navigation, keyboard and error recovery, role-specific flows, large text, map permission fallback and notification routes.
- Device checks: biometrics and fallback, notification permission/delivery, camera scanning, widgets and Live Activities as each integration lands.
- Forecast evaluation: recorded baseline, time-ordered split, error metrics and limitations before any accuracy claim.

## Current limitations

- Authentication, account creation, password reset, Face ID, role workspaces and all cloud services remain unimplemented.
- The generated SwiftData Item container is still template code, not the application's persistence architecture.
- Authentication screens currently validate locally and show truthful unavailable-service feedback. Demo labels, research access, and fabricated welcome stock/prediction values were removed. Customer Home is now available in Xcode previews; authenticated routing is pending. Next front-end screen: Administrator Dashboard.

## Notifications increment

Customer Notifications implemented from Figma with Home/Profile navigation, supplied account-alert cards, newest-first timestamps, alert details, optional station navigation and alert-preferences sheet. Loading, unavailable and successful-empty states are separate. Runtime uses unavailable state until the service is connected; no fabricated alerts or notification permission prompts. Build passed; light unavailable and dark/accessibility-size empty previews checked. Firebase/APNs delivery, authorized deep-link resolution, read-state persistence and populated-state device verification remain pending.

## Account security increment

Profile now opens Sign-in & security, adapted from Figma without simulated biometric controls. Includes setup requirements, truthful unavailable status, password-fallback explanation and Reset password navigation with the correct return label. No biometric prompts, credential storage or enablement flags were added. Build passed; light and dark/accessibility-size previews checked. Actual opt-in, capability checks, LocalAuthentication/Keychain integration and failure/cancel paths await authenticated sessions.

## Manager dashboard increment

ManagerWorkspaceView adds native Home, Stock, Activity and More tabs. Dashboard follows Figma with assigned-station name, explicit unknown operating status, four fuel grades, supplied inventory/capacity progress, report dates and stale labels, and stock/price/forecast navigation. Station details reuse the existing read-only screen. Missing data never becomes zero stock or a forecast. Stock, activity, prices, deliveries and manager profile destinations remain explicitly unavailable pending their screen increments. Build passed; light and dark/accessibility-size workspace previews checked. Review through ManagerWorkspaceView previews; no runtime role bypass was added. Authorized manager routing and assigned-station services remain pending.

## Stock update increment

Stock tab now presents four measured-total fields, latest report and capacity context, stale warnings, explicit discard, and a review sheet. Blank grades remain unchanged; valid decimal litres accept up to three decimal places and cannot exceed a finite positive capacity. Missing assignment disables entry. Assignment/report changes clear drafts to avoid applying old values to a new snapshot. Deliveries are a separate future transaction flow to prevent double counting. Confirm/save stays disabled until authorized atomic writes, server timestamps, conflict checks and duplicate protection exist. Build and nine Swift Testing validation cases passed; light and dark/accessibility-size unavailable-state previews checked. Populated review and interactive device checks remain pending.

## Manager fuel prices increment

Dashboard and More now open the five-grade price form, including kerosene separately from four-grade inventory. Uses Decimal prices, positive values with two decimal places, required per-grade effective date/time in Sri Lanka time, unchanged blank prices, discard confirmation and a review sheet. Existing prices show report time and stale labels when supplied; kerosene report integration remains pending. Assignment/report changes reset drafts. Publishing remains disabled until authorized price services, scheduling policy and atomic audit writes exist. Build and ten Swift Testing cases passed; light and dark/large-text unavailable-state previews checked. Populated review/device interaction checks remain pending.

## Sales history and delivery log increment

Activity now opens Sales history; More and Sales history link to Deliveries. Screens follow Figma summaries/cards with unavailable totals/schedules, fuel filtering, loading/empty/unavailable record states, station-ID filtering and supplied-record detail navigation. Missing quantities and timestamps remain unknown. No fabricated totals, incoming deliveries or exports. Build passed; light Sales history and dark/large-text Deliveries previews checked. Receipt entry/review, scanning, actual export, daily aggregation, authorized record feeds and transaction persistence remain pending.

## Delivery receipt increment

Deliveries now opens a manual receipt sheet with fuel selection, supplier reference, received litres, Sri Lanka receipt time, inventory context, validation and review of proposed stock. Cancel protects unsaved content; assignment/report changes reset the draft. Requires positive quantity, reference, nonfuture receipt time and a nonstale pre-receipt report with valid stock/capacity. Review includes physical-check acknowledgement, while saving stays disabled pending authorized atomic transactions, receipt deduplication and conflict checks. Build and eight Swift Testing cases passed; light and dark/large-text unavailable-state previews checked. Scanning and populated interactive review verification remain pending.

## Manager profile increment

More now opens Manager Profile with supplied identity fields, read-only station assignment/address, station details and security links. Missing identity stays unavailable. Edit and logout display explicit unavailable-service notices; operational notifications remain an unavailable destination. Build and light/dark/large-text previews checked. Manager edit form, authenticated identity/session wiring and actual sign-out remain pending.

## Manager edit profile increment

Edit Profile now opens a draft sheet with prefilled supplied name/phone, shared registration name/mobile validation, keyboard focus, unsaved-discard confirmation and explicit unavailable-save notice. Email stays read-only pending verified email-change integration; station assignment/address stay read-only. Build and light/dark/large-text previews checked. No account update is persisted; authenticated account integration and interaction tests remain pending.

## Manager notifications increment

Profile and More now open operational notifications with station-scoped supplied alerts, newest-first ordering, action labels, loading/empty/unavailable states, detail screens and stock/delivery/price/station routes. Forecast destination remains unavailable. Build and light/dark/large-text missing-assignment previews checked. Server authorization, alert feeds, push delivery, read-state persistence and populated interactive verification remain pending.

## Manager analytics increment

More, Manager Profile and Sales History now open station-scoped sales analytics with 7-day and 30-day periods, complete-record totals, record count, latest timestamp and per-fuel breakdown. Calculations exclude deliveries, other stations, incomplete or invalid quantities, future records and records outside the selected period. Missing assignment, loading, unavailable and successful-empty states remain distinct; runtime defaults to unavailable until authorized sales records are connected. Build, three focused Swift Testing cases, and light plus dark/accessibility-size previews passed on iPhone 17 Pro (iOS 26.5). Real sales feeds, richer trends, export and populated interactive verification remain pending.

## Firebase authentication integration increment

Authentication now has an async service boundary, observable session state, persisted-session restoration, password sign-in, customer registration, password reset, sign-out and server-claim role routing. Customer, manager and administrator workspaces are selected only from the Firebase ID-token `role` claim; missing or unknown roles are blocked, and the client never assigns a privileged role. Registration deliberately remains pending until a trusted backend assigns the customer claim. Firebase initialization is guarded by both SDK availability and `GoogleService-Info.plist`, so missing configuration fails safely instead of crashing or simulating success. Build and four focused session tests passed.

The iOS app is now registered to Firebase project `fuelsmart-lk` with bundle ID `thisara.FuelLanka`. `GoogleService-Info.plist`, `FirebaseAuth` and `FirebaseFirestore` are included, and Email/Password authentication is deployed from the checked-in Firebase CLI configuration. Live registration/sign-in validation and trusted role-claim assignment remain required before authentication is complete. Firestore database creation, Security Rules, Cloud Functions, APNs and data migration remain later integration increments. The proposal PDF is still not present in the accessible workspace.
