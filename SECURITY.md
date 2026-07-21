# Security notes

The former Rails 4 `config/secrets.yml` contained checked-in development and test cookie-signing keys. Those values must be treated as exposed: scan every branch and tag, invalidate sessions, rotate any reused material, and use the repository owner's approved process if history removal is required. This change removes the file but cannot revoke secrets or rewrite shared history.

Production requires `SECRET_KEY_BASE` and `DATABASE_URL`; there is no fallback signing secret. Market-data tokens belong in a managed secret store. Operator and approver roles are privileged and must be assigned through a controlled administrative process, not public parameters.

This application is paper-trading only. Adding a brokerage token or network call does not make live execution safe and is outside the implemented authorization boundary. A future live integration requires separate custody, suitability, compliance, maker-checker approval, reconciliation, incident response, and regulatory review.
