# Play Console: answers to the forms

Everything below matches what the game really does in version 1.0 (no accounts, no servers,
no analytics, no purchases, Google AdMob rewarded ads only). **If you add a feature later
(Firebase, purchases, notifications ...) these answers must be updated.**
Google's forms change from time to time: if a question looks different, answer it honestly
from the facts in section 1.

## 1. Facts about the game
| Question | Answer |
|---|---|
| Needs an account / login | No |
| Own server or database | No (save is on the phone only) |
| In-app purchases | No |
| Ads | Yes: Google AdMob **rewarded video** ads, always optional |
| Ad consent | Google UMP form (EEA, UK ...) + Settings -> "Ad privacy choices" |
| Analytics / crash reporting SDK | None |
| Permissions | INTERNET, ACCESS_NETWORK_STATE, AD_ID (all for ads) |
| Collects name / e-mail / location / photos / contacts | No |
| Languages | English, Hindi |
| Backup | Android Auto Backup of the save file (player's own Google Drive) |

## 2. App content (Policy -> App content)
- **Privacy policy**: the URL of your hosted `docs/privacy-policy.html` (README, "Privacy policy page").
- **Ads**: *Yes, my app contains ads.*
- **App access**: *All functionality is available without special access.*
- **Target audience and content**: choose **13+** age groups (13-15, 16-17, 18+). Do **not** select any group under 13: that would put the game under the Families policy, which needs special ad SDK certification.
  - "Could the app appeal to children?" -> **No** (the art is simple and colourful, so read the question carefully and answer honestly; if Play Console asks you to treat it as appealing to children, you must then follow the Families policy).
- **Advertising ID**: *Yes* the app uses it -> purpose **Advertising or marketing**. (The manifest already declares the `AD_ID` permission.)
- **Government app / Financial features / Health / News / COVID**: No to all.
- **Data safety**: see section 3.
- **Content rating (IARC questionnaire)**: category **Game**. Violence: no. Fear/horror: no. Sexuality/nudity: no. Language: no. Controlled substances (drugs, alcohol, tobacco): **no**. Gambling or simulated gambling: **no** (there are no chance-based rewards for money). User-generated content / users interact: **no**. Shares location: no. Digital purchases: no. Expected result: *Everyone* / PEGI 3 / USK 0 (ads can raise it in some regions).

## 3. Data safety form
The game itself collects nothing. The **Google Mobile Ads SDK** collects and shares data with Google to
show and measure ads. Google publishes the exact list for its SDK (search for
**"AdMob Google Play Data safety"** on support.google.com). At the time of writing, declare:

| Data type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| Approximate location (derived from IP) | Yes | Yes (Google) | Advertising or marketing; Fraud prevention, security | No |
| Device or other IDs (advertising ID) | Yes | Yes (Google) | Advertising or marketing; Fraud prevention | No |
| App interactions (ad interactions) | Yes | Yes (Google) | Advertising or marketing; Analytics | No |
| Crash logs / Diagnostics | Yes | Yes (Google) | Analytics | No |

- *Is all data encrypted in transit?* **Yes.**
- *Can users request that data be deleted?* The game keeps no data of its own; point to Google's
  controls (Android Settings -> Privacy -> Ads) in the policy, which `privacy-policy.html` does. Answer **No** for the
  app's own data (there is none) unless Play Console insists on a way: the policy e-mail then counts.
- Check Google's current AdMob page once more before you submit; it is the authority.

## 4. Store listing
Copy from `store/listing-en.md` and `store/listing-hi.md`. Graphics are in `store/graphics/`.
Add **2+ real screenshots** (see `store/screenshots.md`).

## 5. Testing track (required for new personal developer accounts)
Google requires a **closed test with at least 12 testers who stay opted in for 14 days in a row**
before you can apply for production (accounts created after 13 Nov 2023).
1. *Test and release -> Testing -> Closed testing -> Create track.*
2. Upload the `.aab` built with `env/test.json` (`ADS_MODE` = `test`: only Google's test ads, so your testers can click them safely). Never let testers click real ads: that counts as invalid traffic and can get the AdMob account banned. Use `env/prod.json` only for the production release.
3. Make a Google Group or an e-mail list with **at least 12-15 people** (friends, family, college groups). They must accept the invite link on their phone with the Google account you added, and **stay opted in**.
4. Wait 14 consecutive days. Fix bugs and upload a new build if needed (new `versionCode` each time, see README).
5. *Dashboard -> Apply for production access*, answer the questions, then create the production release.
