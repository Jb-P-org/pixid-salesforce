import { LightningElement } from 'lwc';

import CMG_Title              from '@salesforce/label/c.CMG_Title';
import CMG_AddDeleteProducts  from '@salesforce/label/c.CMG_AddDeleteProducts';
import CMG_GreenIcon          from '@salesforce/label/c.CMG_GreenIcon';
import CMG_OrangeIcon         from '@salesforce/label/c.CMG_OrangeIcon';
import CMG_PurpleIcon         from '@salesforce/label/c.CMG_PurpleIcon';
import CMG_StartDateYear      from '@salesforce/label/c.CMG_StartDateYear';
import CMG_ActivateCheckbox   from '@salesforce/label/c.CMG_ActivateCheckbox';

export default class ChargeMapGuidelines extends LightningElement {
    label = {
        CMG_Title,
        CMG_AddDeleteProducts,
        CMG_GreenIcon,
        CMG_OrangeIcon,
        CMG_PurpleIcon,
        CMG_StartDateYear,
        CMG_ActivateCheckbox
    };
}
