import type { Config } from 'jest';

const config: Config = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$',
  transform: {
    '^.+\\.(t|j)s$': ['ts-jest', { tsconfig: './tsconfig.json' }],
  },
  collectCoverageFrom: [
    '**/*.(t|j)s',
    '!main.ts',
    '!**/*.module.ts',
    '!**/*.spec.ts',
    '!**/*.d.ts',
  ],
  coverageDirectory: '../coverage',
  testEnvironment: 'node',
  coverageThreshold: {
    global: { lines: 80 },
  },
};

export default config;
