import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', redirectTo: 'home', pathMatch: 'full' },
  {
    path: 'home',
    loadChildren: () =>
      import('./features/home/home.routes').then(r => r.routes),
  },
  {
    path: '**',
    loadComponent: () =>
      import('./pages/not-found.component').then(c => c.NotFoundComponent),
  },
];
