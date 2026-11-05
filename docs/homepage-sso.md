# Homepage Keycloak setup

Before deploying the Homepage SSO configuration:

1. In Keycloak's `sacred` realm, create an OpenID Connect client named
   `homepage`. Enable client authentication and the standard authorization
   code flow. Add `https://homepage.tapirus.cc/api/auth/callback/homepage-oidc`
   as a valid redirect URI. Restrict access to intended users in Keycloak:
   Homepage accepts every identity authorized for this client.
2. Add the following environment file as the `homepage/env-file` SOPS secret
   in the private `secrets/emilia.yaml`:

   ```text
   HOMEPAGE_OIDC_CLIENT_SECRET=<client-secret>
   HOMEPAGE_AUTH_SECRET=<random-cookie-signing-secret>
   ```

   Generate the authentication secret with `openssl rand -base64 32`. Keep
   both values private. The file uses systemd `EnvironmentFile` syntax.
3. Deploy and test sign-in in a private browser window. Automatic sign-in can
   be bypassed at `https://homepage.tapirus.cc/auth/signin?autologin=0`.

Homepage's authentication settings and public endpoint exceptions are
documented at https://gethomepage.dev/installation/#security-authentication.
