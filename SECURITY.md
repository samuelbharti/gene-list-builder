# Security Policy

## Supported versions

Fixes land on `main` and go out with the next release. Older tags are not
patched.

## Reporting a problem

Please do not open a public issue for a security problem. Email
<samuelbharti.io@gmail.com> instead, describing what you found and, where you
can, the steps to reproduce it. You will get an acknowledgement within a few
days, along with what happens next.

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
