# Security Policy

## Supported versions

I maintain this project on my own. I fix security problems on `main` and in the
next release. I do not backport fixes to older tags.

## Reporting a problem

**Please do not open a public issue for a security problem.**

Email me at <samuelbharti.io@gmail.com>. Tell me what you found and, if you
can, how to reproduce it. I will acknowledge your report within a few days and
tell you what I plan to do about it.

## Worth knowing before you report

- The app runs fully without any key. Every gene-disease source it queries is
  public and read-only.
- The optional AI curation reads `GEMINI_API_KEY` from `.Renviron`, which is
  git-ignored. Do not commit that file. `ENTREZ_KEY` is optional and only
  raises an NCBI rate limit.
- Cached source tables are written under `data/cache/` (git-ignored, override
  with `GLB_CACHE_DIR`). They hold public query results, not credentials.
- If you deploy the app yourself, the keys and the environment you deploy into
  are yours to secure.
