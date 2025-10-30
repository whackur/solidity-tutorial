// @ts-check
import {defineConfig} from 'eslint/config';
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';
import prettierConfig from 'eslint-config-prettier';

export default defineConfig(
  {
    ignores: [
      'eslint.config.js',
      '**/node_modules/**',
      '**/coverage/**',
      '**/dist/**',
      '**/cache/**',
      '**/artifacts/**',
      '**/types/**',
      '**/ignition/deployments/**',
      '**/bundle/**',
    ],
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  ...tseslint.configs.strict,
  ...tseslint.configs.stylistic,
  prettierConfig,
  {
    languageOptions: {
      parserOptions: {
        project: 'tsconfig.json',
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/object-curly-spacing': 'off',
      'object-curly-spacing': ['error', 'never'],
    },
  },
);
