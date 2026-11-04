# Stirling PDF Keycloak setup

Before deploying the Stirling PDF SSO configuration:

1. In Keycloak's `sacred` realm, create an OpenID Connect client named
   `stirling-pdf`. Enable client authentication and the standard authorization
   code flow. Add `https://pdf.tapirus.cc/login/oauth2/code/keycloak` as a valid
   redirect URI. Restrict access to the intended users in Keycloak.
2. Add the following environment file as the `stirling-pdf/env-file` SOPS
   secret in the private `secrets/emilia.yaml`, using the client's secret and a
   strong, unique admin password:

   ```text
   SECURITY_OAUTH2_CLIENT_KEYCLOAK_CLIENTSECRET=<client-secret>
   SECURITY_INITIALLOGIN_USERNAME=admin
   SECURITY_INITIALLOGIN_PASSWORD=<strong-password>
   ```

   Initial admin credentials only apply when the Stirling database has no users;
   existing accounts retain their passwords. The environment file is read by
   systemd and should use its `EnvironmentFile` syntax.
3. Deploy, then test the Keycloak login in a private browser window. An account
   is created on first sign-in; the free plan has a user limit. Sign in with the
   local admin account and grant the SSO account the Admin role in Settings →
   Workspace → Users.

Password login remains enabled for recovery. If SSO-only login is desired, set
`SECURITY_LOGINMETHOD` to `oauth2` only after verifying the SSO admin account.
Keep the local admin credentials securely for recovery. Stirling's SSO settings
are documented at https://docs.stirlingpdf.com/Server/Security/OAuth-SSO/.
