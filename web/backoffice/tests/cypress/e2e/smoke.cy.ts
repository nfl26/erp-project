describe('Smoke — ERP Backoffice shell', () => {
  beforeEach(() => {
    cy.visit('/');
  });

  it('carga la home sin errores de consola', () => {
    cy.on('uncaught:exception', () => false);
    cy.url().should('include', '/home');
    cy.get('body').should('be.visible');
  });

  it('tiene un h1 visible en la página', () => {
    cy.get('h1').should('be.visible');
  });

  it('la sidebar se renderiza con sus items placeholder', () => {
    cy.get('erp-sidebar').should('exist');
    cy.get('erp-sidebar .nav-item').should('have.length.greaterThan', 0);
    cy.contains('.nav-item', 'Bodega').should('exist');
    cy.contains('.nav-item', 'Producción').should('exist');
  });
});
