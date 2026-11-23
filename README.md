# FinverseAI-app

FinVerse Android app — real-time sync with the FinVerse web app
([finverseaii.netlify.app](https://finverseaii.netlify.app/), repo
[FinverseAI/FinVerse-AI](https://github.com/FinverseAI/FinVerse-AI)).

## Base

Flutter fork of [BeeCount](https://github.com/TNT-Likely/BeeCount)
(local-first bookkeeping, Flutter 3.27+, Riverpod, Drift/SQLite).
UI kept as BeeCount for now; FinVerse theme in `lib/theme/finverse_theme.dart`
applies later, on the user's word.

## What syncs (via the FinVerse backend, Neon Postgres)

Same Google account (Better Auth) as the web app. Same REST API:

- `GET/POST /api/transactions`
- `GET/POST /api/bills`, `/api/goals`
- `GET /api/profile`, `/api/onboarding`
- `GET /api/market/quote/[symbol]`, `/overview`, `/history/[symbol]`
- `GET /api/holdings`, `/api/watchlist`, `/api/portfolio/summary`
- `POST /api/ai/chat`, `/api/ai/explain-stock`, `/api/rag/news/[symbol]`

Local-first: Drift/SQLite cache on device, sync on change + on open.
