import { ComponentFixture, TestBed, fakeAsync, tick } from '@angular/core/testing';
import { Component } from '@angular/core';
import { GridComponent } from './grid.component';
import { ColDef } from 'ag-grid-community';

interface MockRow {
  id: number;
  nombre: string;
  stock: number;
}

const MOCK_ROWS: MockRow[] = [
  { id: 1, nombre: 'Tornillo M6', stock: 150 },
  { id: 2, nombre: 'Tuerca M6',   stock: 80  },
  { id: 3, nombre: 'Arandela',    stock: 0   },
];

const MOCK_COLS: ColDef<MockRow>[] = [
  { field: 'id',     headerName: 'ID',     filter: 'agNumberColumnFilter' },
  { field: 'nombre', headerName: 'Nombre', filter: 'agTextColumnFilter'   },
  { field: 'stock',  headerName: 'Stock',  filter: 'agNumberColumnFilter' },
];

/** Host mínimo para probar el wrapper */
@Component({
  standalone: true,
  imports: [GridComponent],
  template: `
    <erp-grid [rowData]="rows" [columnDefs]="cols" style="height:300px;display:block;" />
  `,
})
class HostComponent {
  rows: MockRow[] = MOCK_ROWS;
  cols: ColDef<MockRow>[] = MOCK_COLS;
}

describe('GridComponent', () => {
  let fixture: ComponentFixture<HostComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [HostComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(HostComponent);
    fixture.detectChanges();
  });

  it('should render ag-grid container', () => {
    const el = fixture.nativeElement as HTMLElement;
    const grid = el.querySelector('ag-grid-angular');
    expect(grid).toBeTruthy();
  });

  it('should apply erp theme class to host', () => {
    const gridHost = fixture.nativeElement.querySelector('erp-grid') as HTMLElement;
    expect(gridHost.classList.contains('ag-theme-erp')).toBeTrue();
  });

  it('should accept rowData input', fakeAsync(() => {
    fixture.detectChanges();
    tick(50);
    const host = fixture.componentInstance;
    expect(host.rows.length).toBe(3);
  }));

  it('should accept columnDefs input', () => {
    const host = fixture.componentInstance;
    expect(host.cols.length).toBe(3);
    expect(host.cols[0].field).toBe('id');
  });

  it('should update when rowData changes', fakeAsync(() => {
    fixture.componentInstance.rows = [MOCK_ROWS[0]];
    fixture.detectChanges();
    tick(50);
    expect(fixture.componentInstance.rows.length).toBe(1);
  }));
});
