# Apple root certificates

Public trust anchors downloaded from Apple's PKI on 2026-09-28:

- https://www.apple.com/certificateauthority/AppleRootCA-G2.cer
- https://www.apple.com/certificateauthority/AppleRootCA-G3.cer

Source index: https://www.apple.com/certificateauthority/

These are public CA certificates, not signing keys. The official Apple library checks the certificate chain, revocation (online), bundle ID, environment and application ID. Do not replace verification with a decoded-only JWT/JWS or trust client-supplied certificates.
