import {
  Component,
  ChangeDetectionStrategy,
  input,
  OnDestroy,
  ElementRef,
  OnInit,
} from '@angular/core';
import { AgGridAngular } from 'ag-grid-angular';
import { ColDef, GridApi, GridReadyEvent } from 'ag-grid-community';

/**
 * Wrapper de ag-grid para el backoffice.
 * Es la ÚNICA forma de usar ag-grid en features — no importar AgGridAngular directamente.
 *
 * Incluye:
 * - Tema aplicado desde tokens CSS (ag-grid-theme.css)
 * - Paginación habilitada por defecto
 * - Filtros por columna
 * - Locale es
 * - Virtualización de filas (ag-grid community nativo)
 *
 * @example
 * // En T-018 (listado bodega):
 * <app-grid [rowData]="insumos()" [columnDefs]="cols" />
 */
@Component({
  selector: 'erp-grid',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [AgGridAngular],
  template: `
    <ag-grid-angular
      class="erp-grid"
      [rowData]="rowData()"
      [columnDefs]="columnDefs()"
      [defaultColDef]="defaultColDef"
      [pagination]="true"
      [paginationPageSize]="50"
      [rowSelection]="'multiple'"
      [animateRows]="true"
      [suppressCellFocus]="false"
      (gridReady)="onGridReady($event)"
    />
  `,
  styles: [`
    :host {
      display: block;
      width: 100%;
    }
    .erp-grid {
      width: 100%;
      height: 500px;
    }
  `],
})
export class GridComponent<T = unknown> implements OnInit, OnDestroy {
  readonly rowData = input<T[]>([]);
  readonly columnDefs = input<ColDef<T>[]>([]);

  readonly defaultColDef: ColDef = {
    sortable: true,
    filter: true,
    resizable: true,
    minWidth: 80,
  };

  private gridApi?: GridApi<T>;

  constructor(private readonly el: ElementRef) {}

  ngOnInit(): void {
    // aplicar clase del tema al host para que ag-grid-theme.css tome efecto
    this.el.nativeElement.classList.add('ag-theme-erp');
  }

  ngOnDestroy(): void {
    this.gridApi?.destroy();
  }

  onGridReady(event: GridReadyEvent<T>): void {
    this.gridApi = event.api;
    event.api.sizeColumnsToFit();
  }
}
