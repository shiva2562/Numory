# Numory: Play Console answers (draft)

Same SDK families as Rani, minus Firebase (no analytics or crash reports in Numory v1).

## Data safety

| Data type | Collected | Shared | Required | Purpose | By |
|---|---|---|---|---|---|
| Approximate location | Yes | Yes | Yes | Advertising, Fraud prevention / security / compliance | AdMob |
| App interactions | Yes | Yes | Yes | Advertising, Analytics | AdMob |
| Diagnostics | Yes | Yes | Yes | Advertising, Fraud prevention / security / compliance | AdMob |
| Device or other IDs | Yes | Yes | Yes | Advertising, Fraud prevention / security / compliance | AdMob |
| Purchase history | Yes | No (service provider) | Yes | App functionality, Analytics | RevenueCat |
| Game info (other user-generated content: scores) | Yes | No | No (Play Games sign-in is optional) | App functionality | Play Games Services leaderboards |

- Not ephemeral. Encrypted in transit: yes. No user accounts in the app (Play Games is Google's own sign-in).
- Deletion: no account to delete; requests through the privacy-policy contact page. Players can remove leaderboard scores by deleting their Play Games data in the Play Games app.
- Check before saving: whether Play wants leaderboard scores declared at all (Google's own service), and declare them anyway if unsure.

## App content
- Privacy policy: https://shiva2562.github.io/privacy.html (shared page; add a Numory line if it lists games by name).
- Ads: yes. Advertising ID: yes (AdMob).
- App access: all features available without special access (no reviewer code needed).
- Target audience: 13+ (13–15, 16–17, 18+), like Rani. Under-13 players picked in the age gate get no ads.
- Content rating: questionnaire, puzzle/casual, no violence, no user communication, no gambling. Expect Everyone / PEGI 3.
- Government apps: no. Financial features: none. Health: none. News: no.
