import * as fs from 'fs';
import * as path from 'path';

const SRC_DIR = path.resolve(__dirname, '../src');
const INTERNAL_IMPORT_PATTERN = /modules\/produccion\/internal/;
const PRODUCCION_INTERNAL_DIR = path.join(
  SRC_DIR,
  'modules',
  'produccion',
  'internal',
);

function collectTsFiles(dir: string, collected: string[] = []): string[] {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      collectTsFiles(full, collected);
    } else if (entry.isFile() && entry.name.endsWith('.ts')) {
      collected.push(full);
    }
  }
  return collected;
}

describe('Architecture: encapsulación de produccion/internal', () => {
  it('ningún archivo fuera de modules/produccion importa desde produccion/internal', () => {
    const allFiles = collectTsFiles(SRC_DIR);

    const violations = allFiles.filter((filePath) => {
      // Los archivos dentro de produccion/internal pueden importarse entre sí
      if (filePath.startsWith(PRODUCCION_INTERNAL_DIR)) return false;

      const content = fs.readFileSync(filePath, 'utf-8');
      return INTERNAL_IMPORT_PATTERN.test(content);
    });

    if (violations.length > 0) {
      const list = violations
        .map((f) => `  - ${path.relative(SRC_DIR, f)}`)
        .join('\n');
      fail(
        `Los siguientes archivos importan desde produccion/internal, violando el contrato de encapsulación:\n${list}\n\n` +
          `Regla: solo los archivos dentro de modules/produccion/ pueden importar desde internal/. ` +
          `Los consumidores externos deben usar ProduccionFacade (public/).`,
      );
    }

    expect(violations).toHaveLength(0);
  });

  it('el módulo public/ exporta ProduccionFacade', () => {
    const indexPath = path.join(
      SRC_DIR,
      'modules',
      'produccion',
      'public',
      'index.ts',
    );
    expect(fs.existsSync(indexPath)).toBe(true);
    const content = fs.readFileSync(indexPath, 'utf-8');
    expect(content).toMatch(/ProduccionFacade/);
  });

  it('cada subdirectorio de internal/ tiene un README.md', () => {
    const subdirs = fs
      .readdirSync(PRODUCCION_INTERNAL_DIR, { withFileTypes: true })
      .filter((e) => e.isDirectory())
      .map((e) => e.name);

    expect(subdirs.length).toBeGreaterThan(0);

    for (const subdir of subdirs) {
      const readme = path.join(PRODUCCION_INTERNAL_DIR, subdir, 'README.md');
      expect(fs.existsSync(readme)).toBe(true);
    }
  });
});
