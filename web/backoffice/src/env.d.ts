interface ImportMeta {
  readonly env: ImportMetaEnv;
}

interface ImportMetaEnv {
  readonly NG_APP_API_URL: string;
  readonly NG_APP_ENV: string;
  readonly NG_APP_SENTRY_DSN: string | undefined;
  readonly NG_APP_KEYCLOAK_URL: string | undefined;
  readonly NG_APP_KEYCLOAK_REALM: string | undefined;
  readonly NG_APP_KEYCLOAK_CLIENT_ID: string | undefined;
  readonly [key: string]: string | undefined;
}
