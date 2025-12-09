import LightningDatatable from 'lightning/datatable';
import picklistColumn from './picklistColumn.html';

export default class ChargeMapItemsDatatable extends LightningDatatable {
    static customTypes = {
        picklistColumn: {
            template: picklistColumn,
            typeAttributes: ['options', 'placeholder', 'value', 'context']
        }
    };
}