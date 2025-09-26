import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveGridRows from '@salesforce/apex/BulkRegistrationController.saveGridRows';

export default class BulkRegistration extends LightningElement {
    @api recordId; // Event__c Id

    @track rows = [];
    @track draftValues = [];
    @track loading = false;
    @track serverMessages = [];

    selectedRowIds = [];
    searchTerm = '';
    massStatus = '';

    columns = [
        { label: 'Name', fieldName: 'name', type: 'text', editable: true },
        { label: 'Email', fieldName: 'email', type: 'email', editable: true },
        { label: 'Phone', fieldName: 'phone', type: 'phone', editable: true },
        { label: 'Ticket Type', fieldName: 'ticketType', type: 'text', editable: true },
        { label: 'Status', fieldName: 'status', type: 'text', editable: true }
    ];

    get statusOptions() {
        return [
            { label: 'Pending', value: 'Pending' },
            { label: 'Confirmed', value: 'Confirmed' },
            { label: 'Cancelled', value: 'Cancelled' }
        ];
    }

    get noSelection() {
        return !this.selectedRowIds || this.selectedRowIds.length === 0;
    }

    get filteredRows() {
        if (!this.searchTerm) return this.rows;
        const term = this.searchTerm.toLowerCase();
        return this.rows.filter(r =>
            (r.name && r.name.toLowerCase().includes(term)) ||
            (r.email && r.email.toLowerCase().includes(term))
        );
    }

    handleAddRow = () => {
        const id = `row-${Date.now()}-${Math.floor(Math.random() * 100000)}`;
        this.rows = [...this.rows, { id, name: '', email: '', phone: '', ticketType: '', status: 'Pending' }];
    }

    handleDeleteSelected = () => {
        const selected = new Set(this.selectedRowIds);
        this.rows = this.rows.filter(r => !selected.has(r.id));
        this.selectedRowIds = [];
    }

    handleRowSelection = (event) => {
        const selected = event.detail.selectedRows || [];
        this.selectedRowIds = selected.map(r => r.id);
    }

    handleInlineSave = (event) => {
        const drafts = event.detail.draftValues || [];
        const mapById = new Map(this.rows.map(r => [r.id, { ...r }]));
        drafts.forEach(d => {
            const existing = mapById.get(d.id) || { id: d.id };
            mapById.set(d.id, { ...existing, ...d });
        });
        this.rows = Array.from(mapById.values());
        this.draftValues = [];
        this.showToast('Saved', 'Edits applied locally. Click Validate or Save All to persist.', 'success');
    }

    handleSearch = (event) => {
        this.searchTerm = event.target.value || '';
    }

    openFileDialog = () => {
        const input = this.template.querySelector('input[data-id="file"]');
        if (input) input.click();
    }

    handleFileChange = (event) => {
        const file = event.target.files && event.target.files[0];
        if (!file) return;
        try {
            const reader = new FileReader();
            reader.onload = () => {
                try {
                    const text = reader.result || '';
                    const newRows = this.parseCsv(text);
                    this.rows = [...this.rows, ...newRows];
                    this.showToast('Imported', `${newRows.length} row(s) added from CSV.`, 'success');
                } catch (inner) {
                    this.showToast('Error', this.errorMessage(inner), 'error');
                } finally {
                    event.target.value = '';
                }
            };
            reader.onerror = () => {
                this.showToast('Error', 'Failed to read file', 'error');
                event.target.value = '';
            };
            reader.readAsText(file);
        } catch (e) {
            this.showToast('Error', this.errorMessage(e), 'error');
            event.target.value = '';
        }
    }

    parseCsv(text) {
        const lines = (text || '').split(/\r?\n/).filter(l => l.length > 0);
        if (lines.length === 0) return [];
        // Strip BOM if present
        let headerLine = lines[0].replace(/^\uFEFF/, '');
        const headerParts = this.splitCsvLine(headerLine).map(h => h.trim().replace(/^"(.*)"$/, '$1').toLowerCase());
        const idxName = headerParts.indexOf('name');
        const idxEmail = headerParts.indexOf('email');
        const idxPhone = headerParts.indexOf('phone');
        // Accept 'ticket type', 'ticket_type', or 'tickettype'
        let idxTicket = headerParts.indexOf('ticket type');
        if (idxTicket < 0) idxTicket = headerParts.indexOf('ticket_type');
        if (idxTicket < 0) idxTicket = headerParts.indexOf('tickettype');
        const idxStatus = headerParts.indexOf('status');
        const rows = [];
        for (let i = 1; i < lines.length; i++) {
            const parts = this.splitCsvLine(lines[i]).map(v => (v || '').trim().replace(/^"(.*)"$/, '$1'));
            // Skip blank lines
            if (parts.every(p => p === '')) continue;
            const id = `row-${Date.now()}-${i}`;
            rows.push({
                id,
                name: idxName >= 0 ? (parts[idxName] || '').trim() : '',
                email: idxEmail >= 0 ? (parts[idxEmail] || '').trim() : '',
                phone: idxPhone >= 0 ? (parts[idxPhone] || '').trim() : '',
                ticketType: idxTicket >= 0 ? (parts[idxTicket] || '').trim() : '',
                status: idxStatus >= 0 ? (parts[idxStatus] || '').trim() : 'Pending'
            });
        }
        return rows;
    }

    // Split a CSV line handling quoted fields and escaped quotes
    splitCsvLine(line) {
        const result = [];
        let current = '';
        let inQuotes = false;
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === '"') {
                if (inQuotes && line[i + 1] === '"') {
                    current += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch === ',' && !inQuotes) {
                result.push(current);
                current = '';
            } else {
                current += ch;
            }
        }
        result.push(current);
        return result;
    }

    handleMassStatusChange = (event) => {
        this.massStatus = event.detail.value;
    }

    applyMassStatus = () => {
        if (!this.massStatus) return;
        const selected = new Set(this.selectedRowIds);
        this.rows = this.rows.map(r => selected.has(r.id) ? { ...r, status: this.massStatus } : r);
    }

    buildApexRows() {
        return this.rows.map(r => ({
            id: r.id,
            name: (r.name || '').trim(),
            email: (r.email || '').trim(),
            phone: (r.phone || '').trim(),
            ticketType: (r.ticketType || '').trim(),
            status: (r.status || '').trim()
        }));
    }

    async handleValidate() {
        if (!this.recordId) {
            this.showToast('Error', 'Missing Event Id', 'error');
            return;
        }
        this.loading = true;
        this.serverMessages = [];
        // Client-side pre-validation for clearer feedback
        const emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
        const rows = this.buildApexRows();
        const missing = rows.filter(r => !r.name || !r.email).length;
        const invalidEmails = rows.filter(r => r.email && !emailRegex.test(r.email)).length;
        if (rows.length > 0 && (missing === rows.length || (missing + invalidEmails) === rows.length)) {
            this.showToast('Validation', 'All imported rows appear to be missing Name/Email or have invalid Email format. Please check CSV headers (Name, Email, Phone, Ticket Type, Status) and try again.', 'warning');
            this.loading = false;
            return;
        }
        try {
            const resp = await saveGridRows({
                eventId: this.recordId,
                rows,
                defaultStatus: 'Pending',
                validateOnly: true
            });
            this.serverMessages = resp?.messages || [];
            const errors = resp?.errors || 0;
            if (errors > 0 || (resp?.duplicates || 0) > 0) {
                this.showToast('Validation', `Found ${errors} error(s), ${resp?.duplicates || 0} duplicate(s).`, 'warning');
            } else {
                this.showToast('Validation', 'All rows valid.', 'success');
            }
        } catch (e) {
            this.showToast('Error', this.errorMessage(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    async handleSaveAll() {
        if (!this.recordId) {
            this.showToast('Error', 'Missing Event Id', 'error');
            return;
        }
        this.loading = true;
        this.serverMessages = [];
        try {
            const resp = await saveGridRows({
                eventId: this.recordId,
                rows: this.buildApexRows(),
                defaultStatus: 'Pending',
                validateOnly: false
            });
            this.serverMessages = resp?.messages || [];
            if (resp?.success) {
                this.showToast('Success', `Registered ${resp.registrationInserts || 0} attendee(s).`, 'success');
            } else {
                this.showToast('Partial Failure', `Inserted ${resp.registrationInserts || 0}. Errors: ${resp.errors || 0}.`, 'warning');
            }
        } catch (e) {
            this.showToast('Error', this.errorMessage(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errorMessage(e) {
        return e?.body?.message || e?.message || 'Unknown error';
    }
}
