module.exports = {
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: 'tsconfig.json',
    tsconfigRootDir: __dirname,
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint/eslint-plugin'],
  extends: [
    'plugin:@typescript-eslint/recommended',
    'plugin:prettier/recommended',
  ],
  root: true,
  env: {
    node: true,
    jest: true,
  },
  ignorePatterns: ['.eslintrc.js'],
  rules: {
    '@typescript-eslint/interface-name-prefix': 'off',
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/explicit-module-boundary-types': 'off',
    '@typescript-eslint/no-explicit-any': 'warn',
    'no-restricted-imports': [
      'error',
      {
        patterns: [
          {
            group: ['**/modules/produccion/internal/**'],
            message:
              'No importar desde produccion/internal directamente. Usa ProduccionFacade (public/).',
          },
        ],
      },
    ],
  },
  overrides: [
    {
      // Los archivos dentro de produccion/internal pueden importarse entre sí
      files: ['src/modules/produccion/internal/**/*.ts'],
      rules: {
        'no-restricted-imports': 'off',
      },
    },
    {
      // Los archivos del propio módulo produccion (no internal) pueden importar internal
      files: ['src/modules/produccion/**/*.ts'],
      excludedFiles: ['src/modules/produccion/internal/**/*.ts'],
      rules: {
        'no-restricted-imports': 'off',
      },
    },
  ],
};
