import { LightningElement, api } from 'lwc';

export default class NavigateToRecordFromFlow extends LightningElement {
  @api url; // Reçu depuis Flow
  @api label = 'Go back to record'; // Texte personnalisable

  handleRedirect() {
    if (this.url) {
      window.open(this.url, '_self'); // Redirection dans la même fenêtre
    } else {
      console.error('[navigateToRecordFromFlow] Aucune URL reçue, impossible de rediriger.');
    }
  }
}